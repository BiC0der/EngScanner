//
//  ARScanEngine.swift
//  EngScanner
//
//  Core ARKit + LiDAR scanning coordinator.
//  Configures scene reconstruction, mesh classification, plane tracking,
//  and transforms LiDAR spatial telemetry into live structural 2D vector floor plans.
//

import Foundation
import ARKit
import Combine
import simd

public enum ScanState {
    case idle
    case scanning
    case paused
    case completed
}

@MainActor
public final class ARScanEngine: NSObject, ObservableObject {
    
    // MARK: - Published Properties for UI
    
    @Published public private(set) var scanState: ScanState = .idle
    @Published public private(set) var currentFloorPlan: StructuralFloorPlan = StructuralFloorPlan()
    @Published public private(set) var userCameraPosition: Vector2D = .zero
    @Published public private(set) var userCameraHeadingDeg: Double = 0.0
    @Published public private(set) var isLiDARAvailable: Bool = false
    @Published public private(set) var trackedMeshAnchorCount: Int = 0
    @Published public private(set) var confidenceScore: Double = 0.0
    
    // MARK: - Internal Engine Components
    
    public let arSession = ARSession()
    private let structuralFilter = StructuralFilter()
    private let vectorSimplifier = VectorSimplifier()
    private let wallTracker = PersistentWallTracker()
    
    // Processing queue for background geometry analysis
    private let processingQueue = DispatchQueue(label: "com.engscanner.geometry-processing", qos: .userInitiated)
    private var isProcessingFrame = false
    
    public override init() {
        super.init()
        checkLiDARCapability()
        arSession.delegate = self
    }
    
    // MARK: - LiDAR Hardware Capability Check
    
    private func checkLiDARCapability() {
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }
    
    // MARK: - ARSession Lifecycle
    
    public func startScan() {
        guard isLiDARAvailable else {
            startFallbackScan()
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        
        wallTracker.reset()
        currentFloorPlan = StructuralFloorPlan(projectName: "Site Survey", scanDate: Date())
        scanState = .scanning
        
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func startFallbackScan() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        wallTracker.reset()
        scanState = .scanning
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    public func pauseScan() {
        scanState = .paused
        arSession.pause()
    }
    
    public func resumeScan() {
        scanState = .scanning
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.planeDetection = [.horizontal, .vertical]
        arSession.run(configuration)
    }
    
    public func resetScan() {
        scanState = .idle
        wallTracker.reset()
        currentFloorPlan = StructuralFloorPlan()
        userCameraPosition = .zero
        userCameraHeadingDeg = 0.0
        arSession.pause()
    }
    
    public func completeScan() {
        scanState = .completed
        
        // Final CAD Rectification Pass
        var finalizedWalls = currentFloorPlan.walls
        finalizedWalls = vectorSimplifier.mergeCollinearWalls(finalizedWalls)
        finalizedWalls = vectorSimplifier.snapOrthogonal(walls: finalizedWalls)
        finalizedWalls = vectorSimplifier.snapCornerIntersections(finalizedWalls)
        
        currentFloorPlan.walls = finalizedWalls
    }
    
    // MARK: - Geometry Extraction Dispatch
    
    private func processAnchorsAsync(_ anchors: [ARAnchor]) {
        guard scanState == .scanning, !isProcessingFrame else { return }
        isProcessingFrame = true
        
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }
        let currentPos = self.userCameraPosition
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                Task { @MainActor in
                    self.isProcessingFrame = false
                }
            }
            
            // 1. Extract Candidate Wall Segments from Vertical Planes (filter out small surfaces)
            var candidateWalls: [WallSegment] = []
            for plane in planeAnchors where plane.alignment == .vertical {
                let center = plane.center
                let extent = plane.extent
                let transform = plane.transform
                
                // Reject small planes (furniture, small cabinets, tables)
                guard extent.x >= 0.50 && extent.y >= 1.20 else { continue }
                
                let halfWidth = Double(extent.x) * 0.5
                let localP1 = SIMD4<Float>(center.x - Float(halfWidth), center.y, center.z, 1.0)
                let localP2 = SIMD4<Float>(center.x + Float(halfWidth), center.y, center.z, 1.0)
                
                let worldP1 = transform * localP1
                let worldP2 = transform * localP2
                
                let start2D = Vector2D(x: Double(worldP1.x), y: Double(-worldP1.z))
                let end2D = Vector2D(x: Double(worldP2.x), y: Double(-worldP2.z))
                
                guard start2D.distance(to: end2D) >= 0.4 else { continue }
                
                let wall = WallSegment(
                    start: start2D,
                    end: end2D,
                    thickness: 0.15,
                    height: Double(extent.y),
                    wallType: .interior,
                    confidence: 0.95
                )
                candidateWalls.append(wall)
            }
            
            // 2. Intelligent Spatial Deduplication & Outermost Structural Filtering
            let fusedWalls = self.wallTracker.ingestCandidateWalls(candidateWalls, userPosition: currentPos)
            
            // 3. Orthogonal Snapping to Rectangular Axes
            var cleanWalls = self.vectorSimplifier.snapOrthogonal(walls: fusedWalls)
            cleanWalls = self.vectorSimplifier.snapCornerIntersections(cleanWalls)
            
            Task { @MainActor in
                self.trackedMeshAnchorCount = meshAnchors.count
                if !cleanWalls.isEmpty {
                    self.currentFloorPlan.walls = cleanWalls
                    self.confidenceScore = min(1.0, Double(cleanWalls.count) * 0.25)
                }
            }
        }
    }
}

// MARK: - ARSessionDelegate

extension ARScanEngine: ARSessionDelegate {
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let cameraTransform = frame.camera.transform
        let camX = cameraTransform.columns.3.x
        let camZ = cameraTransform.columns.3.z
        let pos = Vector2D(x: Double(camX), y: Double(-camZ))
        
        let forwardVector = cameraTransform.columns.2
        let yawRad = atan2(-forwardVector.x, -forwardVector.z)
        let headingDeg = Double(yawRad * (180.0 / .pi))
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.userCameraPosition = pos
            self.userCameraHeadingDeg = headingDeg
        }
        
        processAnchorsAsync(frame.anchors)
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        processAnchorsAsync(anchors)
    }
    
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        processAnchorsAsync(anchors)
    }
}
