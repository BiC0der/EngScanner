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
        public var sliceThicknessMeters: Float = 0.25
        
        /// Minimum wall length threshold to filter out stray clutter objects (in meters)
        public var minWallLengthThreshold: Double = 0.30
        
        /// Minimum confidence for structural classification
        public var minClassificationConfidence: Float = 0.50
        
        public init() {}
    }
    
    public var config: Configuration
    
    public init(config: Configuration = Configuration()) {
        self.config = config
    }
    
    // MARK: - ARMeshAnchor Classification Filter (Crash-Proof Buffer Reader)
    
    #if canImport(ARKit)
    /// Evaluates if an ARMeshAnchor contains structural geometry (Walls)
    /// and safely filters out vertices belonging to non-structural classifications.
    public func extractStructuralVertices(from meshAnchor: ARMeshAnchor) -> [SIMD3<Float>] {
        let geometry = meshAnchor.geometry
        guard let classification = geometry.classification else { return [] }
        
        let faces = geometry.faces
        let vertices = geometry.vertices
        
        let faceCount = faces.count
        let classCount = classification.count
        let vertexCount = vertices.count
        
        // Safety check: classification count must match face count
        guard faceCount > 0 && classCount > 0 && vertexCount > 0 && faceCount == classCount else {
            return []
        }
        
        let classPointer = classification.buffer.contents().bindMemory(to: UInt8.self, capacity: classCount)
        let facePointer = faces.buffer.contents().bindMemory(to: Int32.self, capacity: faceCount * 3)
        let vertexBytePointer = vertices.buffer.contents()
        let vertexStride = vertices.stride
        let transform = meshAnchor.transform
        
        var structuralPoints: [SIMD3<Float>] = []
        structuralPoints.reserveCapacity(min(faceCount, 800))
        
        // Sampling step to keep 60 FPS real-time performance without lag
        let step = max(1, faceCount / 400)
        
        for faceIndex in stride(from: 0, to: faceCount, by: step) {
            let classRaw = classPointer[faceIndex]
            guard let meshClass = ARMeshClassification(rawValue: Int(classRaw)), meshClass == .wall else {
                continue
            }
            
            // Extract the first vertex of this triangular wall face
            let vIndex0 = Int(facePointer[faceIndex * 3])
            guard vIndex0 >= 0 && vIndex0 < vertexCount else { continue }
            
            let byteOffset = vIndex0 * vertexStride
            let vertexRawPtr = vertexBytePointer.advanced(by: byteOffset)
            let localVertex = vertexRawPtr.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            
            // Transform local mesh coordinates into global ARKit world coordinates
            let localVec4 = SIMD4<Float>(localVertex.x, localVertex.y, localVertex.z, 1.0)
            let worldVec4 = transform * localVec4
            let worldPoint = SIMD3<Float>(worldVec4.x, worldVec4.y, worldVec4.z)
            
            // Horizontal cross-section filter at eye/torso height
            if abs(worldPoint.y - config.sliceElevationMeters) <= config.sliceThicknessMeters {
                structuralPoints.append(worldPoint)
            }
        }
        
        return structuralPoints
    }
    #endif
    
    // MARK: - 2D Ground Plane Projection
    
    /// Projects 3D world points onto the 2D floor plane (XZ plane -> Vector2D in meters)
    public func projectTo2DPlane(points: [SIMD3<Float>]) -> [Vector2D] {
        return points.map { point in
            return Vector2D(x: Double(point.x), y: Double(-point.z))
        }
    }
    
    /// Filters candidate wall segments by minimum length and structural validity
    public func filterStructuralWalls(_ candidateWalls: [WallSegment]) -> [WallSegment] {
        return candidateWalls.filter { wall in
            guard wall.length >= config.minWallLengthThreshold else { return false }
            guard wall.confidence >= Double(config.minClassificationConfidence) else { return false }
            return true
        }
    }
}
