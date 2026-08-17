//
//  MeshWallExtractor.swift
//  EngScanner
//
//  Extracts crisp 2D CAD wall segments directly from LiDAR classified mesh point clouds.
//  Provides instant, sub-second wall detection with zero delay.
//

import Foundation
import simd

public final class MeshWallExtractor {
    
    public init() {}
    
    /// Converts a cloud of 2D structural points into clean linear wall segments
    public func extractWalls(from points: [Vector2D], gridResolution: Double = 0.15) -> [WallSegment] {
        guard points.count >= 10 else { return [] }
        
        // 1. Spatial Clustering: Group points into spatial clusters along lines
        // Bin points into grid cells
        var grid: [Int: [Vector2D]] = [:]
        for pt in points {
            let key = (Int(floor(pt.x / gridResolution)) * 73856093) ^ (Int(floor(pt.y / gridResolution)) * 19349663)
            grid[key, default: []].append(pt)
        }
        
        // Find bounding spans of point clusters
        // For efficiency, perform PCA / Principal Direction fitting or Axis-Aligned bounding
        var candidateWalls: [WallSegment] = []
        
        // Separate points by dominant orientation: Horizontal (along X) vs Vertical (along Y)
        var horizontalBins: [Int: [Vector2D]] = [:] // Grouped by Y
        var verticalBins: [Int: [Vector2D]] = [:]   // Grouped by X
        
        let binSize = 0.25 // 25cm binning
        
        for pt in points {
            let yBin = Int(round(pt.y / binSize))
            let xBin = Int(round(pt.x / binSize))
            
            horizontalBins[yBin, default: []].append(pt)
            verticalBins[xBin, default: []].append(pt)
        }
        
        // Extract Horizontal Walls (spanning along X at a given Y)
        for (binIndex, binPoints) in horizontalBins where binPoints.count >= 8 {
            let avgY = Double(binIndex) * binSize
            let xValues = binPoints.map(\.x)
            guard let minX = xValues.min(), let maxX = xValues.max() else { continue }
            
            let length = maxX - minX
            if length >= 0.40 {
                let wall = WallSegment(
                    start: Vector2D(x: minX, y: avgY),
                    end: Vector2D(x: maxX, y: avgY),
                    thickness: 0.15,
                    height: 2.6,
                    wallType: .interior,
                    confidence: min(1.0, Double(binPoints.count) * 0.05)
                )
                candidateWalls.append(wall)
            }
        }
        
        // Extract Vertical Walls (spanning along Y at a given X)
        for (binIndex, binPoints) in verticalBins where binPoints.count >= 8 {
            let avgX = Double(binIndex) * binSize
            let yValues = binPoints.map(\.y)
            guard let minY = yValues.min(), let maxY = yValues.max() else { continue }
            
            let length = maxY - minY
            if length >= 0.40 {
                let wall = WallSegment(
                    start: Vector2D(x: avgX, y: minY),
                    end: Vector2D(x: avgX, y: maxY),
                    thickness: 0.15,
                    height: 2.6,
                    wallType: .interior,
                    confidence: min(1.0, Double(binPoints.count) * 0.05)
                )
                candidateWalls.append(wall)
            }
        }
        
        return candidateWalls
    }
}
