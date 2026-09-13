import SwiftUI

// MARK: - Beckify Flat Glyph System (app-only)
//
// Solid monochrome Canvas pictograms for the Field EE Toolbox — no image
// assets, no SF Symbols in wells, no Meshy/3D, no gradient strokes.
// Each `ToolID` maps 1:1 to a `GlyphKind`. Design grid is 24×24 with a 2pt
// margin (10% canvas inset). One filled silhouette language; even-odd holes
// cut slots and counters. Max three visual objects per mark.
// SF Symbols stay on chrome (favorites, nav) only.

/// Solid pictogram for one toolbox tool. Drawn as vector fills so it stays
/// crisp at any size, follows the theme, and ships no image assets.
///
/// Each `ToolID` maps 1:1 to a distinct `GlyphKind`. When a category is known
/// the fill is that shelf’s solid primary — never a gradient.
struct ToolGlyph: View {
    let kind: GlyphKind
    var size: CGFloat = 44
    var selected: Bool = false
    var toolID: ToolID? = nil
    /// When the caller already resolved the shelf (e.g. `IconWell`), pass it
    /// through to skip a second `ToolboxCatalog.category(of:)` lookup.
    var category: ToolCategory? = nil

    private var resolvedCategory: ToolCategory? {
        category ?? toolID.flatMap(ToolboxCatalog.category(of:))
    }

    private var fillColor: Color {
        if let resolvedCategory {
            return Theme.categoryColors(resolvedCategory).primary
        }
        return selected ? Theme.foreground : Theme.muted
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.10, dy: canvasSize.height * 0.10)
            context.fill(
                kind.path(in: rect),
                with: .color(fillColor),
                style: FillStyle(eoFill: true)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Soft colored well that frames a `ToolGlyph` — the graphic unit of the grid
/// and list rows (quiet category tint + solid pictogram).
struct IconWell: View {
    let toolID: ToolID
    var glyphSize: CGFloat? = nil
    var selected: Bool = true
    var circular: Bool = false

    private let baseSize: CGFloat
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 56

    init(
        toolID: ToolID,
        size: CGFloat = 56,
        glyphSize: CGFloat? = nil,
        selected: Bool = true,
        circular: Bool = false
    ) {
        self.toolID = toolID
        self.glyphSize = glyphSize
        self.selected = selected
        self.circular = circular
        self.baseSize = size
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    private var category: ToolCategory? { ToolboxCatalog.category(of: toolID) }
    private var size: CGFloat { scaledSize }
    private var resolvedGlyph: CGFloat {
        let glyphBase = glyphSize ?? baseSize * 0.66
        let scale = baseSize > 0 ? scaledSize / baseSize : 1
        return glyphBase * scale
    }
    private var corner: CGFloat {
        if circular { return size / 2 }
        return Theme.Radius.control
    }

    var body: some View {
        ZStack {
            if circular {
                Circle()
                    .fill(category.map(Theme.categoryIconGradient) ?? Theme.iconGradient)
                Circle()
                    .stroke(
                        category.map(Theme.categoryWellStroke) ?? Theme.accent.opacity(0.35),
                        lineWidth: Theme.Stroke.hairline
                    )
            } else {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(category.map(Theme.categoryIconGradient) ?? Theme.iconGradient)
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(
                        category.map(Theme.categoryWellStroke) ?? Theme.accent.opacity(0.35),
                        lineWidth: Theme.Stroke.hairline
                    )
            }
            ToolGlyph(
                kind: .forTool(toolID),
                size: resolvedGlyph,
                selected: selected,
                toolID: toolID,
                category: category
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Shelf mark for a toolbox category — same solid-fill language as tool glyphs.
struct CategoryGlyph: View {
    let category: ToolCategory
    var size: CGFloat = 28
    var selected: Bool = true

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.10, dy: canvasSize.height * 0.10)
            context.fill(
                CategoryGlyphKind(category).path(in: rect),
                with: .color(Theme.categoryColors(category).primary),
                style: FillStyle(eoFill: true)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Compact well + category glyph for section chrome.
struct CategoryWell: View {
    let category: ToolCategory
    var size: CGFloat = 28

    private var corner: CGFloat {
        Theme.Radius.control
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.categoryIconGradient(category))
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Theme.categoryWellStroke(category), lineWidth: Theme.Stroke.hairline)
            CategoryGlyph(category: category, size: size * 0.66, selected: true)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum CategoryGlyphKind {
    case field
    case power
    case controls
    case homework
    case sensors
    case reference

    init(_ category: ToolCategory) {
        switch category {
        case .field: self = .field
        case .power: self = .power
        case .controls: self = .controls
        case .homework: self = .homework
        case .sensors: self = .sensors
        case .reference: self = .reference
        }
    }

    func path(in rect: CGRect) -> Path {
        switch self {
        case .field: return Self.field(rect)
        case .power: return Glyph.bolt(rect)
        case .controls: return Self.controls(rect)
        case .homework: return Self.homework(rect)
        case .sensors: return Self.sensors(rect)
        case .reference: return Self.reference(rect)
        }
    }

    /// Posts + sagging ribbon.
    private static func field(_ r: CGRect) -> Path {
        var path = Path()
        let postW = r.width * 0.10
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.18, width: postW, height: r.height * 0.74),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.18, width: postW, height: r.height * 0.74),
            cornerSize: CGSize(width: 2, height: 2)
        )
        Glyph.ribbon(
            &path,
            from: CGPoint(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.22),
            to: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.22),
            sag: r.height * 0.42,
            thickness: r.height * 0.10
        )
        return path
    }

    /// Filled clock disk with hand holes.
    private static func controls(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.circle(&path, CGPoint(x: r.midX, y: r.midY), min(r.width, r.height) * 0.44)
        Glyph.circle(&path, CGPoint(x: r.midX, y: r.midY), min(r.width, r.height) * 0.28)
        path.addRoundedRect(
            in: CGRect(x: r.midX - r.width * 0.05, y: r.minY + r.height * 0.16, width: r.width * 0.10, height: r.height * 0.36),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func homework(_ r: CGRect) -> Path {
        var path = Path()
        let page = r.insetBy(dx: r.width * 0.16, dy: r.height * 0.10)
        path.addRoundedRect(in: page, cornerSize: CGSize(width: 3, height: 3))
        path.addRoundedRect(
            in: CGRect(x: page.minX + page.width * 0.16, y: page.minY + page.height * 0.28, width: page.width * 0.68, height: page.height * 0.10),
            cornerSize: CGSize(width: 1, height: 1)
        )
        path.addRoundedRect(
            in: CGRect(x: page.minX + page.width * 0.16, y: page.minY + page.height * 0.50, width: page.width * 0.50, height: page.height * 0.10),
            cornerSize: CGSize(width: 1, height: 1)
        )
        return path
    }

    private static func sensors(_ r: CGRect) -> Path {
        var path = Path()
        let base = CGPoint(x: r.midX, y: r.maxY - r.height * 0.14)
        Glyph.circle(&path, base, r.width * 0.08)
        Glyph.fanBand(&path, center: base, inner: r.width * 0.16, outer: r.width * 0.26, start: 210, end: 330)
        Glyph.fanBand(&path, center: base, inner: r.width * 0.34, outer: r.width * 0.44, start: 210, end: 330)
        return path
    }

    private static func reference(_ r: CGRect) -> Path {
        var path = Path()
        let book = r.insetBy(dx: r.width * 0.16, dy: r.height * 0.10)
        path.addRoundedRect(in: book, cornerSize: CGSize(width: 3, height: 3))
        path.addRect(CGRect(x: book.minX + book.width * 0.14, y: book.minY, width: book.width * 0.10, height: book.height))
        return path
    }
}

extension GlyphKind {
    /// Single mapping from toolbox identity to pictogram artwork.
    static func forTool(_ id: ToolID) -> GlyphKind {
        switch id {
        case .ohmsLaw: return .ohmsLaw
        case .power: return .power
        case .powerWizard: return .powerWizard
        case .voltageDrop: return .voltageDrop
        case .conduitFill: return .conduitFill
        case .conductorCost: return .conductorCost
        case .conductorLength: return .conductorLength
        case .transformer: return .transformer
        case .timer555: return .timer555
        case .motorFLA: return .motorFLA
        case .wireAmpacity: return .wireAmpacity
        case .voltageDivider: return .voltageDivider
        case .seriesParallel: return .seriesParallel
        case .resistorColor: return .resistorColor
        case .unitConverter: return .unitConverter
        case .frequencyWave: return .frequencyWave
        case .ledRC: return .ledRC
        case .wifiStatus: return .wifiStatus
        case .cellularStatus: return .cellularStatus
        case .bluetoothScan: return .bluetoothScan
        case .noiseMeter: return .noiseMeter
        case .bubbleLevel: return .bubbleLevel
        case .magnetometer: return .magnetometer
        case .barometer: return .barometer
        case .motionSnapshot: return .motionSnapshot
        case .fieldPosition: return .fieldPosition
        case .deviceHealth: return .deviceHealth
        case .receptacleSelector: return .receptacleSelector
        case .reactance: return .reactance
        case .powerFactor: return .powerFactor
        case .shortCircuit: return .shortCircuit
        case .circularMils: return .circularMils
        case .loadFactors: return .loadFactors
        case .signalScaling: return .signalScaling
        case .modbusAddress: return .modbusAddress
        case .plcTimer: return .plcTimer
        case .panelDirectory: return .panelDirectory
        case .motorSpeed: return .motorSpeed
        case .rfLink: return .rfLink
        case .phasorDiagram: return .phasorDiagram
        case .numberBase: return .numberBase
        case .batteryBank: return .batteryBank
        case .referenceLibrary: return .referenceLibrary
        case .magneticCircuit: return .magneticCircuit
        case .fiberLink: return .fiberLink
        case .gaussianBeam: return .gaussianBeam
        case .transientCircuit: return .transientCircuit
        case .rackCurrent: return .rackCurrent
        case .diodeIV: return .diodeIV
        case .isLoopVerifier: return .isLoopVerifier
        case .tapChanger: return .tapChanger
        case .harmonicsTHD: return .harmonicsTHD
        case .upsSizing: return .upsSizing
        case .motorNameplate: return .motorNameplate
        case .motorNameplateOCR: return .motorNameplateOCR
        case .lookCheck: return .lookCheck
        case .heaterDesign: return .heaterDesign
        case .empEmc: return .empEmc
        case .necCircuit: return .necCircuit
        case .loadWorksheet: return .loadWorksheet
        case .cableSchedule: return .cableSchedule
        case .solenoidDesign: return .solenoidDesign
        case .solarDesign: return .solarDesign
        case .analogWorkbench: return .analogWorkbench
        case .noiseSNR: return .noiseSNR
        case .linearRegulator: return .linearRegulator
        case .instrumentationAmp: return .instrumentationAmp
        case .adcDac: return .adcDac
        case .eBikeTorqueRPM: return .eBikeTorqueRPM
        case .eBikeSprocket: return .eBikeSprocket
        case .eBikeRange: return .eBikeRange
        case .eBikePackDesigner: return .eBikePackDesigner
        case .nickelStrip: return .nickelStrip
        case .controlSystems: return .controlSystems
        }
    }
}

enum GlyphKind {
    case ohmsLaw, power, powerWizard, voltageDrop, conduitFill
    case conductorCost, conductorLength, transformer, timer555, motorFLA
    case wireAmpacity, voltageDivider, seriesParallel, resistorColor, unitConverter
    case frequencyWave, ledRC, wifiStatus, cellularStatus, bluetoothScan
    case noiseMeter, bubbleLevel, magnetometer, barometer, motionSnapshot
    case fieldPosition, deviceHealth, receptacleSelector, reactance, powerFactor
    case shortCircuit, circularMils, loadFactors, signalScaling, modbusAddress
    case plcTimer, panelDirectory, motorSpeed, rfLink, phasorDiagram
    case numberBase, batteryBank, referenceLibrary, magneticCircuit, fiberLink
    case gaussianBeam, transientCircuit, rackCurrent, diodeIV, isLoopVerifier
    case tapChanger, harmonicsTHD, upsSizing, motorNameplate, motorNameplateOCR
    case lookCheck, heaterDesign, empEmc, necCircuit, loadWorksheet, cableSchedule
    case solenoidDesign, solarDesign, analogWorkbench, noiseSNR, linearRegulator
    case instrumentationAmp, adcDac, eBikeTorqueRPM, eBikeSprocket, eBikeRange
    case eBikePackDesigner, nickelStrip, controlSystems

    func path(in rect: CGRect) -> Path {
        switch self {
        case .voltageDrop: return Self.voltageDrop(rect)
        case .wireAmpacity: return Self.wireAmpacity(rect)
        case .motorFLA: return Self.motorFLA(rect)
        case .receptacleSelector: return Self.receptacleSelector(rect)
        case .wifiStatus: return Self.wifiStatus(rect)
        case .conduitFill: return Self.conduitFill(rect)
        case .conductorCost: return Self.conductorCost(rect)
        case .conductorLength: return Self.conductorLength(rect)
        case .shortCircuit: return Self.shortCircuit(rect)
        case .circularMils: return Self.circularMils(rect)
        case .loadFactors: return Self.loadFactors(rect)
        case .necCircuit: return Self.necCircuit(rect)
        case .isLoopVerifier: return Self.isLoopVerifier(rect)
        case .motorSpeed: return Self.motorSpeed(rect)
        case .motorNameplate: return Self.motorNameplate(rect)
        case .motorNameplateOCR: return Self.motorNameplateOCR(rect)
        case .lookCheck: return Self.lookCheck(rect)
        case .power: return Glyph.bolt(rect)
        case .powerWizard: return Self.powerWizard(rect)
        case .transformer: return Self.transformer(rect)
        case .tapChanger: return Self.tapChanger(rect)
        case .powerFactor: return Self.powerFactor(rect)
        case .harmonicsTHD: return Self.harmonicsTHD(rect)
        case .batteryBank: return Self.batteryBank(rect)
        case .solarDesign: return Self.solarDesign(rect)
        case .upsSizing: return Self.upsSizing(rect)
        case .signalScaling: return Self.signalScaling(rect)
        case .modbusAddress: return Self.modbusAddress(rect)
        case .plcTimer: return Self.plcTimer(rect)
        case .rackCurrent: return Self.rackCurrent(rect)
        case .controlSystems: return Self.controlSystems(rect)
        case .cellularStatus: return Self.cellularStatus(rect)
        case .bluetoothScan: return Self.bluetoothScan(rect)
        case .noiseMeter: return Self.noiseMeter(rect)
        case .bubbleLevel: return Self.bubbleLevel(rect)
        case .magnetometer: return Self.magnetometer(rect)
        case .barometer: return Self.barometer(rect)
        case .motionSnapshot: return Self.motionSnapshot(rect)
        case .fieldPosition: return Self.fieldPosition(rect)
        case .deviceHealth: return Self.deviceHealth(rect)
        case .ohmsLaw: return Self.ohmsLaw(rect)
        case .voltageDivider: return Self.voltageDivider(rect)
        case .seriesParallel: return Self.seriesParallel(rect)
        case .resistorColor: return Self.resistorColor(rect)
        case .unitConverter: return Self.unitConverter(rect)
        case .frequencyWave: return Self.frequencyWave(rect)
        case .ledRC: return Self.ledRC(rect)
        case .timer555: return Self.timer555(rect)
        case .reactance: return Self.reactance(rect)
        case .phasorDiagram: return Self.phasorDiagram(rect)
        case .numberBase: return Self.numberBase(rect)
        case .magneticCircuit: return Self.magneticCircuit(rect)
        case .fiberLink: return Self.fiberLink(rect)
        case .gaussianBeam: return Self.gaussianBeam(rect)
        case .transientCircuit: return Self.transientCircuit(rect)
        case .diodeIV: return Self.diodeIV(rect)
        case .rfLink: return Self.rfLink(rect)
        case .heaterDesign: return Self.heaterDesign(rect)
        case .solenoidDesign: return Self.solenoidDesign(rect)
        case .empEmc: return Self.empEmc(rect)
        case .eBikeTorqueRPM: return Self.eBikeTorqueRPM(rect)
        case .eBikeSprocket: return Self.eBikeSprocket(rect)
        case .eBikeRange: return Self.eBikeRange(rect)
        case .eBikePackDesigner: return Self.eBikePackDesigner(rect)
        case .nickelStrip: return Self.nickelStrip(rect)
        case .analogWorkbench: return Self.analogWorkbench(rect)
        case .noiseSNR: return Self.noiseSNR(rect)
        case .linearRegulator: return Self.linearRegulator(rect)
        case .instrumentationAmp: return Self.instrumentationAmp(rect)
        case .adcDac: return Self.adcDac(rect)
        case .referenceLibrary: return Self.referenceLibrary(rect)
        case .panelDirectory: return Self.panelDirectory(rect)
        case .loadWorksheet: return Self.loadWorksheet(rect)
        case .cableSchedule: return Self.cableSchedule(rect)
        }
    }

    // MARK: - Field Quick

    /// Two posts + one sagging conductor ribbon.
    private static func voltageDrop(_ r: CGRect) -> Path {
        var path = Path()
        let postW = r.width * 0.11
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.16, width: postW, height: r.height * 0.76),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: r.maxX - r.width * 0.21, y: r.minY + r.height * 0.16, width: postW, height: r.height * 0.76),
            cornerSize: CGSize(width: 2, height: 2)
        )
        Glyph.ribbon(
            &path,
            from: CGPoint(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.22),
            to: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.22),
            sag: r.height * 0.48,
            thickness: r.height * 0.12
        )
        return path
    }

    /// Short sleeve with three conductor holes.
    private static func wireAmpacity(_ r: CGRect) -> Path {
        var path = Path()
        let sleeve = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.22,
            width: r.width * 0.84, height: r.height * 0.56
        )
        path.addRoundedRect(in: sleeve, cornerSize: CGSize(width: sleeve.height * 0.36, height: sleeve.height * 0.36))
        for index in 0..<3 {
            let y = sleeve.minY + sleeve.height * (0.26 + 0.24 * CGFloat(index))
            path.addRoundedRect(
                in: CGRect(x: sleeve.minX + sleeve.width * 0.10, y: y - sleeve.height * 0.07, width: sleeve.width * 0.80, height: sleeve.height * 0.14),
                cornerSize: CGSize(width: 2, height: 2)
            )
        }
        return path
    }

    /// Motor can + shaft + end cap.
    private static func motorFLA(_ r: CGRect) -> Path {
        var path = Path()
        let can = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.22,
            width: r.width * 0.58, height: r.height * 0.50
        )
        path.addRoundedRect(in: can, cornerSize: CGSize(width: can.height * 0.18, height: can.height * 0.18))
        path.addEllipse(in: CGRect(
            x: can.minX - r.width * 0.05, y: can.minY + can.height * 0.10,
            width: r.width * 0.14, height: can.height * 0.80
        ))
        path.addRoundedRect(
            in: CGRect(x: can.maxX, y: can.midY - r.height * 0.07, width: r.width * 0.24, height: r.height * 0.14),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return path
    }

    /// Duplex face with slot and ground holes.
    private static func receptacleSelector(_ r: CGRect) -> Path {
        var path = Path()
        let face = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.06)
        path.addRoundedRect(in: face, cornerSize: CGSize(width: 6, height: 6))
        let slot = CGSize(width: face.width * 0.10, height: face.height * 0.28)
        path.addRoundedRect(
            in: CGRect(x: face.midX - face.width * 0.22 - slot.width / 2, y: face.minY + face.height * 0.26, width: slot.width, height: slot.height),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        path.addRoundedRect(
            in: CGRect(x: face.midX + face.width * 0.22 - slot.width / 2, y: face.minY + face.height * 0.26, width: slot.width, height: slot.height),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        Glyph.circle(&path, CGPoint(x: face.midX, y: face.maxY - face.height * 0.22), face.width * 0.08)
        return path
    }

    /// AP slab + two filled fan bands.
    private static func wifiStatus(_ r: CGRect) -> Path {
        var path = Path()
        let slab = CGRect(
            x: r.minX + r.width * 0.14, y: r.maxY - r.height * 0.26,
            width: r.width * 0.72, height: r.height * 0.20
        )
        path.addRoundedRect(in: slab, cornerSize: CGSize(width: slab.height / 2, height: slab.height / 2))
        let origin = CGPoint(x: r.midX, y: slab.minY + r.height * 0.02)
        Glyph.fanBand(&path, center: origin, inner: r.width * 0.16, outer: r.width * 0.26, start: 210, end: 330)
        Glyph.fanBand(&path, center: origin, inner: r.width * 0.34, outer: r.width * 0.46, start: 210, end: 330)
        return path
    }

    /// Ring + one conductor + fill-chord bite.
    private static func conduitFill(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) * 0.46
        Glyph.circle(&path, c, outer)
        Glyph.circle(&path, c, outer * 0.72)
        Glyph.circle(&path, CGPoint(x: c.x, y: c.y + outer * 0.22), outer * 0.22)
        return path
    }

    // MARK: - Field · Jobsite

    /// Spool disk + stand + tag.
    private static func conductorCost(_ r: CGRect) -> Path {
        var path = Path()
        let hub = CGPoint(x: r.minX + r.width * 0.36, y: r.midY - r.height * 0.06)
        Glyph.circle(&path, hub, r.width * 0.28)
        Glyph.circle(&path, hub, r.width * 0.12)
        path.addPolygon([
            CGPoint(x: hub.x - r.width * 0.18, y: r.maxY - r.height * 0.06),
            CGPoint(x: hub.x, y: hub.y + r.width * 0.20),
            CGPoint(x: hub.x + r.width * 0.18, y: r.maxY - r.height * 0.06),
        ])
        path.addRoundedRect(
            in: CGRect(x: r.maxX - r.width * 0.36, y: r.minY + r.height * 0.10, width: r.width * 0.30, height: r.height * 0.26),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return path
    }

    /// Case + curved tape ribbon.
    private static func conductorLength(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.26, width: r.width * 0.42, height: r.height * 0.48),
            cornerSize: CGSize(width: 4, height: 4)
        )
        Glyph.ribbon(
            &path,
            from: CGPoint(x: r.minX + r.width * 0.46, y: r.midY),
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.18),
            sag: -r.height * 0.28,
            thickness: r.height * 0.14
        )
        return path
    }

    /// Breaker block + handle.
    private static func shortCircuit(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.24, y: r.minY + r.height * 0.40, width: r.width * 0.52, height: r.height * 0.48),
            cornerSize: CGSize(width: 4, height: 4)
        )
        path.addRoundedRect(
            in: CGRect(x: r.midX - r.width * 0.07, y: r.minY + r.height * 0.08, width: r.width * 0.14, height: r.height * 0.36),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return path
    }

    /// Two concentric circles (ring).
    private static func circularMils(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) * 0.44
        Glyph.circle(&path, c, outer)
        Glyph.circle(&path, c, outer * 0.52)
        return path
    }

    /// Three ascending bars.
    private static func loadFactors(_ r: CGRect) -> Path {
        var path = Path()
        let heights: [CGFloat] = [0.38, 0.58, 0.80]
        for (index, height) in heights.enumerated() {
            path.addRoundedRect(
                in: CGRect(
                    x: r.minX + r.width * (0.14 + 0.28 * CGFloat(index)),
                    y: r.maxY - r.height * height,
                    width: r.width * 0.22,
                    height: r.height * height
                ),
                cornerSize: CGSize(width: 3, height: 3)
            )
        }
        return path
    }

    /// Panelboard with three slot holes.
    private static func necCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let panel = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.06)
        path.addRoundedRect(in: panel, cornerSize: CGSize(width: 4, height: 4))
        for index in 0..<3 {
            let y = panel.minY + panel.height * (0.24 + 0.22 * CGFloat(index))
            path.addRoundedRect(
                in: CGRect(x: panel.minX + panel.width * 0.16, y: y, width: panel.width * 0.68, height: panel.height * 0.10),
                cornerSize: CGSize(width: 2, height: 2)
            )
        }
        return path
    }

    /// Rounded loop with a top bite + probe.
    private static func isLoopVerifier(_ r: CGRect) -> Path {
        var path = Path()
        let loop = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.16)
        path.addRoundedRect(in: loop, cornerSize: CGSize(width: 8, height: 8))
        path.addRoundedRect(
            in: loop.insetBy(dx: r.width * 0.12, dy: r.height * 0.14),
            cornerSize: CGSize(width: 5, height: 5)
        )
        path.addRoundedRect(
            in: CGRect(x: r.midX - r.width * 0.05, y: r.minY, width: r.width * 0.10, height: r.height * 0.28),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    /// Motor can + curved arrow head.
    private static func motorSpeed(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.28, width: r.width * 0.46, height: r.height * 0.36),
            cornerSize: CGSize(width: 4, height: 4)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.50, y: r.midY - r.height * 0.06, width: r.width * 0.18, height: r.height * 0.12),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addPolygon([
            CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.18),
            CGPoint(x: r.maxX - r.width * 0.28, y: r.minY + r.height * 0.18),
            CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.40),
        ])
        return path
    }

    /// Plate with two data-line holes.
    private static func motorNameplate(_ r: CGRect) -> Path {
        var path = Path()
        let plate = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.18)
        path.addRoundedRect(in: plate, cornerSize: CGSize(width: 4, height: 4))
        path.addRoundedRect(
            in: CGRect(x: plate.minX + plate.width * 0.14, y: plate.minY + plate.height * 0.32, width: plate.width * 0.72, height: plate.height * 0.12),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        path.addRoundedRect(
            in: CGRect(x: plate.minX + plate.width * 0.14, y: plate.minY + plate.height * 0.56, width: plate.width * 0.52, height: plate.height * 0.12),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        return path
    }

    /// Plate + two camera L brackets.
    private static func motorNameplateOCR(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.20, y: r.minY + r.height * 0.26, width: r.width * 0.60, height: r.height * 0.48),
            cornerSize: CGSize(width: 3, height: 3)
        )
        Glyph.filledL(&path, at: CGPoint(x: r.minX, y: r.minY), size: r.width * 0.22, thickness: r.width * 0.08, flipX: false, flipY: false)
        Glyph.filledL(&path, at: CGPoint(x: r.maxX, y: r.maxY), size: r.width * 0.22, thickness: r.width * 0.08, flipX: true, flipY: true)
        return path
    }

    /// Almond eye + pupil hole.
    private static func lookCheck(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.04, y: r.midY))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.04, y: r.midY),
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.06)
        )
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.04, y: r.midY),
            control: CGPoint(x: r.midX, y: r.maxY - r.height * 0.06)
        )
        path.closeSubpath()
        Glyph.circle(&path, CGPoint(x: r.midX, y: r.midY), r.width * 0.14)
        return path
    }

    // MARK: - Field · Power

    private static func powerWizard(_ r: CGRect) -> Path {
        var path = Glyph.bolt(r)
        let star = CGPoint(x: r.maxX - r.width * 0.10, y: r.minY + r.height * 0.14)
        path.addPolygon([
            CGPoint(x: star.x, y: star.y - r.height * 0.14),
            CGPoint(x: star.x + r.width * 0.05, y: star.y),
            CGPoint(x: star.x, y: star.y + r.height * 0.14),
            CGPoint(x: star.x - r.width * 0.05, y: star.y),
        ])
        return path
    }

    private static func transformer(_ r: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.10, width: r.width * 0.32, height: r.height * 0.80))
        path.addEllipse(in: CGRect(x: r.maxX - r.width * 0.38, y: r.minY + r.height * 0.10, width: r.width * 0.32, height: r.height * 0.80))
        path.addRoundedRect(
            in: CGRect(x: r.midX - r.width * 0.06, y: r.minY + r.height * 0.08, width: r.width * 0.12, height: r.height * 0.84),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func tapChanger(_ r: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: r.minX + r.width * 0.04, y: r.minY + r.height * 0.14, width: r.width * 0.30, height: r.height * 0.72))
        path.addEllipse(in: CGRect(x: r.minX + r.width * 0.36, y: r.minY + r.height * 0.14, width: r.width * 0.30, height: r.height * 0.72))
        path.addPolygon([
            CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.18),
            CGPoint(x: r.maxX - r.width * 0.28, y: r.minY + r.height * 0.32),
            CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.48),
        ])
        return path
    }

    private static func powerFactor(_ r: CGRect) -> Path {
        var path = Path()
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.10, y: r.maxY - r.height * 0.08),
            CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.08),
            CGPoint(x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.10),
        ])
        return path
    }

    private static func harmonicsTHD(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.sineRibbon(&path, in: r, y: r.midY, amplitude: r.height * 0.28, thickness: r.height * 0.16, cycles: 1)
        Glyph.sineRibbon(&path, in: r, y: r.midY, amplitude: r.height * 0.12, thickness: r.height * 0.06, cycles: 3)
        return path
    }

    private static func batteryBank(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.24, width: r.width * 0.74, height: r.height * 0.52)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 4, height: 4))
        path.addRoundedRect(
            in: CGRect(x: body.maxX, y: body.midY - r.height * 0.10, width: r.width * 0.12, height: r.height * 0.20),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRect(CGRect(x: body.minX + body.width * 0.30, y: body.minY + 4, width: body.width * 0.08, height: body.height - 8))
        path.addRect(CGRect(x: body.minX + body.width * 0.62, y: body.minY + 4, width: body.width * 0.08, height: body.height - 8))
        return path
    }

    private static func solarDesign(_ r: CGRect) -> Path {
        var path = Path()
        let sun = CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.20)
        path.addArc(center: sun, radius: r.width * 0.18, startAngle: .degrees(200), endAngle: .degrees(20), clockwise: false)
        path.addLine(to: CGPoint(x: sun.x - r.width * 0.16, y: sun.y))
        path.closeSubpath()
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.14),
            CGPoint(x: r.minX + r.width * 0.62, y: r.maxY - r.height * 0.10),
            CGPoint(x: r.minX + r.width * 0.80, y: r.minY + r.height * 0.42),
            CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.38),
        ])
        return path
    }

    private static func upsSizing(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.34, width: r.width * 0.52, height: r.height * 0.40)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3, height: 3))
        path.addRoundedRect(
            in: CGRect(x: body.maxX, y: body.midY - r.height * 0.08, width: r.width * 0.08, height: r.height * 0.16),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        Glyph.fanBand(
            &path,
            center: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.30),
            inner: r.width * 0.16,
            outer: r.width * 0.30,
            start: 210,
            end: 330
        )
        return path
    }

    // MARK: - Field · Controls

    private static func signalScaling(_ r: CGRect) -> Path {
        var path = Path()
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.12),
            CGPoint(x: r.maxX - r.width * 0.08, y: r.midY),
            CGPoint(x: r.minX + r.width * 0.22, y: r.maxY - r.height * 0.12),
        ])
        path.addRoundedRect(in: CGRect(x: r.minX, y: r.minY + r.height * 0.26, width: r.width * 0.22, height: r.height * 0.10), cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(in: CGRect(x: r.minX, y: r.maxY - r.height * 0.36, width: r.width * 0.22, height: r.height * 0.10), cornerSize: CGSize(width: 2, height: 2))
        return path
    }

    private static func modbusAddress(_ r: CGRect) -> Path {
        var path = Path()
        let jack = CGRect(x: r.minX + r.width * 0.14, y: r.minY + r.height * 0.14, width: r.width * 0.72, height: r.height * 0.50)
        path.addRoundedRect(in: jack, cornerSize: CGSize(width: 4, height: 4))
        for index in 0..<3 {
            Glyph.circle(&path, CGPoint(x: jack.minX + jack.width * (0.25 + 0.25 * CGFloat(index)), y: jack.maxY + r.height * 0.16), r.width * 0.055)
        }
        return path
    }

    private static func plcTimer(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.44
        Glyph.circle(&path, c, rad)
        Glyph.circle(&path, c, rad * 0.62)
        path.addRoundedRect(
            in: CGRect(x: c.x - r.width * 0.055, y: c.y - rad * 0.52, width: r.width * 0.11, height: rad * 0.52),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: c.x, y: c.y - r.height * 0.06, width: rad * 0.42, height: r.height * 0.12),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func rackCurrent(_ r: CGRect) -> Path {
        var path = Path()
        let frame = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.08)
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: 4, height: 4))
        path.addRoundedRect(
            in: CGRect(x: frame.minX + frame.width * 0.16, y: frame.minY + frame.height * 0.26, width: frame.width * 0.72, height: frame.height * 0.12),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: frame.minX + frame.width * 0.16, y: frame.minY + frame.height * 0.58, width: frame.width * 0.72, height: frame.height * 0.12),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func controlSystems(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.40
        Glyph.circle(&path, c, rad)
        Glyph.circle(&path, c, rad * 0.62)
        path.addPolygon([
            CGPoint(x: c.x + rad * 0.92, y: c.y - r.height * 0.02),
            CGPoint(x: c.x + rad * 1.18, y: c.y + r.height * 0.14),
            CGPoint(x: c.x + rad * 0.70, y: c.y + r.height * 0.14),
        ])
        return path
    }

    // MARK: - Field · Instruments

    private static func cellularStatus(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.10, width: r.width * 0.40, height: r.height * 0.80),
            cornerSize: CGSize(width: 5, height: 5)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.60, y: r.maxY - r.height * 0.42, width: r.width * 0.12, height: r.height * 0.30),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.78, y: r.maxY - r.height * 0.64, width: r.width * 0.12, height: r.height * 0.52),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func bluetoothScan(_ r: CGRect) -> Path {
        var path = Path()
        path.addPolygon([
            CGPoint(x: r.midX, y: r.minY + r.height * 0.08),
            CGPoint(x: r.midX + r.width * 0.26, y: r.midY - r.height * 0.18),
            CGPoint(x: r.midX, y: r.midY),
            CGPoint(x: r.midX + r.width * 0.26, y: r.midY + r.height * 0.18),
            CGPoint(x: r.midX, y: r.maxY - r.height * 0.08),
            CGPoint(x: r.midX - r.width * 0.08, y: r.maxY - r.height * 0.20),
            CGPoint(x: r.midX + r.width * 0.06, y: r.midY + r.height * 0.10),
            CGPoint(x: r.midX - r.width * 0.16, y: r.midY),
            CGPoint(x: r.midX + r.width * 0.06, y: r.midY - r.height * 0.10),
            CGPoint(x: r.midX - r.width * 0.08, y: r.minY + r.height * 0.20),
        ])
        return path
    }

    private static func noiseMeter(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.14, width: r.width * 0.34, height: r.height * 0.50),
            cornerSize: CGSize(width: r.width * 0.17, height: r.width * 0.17)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.24, y: r.minY + r.height * 0.60, width: r.width * 0.10, height: r.height * 0.22),
            cornerSize: CGSize(width: 2, height: 2)
        )
        let origin = CGPoint(x: r.maxX - r.width * 0.26, y: r.midY - r.height * 0.08)
        Glyph.fanBand(&path, center: origin, inner: r.width * 0.10, outer: r.width * 0.20, start: -50, end: 50)
        return path
    }

    private static func bubbleLevel(_ r: CGRect) -> Path {
        var path = Path()
        let tube = CGRect(x: r.minX + r.width * 0.04, y: r.midY - r.height * 0.18, width: r.width * 0.92, height: r.height * 0.36)
        path.addRoundedRect(in: tube, cornerSize: CGSize(width: tube.height / 2, height: tube.height / 2))
        Glyph.circle(&path, CGPoint(x: r.midX + r.width * 0.16, y: r.midY), r.height * 0.11)
        return path
    }

    private static func magnetometer(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY - r.height * 0.04)
        Glyph.fanBand(&path, center: c, inner: r.width * 0.16, outer: r.width * 0.34, start: 200, end: 340)
        path.addRoundedRect(
            in: CGRect(x: c.x - r.width * 0.34, y: c.y + r.height * 0.08, width: r.width * 0.18, height: r.height * 0.36),
            cornerSize: CGSize(width: 3, height: 3)
        )
        path.addRoundedRect(
            in: CGRect(x: c.x + r.width * 0.16, y: c.y + r.height * 0.08, width: r.width * 0.18, height: r.height * 0.36),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return path
    }

    private static func barometer(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.44
        Glyph.circle(&path, c, rad)
        Glyph.circle(&path, c, rad * 0.62)
        path.addPolygon([
            c,
            CGPoint(x: c.x + r.width * 0.28, y: c.y - r.height * 0.22),
            CGPoint(x: c.x + r.width * 0.10, y: c.y),
        ])
        return path
    }

    private static func motionSnapshot(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.08, width: r.width * 0.38, height: r.height * 0.84),
            cornerSize: CGSize(width: 5, height: 5)
        )
        path.addPolygon([
            CGPoint(x: r.maxX - r.width * 0.18, y: r.minY + r.height * 0.10),
            CGPoint(x: r.maxX - r.width * 0.06, y: r.midY),
            CGPoint(x: r.maxX - r.width * 0.30, y: r.midY),
        ])
        path.addPolygon([
            CGPoint(x: r.maxX - r.width * 0.18, y: r.maxY - r.height * 0.10),
            CGPoint(x: r.maxX - r.width * 0.06, y: r.midY),
            CGPoint(x: r.maxX - r.width * 0.30, y: r.midY),
        ])
        return path
    }

    private static func fieldPosition(_ r: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: r.midX, y: r.maxY - r.height * 0.02)
        path.move(to: tip)
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.34),
            control: CGPoint(x: r.minX + r.width * 0.06, y: r.maxY - r.height * 0.28)
        )
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.34),
            control: CGPoint(x: r.midX, y: r.minY)
        )
        path.addQuadCurve(
            to: tip,
            control: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.28)
        )
        path.closeSubpath()
        Glyph.circle(&path, CGPoint(x: r.midX, y: r.minY + r.height * 0.32), r.width * 0.12)
        return path
    }

    private static func deviceHealth(_ r: CGRect) -> Path {
        var path = Path()
        let frame = r.insetBy(dx: r.width * 0.04, dy: r.height * 0.16)
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: 5, height: 5))
        let y = frame.midY
        path.move(to: CGPoint(x: frame.minX + frame.width * 0.08, y: y + 3))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.26, y: y + 3))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.36, y: y - frame.height * 0.28))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.52, y: y + frame.height * 0.32))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.64, y: y + 3))
        path.addLine(to: CGPoint(x: frame.maxX - frame.width * 0.08, y: y + 3))
        path.addLine(to: CGPoint(x: frame.maxX - frame.width * 0.08, y: y - 3))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.64, y: y - 3))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.52, y: y + frame.height * 0.22))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.36, y: y - frame.height * 0.36))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.26, y: y - 3))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.08, y: y - 3))
        path.closeSubpath()
        return path
    }

    // MARK: - Toolkit · Basics

    /// Filled Ω with a counter.
    private static func ohmsLaw(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY - r.height * 0.08)
        let outer = min(r.width, r.height) * 0.40
        Glyph.circle(&path, c, outer)
        Glyph.circle(&path, c, outer * 0.52)
        path.addRect(CGRect(x: c.x - outer * 0.55, y: c.y + outer * 0.15, width: outer * 1.10, height: outer * 0.70))
        path.addRoundedRect(
            in: CGRect(x: c.x - outer * 0.72, y: r.maxY - r.height * 0.18, width: outer * 0.50, height: r.height * 0.14),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: c.x + outer * 0.22, y: r.maxY - r.height * 0.18, width: outer * 0.50, height: r.height * 0.14),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func voltageDivider(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.midX - r.width * 0.07, y: r.minY, width: r.width * 0.14, height: r.height),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: r.midX - r.width * 0.24, y: r.minY + r.height * 0.14, width: r.width * 0.48, height: r.height * 0.20),
            cornerSize: CGSize(width: 3, height: 3)
        )
        path.addRoundedRect(
            in: CGRect(x: r.midX - r.width * 0.24, y: r.maxY - r.height * 0.34, width: r.width * 0.48, height: r.height * 0.20),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return path
    }

    private static func seriesParallel(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.04, y: r.midY - r.height * 0.12, width: r.width * 0.32, height: r.height * 0.24),
            cornerSize: CGSize(width: 3, height: 3)
        )
        path.addRoundedRect(
            in: CGRect(x: r.maxX - r.width * 0.46, y: r.minY + r.height * 0.12, width: r.width * 0.42, height: r.height * 0.22),
            cornerSize: CGSize(width: 3, height: 3)
        )
        path.addRoundedRect(
            in: CGRect(x: r.maxX - r.width * 0.46, y: r.maxY - r.height * 0.34, width: r.width * 0.42, height: r.height * 0.22),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return path
    }

    private static func resistorColor(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(x: r.minX + r.width * 0.08, y: r.midY - r.height * 0.18, width: r.width * 0.84, height: r.height * 0.36)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: body.height / 2, height: body.height / 2))
        for fraction in [0.28, 0.50, 0.72] as [CGFloat] {
            path.addRect(CGRect(x: body.minX + body.width * fraction - body.width * 0.04, y: body.minY + 3, width: body.width * 0.08, height: body.height - 6))
        }
        return path
    }

    private static func unitConverter(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX, y: r.minY + r.height * 0.20, width: r.width * 0.36, height: r.height * 0.60),
            cornerSize: CGSize(width: 4, height: 4)
        )
        path.addRoundedRect(
            in: CGRect(x: r.maxX - r.width * 0.36, y: r.minY + r.height * 0.20, width: r.width * 0.36, height: r.height * 0.60),
            cornerSize: CGSize(width: 4, height: 4)
        )
        path.addPolygon([
            CGPoint(x: r.midX - r.width * 0.08, y: r.midY - r.height * 0.10),
            CGPoint(x: r.midX + r.width * 0.10, y: r.midY),
            CGPoint(x: r.midX - r.width * 0.08, y: r.midY + r.height * 0.10),
        ])
        return path
    }

    private static func frequencyWave(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.sineRibbon(&path, in: r, y: r.midY, amplitude: r.height * 0.32, thickness: r.height * 0.18, cycles: 1)
        return path
    }

    private static func ledRC(_ r: CGRect) -> Path {
        var path = Path()
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.22),
            CGPoint(x: r.minX + r.width * 0.42, y: r.midY),
            CGPoint(x: r.minX + r.width * 0.06, y: r.maxY - r.height * 0.22),
        ])
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.20, width: r.width * 0.10, height: r.height * 0.60),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.64, y: r.minY + r.height * 0.20, width: r.width * 0.10, height: r.height * 0.60),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        return path
    }

    private static func timer555(_ r: CGRect) -> Path {
        var path = Path()
        let body = r.insetBy(dx: r.width * 0.18, dy: r.height * 0.14)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 4, height: 4))
        for index in 0..<3 {
            let y = body.minY + body.height * (0.20 + 0.30 * CGFloat(index))
            path.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.04, y: y - r.height * 0.05, width: r.width * 0.16, height: r.height * 0.10), cornerSize: CGSize(width: 2, height: 2))
            path.addRoundedRect(in: CGRect(x: r.maxX - r.width * 0.20, y: y - r.height * 0.05, width: r.width * 0.16, height: r.height * 0.10), cornerSize: CGSize(width: 2, height: 2))
        }
        return path
    }

    private static func reactance(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        let rad = r.width * 0.16
        for index in 0..<3 {
            Glyph.circle(&path, CGPoint(x: r.minX + r.width * (0.22 + 0.28 * CGFloat(index)), y: y), rad)
        }
        return path
    }

    private static func phasorDiagram(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.08, width: r.width * 0.12, height: r.height * 0.80),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.10, y: r.maxY - r.height * 0.16, width: r.width * 0.78, height: r.height * 0.12),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.16, y: r.maxY - r.height * 0.16),
            CGPoint(x: r.minX + r.width * 0.78, y: r.minY + r.height * 0.16),
            CGPoint(x: r.minX + r.width * 0.52, y: r.maxY - r.height * 0.22),
        ])
        return path
    }

    private static func numberBase(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.04, y: r.minY + r.height * 0.20, width: r.width * 0.40, height: r.height * 0.60),
            cornerSize: CGSize(width: 6, height: 6)
        )
        path.addRoundedRect(
            in: CGRect(x: r.maxX - r.width * 0.44, y: r.minY + r.height * 0.20, width: r.width * 0.40, height: r.height * 0.60),
            cornerSize: CGSize(width: 6, height: 6)
        )
        return path
    }

    private static func magneticCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX - r.width * 0.04, y: r.midY)
        Glyph.fanBand(&path, center: c, inner: r.width * 0.20, outer: r.width * 0.40, start: 40, end: 320)
        return path
    }

    private static func fiberLink(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.circle(&path, CGPoint(x: r.minX + r.width * 0.22, y: r.midY), r.width * 0.18)
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.38, y: r.midY),
            CGPoint(x: r.maxX - r.width * 0.04, y: r.minY + r.height * 0.14),
            CGPoint(x: r.maxX - r.width * 0.04, y: r.maxY - r.height * 0.14),
        ])
        return path
    }

    private static func gaussianBeam(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.10))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.10), control: CGPoint(x: r.midX, y: r.midY - r.height * 0.02))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.10))
        path.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.10), control: CGPoint(x: r.midX, y: r.midY + r.height * 0.02))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: r.midX - r.width * 0.10, y: r.midY - r.height * 0.12, width: r.width * 0.20, height: r.height * 0.24))
        return path
    }

    private static func transientCircuit(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.06, y: r.maxY - r.height * 0.08))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.14),
            control: CGPoint(x: r.minX + r.width * 0.40, y: r.minY + r.height * 0.18)
        )
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.08))
        path.closeSubpath()
        return path
    }

    private static func diodeIV(_ r: CGRect) -> Path {
        var path = Path()
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.18),
            CGPoint(x: r.midX + r.width * 0.12, y: r.midY),
            CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.18),
        ])
        path.addRoundedRect(
            in: CGRect(x: r.midX + r.width * 0.12, y: r.minY + r.height * 0.16, width: r.width * 0.12, height: r.height * 0.68),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func rfLink(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.20, y: r.minY + r.height * 0.08, width: r.width * 0.12, height: r.height * 0.80),
            cornerSize: CGSize(width: 2, height: 2)
        )
        let origin = CGPoint(x: r.minX + r.width * 0.34, y: r.minY + r.height * 0.26)
        Glyph.fanBand(&path, center: origin, inner: r.width * 0.14, outer: r.width * 0.24, start: -50, end: 50)
        Glyph.fanBand(&path, center: origin, inner: r.width * 0.30, outer: r.width * 0.42, start: -50, end: 50)
        return path
    }

    // MARK: - Toolkit · Bench

    private static func heaterDesign(_ r: CGRect) -> Path {
        var path = Path()
        let box = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.16)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 4, height: 4))
        path.move(to: CGPoint(x: box.minX + box.width * 0.12, y: box.midY + 4))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.34, y: box.midY - box.height * 0.22))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.56, y: box.midY + box.height * 0.22))
        path.addLine(to: CGPoint(x: box.maxX - box.width * 0.12, y: box.midY - 4))
        path.addLine(to: CGPoint(x: box.maxX - box.width * 0.12, y: box.midY + 4))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.56, y: box.midY + box.height * 0.32))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.34, y: box.midY - box.height * 0.12))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.12, y: box.midY - 4))
        path.closeSubpath()
        return path
    }

    private static func solenoidDesign(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.20, width: r.width * 0.56, height: r.height * 0.60),
            cornerSize: CGSize(width: 6, height: 6)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.58, y: r.midY - r.height * 0.08, width: r.width * 0.32, height: r.height * 0.16),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return path
    }

    private static func empEmc(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.46
        var points: [CGPoint] = []
        for index in 0..<6 {
            let angle = (CGFloat(index) * 60 - 90) * .pi / 180
            points.append(CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad))
        }
        path.addPolygon(points)
        return path
    }

    private static func eBikeTorqueRPM(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.34
        Glyph.circle(&path, c, rad)
        Glyph.circle(&path, c, rad * 0.42)
        path.addRoundedRect(
            in: CGRect(x: c.x, y: c.y - r.height * 0.07, width: rad * 1.35, height: r.height * 0.14),
            cornerSize: CGSize(width: 3, height: 3)
        )
        return path
    }

    private static func eBikeSprocket(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let inner = min(r.width, r.height) * 0.28
        let outer = inner * 1.28
        var points: [CGPoint] = []
        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 6 - .pi / 12
            let rad = index.isMultiple(of: 2) ? outer : inner
            points.append(CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad))
        }
        path.addPolygon(points)
        Glyph.circle(&path, c, inner * 0.40)
        return path
    }

    private static func eBikeRange(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.14, width: r.width * 0.44, height: r.height * 0.28),
            cornerSize: CGSize(width: 3, height: 3)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.52, y: r.minY + r.height * 0.20, width: r.width * 0.08, height: r.height * 0.16),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        Glyph.fanBand(
            &path,
            center: CGPoint(x: r.midX, y: r.maxY - r.height * 0.10),
            inner: r.width * 0.22,
            outer: r.width * 0.38,
            start: 200,
            end: 340
        )
        return path
    }

    private static func eBikePackDesigner(_ r: CGRect) -> Path {
        var path = Path()
        let pack = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.14)
        path.addRoundedRect(in: pack, cornerSize: CGSize(width: 5, height: 5))
        path.addRect(CGRect(x: pack.midX - 2, y: pack.minY + 4, width: 4, height: pack.height - 8))
        path.addRect(CGRect(x: pack.minX + 4, y: pack.minY + pack.height / 3 - 2, width: pack.width - 8, height: 4))
        path.addRect(CGRect(x: pack.minX + 4, y: pack.minY + pack.height * 2 / 3 - 2, width: pack.width - 8, height: 4))
        return path
    }

    private static func nickelStrip(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.04, y: r.midY - r.height * 0.14, width: r.width * 0.74, height: r.height * 0.28),
            cornerSize: CGSize(width: 3, height: 3)
        )
        path.addRoundedRect(
            in: CGRect(x: r.maxX - r.width * 0.26, y: r.midY - r.height * 0.08, width: r.width * 0.22, height: r.height * 0.16),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func analogWorkbench(_ r: CGRect) -> Path {
        var path = Path()
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.10),
            CGPoint(x: r.maxX - r.width * 0.08, y: r.midY),
            CGPoint(x: r.minX + r.width * 0.18, y: r.maxY - r.height * 0.10),
        ])
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.26, width: r.width * 0.16, height: r.height * 0.08),
            cornerSize: CGSize(width: 1, height: 1)
        )
        path.addRect(
            CGRect(x: r.minX + r.width * 0.34, y: r.maxY - r.height * 0.36, width: r.width * 0.04, height: r.height * 0.12)
        )
        return path
    }

    private static func noiseSNR(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.sineRibbon(&path, in: r, y: r.midY - r.height * 0.10, amplitude: r.height * 0.22, thickness: r.height * 0.14, cycles: 1)
        for fraction in [0.28, 0.72] as [CGFloat] {
            path.addRoundedRect(
                in: CGRect(x: r.minX + r.width * fraction - r.width * 0.04, y: r.maxY - r.height * 0.28, width: r.width * 0.08, height: r.height * 0.20),
                cornerSize: CGSize(width: 2, height: 2)
            )
        }
        return path
    }

    private static func linearRegulator(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.08, width: r.width * 0.68, height: r.height * 0.50),
            cornerSize: CGSize(width: 4, height: 4)
        )
        for index in 0..<3 {
            let x = r.minX + r.width * (0.28 + 0.22 * CGFloat(index))
            path.addRoundedRect(
                in: CGRect(x: x - r.width * 0.05, y: r.minY + r.height * 0.54, width: r.width * 0.10, height: r.height * 0.34),
                cornerSize: CGSize(width: 2, height: 2)
            )
        }
        return path
    }

    private static func instrumentationAmp(_ r: CGRect) -> Path {
        var path = Path()
        path.addPolygon([
            CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.14),
            CGPoint(x: r.maxX - r.width * 0.08, y: r.midY),
            CGPoint(x: r.minX + r.width * 0.26, y: r.maxY - r.height * 0.14),
        ])
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.04, y: r.minY + r.height * 0.24, width: r.width * 0.10, height: r.height * 0.52),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func adcDac(_ r: CGRect) -> Path {
        var path = Path()
        let base = r.maxY - r.height * 0.12
        path.move(to: CGPoint(x: r.minX + r.width * 0.06, y: base))
        for index in 0..<3 {
            let x0 = r.minX + r.width * 0.06 + r.width * 0.22 * CGFloat(index)
            let y = base - r.height * 0.22 * CGFloat(index + 1)
            path.addLine(to: CGPoint(x: x0, y: y))
            path.addLine(to: CGPoint(x: x0 + r.width * 0.22, y: y))
        }
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: base - r.height * 0.66))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: base))
        path.closeSubpath()
        return path
    }

    // MARK: - Toolkit · Reference

    private static func referenceLibrary(_ r: CGRect) -> Path {
        var path = Path()
        let book = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.08)
        path.addRoundedRect(in: book, cornerSize: CGSize(width: 4, height: 4))
        path.addRect(CGRect(x: book.minX + book.width * 0.14, y: book.minY, width: book.width * 0.12, height: book.height))
        return path
    }

    private static func panelDirectory(_ r: CGRect) -> Path {
        var path = Path()
        let card = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.06)
        path.addRoundedRect(in: card, cornerSize: CGSize(width: 5, height: 5))
        for index in 0..<3 {
            let y = card.minY + card.height * (0.26 + 0.20 * CGFloat(index))
            path.addRoundedRect(
                in: CGRect(x: card.minX + card.width * 0.14, y: y, width: card.width * 0.52, height: card.height * 0.08),
                cornerSize: CGSize(width: 1.5, height: 1.5)
            )
        }
        path.addRoundedRect(
            in: CGRect(x: card.maxX - card.width * 0.24, y: card.minY + card.height * 0.24, width: card.width * 0.12, height: card.width * 0.12),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }

    private static func loadWorksheet(_ r: CGRect) -> Path {
        var path = Path()
        let page = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.06)
        path.addRoundedRect(in: page, cornerSize: CGSize(width: 4, height: 4))
        path.addRect(CGRect(x: page.midX - 2, y: page.minY + page.height * 0.16, width: 4, height: page.height * 0.70))
        path.addRect(CGRect(x: page.minX + page.width * 0.14, y: page.midY - 2, width: page.width * 0.72, height: 4))
        return path
    }

    private static func cableSchedule(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.minX + r.width * 0.28, y: r.midY)
        Glyph.circle(&path, c, r.width * 0.24)
        for angle in [90.0, 210.0, 330.0] {
            let rad = angle * .pi / 180
            Glyph.circle(
                &path,
                CGPoint(x: c.x + cos(rad) * r.width * 0.10, y: c.y + sin(rad) * r.width * 0.10),
                r.width * 0.045
            )
        }
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.58, y: r.minY + r.height * 0.22, width: r.width * 0.34, height: r.height * 0.12),
            cornerSize: CGSize(width: 2, height: 2)
        )
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.58, y: r.midY - r.height * 0.06, width: r.width * 0.34, height: r.height * 0.12),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }
}

// MARK: - Shared fill primitives

private enum Glyph {
    static func circle(_ path: inout Path, _ center: CGPoint, _ radius: CGFloat) {
        path.addEllipse(in: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    static func ribbon(
        _ path: inout Path,
        from: CGPoint,
        to: CGPoint,
        sag: CGFloat,
        thickness: CGFloat
    ) {
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 + sag)
        path.move(to: CGPoint(x: from.x, y: from.y - thickness / 2))
        path.addQuadCurve(
            to: CGPoint(x: to.x, y: to.y - thickness / 2),
            control: CGPoint(x: mid.x, y: mid.y - thickness / 2)
        )
        path.addLine(to: CGPoint(x: to.x, y: to.y + thickness / 2))
        path.addQuadCurve(
            to: CGPoint(x: from.x, y: from.y + thickness / 2),
            control: CGPoint(x: mid.x, y: mid.y + thickness / 2)
        )
        path.closeSubpath()
    }

    static func fanBand(
        _ path: inout Path,
        center: CGPoint,
        inner: CGFloat,
        outer: CGFloat,
        start: Double,
        end: Double
    ) {
        path.addArc(center: center, radius: outer, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: .degrees(end), endAngle: .degrees(start), clockwise: true)
        path.closeSubpath()
    }

    static func sineRibbon(
        _ path: inout Path,
        in rect: CGRect,
        y: CGFloat,
        amplitude: CGFloat,
        thickness: CGFloat,
        cycles: CGFloat,
        steps: Int = 18
    ) {
        path.move(to: CGPoint(x: rect.minX, y: y - thickness / 2))
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * t,
                y: y - sin(t * .pi * 2 * cycles) * amplitude - thickness / 2
            ))
        }
        for step in stride(from: steps, through: 0, by: -1) {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * t,
                y: y - sin(t * .pi * 2 * cycles) * amplitude + thickness / 2
            ))
        }
        path.closeSubpath()
    }

    static func filledL(
        _ path: inout Path,
        at origin: CGPoint,
        size: CGFloat,
        thickness: CGFloat,
        flipX: Bool,
        flipY: Bool
    ) {
        let sx: CGFloat = flipX ? -1 : 1
        let sy: CGFloat = flipY ? -1 : 1
        path.addPolygon([
            origin,
            CGPoint(x: origin.x + size * sx, y: origin.y),
            CGPoint(x: origin.x + size * sx, y: origin.y + thickness * sy),
            CGPoint(x: origin.x + thickness * sx, y: origin.y + thickness * sy),
            CGPoint(x: origin.x + thickness * sx, y: origin.y + size * sy),
            CGPoint(x: origin.x, y: origin.y + size * sy),
        ])
    }

    static func bolt(_ r: CGRect) -> Path {
        var path = Path()
        path.addPolygon([
            CGPoint(x: r.midX + r.width * 0.12, y: r.minY),
            CGPoint(x: r.midX - r.width * 0.22, y: r.midY + r.height * 0.04),
            CGPoint(x: r.midX - r.width * 0.02, y: r.midY + r.height * 0.04),
            CGPoint(x: r.midX - r.width * 0.16, y: r.maxY),
            CGPoint(x: r.midX + r.width * 0.24, y: r.midY - r.height * 0.04),
            CGPoint(x: r.midX + r.width * 0.04, y: r.midY - r.height * 0.04),
        ])
        return path
    }
}

private extension Path {
    mutating func addPolygon(_ points: [CGPoint]) {
        guard let first = points.first else { return }
        move(to: first)
        for point in points.dropFirst() { addLine(to: point) }
        closeSubpath()
    }
}
