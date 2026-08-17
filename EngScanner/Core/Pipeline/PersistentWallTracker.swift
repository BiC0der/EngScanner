//
//  PersistentWallTracker.swift
//  EngScanner
//
//  Intelligent spatial tracking and deduplication engine.
//  Merges overlapping planes, eliminates duplicate stacked lines,
//  and produces clean, continuous architectural walls.
//

import Foundation
import simd

public final class PersistentWallTracker {
    
    public struct Config {
        /// Maximum perpendicular distance (in meters) to consider two line segments on the same wall
        public var maxCoplanarDistanceMeters: Double = 0.20
        
        /// Maximum angular deviation (in radians) to consider two segments parallel
        public var maxAngularDeviationRad: Double = 12.0 * (.pi / 180.0)
        
        /// Maximum longitudinal gap (in meters) to bridge and merge two segments along the same wall line
        public var maxLongitudinalGapMeters: Double = 0.50
        
        /// Minimum observations/hits before a wall is considered stable and rendered
        public var minHitCountForDisplay: Int = 2
        
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
    
    /// Ingests candidate raw walls from ARKit and intelligently fuses them into persistent walls
    public func ingestCandidateWalls(_ candidates: [WallSegment]) -> [WallSegment] {
        for candidate in candidates {
            fuseCandidate(candidate)
        }
        
        // Remove stale or low-confidence walls
        let now = Date()
        trackedWalls.removeAll { now.timeIntervalSince($0.lastUpdated) > 15.0 && $0.hitCount < 2 }
        
        // Return only stable, validated walls
        return trackedWalls
            .filter { $0.hitCount >= config.minHitCountForDisplay || $0.wall.length >= 1.0 }
            .map { $0.wall }
    }
    
    private func fuseCandidate(_ candidate: WallSegment) {
        guard candidate.length >= 0.25 else { return }
        
        var bestMatchIndex: Int? = nil
        var bestScore: Double = Double.infinity
        
        for (index, tracked) in trackedWalls.enumerated() {
            let existing = tracked.wall
            
            // 1. Angle Check: Are the two walls roughly parallel?
            let angleDiff = abs(existing.direction.angle(to: candidate.direction))
            let isParallel = angleDiff <= config.maxAngularDeviationRad || abs(angleDiff - .pi) <= config.maxAngularDeviationRad
            guard isParallel else { continue }
            
            // 2. Perpendicular Distance Check: How far is candidate from the infinite line of the existing wall?
            let distStart = candidate.start.distanceToSegment(p1: existing.start - existing.direction * 10.0, p2: existing.end + existing.direction * 10.0)
            let distEnd = candidate.end.distanceToSegment(p1: existing.start - existing.direction * 10.0, p2: existing.end + existing.direction * 10.0)
            let perpDist = (distStart + distEnd) * 0.5
            guard perpDist <= config.maxCoplanarDistanceMeters else { continue }
            
            // 3. Longitudinal Overlap / Proximity Check
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
            
            // Project all 4 endpoints onto existing wall axis
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
            matched.wall.thickness = (existing.thickness * Double(matched.hitCount) + candidate.thickness) / Double(matched.hitCount + 1)
            matched.hitCount += 1
            matched.lastUpdated = Date()
            
            trackedWalls[matchIndex] = matched
        } else {
            // ADD AS NEW CANDIDATE WALL
            trackedWalls.append(TrackedWall(wall: candidate, hitCount: 1, lastUpdated: Date()))
        }
    }
}
