import SwiftUI

// MARK: - Beckify Instrument Glyph Set (app-only)
//
// Original schematic linework for the Field EE Toolbox — vector Canvas paths,
// no image assets, outline-only strokes on quiet category wells.
// Each mark is one readable metaphor for what that tool computes.
// SF Symbols stay on chrome (favorites, system buttons), not in tool wells.
//
// Units:
//   • `ToolGlyph`     — per-tool schematic (`GlyphKind`, 1:1 with `ToolID`)
//   • `CategoryGlyph` — shelf mark for each `ToolCategory`
//   • `IconWell`      — tinted well + crisp glyph (grid / list / headers)

/// One stroke-weight curve for every schematic. 44pt is the reference size
/// (`Theme.Stroke.icon`). Selected is a slight weight bump, not a new language.
/// A floor keeps 22pt related-row marks engraved instead of hairline.
enum GlyphStroke {
    static let referenceSize: CGFloat = 44
    static let selectedWeight: CGFloat = 1.08
    static let minimum: CGFloat = 1.55

    static func lineWidth(size: CGFloat, selected: Bool) -> CGFloat {
        let scaled = Theme.Stroke.icon * (size / referenceSize)
        let base = max(minimum, scaled)
        return selected ? base * selectedWeight : base
    }

    static func underWidth(for lineWidth: CGFloat) -> CGFloat {
        lineWidth * Theme.Stroke.iconUnderRatio
    }

    static func underOpacity(selected: Bool) -> Double {
        selected ? 0.10 : 0.08
    }
}

/// Schematic stroke for one toolbox tool. Drawn as vector paths so it stays
/// crisp at any size, follows the theme, and ships no image assets.
///
/// Each `ToolID` maps 1:1 to a distinct `GlyphKind` — no unrelated tools share
/// the same schematic. When `toolID` is supplied the stroke is a
/// category-colored gradient. Glyphs are stroke-only (no fills).
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

    private var strokeColor: Color { selected ? Theme.accent : Theme.muted }

    private var lineWidth: CGFloat {
        GlyphStroke.lineWidth(size: size, selected: selected)
    }

    private var underWidth: CGFloat {
        GlyphStroke.underWidth(for: lineWidth)
    }

    var body: some View {
        Canvas { context, canvasSize in
            // Same 12% inset on every glyph so tile density stays even.
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.12, dy: canvasSize.height * 0.12)
            let path = kind.path(in: rect)
            let mainStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            let underStyle = StrokeStyle(lineWidth: underWidth, lineCap: .round, lineJoin: .round)

            context.stroke(
                path,
                with: .color(Color.black.opacity(GlyphStroke.underOpacity(selected: selected))),
                style: underStyle
            )

            if let resolvedCategory {
                let colors = Theme.categoryColors(resolvedCategory)
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [colors.primary, colors.secondary]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                context.stroke(path, with: shading, style: mainStyle)
            } else {
                context.stroke(path, with: .color(strokeColor), style: mainStyle)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Soft colored well that frames a `ToolGlyph` — the graphic unit of the grid
/// and list rows (pastel container + crisp schematic).
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
        let glyphBase = glyphSize ?? baseSize * 0.64
        let scale = baseSize > 0 ? scaledSize / baseSize : 1
        return glyphBase * scale
    }
    private var corner: CGFloat {
        if circular { return size / 2 }
        // Fixed control-band radius on square wells. Circles stay on Quick strip.
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

/// Shelf mark for a toolbox category — same dual-stroke language as tool glyphs.
struct CategoryGlyph: View {
    let category: ToolCategory
    var size: CGFloat = 28
    var selected: Bool = true

    private var lineWidth: CGFloat {
        GlyphStroke.lineWidth(size: size, selected: selected)
    }

    private var underWidth: CGFloat {
        GlyphStroke.underWidth(for: lineWidth)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.12, dy: canvasSize.height * 0.12)
            let path = CategoryGlyphKind(category).path(in: rect)
            let colors = Theme.categoryColors(category)
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [colors.primary, colors.secondary]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            context.stroke(
                path,
                with: .color(Color.black.opacity(GlyphStroke.underOpacity(selected: selected))),
                style: StrokeStyle(lineWidth: underWidth, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                path,
                with: shading,
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
            CategoryGlyph(category: category, size: size * 0.62, selected: true)
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

    /// Clamp-meter / field probe silhouette.
    private static func field(_ r: CGRect) -> Path {
        var path = Path()
        let jaw = r.width * 0.38
        path.addArc(
            center: CGPoint(x: r.midX, y: r.minY + r.height * 0.32),
            radius: jaw,
            startAngle: .degrees(210),
            endAngle: .degrees(-30),
            clockwise: false
        )
        path.move(to: CGPoint(x: r.midX - jaw * 0.55, y: r.minY + r.height * 0.48))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.12, y: r.maxY - r.height * 0.08))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.12, y: r.maxY - r.height * 0.08))
        path.addLine(to: CGPoint(x: r.midX + jaw * 0.55, y: r.minY + r.height * 0.48))
        path.move(to: CGPoint(x: r.midX, y: r.midY + r.height * 0.05))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.2))
        return path
    }

    /// AC sine inside a power triangle.
    private static func power(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.06))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.1, y: r.maxY - r.height * 0.1))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.maxY - r.height * 0.1))
        path.closeSubpath()
        let waveY = r.midY + r.height * 0.12
        path.move(to: CGPoint(x: r.minX + r.width * 0.28, y: waveY))
        for step in 0...16 {
            let t = CGFloat(step) / 16
            let y = waveY - sin(t * .pi * 2) * r.height * 0.1
            path.addLine(to: CGPoint(x: r.minX + r.width * (0.28 + 0.44 * t), y: y))
        }
        return path
    }

    /// Ladder-logic rung / PLC rail.
    private static func controls(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.12))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.12))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.12))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY - r.height * 0.12))
        let midY = r.midY
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: midY))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.14, y: midY))
        let box = CGRect(
            x: r.midX - r.width * 0.14, y: midY - r.height * 0.14,
            width: r.width * 0.28, height: r.height * 0.28
        )
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 2, height: 2))
        path.move(to: CGPoint(x: r.midX + r.width * 0.14, y: midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: midY))
        return path
    }

    /// Open notebook with a formula stroke.
    private static func homework(_ r: CGRect) -> Path {
        var path = Path()
        let page = CGRect(
            x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.1,
            width: r.width * 0.64, height: r.height * 0.8
        )
        path.addRoundedRect(in: page, cornerSize: CGSize(width: 3, height: 3))
        path.move(to: CGPoint(x: r.midX, y: page.minY))
        path.addLine(to: CGPoint(x: r.midX, y: page.maxY))
        path.move(to: CGPoint(x: page.minX + page.width * 0.12, y: page.minY + page.height * 0.35))
        path.addLine(to: CGPoint(x: page.minX + page.width * 0.38, y: page.minY + page.height * 0.35))
        path.move(to: CGPoint(x: page.minX + page.width * 0.12, y: page.minY + page.height * 0.55))
        path.addLine(to: CGPoint(x: page.minX + page.width * 0.32, y: page.minY + page.height * 0.55))
        path.move(to: CGPoint(x: page.maxX - page.width * 0.38, y: page.minY + page.height * 0.42))
        path.addLine(to: CGPoint(x: page.maxX - page.width * 0.12, y: page.minY + page.height * 0.62))
        return path
    }

    /// Concentric sensor / radar arcs.
    private static func sensors(_ r: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: r.midX, y: r.maxY - r.height * 0.18)
        for fraction in [0.28, 0.48, 0.68] as [CGFloat] {
            path.addArc(
                center: center,
                radius: min(r.width, r.height) * fraction,
                startAngle: .degrees(210),
                endAngle: .degrees(-30),
                clockwise: false
            )
        }
        let node = r.width * 0.06
        path.addEllipse(in: CGRect(x: center.x - node, y: center.y - node, width: node * 2, height: node * 2))
        return path
    }

    /// Datasheet / reference card with index ticks.
    private static func reference(_ r: CGRect) -> Path {
        var path = Path()
        let card = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.12,
            width: r.width * 0.68, height: r.height * 0.76
        )
        path.addRoundedRect(in: card, cornerSize: CGSize(width: 3, height: 3))
        for index in 0..<3 {
            let y = card.minY + card.height * (0.28 + 0.2 * CGFloat(index))
            path.move(to: CGPoint(x: card.minX + card.width * 0.18, y: y))
            path.addLine(to: CGPoint(x: card.maxX - card.width * 0.18, y: y))
        }
        path.move(to: CGPoint(x: card.minX + card.width * 0.18, y: card.minY + card.height * 0.16))
        path.addLine(to: CGPoint(x: card.minX + card.width * 0.42, y: card.minY + card.height * 0.16))
        return path
    }
}

extension GlyphKind {
    /// Single mapping from toolbox identity to schematic artwork.
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

    // swiftlint:disable:next cyclomatic_complexity
    func path(in rect: CGRect) -> Path {
        switch self {
        case .ohmsLaw: return Self.ohmsLaw(rect)
        case .power: return Self.power(rect)
        case .powerWizard: return Self.powerWizard(rect)
        case .voltageDrop: return Self.voltageDrop(rect)
        case .conduitFill: return Self.conduitFill(rect)
        case .conductorCost: return Self.conductorCost(rect)
        case .conductorLength: return Self.conductorLength(rect)
        case .transformer: return Self.transformer(rect)
        case .timer555: return Self.timer555(rect)
        case .motorFLA: return Self.motorFLA(rect)
        case .wireAmpacity: return Self.wireAmpacity(rect)
        case .voltageDivider: return Self.voltageDivider(rect)
        case .seriesParallel: return Self.seriesParallel(rect)
        case .resistorColor: return Self.resistorColor(rect)
        case .unitConverter: return Self.unitConverter(rect)
        case .frequencyWave: return Self.frequencyWave(rect)
        case .ledRC: return Self.ledRC(rect)
        case .wifiStatus: return Self.wifiStatus(rect)
        case .cellularStatus: return Self.cellularStatus(rect)
        case .bluetoothScan: return Self.bluetoothScan(rect)
        case .noiseMeter: return Self.noiseMeter(rect)
        case .bubbleLevel: return Self.bubbleLevel(rect)
        case .magnetometer: return Self.magnetometer(rect)
        case .barometer: return Self.barometer(rect)
        case .motionSnapshot: return Self.motionSnapshot(rect)
        case .fieldPosition: return Self.fieldPosition(rect)
        case .deviceHealth: return Self.deviceHealth(rect)
        case .receptacleSelector: return Self.receptacleSelector(rect)
        case .reactance: return Self.reactance(rect)
        case .powerFactor: return Self.powerFactor(rect)
        case .shortCircuit: return Self.shortCircuit(rect)
        case .circularMils: return Self.circularMils(rect)
        case .loadFactors: return Self.loadFactors(rect)
        case .signalScaling: return Self.signalScaling(rect)
        case .modbusAddress: return Self.modbusAddress(rect)
        case .plcTimer: return Self.plcTimer(rect)
        case .panelDirectory: return Self.panelDirectory(rect)
        case .motorSpeed: return Self.motorSpeed(rect)
        case .rfLink: return Self.rfLink(rect)
        case .phasorDiagram: return Self.phasorDiagram(rect)
        case .numberBase: return Self.numberBase(rect)
        case .batteryBank: return Self.batteryBank(rect)
        case .referenceLibrary: return Self.referenceLibrary(rect)
        case .magneticCircuit: return Self.magneticCircuit(rect)
        case .fiberLink: return Self.fiberLink(rect)
        case .gaussianBeam: return Self.gaussianBeam(rect)
        case .transientCircuit: return Self.transientCircuit(rect)
        case .rackCurrent: return Self.rackCurrent(rect)
        case .diodeIV: return Self.diodeIV(rect)
        case .isLoopVerifier: return Self.isLoopVerifier(rect)
        case .tapChanger: return Self.tapChanger(rect)
        case .harmonicsTHD: return Self.harmonicsTHD(rect)
        case .upsSizing: return Self.upsSizing(rect)
        case .motorNameplate: return Self.motorNameplate(rect)
        case .motorNameplateOCR: return Self.motorNameplateOCR(rect)
        case .lookCheck: return Self.lookCheck(rect)
        case .heaterDesign: return Self.heaterDesign(rect)
        case .empEmc: return Self.empEmc(rect)
        case .necCircuit: return Self.necCircuit(rect)
        case .loadWorksheet: return Self.loadWorksheet(rect)
        case .cableSchedule: return Self.cableSchedule(rect)
        case .solenoidDesign: return Self.solenoidDesign(rect)
        case .solarDesign: return Self.solarDesign(rect)
        case .analogWorkbench: return Self.analogWorkbench(rect)
        case .noiseSNR: return Self.noiseSNR(rect)
        case .linearRegulator: return Self.linearRegulator(rect)
        case .instrumentationAmp: return Self.instrumentationAmp(rect)
        case .adcDac: return Self.adcDac(rect)
        case .eBikeTorqueRPM: return Self.eBikeTorqueRPM(rect)
        case .eBikeSprocket: return Self.eBikeSprocket(rect)
        case .eBikeRange: return Self.eBikeRange(rect)
        case .eBikePackDesigner: return Self.eBikePackDesigner(rect)
        case .nickelStrip: return Self.nickelStrip(rect)
        case .controlSystems: return Self.controlSystems(rect)
        }
    }

    // MARK: - Stroke helpers

    private static func line(_ path: inout Path, _ a: CGPoint, _ b: CGPoint) {
        path.move(to: a)
        path.addLine(to: b)
    }

    private static func circle(_ path: inout Path, _ center: CGPoint, _ radius: CGFloat) {
        path.addEllipse(in: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    private static func arrow(_ path: inout Path, from: CGPoint, to: CGPoint, head: CGFloat) {
        path.move(to: from)
        path.addLine(to: to)
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(hypot(dx, dy), 0.001)
        let ux = dx / length
        let uy = dy / length
        path.move(to: to)
        path.addLine(to: CGPoint(
            x: to.x - ux * head - uy * head * 0.42,
            y: to.y - uy * head + ux * head * 0.42
        ))
        path.move(to: to)
        path.addLine(to: CGPoint(
            x: to.x - ux * head + uy * head * 0.42,
            y: to.y - uy * head - ux * head * 0.42
        ))
    }

    private static func wave(
        _ path: inout Path,
        x0: CGFloat, x1: CGFloat, y: CGFloat, amp: CGFloat,
        cycles: CGFloat, steps: Int = 18
    ) {
        path.move(to: CGPoint(x: x0, y: y))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: x0 + (x1 - x0) * t, y: y - sin(t * .pi * 2 * cycles) * amp))
        }
    }

    // MARK: - Jobsite / power

    /// Schematic resistor — V = I × R.
    private static func ohmsLaw(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.18, y: y))
        let zig0 = r.minX + r.width * 0.18
        let zigW = r.width * 0.52
        let step = zigW / 5
        path.move(to: CGPoint(x: zig0, y: y))
        for index in 0..<5 {
            let x = zig0 + step * (CGFloat(index) + 0.5)
            path.addLine(to: CGPoint(x: x, y: y + (index.isMultiple(of: 2) ? -r.height * 0.22 : r.height * 0.22)))
        }
        path.addLine(to: CGPoint(x: zig0 + zigW, y: y))
        line(&path, CGPoint(x: zig0 + zigW, y: y), CGPoint(x: r.maxX, y: y))
        // Ω cue — small horseshoe under the body
        path.addArc(
            center: CGPoint(x: r.midX, y: r.maxY - r.height * 0.10),
            radius: r.width * 0.10,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        return path
    }

    /// Lightning bolt — watts / kVA / kW.
    private static func power(_ r: CGRect) -> Path {
        var path = Path()
        let pts = [
            CGPoint(x: r.midX + r.width * 0.10, y: r.minY),
            CGPoint(x: r.midX - r.width * 0.22, y: r.midY + r.height * 0.04),
            CGPoint(x: r.midX - r.width * 0.04, y: r.midY + r.height * 0.04),
            CGPoint(x: r.midX - r.width * 0.14, y: r.maxY),
            CGPoint(x: r.midX + r.width * 0.24, y: r.midY - r.height * 0.02),
            CGPoint(x: r.midX + r.width * 0.04, y: r.midY - r.height * 0.02),
        ]
        path.move(to: pts[0])
        for point in pts.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    /// Same bolt with a solve-for spark — Power Wizard deep link.
    private static func powerWizard(_ r: CGRect) -> Path {
        var path = power(r)
        let star = CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.16)
        line(&path, CGPoint(x: star.x, y: star.y - r.height * 0.12), CGPoint(x: star.x, y: star.y + r.height * 0.12))
        line(&path, CGPoint(x: star.x - r.width * 0.10, y: star.y), CGPoint(x: star.x + r.width * 0.10, y: star.y))
        return path
    }

    /// Feeder run with voltage sagging along the length.
    private static func voltageDrop(_ r: CGRect) -> Path {
        var path = Path()
        line(&path, CGPoint(x: r.minX, y: r.minY + r.height * 0.28), CGPoint(x: r.maxX, y: r.minY + r.height * 0.28))
        line(&path, CGPoint(x: r.minX, y: r.maxY - r.height * 0.28), CGPoint(x: r.maxX, y: r.maxY - r.height * 0.28))
        let heights: [CGFloat] = [0.22, 0.34, 0.48, 0.64]
        for (index, h) in heights.enumerated() {
            let x = r.minX + r.width * (0.18 + 0.22 * CGFloat(index))
            line(&path, CGPoint(x: x, y: r.minY + r.height * 0.28), CGPoint(x: x, y: r.minY + r.height * (0.28 + h * 0.42)))
        }
        arrow(
            &path,
            from: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.08),
            to: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.08),
            head: r.width * 0.10
        )
        return path
    }

    /// Conduit cross-section packed with three conductors.
    private static func conduitFill(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.46
        circle(&path, CGPoint(x: r.midX, y: r.midY), radius)
        let inner = radius * 0.22
        for angle in [90.0, 210.0, 330.0] {
            let rad = angle * .pi / 180
            circle(
                &path,
                CGPoint(x: r.midX + cos(rad) * radius * 0.42, y: r.midY + sin(rad) * radius * 0.42),
                inner
            )
        }
        return path
    }

    /// Cable run with a $ tag — first-cost optimizer.
    private static func conductorCost(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.maxX - r.width * 0.38, y: y))
        circle(&path, CGPoint(x: r.minX + r.width * 0.06, y: y), r.width * 0.05)
        let tag = CGRect(
            x: r.maxX - r.width * 0.36, y: r.midY - r.height * 0.28,
            width: r.width * 0.32, height: r.height * 0.56
        )
        path.addRoundedRect(in: tag, cornerSize: CGSize(width: 3, height: 3))
        // $ stem + S
        path.addArc(
            center: CGPoint(x: tag.midX, y: tag.midY - tag.height * 0.10),
            radius: tag.width * 0.22,
            startAngle: .degrees(30),
            endAngle: .degrees(210),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: tag.midX, y: tag.midY + tag.height * 0.12),
            radius: tag.width * 0.22,
            startAngle: .degrees(210),
            endAngle: .degrees(30),
            clockwise: false
        )
        line(
            &path,
            CGPoint(x: tag.midX, y: tag.minY + tag.height * 0.12),
            CGPoint(x: tag.midX, y: tag.maxY - tag.height * 0.12)
        )
        return path
    }

    /// Tape measure on a cable — length from milliohms.
    private static func conductorLength(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.minY + r.height * 0.32
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.maxX, y: y))
        circle(&path, CGPoint(x: r.minX + r.width * 0.06, y: y), r.width * 0.05)
        circle(&path, CGPoint(x: r.maxX - r.width * 0.06, y: y), r.width * 0.05)
        let tape = CGRect(
            x: r.minX + r.width * 0.10, y: r.maxY - r.height * 0.42,
            width: r.width * 0.80, height: r.height * 0.26
        )
        path.addRoundedRect(in: tape, cornerSize: CGSize(width: 2, height: 2))
        for index in 0..<5 {
            let x = tape.minX + tape.width * (0.12 + 0.19 * CGFloat(index))
            let tick = index.isMultiple(of: 2) ? tape.height * 0.55 : tape.height * 0.32
            line(&path, CGPoint(x: x, y: tape.maxY), CGPoint(x: x, y: tape.maxY - tick))
        }
        return path
    }

    /// Transformer: two coils on a core.
    private static func transformer(_ r: CGRect) -> Path {
        var path = Path()
        line(&path, CGPoint(x: r.midX - r.width * 0.05, y: r.minY), CGPoint(x: r.midX - r.width * 0.05, y: r.maxY))
        line(&path, CGPoint(x: r.midX + r.width * 0.05, y: r.minY), CGPoint(x: r.midX + r.width * 0.05, y: r.maxY))
        let hump = r.height * 0.13
        for index in 0..<3 {
            let y = r.minY + r.height * (0.24 + 0.26 * CGFloat(index))
            path.addArc(
                center: CGPoint(x: r.midX - r.width * 0.05, y: y),
                radius: hump,
                startAngle: .degrees(90),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: r.midX + r.width * 0.05, y: y),
                radius: hump,
                startAngle: .degrees(270),
                endAngle: .degrees(90),
                clockwise: false
            )
        }
        return path
    }

    /// 8-pin DIP + square wave — 555 timer.
    private static func timer555(_ r: CGRect) -> Path {
        var path = Path()
        let body = r.insetBy(dx: r.width * 0.22, dy: r.height * 0.22)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3, height: 3))
        for index in 0..<3 {
            let y = body.minY + body.height * (0.22 + 0.28 * CGFloat(index))
            line(&path, CGPoint(x: body.minX, y: y), CGPoint(x: r.minX + r.width * 0.08, y: y))
            line(&path, CGPoint(x: body.maxX, y: y), CGPoint(x: r.maxX - r.width * 0.08, y: y))
        }
        let wy = r.maxY - r.height * 0.08
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: wy))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.28, y: wy))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.28, y: wy - r.height * 0.16))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.52, y: wy - r.height * 0.16))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.52, y: wy))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: wy))
        return path
    }

    /// IEC motor circle with M — table FLA, not a nameplate.
    private static func motorFLA(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.42
        circle(&path, CGPoint(x: r.midX, y: r.midY), radius)
        // M
        let left = r.midX - radius * 0.42
        let right = r.midX + radius * 0.42
        let top = r.midY - radius * 0.38
        let bot = r.midY + radius * 0.38
        path.move(to: CGPoint(x: left, y: bot))
        path.addLine(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: r.midX, y: r.midY + radius * 0.08))
        path.addLine(to: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: bot))
        return path
    }

    /// End-on conductor: copper + insulation — wire size / 310.16.
    private static func wireAmpacity(_ r: CGRect) -> Path {
        var path = Path()
        let outer = min(r.width, r.height) * 0.40
        circle(&path, CGPoint(x: r.midX, y: r.midY), outer)
        circle(&path, CGPoint(x: r.midX, y: r.midY), outer * 0.55)
        // Ampacity heat ticks
        for angle in [40.0, 90.0, 140.0] {
            let rad = angle * .pi / 180
            let inner = outer * 1.12
            let tip = outer * 1.32
            line(
                &path,
                CGPoint(x: r.midX + cos(rad) * inner, y: r.midY - sin(rad) * inner),
                CGPoint(x: r.midX + cos(rad) * tip, y: r.midY - sin(rad) * tip)
            )
        }
        return path
    }

    /// NEMA 5-15 duplex face.
    private static func receptacleSelector(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.44
        circle(&path, CGPoint(x: r.midX, y: r.midY), radius)
        let slotH = radius * 0.42
        line(
            &path,
            CGPoint(x: r.midX - radius * 0.32, y: r.midY - slotH * 0.55),
            CGPoint(x: r.midX - radius * 0.32, y: r.midY + slotH * 0.15)
        )
        line(
            &path,
            CGPoint(x: r.midX + radius * 0.32, y: r.midY - slotH * 0.55),
            CGPoint(x: r.midX + radius * 0.32, y: r.midY + slotH * 0.15)
        )
        circle(&path, CGPoint(x: r.midX, y: r.midY + slotH * 0.55), radius * 0.12)
        return path
    }

    /// Coil + capacitor plates — reactance / resonance, not a generic sine.
    private static func reactance(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.10, y: y))
        let coil0 = r.minX + r.width * 0.10
        let hump = r.width * 0.10
        path.move(to: CGPoint(x: coil0, y: y))
        for index in 0..<3 {
            path.addArc(
                center: CGPoint(x: coil0 + hump * (CGFloat(index) + 0.5), y: y),
                radius: hump / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
        let gap = r.width * 0.10
        let plate = r.minX + r.width * 0.52
        line(&path, CGPoint(x: coil0 + hump * 3, y: y), CGPoint(x: plate, y: y))
        line(&path, CGPoint(x: plate, y: y - r.height * 0.22), CGPoint(x: plate, y: y + r.height * 0.22))
        line(&path, CGPoint(x: plate + gap, y: y - r.height * 0.22), CGPoint(x: plate + gap, y: y + r.height * 0.22))
        line(&path, CGPoint(x: plate + gap, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    /// P-Q triangle with a capacitor on the Q side — PF correction.
    private static func powerFactor(_ r: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.14)
        let pEnd = CGPoint(x: r.maxX - r.width * 0.28, y: origin.y)
        let qEnd = CGPoint(x: origin.x, y: r.minY + r.height * 0.16)
        path.move(to: origin)
        path.addLine(to: pEnd)
        path.addLine(to: qEnd)
        path.closeSubpath()
        path.addArc(
            center: origin,
            radius: r.width * 0.18,
            startAngle: .degrees(0),
            endAngle: .degrees(-50),
            clockwise: true
        )
        let capX = r.maxX - r.width * 0.12
        line(&path, CGPoint(x: capX, y: r.minY + r.height * 0.22), CGPoint(x: capX, y: r.maxY - r.height * 0.22))
        line(&path, CGPoint(x: capX + r.width * 0.08, y: r.minY + r.height * 0.22), CGPoint(x: capX + r.width * 0.08, y: r.maxY - r.height * 0.22))
        return path
    }

    /// Fault into a bus — short-circuit current.
    private static func shortCircuit(_ r: CGRect) -> Path {
        var path = Path()
        line(&path, CGPoint(x: r.minX, y: r.maxY - r.height * 0.18), CGPoint(x: r.maxX, y: r.maxY - r.height * 0.18))
        let bolt = [
            CGPoint(x: r.midX + r.width * 0.06, y: r.minY + r.height * 0.08),
            CGPoint(x: r.midX - r.width * 0.14, y: r.midY + r.height * 0.02),
            CGPoint(x: r.midX + r.width * 0.02, y: r.midY + r.height * 0.02),
            CGPoint(x: r.midX - r.width * 0.08, y: r.maxY - r.height * 0.22),
        ]
        path.move(to: bolt[0])
        for point in bolt.dropFirst() { path.addLine(to: point) }
        return path
    }

    /// Round conductor with a diameter dimension — circular mils.
    private static func circularMils(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.32
        circle(&path, CGPoint(x: r.midX, y: r.midY - r.height * 0.06), radius)
        let dimY = r.maxY - r.height * 0.10
        line(&path, CGPoint(x: r.midX - radius, y: dimY), CGPoint(x: r.midX + radius, y: dimY))
        line(&path, CGPoint(x: r.midX - radius, y: dimY - r.height * 0.08), CGPoint(x: r.midX - radius, y: dimY + r.height * 0.08))
        line(&path, CGPoint(x: r.midX + radius, y: dimY - r.height * 0.08), CGPoint(x: r.midX + radius, y: dimY + r.height * 0.08))
        return path
    }

    /// Connected vs demand — one tall bar, one shorter used bar.
    private static func loadFactors(_ r: CGRect) -> Path {
        var path = Path()
        let base = r.maxY - r.height * 0.10
        let connected = CGRect(
            x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.08,
            width: r.width * 0.28, height: base - (r.minY + r.height * 0.08)
        )
        let demand = CGRect(
            x: r.midX + r.width * 0.08, y: r.minY + r.height * 0.38,
            width: r.width * 0.28, height: base - (r.minY + r.height * 0.38)
        )
        path.addRoundedRect(in: connected, cornerSize: CGSize(width: 3, height: 3))
        path.addRoundedRect(in: demand, cornerSize: CGSize(width: 3, height: 3))
        line(&path, CGPoint(x: r.minX + r.width * 0.08, y: base), CGPoint(x: r.maxX - r.width * 0.08, y: base))
        return path
    }

    /// 4–20 mA current loop with scale ticks.
    private static func signalScaling(_ r: CGRect) -> Path {
        var path = Path()
        let loop = CGRect(
            x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.18,
            width: r.width * 0.80, height: r.height * 0.52
        )
        path.addEllipse(in: loop)
        line(&path, CGPoint(x: loop.minX + loop.width * 0.18, y: loop.maxY), CGPoint(x: loop.minX + loop.width * 0.18, y: r.maxY - r.height * 0.08))
        line(&path, CGPoint(x: loop.maxX - loop.width * 0.18, y: loop.maxY), CGPoint(x: loop.maxX - loop.width * 0.18, y: r.maxY - r.height * 0.08))
        line(&path, CGPoint(x: loop.minX + loop.width * 0.18, y: r.maxY - r.height * 0.08), CGPoint(x: loop.maxX - loop.width * 0.18, y: r.maxY - r.height * 0.08))
        // 4 and 20 ticks
        line(&path, CGPoint(x: loop.minX + loop.width * 0.18, y: r.maxY - r.height * 0.08), CGPoint(x: loop.minX + loop.width * 0.18, y: r.maxY))
        line(&path, CGPoint(x: loop.maxX - loop.width * 0.18, y: r.maxY - r.height * 0.08), CGPoint(x: loop.maxX - loop.width * 0.18, y: r.maxY))
        return path
    }

    /// Holding-register cells — Modbus 4xxxx.
    private static func modbusAddress(_ r: CGRect) -> Path {
        var path = Path()
        let cell = r.width * 0.28
        for col in 0..<2 {
            let box = CGRect(
                x: r.minX + r.width * 0.14 + CGFloat(col) * (cell + r.width * 0.08),
                y: r.minY + r.height * 0.18,
                width: cell, height: r.height * 0.38
            )
            path.addRoundedRect(in: box, cornerSize: CGSize(width: 3, height: 3))
        }
        // 40001-style prefix
        line(&path, CGPoint(x: r.minX + r.width * 0.18, y: r.maxY - r.height * 0.22), CGPoint(x: r.minX + r.width * 0.38, y: r.maxY - r.height * 0.22))
        line(&path, CGPoint(x: r.minX + r.width * 0.46, y: r.maxY - r.height * 0.30), CGPoint(x: r.minX + r.width * 0.46, y: r.maxY - r.height * 0.14))
        line(&path, CGPoint(x: r.minX + r.width * 0.54, y: r.maxY - r.height * 0.22), CGPoint(x: r.maxX - r.width * 0.14, y: r.maxY - r.height * 0.22))
        return path
    }

    /// TON block with a clock — PLC timer preset.
    private static func plcTimer(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY + r.height * 0.06
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.16, y: y))
        let box = CGRect(
            x: r.minX + r.width * 0.16, y: y - r.height * 0.20,
            width: r.width * 0.40, height: r.height * 0.40
        )
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3, height: 3))
        line(&path, CGPoint(x: box.maxX, y: y), CGPoint(x: r.maxX, y: y))
        let clock = CGPoint(x: r.maxX - r.width * 0.20, y: r.minY + r.height * 0.28)
        circle(&path, clock, r.width * 0.16)
        line(&path, clock, CGPoint(x: clock.x, y: clock.y - r.height * 0.10))
        line(&path, clock, CGPoint(x: clock.x + r.width * 0.08, y: clock.y + r.height * 0.02))
        return path
    }

    /// Two-up panel door directory card.
    private static func panelDirectory(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: r.insetBy(dx: r.width * 0.04, dy: r.height * 0.04), cornerSize: CGSize(width: 4, height: 4))
        line(&path, CGPoint(x: r.midX, y: r.minY + r.height * 0.14), CGPoint(x: r.midX, y: r.maxY - r.height * 0.14))
        for index in 0..<4 {
            let y = r.minY + r.height * (0.26 + 0.16 * CGFloat(index))
            line(&path, CGPoint(x: r.minX + r.width * 0.16, y: y), CGPoint(x: r.midX - r.width * 0.08, y: y))
            line(&path, CGPoint(x: r.midX + r.width * 0.08, y: y), CGPoint(x: r.maxX - r.width * 0.16, y: y))
        }
        return path
    }

    // MARK: - Expansion / specialist

    /// Tachometer — motor speed & torque.
    private static func motorSpeed(_ r: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: r.midX, y: r.midY + r.height * 0.12)
        let radius = min(r.width, r.height) * 0.42
        path.addArc(
            center: center, radius: radius,
            startAngle: .degrees(200), endAngle: .degrees(-20),
            clockwise: false
        )
        for tick in 0...4 {
            let t = CGFloat(tick) / 4
            let rad = (200 + (-20 - 200) * t) * .pi / 180
            line(
                &path,
                CGPoint(x: center.x + cos(rad) * radius * 0.78, y: center.y - sin(rad) * radius * 0.78),
                CGPoint(x: center.x + cos(rad) * radius, y: center.y - sin(rad) * radius)
            )
        }
        arrow(
            &path,
            from: center,
            to: CGPoint(x: center.x + cos(55 * .pi / 180) * radius * 0.68, y: center.y - sin(55 * .pi / 180) * radius * 0.68),
            head: r.width * 0.10
        )
        return path
    }

    /// Dipole / yagi radiating — RF power & path loss, not Wi-Fi.
    private static func rfLink(_ r: CGRect) -> Path {
        var path = Path()
        line(&path, CGPoint(x: r.minX + r.width * 0.08, y: r.midY), CGPoint(x: r.minX + r.width * 0.42, y: r.midY))
        line(&path, CGPoint(x: r.minX + r.width * 0.25, y: r.minY + r.height * 0.22), CGPoint(x: r.minX + r.width * 0.25, y: r.maxY - r.height * 0.22))
        let source = CGPoint(x: r.minX + r.width * 0.46, y: r.midY)
        for ring in 1...3 {
            let radius = r.width * 0.14 * CGFloat(ring)
            path.addArc(
                center: source, radius: radius,
                startAngle: .degrees(-50), endAngle: .degrees(50),
                clockwise: false
            )
        }
        return path
    }

    /// Three phasors from one origin.
    private static func phasorDiagram(_ r: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) * 0.40
        circle(&path, center, radius)
        let vectors: [(CGFloat, CGFloat)] = [(-90, 0.92), (28, 0.70), (150, 0.78)]
        for (deg, length) in vectors {
            let rad = deg * .pi / 180
            arrow(
                &path,
                from: center,
                to: CGPoint(x: center.x + cos(rad) * radius * length, y: center.y + sin(rad) * radius * length),
                head: radius * 0.16
            )
        }
        return path
    }

    /// 1-0-1-0 register — number bases.
    private static func numberBase(_ r: CGRect) -> Path {
        var path = Path()
        let box = CGRect(
            x: r.minX + r.width * 0.06, y: r.midY - r.height * 0.22,
            width: r.width * 0.88, height: r.height * 0.44
        )
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3, height: 3))
        for index in 1...3 {
            let x = box.minX + box.width * CGFloat(index) / 4
            line(&path, CGPoint(x: x, y: box.minY), CGPoint(x: x, y: box.maxY))
        }
        for (index, isOne) in [true, false, true, false].enumerated() where isOne {
            let x = box.minX + box.width * (CGFloat(index) + 0.5) / 4
            line(&path, CGPoint(x: x, y: box.midY - box.height * 0.28), CGPoint(x: x, y: box.midY + box.height * 0.28))
        }
        return path
    }

    /// Series cell plates — battery bank sizing.
    private static func batteryBank(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        let longs: [CGFloat] = [0.22, 0.58]
        for fraction in longs {
            let x = r.minX + r.width * fraction
            line(&path, CGPoint(x: x, y: y - r.height * 0.24), CGPoint(x: x, y: y + r.height * 0.24))
            line(&path, CGPoint(x: x + r.width * 0.12, y: y - r.height * 0.12), CGPoint(x: x + r.width * 0.12, y: y + r.height * 0.12))
        }
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.22, y: y))
        line(&path, CGPoint(x: r.minX + r.width * 0.34, y: y), CGPoint(x: r.minX + r.width * 0.58, y: y))
        line(&path, CGPoint(x: r.minX + r.width * 0.70, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    /// Open handbook — reference tables.
    private static func referenceLibrary(_ r: CGRect) -> Path {
        var path = Path()
        let spine = r.midX
        path.move(to: CGPoint(x: spine, y: r.minY + r.height * 0.12))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.20))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.06, y: r.maxY - r.height * 0.14))
        path.addLine(to: CGPoint(x: spine, y: r.maxY - r.height * 0.20))
        path.closeSubpath()
        path.move(to: CGPoint(x: spine, y: r.minY + r.height * 0.12))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.20))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.14))
        path.addLine(to: CGPoint(x: spine, y: r.maxY - r.height * 0.20))
        path.closeSubpath()
        return path
    }

    /// Laminated core + flux loop.
    private static func magneticCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let core = CGRect(
            x: r.midX - r.width * 0.14, y: r.midY - r.height * 0.28,
            width: r.width * 0.28, height: r.height * 0.56
        )
        path.addRoundedRect(in: core, cornerSize: CGSize(width: 2, height: 2))
        path.addEllipse(in: r.insetBy(dx: r.width * 0.06, dy: r.height * 0.08))
        return path
    }

    /// Fiber tip + acceptance cone.
    private static func fiberLink(_ r: CGRect) -> Path {
        var path = Path()
        let apex = CGPoint(x: r.minX + r.width * 0.14, y: r.midY)
        path.move(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.16))
        path.addLine(to: apex)
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.maxY - r.height * 0.16))
        line(&path, apex, CGPoint(x: r.maxX - r.width * 0.06, y: r.midY))
        line(&path, CGPoint(x: r.minX, y: r.minY + r.height * 0.22), apex)
        return path
    }

    /// Beam waist — Gaussian beam.
    private static func gaussianBeam(_ r: CGRect) -> Path {
        var path = Path()
        let steps = 16
        func half(_ x: CGFloat) -> CGFloat {
            let n = abs(x - r.midX) / (r.width / 2)
            return r.height * (0.08 + 0.32 * n * n)
        }
        path.move(to: CGPoint(x: r.minX, y: r.midY - half(r.minX)))
        for step in 0...steps {
            let x = r.minX + r.width * CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: x, y: r.midY - half(x)))
        }
        path.move(to: CGPoint(x: r.minX, y: r.midY + half(r.minX)))
        for step in 0...steps {
            let x = r.minX + r.width * CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: x, y: r.midY + half(x)))
        }
        line(&path, CGPoint(x: r.midX, y: r.midY - r.height * 0.10), CGPoint(x: r.midX, y: r.midY + r.height * 0.10))
        return path
    }

    /// RC charge curve on axes.
    private static func transientCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let base = r.maxY - r.height * 0.12
        let top = r.minY + r.height * 0.12
        line(&path, CGPoint(x: r.minX + r.width * 0.08, y: top), CGPoint(x: r.minX + r.width * 0.08, y: base))
        line(&path, CGPoint(x: r.minX + r.width * 0.08, y: base), CGPoint(x: r.maxX, y: base))
        path.move(to: CGPoint(x: r.minX + r.width * 0.08, y: base))
        for step in 0...16 {
            let t = CGFloat(step) / 16
            let y = base - (base - top) * 0.82 * CGFloat(1 - exp(-3 * Double(t)))
            path.addLine(to: CGPoint(x: r.minX + r.width * 0.08 + r.width * 0.86 * t, y: y))
        }
        return path
    }

    /// Rack U-slots on a current bus.
    private static func rackCurrent(_ r: CGRect) -> Path {
        var path = Path()
        let rail = r.minX + r.width * 0.18
        line(&path, CGPoint(x: rail, y: r.minY + r.height * 0.08), CGPoint(x: rail, y: r.maxY - r.height * 0.08))
        for index in 0..<4 {
            let y = r.minY + r.height * (0.18 + 0.18 * CGFloat(index))
            let width: CGFloat = [0.62, 0.40, 0.54, 0.32][index]
            line(&path, CGPoint(x: rail, y: y), CGPoint(x: rail + r.width * width, y: y))
        }
        return path
    }

    /// Diode schematic — semiconductor I-V.
    private static func diodeIV(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.22, y: y))
        path.move(to: CGPoint(x: r.minX + r.width * 0.22, y: y - r.height * 0.22))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.06, y: y))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.22, y: y + r.height * 0.22))
        path.closeSubpath()
        line(
            &path,
            CGPoint(x: r.midX + r.width * 0.06, y: y - r.height * 0.24),
            CGPoint(x: r.midX + r.width * 0.06, y: y + r.height * 0.24)
        )
        line(&path, CGPoint(x: r.midX + r.width * 0.06, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    /// Intrinsic-safety barrier + check.
    private static func isLoopVerifier(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.08))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.24))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.08))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.24))
        path.closeSubpath()
        path.move(to: CGPoint(x: r.midX - r.width * 0.16, y: r.midY + r.height * 0.02))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.02, y: r.midY + r.height * 0.16))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.20, y: r.midY - r.height * 0.12))
        return path
    }

    /// Transformer plus a tap switch.
    private static func tapChanger(_ r: CGRect) -> Path {
        var path = transformer(r)
        path.move(to: CGPoint(x: r.midX + r.width * 0.18, y: r.minY + r.height * 0.12))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.28))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.18, y: r.minY + r.height * 0.44))
        return path
    }

    /// Distorted sine — THD.
    private static func harmonicsTHD(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        for step in 0...24 {
            let t = CGFloat(step) / 24
            let y = r.midY - sin(t * .pi * 2) * r.height * 0.28 - sin(t * .pi * 6) * r.height * 0.10
            path.addLine(to: CGPoint(x: r.minX + r.width * t, y: y))
        }
        return path
    }

    /// UPS cabinet with an outlet and a battery brick.
    private static func upsSizing(_ r: CGRect) -> Path {
        var path = Path()
        let cabinet = CGRect(
            x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.08,
            width: r.width * 0.76, height: r.height * 0.54
        )
        path.addRoundedRect(in: cabinet, cornerSize: CGSize(width: 3, height: 3))
        line(
            &path,
            CGPoint(x: cabinet.minX + cabinet.width * 0.28, y: cabinet.midY - cabinet.height * 0.18),
            CGPoint(x: cabinet.minX + cabinet.width * 0.28, y: cabinet.midY + cabinet.height * 0.06)
        )
        line(
            &path,
            CGPoint(x: cabinet.maxX - cabinet.width * 0.28, y: cabinet.midY - cabinet.height * 0.18),
            CGPoint(x: cabinet.maxX - cabinet.width * 0.28, y: cabinet.midY + cabinet.height * 0.06)
        )
        circle(&path, CGPoint(x: cabinet.midX, y: cabinet.midY + cabinet.height * 0.18), cabinet.width * 0.07)
        let brick = CGRect(
            x: r.minX + r.width * 0.22, y: r.maxY - r.height * 0.30,
            width: r.width * 0.56, height: r.height * 0.18
        )
        path.addRoundedRect(in: brick, cornerSize: CGSize(width: 2, height: 2))
        return path
    }

    /// Motor M plus a stamped nameplate card.
    private static func motorNameplate(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.28
        let motor = CGPoint(x: r.minX + r.width * 0.34, y: r.midY)
        circle(&path, motor, radius)
        path.move(to: CGPoint(x: motor.x - radius * 0.40, y: motor.y + radius * 0.38))
        path.addLine(to: CGPoint(x: motor.x - radius * 0.40, y: motor.y - radius * 0.38))
        path.addLine(to: CGPoint(x: motor.x, y: motor.y + radius * 0.06))
        path.addLine(to: CGPoint(x: motor.x + radius * 0.40, y: motor.y - radius * 0.38))
        path.addLine(to: CGPoint(x: motor.x + radius * 0.40, y: motor.y + radius * 0.38))
        let plate = CGRect(
            x: r.maxX - r.width * 0.46, y: r.minY + r.height * 0.18,
            width: r.width * 0.40, height: r.height * 0.40
        )
        path.addRoundedRect(in: plate, cornerSize: CGSize(width: 2, height: 2))
        line(&path, CGPoint(x: plate.minX + plate.width * 0.18, y: plate.minY + plate.height * 0.38), CGPoint(x: plate.maxX - plate.width * 0.18, y: plate.minY + plate.height * 0.38))
        line(&path, CGPoint(x: plate.minX + plate.width * 0.18, y: plate.minY + plate.height * 0.62), CGPoint(x: plate.maxX - plate.width * 0.28, y: plate.minY + plate.height * 0.62))
        return path
    }

    /// Nameplate in a camera viewfinder — OCR, not the analyzer.
    private static func motorNameplateOCR(_ r: CGRect) -> Path {
        var path = Path()
        let plate = CGRect(
            x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.30,
            width: r.width * 0.56, height: r.height * 0.40
        )
        path.addRoundedRect(in: plate, cornerSize: CGSize(width: 3, height: 3))
        line(&path, CGPoint(x: plate.minX + plate.width * 0.16, y: plate.minY + plate.height * 0.38), CGPoint(x: plate.maxX - plate.width * 0.16, y: plate.minY + plate.height * 0.38))
        line(&path, CGPoint(x: plate.minX + plate.width * 0.16, y: plate.minY + plate.height * 0.62), CGPoint(x: plate.maxX - plate.width * 0.16, y: plate.minY + plate.height * 0.62))
        let arm = min(r.width, r.height) * 0.14
        let corners = [
            (CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.10), 1.0, 1.0),
            (CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.10), -1.0, 1.0),
            (CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.10), 1.0, -1.0),
            (CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.10), -1.0, -1.0),
        ]
        for (origin, dx, dy) in corners {
            line(&path, origin, CGPoint(x: origin.x + arm * dx, y: origin.y))
            line(&path, origin, CGPoint(x: origin.x, y: origin.y + arm * dy))
        }
        return path
    }

    /// Face in a photo frame — Look Check verdict.
    private static func lookCheck(_ r: CGRect) -> Path {
        var path = Path()
        let frame = CGRect(
            x: r.minX + r.width * 0.14, y: r.minY + r.height * 0.18,
            width: r.width * 0.72, height: r.height * 0.64
        )
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: 4, height: 4))
        circle(&path, CGPoint(x: r.midX, y: r.minY + r.height * 0.40), r.width * 0.11)
        path.move(to: CGPoint(x: r.minX + r.width * 0.30, y: r.minY + r.height * 0.70))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.30, y: r.minY + r.height * 0.70),
            control: CGPoint(x: r.midX, y: r.minY + r.height * 0.54)
        )
        return path
    }

    /// Nichrome heating coil — heater design.
    private static func heaterDesign(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.12, y: y))
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: y))
        for index in 0..<5 {
            let x0 = r.minX + r.width * (0.12 + 0.14 * CGFloat(index))
            path.addCurve(
                to: CGPoint(x: x0 + r.width * 0.14, y: y),
                control1: CGPoint(x: x0 + r.width * 0.04, y: y - r.height * 0.32),
                control2: CGPoint(x: x0 + r.width * 0.10, y: y + r.height * 0.32)
            )
        }
        line(&path, CGPoint(x: r.maxX - r.width * 0.18, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    /// Faraday cage grid — EMP / EMC shielding.
    private static func empEmc(_ r: CGRect) -> Path {
        var path = Path()
        let cage = r.insetBy(dx: r.width * 0.08, dy: r.height * 0.10)
        path.addRoundedRect(in: cage, cornerSize: CGSize(width: 3, height: 3))
        line(&path, CGPoint(x: cage.midX, y: cage.minY), CGPoint(x: cage.midX, y: cage.maxY))
        line(&path, CGPoint(x: cage.minX, y: cage.midY), CGPoint(x: cage.maxX, y: cage.midY))
        return path
    }

    /// Code book with a circuit tick — NEC one-pass calculator.
    private static func necCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let book = CGRect(
            x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.12,
            width: r.width * 0.50, height: r.height * 0.76
        )
        path.addRoundedRect(in: book, cornerSize: CGSize(width: 3, height: 3))
        line(&path, CGPoint(x: book.minX + book.width * 0.18, y: book.minY + book.height * 0.28), CGPoint(x: book.maxX - book.width * 0.18, y: book.minY + book.height * 0.28))
        line(&path, CGPoint(x: book.minX + book.width * 0.18, y: book.minY + book.height * 0.48), CGPoint(x: book.maxX - book.width * 0.18, y: book.minY + book.height * 0.48))
        line(&path, CGPoint(x: book.minX + book.width * 0.18, y: book.minY + book.height * 0.68), CGPoint(x: book.maxX - book.width * 0.30, y: book.minY + book.height * 0.68))
        line(&path, CGPoint(x: book.maxX, y: r.midY), CGPoint(x: r.maxX - r.width * 0.08, y: r.midY))
        circle(&path, CGPoint(x: r.maxX - r.width * 0.08, y: r.midY), r.width * 0.07)
        return path
    }

    /// Single-column worksheet with a Σ total — NEC 220 load calc.
    private static func loadWorksheet(_ r: CGRect) -> Path {
        var path = Path()
        let sheet = r.insetBy(dx: r.width * 0.14, dy: r.height * 0.08)
        path.addRoundedRect(in: sheet, cornerSize: CGSize(width: 3, height: 3))
        for index in 0..<3 {
            let y = sheet.minY + sheet.height * (0.22 + 0.18 * CGFloat(index))
            line(&path, CGPoint(x: sheet.minX + sheet.width * 0.16, y: y), CGPoint(x: sheet.maxX - sheet.width * 0.16, y: y))
        }
        line(&path, CGPoint(x: sheet.minX + sheet.width * 0.16, y: sheet.maxY - sheet.height * 0.16), CGPoint(x: sheet.maxX - sheet.width * 0.16, y: sheet.maxY - sheet.height * 0.16))
        // Σ
        path.move(to: CGPoint(x: sheet.minX + sheet.width * 0.16, y: sheet.maxY - sheet.height * 0.28))
        path.addLine(to: CGPoint(x: sheet.minX + sheet.width * 0.34, y: sheet.maxY - sheet.height * 0.22))
        path.addLine(to: CGPoint(x: sheet.minX + sheet.width * 0.16, y: sheet.maxY - sheet.height * 0.16))
        return path
    }

    /// Numbered cable tags C-1 C-2 — schedule generator.
    private static func cableSchedule(_ r: CGRect) -> Path {
        var path = Path()
        for index in 0..<3 {
            let y = r.minY + r.height * (0.16 + 0.28 * CGFloat(index))
            let tag = CGRect(x: r.minX + r.width * 0.10, y: y, width: r.width * 0.28, height: r.height * 0.20)
            path.addRoundedRect(in: tag, cornerSize: CGSize(width: 2, height: 2))
            line(&path, CGPoint(x: tag.maxX, y: tag.midY), CGPoint(x: r.maxX - r.width * 0.10, y: tag.midY))
        }
        return path
    }

    /// Coil with a plunger — solenoid design.
    private static func solenoidDesign(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.16,
            width: r.width * 0.56, height: r.height * 0.56
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 4, height: 4))
        for index in 0..<4 {
            let y = body.minY + body.height * (0.20 + 0.20 * CGFloat(index))
            line(&path, CGPoint(x: body.minX + 3, y: y), CGPoint(x: body.maxX - 3, y: y))
        }
        line(&path, CGPoint(x: r.midX, y: body.maxY), CGPoint(x: r.midX, y: r.maxY - r.height * 0.04))
        line(
            &path,
            CGPoint(x: r.midX - r.width * 0.10, y: r.maxY - r.height * 0.12),
            CGPoint(x: r.midX + r.width * 0.10, y: r.maxY - r.height * 0.12)
        )
        return path
    }

    /// Tilted PV module + sun.
    private static func solarDesign(_ r: CGRect) -> Path {
        var path = Path()
        let sun = CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.22)
        circle(&path, sun, r.width * 0.12)
        for index in 0..<4 {
            let a = CGFloat(index) * .pi / 2
            line(
                &path,
                CGPoint(x: sun.x + cos(a) * r.width * 0.16, y: sun.y + sin(a) * r.width * 0.16),
                CGPoint(x: sun.x + cos(a) * r.width * 0.24, y: sun.y + sin(a) * r.width * 0.24)
            )
        }
        let p0 = CGPoint(x: r.minX + r.width * 0.10, y: r.maxY - r.height * 0.18)
        let p1 = CGPoint(x: r.minX + r.width * 0.58, y: r.maxY - r.height * 0.14)
        let p2 = CGPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.42)
        let p3 = CGPoint(x: r.minX + r.width * 0.24, y: r.minY + r.height * 0.38)
        path.move(to: p0)
        path.addLine(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        path.closeSubpath()
        line(&path, CGPoint(x: (p0.x + p3.x) / 2, y: (p0.y + p3.y) / 2), CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2))
        return path
    }

    /// Single op-amp — analog workbench.
    private static func analogWorkbench(_ r: CGRect) -> Path {
        var path = Path()
        let left = r.minX + r.width * 0.20
        path.move(to: CGPoint(x: left, y: r.minY + r.height * 0.14))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.midY))
        path.addLine(to: CGPoint(x: left, y: r.maxY - r.height * 0.14))
        path.closeSubpath()
        line(&path, CGPoint(x: r.minX, y: r.minY + r.height * 0.32), CGPoint(x: left, y: r.minY + r.height * 0.32))
        line(&path, CGPoint(x: r.minX, y: r.maxY - r.height * 0.32), CGPoint(x: left, y: r.maxY - r.height * 0.32))
        line(&path, CGPoint(x: r.maxX - r.width * 0.12, y: r.midY), CGPoint(x: r.maxX, y: r.midY))
        let plusY = r.minY + r.height * 0.32
        line(&path, CGPoint(x: left + r.width * 0.08, y: plusY), CGPoint(x: left + r.width * 0.18, y: plusY))
        line(&path, CGPoint(x: left + r.width * 0.13, y: plusY - r.height * 0.05), CGPoint(x: left + r.width * 0.13, y: plusY + r.height * 0.05))
        line(&path, CGPoint(x: left + r.width * 0.08, y: r.maxY - r.height * 0.32), CGPoint(x: left + r.width * 0.18, y: r.maxY - r.height * 0.32))
        return path
    }

    /// Clean sine vs noisy scribble — SNR, not Ohm's law.
    private static func noiseSNR(_ r: CGRect) -> Path {
        var path = Path()
        wave(&path, x0: r.minX, x1: r.maxX, y: r.minY + r.height * 0.32, amp: r.height * 0.14, cycles: 1.5)
        path.move(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.28))
        for step in 0...12 {
            let t = CGFloat(step) / 12
            let jitter: CGFloat = (step.isMultiple(of: 2) ? -1 : 1) * r.height * (0.06 + CGFloat(step % 3) * 0.04)
            path.addLine(to: CGPoint(x: r.minX + r.width * t, y: r.maxY - r.height * 0.28 + jitter))
        }
        return path
    }

    /// TO-220 / 3-pin regulator.
    private static func linearRegulator(_ r: CGRect) -> Path {
        var path = Path()
        let tab = CGRect(
            x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.08,
            width: r.width * 0.56, height: r.height * 0.22
        )
        path.addRoundedRect(in: tab, cornerSize: CGSize(width: 2, height: 2))
        let body = CGRect(
            x: r.minX + r.width * 0.22, y: tab.maxY,
            width: r.width * 0.56, height: r.height * 0.36
        )
        path.addRect(body)
        for index in 0..<3 {
            let x = body.minX + body.width * (0.22 + 0.28 * CGFloat(index))
            line(&path, CGPoint(x: x, y: body.maxY), CGPoint(x: x, y: r.maxY - r.height * 0.08))
        }
        return path
    }

    /// Classic 3-op-amp InAmp.
    private static func instrumentationAmp(_ r: CGRect) -> Path {
        var path = Path()
        func triangle(at origin: CGPoint, width: CGFloat, height: CGFloat) {
            path.move(to: origin)
            path.addLine(to: CGPoint(x: origin.x + width, y: origin.y + height / 2))
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + height))
            path.closeSubpath()
        }
        let w = r.width * 0.30
        let h = r.height * 0.28
        triangle(at: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.10), width: w, height: h)
        triangle(at: CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.10 - h), width: w, height: h)
        triangle(at: CGPoint(x: r.midX + r.width * 0.02, y: r.midY - h / 2), width: w, height: h)
        line(&path, CGPoint(x: r.minX + r.width * 0.08 + w, y: r.minY + r.height * 0.10 + h / 2), CGPoint(x: r.midX + r.width * 0.02, y: r.midY - h * 0.18))
        line(&path, CGPoint(x: r.minX + r.width * 0.08 + w, y: r.maxY - r.height * 0.10 - h / 2), CGPoint(x: r.midX + r.width * 0.02, y: r.midY + h * 0.18))
        return path
    }

    /// ADC stairstep.
    private static func adcDac(_ r: CGRect) -> Path {
        var path = Path()
        let base = r.maxY - r.height * 0.12
        path.move(to: CGPoint(x: r.minX + r.width * 0.08, y: base))
        for index in 0..<4 {
            let x0 = r.minX + r.width * 0.08 + r.width * 0.22 * CGFloat(index)
            let x1 = x0 + r.width * 0.22
            let y = base - r.height * 0.16 * CGFloat(index + 1)
            path.addLine(to: CGPoint(x: x0, y: y))
            path.addLine(to: CGPoint(x: x1, y: y))
        }
        line(&path, CGPoint(x: r.minX + r.width * 0.08, y: base), CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.10))
        return path
    }

    // MARK: - Homework / bench

    /// Two resistors with a tap — voltage divider.
    private static func voltageDivider(_ r: CGRect) -> Path {
        var path = Path()
        let x = r.midX - r.width * 0.10
        line(&path, CGPoint(x: x, y: r.minY), CGPoint(x: x, y: r.minY + r.height * 0.18))
        path.move(to: CGPoint(x: x, y: r.minY + r.height * 0.18))
        path.addLine(to: CGPoint(x: x - r.width * 0.16, y: r.minY + r.height * 0.28))
        path.addLine(to: CGPoint(x: x + r.width * 0.16, y: r.minY + r.height * 0.28))
        path.addLine(to: CGPoint(x: x, y: r.minY + r.height * 0.38))
        line(&path, CGPoint(x: x, y: r.minY + r.height * 0.38), CGPoint(x: x, y: r.midY))
        arrow(&path, from: CGPoint(x: x, y: r.midY), to: CGPoint(x: r.maxX - r.width * 0.06, y: r.midY), head: r.width * 0.10)
        path.move(to: CGPoint(x: x, y: r.midY))
        path.addLine(to: CGPoint(x: x, y: r.maxY - r.height * 0.38))
        path.addLine(to: CGPoint(x: x - r.width * 0.16, y: r.maxY - r.height * 0.28))
        path.addLine(to: CGPoint(x: x + r.width * 0.16, y: r.maxY - r.height * 0.28))
        path.addLine(to: CGPoint(x: x, y: r.maxY - r.height * 0.18))
        line(&path, CGPoint(x: x, y: r.maxY - r.height * 0.18), CGPoint(x: x, y: r.maxY))
        return path
    }

    /// Series pair on the left, parallel pair on the right.
    private static func seriesParallel(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.10, y: y))
        path.addRect(CGRect(x: r.minX + r.width * 0.10, y: y - r.height * 0.10, width: r.width * 0.16, height: r.height * 0.20))
        line(&path, CGPoint(x: r.minX + r.width * 0.26, y: y), CGPoint(x: r.minX + r.width * 0.32, y: y))
        path.addRect(CGRect(x: r.minX + r.width * 0.32, y: y - r.height * 0.10, width: r.width * 0.16, height: r.height * 0.20))
        line(&path, CGPoint(x: r.minX + r.width * 0.48, y: y), CGPoint(x: r.midX, y: y))
        let rail = r.midX + r.width * 0.06
        line(&path, CGPoint(x: r.midX, y: y), CGPoint(x: rail, y: y))
        line(&path, CGPoint(x: rail, y: y - r.height * 0.22), CGPoint(x: rail, y: y + r.height * 0.22))
        path.addRect(CGRect(x: rail + r.width * 0.08, y: y - r.height * 0.32, width: r.width * 0.20, height: r.height * 0.16))
        path.addRect(CGRect(x: rail + r.width * 0.08, y: y + r.height * 0.16, width: r.width * 0.20, height: r.height * 0.16))
        line(&path, CGPoint(x: rail, y: y - r.height * 0.22), CGPoint(x: rail + r.width * 0.08, y: y - r.height * 0.24))
        line(&path, CGPoint(x: rail, y: y + r.height * 0.22), CGPoint(x: rail + r.width * 0.08, y: y + r.height * 0.24))
        let out = rail + r.width * 0.28
        line(&path, CGPoint(x: out, y: y - r.height * 0.24), CGPoint(x: r.maxX - r.width * 0.08, y: y - r.height * 0.24))
        line(&path, CGPoint(x: out, y: y + r.height * 0.24), CGPoint(x: r.maxX - r.width * 0.08, y: y + r.height * 0.24))
        line(&path, CGPoint(x: r.maxX - r.width * 0.08, y: y - r.height * 0.24), CGPoint(x: r.maxX - r.width * 0.08, y: y + r.height * 0.24))
        line(&path, CGPoint(x: r.maxX - r.width * 0.08, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    /// Resistor body with color bands.
    private static func resistorColor(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.14, y: r.midY - r.height * 0.16,
            width: r.width * 0.72, height: r.height * 0.32
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r.width * 0.06, height: r.width * 0.06))
        line(&path, CGPoint(x: r.minX, y: r.midY), CGPoint(x: body.minX, y: r.midY))
        line(&path, CGPoint(x: body.maxX, y: r.midY), CGPoint(x: r.maxX, y: r.midY))
        for fraction in [0.22, 0.40, 0.58, 0.78] as [CGFloat] {
            let x = body.minX + body.width * fraction
            line(&path, CGPoint(x: x, y: body.minY), CGPoint(x: x, y: body.maxY))
        }
        return path
    }

    /// Two unit boxes with a swap — SI / °C / mils converter.
    private static func unitConverter(_ r: CGRect) -> Path {
        var path = Path()
        let a = CGRect(x: r.minX + r.width * 0.04, y: r.minY + r.height * 0.22, width: r.width * 0.36, height: r.height * 0.56)
        let b = CGRect(x: r.maxX - r.width * 0.40, y: r.minY + r.height * 0.22, width: r.width * 0.36, height: r.height * 0.56)
        path.addRoundedRect(in: a, cornerSize: CGSize(width: 3, height: 3))
        path.addRoundedRect(in: b, cornerSize: CGSize(width: 3, height: 3))
        arrow(
            &path,
            from: CGPoint(x: a.maxX + r.width * 0.04, y: r.midY - r.height * 0.10),
            to: CGPoint(x: b.minX - r.width * 0.04, y: r.midY - r.height * 0.10),
            head: r.width * 0.08
        )
        arrow(
            &path,
            from: CGPoint(x: b.minX - r.width * 0.04, y: r.midY + r.height * 0.10),
            to: CGPoint(x: a.maxX + r.width * 0.04, y: r.midY + r.height * 0.10),
            head: r.width * 0.08
        )
        return path
    }

    /// LC tank — frequency / resonance.
    private static func frequencyWave(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.10, y: y))
        let coil0 = r.minX + r.width * 0.10
        let hump = r.width * 0.11
        path.move(to: CGPoint(x: coil0, y: y))
        for index in 0..<3 {
            path.addArc(
                center: CGPoint(x: coil0 + hump * (CGFloat(index) + 0.5), y: y),
                radius: hump / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
        let plate = r.midX + r.width * 0.08
        line(&path, CGPoint(x: coil0 + hump * 3, y: y), CGPoint(x: plate, y: y))
        line(&path, CGPoint(x: plate, y: y - r.height * 0.22), CGPoint(x: plate, y: y + r.height * 0.22))
        line(&path, CGPoint(x: plate + r.width * 0.10, y: y - r.height * 0.22), CGPoint(x: plate + r.width * 0.10, y: y + r.height * 0.22))
        line(&path, CGPoint(x: plate + r.width * 0.10, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    /// LED + current-limit resistor.
    private static func ledRC(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: r.minX + r.width * 0.16, y: y))
        let zig0 = r.minX + r.width * 0.16
        path.move(to: CGPoint(x: zig0, y: y))
        for index in 0..<3 {
            path.addLine(to: CGPoint(
                x: zig0 + r.width * 0.10 * (CGFloat(index) + 0.5),
                y: y + (index.isMultiple(of: 2) ? -r.height * 0.12 : r.height * 0.12)
            ))
        }
        path.addLine(to: CGPoint(x: zig0 + r.width * 0.30, y: y))
        let led = zig0 + r.width * 0.34
        path.move(to: CGPoint(x: led, y: y - r.height * 0.20))
        path.addLine(to: CGPoint(x: led + r.width * 0.18, y: y))
        path.addLine(to: CGPoint(x: led, y: y + r.height * 0.20))
        path.closeSubpath()
        line(&path, CGPoint(x: led + r.width * 0.18, y: y - r.height * 0.16), CGPoint(x: led + r.width * 0.30, y: y - r.height * 0.26))
        line(&path, CGPoint(x: led + r.width * 0.18, y: y + r.height * 0.06), CGPoint(x: led + r.width * 0.30, y: y - r.height * 0.04))
        line(&path, CGPoint(x: led + r.width * 0.18, y: y), CGPoint(x: r.maxX, y: y))
        return path
    }

    // MARK: - Instruments

    /// Cell tower + bars — cellular path.
    private static func cellularStatus(_ r: CGRect) -> Path {
        var path = Path()
        let mast = CGPoint(x: r.minX + r.width * 0.34, y: r.minY + r.height * 0.12)
        line(&path, CGPoint(x: mast.x - r.width * 0.14, y: mast.y + r.height * 0.14), mast)
        line(&path, mast, CGPoint(x: mast.x + r.width * 0.14, y: mast.y + r.height * 0.14))
        line(&path, mast, CGPoint(x: mast.x, y: r.maxY - r.height * 0.10))
        line(&path, CGPoint(x: mast.x - r.width * 0.16, y: r.maxY - r.height * 0.10), CGPoint(x: mast.x + r.width * 0.16, y: r.maxY - r.height * 0.10))
        for (index, height) in [0.22, 0.38, 0.54].enumerated() {
            let x = r.minX + r.width * (0.62 + 0.12 * CGFloat(index))
            line(&path, CGPoint(x: x, y: r.maxY - r.height * 0.14), CGPoint(x: x, y: r.maxY - r.height * (0.14 + height)))
        }
        return path
    }

    /// Wi-Fi fan from a node.
    private static func wifiStatus(_ r: CGRect) -> Path {
        var path = Path()
        let base = CGPoint(x: r.midX, y: r.maxY - r.height * 0.12)
        circle(&path, base, r.width * 0.05)
        for index in 1...3 {
            path.addArc(
                center: base,
                radius: r.width * 0.14 * CGFloat(index),
                startAngle: .degrees(205),
                endAngle: .degrees(335),
                clockwise: false
            )
        }
        return path
    }

    /// Bluetooth rune inside a radar ping — BLE scanner + RSSI radar.
    private static func bluetoothScan(_ r: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: r.midX, y: r.minY + r.height * 0.16)
        let bottom = CGPoint(x: r.midX, y: r.maxY - r.height * 0.16)
        path.move(to: top)
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.16, y: r.midY))
        path.addLine(to: bottom)
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.16, y: r.midY + r.height * 0.16))
        path.addLine(to: top)
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.16, y: r.midY - r.height * 0.16))
        path.addLine(to: bottom)
        path.addArc(
            center: CGPoint(x: r.midX, y: r.midY),
            radius: min(r.width, r.height) * 0.48,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        return path
    }

    /// Microphone + level bars — noise meter.
    private static func noiseMeter(_ r: CGRect) -> Path {
        var path = Path()
        let mic = CGRect(
            x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.16,
            width: r.width * 0.28, height: r.height * 0.46
        )
        path.addRoundedRect(in: mic, cornerSize: CGSize(width: mic.width * 0.45, height: mic.width * 0.45))
        line(&path, CGPoint(x: mic.midX, y: mic.maxY), CGPoint(x: mic.midX, y: r.maxY - r.height * 0.14))
        line(&path, CGPoint(x: mic.midX - r.width * 0.10, y: r.maxY - r.height * 0.08), CGPoint(x: mic.midX + r.width * 0.10, y: r.maxY - r.height * 0.08))
        for (index, height) in [0.22, 0.40, 0.56].enumerated() {
            let x = r.minX + r.width * (0.52 + 0.14 * CGFloat(index))
            line(&path, CGPoint(x: x, y: r.maxY - r.height * 0.14), CGPoint(x: x, y: r.maxY - r.height * (0.14 + height)))
        }
        return path
    }

    /// Spirit-level vial.
    private static func bubbleLevel(_ r: CGRect) -> Path {
        var path = Path()
        let tube = CGRect(
            x: r.minX + r.width * 0.06, y: r.midY - r.height * 0.14,
            width: r.width * 0.88, height: r.height * 0.28
        )
        path.addRoundedRect(in: tube, cornerSize: CGSize(width: tube.height / 2, height: tube.height / 2))
        circle(&path, CGPoint(x: r.midX, y: r.midY), r.height * 0.08)
        line(&path, CGPoint(x: r.midX, y: r.minY + r.height * 0.12), CGPoint(x: r.midX, y: tube.minY - r.height * 0.04))
        return path
    }

    /// Compass rose — magnetometer heading.
    private static func magnetometer(_ r: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) * 0.42
        circle(&path, center, radius)
        arrow(
            &path,
            from: CGPoint(x: center.x, y: center.y + radius * 0.55),
            to: CGPoint(x: center.x, y: center.y - radius * 0.72),
            head: r.width * 0.12
        )
        return path
    }

    /// Aneroid gauge — barometer / altitude.
    private static func barometer(_ r: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: r.midX, y: r.maxY - r.height * 0.10)
        let radius = min(r.width, r.height) * 0.72
        path.addArc(center: center, radius: radius, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        arrow(
            &path,
            from: center,
            to: CGPoint(x: center.x + radius * 0.48, y: center.y - radius * 0.42),
            head: r.width * 0.10
        )
        return path
    }

    /// Bold g with a motion dash — g-force snapshot.
    private static func motionSnapshot(_ r: CGRect) -> Path {
        var path = Path()
        let oval = CGRect(
            x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.12,
            width: r.width * 0.56, height: r.height * 0.76
        )
        path.addEllipse(in: oval)
        path.addArc(
            center: CGPoint(x: oval.midX, y: oval.midY + oval.height * 0.08),
            radius: oval.width * 0.22,
            startAngle: .degrees(200),
            endAngle: .degrees(20),
            clockwise: false
        )
        line(&path, CGPoint(x: oval.midX, y: oval.midY + oval.height * 0.08), CGPoint(x: oval.maxX - oval.width * 0.18, y: oval.midY + oval.height * 0.08))
        line(&path, CGPoint(x: r.minX, y: r.minY + r.height * 0.22), CGPoint(x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.22))
        line(&path, CGPoint(x: r.minX, y: r.midY), CGPoint(x: r.minX + r.width * 0.12, y: r.midY))
        return path
    }

    /// Map pin on a crosshair — GPS position.
    private static func fieldPosition(_ r: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: r.midX, y: r.maxY - r.height * 0.08)
        path.move(to: tip)
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.22, y: r.minY + r.height * 0.36))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.22, y: r.minY + r.height * 0.36))
        path.closeSubpath()
        circle(&path, CGPoint(x: r.midX, y: r.minY + r.height * 0.30), r.width * 0.10)
        line(&path, CGPoint(x: r.minX + r.width * 0.10, y: r.midY + r.height * 0.06), CGPoint(x: r.maxX - r.width * 0.10, y: r.midY + r.height * 0.06))
        return path
    }

    /// Phone battery + thermal tick — device health.
    private static func deviceHealth(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX + r.width * 0.14, y: r.midY - r.height * 0.18,
            width: r.width * 0.52, height: r.height * 0.36
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: 3, height: 3))
        path.addRect(CGRect(x: body.maxX, y: body.midY - r.height * 0.08, width: r.width * 0.07, height: r.height * 0.16))
        path.addArc(
            center: CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.28),
            radius: r.width * 0.12,
            startAngle: .degrees(210),
            endAngle: .degrees(330),
            clockwise: false
        )
        line(
            &path,
            CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.18),
            CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.40)
        )
        return path
    }

    // MARK: - E-bike

    /// Crank / torque arc — e-bike torque & RPM.
    private static func eBikeTorqueRPM(_ r: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) * 0.28
        circle(&path, center, radius)
        circle(&path, center, radius * 0.28)
        path.addArc(center: center, radius: radius * 1.35, startAngle: .degrees(-15), endAngle: .degrees(120), clockwise: false)
        arrow(
            &path,
            from: center,
            to: CGPoint(x: center.x + radius * 0.92, y: center.y - radius * 0.18),
            head: r.width * 0.10
        )
        return path
    }

    /// Drive and driven sprockets on a chain.
    private static func eBikeSprocket(_ r: CGRect) -> Path {
        var path = Path()
        let drive = CGPoint(x: r.minX + r.width * 0.26, y: r.midY)
        let driven = CGPoint(x: r.maxX - r.width * 0.28, y: r.midY)
        circle(&path, drive, r.width * 0.16)
        circle(&path, drive, r.width * 0.06)
        circle(&path, driven, r.width * 0.24)
        circle(&path, driven, r.width * 0.08)
        line(&path, CGPoint(x: drive.x, y: drive.y - r.width * 0.16), CGPoint(x: driven.x, y: driven.y - r.width * 0.24))
        line(&path, CGPoint(x: drive.x, y: drive.y + r.width * 0.16), CGPoint(x: driven.x, y: driven.y + r.width * 0.24))
        return path
    }

    /// Pack + road arrow — range estimator.
    private static func eBikeRange(_ r: CGRect) -> Path {
        var path = Path()
        let pack = CGRect(
            x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.14,
            width: r.width * 0.40, height: r.height * 0.28
        )
        path.addRoundedRect(in: pack, cornerSize: CGSize(width: 3, height: 3))
        path.addRect(CGRect(x: pack.maxX, y: pack.midY - r.height * 0.06, width: r.width * 0.06, height: r.height * 0.12))
        arrow(
            &path,
            from: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.24),
            to: CGPoint(x: r.maxX - r.width * 0.10, y: r.maxY - r.height * 0.24),
            head: r.width * 0.12
        )
        return path
    }

    /// Cylindrical cells in a pack outline.
    private static func eBikePackDesigner(_ r: CGRect) -> Path {
        var path = Path()
        let pack = r.insetBy(dx: r.width * 0.10, dy: r.height * 0.16)
        path.addRoundedRect(in: pack, cornerSize: CGSize(width: 4, height: 4))
        let cell = min(r.width, r.height) * 0.16
        for row in 0..<2 {
            for col in 0..<2 {
                let x = pack.minX + pack.width * (0.28 + 0.44 * CGFloat(col))
                let y = pack.minY + pack.height * (0.30 + 0.40 * CGFloat(row))
                circle(&path, CGPoint(x: x, y: y), cell / 2)
            }
        }
        return path
    }

    /// Flat nickel strip with thickness ticks.
    private static func nickelStrip(_ r: CGRect) -> Path {
        var path = Path()
        let strip = CGRect(
            x: r.minX + r.width * 0.14, y: r.midY - r.height * 0.10,
            width: r.width * 0.72, height: r.height * 0.20
        )
        path.addRect(strip)
        line(&path, CGPoint(x: strip.minX - r.width * 0.06, y: strip.minY), CGPoint(x: strip.minX - r.width * 0.06, y: strip.maxY))
        line(&path, CGPoint(x: strip.minX - r.width * 0.10, y: strip.minY), CGPoint(x: strip.minX - r.width * 0.02, y: strip.minY))
        line(&path, CGPoint(x: strip.minX - r.width * 0.10, y: strip.maxY), CGPoint(x: strip.minX - r.width * 0.02, y: strip.maxY))
        return path
    }

    /// Unity-feedback loop — control systems lab.
    private static func controlSystems(_ r: CGRect) -> Path {
        var path = Path()
        let y = r.midY
        let sum = CGPoint(x: r.minX + r.width * 0.24, y: y)
        circle(&path, sum, r.width * 0.11)
        line(&path, CGPoint(x: sum.x - r.width * 0.05, y: y), CGPoint(x: sum.x + r.width * 0.05, y: y))
        line(&path, CGPoint(x: sum.x, y: y - r.height * 0.05), CGPoint(x: sum.x, y: y + r.height * 0.05))
        let box = CGRect(
            x: r.minX + r.width * 0.48, y: r.minY + r.height * 0.28,
            width: r.width * 0.32, height: r.height * 0.32
        )
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3, height: 3))
        line(&path, CGPoint(x: r.minX, y: y), CGPoint(x: sum.x - r.width * 0.11, y: y))
        line(&path, CGPoint(x: sum.x + r.width * 0.11, y: y), CGPoint(x: box.minX, y: y))
        line(&path, CGPoint(x: box.maxX, y: y), CGPoint(x: r.maxX, y: y))
        let ret = r.maxY - r.height * 0.14
        line(&path, CGPoint(x: r.maxX - r.width * 0.08, y: y), CGPoint(x: r.maxX - r.width * 0.08, y: ret))
        line(&path, CGPoint(x: r.maxX - r.width * 0.08, y: ret), CGPoint(x: sum.x, y: ret))
        line(&path, CGPoint(x: sum.x, y: ret), CGPoint(x: sum.x, y: sum.y + r.width * 0.11))
        return path
    }
}
