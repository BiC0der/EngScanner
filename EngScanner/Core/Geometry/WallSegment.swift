//
//  WallSegment.swift
//  EngScanner
//
//  Represents an isolated structural wall vector with precise 2D metric coordinates,
//  thickness, height, and attached openings.
//

import Foundation
import CoreGraphics

public enum WallType: String, Codable {
    case exterior = "WALLS_EXTERIOR"
    case interior = "WALLS_INTERIOR"
    case partition = "WALLS_PARTITION"
    
    public var cadAciColor: Int {
        switch self {
        case .exterior: return 7 // White / Black in AutoCAD
        case .interior: return 2 // Yellow in AutoCAD
        case .partition: return 8 // Gray in AutoCAD
        }
    }
    
    public var lineWeightMm: Double {
        switch self {
        case .exterior: return 0.50
        case .interior: return 0.35
        case .partition: return 0.25
        }
    }
}

public struct WallSegment: Identifiable, Equatable, Hashable, Codable {
    public var id: UUID
    
    /// Start coordinate on 2D floor plane (in meters)
    public var start: Vector2D
    
    /// End coordinate on 2D floor plane (in meters)
    public var end: Vector2D
    
    /// Structural thickness of the wall (in meters, e.g. 0.20m exterior, 0.10m interior)
    public var thickness: Double
    
    /// Vertical height of the wall (in meters, e.g. 2.70m)
    public var height: Double
    
    /// Wall classification
    public var wallType: WallType
    
    /// Attached openings (doors, windows, portals)
    public var openings: [Opening]
    
    /// Detection confidence (0.0 to 1.0)
    public var confidence: Double
    
    public init(
        id: UUID = UUID(),
        start: Vector2D,
        end: Vector2D,
        thickness: Double = 0.15,
        height: Double = 2.8,
        wallType: WallType = .interior,
        openings: [Opening] = [],
        confidence: Double = 1.0
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.thickness = thickness
        self.height = height
        self.wallType = wallType
        self.openings = openings
        self.confidence = confidence
    }
    
    // MARK: - Metric Properties
    
    /// Total wall length in meters
    public var length: Double {
        return start.distance(to: end)
    }
    
    /// Wall direction vector (normalized)
    public var direction: Vector2D {
        return (end - start).normalized
    }
    
    /// Outward unit normal vector (perpendicular to wall direction)
    public var normal: Vector2D {
        return direction.normalCCW
    }
    
    /// Midpoint of the wall in meters
    public var midpoint: Vector2D {
        return (start + end) * 0.5
    }
    
    /// Angle in degrees [0, 360)
    public var angleDegrees: Double {
        return (end - start).angleDegrees
    }
    
    // MARK: - 2D CAD Polygon & Thickness Extrusion
    
    /// Generates 4 corner vertices representing the physical wall thickness footprint in meters
    public func polygonOutline() -> [Vector2D] {
        let halfT = (normal * (thickness * 0.5))
        let p1 = start + halfT
        let p2 = end + halfT
        let p3 = end - halfT
        let p4 = start - halfT
        return [p1, p2, p3, p4]
    }
    
    /// Returns world coordinates for start and end of a specific opening along this wall
    public func worldCoordinates(for opening: Opening) -> (start: Vector2D, end: Vector2D) {
        let dir = direction
        let opStart = start + (dir * opening.offsetFromStart)
        let opEnd = opStart + (dir * opening.width)
        return (opStart, opEnd)
    }
}
