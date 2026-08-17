//
//  PersistentWallTracker.swift
//  EngScanner
//
//  Intelligent structural spatial tracking, furniture filtering, and CAD unification engine.
//  Merges overlapping walls and rectifies boundaries to clean architectural room geometry.
//

import Foundation
import simd

public final class PersistentWallTracker {
    
    public struct Config {
        /// Maximum perpendicular distance (in meters) to fuse parallel wall segments
        public var maxCoplanarDistanceMeters: Double = 0.35
        
        /// Maximum angular deviation (in radians) to consider two segments parallel
        public var maxAngularDeviationRad: Double = 18.0 * (.pi / 180.0)
        
        /// Maximum longitudinal gap (in meters) to bridge and merge two segments along the same wall line
        public var maxLongitudinalGapMeters: Double = 1.00
        
        /// Minimum wall length (in meters) to display
        public var minStructuralWallLengthMeters: Double = 0.30
        
        /// Minimum observations/hits before a wall is locked and rendered (1 = instant feedback)
        public var minHitCountForDisplay: Int = 1
        
        public init() {}
    }
    
    public var config: Config
    
    // Tracked persistent walls with observation counts
    private struct TrackedWall {
        var wall: WallSegment
        var hitCount: Int
        var lastUpdated: Date
    }
    
    private var trackedWalls: [TrackedWall] = []
    
    public init(config: Config = Config()) {
        self.config = config
    }
    
    public func reset() {
        trackedWalls.removeAll()
    }
    
    // MARK: - Ingestion & Fusion Pipeline
    
    /// Ingests candidate raw planes and filters out furniture/clutter
    public func ingestCandidateWalls(_ candidates: [WallSegment], userPosition: Vector2D = .zero) -> [WallSegment] {
        for candidate in candidates {
            guard candidate.length >= config.minStructuralWallLengthMeters else { continue }
            fuseCandidate(candidate, userPos: userPosition)
        }
        
        // Remove stale transient detections (keep for 20 seconds)
        let now = Date()
        trackedWalls.removeAll { now.timeIntervalSince($0.lastUpdated) > 20.0 && $0.hitCount < 2 }
        
        // Outermost Boundary Selection (Filter out duplicate inner planes)
        let filteredWalls = filterOutermostStructuralWalls(userPosition: userPosition)
        
        return filteredWalls
    }
    
    private func fuseCandidate(_ candidate: WallSegment, userPos: Vector2D) {
        var bestMatchIndex: Int? = nil
        var bestScore: Double = Double.infinity
        
        for (index, tracked) in trackedWalls.enumerated() {
            let existing = tracked.wall
            
            // 1. Angle Check: Are the two walls roughly parallel?
            let angleDiff = abs(existing.direction.angle(to: candidate.direction))
            let isParallel = angleDiff <= config.maxAngularDeviationRad || abs(angleDiff - .pi) <= config.maxAngularDeviationRad
            guard isParallel else { continue }
            
            // 2. Perpendicular Distance Check: How far is candidate from the existing wall plane?
            let distStart = candidate.start.distanceToSegment(p1: existing.start - existing.direction * 10.0, p2: existing.end + existing.direction * 10.0)
            let distEnd = candidate.end.distanceToSegment(p1: existing.start - existing.direction * 10.0, p2: existing.end + existing.direction * 10.0)
            let perpDist = (distStart + distEnd) * 0.5
            guard perpDist <= config.maxCoplanarDistanceMeters else { continue }
            
            // 3. Longitudinal Proximity Check
            let existingDir = existing.direction
            let projExStart = 0.0
            let projExEnd = existing.length
            
            let projCandStart = (candidate.start - existing.start).dot(existingDir)
            let projCandEnd = (candidate.end - existing.start).dot(existingDir)
            
            let minCandProj = min(projCandStart, projCandEnd)
            let maxCandProj = max(projCandStart, projCandEnd)
            
            let overlap = max(0.0, min(projExEnd, maxCandProj) - max(projExStart, minCandProj))
            let gap = max(0.0, max(projExStart, minCandProj) - min(projExEnd, maxCandProj))
            
            if overlap > 0.0 || gap <= config.maxLongitudinalGapMeters {
                let score = perpDist + gap * 0.5
                if score < bestScore {
                    bestScore = score
                    bestMatchIndex = index
                }
            }
        }
        
        if let matchIndex = bestMatchIndex {
            // MERGE & EXTEND EXISTING WALL
            var matched = trackedWalls[matchIndex]
            let existing = matched.wall
            let existingDir = existing.direction
            
            let proj1 = 0.0
            let proj2 = existing.length
            let proj3 = (candidate.start - existing.start).dot(existingDir)
            let proj4 = (candidate.end - existing.start).dot(existingDir)
            
            let minProj = min(proj1, proj2, proj3, proj4)
            let maxProj = max(proj1, proj2, proj3, proj4)
            
            let newStart = existing.start + (existingDir * minProj)
            let newEnd = existing.start + (existingDir * maxProj)
            
            matched.wall.start = newStart
            matched.wall.end = newEnd
            matched.wall.height = max(existing.height, candidate.height)
            matched.wall.thickness = max(0.15, (existing.thickness + candidate.thickness) * 0.5)
            matched.hitCount += 1
            matched.lastUpdated = Date()
            
            trackedWalls[matchIndex] = matched
        } else {
            // ADD AS NEW STRUCTURAL CANDIDATE
            trackedWalls.append(TrackedWall(wall: candidate, hitCount: 1, lastUpdated: Date()))
        }
    }
    
    // MARK: - Outermost Perimeter Filter
    
    private func filterOutermostStructuralWalls(userPosition: Vector2D) -> [WallSegment] {
        let stableWalls = trackedWalls
            .filter { $0.hitCount >= config.minHitCountForDisplay }
            .map { $0.wall }
        
        guard stableWalls.count > 1 else { return stableWalls }
        
        var result: [WallSegment] = []
        
        for wall in stableWalls {
            var isInnerClutter = false
            
            for other in stableWalls where other.id != wall.id {
                let angleDiff = abs(wall.direction.angle(to: other.direction))
                let isParallel = angleDiff <= config.maxAngularDeviationRad || abs(angleDiff - .pi) <= config.maxAngularDeviationRad
                
                if isParallel {
                    let perpDist = wall.midpoint.distanceToSegment(p1: other.start - other.direction * 10.0, p2: other.end + other.direction * 10.0)
                    
                    // If within 0.60m of another parallel wall
                    if perpDist > 0.15 && perpDist <= 0.60 {
                        let dist1 = wall.midpoint.distance(to: userPosition)
                        let dist2 = other.midpoint.distance(to: userPosition)
                        
                        if dist1 < dist2 {
                            isInnerClutter = true
                            break
                        }
                    }
                }
            }
            
            if !isInnerClutter {
                result.append(wall)
            }
        }
        
        return result.isEmpty ? stableWalls : result
    }
}
