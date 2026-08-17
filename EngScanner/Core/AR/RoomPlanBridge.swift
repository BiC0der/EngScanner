//
//  RoomPlanBridge.swift
//  EngScanner
//
//  Apple RoomPlan framework integration (iOS 16+ on LiDAR devices).
//  Extracts parametric structural surfaces (walls, doors, windows, openings)
//  with automatic clutter and furniture elimination.
//

import Foundation
import ARKit
import Combine

#if canImport(RoomPlan)
import RoomPlan

@available(iOS 16.0, *)
@MainActor
public final class RoomPlanBridge: NSObject, ObservableObject, RoomCaptureSessionDelegate {
    
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var latestCapturedRoom: CapturedRoom?
    @Published public private(set) var structuralFloorPlan: StructuralFloorPlan = StructuralFloorPlan()
    
    public var captureSession: RoomCaptureSession?
    
    public override init() {
        super.init()
        if RoomCaptureSession.isSupported {
            captureSession = RoomCaptureSession()
            captureSession?.delegate = self
        }
    }
    
    public func startSession() {
        guard let session = captureSession, RoomCaptureSession.isSupported else {
            print("[RoomPlanBridge] RoomPlan is not supported on this device.")
            return
        }
        
        var config = RoomCaptureSession.Configuration()
        // Strictly capture structural elements only
        session.run(configuration: config)
        isScanning = true
    }
    
    public func stopSession() {
        captureSession?.stop()
        isScanning = false
    }
    
    // MARK: - RoomCaptureSessionDelegate
    
    public func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        self.latestCapturedRoom = room
        self.structuralFloorPlan = convertToStructuralFloorPlan(room: room)
    }
    
    public func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        isScanning = false
        if let error = error {
            print("[RoomPlanBridge] RoomCaptureSession ended with error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transformation to Structural Floor Plan
    
    private func convertToStructuralFloorPlan(room: CapturedRoom) -> StructuralFloorPlan {
        var walls: [WallSegment] = []
        
        // 1. Process Walls
        for wall in room.walls {
            let transform = wall.transform
            let dimensions = wall.dimensions // SIMD3<Float>(width, height, thickness)
            
            let halfWidth = Double(dimensions.x) * 0.5
            
            // Calculate start and end coordinates in world space (XZ plane)
            let localStart = SIMD4<Float>(-Float(halfWidth), 0, 0, 1.0)
            let localEnd = SIMD4<Float>(Float(halfWidth), 0, 0, 1.0)
            
            let worldStart = transform * localStart
            let worldEnd = transform * localEnd
            
            let start2D = Vector2D(x: Double(worldStart.x), y: Double(-worldStart.z))
            let end2D = Vector2D(x: Double(worldEnd.x), y: Double(-worldEnd.z))
            
            // Process attached openings (doors/windows on this wall)
            var openings: [Opening] = []
            
            for door in room.doors {
                if isOpeningOnWall(openingTransform: door.transform, wallTransform: transform) {
                    openings.append(Opening(
                        type: .door,
                        offsetFromStart: calculateOffset(openingPos: door.transform.columns.3, wallStart: worldStart, wallDir: (worldEnd - worldStart)),
                        width: Double(door.dimensions.x),
                        height: Double(door.dimensions.y),
                        sillElevation: 0.0
                    ))
                }
            }
            
            for window in room.windows {
                if isOpeningOnWall(openingTransform: window.transform, wallTransform: transform) {
                    openings.append(Opening(
                        type: .window,
                        offsetFromStart: calculateOffset(openingPos: window.transform.columns.3, wallStart: worldStart, wallDir: (worldEnd - worldStart)),
                        width: Double(window.dimensions.x),
                        height: Double(window.dimensions.y),
                        sillElevation: 0.90
                    ))
                }
            }
            
            let wallSegment = WallSegment(
                id: wall.identifier,
                start: start2D,
                end: end2D,
                thickness: Double(dimensions.z),
                height: Double(dimensions.y),
                wallType: .exterior,
                openings: openings,
                confidence: 1.0
            )
            
            walls.append(wallSegment)
        }
        
        return StructuralFloorPlan(
            projectName: "RoomPlan Survey",
            engineerName: "Field Contractor",
            scanDate: Date(),
            walls: walls,
            ceilingHeight: walls.map(\.height).max() ?? 2.80
        )
    }
    
    private func isOpeningOnWall(openingTransform: simd_float4x4, wallTransform: simd_float4x4) -> Bool {
        let opPos = SIMD3<Float>(openingTransform.columns.3.x, openingTransform.columns.3.y, openingTransform.columns.3.z)
        let wallPos = SIMD3<Float>(wallTransform.columns.3.x, wallTransform.columns.3.y, wallTransform.columns.3.z)
        return simd_distance(opPos, wallPos) < 2.5
    }
    
    private func calculateOffset(openingPos: simd_float4, wallStart: simd_float4, wallDir: simd_float4) -> Double {
        let opVec = SIMD2<Float>(openingPos.x - wallStart.x, openingPos.z - wallStart.z)
        let dirVec = SIMD2<Float>(wallDir.x, wallDir.z)
        let len = simd_length(dirVec)
        guard len > 0.001 else { return 0.0 }
        let normDir = dirVec / len
        let projection = simd_dot(opVec, normDir)
        return max(0.0, Double(projection))
    }
}
#endif
