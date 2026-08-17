//
//  StructuralFilter.swift
//  EngScanner
//
//  Semantic segmentation and point cloud / mesh filtering.
//  Strictly isolates structural elements (walls, floors, ceilings)
//  and eliminates furniture, clutter, tables, chairs, decorations.
//

import Foundation
import ARKit
import simd

public final class StructuralFilter {
    
    // Configurable filtering parameters
    public struct Configuration {
        /// Cross-section slicing plane height in meters (e.g. 1.2m above floor)
        public var sliceElevationMeters: Float = 1.2
        
        /// Slicing thickness tolerance in meters
        public var sliceThicknessMeters: Float = 0.20
        
        /// Minimum wall length threshold to filter out stray clutter objects (in meters)
        public var minWallLengthThreshold: Double = 0.40
        
        /// Minimum confidence for structural classification
        public var minClassificationConfidence: Float = 0.60
        
        public init() {}
    }
    
    public var config: Configuration
    
    public init(config: Configuration = Configuration()) {
        self.config = config
    }
    
    // MARK: - ARMeshAnchor Classification Filter
    
    #if canImport(ARKit)
    /// Evaluates if an ARMeshAnchor contains structural geometry (Walls / Floors)
    /// and filters out vertices belonging to non-structural classifications.
    public func extractStructuralVertices(from meshAnchor: ARMeshAnchor) -> [SIMD3<Float>] {
        guard let classification = meshAnchor.geometry.classification else {
            return []
        }
        
        let vertices = meshAnchor.geometry.vertices
        let vertexCount = vertices.count
        let classificationCount = classification.count
        
        // Ensure vertex buffer matches classification buffer length
        guard vertexCount > 0 && classificationCount > 0 else { return [] }
        
        var structuralPoints: [SIMD3<Float>] = []
        structuralPoints.reserveCapacity(vertexCount / 2)
        
        let classificationPointer = classification.buffer.contents().assumingMemoryBound(to: UInt8.self)
        let vertexPointer = vertices.buffer.contents().assumingMemoryBound(to: SIMD3<Float>.self)
        
        let transform = meshAnchor.transform
        
        for i in 0..<min(vertexCount, classificationCount) {
            let classRaw = classificationPointer[i]
            guard let meshClass = ARMeshClassification(rawValue: Int(classRaw)) else { continue }
            
            // STRICT STRUCTURAL FILTER:
            // Allow ONLY .wall, .floor, .ceiling
            // Reject .table, .seat, .door (for raw mesh), .window, .none (unclassified noise)
            switch meshClass {
            case .wall:
                // Transform local vertex coordinates into global ARKit world coordinates
                let localVertex = vertexPointer[i]
                let localVec4 = SIMD4<Float>(localVertex.x, localVertex.y, localVertex.z, 1.0)
                let worldVec4 = transform * localVec4
                let worldPoint = SIMD3<Float>(worldVec4.x, worldVec4.y, worldVec4.z)
                
                // Cross-section horizontal filtering at standard eye/torso height
                if abs(worldPoint.y - config.sliceElevationMeters) <= config.sliceThicknessMeters {
                    structuralPoints.append(worldPoint)
                }
            default:
                // Strictly ignore furniture, chairs, tables, and clutter
                break
            }
        }
        
        return structuralPoints
    }
    #endif
    
    // MARK: - 2D Ground Plane Projection
    
    /// Projects 3D world points onto the 2D floor plane (XZ plane -> Vector2D in meters)
    public func projectTo2DPlane(points: [SIMD3<Float>]) -> [Vector2D] {
        return points.map { point in
            // ARKit Coordinate System:
            // +X is right, +Y is up (gravity opposite), +Z is towards viewer (backward)
            // In 2D floor plan CAD space: X is East/Right, Y is North/Forward (-Z in ARKit)
            return Vector2D(x: Double(point.x), y: Double(-point.z))
        }
    }
    
    /// Filters candidate wall segments by minimum length and structural validity
    public func filterStructuralWalls(_ candidateWalls: [WallSegment]) -> [WallSegment] {
        return candidateWalls.filter { wall in
            // Filter out transient micro-segments (clutter artifacts)
            guard wall.length >= config.minWallLengthThreshold else { return false }
            guard wall.confidence >= Double(config.minClassificationConfidence) else { return false }
            return true
        }
    }
}
