//
//  ARViewContainer.swift
//  EngScanner
//
//  SwiftUI UIViewRepresentable wrapper around RealityKit / ARSCNView
//  for real-time camera passthrough and LiDAR point cloud feedback.
//

import SwiftUI
import ARKit
import RealityKit

public struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var engine: ARScanEngine
    
    public init(engine: ARScanEngine) {
        self.engine = engine
    }
    
    public func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = engine.arSession
        
        // Configure RealityKit scene reconstruction visualization
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            arView.environment.sceneUnderstanding.options = [
                .collision,
                .physics,
                .receivesLighting
            ]
            // Show structural mesh overlay in subtle engineering wireframe
            arView.debugOptions.insert(.showSceneUnderstanding)
        }
        
        arView.renderOptions = [
            .disableFaceMesh,
            .disableGroundingShadows,
            .disableMotionBlur
        ]
        
        return arView
    }
    
    public func updateUIView(_ uiView: ARView, context: Context) {
        // Dynamic state updates if needed
    }
}
