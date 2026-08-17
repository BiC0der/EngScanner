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
    
    // Processing queue for background geometry analysis
    private let processingQueue = DispatchQueue(label: "com.engscanner.geometry-processing", qos: .userInitiated)
    private var isProcessingFrame = false
    private var rawStructuralPoints: [SIMD3<Float>] = []
    
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
    
    /// Starts the LiDAR-based structural scanning session
    public func startScan() {
        guard isLiDARAvailable else {
            print("[ARScanEngine] Warning: Device does not support LiDAR Scene Reconstruction (.meshWithClassification)")
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
        
        rawStructuralPoints.removeAll()
        currentFloorPlan = StructuralFloorPlan(projectName: "Site Survey", scanDate: Date())
        scanState = .scanning
        
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    /// Fallback scan mode for non-LiDAR development devices
    private func startFallbackScan() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
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
        rawStructuralPoints.removeAll()
        currentFloorPlan = StructuralFloorPlan()
        userCameraPosition = .zero
        userCameraHeadingDeg = 0.0
        arSession.pause()
    }
    
    public func completeScan() {
        scanState = .completed
        
        // Final optimization pass on vectors
        var finalizedWalls = currentFloorPlan.walls
        finalizedWalls = vectorSimplifier.mergeCollinearWalls(finalizedWalls)
        finalizedWalls = vectorSimplifier.snapOrthogonal(walls: finalizedWalls)
        finalizedWalls = vectorSimplifier.snapVerticesAndCloseLoop(finalizedWalls)
        
        currentFloorPlan.walls = finalizedWalls
    }
    
    // MARK: - Geometry Extraction Dispatch
    
    private func processAnchorsAsync(_ anchors: [ARAnchor]) {
        guard scanState == .scanning, !isProcessingFrame else { return }
        isProcessingFrame = true
        
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                Task { @MainActor in
                    self.isProcessingFrame = false
                }
            }
            
            var extractedPoints: [SIMD3<Float>] = []
            
            // 1. Process LiDAR classified mesh anchors (Walls only)
            for meshAnchor in meshAnchors {
                let structuralVertices = self.structuralFilter.extractStructuralVertices(from: meshAnchor)
                extractedPoints.append(contentsOf: structuralVertices)
            }
            
            // 2. Process vertical plane anchors (Walls)
            var planeWalls: [WallSegment] = []
            for plane in planeAnchors where plane.alignment == .vertical {
                let center = plane.center
                let extent = plane.extent
                let transform = plane.transform
                
                // Construct 2D line segment representing plane extent in metric floor space
                let halfWidth = Double(extent.x) * 0.5
                let localP1 = SIMD4<Float>(center.x - Float(halfWidth), center.y, center.z, 1.0)
                let localP2 = SIMD4<Float>(center.x + Float(halfWidth), center.y, center.z, 1.0)
                
                let worldP1 = transform * localP1
                let worldP2 = transform * localP2
                
                let start2D = Vector2D(x: Double(worldP1.x), y: Double(-worldP1.z))
                let end2D = Vector2D(x: Double(worldP2.x), y: Double(-worldP2.z))
                
                let wall = WallSegment(
                    start: start2D,
                    end: end2D,
                    thickness: 0.15,
                    height: Double(extent.y),
                    wallType: .interior,
                    confidence: 0.95
                )
                planeWalls.append(wall)
            }
            
            // 3. Vectorize and simplify structural geometry
            let simplifiedWalls = self.vectorSimplifier.mergeCollinearWalls(planeWalls)
            let filteredWalls = self.structuralFilter.filterStructuralWalls(simplifiedWalls)
            
            Task { @MainActor in
                self.trackedMeshAnchorCount = meshAnchors.count
                if !filteredWalls.isEmpty {
                    self.currentFloorPlan.walls = filteredWalls
                    self.confidenceScore = min(1.0, Double(meshAnchors.count) * 0.1)
                }
            }
        }
    }
}

// MARK: - ARSessionDelegate

extension ARScanEngine: ARSessionDelegate {
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update user camera position and heading for live mini-map
        let cameraTransform = frame.camera.transform
        let camX = cameraTransform.columns.3.x
        let camZ = cameraTransform.columns.3.z
        userCameraPosition = Vector2D(x: Double(camX), y: Double(-camZ))
        
        // Compute yaw angle in degrees
        let forwardVector = cameraTransform.columns.2
        let yawRad = atan2(-forwardVector.x, -forwardVector.z)
        userCameraHeadingDeg = Double(yawRad * (180.0 / .pi))
        
        // Trigger structural geometry extraction
        processAnchorsAsync(frame.anchors)
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        processAnchorsAsync(anchors)
    }
    
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        processAnchorsAsync(anchors)
    }
}
