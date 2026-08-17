//
//  EngScannerApp.swift
//  EngScanner
//
//  Professional LiDAR Structural Room Scanner & AutoCAD DXF Exporter.
//

import SwiftUI

@main
struct EngScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ScannerContainerView()
                .preferredColorScheme(.dark)
        }
    }
}
