//
//  ScannerContainerView.swift
//  EngScanner
//
//  Primary LiDAR scanning workspace.
//  Minimalist, elegant HUD design providing 95% unobstructed AR visibility.
//

import SwiftUI

public struct ScannerContainerView: View {
    @StateObject private var engine = ARScanEngine()
    @State private var showingExportSummary: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 1. AR RealityKit Full-Screen Background Feed (100% full screen)
            ARViewContainer(engine: engine)
                .edgesIgnoringSafeArea(.all)
            
            // 2. Minimalist Scanning HUD Overlay
            VStack {
                // Top Header Row
                HStack(alignment: .top) {
                    // Left: Compact Metric Island
                    CompactMetricIsland(
                        plan: engine.currentFloorPlan,
                        wallCount: engine.currentFloorPlan.walls.count
                    )
                    
                    Spacer()
                    
                    // Right: Sleek Floating Mini-Map Radar
                    MiniMapOverlayView(
                        floorPlan: engine.currentFloorPlan,
                        userPosition: engine.userCameraPosition,
                        userHeadingDeg: engine.userCameraHeadingDeg
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                Spacer()
                
                // Bottom Floating Controls
                ScanControlBar(engine: engine) {
                    showingExportSummary = true
                }
                .padding(.bottom, 24)
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
}
