//
//  MiniMapOverlayView.swift
//  EngScanner
//
//  Live 2D floor plan mini-map overlay rendered via SwiftUI Canvas.
//  Renders structural wall vectors, real-time meter dimensions,
//  a 1.0m metric grid, and user camera position / heading cone.
//

import SwiftUI

public struct MiniMapOverlayView: View {
    public let floorPlan: StructuralFloorPlan
    public let userPosition: Vector2D
    public let userHeadingDeg: Double
    
    @State private var scale: CGFloat = 35.0 // Pixels per meter
    @State private var offset: CGSize = .zero
    @State private var isExpanded: Bool = false
    
    public init(floorPlan: StructuralFloorPlan, userPosition: Vector2D, userHeadingDeg: Double) {
        self.floorPlan = floorPlan
        self.userPosition = userPosition
        self.userHeadingDeg = userHeadingDeg
    }
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main CAD Canvas
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)
                
                // 1. Draw 1.0m Metric Reference Grid
                drawMetricGrid(context: context, size: size, center: center)
                
                // 2. Draw Structural Walls
                drawWalls(context: context, center: center)
                
                // 3. Draw Dimension Annotations in Meters
                drawDimensions(context: context, center: center)
                
                // 4. Draw User Camera Position and Heading Cone
                drawUserPosition(context: context, center: center)
            }
            .background(Color(white: 0.08).opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(15.0, min(80.0, 35.0 * value))
                    }
            )
            
            // Header Controls & Legend
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("LIVE 2D CAD (METERS)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
                
                Spacer()
                
                // Reset View Button
                Button(action: {
                    withAnimation(.spring()) {
                        offset = .zero
                        scale = 35.0
                    }
                }) {
                    Image(systemName: "scope")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding(10)
        }
        .frame(width: isExpanded ? 340 : 220, height: isExpanded ? 340 : 220)
        .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 4)
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                isExpanded.toggle()
            }
        }
    }
    
    // MARK: - Canvas Drawing Routines
    
    private func toScreenPoint(vec: Vector2D, center: CGPoint) -> CGPoint {
        // Map meter coordinates into screen space
        return CGPoint(
            x: center.x + CGFloat(vec.x) * scale,
            y: center.y - CGFloat(vec.y) * scale // Invert Y for screen coordinates
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
        
        context.stroke(gridPath, with: .color(Color.white.opacity(0.08)), lineWidth: 0.8)
    }
    
    private func drawWalls(context: GraphicsContext, center: CGPoint) {
        for wall in floorPlan.walls {
            let p1 = toScreenPoint(vec: wall.start, center: center)
            let p2 = toScreenPoint(vec: wall.end, center: center)
            
            // Draw wall core line
            var wallPath = Path()
            wallPath.move(to: p1)
            wallPath.addLine(to: p2)
            
            let wallColor = (wall.wallType == .exterior) ? Color.white : Color.yellow
            context.stroke(wallPath, with: .color(wallColor), style: StrokeStyle(lineWidth: 3.5, lineCap: .square))
            
            // Draw openings (doors / windows)
            for opening in wall.openings {
                let coords = wall.worldCoordinates(for: opening)
                let opP1 = toScreenPoint(vec: coords.start, center: center)
                let opP2 = toScreenPoint(vec: coords.end, center: center)
                
                var opPath = Path()
                opPath.move(to: opP1)
                opPath.addLine(to: opP2)
                
                let opColor = (opening.type == .door) ? Color.cyan : Color.green
                context.stroke(opPath, with: .color(opColor), lineWidth: 4.5)
            }
        }
    }
    
    private func drawDimensions(context: GraphicsContext, center: CGPoint) {
        for wall in floorPlan.walls where wall.length >= 0.4 {
            let mid = wall.midpoint + (wall.normal * 0.22)
            let screenMid = toScreenPoint(vec: mid, center: center)
            
            let dimString = "\(String(format: "%.2f", wall.length))m"
            let text = Text(dimString)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            context.draw(context.resolve(text), at: screenMid, anchor: .center)
        }
    }
    
    private func drawUserPosition(context: GraphicsContext, center: CGPoint) {
        let userPt = toScreenPoint(vec: userPosition, center: center)
        
        // 1. Heading Field of View Cone
        var conePath = Path()
        conePath.move(to: userPt)
        let headingRad = -userHeadingDeg * (.pi / 180.0) + (.pi / 2.0)
        let coneSpread: Double = .pi / 4.0 // 45 degree FOV
        let coneLengthPx: CGFloat = 30.0
        
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
        
        context.fill(conePath, with: .color(Color.cyan.opacity(0.25)))
        
        // 2. User Center Dot
        let dotRect = CGRect(x: userPt.x - 5, y: userPt.y - 5, width: 10, height: 10)
        context.fill(Path(ellipseIn: dotRect), with: .color(.cyan))
        context.stroke(Path(ellipseIn: dotRect), with: .color(.white), lineWidth: 1.5)
    }
}
