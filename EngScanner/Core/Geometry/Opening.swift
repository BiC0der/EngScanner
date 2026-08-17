//
//  Opening.swift
//  EngScanner
//
//  Represents a structural opening (door, window, opening) along a wall segment.
//

import Foundation

public enum OpeningType: String, Codable, CaseIterable {
    case door = "DOOR"
    case window = "WINDOW"
    case opening = "OPENING"
    
    public var dxfLayerName: String {
        switch self {
        case .door: return "DOORS"
        case .window: return "WINDOWS"
        case .opening: return "OPENINGS"
        }
    }
    
    public var cadAciColor: Int {
        switch self {
        case .door: return 4    // Cyan in AutoCAD
        case .window: return 3  // Green in AutoCAD
        case .opening: return 6 // Magenta in AutoCAD
        }
    }
}

public struct Opening: Identifiable, Equatable, Hashable, Codable {
    public var id: UUID
    public var type: OpeningType
    
    /// Distance from wall start point along the wall vector (in meters)
    public var offsetFromStart: Double
    
    /// Width of the opening (in meters)
    public var width: Double
    
    /// Height of the opening (in meters)
    public var height: Double
    
    /// Sill elevation above floor level (in meters, e.g. 0.0m for doors, 0.9m for standard windows)
    public var sillElevation: Double
    
    /// Confidence score from ARKit / RoomPlan (0.0 to 1.0)
    public var confidence: Double
    
    public init(
        id: UUID = UUID(),
        type: OpeningType,
        offsetFromStart: Double,
        width: Double,
        height: Double = 2.1,
        sillElevation: Double = 0.0,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.type = type
        self.offsetFromStart = offsetFromStart
        self.width = width
        self.height = height
        self.sillElevation = sillElevation
        self.confidence = confidence
    }
}
