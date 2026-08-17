//
//  MetricDimensionLabel.swift
//  EngScanner
//
//  Metric HUD components and minimalist widgets for CAD room scanning.
//

import SwiftUI

public struct MetricDimensionBadge: View {
    public let value: Double
    public let unit: String
    public let label: String
    public let iconName: String
    
    public init(value: Double, unit: String = "m", label: String, iconName: String) {
        self.value = value
        self.unit = unit
        self.label = label
        self.iconName = iconName
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.cyan)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.2f", value))
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.12).opacity(0.90))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

public struct CompactMetricIsland: View {
    public let plan: StructuralFloorPlan
    public let wallCount: Int
    
    public init(plan: StructuralFloorPlan, wallCount: Int) {
        self.plan = plan
        self.wallCount = wallCount
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
                Text(String(format: "%.1f m²", plan.estimatedAreaSquareMeters))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 3, height: 3)
            
            HStack(spacing: 4) {
                Image(systemName: "ruler")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.yellow)
                Text(String(format: "%.1f m", plan.totalPerimeterMeters))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 3, height: 3)
            
            HStack(spacing: 4) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
                Text("\(wallCount) walls")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(white: 0.10).opacity(0.85))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
    }
}
