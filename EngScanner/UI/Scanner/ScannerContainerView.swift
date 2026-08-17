//
//  ScannerContainerView.swift
//  EngScanner
//
//  Primary LiDAR scanning workspace.
//  Hosts the RealityKit AR viewport, live 2D mini-map, HUD metric gauges,
//  and scan controls.
//

import SwiftUI

public struct ScannerContainerView: View {
    @StateObject private var engine = ARScanEngine()
    @State private var showingExportSummary: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 1. AR RealityKit Background Camera Feed
            ARViewContainer(engine: engine)
                .ignoresSafeArea()
            
            // 2. Main Scanning Interface Overlay
            VStack {
                // Top Engineering HUD Bar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        // LiDAR Hardware Status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(engine.isLiDARAvailable ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(engine.isLiDARAvailable ? "LiDAR ACTIVE (0.01m RES)" : "OPTICAL FALLBACK (NON-LIDAR)")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                        
                        // Live Dimension HUD
                        MetricLiveHUD(
                            plan: engine.currentFloorPlan,
                            wallCount: engine.currentFloorPlan.walls.count
                        )
                    }
                    
                    Spacer()
                    
                    // Live 2D Floor Plan Mini-Map Overlay
                    MiniMapOverlayView(
                        floorPlan: engine.currentFloorPlan,
                        userPosition: engine.userCameraPosition,
                        userHeadingDeg: engine.userCameraHeadingDeg
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                Spacer()
                
                // Guidance Prompts
                if engine.scanState == .scanning {
                    scanningGuidanceChip
                }
                
                // Bottom Engineering Action Bar
                ScanControlBar(engine: engine) {
                    showingExportSummary = true
                }
                .padding(.bottom, 16)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.75))
        .cornerRadius(12)
        .padding(.bottom, 8)
    }
}
