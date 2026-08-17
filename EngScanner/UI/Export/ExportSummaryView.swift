//
//  ExportSummaryView.swift
//  EngScanner
//
//  Post-scan review and AutoCAD DXF export screen.
//  Enables engineer metadata configuration, layer selection, and DXF file sharing.
//

import SwiftUI

public struct ExportSummaryView: View {
    @Binding public var floorPlan: StructuralFloorPlan
    public let onDismiss: () -> Void
    
    @State private var projectName: String = ""
    @State private var engineerName: String = ""
    @State private var includeDimensions: Bool = true
    @State private var includeGrid: Bool = true
    @State private var isExporting: Bool = false
    @State private var exportedURL: URL?
    
    public init(floorPlan: Binding<StructuralFloorPlan>, onDismiss: @escaping () -> Void) {
        self._floorPlan = floorPlan
        self.onDismiss = onDismiss
        self._projectName = State(initialValue: floorPlan.wrappedValue.projectName)
        self._engineerName = State(initialValue: floorPlan.wrappedValue.engineerName)
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Engineering Metrics Banner
                        metricsCard
                        
                        // 2. 2D CAD Preview
                        cadPreviewCard
                        
                        // 3. Project Metadata Fields
                        metadataCard
                        
                        // 4. CAD Layer Configuration
                        layersCard
                        
                        // 5. AutoCAD DXF Export Button
                        exportButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle("AutoCAD DXF Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STRUCTURAL METRICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                MetricDimensionBadge(
                    value: floorPlan.estimatedAreaSquareMeters,
                    unit: "m²",
                    label: "Floor Area",
                    iconName: "square.dashed"
                )
                
                MetricDimensionBadge(
                    value: floorPlan.totalPerimeterMeters,
                    unit: "m",
                    label: "Perimeter",
                    iconName: "ruler"
                )
                
                MetricDimensionBadge(
                    value: floorPlan.ceilingHeight,
                    unit: "m",
                    label: "Ceiling",
                    iconName: "arrow.up.and.down"
                )
            }
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }
    
    private var cadPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("2D CAD VECTOR PREVIEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(floorPlan.walls.count) Walls Detected")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            MiniMapOverlayView(
                floorPlan: floorPlan,
                userPosition: .zero,
                userHeadingDeg: 0.0
            )
            .frame(maxWidth: .infinity)
            .frame(height: 240)
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }
    
    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROJECT METADATA")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Project / Site Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                TextField("e.g. Building A - Room 204", text: $projectName)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(white: 0.18))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Structural Engineer / Contractor")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                TextField("e.g. bic0der", text: $engineerName)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(white: 0.18))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }
    
    private var layersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUTOCAD DXF LAYERS (AC1027)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            Toggle("Include Aligned Dimensions (DIMENSIONS layer)", isOn: $includeDimensions)
                .font(.system(size: 14))
                .tint(.cyan)
            
            Toggle("Include 1.0m Reference Grid (GRID_1M layer)", isOn: $includeGrid)
                .font(.system(size: 14))
                .tint(.cyan)
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }
    
    private var exportButton: some View {
        Button(action: {
            exportDXF()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Export AutoCAD (.DXF)")
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.cyan)
            .cornerRadius(14)
            .shadow(color: Color.cyan.opacity(0.4), radius: 10, x: 0, y: 4)
        }
    }
    
    private func exportDXF() {
        var planToExport = floorPlan
        planToExport.projectName = projectName.isEmpty ? "Structural Scan" : projectName
        planToExport.engineerName = engineerName.isEmpty ? "Field Engineer" : engineerName
        
        DXFExporter.shared.presentShareSheet(for: planToExport, from: nil)
    }
}
