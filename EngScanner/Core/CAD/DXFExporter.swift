//
//  DXFExporter.swift
//  EngScanner
//
//  Handles file system persistence and sharing for exported .DXF drawings.
//

import Foundation
import UIKit

public final class DXFExporter {
    
    public static let shared = DXFExporter()
    
    private let generator = DXFDocument()
    
    private init() {}
    
    /// Exports the given floor plan as an AutoCAD DXF file and returns the local file URL
    public func exportToURL(plan: StructuralFloorPlan) throws -> URL {
        let dxfString = generator.generateDXF(from: plan)
        
        let sanitizedProjectName = plan.projectName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        let dateString = ISO8601DateFormatter().string(from: plan.scanDate)
            .replacingOccurrences(of: ":", with: "-")
        
        let fileName = "\(sanitizedProjectName)_\(dateString).dxf"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        guard let data = dxfString.data(using: .utf8) else {
            throw NSError(domain: "DXFExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode DXF file as UTF-8"])
        }
        
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
    
    /// Presents the iOS share sheet for the exported DXF file (AirDrop, Files, Mail, AutoCAD app)
    @MainActor
    public func presentShareSheet(for plan: StructuralFloorPlan, from sourceView: UIView?) {
        do {
            let fileURL = try exportToURL(plan: plan)
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            // iPad popover anchor configuration
            if let popover = activityVC.popoverPresentationController {
                if let source = sourceView {
                    popover.sourceView = source
                    popover.sourceRect = source.bounds
                } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let rootVC = windowScene.windows.first?.rootViewController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
            }
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                return
            }
            
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
            
        } catch {
            print("[DXFExporter] Error exporting DXF file: \(error.localizedDescription)")
        }
    }
}
