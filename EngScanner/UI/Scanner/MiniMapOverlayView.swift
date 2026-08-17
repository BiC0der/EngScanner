//
//  MiniMapOverlayView.swift
//  EngScanner
//
//  Live 2D floor plan mini-map overlay rendered via SwiftUI Canvas.
//  Renders clean structural wall vectors, 1.0m metric grid, and user camera position.
//

import SwiftUI

public struct MiniMapOverlayView: View {
    public let floorPlan: StructuralFloorPlan
    public let userPosition: Vector2D
    public let userHeadingDeg: Double
    
    @State private var scale: CGFloat = 22.0 // Pixels per meter
    @State private var isExpanded: Bool = false
    
    public init(floorPlan: StructuralFloorPlan, userPosition: Vector2D, userHeadingDeg: Double) {
        self.floorPlan = floorPlan
        self.userPosition = userPosition
        self.userHeadingDeg = userHeadingDeg
    }
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                
                // 1. Metric Grid
                drawMetricGrid(context: context, size: size, center: center)
                
                // 2. Structural Walls
                drawWalls(context: context, center: center)
                
                // 3. User Camera Marker
                drawUserPosition(context: context, center: center)
            }
            .background(Color(white: 0.08).opacity(0.80))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
            )
            
            // Expand / Minimize indicator
            Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.cyan)
                .padding(6)
        }
        .frame(width: isExpanded ? 240 : 110, height: isExpanded ? 240 : 110)
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isExpanded.toggle()
                scale = isExpanded ? 35.0 : 22.0
            }
        }
    }
    
    private func toScreenPoint(vec: Vector2D, center: CGPoint) -> CGPoint {
        return CGPoint(
            x: center.x + CGFloat(vec.x) * scale,
            y: center.y - CGFloat(vec.y) * scale
        )
    }
    
    private func drawMetricGrid(context: GraphicsContext, size: CGSize, center: CGPoint) {
        var gridPath = Path()
        let gridSizePx = scale // 1.0 meter
        
        let startX = center.x.truncatingRemainder(dividingBy: gridSizePx)
        let startY = center.y.truncatingRemainder(dividingBy: gridSizePx)
        
        var x = startX
        while x < size.width {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
            x += gridSizePx
        }
        
        var y = startY
        while y < size.height {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
            y += gridSizePx
        }
        
        context.stroke(gridPath, with: .color(Color.white.opacity(0.08)), lineWidth: 0.6)
    }
    
    private func drawWalls(context: GraphicsContext, center: CGPoint) {
        for wall in floorPlan.walls {
            let p1 = toScreenPoint(vec: wall.start, center: center)
            let p2 = toScreenPoint(vec: wall.end, center: center)
            
            var wallPath = Path()
            wallPath.move(to: p1)
            wallPath.addLine(to: p2)
            
            context.stroke(wallPath, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
    
    private func drawUserPosition(context: GraphicsContext, center: CGPoint) {
        let userPt = toScreenPoint(vec: userPosition, center: center)
        
        var conePath = Path()
        conePath.move(to: userPt)
        let headingRad = -userHeadingDeg * (.pi / 180.0) + (.pi / 2.0)
        let coneSpread: Double = .pi / 4.0
        let coneLengthPx: CGFloat = 18.0
        
        let leftAngle = headingRad - (coneSpread / 2.0)
        let rightAngle = headingRad + (coneSpread / 2.0)
        
        let leftPt = CGPoint(
            x: userPt.x + CGFloat(cos(leftAngle)) * coneLengthPx,
            y: userPt.y - CGFloat(sin(leftAngle)) * coneLengthPx
        )
        let rightPt = CGPoint(
            x: userPt.x + CGFloat(cos(rightAngle)) * coneLengthPx,
            y: userPt.y - CGFloat(sin(rightAngle)) * coneLengthPx
        )
        
        conePath.addLine(to: leftPt)
        conePath.addLine(to: rightPt)
        conePath.closeSubpath()
        
        context.fill(conePath, with: .color(Color.cyan.opacity(0.35)))
        
        let dotRect = CGRect(x: userPt.x - 3.5, y: userPt.y - 3.5, width: 7, height: 7)
        context.fill(Path(ellipseIn: dotRect), with: .color(.cyan))
        context.stroke(Path(ellipseIn: dotRect), with: .color(.white), lineWidth: 1.0)
    }
}
