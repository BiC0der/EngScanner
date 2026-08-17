//
//  DXFDocument.swift
//  EngScanner
//
//  Pure Swift AutoCAD DXF (Drawing Exchange Format) Generator.
//  Conforms to AutoCAD AC1027 (R2013) / AC1009 ASCII specifications.
//  All coordinates, dimensions, and text annotations are output in METERS (m).
//

import Foundation

public final class DXFDocument {
    
    public struct LayerDefinition {
        public let name: String
        public let colorACI: Int // AutoCAD Color Index (1=Red, 2=Yellow, 3=Green, 4=Cyan, 5=Blue, 6=Magenta, 7=White/Black, 8=Gray)
        public let lineType: String
        public let lineWeight: Int // In 1/100 mm (e.g. 50 = 0.50mm, 35 = 0.35mm, 25 = 0.25mm)
        
        public init(name: String, colorACI: Int, lineType: String = "CONTINUOUS", lineWeight: Int = 35) {
            self.name = name
            self.colorACI = colorACI
            self.lineType = lineType
            self.lineWeight = lineWeight
        }
    }
    
    private var buffer: String = ""
    private var handleCounter: Int = 0x20
    
    // Standard architectural CAD layers
    public let defaultLayers: [LayerDefinition] = [
        LayerDefinition(name: "0", colorACI: 7, lineWeight: 25),
        LayerDefinition(name: "WALLS_EXTERIOR", colorACI: 7, lineWeight: 50),
        LayerDefinition(name: "WALLS_INTERIOR", colorACI: 2, lineWeight: 35),
        LayerDefinition(name: "WALLS_PARTITION", colorACI: 8, lineWeight: 25),
        LayerDefinition(name: "DOORS", colorACI: 4, lineWeight: 25),
        LayerDefinition(name: "WINDOWS", colorACI: 3, lineWeight: 25),
        LayerDefinition(name: "OPENINGS", colorACI: 6, lineWeight: 25),
        LayerDefinition(name: "DIMENSIONS", colorACI: 1, lineWeight: 18),
        LayerDefinition(name: "GRID_1M", colorACI: 8, lineType: "DOT", lineWeight: 9),
        LayerDefinition(name: "TEXT_METADATA", colorACI: 7, lineWeight: 25)
    ]
    
    public init() {}
    
    private func nextHandle() -> String {
        let handle = String(format: "%X", handleCounter)
        handleCounter += 1
        return handle
    }
    
    private func appendPair(_ code: Int, _ value: String) {
        buffer.append("\(code)\r\n\(value)\r\n")
    }
    
    private func appendPair(_ code: Int, _ value: Double) {
        buffer.append("\(code)\r\n\(String(format: "%.4f", value))\r\n")
    }
    
    private func appendPair(_ code: Int, _ value: Int) {
        buffer.append("\(code)\r\n\(value)\r\n")
    }
    
    // MARK: - DXF Generation Pipeline
    
    /// Generates standard ASCII DXF content from a StructuralFloorPlan model
    public func generateDXF(from plan: StructuralFloorPlan) -> String {
        buffer = ""
        handleCounter = 0x20
        
        writeHeader(plan: plan)
        writeClasses()
        writeTables()
        writeBlocks()
        writeEntities(plan: plan)
        writeObjects()
        writeEOF()
        
        return buffer
    }
    
    // MARK: - Section 1: HEADER
    
    private func writeHeader(plan: StructuralFloorPlan) {
        appendPair(0, "SECTION")
        appendPair(2, "HEADER")
        
        // AutoCAD Version AC1027 (AutoCAD 2013/2014/2015/2016/2017)
        appendPair(9, "$ACADVER")
        appendPair(1, "AC1027")
        
        // Measurement System: 1 = Metric
        appendPair(9, "$MEASUREMENT")
        appendPair(70, 1)
        
        // Insertion Units: 6 = Meters (AutoCAD standard: 0=Unspecified, 1=Inches, 4=Millimeters, 6=Meters)
        appendPair(9, "$INSUNITS")
        appendPair(70, 6)
        
        // Linear unit format: 2 = Decimal
        appendPair(9, "$LUNITS")
        appendPair(70, 2)
        
        // Linear unit precision: 4 decimals (e.g. 0.0001 m = 0.1 mm)
        appendPair(9, "$LUPREC")
        appendPair(70, 4)
        
        // Drawing limits (extents of scanned space in meters)
        let bounds = plan.bounds
        appendPair(9, "$EXTMIN")
        appendPair(10, bounds.minX - 1.0)
        appendPair(20, bounds.minY - 1.0)
        appendPair(30, 0.0)
        
        appendPair(9, "$EXTMAX")
        appendPair(10, bounds.maxX + 1.0)
        appendPair(20, bounds.maxY + 1.0)
        appendPair(30, plan.ceilingHeight)
        
        appendPair(0, "ENDSEC")
    }
    
    // MARK: - Section 2: CLASSES
    
    private func writeClasses() {
        appendPair(0, "SECTION")
        appendPair(2, "CLASSES")
        appendPair(0, "ENDSEC")
    }
    
    // MARK: - Section 3: TABLES
    
    private func writeTables() {
        appendPair(0, "SECTION")
        appendPair(2, "TABLES")
        
        // Linetypes table
        appendPair(0, "TABLE")
        appendPair(2, "LTYPE")
        appendPair(5, nextHandle())
        appendPair(100, "AcDbSymbolTable")
        appendPair(70, 2)
        
        // Continuous Linetype
        appendPair(0, "LTYPE")
        appendPair(5, nextHandle())
        appendPair(100, "AcDbSymbolTableRecord")
        appendPair(100, "AcDbLinetypeTableRecord")
        appendPair(2, "CONTINUOUS")
        appendPair(70, 0)
        appendPair(3, "Solid line")
        appendPair(72, 65)
        appendPair(73, 0)
        appendPair(40, 0.0)
        
        // Dot Linetype (for Grid)
        appendPair(0, "LTYPE")
        appendPair(5, nextHandle())
        appendPair(100, "AcDbSymbolTableRecord")
        appendPair(100, "AcDbLinetypeTableRecord")
        appendPair(2, "DOT")
        appendPair(70, 0)
        appendPair(3, "Dot . . . . . . . . .")
        appendPair(72, 65)
        appendPair(73, 2)
        appendPair(40, 0.25)
        appendPair(49, 0.0)
        appendPair(49, -0.25)
        
        appendPair(0, "ENDTAB")
        
        // Layers table
        appendPair(0, "TABLE")
        appendPair(2, "LAYER")
        appendPair(5, nextHandle())
        appendPair(100, "AcDbSymbolTable")
        appendPair(70, defaultLayers.count)
        
        for layer in defaultLayers {
            appendPair(0, "LAYER")
            appendPair(5, nextHandle())
            appendPair(100, "AcDbSymbolTableRecord")
            appendPair(100, "AcDbLayerTableRecord")
            appendPair(2, layer.name)
            appendPair(70, 0)
            appendPair(62, layer.colorACI)
            appendPair(6, layer.lineType)
            appendPair(370, layer.lineWeight)
        }
        
        appendPair(0, "ENDTAB")
        appendPair(0, "ENDSEC")
    }
    
    // MARK: - Section 4: BLOCKS
    
    private func writeBlocks() {
        appendPair(0, "SECTION")
        appendPair(2, "BLOCKS")
        appendPair(0, "ENDSEC")
    }
    
    // MARK: - Section 5: ENTITIES
    
    private func writeEntities(plan: StructuralFloorPlan) {
        appendPair(0, "SECTION")
        appendPair(2, "ENTITIES")
        
        // 1. Draw 1.0m Background Reference Grid
        writeGrid(plan: plan)
        
        // 2. Draw Structural Walls and Thickness Polygons
        for wall in plan.walls {
            writeWall(wall: wall)
            
            // 3. Draw Openings (Doors / Windows)
            for opening in wall.openings {
                writeOpening(wall: wall, opening: opening)
            }
            
            // 4. Draw Aligned Dimension Lines (in meters)
            writeWallDimension(wall: wall)
        }
        
        // 5. Draw Title Block / Engineering Metadata
        writeTitleBlock(plan: plan)
        
        appendPair(0, "ENDSEC")
    }
    
    // MARK: - Entity Writers
    
    private func writeGrid(plan: StructuralFloorPlan) {
        let b = plan.bounds
        let startX = floor(b.minX) - 1.0
        let endX = ceil(b.maxX) + 1.0
        let startY = floor(b.minY) - 1.0
        let endY = ceil(b.maxY) + 1.0
        
        // Vertical grid lines (every 1 meter)
        var x = startX
        while x <= endX {
            writeLine(
                p1: Vector2D(x: x, y: startY),
                p2: Vector2D(x: x, y: endY),
                layer: "GRID_1M"
            )
            x += 1.0
        }
        
        // Horizontal grid lines (every 1 meter)
        var y = startY
        while y <= endY {
            writeLine(
                p1: Vector2D(x: startX, y: y),
                p2: Vector2D(x: endX, y: y),
                layer: "GRID_1M"
            )
            y += 1.0
        }
    }
    
    private func writeWall(wall: WallSegment) {
        let layer = wall.wallType.rawValue
        
        // Primary Wall Centerline
        writeLine(p1: wall.start, p2: wall.end, layer: layer)
        
        // Wall Footprint Polygon (LWPOLYLINE with thickness extrusion)
        let corners = wall.polygonOutline()
        writeLightweightPolyline(points: corners, layer: layer, isClosed: true)
    }
    
    private func writeOpening(wall: WallSegment, opening: Opening) {
        let coords = wall.worldCoordinates(for: opening)
        let layer = opening.type.dxfLayerName
        
        // Draw opening sill/jamb line
        writeLine(p1: coords.start, p2: coords.end, layer: layer)
        
        // Door swing arc simulation for CAD
        if opening.type == .door {
            let perpendicularEnd = coords.start + (wall.normal * opening.width)
            writeLine(p1: coords.start, p2: perpendicularEnd, layer: layer)
        }
        
        // Dimension / Tag for opening
        let tagPoint = (coords.start + coords.end) * 0.5 + (wall.normal * 0.25)
        let tagText = "\(opening.type.rawValue) \(String(format: "%.2f", opening.width))m"
        writeText(position: tagPoint, text: tagText, height: 0.15, layer: layer)
    }
    
    private func writeWallDimension(wall: WallSegment) {
        guard wall.length >= 0.3 else { return }
        
        // Offset dimension line outward by 0.35m
        let offsetDistance = 0.35
        let dimOffset = wall.normal * offsetDistance
        let dimP1 = wall.start + dimOffset
        let dimP2 = wall.end + dimOffset
        
        // Draw dimension line
        writeLine(p1: dimP1, p2: dimP2, layer: "DIMENSIONS")
        
        // Draw extension witness lines
        writeLine(p1: wall.start + (wall.normal * 0.05), p2: dimP1 + (wall.normal * 0.08), layer: "DIMENSIONS")
        writeLine(p1: wall.end + (wall.normal * 0.05), p2: dimP2 + (wall.normal * 0.08), layer: "DIMENSIONS")
        
        // Dimension Text centered above line in meters
        let textPos = (dimP1 + dimP2) * 0.5 + (wall.normal * 0.08)
        let dimText = "\(String(format: "%.2f", wall.length)) m"
        let angleDeg = wall.angleDegrees
        
        writeText(position: textPos, text: dimText, height: 0.18, layer: "DIMENSIONS", rotationDeg: angleDeg)
    }
    
    private func writeTitleBlock(plan: StructuralFloorPlan) {
        let b = plan.bounds
        let basePoint = Vector2D(x: b.minX, y: b.minY - 1.2)
        
        let title = "PROJECT: \(plan.projectName.uppercased())"
        let engineer = "ENGINEER: \(plan.engineerName.uppercased())"
        let metrics = "AREA: \(String(format: "%.2f", plan.estimatedAreaSquareMeters)) m² | PERIMETER: \(String(format: "%.2f", plan.totalPerimeterMeters)) m | HEIGHT: \(String(format: "%.2f", plan.ceilingHeight)) m"
        let dateStr = "DATE: \(ISO8601DateFormatter().string(from: plan.scanDate))"
        let unitsStr = "UNITS: METERS (SI) | SCALE: 1:1"
        
        writeText(position: basePoint, text: title, height: 0.28, layer: "TEXT_METADATA")
        writeText(position: basePoint - Vector2D(x: 0, y: 0.35), text: engineer, height: 0.20, layer: "TEXT_METADATA")
        writeText(position: basePoint - Vector2D(x: 0, y: 0.65), text: metrics, height: 0.20, layer: "TEXT_METADATA")
        writeText(position: basePoint - Vector2D(x: 0, y: 0.95), text: "\(dateStr) | \(unitsStr)", height: 0.16, layer: "TEXT_METADATA")
    }
    
    // MARK: - Low-Level DXF Entity Primitives
    
    public func writeLine(p1: Vector2D, p2: Vector2D, layer: String) {
        appendPair(0, "LINE")
        appendPair(5, nextHandle())
        appendPair(100, "AcDbEntity")
        appendPair(8, layer)
        appendPair(100, "AcDbLine")
        appendPair(10, p1.x)
        appendPair(20, p1.y)
        appendPair(30, 0.0)
        appendPair(11, p2.x)
        appendPair(21, p2.y)
        appendPair(31, 0.0)
    }
    
    public func writeLightweightPolyline(points: [Vector2D], layer: String, isClosed: Bool = true) {
        guard points.count >= 2 else { return }
        appendPair(0, "LWPOLYLINE")
        appendPair(5, nextHandle())
        appendPair(100, "AcDbEntity")
        appendPair(8, layer)
        appendPair(100, "AcDbPolyline")
        appendPair(90, points.count)
        appendPair(70, isClosed ? 1 : 0)
        appendPair(43, 0.0) // Constant width
        
        for pt in points {
            appendPair(10, pt.x)
            appendPair(20, pt.y)
        }
    }
    
    public func writeText(position: Vector2D, text: String, height: Double = 0.20, layer: String, rotationDeg: Double = 0.0) {
        appendPair(0, "TEXT")
        appendPair(5, nextHandle())
        appendPair(100, "AcDbEntity")
        appendPair(8, layer)
        appendPair(100, "AcDbText")
        appendPair(10, position.x)
        appendPair(20, position.y)
        appendPair(30, 0.0)
        appendPair(40, height)
        appendPair(1, text)
        if rotationDeg != 0.0 {
            appendPair(50, rotationDeg)
        }
        appendPair(100, "AcDbText")
    }
    
    // MARK: - Section 6: OBJECTS & EOF
    
    private func writeObjects() {
        appendPair(0, "SECTION")
        appendPair(2, "OBJECTS")
        appendPair(0, "DICTIONARY")
        appendPair(5, nextHandle())
        appendPair(100, "AcDbDictionary")
        appendPair(281, 1)
        appendPair(0, "ENDSEC")
    }
    
    private func writeEOF() {
        appendPair(0, "EOF")
    }
}
