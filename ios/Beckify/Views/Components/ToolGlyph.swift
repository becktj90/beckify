import SwiftUI

// MARK: - Beckify Flat Glyph System (app-only)
//
// Stroke-only Canvas pictograms for the Field EE Toolbox — no image assets,
// no SF Symbols in wells, no fills, no gradient strokes, no dual under-ink.
// Each `ToolID` maps 1:1 to a `GlyphKind`. Design grid is 24×24 with a 2pt
// margin (10% canvas inset). Weight is `Theme.Stroke.icon` (2.6 @ 44pt).
// SF Symbols stay on chrome (favorites, nav) only.

/// One stroke-weight curve for every pictogram. 44pt is the reference size
/// (`Theme.Stroke.icon` = 2.6). Selected is a slight weight bump, not a new
/// language. A 1.8 floor keeps 22pt related-row marks engraved.
enum GlyphStroke {
    static let referenceSize: CGFloat = 44
    static let selectedWeight: CGFloat = 1.06
    static let minimum: CGFloat = 1.8

    static func lineWidth(size: CGFloat, selected: Bool) -> CGFloat {
        let scaled = Theme.Stroke.icon * (size / referenceSize)
        let base = max(minimum, scaled)
        return selected ? base * selectedWeight : base
    }
}

/// Stroke pictogram for one toolbox tool. Drawn as vector paths so it stays
/// crisp at any size, follows the theme, and ships no image assets.
///
/// Each `ToolID` maps 1:1 to a distinct `GlyphKind`. When a category is known
/// the stroke is that shelf’s solid primary — never a gradient.
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

    private var strokeColor: Color {
        if let resolvedCategory {
            return Theme.categoryColors(resolvedCategory).primary
        }
        return selected ? Theme.foreground : Theme.muted
    }

    private var lineWidth: CGFloat {
        GlyphStroke.lineWidth(size: size, selected: selected)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.10, dy: canvasSize.height * 0.10)
            let path = kind.path(in: rect)
            context.stroke(
                path,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Soft colored well that frames a `ToolGlyph` — the graphic unit of the grid
/// and list rows (quiet category tint + crisp stroke pictogram).
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

/// Shelf mark for a toolbox category — same single-stroke language as tools.
struct CategoryGlyph: View {
    let category: ToolCategory
    var size: CGFloat = 28
    var selected: Bool = true

    private var lineWidth: CGFloat {
        GlyphStroke.lineWidth(size: size, selected: selected)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.10, dy: canvasSize.height * 0.10)
            let path = CategoryGlyphKind(category).path(in: rect)
            context.stroke(
                path,
                with: .color(Theme.categoryColors(category).primary),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
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
        case .power: return Self.power(rect)
        case .controls: return Self.controls(rect)
        case .homework: return Self.homework(rect)
        case .sensors: return Self.sensors(rect)
        case .reference: return Self.reference(rect)
        }
    }

    /// Two posts + sagging span — jobsite / field.
    private static func field(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.minY + r.height * 0.22
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.18, y: y), CGPoint(x: r.minX + r.width * 0.18, y: r.maxY - r.height * 0.08))
        Glyph.line(&path, CGPoint(x: r.maxX - r.width * 0.18, y: y), CGPoint(x: r.maxX - r.width * 0.18, y: r.maxY - r.height * 0.08))
        path.move(to: CGPoint(x: r.minX + r.width * 0.18, y: y))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.18, y: y),
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.72)
        )
        return path
    }

    /// Lightning bolt.
    private static func power(_ r: CGRect) -> Path {
        Glyph.bolt(r)
    }

    /// Clock face — controls / PLC.
    private static func controls(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.42
        Glyph.circle(&path, c, rad)
        Glyph.line(&path, c, CGPoint(x: c.x, y: c.y - rad * 0.52))
        Glyph.line(&path, c, CGPoint(x: c.x + rad * 0.38, y: c.y + rad * 0.08))
        return path
    }

    /// Closed notebook.
    private static func homework(_ r: CGRect) -> Path {
        var path = Path()
        let page = r.insetBy(dx: r.width * 0.16, dy: r.height * 0.10)
        path.addRoundedRect(in: page, cornerSize: CGSize(width: 3, height: 3))
        Glyph.line(&path, CGPoint(x: page.minX + page.width * 0.18, y: page.minY + page.height * 0.32), CGPoint(x: page.maxX - page.width * 0.18, y: page.minY + page.height * 0.32))
        Glyph.line(&path, CGPoint(x: page.minX + page.width * 0.18, y: page.minY + page.height * 0.52), CGPoint(x: page.maxX - page.width * 0.28, y: page.minY + page.height * 0.52))
        return path
    }

    /// Two upward instrument arcs.
    private static func sensors(_ r: CGRect) -> Path {
        var path = Path()
        let base = CGPoint(x: r.midX, y: r.maxY - r.height * 0.16)
        Glyph.circle(&path, base, r.width * 0.06)
        for index in 1...2 {
            path.addArc(
                center: base,
                radius: r.width * 0.20 * CGFloat(index),
                startAngle: .degrees(210),
                endAngle: .degrees(330),
                clockwise: false
            )
        }
        return path
    }

    /// Book + spine.
    private static func reference(_ r: CGRect) -> Path {
        var path = Path()
        let book = r.insetBy(dx: r.width * 0.16, dy: r.height * 0.10)
        path.addRoundedRect(in: book, cornerSize: CGSize(width: 3, height: 3))
        Glyph.line(&path, CGPoint(x: book.minX + book.width * 0.18, y: book.minY), CGPoint(x: book.minX + book.width * 0.18, y: book.maxY))
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
    case ohmsLaw
    case power
    case powerWizard
    case voltageDrop
    case conduitFill
    case conductorCost
    case conductorLength
    case transformer
    case timer555
    case motorFLA
    case wireAmpacity
    case voltageDivider
    case seriesParallel
    case resistorColor
    case unitConverter
    case frequencyWave
    case ledRC
    case wifiStatus
    case cellularStatus
    case bluetoothScan
    case noiseMeter
    case bubbleLevel
    case magnetometer
    case barometer
    case motionSnapshot
    case fieldPosition
    case deviceHealth
    case receptacleSelector
    case reactance
    case powerFactor
    case shortCircuit
    case circularMils
    case loadFactors
    case signalScaling
    case modbusAddress
    case plcTimer
    case panelDirectory
    case motorSpeed
    case rfLink
    case phasorDiagram
    case numberBase
    case batteryBank
    case referenceLibrary
    case magneticCircuit
    case fiberLink
    case gaussianBeam
    case transientCircuit
    case rackCurrent
    case diodeIV
    case isLoopVerifier
    case tapChanger
    case harmonicsTHD
    case upsSizing
    case motorNameplate
    case motorNameplateOCR
    case lookCheck
    case heaterDesign
    case empEmc
    case necCircuit
    case loadWorksheet
    case cableSchedule
    case solenoidDesign
    case solarDesign
    case analogWorkbench
    case noiseSNR
    case linearRegulator
    case instrumentationAmp
    case adcDac
    case eBikeTorqueRPM
    case eBikeSprocket
    case eBikeRange
    case eBikePackDesigner
    case nickelStrip
    case controlSystems

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
        case .power: return Self.power(rect)
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

    /// Horizontal conductor with one sagging mid span.
    private static func voltageDrop(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.minY + r.height * 0.28
        let left = CGPoint(x: r.minX + r.width * 0.16, y: y)
        let right = CGPoint(x: r.maxX - r.width * 0.16, y: y)
        Glyph.line(&path, CGPoint(x: r.minX, y: y), left)
        path.move(to: left)
        path.addQuadCurve(
            to: right,
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.82)
        )
        Glyph.line(&path, right, CGPoint(x: r.maxX, y: y))
        Glyph.line(&path, left, CGPoint(x: left.x, y: r.maxY - r.height * 0.06))
        Glyph.line(&path, right, CGPoint(x: right.x, y: r.maxY - r.height * 0.06))
        return path
    }

    /// Three parallel conductors in a short sleeve.
    private static func wireAmpacity(_ r: CGRect) -> Path {
        var path = Path()
        let sleeve = CGRect(
            x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.22,
            width: r.width * 0.56, height: r.height * 0.56
        )
        path.addRoundedRect(in: sleeve, cornerSize: CGSize(width: sleeve.height * 0.22, height: sleeve.height * 0.22))
        for index in 0..<3 {
            let y = sleeve.minY + sleeve.height * (0.28 + 0.22 * CGFloat(index))
            Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.06, y: y), CGPoint(x: r.maxX - r.width * 0.06, y: y))
        }
        return path
    }

    /// Motor can + shaft stub + one current arc.
    private static func motorFLA(_ r: CGRect) -> Path {
        var path = Path()
        let can = CGRect(
            x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.22,
            width: r.width * 0.62, height: r.height * 0.46
        )
        path.addRoundedRect(in: can, cornerSize: CGSize(width: can.height * 0.18, height: can.height * 0.18))
        path.addEllipse(in: CGRect(
            x: can.minX - r.width * 0.04, y: can.minY + can.height * 0.12,
            width: r.width * 0.12, height: can.height * 0.76
        ))
        Glyph.line(
            &path,
            CGPoint(x: can.maxX, y: can.midY),
            CGPoint(x: r.maxX - r.width * 0.06, y: can.midY)
        )
        path.addArc(
            center: CGPoint(x: r.midX - r.width * 0.04, y: r.maxY - r.height * 0.10),
            radius: r.width * 0.28,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        return path
    }

    /// US duplex: two slots + round ground.
    private static func receptacleSelector(_ r: CGRect) -> Path {
        var path = Path()
        let face = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.08)
        path.addRoundedRect(in: face, cornerSize: CGSize(width: 5, height: 5))
        let slotH = face.height * 0.28
        let slotY = face.minY + face.height * 0.28
        Glyph.line(&path, CGPoint(x: face.midX - face.width * 0.18, y: slotY), CGPoint(x: face.midX - face.width * 0.18, y: slotY + slotH))
        Glyph.line(&path, CGPoint(x: face.midX + face.width * 0.18, y: slotY), CGPoint(x: face.midX + face.width * 0.18, y: slotY + slotH))
        Glyph.circle(&path, CGPoint(x: face.midX, y: face.maxY - face.height * 0.22), face.width * 0.07)
        return path
    }

    /// AP slab + two upward arcs (CoS: 2 max).
    private static func wifiStatus(_ r: CGRect) -> Path {
        var path = Path()
        let slab = CGRect(
            x: r.minX + r.width * 0.16, y: r.maxY - r.height * 0.28,
            width: r.width * 0.68, height: r.height * 0.20
        )
        path.addRoundedRect(in: slab, cornerSize: CGSize(width: slab.height * 0.45, height: slab.height * 0.45))
        Glyph.line(&path, CGPoint(x: slab.minX + slab.width * 0.22, y: slab.midY), CGPoint(x: slab.minX + slab.width * 0.38, y: slab.midY))
        let origin = CGPoint(x: r.midX, y: slab.minY)
        for index in 1...2 {
            path.addArc(
                center: origin,
                radius: r.width * 0.22 * CGFloat(index),
                startAngle: .degrees(210),
                endAngle: .degrees(330),
                clockwise: false
            )
        }
        return path
    }

    /// Outer conduit + one inner conductor + fill chord.
    private static func conduitFill(_ r: CGRect) -> Path {
        var path = Path()
        let outer = min(r.width, r.height) * 0.46
        Glyph.circle(&path, CGPoint(x: r.midX, y: r.midY), outer)
        Glyph.circle(
            &path,
            CGPoint(x: r.midX, y: r.midY + outer * 0.22),
            outer * 0.28
        )
        Glyph.line(
            &path,
            CGPoint(x: r.midX - outer * 0.72, y: r.midY - outer * 0.18),
            CGPoint(x: r.midX + outer * 0.72, y: r.midY - outer * 0.18)
        )
        return path
    }

    // MARK: - Field · Jobsite

    /// Spool (circle + stand) + price tag outline — no $ letter.
    private static func conductorCost(_ r: CGRect) -> Path {
        var path = Path()
        let hub = CGPoint(x: r.minX + r.width * 0.36, y: r.midY - r.height * 0.04)
        Glyph.circle(&path, hub, r.width * 0.26)
        Glyph.circle(&path, hub, r.width * 0.08)
        Glyph.line(&path, CGPoint(x: hub.x - r.width * 0.16, y: r.maxY - r.height * 0.08), CGPoint(x: hub.x, y: hub.y + r.width * 0.26))
        Glyph.line(&path, CGPoint(x: hub.x + r.width * 0.16, y: r.maxY - r.height * 0.08), CGPoint(x: hub.x, y: hub.y + r.width * 0.26))
        let tag = CGRect(
            x: r.maxX - r.width * 0.36, y: r.minY + r.height * 0.12,
            width: r.width * 0.32, height: r.height * 0.28
        )
        path.addRoundedRect(in: tag, cornerSize: CGSize(width: 3, height: 3))
        return path
    }

    /// Tape case + curved tape.
    private static func conductorLength(_ r: CGRect) -> Path {
        var path = Path()
        let box = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.28,
            width: r.width * 0.42, height: r.height * 0.44
        )
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3, height: 3))
        path.move(to: CGPoint(x: box.maxX, y: box.midY))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.16),
            control: CGPoint(x: r.maxX - r.width * 0.10, y: box.minY - r.height * 0.08)
        )
        return path
    }

    /// Breaker block + vertical handle + one chevron.
    private static func shortCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let block = CGRect(
            x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.38,
            width: r.width * 0.44, height: r.height * 0.44
        )
        path.addRoundedRect(in: block, cornerSize: CGSize(width: 3, height: 3))
        Glyph.line(
            &path,
            CGPoint(x: r.midX, y: r.minY + r.height * 0.08),
            CGPoint(x: r.midX, y: block.minY)
        )
        path.move(to: CGPoint(x: r.midX - r.width * 0.14, y: r.minY + r.height * 0.22))
        path.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.10))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.14, y: r.minY + r.height * 0.22))
        return path
    }

    /// Two concentric circles.
    private static func circularMils(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) * 0.44
        Glyph.circle(&path, c, outer)
        Glyph.circle(&path, c, outer * 0.48)
        return path
    }

    /// Three ascending demand bars.
    private static func loadFactors(_ r: CGRect) -> Path {
        var path = Path()
        let heights: [CGFloat] = [0.36, 0.56, 0.78]
        for (index, height) in heights.enumerated() {
            let x = r.minX + r.width * (0.16 + 0.28 * CGFloat(index))
            let bar = CGRect(
                x: x, y: r.maxY - r.height * height,
                width: r.width * 0.20, height: r.height * height
            )
            path.addRoundedRect(in: bar, cornerSize: CGSize(width: 2.5, height: 2.5))
        }
        return path
    }

    /// Panelboard + three breaker slots.
    private static func necCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let panel = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.08)
        path.addRoundedRect(in: panel, cornerSize: CGSize(width: 4, height: 4))
        for index in 0..<3 {
            let y = panel.minY + panel.height * (0.28 + 0.22 * CGFloat(index))
            Glyph.line(
                &path,
                CGPoint(x: panel.minX + panel.width * 0.18, y: y),
                CGPoint(x: panel.maxX - panel.width * 0.18, y: y)
            )
        }
        return path
    }

    /// Loop with a break + probe tip.
    private static func isLoopVerifier(_ r: CGRect) -> Path {
        var path = Path()
        let loop = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.16)
        let radius: CGFloat = 6
        path.move(to: CGPoint(x: loop.midX + r.width * 0.10, y: loop.minY))
        path.addLine(to: CGPoint(x: loop.maxX - radius, y: loop.minY))
        path.addQuadCurve(to: CGPoint(x: loop.maxX, y: loop.minY + radius), control: CGPoint(x: loop.maxX, y: loop.minY))
        path.addLine(to: CGPoint(x: loop.maxX, y: loop.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: loop.maxX - radius, y: loop.maxY), control: CGPoint(x: loop.maxX, y: loop.maxY))
        path.addLine(to: CGPoint(x: loop.minX + radius, y: loop.maxY))
        path.addQuadCurve(to: CGPoint(x: loop.minX, y: loop.maxY - radius), control: CGPoint(x: loop.minX, y: loop.maxY))
        path.addLine(to: CGPoint(x: loop.minX, y: loop.minY + radius))
        path.addQuadCurve(to: CGPoint(x: loop.minX + radius, y: loop.minY), control: CGPoint(x: loop.minX, y: loop.minY))
        path.addLine(to: CGPoint(x: loop.midX - r.width * 0.10, y: loop.minY))
        Glyph.line(
            &path,
            CGPoint(x: loop.midX, y: r.minY),
            CGPoint(x: loop.midX, y: loop.minY + r.height * 0.12)
        )
        return path
    }

    /// Motor can + curved arrow around the shaft.
    private static func motorSpeed(_ r: CGRect) -> Path {
        var path = Path()
        let can = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.28,
            width: r.width * 0.48, height: r.height * 0.36
        )
        path.addRoundedRect(in: can, cornerSize: CGSize(width: 4, height: 4))
        Glyph.line(&path, CGPoint(x: can.maxX, y: can.midY), CGPoint(x: r.maxX - r.width * 0.18, y: can.midY))
        let shaft = CGPoint(x: r.maxX - r.width * 0.22, y: can.midY)
        path.addArc(
            center: shaft,
            radius: r.width * 0.28,
            startAngle: .degrees(-20),
            endAngle: .degrees(210),
            clockwise: false
        )
        Glyph.arrowHead(
            &path,
            at: CGPoint(x: shaft.x + r.width * 0.26, y: shaft.y - r.height * 0.06),
            toward: CGPoint(x: shaft.x + r.width * 0.18, y: shaft.y - r.height * 0.16),
            size: r.width * 0.10
        )
        return path
    }

    /// Rounded plate + two data lines.
    private static func motorNameplate(_ r: CGRect) -> Path {
        var path = Path()
        let plate = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.18)
        path.addRoundedRect(in: plate, cornerSize: CGSize(width: 4, height: 4))
        Glyph.line(
            &path,
            CGPoint(x: plate.minX + plate.width * 0.16, y: plate.minY + plate.height * 0.38),
            CGPoint(x: plate.maxX - plate.width * 0.16, y: plate.minY + plate.height * 0.38)
        )
        Glyph.line(
            &path,
            CGPoint(x: plate.minX + plate.width * 0.16, y: plate.minY + plate.height * 0.62),
            CGPoint(x: plate.maxX - plate.width * 0.28, y: plate.minY + plate.height * 0.62)
        )
        return path
    }

    /// Nameplate + camera L brackets.
    private static func motorNameplateOCR(_ r: CGRect) -> Path {
        var path = Path()
        let plate = CGRect(
            x: r.minX + r.width * 0.20, y: r.minY + r.height * 0.26,
            width: r.width * 0.60, height: r.height * 0.48
        )
        path.addRoundedRect(in: plate, cornerSize: CGSize(width: 3, height: 3))
        Glyph.line(
            &path,
            CGPoint(x: plate.minX + plate.width * 0.16, y: plate.midY),
            CGPoint(x: plate.maxX - plate.width * 0.16, y: plate.midY)
        )
        let arm = min(r.width, r.height) * 0.16
        Glyph.lBracket(&path, CGPoint(x: r.minX + r.width * 0.04, y: r.minY + r.height * 0.06), dx: arm, dy: arm)
        Glyph.lBracket(&path, CGPoint(x: r.maxX - r.width * 0.04, y: r.minY + r.height * 0.06), dx: -arm, dy: arm)
        Glyph.lBracket(&path, CGPoint(x: r.minX + r.width * 0.04, y: r.maxY - r.height * 0.06), dx: arm, dy: -arm)
        Glyph.lBracket(&path, CGPoint(x: r.maxX - r.width * 0.04, y: r.maxY - r.height * 0.06), dx: -arm, dy: -arm)
        return path
    }

    /// Almond eye + pupil — Look Check, not OCR.
    private static func lookCheck(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.06, y: r.midY))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.midY),
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.08)
        )
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.06, y: r.midY),
            control: CGPoint(x: r.midX, y: r.maxY - r.height * 0.08)
        )
        Glyph.circle(&path, CGPoint(x: r.midX, y: r.midY), r.width * 0.14)
        return path
    }

    // MARK: - Field · Power

    private static func power(_ r: CGRect) -> Path {
        Glyph.bolt(r)
    }

    /// Bolt + two-ray star.
    private static func powerWizard(_ r: CGRect) -> Path {
        var path = Glyph.bolt(r)
        let star = CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.14)
        Glyph.line(&path, CGPoint(x: star.x, y: star.y - r.height * 0.12), CGPoint(x: star.x, y: star.y + r.height * 0.12))
        Glyph.line(&path, CGPoint(x: star.x - r.width * 0.12, y: star.y), CGPoint(x: star.x + r.width * 0.12, y: star.y))
        return path
    }

    /// Two vertical coil ovals + core bar.
    private static func transformer(_ r: CGRect) -> Path {
        var path = Path()
        let left = CGRect(
            x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.12,
            width: r.width * 0.28, height: r.height * 0.76
        )
        let right = CGRect(
            x: r.maxX - r.width * 0.38, y: r.minY + r.height * 0.12,
            width: r.width * 0.28, height: r.height * 0.76
        )
        path.addEllipse(in: left)
        path.addEllipse(in: right)
        Glyph.line(&path, CGPoint(x: r.midX, y: r.minY + r.height * 0.10), CGPoint(x: r.midX, y: r.maxY - r.height * 0.10))
        return path
    }

    /// Transformer coils + tap arrow.
    private static func tapChanger(_ r: CGRect) -> Path {
        var path = transformer(r)
        Glyph.arrow(
            &path,
            from: CGPoint(x: r.midX + r.width * 0.08, y: r.minY + r.height * 0.18),
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.34),
            head: r.width * 0.10
        )
        return path
    }

    /// Right triangle.
    private static func powerFactor(_ r: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.12)
        path.move(to: origin)
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.10, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x, y: r.minY + r.height * 0.12))
        path.closeSubpath()
        return path
    }

    /// Fundamental sine + higher-frequency ripple.
    private static func harmonicsTHD(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.sine(&path, in: r, y: r.midY, amplitude: r.height * 0.28, cycles: 1)
        Glyph.sine(&path, in: r, y: r.midY, amplitude: r.height * 0.10, cycles: 3)
        return path
    }

    /// Battery + nub + two cell dividers.
    private static func batteryBank(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.26,
            width: r.width * 0.72, height: r.height * 0.48
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3, height: 3))
        path.addRoundedRect(
            in: CGRect(x: body.maxX, y: body.midY - r.height * 0.10, width: r.width * 0.10, height: r.height * 0.20),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        Glyph.line(&path, CGPoint(x: body.minX + body.width * 0.33, y: body.minY + 3), CGPoint(x: body.minX + body.width * 0.33, y: body.maxY - 3))
        Glyph.line(&path, CGPoint(x: body.minX + body.width * 0.66, y: body.minY + 3), CGPoint(x: body.minX + body.width * 0.66, y: body.maxY - 3))
        return path
    }

    /// Half sun over a tilted panel.
    private static func solarDesign(_ r: CGRect) -> Path {
        var path = Path()
        let sun = CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.22)
        path.addArc(center: sun, radius: r.width * 0.16, startAngle: .degrees(200), endAngle: .degrees(20), clockwise: false)
        path.move(to: CGPoint(x: r.minX + r.width * 0.10, y: r.maxY - r.height * 0.16))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.62, y: r.maxY - r.height * 0.12))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.78, y: r.minY + r.height * 0.42))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.38))
        path.closeSubpath()
        return path
    }

    /// Battery + shield arc.
    private static func upsSizing(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.32,
            width: r.width * 0.52, height: r.height * 0.40
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3, height: 3))
        path.addRect(CGRect(x: body.maxX, y: body.midY - r.height * 0.08, width: r.width * 0.08, height: r.height * 0.16))
        path.addArc(
            center: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.28),
            radius: r.width * 0.28,
            startAngle: .degrees(210),
            endAngle: .degrees(330),
            clockwise: false
        )
        return path
    }

    // MARK: - Field · Controls

    /// Amp triangle with I/O stubs.
    private static func signalScaling(_ r: CGRect) -> Path {
        var path = Path()
        let left = r.minX + r.width * 0.22
        path.move(to: CGPoint(x: left, y: r.minY + r.height * 0.14))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.midY))
        path.addLine(to: CGPoint(x: left, y: r.maxY - r.height * 0.14))
        path.closeSubpath()
        Glyph.line(&path, CGPoint(x: r.minX, y: r.minY + r.height * 0.32), CGPoint(x: left, y: r.minY + r.height * 0.32))
        Glyph.line(&path, CGPoint(x: r.minX, y: r.maxY - r.height * 0.32), CGPoint(x: left, y: r.maxY - r.height * 0.32))
        Glyph.line(&path, CGPoint(x: r.maxX - r.width * 0.12, y: r.midY), CGPoint(x: r.maxX, y: r.midY))
        return path
    }

    /// Bus node + three pin ticks.
    private static func modbusAddress(_ r: CGRect) -> Path {
        var path = Path()
        let jack = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.18,
            width: r.width * 0.68, height: r.height * 0.46
        )
        path.addRoundedRect(in: jack, cornerSize: CGSize(width: 3, height: 3))
        for index in 0..<3 {
            let x = jack.minX + jack.width * (0.28 + 0.22 * CGFloat(index))
            Glyph.circle(&path, CGPoint(x: x, y: jack.maxY + r.height * 0.14), r.width * 0.045)
        }
        return path
    }

    /// Clock + two hands.
    private static func plcTimer(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        Glyph.circle(&path, c, min(r.width, r.height) * 0.44)
        Glyph.line(&path, c, CGPoint(x: c.x, y: c.y - r.height * 0.26))
        Glyph.line(&path, c, CGPoint(x: c.x + r.width * 0.22, y: c.y + r.height * 0.06))
        return path
    }

    /// Rack unit + two rails.
    private static func rackCurrent(_ r: CGRect) -> Path {
        var path = Path()
        let frame = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.10)
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: 3, height: 3))
        Glyph.line(&path, CGPoint(x: frame.minX + frame.width * 0.18, y: frame.minY + frame.height * 0.32), CGPoint(x: frame.maxX - frame.width * 0.12, y: frame.minY + frame.height * 0.32))
        Glyph.line(&path, CGPoint(x: frame.minX + frame.width * 0.18, y: frame.minY + frame.height * 0.62), CGPoint(x: frame.maxX - frame.width * 0.12, y: frame.minY + frame.height * 0.62))
        return path
    }

    /// Feedback circle + one arrow.
    private static func controlSystems(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.40
        path.addArc(center: c, radius: rad, startAngle: .degrees(-10), endAngle: .degrees(300), clockwise: false)
        let tip = CGPoint(x: c.x + rad, y: c.y)
        Glyph.arrowHead(&path, at: tip, toward: CGPoint(x: tip.x, y: tip.y + r.height * 0.12), size: r.width * 0.12)
        return path
    }

    // MARK: - Field · Instruments

    /// Phone slab + two bars.
    private static func cellularStatus(_ r: CGRect) -> Path {
        var path = Path()
        let phone = CGRect(
            x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.12,
            width: r.width * 0.40, height: r.height * 0.76
        )
        path.addRoundedRect(in: phone, cornerSize: CGSize(width: 4, height: 4))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.64, y: r.maxY - r.height * 0.16), CGPoint(x: r.minX + r.width * 0.64, y: r.maxY - r.height * 0.42))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.80, y: r.maxY - r.height * 0.16), CGPoint(x: r.minX + r.width * 0.80, y: r.maxY - r.height * 0.68))
        return path
    }

    /// Geometric Bluetooth rune.
    private static func bluetoothScan(_ r: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: r.midX, y: r.minY + r.height * 0.10)
        let bottom = CGPoint(x: r.midX, y: r.maxY - r.height * 0.10)
        path.move(to: top)
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.22, y: r.midY - r.height * 0.18))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.18, y: r.midY + r.height * 0.06))
        path.move(to: bottom)
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.22, y: r.midY + r.height * 0.18))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.18, y: r.midY - r.height * 0.06))
        Glyph.line(&path, top, bottom)
        return path
    }

    /// Mic capsule + two sound arcs.
    private static func noiseMeter(_ r: CGRect) -> Path {
        var path = Path()
        let mic = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.16,
            width: r.width * 0.32, height: r.height * 0.48
        )
        path.addRoundedRect(in: mic, cornerSize: CGSize(width: mic.width * 0.48, height: mic.width * 0.48))
        Glyph.line(&path, CGPoint(x: mic.midX, y: mic.maxY), CGPoint(x: mic.midX, y: r.maxY - r.height * 0.12))
        let origin = CGPoint(x: r.maxX - r.width * 0.28, y: r.midY - r.height * 0.06)
        for index in 1...2 {
            path.addArc(
                center: origin,
                radius: r.width * 0.16 * CGFloat(index),
                startAngle: .degrees(-55),
                endAngle: .degrees(55),
                clockwise: false
            )
        }
        return path
    }

    /// Capsule + offset bubble.
    private static func bubbleLevel(_ r: CGRect) -> Path {
        var path = Path()
        let tube = CGRect(
            x: r.minX + r.width * 0.04, y: r.midY - r.height * 0.16,
            width: r.width * 0.92, height: r.height * 0.32
        )
        path.addRoundedRect(in: tube, cornerSize: CGSize(width: tube.height / 2, height: tube.height / 2))
        Glyph.circle(&path, CGPoint(x: r.midX + r.width * 0.14, y: r.midY), r.height * 0.10)
        return path
    }

    /// Horseshoe magnet.
    private static func magnetometer(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY - r.height * 0.06)
        path.addArc(center: c, radius: r.width * 0.32, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        let left = CGPoint(x: c.x + cos(200 * .pi / 180) * r.width * 0.32, y: c.y + sin(200 * .pi / 180) * r.width * 0.32)
        let right = CGPoint(x: c.x + cos(340 * .pi / 180) * r.width * 0.32, y: c.y + sin(340 * .pi / 180) * r.width * 0.32)
        Glyph.line(&path, left, CGPoint(x: left.x, y: r.maxY - r.height * 0.08))
        Glyph.line(&path, right, CGPoint(x: right.x, y: r.maxY - r.height * 0.08))
        return path
    }

    /// Circle + one needle.
    private static func barometer(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        Glyph.circle(&path, c, min(r.width, r.height) * 0.44)
        Glyph.line(&path, c, CGPoint(x: c.x + r.width * 0.22, y: c.y - r.height * 0.22))
        return path
    }

    /// Phone + double-headed vertical arrow.
    private static func motionSnapshot(_ r: CGRect) -> Path {
        var path = Path()
        let phone = CGRect(
            x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.08,
            width: r.width * 0.36, height: r.height * 0.84
        )
        path.addRoundedRect(in: phone, cornerSize: CGSize(width: 4, height: 4))
        let x = r.maxX - r.width * 0.18
        Glyph.arrow(&path, from: CGPoint(x: x, y: r.midY), to: CGPoint(x: x, y: r.minY + r.height * 0.12), head: r.width * 0.10)
        Glyph.arrow(&path, from: CGPoint(x: x, y: r.midY), to: CGPoint(x: x, y: r.maxY - r.height * 0.12), head: r.width * 0.10)
        return path
    }

    /// Map-pin teardrop.
    private static func fieldPosition(_ r: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: r.midX, y: r.maxY - r.height * 0.04)
        path.move(to: tip)
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.14, y: r.minY + r.height * 0.36),
            control: CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.28)
        )
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.36),
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.02)
        )
        path.addQuadCurve(
            to: tip,
            control: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.28)
        )
        Glyph.circle(&path, CGPoint(x: r.midX, y: r.minY + r.height * 0.34), r.width * 0.12)
        return path
    }

    /// Heartbeat in a rounded rect.
    private static func deviceHealth(_ r: CGRect) -> Path {
        var path = Path()
        let frame = r.insetBy(dx: r.width * 0.06, dy: r.height * 0.18)
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: 4, height: 4))
        let y = frame.midY
        path.move(to: CGPoint(x: frame.minX + frame.width * 0.10, y: y))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.28, y: y))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.38, y: y - frame.height * 0.32))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.52, y: y + frame.height * 0.36))
        path.addLine(to: CGPoint(x: frame.minX + frame.width * 0.64, y: y))
        path.addLine(to: CGPoint(x: frame.maxX - frame.width * 0.10, y: y))
        return path
    }

    // MARK: - Toolkit · Basics

    /// Bold Ω — not a resistor zigzag.
    private static func ohmsLaw(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY - r.height * 0.06)
        let rad = min(r.width, r.height) * 0.36
        path.addArc(center: c, radius: rad, startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
        let left = CGPoint(
            x: c.x + cos(205 * .pi / 180) * rad,
            y: c.y + sin(205 * .pi / 180) * rad
        )
        let right = CGPoint(
            x: c.x + cos(335 * .pi / 180) * rad,
            y: c.y + sin(335 * .pi / 180) * rad
        )
        let footY = r.maxY - r.height * 0.10
        Glyph.line(&path, left, CGPoint(x: left.x - r.width * 0.02, y: footY))
        Glyph.line(&path, CGPoint(x: left.x - r.width * 0.08, y: footY), CGPoint(x: left.x + r.width * 0.10, y: footY))
        Glyph.line(&path, right, CGPoint(x: right.x + r.width * 0.02, y: footY))
        Glyph.line(&path, CGPoint(x: right.x - r.width * 0.10, y: footY), CGPoint(x: right.x + r.width * 0.08, y: footY))
        return path
    }

    /// Two bodies on a vertical run.
    private static func voltageDivider(_ r: CGRect) -> Path {
        var path = Path()
        let x = r.midX
        Glyph.line(&path, CGPoint(x: x, y: r.minY), CGPoint(x: x, y: r.maxY))
        let top = CGRect(x: x - r.width * 0.22, y: r.minY + r.height * 0.16, width: r.width * 0.44, height: r.height * 0.18)
        let bot = CGRect(x: x - r.width * 0.22, y: r.maxY - r.height * 0.34, width: r.width * 0.44, height: r.height * 0.18)
        path.addRoundedRect(in: top, cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(in: bot, cornerSize: CGSize(width: 2, height: 2))
        Glyph.line(&path, CGPoint(x: x, y: r.midY), CGPoint(x: r.maxX - r.width * 0.06, y: r.midY))
        return path
    }

    /// Series body left, parallel fork right.
    private static func seriesParallel(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        Glyph.line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.10, y: y))
        path.addRoundedRect(
            in: CGRect(x: r.minX + r.width * 0.10, y: y - r.height * 0.10, width: r.width * 0.22, height: r.height * 0.20),
            cornerSize: CGSize(width: 2, height: 2)
        )
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.32, y: y), CGPoint(x: r.minX + r.width * 0.46, y: y))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.46, y: y - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.46, y: y + r.height * 0.22))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.46, y: y - r.height * 0.22), CGPoint(x: r.maxX - r.width * 0.06, y: y - r.height * 0.22))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.46, y: y + r.height * 0.22), CGPoint(x: r.maxX - r.width * 0.06, y: y + r.height * 0.22))
        return path
    }

    /// Capsule + three band ticks.
    private static func resistorColor(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.12, y: r.midY - r.height * 0.16,
            width: r.width * 0.76, height: r.height * 0.32
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: body.height / 2, height: body.height / 2))
        for fraction in [0.28, 0.50, 0.72] as [CGFloat] {
            let x = body.minX + body.width * fraction
            Glyph.line(&path, CGPoint(x: x, y: body.minY + 2), CGPoint(x: x, y: body.maxY - 2))
        }
        return path
    }

    /// Two unit blocks with a swap.
    private static func unitConverter(_ r: CGRect) -> Path {
        var path = Path()
        let a = CGRect(x: r.minX, y: r.minY + r.height * 0.22, width: r.width * 0.32, height: r.height * 0.56)
        let b = CGRect(x: r.maxX - r.width * 0.32, y: r.minY + r.height * 0.22, width: r.width * 0.32, height: r.height * 0.56)
        path.addRoundedRect(in: a, cornerSize: CGSize(width: 3, height: 3))
        path.addRoundedRect(in: b, cornerSize: CGSize(width: 3, height: 3))
        Glyph.arrow(&path, from: CGPoint(x: a.maxX + r.width * 0.04, y: r.midY - r.height * 0.10), to: CGPoint(x: b.minX - r.width * 0.04, y: r.midY - r.height * 0.10), head: r.width * 0.08)
        Glyph.arrow(&path, from: CGPoint(x: b.minX - r.width * 0.04, y: r.midY + r.height * 0.10), to: CGPoint(x: a.maxX + r.width * 0.04, y: r.midY + r.height * 0.10), head: r.width * 0.08)
        return path
    }

    /// One sine period.
    private static func frequencyWave(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.sine(&path, in: r, y: r.midY, amplitude: r.height * 0.32, cycles: 1)
        return path
    }

    /// Diode + capacitor plates.
    private static func ledRC(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        path.move(to: CGPoint(x: r.minX + r.width * 0.08, y: y - r.height * 0.20))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.36, y: y))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.08, y: y + r.height * 0.20))
        path.closeSubpath()
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.36, y: y - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.36, y: y + r.height * 0.22))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.58, y: y - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.58, y: y + r.height * 0.22))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.70, y: y - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.70, y: y + r.height * 0.22))
        return path
    }

    /// DIP body + side pins.
    private static func timer555(_ r: CGRect) -> Path {
        var path = Path()
        let body = r.insetBy(dx: r.width * 0.22, dy: r.height * 0.16)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3, height: 3))
        for index in 0..<3 {
            let y = body.minY + body.height * (0.22 + 0.28 * CGFloat(index))
            Glyph.line(&path, CGPoint(x: body.minX, y: y), CGPoint(x: r.minX + r.width * 0.08, y: y))
            Glyph.line(&path, CGPoint(x: body.maxX, y: y), CGPoint(x: r.maxX - r.width * 0.08, y: y))
        }
        return path
    }

    /// Three-loop inductor.
    private static func reactance(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        Glyph.line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.10, y: y))
        let start = r.minX + r.width * 0.10
        let hump = r.width * 0.22
        path.move(to: CGPoint(x: start, y: y))
        for index in 0..<3 {
            path.addArc(
                center: CGPoint(x: start + hump * (CGFloat(index) + 0.5), y: y),
                radius: hump / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
        Glyph.line(&path, CGPoint(x: start + hump * 3, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    /// Origin + one phasor.
    private static func phasorDiagram(_ r: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: r.minX + r.width * 0.16, y: r.maxY - r.height * 0.16)
        Glyph.line(&path, CGPoint(x: origin.x, y: r.minY + r.height * 0.08), origin)
        Glyph.line(&path, origin, CGPoint(x: r.maxX - r.width * 0.08, y: origin.y))
        Glyph.arrow(
            &path,
            from: origin,
            to: CGPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.22),
            head: r.width * 0.12
        )
        return path
    }

    /// Two rounded squares.
    private static func numberBase(_ r: CGRect) -> Path {
        var path = Path()
        let a = CGRect(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.22, width: r.width * 0.38, height: r.height * 0.56)
        let b = CGRect(x: r.maxX - r.width * 0.44, y: r.minY + r.height * 0.22, width: r.width * 0.38, height: r.height * 0.56)
        path.addRoundedRect(in: a, cornerSize: CGSize(width: 4, height: 4))
        path.addRoundedRect(in: b, cornerSize: CGSize(width: 4, height: 4))
        return path
    }

    /// C-core with a gap.
    private static func magneticCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX - r.width * 0.06, y: r.midY)
        path.addArc(center: c, radius: r.width * 0.38, startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false)
        return path
    }

    /// Cable end + light cone.
    private static func fiberLink(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.circle(&path, CGPoint(x: r.minX + r.width * 0.22, y: r.midY), r.width * 0.16)
        path.move(to: CGPoint(x: r.minX + r.width * 0.38, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.16))
        path.move(to: CGPoint(x: r.minX + r.width * 0.38, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.16))
        return path
    }

    /// Beam waist.
    private static func gaussianBeam(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.16))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.16),
            control: CGPoint(x: r.midX, y: r.midY - r.height * 0.06)
        )
        path.move(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.16))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.16),
            control: CGPoint(x: r.midX, y: r.midY + r.height * 0.06)
        )
        return path
    }

    /// Rising exponential.
    private static func transientCircuit(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.06, y: r.maxY - r.height * 0.10))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.16),
            control: CGPoint(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.22)
        )
        return path
    }

    /// Diode triangle + bar.
    private static func diodeIV(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        path.move(to: CGPoint(x: r.minX + r.width * 0.16, y: y - r.height * 0.24))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.10, y: y))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.16, y: y + r.height * 0.24))
        path.closeSubpath()
        Glyph.line(&path, CGPoint(x: r.midX + r.width * 0.10, y: y - r.height * 0.26), CGPoint(x: r.midX + r.width * 0.10, y: y + r.height * 0.26))
        Glyph.line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.16, y: y))
        Glyph.line(&path, CGPoint(x: r.midX + r.width * 0.10, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    /// Mast + two side broadcast arcs.
    private static func rfLink(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.10), CGPoint(x: r.minX + r.width * 0.28, y: r.maxY - r.height * 0.08))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.08), CGPoint(x: r.minX + r.width * 0.44, y: r.maxY - r.height * 0.08))
        let origin = CGPoint(x: r.minX + r.width * 0.36, y: r.minY + r.height * 0.28)
        for index in 1...2 {
            path.addArc(
                center: origin,
                radius: r.width * 0.22 * CGFloat(index),
                startAngle: .degrees(-50),
                endAngle: .degrees(50),
                clockwise: false
            )
        }
        return path
    }

    // MARK: - Toolkit · Bench

    /// Two-peak zig inside a rect.
    private static func heaterDesign(_ r: CGRect) -> Path {
        var path = Path()
        let box = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.18)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3, height: 3))
        let y = box.midY
        path.move(to: CGPoint(x: box.minX + box.width * 0.12, y: y))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.32, y: y - box.height * 0.28))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.52, y: y + box.height * 0.28))
        path.addLine(to: CGPoint(x: box.minX + box.width * 0.72, y: y - box.height * 0.28))
        path.addLine(to: CGPoint(x: box.maxX - box.width * 0.12, y: y))
        return path
    }

    /// Coil cylinder + plunger.
    private static func solenoidDesign(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.22,
            width: r.width * 0.58, height: r.height * 0.56
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 4, height: 4))
        Glyph.line(&path, CGPoint(x: body.maxX, y: body.midY), CGPoint(x: r.maxX - r.width * 0.06, y: body.midY))
        Glyph.line(
            &path,
            CGPoint(x: r.maxX - r.width * 0.18, y: body.midY - r.height * 0.12),
            CGPoint(x: r.maxX - r.width * 0.18, y: body.midY + r.height * 0.12)
        )
        return path
    }

    /// Hex Faraday cage.
    private static func empEmc(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.44
        var points: [CGPoint] = []
        for index in 0..<6 {
            let angle = (CGFloat(index) * 60 - 90) * .pi / 180
            points.append(CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad))
        }
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    /// Chainring + crank arm.
    private static func eBikeTorqueRPM(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.34
        Glyph.circle(&path, c, rad)
        Glyph.circle(&path, c, rad * 0.28)
        Glyph.line(&path, c, CGPoint(x: c.x + rad * 1.35, y: c.y + rad * 0.55))
        return path
    }

    /// Circle + six teeth.
    private static func eBikeSprocket(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.34
        Glyph.circle(&path, c, rad)
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            Glyph.line(
                &path,
                CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad),
                CGPoint(x: c.x + cos(angle) * rad * 1.28, y: c.y + sin(angle) * rad * 1.28)
            )
        }
        return path
    }

    /// Battery + range gauge arc.
    private static func eBikeRange(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.18,
            width: r.width * 0.42, height: r.height * 0.28
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3, height: 3))
        path.addRect(CGRect(x: body.maxX, y: body.midY - r.height * 0.06, width: r.width * 0.07, height: r.height * 0.12))
        let gauge = CGPoint(x: r.midX, y: r.maxY - r.height * 0.12)
        path.addArc(center: gauge, radius: r.width * 0.36, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        Glyph.line(&path, gauge, CGPoint(x: gauge.x + r.width * 0.18, y: gauge.y - r.height * 0.22))
        return path
    }

    /// Pack outline with a 2×3 cell grid.
    private static func eBikePackDesigner(_ r: CGRect) -> Path {
        var path = Path()
        let pack = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.16)
        path.addRoundedRect(in: pack, cornerSize: CGSize(width: 4, height: 4))
        Glyph.line(&path, CGPoint(x: pack.midX, y: pack.minY), CGPoint(x: pack.midX, y: pack.maxY))
        Glyph.line(&path, CGPoint(x: pack.minX, y: pack.minY + pack.height / 3), CGPoint(x: pack.maxX, y: pack.minY + pack.height / 3))
        Glyph.line(&path, CGPoint(x: pack.minX, y: pack.minY + pack.height * 2 / 3), CGPoint(x: pack.maxX, y: pack.minY + pack.height * 2 / 3))
        return path
    }

    /// Long strip + tab.
    private static func nickelStrip(_ r: CGRect) -> Path {
        var path = Path()
        let strip = CGRect(
            x: r.minX + r.width * 0.08, y: r.midY - r.height * 0.12,
            width: r.width * 0.72, height: r.height * 0.24
        )
        path.addRoundedRect(in: strip, cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(
            in: CGRect(x: strip.maxX, y: strip.midY - r.height * 0.06, width: r.width * 0.12, height: r.height * 0.12),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        return path
    }

    /// Op-amp triangle with +/− stubs.
    private static func analogWorkbench(_ r: CGRect) -> Path {
        var path = Path()
        let left = r.minX + r.width * 0.22
        path.move(to: CGPoint(x: left, y: r.minY + r.height * 0.12))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.10, y: r.midY))
        path.addLine(to: CGPoint(x: left, y: r.maxY - r.height * 0.12))
        path.closeSubpath()
        Glyph.line(&path, CGPoint(x: r.minX, y: r.minY + r.height * 0.30), CGPoint(x: left, y: r.minY + r.height * 0.30))
        Glyph.line(&path, CGPoint(x: r.minX, y: r.maxY - r.height * 0.30), CGPoint(x: left, y: r.maxY - r.height * 0.30))
        Glyph.line(&path, CGPoint(x: r.maxX - r.width * 0.10, y: r.midY), CGPoint(x: r.maxX, y: r.midY))
        let plusY = r.minY + r.height * 0.30
        Glyph.line(&path, CGPoint(x: left + r.width * 0.08, y: plusY), CGPoint(x: left + r.width * 0.18, y: plusY))
        Glyph.line(&path, CGPoint(x: left + r.width * 0.13, y: plusY - r.height * 0.05), CGPoint(x: left + r.width * 0.13, y: plusY + r.height * 0.05))
        Glyph.line(&path, CGPoint(x: left + r.width * 0.08, y: r.maxY - r.height * 0.30), CGPoint(x: left + r.width * 0.18, y: r.maxY - r.height * 0.30))
        return path
    }

    /// Sine + sparse noise ticks.
    private static func noiseSNR(_ r: CGRect) -> Path {
        var path = Path()
        Glyph.sine(&path, in: r, y: r.midY - r.height * 0.08, amplitude: r.height * 0.22, cycles: 1)
        for fraction in [0.22, 0.48, 0.74] as [CGFloat] {
            let x = r.minX + r.width * fraction
            Glyph.line(&path, CGPoint(x: x, y: r.maxY - r.height * 0.12), CGPoint(x: x, y: r.maxY - r.height * 0.28))
        }
        return path
    }

    /// IC + three-line ground rake.
    private static func linearRegulator(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.10,
            width: r.width * 0.64, height: r.height * 0.48
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3, height: 3))
        for index in 0..<3 {
            let x = body.minX + body.width * (0.22 + 0.28 * CGFloat(index))
            Glyph.line(&path, CGPoint(x: x, y: body.maxY), CGPoint(x: x, y: r.maxY - r.height * 0.10))
        }
        return path
    }

    /// One triangle + sense leads.
    private static func instrumentationAmp(_ r: CGRect) -> Path {
        var path = Path()
        let left = r.minX + r.width * 0.28
        path.move(to: CGPoint(x: left, y: r.minY + r.height * 0.16))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.10, y: r.midY))
        path.addLine(to: CGPoint(x: left, y: r.maxY - r.height * 0.16))
        path.closeSubpath()
        Glyph.line(&path, CGPoint(x: r.minX, y: r.minY + r.height * 0.28), CGPoint(x: left, y: r.minY + r.height * 0.28))
        Glyph.line(&path, CGPoint(x: r.minX, y: r.maxY - r.height * 0.28), CGPoint(x: left, y: r.maxY - r.height * 0.28))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.28), CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.28))
        return path
    }

    /// Staircase into an arrow.
    private static func adcDac(_ r: CGRect) -> Path {
        var path = Path()
        let base = r.maxY - r.height * 0.16
        path.move(to: CGPoint(x: r.minX + r.width * 0.06, y: base))
        for index in 0..<3 {
            let x0 = r.minX + r.width * 0.06 + r.width * 0.22 * CGFloat(index)
            let y = base - r.height * 0.20 * CGFloat(index + 1)
            path.addLine(to: CGPoint(x: x0, y: y))
            path.addLine(to: CGPoint(x: x0 + r.width * 0.22, y: y))
        }
        Glyph.arrow(
            &path,
            from: CGPoint(x: r.minX + r.width * 0.72, y: base - r.height * 0.60),
            to: CGPoint(x: r.maxX - r.width * 0.04, y: base - r.height * 0.60),
            head: r.width * 0.10
        )
        return path
    }

    // MARK: - Toolkit · Reference

    /// Book + spine.
    private static func referenceLibrary(_ r: CGRect) -> Path {
        var path = Path()
        let book = r.insetBy(dx: r.width * 0.14, dy: r.height * 0.10)
        path.addRoundedRect(in: book, cornerSize: CGSize(width: 3, height: 3))
        Glyph.line(&path, CGPoint(x: book.minX + book.width * 0.18, y: book.minY), CGPoint(x: book.minX + book.width * 0.18, y: book.maxY))
        return path
    }

    /// Rect + three lines + checkbox.
    private static func panelDirectory(_ r: CGRect) -> Path {
        var path = Path()
        let card = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.08)
        path.addRoundedRect(in: card, cornerSize: CGSize(width: 4, height: 4))
        for index in 0..<3 {
            let y = card.minY + card.height * (0.30 + 0.20 * CGFloat(index))
            Glyph.line(&path, CGPoint(x: card.minX + card.width * 0.16, y: y), CGPoint(x: card.maxX - card.width * 0.28, y: y))
        }
        let box = CGRect(
            x: card.maxX - card.width * 0.22, y: card.minY + card.height * 0.22,
            width: card.width * 0.12, height: card.width * 0.12
        )
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 1.5, height: 1.5))
        return path
    }

    /// Page + 2×2 grid.
    private static func loadWorksheet(_ r: CGRect) -> Path {
        var path = Path()
        let page = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.08)
        path.addRoundedRect(in: page, cornerSize: CGSize(width: 3, height: 3))
        Glyph.line(&path, CGPoint(x: page.midX, y: page.minY + page.height * 0.18), CGPoint(x: page.midX, y: page.maxY - page.height * 0.12))
        Glyph.line(&path, CGPoint(x: page.minX + page.width * 0.14, y: page.midY), CGPoint(x: page.maxX - page.width * 0.14, y: page.midY))
        return path
    }

    /// Conductor end (circle + 3 dots) + list lines.
    private static func cableSchedule(_ r: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: r.minX + r.width * 0.28, y: r.midY)
        Glyph.circle(&path, c, r.width * 0.22)
        for angle in [90.0, 210.0, 330.0] {
            let rad = angle * .pi / 180
            Glyph.circle(
                &path,
                CGPoint(x: c.x + cos(rad) * r.width * 0.10, y: c.y + sin(rad) * r.width * 0.10),
                r.width * 0.035
            )
        }
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.58, y: r.minY + r.height * 0.28), CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.28))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.58, y: r.midY), CGPoint(x: r.maxX - r.width * 0.06, y: r.midY))
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.58, y: r.maxY - r.height * 0.28), CGPoint(x: r.maxX - r.width * 0.16, y: r.maxY - r.height * 0.28))
        return path
    }
}

// MARK: - Shared stroke primitives

private enum Glyph {
    static func line(_ path: inout Path, _ a: CGPoint, _ b: CGPoint) {
        path.move(to: a)
        path.addLine(to: b)
    }

    static func circle(_ path: inout Path, _ center: CGPoint, _ radius: CGFloat) {
        path.addEllipse(in: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    static func lBracket(_ path: inout Path, _ origin: CGPoint, dx: CGFloat, dy: CGFloat) {
        line(&path, origin, CGPoint(x: origin.x + dx, y: origin.y))
        line(&path, origin, CGPoint(x: origin.x, y: origin.y + dy))
    }

    static func arrow(_ path: inout Path, from: CGPoint, to: CGPoint, head: CGFloat) {
        path.move(to: from)
        path.addLine(to: to)
        arrowHead(&path, at: to, toward: from, size: head)
    }

    static func arrowHead(_ path: inout Path, at tip: CGPoint, toward from: CGPoint, size: CGFloat) {
        let dx = tip.x - from.x
        let dy = tip.y - from.y
        let length = max(hypot(dx, dy), 0.001)
        let ux = dx / length
        let uy = dy / length
        path.move(to: tip)
        path.addLine(to: CGPoint(
            x: tip.x - ux * size - uy * size * 0.42,
            y: tip.y - uy * size + ux * size * 0.42
        ))
        path.move(to: tip)
        path.addLine(to: CGPoint(
            x: tip.x - ux * size + uy * size * 0.42,
            y: tip.y - uy * size - ux * size * 0.42
        ))
    }

    static func sine(
        _ path: inout Path,
        in rect: CGRect,
        y: CGFloat,
        amplitude: CGFloat,
        cycles: CGFloat,
        steps: Int = 20
    ) {
        path.move(to: CGPoint(x: rect.minX, y: y))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * t,
                y: y - sin(t * .pi * 2 * cycles) * amplitude
            ))
        }
    }

    static func bolt(_ r: CGRect) -> Path {
        var path = Path()
        let pts = [
            CGPoint(x: r.midX + r.width * 0.12, y: r.minY),
            CGPoint(x: r.midX - r.width * 0.22, y: r.midY + r.height * 0.04),
            CGPoint(x: r.midX - r.width * 0.02, y: r.midY + r.height * 0.04),
            CGPoint(x: r.midX - r.width * 0.16, y: r.maxY),
            CGPoint(x: r.midX + r.width * 0.24, y: r.midY - r.height * 0.04),
            CGPoint(x: r.midX + r.width * 0.04, y: r.midY - r.height * 0.04),
        ]
        path.move(to: pts[0])
        for point in pts.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
