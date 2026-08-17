//
//  VectorSimplifier.swift
//  EngScanner
//
//  Computational geometry pipeline for vectorizing structural point clouds:
//  - Ramer-Douglas-Peucker (RDP) path simplification
//  - Collinear segment fusion
//  - Orthogonal 90° angle snapping
//  - Vertex closure and snapping
//

import Foundation
import CoreGraphics

public final class VectorSimplifier {
    
    public struct Parameters {
        /// Ramer-Douglas-Peucker epsilon distance tolerance in meters (e.g. 0.04m = 4cm)
        public var rdpEpsilonMeters: Double = 0.04
        
        /// Collinear angle tolerance in radians (e.g. 5 degrees)
        public var collinearAngleToleranceRad: Double = 5.0 * (.pi / 180.0)
        
        /// Orthogonal snapping tolerance in radians (e.g. 6 degrees)
        public var orthogonalSnapToleranceRad: Double = 6.0 * (.pi / 180.0)
        
        /// Endpoint closure snap distance in meters (e.g. 0.06m = 6cm)
        public var vertexSnapDistanceMeters: Double = 0.06
        
        public init() {}
    }
    
    public var params: Parameters
    
    public init(params: Parameters = Parameters()) {
        self.params = params
    }
    
    // MARK: - Ramer-Douglas-Peucker (RDP) Algorithm
    
    /// Reduces a dense polyline of 2D points into principal structural vertices
    public func simplifyRDP(points: [Vector2D], epsilon: Double? = nil) -> [Vector2D] {
        let eps = epsilon ?? params.rdpEpsilonMeters
        guard points.count >= 3 else { return points }
        
        var maxDistance: Double = 0.0
        var index = 0
        let first = points.first!
        let last = points.last!
        
        for i in 1..<(points.count - 1) {
            let dist = points[i].distanceToSegment(p1: first, p2: last)
            if dist > maxDistance {
                maxDistance = dist
                index = i
            }
        }
        
        if maxDistance > eps {
            let leftSlice = Array(points[0...index])
            let rightSlice = Array(points[index..<points.count])
            
            let recResults1 = simplifyRDP(points: leftSlice, epsilon: eps)
            let recResults2 = simplifyRDP(points: rightSlice, epsilon: eps)
            
            // Combine slices without duplicating the middle vertex
            return Array(recResults1.dropLast()) + recResults2
        } else {
            return [first, last]
        }
    }
    
    // MARK: - Collinear Wall Segment Fusion
    
    /// Merges adjacent wall segments that are nearly collinear into single clean CAD vectors
    public func mergeCollinearWalls(_ walls: [WallSegment]) -> [WallSegment] {
        guard walls.count > 1 else { return walls }
        
        var merged: [WallSegment] = []
        var current = walls[0]
        
        for i in 1..<walls.count {
            let next = walls[i]
            
            // Check if 'current' and 'next' share an endpoint (or are very close)
            let areConnected = current.end.distance(to: next.start) <= params.vertexSnapDistanceMeters
            
            // Check if vectors have similar angle / direction
            let angleDiff = abs(current.direction.angle(to: next.direction))
            let isCollinear = angleDiff <= params.collinearAngleToleranceRad || abs(angleDiff - .pi) <= params.collinearAngleToleranceRad
            
            if areConnected && isCollinear {
                // Merge into single elongated wall segment
                let combinedOpenings = current.openings + next.openings.map { op in
                    var offsetOp = op
                    offsetOp.offsetFromStart += current.length
                    return offsetOp
                }
                
                current = WallSegment(
                    id: current.id,
                    start: current.start,
                    end: next.end,
                    thickness: (current.thickness + next.thickness) * 0.5,
                    height: max(current.height, next.height),
                    wallType: current.wallType,
                    openings: combinedOpenings,
                    confidence: (current.confidence + next.confidence) * 0.5
                )
            } else {
                merged.append(current)
                current = next
            }
        }
        
        merged.append(current)
        return merged
    }
    
    // MARK: - Orthogonal 90° Angle Snapping
    
    /// Snaps nearly perpendicular walls (e.g. 86° - 94°) to exact 90° angles for architectural accuracy
    public func snapOrthogonal(walls: [WallSegment], dominantAngleRad: Double = 0.0) -> [WallSegment] {
        return walls.map { wall in
            var snapped = wall
            let angle = (wall.end - wall.start).angle
            let relativeAngle = angle - dominantAngleRad
            
            // Find nearest cardinal direction (0, π/2, π, 3π/2)
            let quadrant = round(relativeAngle / (.pi / 2.0))
            let targetAngle = dominantAngleRad + (quadrant * (.pi / 2.0))
            
            let angleDelta = abs(angle - targetAngle)
            if angleDelta <= params.orthogonalSnapToleranceRad {
                let length = wall.length
                let dir = Vector2D(x: cos(targetAngle), y: sin(targetAngle))
                snapped.end = snapped.start + (dir * length)
            }
            
            return snapped
        }
    }
    
    // MARK: - Corner Vertex Snapping & Loop Closure
    
    /// Snaps adjacent wall endpoints together if they are within tolerance to close the floor plan polygon
    public func snapVerticesAndCloseLoop(_ walls: [WallSegment]) -> [WallSegment] {
        guard walls.count >= 3 else { return walls }
        var result = walls
        
        for i in 0..<result.count {
            let nextIndex = (i + 1) % result.count
            let pEnd = result[i].end
            let pNextStart = result[nextIndex].start
            
            if pEnd.distance(to: pNextStart) <= params.vertexSnapDistanceMeters {
                // Snap to mid-point average
                let mid = (pEnd + pNextStart) * 0.5
                result[i].end = mid
                result[nextIndex].start = mid
            }
        }
        
        return result
    }
}
