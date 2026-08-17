//
//  ScannerContainerView.swift
//  EngScanner
//
//  Primary LiDAR scanning workspace.
//  Hosts the RealityKit AR viewport, live 2D mini-map, full-width HUD metric gauges,
//  and scan controls.
//

import SwiftUI

public struct ScannerContainerView: View {
    @StateObject private var engine = ARScanEngine()
    @State private var showingExportSummary: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 1. AR RealityKit Full-Screen Background Feed (Fills screen completely)
            ARViewContainer(engine: engine)
                .edgesIgnoringSafeArea(.all)
            
            // 2. Main Scanning HUD Overlay
            VStack(spacing: 12) {
                // Top Navigation & Status Bar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        // LiDAR Hardware Status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(engine.isLiDARAvailable ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(engine.isLiDARAvailable ? "LiDAR ACTIVE (0.01m RES)" : "OPTICAL FALLBACK")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                        
                        // Confidence & Anchor Count
                        if engine.scanState == .scanning {
                            Text("ANCHORS: \(engine.trackedMeshAnchorCount) | CONF: \(Int(engine.confidenceScore * 100))%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.60))
                                .cornerRadius(6)
                        }
                    }
                    
                    Spacer()
                    
                    // Floating 2D Floor Plan Mini-Map
                    MiniMapOverlayView(
                        floorPlan: engine.currentFloorPlan,
                        userPosition: engine.userCameraPosition,
                        userHeadingDeg: engine.userCameraHeadingDeg
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Full-Width Live Metric Dimension HUD (Spans entire screen width)
                MetricLiveHUD(
                    plan: engine.currentFloorPlan,
                    wallCount: engine.currentFloorPlan.walls.count
                )
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Real-time Scanning Guidance Tip
                if engine.scanState == .scanning {
                    scanningGuidanceChip
                }
                
                // Bottom Engineering Action Bar
                ScanControlBar(engine: engine) {
                    showingExportSummary = true
                }
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showingExportSummary) {
            ExportSummaryView(
                floorPlan: Binding(
                    get: { engine.currentFloorPlan },
                    set: { _ in }
                ),
                onDismiss: {
                    showingExportSummary = false
                }
            )
        }
        .onAppear {
            engine.startScan()
        }
    }
    
    private var scanningGuidanceChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.yellow)
            Text("Slowly pan across walls and corners to lock structural boundaries.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.80))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}
