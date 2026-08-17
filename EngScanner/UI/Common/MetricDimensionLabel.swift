//
//  MetricDimensionLabel.swift
//  EngScanner
//
//  SwiftUI components for displaying metric measurements (meters, m²).
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

public struct MetricLiveHUD: View {
    public let plan: StructuralFloorPlan
    public let wallCount: Int
    
    public init(plan: StructuralFloorPlan, wallCount: Int) {
        self.plan = plan
        self.wallCount = wallCount
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            MetricDimensionBadge(
                value: plan.estimatedAreaSquareMeters,
                unit: "m²",
                label: "Area",
                iconName: "square.dashed"
            )
            MetricDimensionBadge(
                value: plan.totalPerimeterMeters,
                unit: "m",
                label: "Perimeter",
                iconName: "ruler"
            )
            MetricDimensionBadge(
                value: plan.ceilingHeight,
                unit: "m",
                label: "Height",
                iconName: "arrow.up.and.down"
            )
            MetricDimensionBadge(
                value: Double(wallCount),
                unit: "walls",
                label: "Walls",
                iconName: "square.3.layers.3d"
            )
        }
        .frame(maxWidth: .infinity)
    }
}
