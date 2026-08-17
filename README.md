# EngScanner 📐🏗️
### Professional LiDAR Structural Room Scanner & AutoCAD DXF Exporter for iOS

EngScanner is a high-precision mobile application designed for **structural engineers, architects, general contractors, and surveyors**. It transforms LiDAR-equipped iOS devices (iPhone Pro & iPad Pro) into real-time CAD capture stations that isolate structural boundaries (walls, floors, ceilings, doors, windows), eliminate furniture and clutter, render a dynamic 2D mini-map in meters, and export production-ready `.DXF` drawings for AutoCAD, Revit, and Rhino.

---

## ⚠️ Security Notice Regarding Credentials
> [!CAUTION]
> **Action Required:** Never commit plaintext usernames or passwords to Git repositories or share them in prompts.
> If you shared credentials, **change your GitHub password immediately** and enable 2FA.
> For automated CI/CD builds, GitHub Actions uses encrypted **Repository Secrets** and App Store Connect API keys.

---

## Table of Contents
1. [Core Features](#core-features)
2. [Technical Architecture](#technical-architecture)
3. [ARKit & LiDAR Pipeline](#arkit--lidar-pipeline)
4. [Structural Filtering & Clutter Elimination](#structural-filtering--clutter-elimination)
5. [Geometry Simplification & Orthogonal Rectification](#geometry-simplification--orthogonal-rectification)
6. [AutoCAD DXF Exporter Specification](#autocad-dxf-exporter-specification)
7. [Live 2D Mini-Map Overlay](#live-2d-mini-map-overlay)
8. [GitHub Actions CI/CD for IPA Builds](#github-actions-cicd-for-ipa-builds)
9. [Project Directory Layout](#project-directory-layout)
10. [Future Android (ARCore) Expansion](#future-android-arcore-expansion)

---

## 1. Core Features

- 🎯 **High-Precision LiDAR Slices**: Millimeter-to-centimeter precision scanning using `ARWorldTrackingConfiguration.sceneReconstruction = .meshWithClassification` and `smoothedSceneDepth`.
- 🧹 **Zero Clutter Semantic Isolation**: Filters out non-structural obstacles (sofas, tables, chairs, decorations) to capture only physical structural boundaries.
- 🗺️ **Live 2D Vector Mini-Map**: Dynamic HUD rendering of wall lines, door openings, 1.0m metric grid, and real-time user camera position with field-of-view cone.
- 📏 **Strict Metric Standards**: All dimensions computed, displayed, and exported in standard SI meters ($m$) and square meters ($m^2$).
- 📑 **AutoCAD (.DXF) Integration**: Native ASCII DXF (AC1027/R2013 standard) export with layered architecture (`WALLS_EXTERIOR`, `WALLS_INTERIOR`, `DOORS`, `WINDOWS`, `DIMENSIONS`, `GRID_1M`, `TEXT_METADATA`).
- 🚀 **Automated GitHub CI/CD**: Cloud-based macOS runner building and packaging `.IPA` files directly on push or tag release.

---

## 2. Technical Architecture

```
+-------------------------------------------------------------------------+
|                              iOS Client Layer                           |
|  +---------------------------+   +------------------------------------+ |
|  | RealityKit ARView (3D)    |   | Live 2D Mini-Map (SwiftUI Canvas)  | |
|  | Wireframe Scene Overlay   |   | User Frustum & 1m Grid             | |
|  +---------------------------+   +------------------------------------+ |
+-------------------------------------------------------------------------+
                                    ▲
                                    │ Publishes @Published State
+-------------------------------------------------------------------------+
|                            ARScanEngine Core                            |
|  - ARSession (60 Hz LiDAR Telemetry)                                    |
|  - Dual Mode: ARKit Mesh Classification OR Apple RoomPlan (iOS 16+)     |
+-------------------------------------------------------------------------+
                                    │
                                    ▼ Passes Raw Mesh & Planes
+-------------------------------------------------------------------------+
|                  Structural Extraction & Vector Pipeline                 |
|  1. StructuralFilter: Retains .wall / .floor; Rejects .seat, .table     |
|  2. Cross-Section Slicer: Horizontal cut at eye height (Y = 1.2m)       |
|  3. Ground Projection: Projects (X, Y, Z) -> 2D (X, -Z) in meters       |
|  4. RDP Simplifier: Reduces dense point paths (epsilon = 0.04m)         |
|  5. Collinear Fusion: Merges adjacent continuous wall vectors (< 5 deg)  |
|  6. Orthogonal Rectifier: Snaps 90° corners (+- 6 deg tolerance)        |
+-------------------------------------------------------------------------+
                                    │
                                    ▼ Generates
+-------------------------------------------------------------------------+
|                     StructuralFloorPlan Data Model                       |
|  - walls: [WallSegment] (start, end, thickness, height, openings)       |
|  - metrics: area (m² via Shoelace), perimeter (m), bounds (m)           |
+-------------------------------------------------------------------------+
                                    │
                                    ▼ Exports
+-------------------------------------------------------------------------+
|                       AutoCAD DXF Exporter (AC1027)                     |
|  - Header: $INSUNITS = 6 (Meters), $MEASUREMENT = 1 (Metric)            |
|  - Tables: Color-coded layers (ACI 7, ACI 2, ACI 4, ACI 3, ACI 1)       |
|  - Entities: LINE, LWPOLYLINE, DIMENSION, TEXT annotations              |
|  - Output: Share sheet (AirDrop / iCloud / CAD apps / Email)            |
+-------------------------------------------------------------------------+
```

---

## 3. ARKit & LiDAR Pipeline

### Session Configuration (`ARScanEngine.swift`)
```swift
let configuration = ARWorldTrackingConfiguration()
configuration.sceneReconstruction = .meshWithClassification
configuration.planeDetection = [.horizontal, .vertical]
configuration.environmentTexturing = .automatic

if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
    configuration.frameSemantics.insert(.smoothedSceneDepth)
}

arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
```

### Apple RoomPlan Bridge (`RoomPlanBridge.swift`)
On devices running iOS 16+ with LiDAR, EngScanner also supports direct integration with Apple's `RoomCaptureSession`, automatically isolating parametric walls, doors, windows, and openings with zero manual mesh slicing required.

---

## 4. Structural Filtering & Clutter Elimination

To eliminate non-structural clutter (furniture, boxes, appliances), EngScanner inspects the `ARMeshClassification` buffer associated with each `ARMeshAnchor`:

```swift
// Allowed Structural Classes:
// ARMeshClassification.wall
// ARMeshClassification.floor
// ARMeshClassification.ceiling

// Rejected Clutter Classes:
// ARMeshClassification.table
// ARMeshClassification.seat
// ARMeshClassification.door (handled as opening)
// ARMeshClassification.window (handled as opening)
// ARMeshClassification.none (unclassified noise)
```

The filter takes horizontal planar cross-sections at $Y = 1.2\text{ m}$ (standard eye/torso height) with a $\pm 0.20\text{ m}$ tolerance, ensuring only true vertical structural boundary points are extracted.

---

## 5. Geometry Simplification & Orthogonal Rectification

1. **Ramer-Douglas-Peucker (RDP)**: Simplifies noisy point clouds into sparse line segments with an $\varepsilon = 0.04\text{ m}$ ($4\text{ cm}$) tolerance:
   $$d = \frac{|(y_2 - y_1)x_0 - (x_2 - x_1)y_0 + x_2y_1 - y_2x_1|}{\sqrt{(y_2 - y_1)^2 + (x_2 - x_1)^2}}$$

2. **Collinear Wall Merging**: Detects consecutive segments whose directional angle differs by less than $5^\circ$ ($\Delta\theta \le 0.087\text{ rad}$) and merges them into a continuous structural span.

3. **Orthogonal 90° Snapping**: Commercial and residential walls are predominantly perpendicular. Walls within $90^\circ \pm 6^\circ$ are rectified to true cardinal alignments.

4. **Area Calculation (Shoelace Algorithm)**:
   $$A = \frac{1}{2} \left| \sum_{i=0}^{n-1} (x_i y_{i+1} - x_{i+1} y_i) \right| \quad (\text{in } \text{m}^2)$$

---

## 6. AutoCAD DXF Exporter Specification

The DXF engine generates standard ASCII AutoCAD DXF files conforming to **AutoCAD 2013 / AC1027**:

### Metric Header
- `$MEASUREMENT`: `1` (Metric)
- `$INSUNITS`: `6` (Meters)
- `$LUNITS`: `2` (Decimal)
- `$LUPREC`: `4` (4 Decimal places: $0.0001\text{ m} = 0.1\text{ mm}$)

### Layer Structure & ACI Colors
| Layer Name | AutoCAD Color Index (ACI) | Line Weight | Description |
|---|---|---|---|
| `WALLS_EXTERIOR` | 7 (White / Black) | 0.50 mm | Exterior perimeter load-bearing walls |
| `WALLS_INTERIOR` | 2 (Yellow) | 0.35 mm | Interior partition walls |
| `DOORS` | 4 (Cyan) | 0.25 mm | Door openings and swing arcs |
| `WINDOWS` | 3 (Green) | 0.25 mm | Window sill outlines |
| `DIMENSIONS` | 1 (Red) | 0.18 mm | Linear dimension lines with meter text |
| `GRID_1M` | 8 (Gray - DOT) | 0.09 mm | 1.0m background reference grid |
| `TEXT_METADATA` | 7 (White / Black) | 0.25 mm | Project title, date, area ($m^2$), engineer |

---

## 7. Live 2D Mini-Map Overlay

The `MiniMapOverlayView` is rendered via high-performance SwiftUI Canvas:
- **1-Meter Grid**: Real-time reference lines scaling dynamically with user pinch-to-zoom.
- **Camera Frustum**: Live position marker with directional FOV cone tracking camera yaw ($[0^\circ, 360^\circ)$).
- **Dimension Callouts**: Real-time length labels ($3.45\text{ m}$) drawn along wall vectors.
- **Interactive Gestures**: Double-tap to expand full-screen; pinch to zoom ($15\text{ px/m}$ to $80\text{ px/m}$).

---

## 8. GitHub Actions CI/CD for IPA Builds

The repository includes a ready-to-use GitHub Actions workflow at [`.github/workflows/build-ios.yml`](file:///.github/workflows/build-ios.yml).

### Workflow Triggers
- Automatic build on `push` to `main` or `release/*`.
- Automatic release with `.ipa` attachment on Git tag creation (`git tag v1.0.0 && git push --tags`).
- Manual trigger via GitHub UI (`workflow_dispatch`) with selectable export method (`development`, `ad-hoc`, `enterprise`, `app-store`).

### Required GitHub Secrets (For Signed Builds)
Navigate to **GitHub Repository -> Settings -> Secrets and variables -> Actions** and add:
- `BUILD_CERTIFICATE_BASE64`: Base64-encoded `.p12` distribution certificate.
- `P12_PASSWORD`: Password for the `.p12` certificate.
- `BUILD_PROVISION_PROFILE_BASE64`: Base64-encoded `.mobileprovision` file.
- `KEYCHAIN_PASSWORD`: Any secure string for temporary runner keychain encryption.

*(Note: If signing secrets are omitted, the workflow automatically builds an unsigned development archive and packages the `.ipa` container for inspection).*

---

## 9. Project Directory Layout

```
EngScanner/
├── .github/
│   └── workflows/
│       └── build-ios.yml            # GitHub Actions CI/CD Pipeline
├── Fastlane/
│   ├── Fastfile                    # Fastlane automation recipes
│   └── Appfile                     # App identifier configuration
├── EngScanner/
│   ├── App/
│   │   ├── EngScannerApp.swift      # SwiftUI App lifecycle entry point
│   │   └── Info.plist              # Permissions (Camera, LiDAR) & DXF UTIs
│   ├── Core/
│   │   ├── Geometry/
│   │   │   ├── Vector2D.swift      # 2D metric vector math library
│   │   │   ├── WallSegment.swift   # Structural wall data model
│   │   │   ├── Opening.swift       # Doors and windows on structural walls
│   │   │   └── StructuralFloorPlan.swift # Complete room geometry & Shoelace area
│   │   ├── Pipeline/
│   │   │   ├── StructuralFilter.swift # Semantic mesh & cross-section filter
│   │   │   └── VectorSimplifier.swift # RDP, collinear merge, orthogonal snap
│   │   ├── AR/
│   │   │   ├── ARScanEngine.swift  # ARKit LiDAR session & telemetry delegate
│   │   │   └── RoomPlanBridge.swift# Apple RoomPlan iOS 16+ integration
│   │   └── CAD/
│   │       ├── DXFDocument.swift   # Pure-Swift AutoCAD DXF generator (AC1027)
│   │       └── DXFExporter.swift   # File exporter & iOS Share Sheet handler
│   └── UI/
│       ├── Common/
│       │   ├── MetricDimensionLabel.swift # Metric badges & HUD meters gauge
│       │   └── ScanControlBar.swift      # Floating scan action bar
│       ├── Scanner/
│       │   ├── ARViewContainer.swift     # RealityKit camera viewport
│       │   ├── MiniMapOverlayView.swift  # Live 2D Canvas mini-map with 1m grid
│       │   └── ScannerContainerView.swift# Main scanning screen
│       └── Export/
│           └── ExportSummaryView.swift   # CAD floor plan preview & DXF export
└── README.md
```

---

## 10. Future Android (ARCore) Expansion

All core geometric models (`Vector2D`, `WallSegment`, `StructuralFloorPlan`, `VectorSimplifier`, and `DXFDocument`) are written in pure platform-agnostic Swift / Kotlin-translatable computational geometry.

When expanding to Android:
1. Replace `ARScanEngine` with **ARCore Depth API** (`Frame.acquireDepthImage16Bits()` / `DepthPoint`).
2. Pass raw depth point clouds through the same `StructuralFilter` & `VectorSimplifier` algorithms.
3. Reuse the identical DXF generation engine to output `.DXF` files on Android.
