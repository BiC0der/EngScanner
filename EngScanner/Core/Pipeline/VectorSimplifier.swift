//
//  VectorSimplifier.swift
//  EngScanner
//
//  Computational geometry pipeline for vectorizing structural point clouds:
//  - Ramer-Douglas-Peucker (RDP) path simplification
//  - Collinear segment fusion
//  - Dominant-axis orthogonal 90° angle snapping
//  - Corner intersection snapping
//

import Foundation
import CoreGraphics

public final class VectorSimplifier {
    
    public struct Parameters {
        /// Ramer-Douglas-Peucker epsilon distance tolerance in meters (e.g. 0.04m = 4cm)
        public var rdpEpsilonMeters: Double = 0.04
        
        /// Collinear angle tolerance in radians (e.g. 8 degrees)
        public var collinearAngleToleranceRad: Double = 8.0 * (.pi / 180.0)
        
        /// Orthogonal snapping tolerance in radians (e.g. 12 degrees)
        public var orthogonalSnapToleranceRad: Double = 12.0 * (.pi / 180.0)
        
        /// Endpoint closure snap distance in meters (e.g. 0.25m = 25cm)
        public var vertexSnapDistanceMeters: Double = 0.25
        
        public init() {}
    }
    
    public var params: Parameters
    
    public init(params: Parameters = Parameters()) {
        self.params = params
    }
    
    // MARK: - Ramer-Douglas-Peucker (RDP) Algorithm
    
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
            
            return Array(recResults1.dropLast()) + recResults2
        } else {
            return [first, last]
        }
    }
    
    // MARK: - Collinear Wall Segment Fusion
    
    public func mergeCollinearWalls(_ walls: [WallSegment]) -> [WallSegment] {
        guard walls.count > 1 else { return walls }
        
        var merged: [WallSegment] = []
        var remaining = walls
        
        while !remaining.isEmpty {
            var current = remaining.removeFirst()
            var i = 0
            
            while i < remaining.count {
                let candidate = remaining[i]
                let angleDiff = abs(current.direction.angle(to: candidate.direction))
                let isParallel = angleDiff <= params.collinearAngleToleranceRad || abs(angleDiff - .pi) <= params.collinearAngleToleranceRad
                
                let distToCandidate = current.distanceToSegment(candidate)
                
                if isParallel && distToCandidate <= params.vertexSnapDistanceMeters {
                    // Combine into single segment
                    let axis = current.direction
                    let p1 = 0.0
                    let p2 = current.length
                    let p3 = (candidate.start - current.start).dot(axis)
                    let p4 = (candidate.end - current.start).dot(axis)
                    
                    let minProj = min(p1, p2, p3, p4)
                    let maxProj = max(p1, p2, p3, p4)
                    
                    current.start = current.start + (axis * minProj)
                    current.end = current.start + (axis * (maxProj - minProj))
                    current.height = max(current.height, candidate.height)
                    
                    remaining.remove(at: i)
                } else {
                    i += 1
                }
            }
            
            merged.append(current)
        }
        
        return merged
    }
    
    // MARK: - Dominant-Axis Orthogonal 90° Angle Snapping
    
    /// Finds dominant orientation angle (e.g. from longest wall) and snaps all walls to 0°, 90°, 180°, 270°
    public func snapOrthogonal(walls: [WallSegment]) -> [WallSegment] {
        guard let longestWall = walls.max(by: { $0.length < $1.length }) else { return walls }
        let dominantAngle = (longestWall.end - longestWall.start).angle
        
        return walls.map { wall in
            var snapped = wall
            let currentAngle = (wall.end - wall.start).angle
            let relativeAngle = currentAngle - dominantAngle
            
            // Find closest right-angle quadrant (0, π/2, π, 3π/2)
            let quadrant = round(relativeAngle / (.pi / 2.0))
            let targetAngle = dominantAngle + (quadrant * (.pi / 2.0))
            
            let angleDelta = abs(currentAngle - targetAngle)
            if angleDelta <= params.orthogonalSnapToleranceRad || abs(angleDelta - 2 * .pi) <= params.orthogonalSnapToleranceRad {
                let length = wall.length
                let dir = Vector2D(x: cos(targetAngle), y: sin(targetAngle))
                snapped.end = snapped.start + (dir * length)
            }
            
            return snapped
        }
    }
    
    // MARK: - Corner Intersection Snapping
    
    /// Snaps adjacent corner walls together so room corners form clean CAD joints
    public func snapCornerIntersections(_ walls: [WallSegment]) -> [WallSegment] {
        guard walls.count >= 2 else { return walls }
        var result = walls
        
        for i in 0..<result.count {
            for j in (i + 1)..<result.count {
                let w1 = result[i]
                let w2 = result[j]
                
                // If angle is roughly perpendicular (between 60° and 120°)
                let angleBetween = abs(w1.direction.angle(to: w2.direction))
                let isPerpendicular = (angleBetween >= .pi / 3.0 && angleBetween <= 2.0 * .pi / 3.0)
                guard isPerpendicular else { continue }
                
                // Check if any endpoints are close to each other
                let pairs: [(p1: Vector2D, p2: Vector2D, isStart1: Bool, isStart2: Bool)] = [
                    (w1.end, w2.start, false, true),
                    (w1.start, w2.end, true, false),
                    (w1.end, w2.end, false, false),
                    (w1.start, w2.start, true, true)
                ]
                
                for pair in pairs {
                    if pair.p1.distance(to: pair.p2) <= params.vertexSnapDistanceMeters {
                        // Calculate exact mathematical line intersection
                        if let intersection = lineIntersection(p1: w1.start, p2: w1.end, p3: w2.start, p4: w2.end) {
                            if pair.isStart1 { result[i].start = intersection } else { result[i].end = intersection }
                            if pair.isStart2 { result[j].start = intersection } else { result[j].end = intersection }
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func lineIntersection(p1: Vector2D, p2: Vector2D, p3: Vector2D, p4: Vector2D) -> Vector2D? {
        let denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
        guard abs(denom) > 0.0001 else { return nil }
        
        let t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denom
        return Vector2D(
            x: p1.x + t * (p2.x - p1.x),
            y: p1.y + t * (p2.y - p1.y)
        )
    }
}

private extension WallSegment {
    func distanceToSegment(_ other: WallSegment) -> Double {
        let d1 = other.start.distanceToSegment(p1: self.start, p2: self.end)
        let d2 = other.end.distanceToSegment(p1: self.start, p2: self.end)
        let d3 = self.start.distanceToSegment(p1: other.start, p2: other.end)
        let d4 = self.end.distanceToSegment(p1: other.start, p2: other.end)
        return min(min(d1, d2), min(d3, d4))
    }
}
