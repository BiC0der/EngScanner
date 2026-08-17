//
//  StructuralFloorPlan.swift
//  EngScanner
//
//  Represents the complete 2D/3D structural floor plan of the scanned space,
//  containing isolated walls, openings, metrics (area, perimeter in meters),
//  and CAD export metadata.
//

import Foundation

public struct StructuralFloorPlan: Identifiable, Codable {
    public var id: UUID
    public var projectName: String
    public var engineerName: String
    public var scanDate: Date
    public var walls: [WallSegment]
    public var ceilingHeight: Double // In meters
    
    public init(
        id: UUID = UUID(),
        projectName: String = "Structural Scan",
        engineerName: String = "Engineer",
        scanDate: Date = Date(),
        walls: [WallSegment] = [],
        ceilingHeight: Double = 2.80
    ) {
        self.id = id
        self.projectName = projectName
        self.engineerName = engineerName
        self.scanDate = scanDate
        self.walls = walls
        self.ceilingHeight = ceilingHeight
    }
    
    // MARK: - Metric Calculations
    
    /// Total combined perimeter length of all structural walls in meters
    public var totalPerimeterMeters: Double {
        return walls.reduce(0.0) { $0 + $1.length }
    }
    
    /// Estimated enclosed floor area in square meters (m²) using Shoelace formula on wall endpoints
    public var estimatedAreaSquareMeters: Double {
        guard walls.count >= 3 else { return 0.0 }
        
        // Extract ordered boundary vertices
        let vertices = orderedVertices()
        guard vertices.count >= 3 else { return 0.0 }
        
        var area: Double = 0.0
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            area += (vertices[i].x * vertices[j].y)
            area -= (vertices[j].x * vertices[i].y)
        }
        return abs(area) * 0.5
    }
    
    /// Bounding box (minX, minY, maxX, maxY) in meters
    public var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        guard !walls.isEmpty else { return (-5, -5, 5, 5) }
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity
        
        for wall in walls {
            minX = min(minX, min(wall.start.x, wall.end.x))
            minY = min(minY, min(wall.start.y, wall.end.y))
            maxX = max(maxX, max(wall.start.x, wall.end.x))
            maxY = max(maxY, max(wall.start.y, wall.end.y))
        }
        
        return (minX, minY, maxX, maxY)
    }
    
    /// Width of the bounding box in meters
    public var widthMeters: Double {
        let b = bounds
        return b.maxX - b.minX
    }
    
    /// Length of the bounding box in meters
    public var lengthMeters: Double {
        let b = bounds
        return b.maxY - b.minY
    }
    
    // MARK: - Vertex Ordering for Polygons
    
    /// Orders wall endpoints into a continuous loop for polygon area and boundary rendering
    public func orderedVertices() -> [Vector2D] {
        guard !walls.isEmpty else { return [] }
        var result: [Vector2D] = []
        for wall in walls {
            if result.isEmpty || result.last?.distance(to: wall.start) ?? 0 > 0.05 {
                result.append(wall.start)
            }
            result.append(wall.end)
        }
        return result
    }
    
    /// Formatted summary string for structural engineering reports
    public var engineeringSummary: String {
        return """
        ==================================================
        STRUCTURAL SCAN REPORT (METRIC)
        Project: \(projectName)
        Engineer: \(engineerName)
        Date: \(ISO8601DateFormatter().string(from: scanDate))
        --------------------------------------------------
        Wall Count: \(walls.count)
        Ceiling Height: \(String(format: "%.2f", ceilingHeight)) m
        Total Wall Perimeter: \(String(format: "%.2f", totalPerimeterMeters)) m
        Estimated Floor Area: \(String(format: "%.2f", estimatedAreaSquareMeters)) m²
        Bounding Box: \(String(format: "%.2f", widthMeters)) m x \(String(format: "%.2f", lengthMeters)) m
        ==================================================
        """
    }
}
