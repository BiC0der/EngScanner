//
//  Vector2D.swift
//  EngScanner
//
//  High-precision 2D Vector math and computational geometry
//  specifically tailored for structural floor plan extraction and CAD alignment in meters.
//

import Foundation
import CoreGraphics
import simd

/// A 2D point or vector in metric space (meters).
public struct Vector2D: Equatable, Hashable, Codable {
    public var x: Double // In meters
    public var y: Double // In meters (corresponds to -Z in ARKit coordinate space)
    
    public static let zero = Vector2D(x: 0, y: 0)
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public init(_ x: Float, _ y: Float) {
        self.x = Double(x)
        self.y = Double(y)
    }
    
    public init(_ cgPoint: CGPoint) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
    }
    
    public var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
    
    public var simdFloat2: SIMD2<Float> {
        return SIMD2<Float>(Float(x), Float(y))
    }
    
    // MARK: - Vector Arithmetic
    
    public static func + (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        return Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    public static func - (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        return Vector2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    public static func * (lhs: Vector2D, scalar: Double) -> Vector2D {
        return Vector2D(x: lhs.x * scalar, y: lhs.y * scalar)
    }
    
    public static func / (lhs: Vector2D, scalar: Double) -> Vector2D {
        guard scalar != 0 else { return .zero }
        return Vector2D(x: lhs.x / scalar, y: lhs.y / scalar)
    }
    
    // MARK: - Geometric Operations
    
    /// Euclidean length/magnitude of the vector in meters
    public var length: Double {
        return hypot(x, y)
    }
    
    /// Squared length to avoid costly square root operations during comparisons
    public var lengthSquared: Double {
        return (x * x) + (y * y)
    }
    
    /// Normalized unit vector
    public var normalized: Vector2D {
        let len = length
        return len > 0.000001 ? (self / len) : .zero
    }
    
    /// Dot product with another vector
    public func dot(_ other: Vector2D) -> Double {
        return (x * other.x) + (y * other.y)
    }
    
    /// 2D Cross product (scalar determinant)
    public func cross(_ other: Vector2D) -> Double {
        return (x * other.y) - (y * other.x)
    }
    
    /// Euclidean distance to another point in meters
    public func distance(to other: Vector2D) -> Double {
        return (self - other).length
    }
    
    /// Squared distance to another point
    public func distanceSquared(to other: Vector2D) -> Double {
        return (self - other).lengthSquared
    }
    
    /// Returns perpendicular normal vector (rotated 90 degrees counter-clockwise)
    public var normalCCW: Vector2D {
        return Vector2D(x: -y, y: x)
    }
    
    /// Returns perpendicular normal vector (rotated 90 degrees clockwise)
    public var normalCW: Vector2D {
        return Vector2D(x: y, y: -x)
    }
    
    /// Angle in radians relative to positive X-axis
    public var angle: Double {
        return atan2(y, x)
    }
    
    /// Angle in degrees [0, 360)
    public var angleDegrees: Double {
        let deg = angle * (180.0 / .pi)
        return deg >= 0 ? deg : deg + 360.0
    }
    
    /// Angle between two vectors in radians [0, π]
    public func angle(to other: Vector2D) -> Double {
        let denom = self.length * other.length
        guard denom > 0.000001 else { return 0 }
        let cosVal = max(-1.0, min(1.0, self.dot(other) / denom))
        return acos(cosVal)
    }
    
    /// Perpendicular distance from this point to a line segment (P1 -> P2)
    public func distanceToSegment(p1: Vector2D, p2: Vector2D) -> Double {
        let l2 = p1.distanceSquared(to: p2)
        if l2 == 0 { return self.distance(to: p1) }
        
        let t = max(0, min(1, (self - p1).dot(p2 - p1) / l2))
        let projection = p1 + (p2 - p1) * t
        return self.distance(to: projection)
    }
    
    /// Closest projected point on line segment (P1 -> P2)
    public func closestPointOnSegment(p1: Vector2D, p2: Vector2D) -> Vector2D {
        let l2 = p1.distanceSquared(to: p2)
        if l2 == 0 { return p1 }
        let t = max(0, min(1, (self - p1).dot(p2 - p1) / l2))
        return p1 + (p2 - p1) * t
    }
}
