//
//  ScanControlBar.swift
//  EngScanner
//
//  Floating engineering control panel for LiDAR scanning operations.
//

import SwiftUI

public struct ScanControlBar: View {
    @ObservedObject var engine: ARScanEngine
    public let onFinishScan: () -> Void
    
    public init(engine: ARScanEngine, onFinishScan: @escaping () -> Void) {
        self.engine = engine
        self.onFinishScan = onFinishScan
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            // Reset Button
            Button(action: {
                engine.resetScan()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color(white: 0.15).opacity(0.85))
                    .clipShape(Circle())
            }
            
            // Primary Action Button (Start / Pause / Resume)
            Button(action: {
                switch engine.scanState {
                case .idle:
                    engine.startScan()
                case .scanning:
                    engine.pauseScan()
                case .paused:
                    engine.resumeScan()
                case .completed:
                    engine.startScan()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: mainActionIcon)
                        .font(.system(size: 16, weight: .black))
                    Text(mainActionText)
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .frame(height: 44)
                .background(mainActionColor)
                .clipShape(Capsule())
                .shadow(color: mainActionColor.opacity(0.4), radius: 8, x: 0, y: 3)
            }
            
            // Export Button
            Button(action: {
                engine.completeScan()
                onFinishScan()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Export")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.blue.opacity(0.9))
                .clipShape(Capsule())
            }
            .disabled(engine.currentFloorPlan.walls.isEmpty && engine.scanState == .idle)
            .opacity((engine.currentFloorPlan.walls.isEmpty && engine.scanState == .idle) ? 0.35 : 1.0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(white: 0.08).opacity(0.80))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    private var mainActionIcon: String {
        switch engine.scanState {
        case .idle: return "play.fill"
        case .scanning: return "pause.fill"
        case .paused: return "play.fill"
        case .completed: return "arrow.triangle.2.circlepath"
        }
    }
    
    private var mainActionText: String {
        switch engine.scanState {
        case .idle: return "Start Scan"
        case .scanning: return "Pause"
        case .paused: return "Resume"
        case .completed: return "New Scan"
        }
    }
    
    private var mainActionColor: Color {
        switch engine.scanState {
        case .idle: return .cyan
        case .scanning: return .yellow
        case .paused: return .green
        case .completed: return .cyan
        }
    }
}
