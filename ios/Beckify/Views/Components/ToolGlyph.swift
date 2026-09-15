import SwiftUI

// MARK: - Beckify Flat Glyph System (app-only)
//
// App Design visual pass 2026-09-15 overturns #151 stroke-only lock.
// Stroke-only at 2.6pt read as hollow wireframes at Quick (~52) / grid (~72).
//
// Default ink: solid monochrome fill = category primary, with even-odd holes
// punched through to the well tint (`context.fill(..., eoFill: true)`).
// Never stroke large hollow roundedRect frames.
// Open-only marks stay stroke at dedicated `Theme.Stroke.iconOpen` (3.2 @ 44pt,
// floor 2.2) — voltage-drop sag, Ω, Wi-Fi arcs, sines, arrows. Overlay strokes
// on filled silhouettes keep `Theme.Stroke.icon` at 2.6 (not a global bump).
// P0: receptacle, nec/paperwork, pack, battery/UPS, power, ampacity, conduit,
// motorFLA — then the rest of the shelves.
// No SF Symbols in wells, no Meshy, no dual under-ink. 1:1 ToolID→GlyphKind.
// Design grid is 24×24 with a 10% canvas inset. SF stays on chrome only.

/// Stroke curve for pictogram linework. 44pt is the reference size.
/// Open-only marks use `iconOpen` (3.2, floor 2.2). Overlay ticks on filled
/// silhouettes use `icon` (2.6, floor 1.8). Selected is a slight weight bump.
enum GlyphStroke {
    static let referenceSize: CGFloat = 44
    static let selectedWeight: CGFloat = 1.06
    static let overlayMinimum: CGFloat = 1.8
    static let openMinimum: CGFloat = 2.2

    static func lineWidth(size: CGFloat, selected: Bool, openMark: Bool) -> CGFloat {
        let token = openMark ? Theme.Stroke.iconOpen : Theme.Stroke.icon
        let floor = openMark ? openMinimum : overlayMinimum
        let scaled = token * (size / referenceSize)
        let base = max(floor, scaled)
        return selected ? base * selectedWeight : base
    }
}

/// Fill path (even-odd holes) plus optional stroke, both the same category
/// primary. Fill first so holes cut through to the well tint. `openMark`
/// selects `iconOpen` (3.2 / floor 2.2) vs overlay `icon` (2.6 / floor 1.8).
struct GlyphArtwork {
    var fill: Path?
    var stroke: Path?
    var openMark: Bool

    static func fill(_ path: Path) -> GlyphArtwork {
        GlyphArtwork(fill: path, stroke: nil, openMark: false)
    }

    static func stroke(_ path: Path) -> GlyphArtwork {
        GlyphArtwork(fill: nil, stroke: path, openMark: true)
    }

    static func both(fill: Path, stroke: Path, openMark: Bool = false) -> GlyphArtwork {
        GlyphArtwork(fill: fill, stroke: stroke, openMark: openMark)
    }
}

/// Solid-fill / open-stroke pictogram for one toolbox tool. Drawn as vector
/// paths so it stays crisp at any size, follows the theme, and ships no
/// image assets.
///
/// Each `ToolID` maps 1:1 to a distinct `GlyphKind`. When a category is known
/// the ink is that shelf’s solid primary — never a gradient.
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

    private var ink: Color {
        if let resolvedCategory {
            return Theme.categoryColors(resolvedCategory).primary
        }
        return selected ? Theme.foreground : Theme.muted
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.10, dy: canvasSize.height * 0.10)
            let artwork = kind.artwork(in: rect)
            let shading = GraphicsContext.Shading.color(ink)
            if let fill = artwork.fill {
                context.fill(fill, with: shading, style: FillStyle(eoFill: true))
            }
            if let stroke = artwork.stroke {
                context.stroke(
                    stroke,
                    with: shading,
                    style: StrokeStyle(
                        lineWidth: GlyphStroke.lineWidth(size: size, selected: selected, openMark: artwork.openMark),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Soft colored well that frames a `ToolGlyph` — the graphic unit of the grid
/// and list rows (quiet category tint + solid/open pictogram).
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

/// Shelf mark for a toolbox category — same fill / open-stroke language as tools.
struct CategoryGlyph: View {
    let category: ToolCategory
    var size: CGFloat = 28
    var selected: Bool = true

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.10, dy: canvasSize.height * 0.10)
            let artwork = CategoryGlyphKind(category).artwork(in: rect)
            let shading = GraphicsContext.Shading.color(Theme.categoryColors(category).primary)
            if let fill = artwork.fill {
                context.fill(fill, with: shading, style: FillStyle(eoFill: true))
            }
            if let stroke = artwork.stroke {
                context.stroke(
                    stroke,
                    with: shading,
                    style: StrokeStyle(
                        lineWidth: GlyphStroke.lineWidth(size: size, selected: selected, openMark: artwork.openMark),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
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

    func artwork(in rect: CGRect) -> GlyphArtwork {
        switch self {
        case .field: return Self.field(rect)
        case .power: return Self.power(rect)
        case .controls: return Self.controls(rect)
        case .homework: return Self.homework(rect)
        case .sensors: return Self.sensors(rect)
        case .reference: return Self.reference(rect)
        }
    }

    /// Two posts + sagging span — jobsite / field. Open mark.
    private static func field(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        let y = r.minY + r.height * 0.22
        Glyph.line(&path, CGPoint(x: r.minX + r.width * 0.18, y: y), CGPoint(x: r.minX + r.width * 0.18, y: r.maxY - r.height * 0.08))
        Glyph.line(&path, CGPoint(x: r.maxX - r.width * 0.18, y: y), CGPoint(x: r.maxX - r.width * 0.18, y: r.maxY - r.height * 0.08))
        path.move(to: CGPoint(x: r.minX + r.width * 0.18, y: y))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.18, y: y),
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.72)
        )
        return .stroke(path)
    }

    /// Lightning bolt — closed silhouette, solid fill.
    private static func power(_ r: CGRect) -> GlyphArtwork {
        .fill(Glyph.bolt(r))
    }

    /// Clock bezel + hands — filled ring, open hands.
    private static func controls(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.42
        let fill = Glyph.punched(Glyph.circlePath(c, rad), Glyph.circlePath(c, rad * 0.62))
        var stroke = Path()
        Glyph.line(&stroke, c, CGPoint(x: c.x, y: c.y - rad * 0.52))
        Glyph.line(&stroke, c, CGPoint(x: c.x + rad * 0.38, y: c.y + rad * 0.08))
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// Closed notebook — filled cover + line holes.
    private static func homework(_ r: CGRect) -> GlyphArtwork {
        let page = r.insetBy(dx: r.width * 0.16, dy: r.height * 0.10)
        let body = Glyph.roundedRect(page, corner: 3)
        let slotH = max(2.0, page.height * 0.07)
        let slotW = page.width * 0.64
        let a = Glyph.slot(CGRect(x: page.midX - slotW / 2, y: page.minY + page.height * 0.32 - slotH / 2, width: slotW, height: slotH))
        let b = Glyph.slot(CGRect(x: page.minX + page.width * 0.18, y: page.minY + page.height * 0.52 - slotH / 2, width: slotW * 0.72, height: slotH))
        return .fill(Glyph.punched(body, a, b))
    }

    /// Two upward instrument arcs — open mark.
    private static func sensors(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    /// Book + spine hole.
    private static func reference(_ r: CGRect) -> GlyphArtwork {
        let book = r.insetBy(dx: r.width * 0.16, dy: r.height * 0.10)
        let body = Glyph.roundedRect(book, corner: 3)
        let spine = Glyph.slot(CGRect(
            x: book.minX + book.width * 0.16,
            y: book.minY + book.height * 0.08,
            width: max(2.0, book.width * 0.08),
            height: book.height * 0.84
        ))
        return .fill(Glyph.punched(body, spine))
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

    func artwork(in rect: CGRect) -> GlyphArtwork {
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

    /// Horizontal conductor with one sagging mid span — open mark.
    private static func voltageDrop(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    /// Filled sleeve with three conductor slot holes.
    private static func wireAmpacity(_ r: CGRect) -> GlyphArtwork {
        let sleeve = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.16,
            width: r.width * 0.68, height: r.height * 0.68
        )
        let body = Glyph.roundedRect(sleeve, corner: sleeve.height * 0.18)
        let slotH = max(2.4, sleeve.height * 0.11)
        let slotW = sleeve.width * 0.56
        var holes: [Path] = []
        for index in 0..<3 {
            let y = sleeve.minY + sleeve.height * (0.26 + 0.24 * CGFloat(index)) - slotH / 2
            holes.append(Glyph.slot(CGRect(
                x: sleeve.midX - slotW / 2, y: y, width: slotW, height: slotH
            )))
        }
        return .fill(Glyph.punched(body, holes))
    }

    /// Filled motor can + end-bell hole + shaft stub.
    private static func motorFLA(_ r: CGRect) -> GlyphArtwork {
        let can = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.24,
            width: r.width * 0.62, height: r.height * 0.48
        )
        let body = Glyph.roundedRect(can, corner: can.height * 0.22)
        let bell = Glyph.circlePath(
            CGPoint(x: can.minX + can.height * 0.22, y: can.midY),
            can.height * 0.22
        )
        var stroke = Path()
        Glyph.line(
            &stroke,
            CGPoint(x: can.maxX, y: can.midY),
            CGPoint(x: r.maxX - r.width * 0.06, y: can.midY)
        )
        return .both(fill: Glyph.punched(body, bell), stroke: stroke)
    }

    /// US duplex: filled face + slot holes + ground hole.
    private static func receptacleSelector(_ r: CGRect) -> GlyphArtwork {
        let face = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.08)
        let body = Glyph.roundedRect(face, corner: 5)
        let slotH = face.height * 0.28
        let slotW = max(2.6, face.width * 0.11)
        let slotY = face.minY + face.height * 0.28
        let left = Glyph.slot(CGRect(
            x: face.midX - face.width * 0.18 - slotW / 2, y: slotY,
            width: slotW, height: slotH
        ))
        let right = Glyph.slot(CGRect(
            x: face.midX + face.width * 0.18 - slotW / 2, y: slotY,
            width: slotW, height: slotH
        ))
        let ground = Glyph.circlePath(
            CGPoint(x: face.midX, y: face.maxY - face.height * 0.22),
            face.width * 0.09
        )
        return .fill(Glyph.punched(body, left, right, ground))
    }

    /// Filled AP slab + two upward arcs (open). CoS: 2 max on the waves.
    private static func wifiStatus(_ r: CGRect) -> GlyphArtwork {
        let slab = CGRect(
            x: r.minX + r.width * 0.20, y: r.maxY - r.height * 0.24,
            width: r.width * 0.60, height: r.height * 0.16
        )
        let fill = Glyph.roundedRect(slab, corner: slab.height * 0.45)
        var stroke = Path()
        let origin = CGPoint(x: r.midX, y: slab.minY)
        for index in 1...2 {
            stroke.addArc(
                center: origin,
                radius: r.width * 0.24 * CGFloat(index),
                startAngle: .degrees(210),
                endAngle: .degrees(330),
                clockwise: false
            )
        }
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// Filled conduit ring + inner conductor (even-odd restores the core).
    private static func conduitFill(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) * 0.46
        let body = Glyph.circlePath(c, outer)
        let hole = Glyph.circlePath(c, outer * 0.62)
        let conductor = Glyph.circlePath(
            CGPoint(x: r.midX, y: r.midY + outer * 0.14),
            outer * 0.24
        )
        return .fill(Glyph.punched(body, hole, conductor))
    }

    // MARK: - Field · Jobsite

    /// Filled spool (annulus) + stand strokes + filled price tag.
    private static func conductorCost(_ r: CGRect) -> GlyphArtwork {
        let hub = CGPoint(x: r.minX + r.width * 0.36, y: r.midY - r.height * 0.04)
        let spool = Glyph.punched(
            Glyph.circlePath(hub, r.width * 0.26),
            Glyph.circlePath(hub, r.width * 0.10)
        )
        let tag = Glyph.roundedRect(
            CGRect(x: r.maxX - r.width * 0.36, y: r.minY + r.height * 0.12, width: r.width * 0.32, height: r.height * 0.28),
            corner: 3
        )
        var fill = spool
        fill.addPath(tag)
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: hub.x - r.width * 0.16, y: r.maxY - r.height * 0.08), CGPoint(x: hub.x, y: hub.y + r.width * 0.26))
        Glyph.line(&stroke, CGPoint(x: hub.x + r.width * 0.16, y: r.maxY - r.height * 0.08), CGPoint(x: hub.x, y: hub.y + r.width * 0.26))
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled tape case + curved tape stroke.
    private static func conductorLength(_ r: CGRect) -> GlyphArtwork {
        let box = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.28,
            width: r.width * 0.42, height: r.height * 0.44
        )
        let fill = Glyph.roundedRect(box, corner: 3)
        var stroke = Path()
        stroke.move(to: CGPoint(x: box.maxX, y: box.midY))
        stroke.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.16),
            control: CGPoint(x: r.maxX - r.width * 0.10, y: box.minY - r.height * 0.08)
        )
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled breaker block + handle / chevron strokes.
    private static func shortCircuit(_ r: CGRect) -> GlyphArtwork {
        let block = CGRect(
            x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.38,
            width: r.width * 0.44, height: r.height * 0.44
        )
        let fill = Glyph.roundedRect(block, corner: 3)
        var stroke = Path()
        Glyph.line(
            &stroke,
            CGPoint(x: r.midX, y: r.minY + r.height * 0.08),
            CGPoint(x: r.midX, y: block.minY)
        )
        stroke.move(to: CGPoint(x: r.midX - r.width * 0.14, y: r.minY + r.height * 0.22))
        stroke.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.10))
        stroke.addLine(to: CGPoint(x: r.midX + r.width * 0.14, y: r.minY + r.height * 0.22))
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled annulus.
    private static func circularMils(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) * 0.44
        return .fill(Glyph.punched(Glyph.circlePath(c, outer), Glyph.circlePath(c, outer * 0.48)))
    }

    /// Three filled demand bars.
    private static func loadFactors(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        let heights: [CGFloat] = [0.36, 0.56, 0.78]
        for (index, height) in heights.enumerated() {
            let x = r.minX + r.width * (0.16 + 0.28 * CGFloat(index))
            path.addPath(Glyph.roundedRect(
                CGRect(x: x, y: r.maxY - r.height * height, width: r.width * 0.20, height: r.height * height),
                corner: 2.5
            ))
        }
        return .fill(path)
    }

    /// Filled panelboard + three breaker slot holes.
    private static func necCircuit(_ r: CGRect) -> GlyphArtwork {
        let panel = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.08)
        let body = Glyph.roundedRect(panel, corner: 4)
        let slotH = max(2.4, panel.height * 0.10)
        let slotW = panel.width * 0.64
        var holes: [Path] = []
        for index in 0..<3 {
            let y = panel.minY + panel.height * (0.26 + 0.22 * CGFloat(index)) - slotH / 2
            holes.append(Glyph.slot(CGRect(
                x: panel.midX - slotW / 2, y: y, width: slotW, height: slotH
            )))
        }
        return .fill(Glyph.punched(body, holes))
    }

    /// Loop with a break + probe tip — open mark.
    private static func isLoopVerifier(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    /// Filled motor can + shaft / rotation arrow strokes.
    private static func motorSpeed(_ r: CGRect) -> GlyphArtwork {
        let can = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.28,
            width: r.width * 0.48, height: r.height * 0.36
        )
        let fill = Glyph.roundedRect(can, corner: 4)
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: can.maxX, y: can.midY), CGPoint(x: r.maxX - r.width * 0.18, y: can.midY))
        let shaft = CGPoint(x: r.maxX - r.width * 0.22, y: can.midY)
        stroke.addArc(
            center: shaft,
            radius: r.width * 0.28,
            startAngle: .degrees(-20),
            endAngle: .degrees(210),
            clockwise: false
        )
        Glyph.arrowHead(
            &stroke,
            at: CGPoint(x: shaft.x + r.width * 0.26, y: shaft.y - r.height * 0.06),
            toward: CGPoint(x: shaft.x + r.width * 0.18, y: shaft.y - r.height * 0.16),
            size: r.width * 0.10
        )
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// Filled plate + two data-line holes.
    private static func motorNameplate(_ r: CGRect) -> GlyphArtwork {
        let plate = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.18)
        let body = Glyph.roundedRect(plate, corner: 4)
        let slotH = max(2.0, plate.height * 0.10)
        let a = Glyph.slot(CGRect(
            x: plate.minX + plate.width * 0.16,
            y: plate.minY + plate.height * 0.38 - slotH / 2,
            width: plate.width * 0.68, height: slotH
        ))
        let b = Glyph.slot(CGRect(
            x: plate.minX + plate.width * 0.16,
            y: plate.minY + plate.height * 0.62 - slotH / 2,
            width: plate.width * 0.56, height: slotH
        ))
        return .fill(Glyph.punched(body, a, b))
    }

    /// Filled nameplate + camera L brackets (open).
    private static func motorNameplateOCR(_ r: CGRect) -> GlyphArtwork {
        let plate = CGRect(
            x: r.minX + r.width * 0.20, y: r.minY + r.height * 0.26,
            width: r.width * 0.60, height: r.height * 0.48
        )
        let body = Glyph.roundedRect(plate, corner: 3)
        let slotH = max(2.0, plate.height * 0.12)
        let slot = Glyph.slot(CGRect(
            x: plate.minX + plate.width * 0.16,
            y: plate.midY - slotH / 2,
            width: plate.width * 0.68, height: slotH
        ))
        var stroke = Path()
        let arm = min(r.width, r.height) * 0.16
        Glyph.lBracket(&stroke, CGPoint(x: r.minX + r.width * 0.04, y: r.minY + r.height * 0.06), dx: arm, dy: arm)
        Glyph.lBracket(&stroke, CGPoint(x: r.maxX - r.width * 0.04, y: r.minY + r.height * 0.06), dx: -arm, dy: arm)
        Glyph.lBracket(&stroke, CGPoint(x: r.minX + r.width * 0.04, y: r.maxY - r.height * 0.06), dx: arm, dy: -arm)
        Glyph.lBracket(&stroke, CGPoint(x: r.maxX - r.width * 0.04, y: r.maxY - r.height * 0.06), dx: -arm, dy: -arm)
        return .both(fill: Glyph.punched(body, slot), stroke: stroke)
    }

    /// Filled almond eye + pupil hole — Look Check, not OCR.
    private static func lookCheck(_ r: CGRect) -> GlyphArtwork {
        var eye = Path()
        eye.move(to: CGPoint(x: r.minX + r.width * 0.06, y: r.midY))
        eye.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.midY),
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.08)
        )
        eye.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.06, y: r.midY),
            control: CGPoint(x: r.midX, y: r.maxY - r.height * 0.08)
        )
        eye.closeSubpath()
        let pupil = Glyph.circlePath(CGPoint(x: r.midX, y: r.midY), r.width * 0.14)
        return .fill(Glyph.punched(eye, pupil))
    }

    // MARK: - Field · Power

    private static func power(_ r: CGRect) -> GlyphArtwork {
        .fill(Glyph.bolt(r))
    }

    /// Filled bolt + two-ray star (open).
    private static func powerWizard(_ r: CGRect) -> GlyphArtwork {
        var stroke = Path()
        let star = CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.14)
        Glyph.line(&stroke, CGPoint(x: star.x, y: star.y - r.height * 0.12), CGPoint(x: star.x, y: star.y + r.height * 0.12))
        Glyph.line(&stroke, CGPoint(x: star.x - r.width * 0.12, y: star.y), CGPoint(x: star.x + r.width * 0.12, y: star.y))
        return .both(fill: Glyph.bolt(r), stroke: stroke, openMark: true)
    }

    /// Two filled coil rings + core bar stroke.
    private static func transformer(_ r: CGRect) -> GlyphArtwork {
        let left = CGRect(
            x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.12,
            width: r.width * 0.28, height: r.height * 0.76
        )
        let right = CGRect(
            x: r.maxX - r.width * 0.38, y: r.minY + r.height * 0.12,
            width: r.width * 0.28, height: r.height * 0.76
        )
        var fill = Glyph.punched(
            Path(ellipseIn: left),
            Path(ellipseIn: left.insetBy(dx: left.width * 0.28, dy: left.height * 0.14))
        )
        fill.addPath(Glyph.punched(
            Path(ellipseIn: right),
            Path(ellipseIn: right.insetBy(dx: right.width * 0.28, dy: right.height * 0.14))
        ))
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.midX, y: r.minY + r.height * 0.10), CGPoint(x: r.midX, y: r.maxY - r.height * 0.10))
        return .both(fill: fill, stroke: stroke)
    }

    /// Transformer coils + tap arrow.
    private static func tapChanger(_ r: CGRect) -> GlyphArtwork {
        let base = transformer(r)
        var stroke = base.stroke ?? Path()
        Glyph.arrow(
            &stroke,
            from: CGPoint(x: r.midX + r.width * 0.08, y: r.minY + r.height * 0.18),
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.34),
            head: r.width * 0.10
        )
        return .both(fill: base.fill ?? Path(), stroke: stroke, openMark: true)
    }

    /// Filled right triangle.
    private static func powerFactor(_ r: CGRect) -> GlyphArtwork {
        let origin = CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.12)
        return .fill(Glyph.triangle(
            origin,
            CGPoint(x: r.maxX - r.width * 0.10, y: origin.y),
            CGPoint(x: origin.x, y: r.minY + r.height * 0.12)
        ))
    }

    /// Fundamental sine + higher-frequency ripple — open mark.
    private static func harmonicsTHD(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        Glyph.sine(&path, in: r, y: r.midY, amplitude: r.height * 0.28, cycles: 1)
        Glyph.sine(&path, in: r, y: r.midY, amplitude: r.height * 0.10, cycles: 3)
        return .stroke(path)
    }

    /// Filled battery + nub + two cell-gap holes.
    private static func batteryBank(_ r: CGRect) -> GlyphArtwork {
        let body = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.26,
            width: r.width * 0.72, height: r.height * 0.48
        )
        var fill = Glyph.roundedRect(body, corner: 3)
        fill.addPath(Glyph.roundedRect(
            CGRect(x: body.maxX, y: body.midY - r.height * 0.10, width: r.width * 0.10, height: r.height * 0.20),
            corner: 1.5
        ))
        let gapW = max(2.2, body.width * 0.08)
        let gapH = body.height * 0.62
        let gapY = body.midY - gapH / 2
        let g1 = Glyph.slot(CGRect(x: body.minX + body.width * 0.30 - gapW / 2, y: gapY, width: gapW, height: gapH))
        let g2 = Glyph.slot(CGRect(x: body.minX + body.width * 0.62 - gapW / 2, y: gapY, width: gapW, height: gapH))
        return .fill(Glyph.punched(fill, g1, g2))
    }

    /// Filled tilted panel + sun arc stroke.
    private static func solarDesign(_ r: CGRect) -> GlyphArtwork {
        var panel = Path()
        panel.move(to: CGPoint(x: r.minX + r.width * 0.10, y: r.maxY - r.height * 0.16))
        panel.addLine(to: CGPoint(x: r.minX + r.width * 0.62, y: r.maxY - r.height * 0.12))
        panel.addLine(to: CGPoint(x: r.minX + r.width * 0.78, y: r.minY + r.height * 0.42))
        panel.addLine(to: CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.38))
        panel.closeSubpath()
        var stroke = Path()
        let sun = CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.22)
        stroke.addArc(center: sun, radius: r.width * 0.16, startAngle: .degrees(200), endAngle: .degrees(20), clockwise: false)
        return .both(fill: panel, stroke: stroke, openMark: true)
    }

    /// Filled battery + gap hole + shield arc stroke.
    private static func upsSizing(_ r: CGRect) -> GlyphArtwork {
        let body = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.32,
            width: r.width * 0.52, height: r.height * 0.40
        )
        var fill = Glyph.roundedRect(body, corner: 3)
        fill.addPath(Path(CGRect(x: body.maxX, y: body.midY - r.height * 0.08, width: r.width * 0.08, height: r.height * 0.16)))
        let gapW = max(2.2, body.width * 0.12)
        let gapH = body.height * 0.58
        let gap = Glyph.slot(CGRect(
            x: body.midX - gapW / 2, y: body.midY - gapH / 2,
            width: gapW, height: gapH
        ))
        var stroke = Path()
        stroke.addArc(
            center: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.28),
            radius: r.width * 0.28,
            startAngle: .degrees(210),
            endAngle: .degrees(330),
            clockwise: false
        )
        return .both(fill: Glyph.punched(fill, gap), stroke: stroke, openMark: true)
    }

    // MARK: - Field · Controls

    /// Filled amp triangle with I/O stubs.
    private static func signalScaling(_ r: CGRect) -> GlyphArtwork {
        let left = r.minX + r.width * 0.22
        let fill = Glyph.triangle(
            CGPoint(x: left, y: r.minY + r.height * 0.14),
            CGPoint(x: r.maxX - r.width * 0.12, y: r.midY),
            CGPoint(x: left, y: r.maxY - r.height * 0.14)
        )
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.minX, y: r.minY + r.height * 0.32), CGPoint(x: left, y: r.minY + r.height * 0.32))
        Glyph.line(&stroke, CGPoint(x: r.minX, y: r.maxY - r.height * 0.32), CGPoint(x: left, y: r.maxY - r.height * 0.32))
        Glyph.line(&stroke, CGPoint(x: r.maxX - r.width * 0.12, y: r.midY), CGPoint(x: r.maxX, y: r.midY))
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled jack + three pin holes.
    private static func modbusAddress(_ r: CGRect) -> GlyphArtwork {
        let jack = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.18,
            width: r.width * 0.68, height: r.height * 0.64
        )
        let body = Glyph.roundedRect(jack, corner: 3)
        var holes: [Path] = []
        for index in 0..<3 {
            let x = jack.minX + jack.width * (0.28 + 0.22 * CGFloat(index))
            holes.append(Glyph.circlePath(CGPoint(x: x, y: jack.minY + jack.height * 0.42), r.width * 0.055))
        }
        return .fill(Glyph.punched(body, holes))
    }

    /// Filled clock bezel + two hands.
    private static func plcTimer(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.44
        let fill = Glyph.punched(Glyph.circlePath(c, rad), Glyph.circlePath(c, rad * 0.62))
        var stroke = Path()
        Glyph.line(&stroke, c, CGPoint(x: c.x, y: c.y - r.height * 0.26))
        Glyph.line(&stroke, c, CGPoint(x: c.x + r.width * 0.22, y: c.y + r.height * 0.06))
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// Filled rack unit + two rail holes.
    private static func rackCurrent(_ r: CGRect) -> GlyphArtwork {
        let frame = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.10)
        let body = Glyph.roundedRect(frame, corner: 3)
        let slotH = max(2.0, frame.height * 0.10)
        let slotW = frame.width * 0.70
        let a = Glyph.slot(CGRect(
            x: frame.minX + frame.width * 0.18, y: frame.minY + frame.height * 0.32 - slotH / 2,
            width: slotW * 0.90, height: slotH
        ))
        let b = Glyph.slot(CGRect(
            x: frame.minX + frame.width * 0.18, y: frame.minY + frame.height * 0.62 - slotH / 2,
            width: slotW * 0.90, height: slotH
        ))
        return .fill(Glyph.punched(body, a, b))
    }

    /// Feedback circle + one arrow — open mark.
    private static func controlSystems(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.40
        path.addArc(center: c, radius: rad, startAngle: .degrees(-10), endAngle: .degrees(300), clockwise: false)
        let tip = CGPoint(x: c.x + rad, y: c.y)
        Glyph.arrowHead(&path, at: tip, toward: CGPoint(x: tip.x, y: tip.y + r.height * 0.12), size: r.width * 0.12)
        return .stroke(path)
    }

    // MARK: - Field · Instruments

    /// Filled phone + two bars.
    private static func cellularStatus(_ r: CGRect) -> GlyphArtwork {
        let phone = CGRect(
            x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.12,
            width: r.width * 0.40, height: r.height * 0.76
        )
        let fill = Glyph.roundedRect(phone, corner: 4)
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.64, y: r.maxY - r.height * 0.16), CGPoint(x: r.minX + r.width * 0.64, y: r.maxY - r.height * 0.42))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.80, y: r.maxY - r.height * 0.16), CGPoint(x: r.minX + r.width * 0.80, y: r.maxY - r.height * 0.68))
        return .both(fill: fill, stroke: stroke)
    }

    /// Geometric Bluetooth rune — open mark.
    private static func bluetoothScan(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    /// Filled mic capsule + stem / sound arcs.
    private static func noiseMeter(_ r: CGRect) -> GlyphArtwork {
        let mic = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.16,
            width: r.width * 0.32, height: r.height * 0.48
        )
        let fill = Glyph.roundedRect(mic, corner: mic.width * 0.48)
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: mic.midX, y: mic.maxY), CGPoint(x: mic.midX, y: r.maxY - r.height * 0.12))
        let origin = CGPoint(x: r.maxX - r.width * 0.28, y: r.midY - r.height * 0.06)
        for index in 1...2 {
            stroke.addArc(
                center: origin,
                radius: r.width * 0.16 * CGFloat(index),
                startAngle: .degrees(-55),
                endAngle: .degrees(55),
                clockwise: false
            )
        }
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// Filled capsule + offset bubble hole.
    private static func bubbleLevel(_ r: CGRect) -> GlyphArtwork {
        let tube = CGRect(
            x: r.minX + r.width * 0.04, y: r.midY - r.height * 0.16,
            width: r.width * 0.92, height: r.height * 0.32
        )
        let body = Glyph.roundedRect(tube, corner: tube.height / 2)
        let bubble = Glyph.circlePath(CGPoint(x: r.midX + r.width * 0.14, y: r.midY), r.height * 0.10)
        return .fill(Glyph.punched(body, bubble))
    }

    /// Horseshoe magnet — open mark.
    private static func magnetometer(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        let c = CGPoint(x: r.midX, y: r.midY - r.height * 0.06)
        path.addArc(center: c, radius: r.width * 0.32, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        let left = CGPoint(x: c.x + cos(200 * .pi / 180) * r.width * 0.32, y: c.y + sin(200 * .pi / 180) * r.width * 0.32)
        let right = CGPoint(x: c.x + cos(340 * .pi / 180) * r.width * 0.32, y: c.y + sin(340 * .pi / 180) * r.width * 0.32)
        Glyph.line(&path, left, CGPoint(x: left.x, y: r.maxY - r.height * 0.08))
        Glyph.line(&path, right, CGPoint(x: right.x, y: r.maxY - r.height * 0.08))
        return .stroke(path)
    }

    /// Filled gauge bezel + needle.
    private static func barometer(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.44
        let fill = Glyph.punched(Glyph.circlePath(c, rad), Glyph.circlePath(c, rad * 0.62))
        var stroke = Path()
        Glyph.line(&stroke, c, CGPoint(x: c.x + r.width * 0.22, y: c.y - r.height * 0.22))
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// Filled phone + double-headed vertical arrow.
    private static func motionSnapshot(_ r: CGRect) -> GlyphArtwork {
        let phone = CGRect(
            x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.08,
            width: r.width * 0.36, height: r.height * 0.84
        )
        let fill = Glyph.roundedRect(phone, corner: 4)
        var stroke = Path()
        let x = r.maxX - r.width * 0.18
        Glyph.arrow(&stroke, from: CGPoint(x: x, y: r.midY), to: CGPoint(x: x, y: r.minY + r.height * 0.12), head: r.width * 0.10)
        Glyph.arrow(&stroke, from: CGPoint(x: x, y: r.midY), to: CGPoint(x: x, y: r.maxY - r.height * 0.12), head: r.width * 0.10)
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// Filled map-pin teardrop + inner hole.
    private static func fieldPosition(_ r: CGRect) -> GlyphArtwork {
        var pin = Path()
        let tip = CGPoint(x: r.midX, y: r.maxY - r.height * 0.04)
        pin.move(to: tip)
        pin.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.14, y: r.minY + r.height * 0.36),
            control: CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.28)
        )
        pin.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.36),
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.02)
        )
        pin.addQuadCurve(
            to: tip,
            control: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.28)
        )
        pin.closeSubpath()
        let hole = Glyph.circlePath(CGPoint(x: r.midX, y: r.minY + r.height * 0.34), r.width * 0.12)
        return .fill(Glyph.punched(pin, hole))
    }

    /// Filled monitor + heartbeat ribbon hole.
    private static func deviceHealth(_ r: CGRect) -> GlyphArtwork {
        let frame = r.insetBy(dx: r.width * 0.06, dy: r.height * 0.18)
        let body = Glyph.roundedRect(frame, corner: 4)
        let y = frame.midY
        let pulse = Glyph.ribbon([
            CGPoint(x: frame.minX + frame.width * 0.10, y: y),
            CGPoint(x: frame.minX + frame.width * 0.28, y: y),
            CGPoint(x: frame.minX + frame.width * 0.38, y: y - frame.height * 0.32),
            CGPoint(x: frame.minX + frame.width * 0.52, y: y + frame.height * 0.36),
            CGPoint(x: frame.minX + frame.width * 0.64, y: y),
            CGPoint(x: frame.maxX - frame.width * 0.10, y: y),
        ], width: max(2.2, frame.height * 0.12))
        return .fill(Glyph.punched(body, pulse))
    }

    // MARK: - Toolkit · Basics

    /// Bold Ω — not a resistor zigzag. Open mark.
    private static func ohmsLaw(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    /// Two filled bodies on a vertical run.
    private static func voltageDivider(_ r: CGRect) -> GlyphArtwork {
        let x = r.midX
        let top = Glyph.roundedRect(
            CGRect(x: x - r.width * 0.22, y: r.minY + r.height * 0.16, width: r.width * 0.44, height: r.height * 0.18),
            corner: 2
        )
        let bot = Glyph.roundedRect(
            CGRect(x: x - r.width * 0.22, y: r.maxY - r.height * 0.34, width: r.width * 0.44, height: r.height * 0.18),
            corner: 2
        )
        var fill = top
        fill.addPath(bot)
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: x, y: r.minY), CGPoint(x: x, y: r.maxY))
        Glyph.line(&stroke, CGPoint(x: x, y: r.midY), CGPoint(x: r.maxX - r.width * 0.06, y: r.midY))
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled series body, parallel fork stroke.
    private static func seriesParallel(_ r: CGRect) -> GlyphArtwork {
        let y = r.midY
        let fill = Glyph.roundedRect(
            CGRect(x: r.minX + r.width * 0.10, y: y - r.height * 0.10, width: r.width * 0.22, height: r.height * 0.20),
            corner: 2
        )
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.10, y: y))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.32, y: y), CGPoint(x: r.minX + r.width * 0.46, y: y))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.46, y: y - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.46, y: y + r.height * 0.22))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.46, y: y - r.height * 0.22), CGPoint(x: r.maxX - r.width * 0.06, y: y - r.height * 0.22))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.46, y: y + r.height * 0.22), CGPoint(x: r.maxX - r.width * 0.06, y: y + r.height * 0.22))
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled capsule + three band holes.
    private static func resistorColor(_ r: CGRect) -> GlyphArtwork {
        let body = CGRect(
            x: r.minX + r.width * 0.12, y: r.midY - r.height * 0.16,
            width: r.width * 0.76, height: r.height * 0.32
        )
        let fill = Glyph.roundedRect(body, corner: body.height / 2)
        let bandW = max(2.2, body.width * 0.08)
        var holes: [Path] = []
        for fraction in [0.28, 0.50, 0.72] as [CGFloat] {
            holes.append(Glyph.slot(CGRect(
                x: body.minX + body.width * fraction - bandW / 2,
                y: body.minY + 2,
                width: bandW,
                height: body.height - 4
            )))
        }
        return .fill(Glyph.punched(fill, holes))
    }

    /// Two filled unit blocks with a swap.
    private static func unitConverter(_ r: CGRect) -> GlyphArtwork {
        let a = Glyph.roundedRect(
            CGRect(x: r.minX, y: r.minY + r.height * 0.22, width: r.width * 0.32, height: r.height * 0.56),
            corner: 3
        )
        let b = Glyph.roundedRect(
            CGRect(x: r.maxX - r.width * 0.32, y: r.minY + r.height * 0.22, width: r.width * 0.32, height: r.height * 0.56),
            corner: 3
        )
        var fill = a
        fill.addPath(b)
        var stroke = Path()
        Glyph.arrow(&stroke, from: CGPoint(x: r.minX + r.width * 0.36, y: r.midY - r.height * 0.10), to: CGPoint(x: r.maxX - r.width * 0.36, y: r.midY - r.height * 0.10), head: r.width * 0.08)
        Glyph.arrow(&stroke, from: CGPoint(x: r.maxX - r.width * 0.36, y: r.midY + r.height * 0.10), to: CGPoint(x: r.minX + r.width * 0.36, y: r.midY + r.height * 0.10), head: r.width * 0.08)
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// One sine period — open mark.
    private static func frequencyWave(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        Glyph.sine(&path, in: r, y: r.midY, amplitude: r.height * 0.32, cycles: 1)
        return .stroke(path)
    }

    /// Filled diode + capacitor plates.
    private static func ledRC(_ r: CGRect) -> GlyphArtwork {
        let y = r.midY
        let fill = Glyph.triangle(
            CGPoint(x: r.minX + r.width * 0.08, y: y - r.height * 0.20),
            CGPoint(x: r.minX + r.width * 0.36, y: y),
            CGPoint(x: r.minX + r.width * 0.08, y: y + r.height * 0.20)
        )
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.36, y: y - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.36, y: y + r.height * 0.22))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.58, y: y - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.58, y: y + r.height * 0.22))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.70, y: y - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.70, y: y + r.height * 0.22))
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled DIP body + side pins.
    private static func timer555(_ r: CGRect) -> GlyphArtwork {
        let body = r.insetBy(dx: r.width * 0.22, dy: r.height * 0.16)
        let fill = Glyph.roundedRect(body, corner: 3)
        var stroke = Path()
        for index in 0..<3 {
            let y = body.minY + body.height * (0.22 + 0.28 * CGFloat(index))
            Glyph.line(&stroke, CGPoint(x: body.minX, y: y), CGPoint(x: r.minX + r.width * 0.08, y: y))
            Glyph.line(&stroke, CGPoint(x: body.maxX, y: y), CGPoint(x: r.maxX - r.width * 0.08, y: y))
        }
        return .both(fill: fill, stroke: stroke)
    }

    /// Three-loop inductor — open mark.
    private static func reactance(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    /// Origin + one phasor — open mark.
    private static func phasorDiagram(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    /// Two filled rounded squares.
    private static func numberBase(_ r: CGRect) -> GlyphArtwork {
        var fill = Glyph.roundedRect(
            CGRect(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.22, width: r.width * 0.38, height: r.height * 0.56),
            corner: 4
        )
        fill.addPath(Glyph.roundedRect(
            CGRect(x: r.maxX - r.width * 0.44, y: r.minY + r.height * 0.22, width: r.width * 0.38, height: r.height * 0.56),
            corner: 4
        ))
        return .fill(fill)
    }

    /// C-core with a gap — open mark.
    private static func magneticCircuit(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        let c = CGPoint(x: r.midX - r.width * 0.06, y: r.midY)
        path.addArc(center: c, radius: r.width * 0.38, startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false)
        return .stroke(path)
    }

    /// Filled cable end + light cone.
    private static func fiberLink(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.minX + r.width * 0.22, y: r.midY)
        let fill = Glyph.punched(Glyph.circlePath(c, r.width * 0.16), Glyph.circlePath(c, r.width * 0.07))
        var stroke = Path()
        stroke.move(to: CGPoint(x: r.minX + r.width * 0.38, y: r.midY))
        stroke.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.16))
        stroke.move(to: CGPoint(x: r.minX + r.width * 0.38, y: r.midY))
        stroke.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.16))
        return .both(fill: fill, stroke: stroke)
    }

    /// Beam waist — open mark.
    private static func gaussianBeam(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    /// Rising exponential — open mark.
    private static func transientCircuit(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.06, y: r.maxY - r.height * 0.10))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.16),
            control: CGPoint(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.22)
        )
        return .stroke(path)
    }

    /// Filled diode triangle + bar / leads.
    private static func diodeIV(_ r: CGRect) -> GlyphArtwork {
        let y = r.midY
        let fill = Glyph.triangle(
            CGPoint(x: r.minX + r.width * 0.16, y: y - r.height * 0.24),
            CGPoint(x: r.midX + r.width * 0.10, y: y),
            CGPoint(x: r.minX + r.width * 0.16, y: y + r.height * 0.24)
        )
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.midX + r.width * 0.10, y: y - r.height * 0.26), CGPoint(x: r.midX + r.width * 0.10, y: y + r.height * 0.26))
        Glyph.line(&stroke, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.16, y: y))
        Glyph.line(&stroke, CGPoint(x: r.midX + r.width * 0.10, y: y), CGPoint(x: r.maxX, y: y))
        return .both(fill: fill, stroke: stroke)
    }

    /// Mast + two side broadcast arcs — open mark.
    private static func rfLink(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    // MARK: - Toolkit · Bench

    /// Filled heater body + zigzag element hole.
    private static func heaterDesign(_ r: CGRect) -> GlyphArtwork {
        let box = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.18)
        let body = Glyph.roundedRect(box, corner: 3)
        let y = box.midY
        let zig = Glyph.ribbon([
            CGPoint(x: box.minX + box.width * 0.12, y: y),
            CGPoint(x: box.minX + box.width * 0.32, y: y - box.height * 0.28),
            CGPoint(x: box.minX + box.width * 0.52, y: y + box.height * 0.28),
            CGPoint(x: box.minX + box.width * 0.72, y: y - box.height * 0.28),
            CGPoint(x: box.maxX - box.width * 0.12, y: y),
        ], width: max(2.4, box.height * 0.12))
        return .fill(Glyph.punched(body, zig))
    }

    /// Filled coil cylinder + plunger stroke.
    private static func solenoidDesign(_ r: CGRect) -> GlyphArtwork {
        let body = CGRect(
            x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.22,
            width: r.width * 0.58, height: r.height * 0.56
        )
        let fill = Glyph.roundedRect(body, corner: 4)
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: body.maxX, y: body.midY), CGPoint(x: r.maxX - r.width * 0.06, y: body.midY))
        Glyph.line(
            &stroke,
            CGPoint(x: r.maxX - r.width * 0.18, y: body.midY - r.height * 0.12),
            CGPoint(x: r.maxX - r.width * 0.18, y: body.midY + r.height * 0.12)
        )
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled hex Faraday cage + inner hex hole.
    private static func empEmc(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.44
        return .fill(Glyph.punched(
            Glyph.regularPolygon(center: c, radius: rad, sides: 6),
            Glyph.regularPolygon(center: c, radius: rad * 0.55, sides: 6)
        ))
    }

    /// Filled chainring + crank arm.
    private static func eBikeTorqueRPM(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.34
        let fill = Glyph.punched(Glyph.circlePath(c, rad), Glyph.circlePath(c, rad * 0.28))
        var stroke = Path()
        Glyph.line(&stroke, c, CGPoint(x: c.x + rad * 1.35, y: c.y + rad * 0.55))
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled sprocket + six teeth.
    private static func eBikeSprocket(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) * 0.34
        let fill = Glyph.punched(Glyph.circlePath(c, rad), Glyph.circlePath(c, rad * 0.28))
        var stroke = Path()
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            Glyph.line(
                &stroke,
                CGPoint(x: c.x + cos(angle) * rad, y: c.y + sin(angle) * rad),
                CGPoint(x: c.x + cos(angle) * rad * 1.28, y: c.y + sin(angle) * rad * 1.28)
            )
        }
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled battery + range gauge arc.
    private static func eBikeRange(_ r: CGRect) -> GlyphArtwork {
        let body = CGRect(
            x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.18,
            width: r.width * 0.42, height: r.height * 0.28
        )
        var fill = Glyph.roundedRect(body, corner: 3)
        fill.addPath(Path(CGRect(x: body.maxX, y: body.midY - r.height * 0.06, width: r.width * 0.07, height: r.height * 0.12)))
        var stroke = Path()
        let gauge = CGPoint(x: r.midX, y: r.maxY - r.height * 0.12)
        stroke.addArc(center: gauge, radius: r.width * 0.36, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        Glyph.line(&stroke, gauge, CGPoint(x: gauge.x + r.width * 0.18, y: gauge.y - r.height * 0.22))
        return .both(fill: fill, stroke: stroke, openMark: true)
    }

    /// Filled pack + 2×3 cell holes.
    private static func eBikePackDesigner(_ r: CGRect) -> GlyphArtwork {
        let pack = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.16)
        let body = Glyph.roundedRect(pack, corner: 4)
        let insetX = pack.width * 0.10
        let insetY = pack.height * 0.10
        let gapX = pack.width * 0.08
        let gapY = pack.height * 0.07
        let cellW = (pack.width - insetX * 2 - gapX) / 2
        let cellH = (pack.height - insetY * 2 - gapY * 2) / 3
        var holes: [Path] = []
        for row in 0..<3 {
            for col in 0..<2 {
                let x = pack.minX + insetX + CGFloat(col) * (cellW + gapX)
                let y = pack.minY + insetY + CGFloat(row) * (cellH + gapY)
                holes.append(Glyph.roundedRect(CGRect(x: x, y: y, width: cellW, height: cellH), corner: 2))
            }
        }
        return .fill(Glyph.punched(body, holes))
    }

    /// Filled long strip + tab.
    private static func nickelStrip(_ r: CGRect) -> GlyphArtwork {
        let strip = CGRect(
            x: r.minX + r.width * 0.08, y: r.midY - r.height * 0.12,
            width: r.width * 0.72, height: r.height * 0.24
        )
        var fill = Glyph.roundedRect(strip, corner: 2)
        fill.addPath(Glyph.roundedRect(
            CGRect(x: strip.maxX, y: strip.midY - r.height * 0.06, width: r.width * 0.12, height: r.height * 0.12),
            corner: 1.5
        ))
        return .fill(fill)
    }

    /// Filled op-amp triangle with +/− holes and I/O stubs.
    private static func analogWorkbench(_ r: CGRect) -> GlyphArtwork {
        let left = r.minX + r.width * 0.22
        let triangle = Glyph.triangle(
            CGPoint(x: left, y: r.minY + r.height * 0.12),
            CGPoint(x: r.maxX - r.width * 0.10, y: r.midY),
            CGPoint(x: left, y: r.maxY - r.height * 0.12)
        )
        let plusY = r.minY + r.height * 0.30
        let plus = Glyph.plus(
            center: CGPoint(x: left + r.width * 0.13, y: plusY),
            arm: r.width * 0.055,
            thickness: max(1.8, r.width * 0.045)
        )
        let minus = Glyph.slot(CGRect(
            x: left + r.width * 0.08,
            y: r.maxY - r.height * 0.30 - max(1.2, r.height * 0.025),
            width: r.width * 0.10,
            height: max(2.0, r.height * 0.05)
        ))
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.minX, y: r.minY + r.height * 0.30), CGPoint(x: left, y: r.minY + r.height * 0.30))
        Glyph.line(&stroke, CGPoint(x: r.minX, y: r.maxY - r.height * 0.30), CGPoint(x: left, y: r.maxY - r.height * 0.30))
        Glyph.line(&stroke, CGPoint(x: r.maxX - r.width * 0.10, y: r.midY), CGPoint(x: r.maxX, y: r.midY))
        return .both(fill: Glyph.punched(triangle, plus, minus), stroke: stroke)
    }

    /// Sine + sparse noise ticks — open mark.
    private static func noiseSNR(_ r: CGRect) -> GlyphArtwork {
        var path = Path()
        Glyph.sine(&path, in: r, y: r.midY - r.height * 0.08, amplitude: r.height * 0.22, cycles: 1)
        for fraction in [0.22, 0.48, 0.74] as [CGFloat] {
            let x = r.minX + r.width * fraction
            Glyph.line(&path, CGPoint(x: x, y: r.maxY - r.height * 0.12), CGPoint(x: x, y: r.maxY - r.height * 0.28))
        }
        return .stroke(path)
    }

    /// Filled IC + three-line ground rake.
    private static func linearRegulator(_ r: CGRect) -> GlyphArtwork {
        let body = CGRect(
            x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.10,
            width: r.width * 0.64, height: r.height * 0.48
        )
        let fill = Glyph.roundedRect(body, corner: 3)
        var stroke = Path()
        for index in 0..<3 {
            let x = body.minX + body.width * (0.22 + 0.28 * CGFloat(index))
            Glyph.line(&stroke, CGPoint(x: x, y: body.maxY), CGPoint(x: x, y: r.maxY - r.height * 0.10))
        }
        return .both(fill: fill, stroke: stroke)
    }

    /// Filled triangle + sense leads.
    private static func instrumentationAmp(_ r: CGRect) -> GlyphArtwork {
        let left = r.minX + r.width * 0.28
        let fill = Glyph.triangle(
            CGPoint(x: left, y: r.minY + r.height * 0.16),
            CGPoint(x: r.maxX - r.width * 0.10, y: r.midY),
            CGPoint(x: left, y: r.maxY - r.height * 0.16)
        )
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.minX, y: r.minY + r.height * 0.28), CGPoint(x: left, y: r.minY + r.height * 0.28))
        Glyph.line(&stroke, CGPoint(x: r.minX, y: r.maxY - r.height * 0.28), CGPoint(x: left, y: r.maxY - r.height * 0.28))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.28), CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.28))
        return .both(fill: fill, stroke: stroke)
    }

    /// Staircase into an arrow — open mark.
    private static func adcDac(_ r: CGRect) -> GlyphArtwork {
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
        return .stroke(path)
    }

    // MARK: - Toolkit · Reference

    /// Filled book + spine hole.
    private static func referenceLibrary(_ r: CGRect) -> GlyphArtwork {
        let book = r.insetBy(dx: r.width * 0.14, dy: r.height * 0.10)
        let body = Glyph.roundedRect(book, corner: 3)
        let spine = Glyph.slot(CGRect(
            x: book.minX + book.width * 0.16,
            y: book.minY + book.height * 0.08,
            width: max(2.0, book.width * 0.08),
            height: book.height * 0.84
        ))
        return .fill(Glyph.punched(body, spine))
    }

    /// Filled card + three line holes + checkbox hole.
    private static func panelDirectory(_ r: CGRect) -> GlyphArtwork {
        let card = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.08)
        let body = Glyph.roundedRect(card, corner: 4)
        let slotH = max(2.0, card.height * 0.07)
        var holes: [Path] = []
        for index in 0..<3 {
            let y = card.minY + card.height * (0.30 + 0.20 * CGFloat(index)) - slotH / 2
            holes.append(Glyph.slot(CGRect(
                x: card.minX + card.width * 0.16, y: y,
                width: card.width * 0.56, height: slotH
            )))
        }
        let box = CGRect(
            x: card.maxX - card.width * 0.22, y: card.minY + card.height * 0.22,
            width: card.width * 0.12, height: card.width * 0.12
        )
        holes.append(Glyph.roundedRect(box, corner: 1.5))
        return .fill(Glyph.punched(body, holes))
    }

    /// Filled page + 2×2 cell holes.
    private static func loadWorksheet(_ r: CGRect) -> GlyphArtwork {
        let page = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.08)
        let body = Glyph.roundedRect(page, corner: 3)
        let inset = page.width * 0.12
        let gap = page.width * 0.08
        let cellW = (page.width - inset * 2 - gap) / 2
        let cellH = (page.height - page.height * 0.18 - page.height * 0.12 - gap) / 2
        let originY = page.minY + page.height * 0.18
        var holes: [Path] = []
        for row in 0..<2 {
            for col in 0..<2 {
                let x = page.minX + inset + CGFloat(col) * (cellW + gap)
                let y = originY + CGFloat(row) * (cellH + gap)
                holes.append(Glyph.roundedRect(CGRect(x: x, y: y, width: cellW, height: cellH), corner: 2))
            }
        }
        return .fill(Glyph.punched(body, holes))
    }

    /// Filled conductor end with three strand holes + list lines.
    private static func cableSchedule(_ r: CGRect) -> GlyphArtwork {
        let c = CGPoint(x: r.minX + r.width * 0.28, y: r.midY)
        var holes: [Path] = []
        for angle in [90.0, 210.0, 330.0] {
            let rad = angle * .pi / 180
            holes.append(Glyph.circlePath(
                CGPoint(x: c.x + cos(rad) * r.width * 0.10, y: c.y + sin(rad) * r.width * 0.10),
                r.width * 0.045
            ))
        }
        let fill = Glyph.punched(Glyph.circlePath(c, r.width * 0.22), holes)
        var stroke = Path()
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.58, y: r.minY + r.height * 0.28), CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.28))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.58, y: r.midY), CGPoint(x: r.maxX - r.width * 0.06, y: r.midY))
        Glyph.line(&stroke, CGPoint(x: r.minX + r.width * 0.58, y: r.maxY - r.height * 0.28), CGPoint(x: r.maxX - r.width * 0.16, y: r.maxY - r.height * 0.28))
        return .both(fill: fill, stroke: stroke)
    }
}

// MARK: - Shared fill / stroke primitives

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

    static func circlePath(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    static func roundedRect(_ rect: CGRect, corner: CGFloat) -> Path {
        Path(roundedRect: rect, cornerSize: CGSize(width: corner, height: corner), style: .continuous)
    }

    static func slot(_ rect: CGRect) -> Path {
        let corner = min(rect.width, rect.height) / 2
        return Path(roundedRect: rect, cornerSize: CGSize(width: corner, height: corner), style: .continuous)
    }

    static func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.closeSubpath()
        return path
    }

    static func regularPolygon(center: CGPoint, radius: CGFloat, sides: Int, rotationDeg: CGFloat = -90) -> Path {
        var path = Path()
        var points: [CGPoint] = []
        for index in 0..<sides {
            let angle = (CGFloat(index) * 360 / CGFloat(sides) + rotationDeg) * .pi / 180
            points.append(CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
        }
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    /// Even-odd fill: solid `body` with `holes` punched through to the well tint.
    static func punched(_ body: Path, _ holes: Path...) -> Path {
        punched(body, holes)
    }

    static func punched(_ body: Path, _ holes: [Path]) -> Path {
        var path = body
        for hole in holes {
            path.addPath(hole)
        }
        return path
    }

    static func plus(center: CGPoint, arm: CGFloat, thickness: CGFloat) -> Path {
        let t = thickness / 2
        let a = arm
        let pts = [
            CGPoint(x: center.x - t, y: center.y - a),
            CGPoint(x: center.x + t, y: center.y - a),
            CGPoint(x: center.x + t, y: center.y - t),
            CGPoint(x: center.x + a, y: center.y - t),
            CGPoint(x: center.x + a, y: center.y + t),
            CGPoint(x: center.x + t, y: center.y + t),
            CGPoint(x: center.x + t, y: center.y + a),
            CGPoint(x: center.x - t, y: center.y + a),
            CGPoint(x: center.x - t, y: center.y + t),
            CGPoint(x: center.x - a, y: center.y + t),
            CGPoint(x: center.x - a, y: center.y - t),
            CGPoint(x: center.x - t, y: center.y - t),
        ]
        var path = Path()
        path.move(to: pts[0])
        for point in pts.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    /// Closed ribbon around a polyline — used as an even-odd hole.
    static func ribbon(_ points: [CGPoint], width: CGFloat) -> Path {
        guard points.count >= 2 else { return Path() }
        let half = width / 2
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for index in 0..<points.count {
            let prev = index == 0 ? points[index] : points[index - 1]
            let next = index == points.count - 1 ? points[index] : points[index + 1]
            let dx = next.x - prev.x
            let dy = next.y - prev.y
            let length = max(hypot(dx, dy), 0.001)
            let nx = -dy / length * half
            let ny = dx / length * half
            left.append(CGPoint(x: points[index].x + nx, y: points[index].y + ny))
            right.append(CGPoint(x: points[index].x - nx, y: points[index].y - ny))
        }
        var path = Path()
        path.move(to: left[0])
        for point in left.dropFirst() { path.addLine(to: point) }
        for point in right.reversed() { path.addLine(to: point) }
        path.closeSubpath()
        return path
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

#if DEBUG
private struct GlyphPassPreview: View {
    let ids: [ToolID]
    var circular: Bool = false
    var well: CGFloat = 72

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: well + 12), spacing: 12)]
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(ids, id: \.self) { id in
                VStack(spacing: 6) {
                    IconWell(toolID: id, size: well, circular: circular)
                    Text(ToolboxCatalog.tools.first(where: { $0.id == id })?.title ?? id.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: well + 16)
                }
            }
        }
        .padding()
        .background(Theme.background)
    }
}

#Preview("QA — Field Quick 52") {
    GlyphPassPreview(
        ids: [.voltageDrop, .wireAmpacity, .motorFLA, .receptacleSelector, .wifiStatus, .conduitFill],
        circular: true,
        well: 52
    )
}

#Preview("QA — Jobsite 4-across 72") {
    GlyphPassPreview(
        ids: [.receptacleSelector, .necCircuit, .wireAmpacity, .conduitFill],
        well: 72
    )
}

#Preview("QA — Toolkit Bench 72") {
    GlyphPassPreview(
        ids: [.eBikePackDesigner, .heaterDesign, .solenoidDesign, .analogWorkbench],
        well: 72
    )
}
#endif
