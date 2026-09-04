import SwiftUI

// MARK: - Beckify Instrument Glyph Set (app-only)
//
// Original schematic linework for the Field EE Toolbox — vector Canvas paths,
// no image assets, dual-stroke depth, category-colored wells.
//
// Units:
//   • `ToolGlyph`     — per-tool schematic (`GlyphKind`, 1:1 with `ToolID`)
//   • `CategoryGlyph` — shelf mark for each `ToolCategory`
//   • `IconWell`      — pastel well + crisp glyph (grid / list / headers)

/// Schematic stroke for one toolbox tool. Drawn as vector paths so it stays
/// crisp at any size, follows the theme, and ships no image assets.
///
/// Each `ToolID` maps 1:1 to a distinct `GlyphKind` — no unrelated tools share
/// the same schematic. When `toolID` is supplied the stroke is a
/// category-colored gradient with a small per-tool hue nudge.
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
        let base = max(Theme.Stroke.icon, size * 0.052)
        return selected ? base * 1.12 : base
    }

    private var underWidth: CGFloat {
        max(Theme.Stroke.iconUnder * (size / 44), lineWidth * 1.85)
    }

    var body: some View {
        Canvas { context, canvasSize in
            // Slightly tighter inset so schematics read larger at tile sizes.
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.12, dy: canvasSize.height * 0.12)
            let path = kind.path(in: rect)
            let mainStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            let underStyle = StrokeStyle(lineWidth: underWidth, lineCap: .round, lineJoin: .round)

            // Soft understroke — second ink pass for body without fill blobs.
            context.stroke(
                path,
                with: .color(Color.black.opacity(selected ? 0.22 : 0.12)),
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
        .hueRotation(toolID.map(Theme.toolHueNudge) ?? .zero)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Soft colored well that frames a `ToolGlyph` — the graphic unit of the grid
/// and list rows (pastel container + crisp schematic).
struct IconWell: View {
    let toolID: ToolID
    var size: CGFloat = 56
    var glyphSize: CGFloat? = nil
    var selected: Bool = true
    var circular: Bool = false

    private var category: ToolCategory? { ToolboxCatalog.category(of: toolID) }
    private var resolvedGlyph: CGFloat { glyphSize ?? size * 0.58 }
    private var corner: CGFloat {
        if circular { return size / 2 }
        // Scale the well radius with size so large grid tiles stay soft, not boxy.
        return min(Theme.Radius.tile, max(Theme.Radius.well * 0.75, size * 0.22))
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
        let base = max(Theme.Stroke.icon, size * 0.06)
        return selected ? base * 1.1 : base
    }

    private var underWidth: CGFloat {
        max(Theme.Stroke.iconUnder * (size / 28), lineWidth * 1.7)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.14, dy: canvasSize.height * 0.14)
            let path = CategoryGlyphKind(category).path(in: rect)
            let colors = Theme.categoryColors(category)
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [colors.primary, colors.secondary]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            context.stroke(
                path,
                with: .color(Color.black.opacity(0.18)),
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
        min(Theme.Radius.tile, max(Theme.Radius.well * 0.65, size * 0.22))
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
        }
    }
}

enum GlyphKind {
    case ohmsLaw
    case power
    case powerWizard
    case voltageDrop
    case conduitFill
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

    // swiftlint:disable:next cyclomatic_complexity
    func path(in rect: CGRect) -> Path {
        switch self {
        case .ohmsLaw: return Self.ohmsLaw(rect)
        case .power: return Self.power(rect)
        case .powerWizard: return Self.powerWizard(rect)
        case .voltageDrop: return Self.voltageDrop(rect)
        case .conduitFill: return Self.conduitFill(rect)
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
        }
    }

    // MARK: - Power & field calculators

    private static func ohmsLaw(_ r: CGRect) -> Path {
        var path = Path()
        let midY = r.midY
        let nodeR = r.width * 0.05

        path.move(to: CGPoint(x: r.minX, y: midY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.14, y: midY))
        path.addEllipse(in: CGRect(x: r.minX - nodeR, y: midY - nodeR, width: nodeR * 2, height: nodeR * 2))

        let zigStart = r.minX + r.width * 0.18
        let zigWidth = r.width * 0.44
        let step = zigWidth / 6
        let peak = r.height * 0.2
        path.move(to: CGPoint(x: zigStart, y: midY))
        for index in 0..<6 {
            let x = zigStart + step * (CGFloat(index) + 0.5)
            path.addLine(to: CGPoint(x: x, y: midY + (index.isMultiple(of: 2) ? -peak : peak)))
        }
        path.addLine(to: CGPoint(x: zigStart + zigWidth, y: midY))

        path.move(to: CGPoint(x: r.maxX - r.width * 0.14, y: midY))
        path.addLine(to: CGPoint(x: r.maxX, y: midY))
        path.addEllipse(in: CGRect(x: r.maxX - nodeR, y: midY - nodeR, width: nodeR * 2, height: nodeR * 2))

        let mark = r.width * 0.07
        path.move(to: CGPoint(x: r.minX + r.width * 0.04, y: midY - r.height * 0.28))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.04, y: midY - r.height * 0.28 + mark))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.04 - mark, y: midY - r.height * 0.28))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.04, y: midY - r.height * 0.28))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.04, y: midY - r.height * 0.28 + mark))
        return path
    }

    private static func power(_ r: CGRect) -> Path {
        var path = Path()
        let apex = CGPoint(x: r.midX, y: r.minY + r.height * 0.08)
        let baseLeft = CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.08)
        let baseRight = CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY - r.height * 0.08)
        path.move(to: apex)
        path.addLine(to: baseLeft)
        path.addLine(to: baseRight)
        path.closeSubpath()

        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.08))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY - r.height * 0.08))

        let waveY = r.midY + r.height * 0.08
        path.move(to: CGPoint(x: r.minX + r.width * 0.18, y: waveY))
        for step in 0...24 {
            let t = CGFloat(step) / 24
            let y = waveY - sin(t * .pi * 2) * r.height * 0.12
            path.addLine(to: CGPoint(x: r.minX + r.width * (0.18 + 0.64 * t), y: y))
        }
        return path
    }

    private static func powerWizard(_ r: CGRect) -> Path {
        var path = power(r)
        let tip = CGPoint(x: r.midX + r.width * 0.22, y: r.minY + r.height * 0.18)
        path.move(to: CGPoint(x: r.midX + r.width * 0.06, y: r.minY + r.height * 0.34))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.14, y: r.minY + r.height * 0.1))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.3, y: r.minY + r.height * 0.26))
        return path
    }

    private static func voltageDrop(_ r: CGRect) -> Path {
        var path = Path()
        let runY = r.midY
        path.move(to: CGPoint(x: r.minX, y: runY))
        path.addLine(to: CGPoint(x: r.maxX, y: runY))

        for index in 0..<4 {
            let x = r.minX + r.width * (0.18 + 0.2 * CGFloat(index))
            let tickTop = runY - r.height * (0.34 - 0.06 * CGFloat(index))
            path.move(to: CGPoint(x: x, y: runY))
            path.addLine(to: CGPoint(x: x, y: tickTop))
            path.addLine(to: CGPoint(x: x + r.width * 0.08, y: tickTop))
        }

        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: runY - r.height * 0.36))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: runY - r.height * 0.14))
        return path
    }

    private static func conduitFill(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.42
        path.addEllipse(in: CGRect(
            x: r.midX - radius, y: r.midY - radius,
            width: radius * 2, height: radius * 2
        ))
        let inner = radius * 0.26
        for angle in stride(from: CGFloat(0), to: CGFloat(360), by: CGFloat(120)) {
            let radians = angle * .pi / 180
            let center = CGPoint(
                x: r.midX + cos(radians) * radius * 0.42,
                y: r.midY + sin(radians) * radius * 0.42
            )
            path.addEllipse(in: CGRect(
                x: center.x - inner, y: center.y - inner,
                width: inner * 2, height: inner * 2
            ))
        }
        path.move(to: CGPoint(x: r.midX - radius * 0.18, y: r.midY - radius * 0.18))
        path.addLine(to: CGPoint(x: r.midX + radius * 0.18, y: r.midY + radius * 0.18))
        return path
    }

    private static func transformer(_ r: CGRect) -> Path {
        var path = Path()
        let coreLeft = r.midX - r.width * 0.04
        let coreRight = r.midX + r.width * 0.04
        path.move(to: CGPoint(x: coreLeft, y: r.minY))
        path.addLine(to: CGPoint(x: coreLeft, y: r.maxY))
        path.move(to: CGPoint(x: coreRight, y: r.minY))
        path.addLine(to: CGPoint(x: coreRight, y: r.maxY))

        let humpRadius = r.height * 0.13
        for index in 0..<3 {
            let y = r.minY + r.height * (0.26 + 0.24 * CGFloat(index))
            path.addArc(
                center: CGPoint(x: coreLeft, y: y),
                radius: humpRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: coreRight, y: y),
                radius: humpRadius,
                startAngle: .degrees(270),
                endAngle: .degrees(90),
                clockwise: false
            )
        }
        path.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.midY))
        path.addLine(to: CGPoint(x: coreLeft - humpRadius, y: r.midY))
        path.move(to: CGPoint(x: coreRight + humpRadius, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.midY))
        return path
    }

    private static func timer555(_ r: CGRect) -> Path {
        var path = Path()
        let body = r.insetBy(dx: r.width * 0.14, dy: r.height * 0.18)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r.width * 0.06, height: r.width * 0.06))
        for index in 0..<3 {
            let y = body.minY + body.height * (0.25 + 0.25 * CGFloat(index))
            path.move(to: CGPoint(x: body.minX, y: y))
            path.addLine(to: CGPoint(x: r.minX, y: y))
            path.move(to: CGPoint(x: body.maxX, y: y))
            path.addLine(to: CGPoint(x: r.maxX, y: y))
        }
        let waveY = r.midY
        path.move(to: CGPoint(x: r.maxX - r.width * 0.28, y: waveY + r.height * 0.14))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.18, y: waveY + r.height * 0.14))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.18, y: waveY - r.height * 0.14))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: waveY - r.height * 0.14))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: waveY + r.height * 0.14))
        path.addLine(to: CGPoint(x: r.maxX, y: waveY + r.height * 0.14))
        return path
    }

    private static func motorFLA(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.38
        path.addEllipse(in: CGRect(
            x: r.midX - radius, y: r.midY - radius,
            width: radius * 2, height: radius * 2
        ))
        let inset = radius * 0.55
        path.move(to: CGPoint(x: r.midX - inset, y: r.midY + inset * 0.75))
        path.addLine(to: CGPoint(x: r.midX - inset, y: r.midY - inset * 0.75))
        path.addLine(to: CGPoint(x: r.midX, y: r.midY + inset * 0.15))
        path.addLine(to: CGPoint(x: r.midX + inset, y: r.midY - inset * 0.75))
        path.addLine(to: CGPoint(x: r.midX + inset, y: r.midY + inset * 0.75))
        for index in 0..<3 {
            let angle = CGFloat(index) * .pi / 3 - .pi / 2
            path.move(to: CGPoint(x: r.midX, y: r.midY))
            path.addLine(to: CGPoint(
                x: r.midX + cos(angle) * radius * 0.72,
                y: r.midY + sin(angle) * radius * 0.72
            ))
        }
        return path
    }

    private static func wireAmpacity(_ r: CGRect) -> Path {
        var path = Path()
        let conductor = CGRect(
            x: r.midX - r.width * 0.08,
            y: r.minY + r.height * 0.12,
            width: r.width * 0.16,
            height: r.height * 0.76
        )
        path.addRoundedRect(in: conductor, cornerSize: CGSize(width: r.width * 0.04, height: r.width * 0.04))
        for index in 0..<3 {
            let y = r.minY + r.height * (0.22 + 0.18 * CGFloat(index))
            path.move(to: CGPoint(x: conductor.maxX + r.width * 0.06, y: y))
            path.addQuadCurve(
                to: CGPoint(x: conductor.maxX + r.width * 0.22, y: y - r.height * 0.04),
                control: CGPoint(x: conductor.maxX + r.width * 0.14, y: y - r.height * 0.1)
            )
        }
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.18))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.22, y: r.maxY - r.height * 0.18))
        path.move(to: CGPoint(x: r.minX + r.width * 0.17, y: r.maxY - r.height * 0.24))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.17, y: r.maxY - r.height * 0.12))
        return path
    }

    private static func receptacleSelector(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.4
        path.addEllipse(in: CGRect(
            x: r.midX - radius, y: r.midY - radius,
            width: radius * 2, height: radius * 2
        ))
        let slot = radius * 0.4
        path.move(to: CGPoint(x: r.midX - radius * 0.38, y: r.midY - slot))
        path.addLine(to: CGPoint(x: r.midX - radius * 0.38, y: r.midY + slot * 0.15))
        path.move(to: CGPoint(x: r.midX + radius * 0.38, y: r.midY - slot))
        path.addLine(to: CGPoint(x: r.midX + radius * 0.38, y: r.midY + slot * 0.15))
        path.addEllipse(in: CGRect(
            x: r.midX - slot * 0.32, y: r.midY + slot * 0.42,
            width: slot * 0.64, height: slot * 0.64
        ))
        path.move(to: CGPoint(x: r.midX - radius, y: r.midY))
        path.addLine(to: CGPoint(x: r.midX - radius * 0.62, y: r.midY))
        path.move(to: CGPoint(x: r.midX + radius * 0.62, y: r.midY))
        path.addLine(to: CGPoint(x: r.midX + radius, y: r.midY))
        return path
    }

    private static func reactance(_ r: CGRect) -> Path {
        var path = Path()
        let topY = r.midY - r.height * 0.18
        let bottomY = r.midY + r.height * 0.18
        path.move(to: CGPoint(x: r.minX, y: topY))
        for step in 0...32 {
            let t = CGFloat(step) / 32
            let y = topY - sin(t * .pi * 2) * r.height * 0.14
            path.addLine(to: CGPoint(x: r.minX + r.width * t, y: y))
        }
        path.move(to: CGPoint(x: r.minX, y: bottomY))
        for step in 0...32 {
            let t = CGFloat(step) / 32
            let y = bottomY - sin(t * .pi * 2 + .pi / 3) * r.height * 0.14
            path.addLine(to: CGPoint(x: r.minX + r.width * t, y: y))
        }
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: topY - r.height * 0.14))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.12, y: bottomY + r.height * 0.14))
        return path
    }

    private static func powerFactor(_ r: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: r.minX + r.width * 0.14, y: r.maxY - r.height * 0.12)
        let pEnd = CGPoint(x: r.maxX - r.width * 0.1, y: origin.y)
        let sEnd = CGPoint(x: origin.x, y: r.minY + r.height * 0.12)
        path.move(to: origin)
        path.addLine(to: pEnd)
        path.addLine(to: sEnd)
        path.closeSubpath()
        path.addArc(
            center: origin,
            radius: r.width * 0.18,
            startAngle: .degrees(0),
            endAngle: .degrees(-55),
            clockwise: true
        )
        path.move(to: CGPoint(x: origin.x + r.width * 0.2, y: origin.y - r.height * 0.02))
        path.addLine(to: CGPoint(x: pEnd.x - r.width * 0.12, y: sEnd.y + r.height * 0.08))
        return path
    }

    private static func shortCircuit(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.12))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.18, y: r.maxY - r.height * 0.12))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.2))
        path.move(to: CGPoint(x: r.midX + r.width * 0.16, y: r.maxY - r.height * 0.12))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.12))

        let bolt = [
            CGPoint(x: r.midX - r.width * 0.02, y: r.minY + r.height * 0.22),
            CGPoint(x: r.midX - r.width * 0.12, y: r.midY),
            CGPoint(x: r.midX + r.width * 0.02, y: r.midY - r.height * 0.04),
            CGPoint(x: r.midX - r.width * 0.04, y: r.maxY - r.height * 0.22),
            CGPoint(x: r.midX + r.width * 0.12, y: r.midY - r.height * 0.08),
            CGPoint(x: r.midX, y: r.midY - r.height * 0.12),
        ]
        path.move(to: bolt[0])
        for point in bolt.dropFirst() { path.addLine(to: point) }
        return path
    }

    private static func circularMils(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.28
        path.addEllipse(in: CGRect(
            x: r.midX - radius, y: r.midY - radius * 0.2,
            width: radius * 2, height: radius * 2
        ))
        path.move(to: CGPoint(x: r.midX - radius, y: r.midY - radius * 0.2))
        path.addLine(to: CGPoint(x: r.midX - radius, y: r.maxY - r.height * 0.08))
        path.move(to: CGPoint(x: r.midX + radius, y: r.midY - radius * 0.2))
        path.addLine(to: CGPoint(x: r.midX + radius, y: r.maxY - r.height * 0.08))
        path.move(to: CGPoint(x: r.midX - radius - r.width * 0.06, y: r.maxY - r.height * 0.08))
        path.addLine(to: CGPoint(x: r.midX + radius + r.width * 0.06, y: r.maxY - r.height * 0.08))
        for tick in [-1.0, 1.0] as [CGFloat] {
            let x = r.midX + tick * (radius + r.width * 0.06)
            path.move(to: CGPoint(x: x, y: r.maxY - r.height * 0.08))
            path.addLine(to: CGPoint(x: x, y: r.maxY - r.height * 0.14))
        }
        return path
    }

    private static func loadFactors(_ r: CGRect) -> Path {
        var path = Path()
        let baseY = r.maxY - r.height * 0.12
        path.move(to: CGPoint(x: r.minX + r.width * 0.08, y: baseY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: baseY))
        let heights: [CGFloat] = [0.22, 0.48, 0.36, 0.62, 0.44, 0.78]
        let barW = r.width * 0.1
        let gap = (r.width * 0.84 - barW * CGFloat(heights.count)) / CGFloat(heights.count - 1)
        for (index, height) in heights.enumerated() {
            let x = r.minX + r.width * 0.08 + (barW + gap) * CGFloat(index)
            let bar = CGRect(x: x, y: baseY - r.height * height, width: barW, height: r.height * height)
            path.addRoundedRect(in: bar, cornerSize: CGSize(width: barW * 0.2, height: barW * 0.2))
        }
        path.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.16))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.28))
        return path
    }

    private static func signalScaling(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY))
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.move(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.2))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.08))
        path.move(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.2))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.06, y: r.maxY - r.height * 0.2))
        path.move(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.2))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.26))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.08))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.08))
        return path
    }

    private static func modbusAddress(_ r: CGRect) -> Path {
        var path = Path()
        let cell = r.width * 0.2
        for row in 0..<2 {
            for col in 0..<3 {
                let rect = CGRect(
                    x: r.minX + r.width * 0.1 + CGFloat(col) * (cell + r.width * 0.04),
                    y: r.minY + r.height * (0.18 + 0.28 * CGFloat(row)),
                    width: cell,
                    height: r.height * 0.22
                )
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: r.width * 0.03, height: r.width * 0.03))
            }
        }
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.16))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.28, y: r.maxY - r.height * 0.16))
        path.move(to: CGPoint(x: r.minX + r.width * 0.34, y: r.maxY - r.height * 0.22))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.34, y: r.maxY - r.height * 0.1))
        path.move(to: CGPoint(x: r.minX + r.width * 0.42, y: r.maxY - r.height * 0.16))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.maxY - r.height * 0.16))
        return path
    }

    private static func plcTimer(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.18, y: r.midY))
        let block = CGRect(
            x: r.minX + r.width * 0.18,
            y: r.midY - r.height * 0.18,
            width: r.width * 0.34,
            height: r.height * 0.36
        )
        path.addRoundedRect(in: block, cornerSize: CGSize(width: r.width * 0.04, height: r.width * 0.04))
        path.move(to: CGPoint(x: block.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.move(to: CGPoint(x: block.minX + r.width * 0.08, y: block.minY + r.height * 0.1))
        path.addLine(to: CGPoint(x: block.minX + r.width * 0.08, y: block.maxY - r.height * 0.1))
        path.move(to: CGPoint(x: block.maxX - r.width * 0.08, y: block.minY + r.height * 0.1))
        path.addLine(to: CGPoint(x: block.maxX - r.width * 0.08, y: block.maxY - r.height * 0.1))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.16, y: r.minY + r.height * 0.18))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.18))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.1))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.22))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.34))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.26))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.16, y: r.minY + r.height * 0.26))
        return path
    }

    private static func panelDirectory(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: r, cornerSize: CGSize(width: r.width * 0.08, height: r.width * 0.08))
        for index in 0..<4 {
            let y = r.minY + r.height * (0.24 + 0.16 * CGFloat(index))
            path.move(to: CGPoint(x: r.minX + r.width * 0.14, y: y))
            path.addLine(to: CGPoint(x: r.minX + r.width * 0.26, y: y))
            path.move(to: CGPoint(x: r.minX + r.width * 0.32, y: y))
            path.addLine(to: CGPoint(x: r.midX - r.width * 0.04, y: y))
            path.move(to: CGPoint(x: r.midX + r.width * 0.06, y: y))
            path.addLine(to: CGPoint(x: r.maxX - r.width * 0.14, y: y))
        }
        path.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.1))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.1))
        return path
    }

    // MARK: - Expansion pack

    /// Tachometer: an open gauge arc, five ticks, and a needle past center.
    private static func motorSpeed(_ r: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: r.midX, y: r.midY + r.height * 0.08)
        let radius = min(r.width, r.height) * 0.4
        let startDeg: CGFloat = 200
        let endDeg: CGFloat = -20
        let steps = 24

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let rad = (startDeg + (endDeg - startDeg) * t) * .pi / 180
            let point = CGPoint(x: center.x + cos(rad) * radius, y: center.y - sin(rad) * radius)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        for tick in 0...4 {
            let t = CGFloat(tick) / 4
            let rad = (startDeg + (endDeg - startDeg) * t) * .pi / 180
            let outer = CGPoint(x: center.x + cos(rad) * radius, y: center.y - sin(rad) * radius)
            let inner = CGPoint(x: center.x + cos(rad) * radius * 0.8, y: center.y - sin(rad) * radius * 0.8)
            path.move(to: inner)
            path.addLine(to: outer)
        }

        let needleRad: CGFloat = 55 * .pi / 180
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x + cos(needleRad) * radius * 0.68, y: center.y - sin(needleRad) * radius * 0.68))

        let hub = radius * 0.09
        path.addEllipse(in: CGRect(x: center.x - hub, y: center.y - hub, width: hub * 2, height: hub * 2))
        return path
    }

    /// A transmitter dot with three arcs of "radio waves" fanning upward from it.
    private static func rfLink(_ r: CGRect) -> Path {
        var path = Path()
        let source = CGPoint(x: r.midX, y: r.maxY - r.height * 0.14)

        let dot = r.width * 0.045
        path.addEllipse(in: CGRect(x: source.x - dot, y: source.y - dot, width: dot * 2, height: dot * 2))

        for ring in 1...3 {
            let radius = r.height * 0.17 * CGFloat(ring)
            let steps = 16
            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let rad = (200 + 140 * t) * .pi / 180
                let point = CGPoint(x: source.x + cos(rad) * radius, y: source.y + sin(rad) * radius)
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
        return path
    }

    /// A dial circle with three arrows from center, at different angles and
    /// lengths — a phasor diagram, not a balanced-set illustration.
    private static func phasorDiagram(_ r: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) * 0.38

        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

        let vectors: [(angleDeg: CGFloat, length: CGFloat)] = [
            (-90, radius * 0.92),
            (30, radius * 0.68),
            (150, radius * 0.78),
        ]
        for vector in vectors {
            let rad = vector.angleDeg * .pi / 180
            let tip = CGPoint(x: center.x + cos(rad) * vector.length, y: center.y + sin(rad) * vector.length)
            path.move(to: center)
            path.addLine(to: tip)

            let arrowLength = radius * 0.16
            let spread: CGFloat = 24 * .pi / 180
            for sign: CGFloat in [-1, 1] {
                let backRad = rad + .pi + sign * spread
                path.move(to: tip)
                path.addLine(to: CGPoint(x: tip.x + cos(backRad) * arrowLength, y: tip.y + sin(backRad) * arrowLength))
            }
        }
        return path
    }

    /// A four-cell register outline with a literal 1-0-1-0 bit pattern inside.
    private static func numberBase(_ r: CGRect) -> Path {
        var path = Path()
        let boxWidth = r.width * 0.86
        let boxHeight = r.height * 0.42
        let box = CGRect(x: r.midX - boxWidth / 2, y: r.midY - boxHeight / 2, width: boxWidth, height: boxHeight)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: r.width * 0.05, height: r.width * 0.05))

        for i in 1...3 {
            let x = box.minX + boxWidth * CGFloat(i) / 4
            path.move(to: CGPoint(x: x, y: box.minY))
            path.addLine(to: CGPoint(x: x, y: box.maxY))
        }

        let bits = [true, false, true, false]
        for (index, isOne) in bits.enumerated() where isOne {
            let x = box.minX + boxWidth * (CGFloat(index) + 0.5) / 4
            path.move(to: CGPoint(x: x, y: box.midY - boxHeight * 0.24))
            path.addLine(to: CGPoint(x: x, y: box.midY + boxHeight * 0.24))
        }
        return path
    }

    /// Two schematic battery cells (long/short plate pairs) wired in series.
    private static func batteryBank(_ r: CGRect) -> Path {
        var path = Path()
        let midY = r.midY
        let gap = r.width * 0.16
        let firstLongX = r.midX - gap * 1.5
        let firstShortX = firstLongX + gap * 0.5
        let secondLongX = firstLongX + gap * 2
        let secondShortX = secondLongX + gap * 0.5

        for longX in [firstLongX, secondLongX] {
            path.move(to: CGPoint(x: longX, y: midY - r.height * 0.22))
            path.addLine(to: CGPoint(x: longX, y: midY + r.height * 0.22))
        }
        for shortX in [firstShortX, secondShortX] {
            path.move(to: CGPoint(x: shortX, y: midY - r.height * 0.1))
            path.addLine(to: CGPoint(x: shortX, y: midY + r.height * 0.1))
        }

        path.move(to: CGPoint(x: firstShortX, y: midY))
        path.addLine(to: CGPoint(x: secondLongX, y: midY))
        path.move(to: CGPoint(x: r.minX + r.width * 0.06, y: midY))
        path.addLine(to: CGPoint(x: firstLongX, y: midY))
        path.move(to: CGPoint(x: secondShortX, y: midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: midY))
        return path
    }

    /// An open book — two pages meeting at a spine, with a couple of text lines.
    private static func referenceLibrary(_ r: CGRect) -> Path {
        var path = Path()
        let spineX = r.midX
        let baseY = r.maxY - r.height * 0.16
        let topY = r.minY + r.height * 0.14

        path.move(to: CGPoint(x: spineX, y: topY))
        path.addLine(to: CGPoint(x: r.minX, y: topY + r.height * 0.08))
        path.addLine(to: CGPoint(x: r.minX, y: baseY))
        path.addLine(to: CGPoint(x: spineX, y: baseY - r.height * 0.06))
        path.closeSubpath()

        path.move(to: CGPoint(x: spineX, y: topY))
        path.addLine(to: CGPoint(x: r.maxX, y: topY + r.height * 0.08))
        path.addLine(to: CGPoint(x: r.maxX, y: baseY))
        path.addLine(to: CGPoint(x: spineX, y: baseY - r.height * 0.06))
        path.closeSubpath()

        for index in 0..<2 {
            let y = topY + r.height * (0.3 + 0.14 * CGFloat(index))
            path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: y))
            path.addLine(to: CGPoint(x: spineX - r.width * 0.06, y: y))
            path.move(to: CGPoint(x: spineX + r.width * 0.06, y: y))
            path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: y))
        }
        return path
    }

    /// A laminated core with a closed flux loop and a direction arrow.
    private static func magneticCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let coreWidth = r.width * 0.26
        let coreHeight = r.height * 0.58
        let coreRect = CGRect(x: r.midX - coreWidth / 2, y: r.midY - coreHeight / 2, width: coreWidth, height: coreHeight)
        path.addRoundedRect(in: coreRect, cornerSize: CGSize(width: r.width * 0.03, height: r.width * 0.03))

        let loopRect = CGRect(x: r.minX + r.width * 0.04, y: r.minY + r.height * 0.08, width: r.width * 0.92, height: r.height * 0.84)
        path.addEllipse(in: loopRect)

        let arrowSize = r.width * 0.07
        let apex = CGPoint(x: r.midX, y: loopRect.minY)
        path.move(to: CGPoint(x: apex.x - arrowSize, y: apex.y + arrowSize))
        path.addLine(to: apex)
        path.addLine(to: CGPoint(x: apex.x + arrowSize, y: apex.y + arrowSize))
        return path
    }

    /// A fiber tip with its acceptance cone and one incoming ray.
    private static func fiberLink(_ r: CGRect) -> Path {
        var path = Path()
        let apex = CGPoint(x: r.minX + r.width * 0.12, y: r.midY)
        let coneHeight = r.height * 0.34

        path.move(to: CGPoint(x: r.maxX - r.width * 0.08, y: apex.y - coneHeight))
        path.addLine(to: apex)
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: apex.y + coneHeight))

        path.move(to: apex)
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: apex.y))

        path.move(to: CGPoint(x: r.minX, y: apex.y - r.height * 0.4))
        path.addLine(to: apex)
        return path
    }

    /// A beam-waist silhouette — narrow at center, flaring at both edges.
    private static func gaussianBeam(_ r: CGRect) -> Path {
        var path = Path()
        let waistX = r.midX
        let maxHalfHeight = r.height * 0.4
        let waistHalfHeight = r.height * 0.08
        let steps = 20

        func halfHeight(at x: CGFloat) -> CGFloat {
            let normalized = abs(x - waistX) / (r.width / 2)
            return waistHalfHeight + (maxHalfHeight - waistHalfHeight) * (normalized * normalized)
        }

        path.move(to: CGPoint(x: r.minX, y: r.midY - halfHeight(at: r.minX)))
        for step in 0...steps {
            let x = r.minX + r.width * CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: x, y: r.midY - halfHeight(at: x)))
        }
        path.move(to: CGPoint(x: r.minX, y: r.midY + halfHeight(at: r.minX)))
        for step in 0...steps {
            let x = r.minX + r.width * CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: x, y: r.midY + halfHeight(at: x)))
        }
        path.move(to: CGPoint(x: waistX, y: r.midY - waistHalfHeight))
        path.addLine(to: CGPoint(x: waistX, y: r.midY + waistHalfHeight))
        return path
    }

    /// A rising exponential charging curve against axes.
    private static func transientCircuit(_ r: CGRect) -> Path {
        var path = Path()
        let baseY = r.maxY - r.height * 0.14
        let topY = r.minY + r.height * 0.1

        path.move(to: CGPoint(x: r.minX, y: topY))
        path.addLine(to: CGPoint(x: r.minX, y: baseY))
        path.addLine(to: CGPoint(x: r.maxX, y: baseY))

        let steps = 20
        path.move(to: CGPoint(x: r.minX, y: baseY))
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let x = r.minX + r.width * 0.94 * t
            let rise = 1 - exp(-3 * Double(t))
            let y = baseY - (baseY - topY) * 0.8 * CGFloat(rise)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }

    /// A rack rail with device ticks feeding off it.
    private static func rackCurrent(_ r: CGRect) -> Path {
        var path = Path()
        let railY = r.midY
        path.move(to: CGPoint(x: r.minX, y: railY))
        path.addLine(to: CGPoint(x: r.maxX, y: railY))

        let deviceXs: [CGFloat] = [0.2, 0.42, 0.64, 0.86].map { r.minX + r.width * $0 }
        let heights: [CGFloat] = [0.5, 0.3, 0.4, 0.22]
        for (x, h) in zip(deviceXs, heights) {
            path.move(to: CGPoint(x: x, y: railY))
            path.addLine(to: CGPoint(x: x, y: railY + r.height * h))
        }
        return path
    }

    /// The diode schematic symbol (triangle + cathode bar) with a small
    /// rising I-V curve alongside it.
    private static func diodeIV(_ r: CGRect) -> Path {
        var path = Path()
        let midY = r.midY
        let triLeft = r.minX + r.width * 0.14
        let triRight = r.midX - r.width * 0.1
        let barHeight = r.height * 0.3

        path.move(to: CGPoint(x: r.minX, y: midY))
        path.addLine(to: CGPoint(x: triLeft, y: midY))

        path.move(to: CGPoint(x: triLeft, y: midY - r.height * 0.18))
        path.addLine(to: CGPoint(x: triRight, y: midY))
        path.addLine(to: CGPoint(x: triLeft, y: midY + r.height * 0.18))
        path.closeSubpath()

        path.move(to: CGPoint(x: triRight, y: midY - barHeight / 2))
        path.addLine(to: CGPoint(x: triRight, y: midY + barHeight / 2))

        path.move(to: CGPoint(x: triRight, y: midY))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.02, y: midY))

        let curveBaseX = r.midX + r.width * 0.12
        let curveBaseY = r.maxY - r.height * 0.16
        let curveTopY = r.minY + r.height * 0.14
        path.move(to: CGPoint(x: curveBaseX, y: curveBaseY))
        let steps = 10
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let x = curveBaseX + (r.maxX - curveBaseX) * t
            let rise = t * t * t
            let y = curveBaseY - (curveBaseY - curveTopY) * rise
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }

    /// A shield outline with a checkmark — the loop either passes or it doesn't.
    private static func isLoopVerifier(_ r: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: r.midX, y: r.minY + r.height * 0.08)
        let leftTop = CGPoint(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.22)
        let rightTop = CGPoint(x: r.maxX - r.width * 0.1, y: r.minY + r.height * 0.22)
        let leftMid = CGPoint(x: r.minX + r.width * 0.1, y: r.midY + r.height * 0.06)
        let rightMid = CGPoint(x: r.maxX - r.width * 0.1, y: r.midY + r.height * 0.06)
        let bottom = CGPoint(x: r.midX, y: r.maxY - r.height * 0.06)

        path.move(to: top)
        path.addLine(to: rightTop)
        path.addLine(to: rightMid)
        path.addLine(to: bottom)
        path.addLine(to: leftMid)
        path.addLine(to: leftTop)
        path.closeSubpath()

        path.move(to: CGPoint(x: r.midX - r.width * 0.14, y: r.midY))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.02, y: r.midY + r.height * 0.12))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.16, y: r.midY - r.height * 0.14))
        return path
    }

    // Placeholder glyphs — icon art agent will refine.
    private static func tapChanger(_ r: CGRect) -> Path {
        var path = transformer(r)
        path.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.08))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.18, y: r.minY + r.height * 0.18))
        path.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.28))
        return path
    }

    private static func harmonicsTHD(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        for step in 0...24 {
            let t = CGFloat(step) / 24
            let y = r.midY - sin(t * .pi * 2) * r.height * 0.22 - sin(t * .pi * 6) * r.height * 0.08
            path.addLine(to: CGPoint(x: r.minX + r.width * t, y: y))
        }
        return path
    }

    private static func upsSizing(_ r: CGRect) -> Path {
        batteryBank(r)
    }

    private static func motorNameplate(_ r: CGRect) -> Path {
        var path = motorFLA(r)
        path.addRect(CGRect(x: r.minX + r.width * 0.62, y: r.minY + r.height * 0.18, width: r.width * 0.28, height: r.height * 0.36))
        return path
    }

    /// Nameplate card with viewfinder corners — sibling to the analyzer glyph.
    private static func motorNameplateOCR(_ r: CGRect) -> Path {
        var path = Path()
        let plate = CGRect(
            x: r.minX + r.width * 0.20,
            y: r.minY + r.height * 0.30,
            width: r.width * 0.60,
            height: r.height * 0.44
        )
        path.addRoundedRect(in: plate, cornerSize: CGSize(width: 3, height: 3))
        for index in 0..<3 {
            let y = plate.minY + plate.height * (0.30 + 0.20 * CGFloat(index))
            path.move(to: CGPoint(x: plate.minX + plate.width * 0.16, y: y))
            path.addLine(to: CGPoint(x: plate.maxX - plate.width * 0.16, y: y))
        }
        let arm = min(r.width, r.height) * 0.12
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.12), 1, 1),
            (CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.12), -1, 1),
            (CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.12), 1, -1),
            (CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.12), -1, -1),
        ]
        for (origin, dx, dy) in corners {
            path.move(to: origin)
            path.addLine(to: CGPoint(x: origin.x + arm * dx, y: origin.y))
            path.move(to: origin)
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + arm * dy))
        }
        return path
    }

    private static func heaterDesign(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.2))
        path.addCurve(
            to: CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY - r.height * 0.2),
            control1: CGPoint(x: r.minX + r.width * 0.3, y: r.minY + r.height * 0.1),
            control2: CGPoint(x: r.maxX - r.width * 0.3, y: r.minY + r.height * 0.1)
        )
        path.move(to: CGPoint(x: r.midX - r.width * 0.08, y: r.maxY - r.height * 0.12))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.02))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.08, y: r.maxY - r.height * 0.12))
        return path
    }

    private static func empEmc(_ r: CGRect) -> Path {
        isLoopVerifier(r)
    }

    private static func necCircuit(_ r: CGRect) -> Path {
        wireAmpacity(r)
    }

    private static func loadWorksheet(_ r: CGRect) -> Path {
        panelDirectory(r)
    }

    private static func cableSchedule(_ r: CGRect) -> Path {
        var path = Path()
        for i in 0..<4 {
            let y = r.minY + r.height * (0.2 + 0.18 * CGFloat(i))
            path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: y))
            path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: y))
        }
        return path
    }

    private static func solenoidDesign(_ r: CGRect) -> Path {
        var path = Path()
        let left = r.minX + r.width * 0.22
        let right = r.maxX - r.width * 0.22
        let top = r.minY + r.height * 0.18
        let bottom = r.maxY - r.height * 0.18
        path.addRoundedRect(
            in: CGRect(x: left, y: top, width: right - left, height: bottom - top),
            cornerSize: CGSize(width: 6, height: 6)
        )
        for i in 0..<5 {
            let y = top + (bottom - top) * (0.15 + 0.15 * CGFloat(i))
            path.move(to: CGPoint(x: left + 4, y: y))
            path.addLine(to: CGPoint(x: right - 4, y: y))
        }
        path.move(to: CGPoint(x: r.midX, y: bottom + 2))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.04))
        return path
    }

    private static func solarDesign(_ r: CGRect) -> Path {
        var path = Path()
        // Sun
        let sunR = min(r.width, r.height) * 0.14
        let sunC = CGPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.28)
        path.addEllipse(in: CGRect(x: sunC.x - sunR, y: sunC.y - sunR, width: sunR * 2, height: sunR * 2))
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4
            let inner = sunR * 1.25
            let outer = sunR * 1.85
            path.move(to: CGPoint(x: sunC.x + cos(a) * inner, y: sunC.y + sin(a) * inner))
            path.addLine(to: CGPoint(x: sunC.x + cos(a) * outer, y: sunC.y + sin(a) * outer))
        }
        // Tilted panel parallelogram
        let p0 = CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.22)
        let p1 = CGPoint(x: r.minX + r.width * 0.55, y: r.maxY - r.height * 0.18)
        let p2 = CGPoint(x: r.minX + r.width * 0.68, y: r.minY + r.height * 0.42)
        let p3 = CGPoint(x: r.minX + r.width * 0.25, y: r.minY + r.height * 0.38)
        path.move(to: p0); path.addLine(to: p1); path.addLine(to: p2); path.addLine(to: p3); path.closeSubpath()
        path.move(to: CGPoint(x: (p0.x+p3.x)/2, y: (p0.y+p3.y)/2))
        path.addLine(to: CGPoint(x: (p1.x+p2.x)/2, y: (p1.y+p2.y)/2))
        path.move(to: CGPoint(x: (p0.x+p1.x)/2, y: (p0.y+p1.y)/2))
        path.addLine(to: CGPoint(x: (p3.x+p2.x)/2, y: (p3.y+p2.y)/2))
        return path
    }

    /// Single op-amp triangle with +/− inputs and an output lead.
    private static func analogWorkbench(_ r: CGRect) -> Path {
        var path = Path()
        let left = r.minX + r.width * 0.18
        let right = r.maxX - r.width * 0.16
        let top = r.minY + r.height * 0.16
        let bottom = r.maxY - r.height * 0.16
        path.move(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: right, y: r.midY))
        path.addLine(to: CGPoint(x: left, y: bottom))
        path.closeSubpath()
        path.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.34))
        path.addLine(to: CGPoint(x: left, y: r.minY + r.height * 0.34))
        path.move(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.34))
        path.addLine(to: CGPoint(x: left, y: r.maxY - r.height * 0.34))
        path.move(to: CGPoint(x: right, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        let plusY = r.minY + r.height * 0.34
        path.move(to: CGPoint(x: left + r.width * 0.08, y: plusY))
        path.addLine(to: CGPoint(x: left + r.width * 0.18, y: plusY))
        path.move(to: CGPoint(x: left + r.width * 0.13, y: plusY - r.height * 0.05))
        path.addLine(to: CGPoint(x: left + r.width * 0.13, y: plusY + r.height * 0.05))
        path.move(to: CGPoint(x: left + r.width * 0.08, y: r.maxY - r.height * 0.34))
        path.addLine(to: CGPoint(x: left + r.width * 0.18, y: r.maxY - r.height * 0.34))
        return path
    }

    /// Resistor zigzag with a noisy scribble above it.
    private static func noiseSNR(_ r: CGRect) -> Path {
        var path = Path()
        let midY = r.midY + r.height * 0.12
        path.move(to: CGPoint(x: r.minX, y: midY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.16, y: midY))
        let zig = r.width * 0.48
        let step = zig / 6
        let start = r.minX + r.width * 0.16
        for index in 0..<6 {
            let x = start + step * (CGFloat(index) + 0.5)
            path.addLine(to: CGPoint(x: x, y: midY + (index.isMultiple(of: 2) ? -r.height * 0.12 : r.height * 0.12)))
        }
        path.addLine(to: CGPoint(x: start + zig, y: midY))
        path.addLine(to: CGPoint(x: r.maxX, y: midY))

        let noiseY = r.minY + r.height * 0.28
        path.move(to: CGPoint(x: r.minX + r.width * 0.08, y: noiseY))
        let samples = 8
        for i in 1...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let x = r.minX + r.width * 0.08 + r.width * 0.84 * t
            let amp: CGFloat = (i.isMultiple(of: 2) ? -1 : 1) * r.height * (0.06 + CGFloat(i % 3) * 0.03)
            path.addLine(to: CGPoint(x: x, y: noiseY + amp))
        }
        return path
    }

    /// Three-terminal regulator block with in / adj / out leads.
    private static func linearRegulator(_ r: CGRect) -> Path {
        var path = Path()
        let box = CGRect(
            x: r.minX + r.width * 0.22,
            y: r.minY + r.height * 0.22,
            width: r.width * 0.46,
            height: r.height * 0.56
        )
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3, height: 3))
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: box.minX, y: r.midY))
        path.move(to: CGPoint(x: box.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.move(to: CGPoint(x: box.midX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.midX, y: r.maxY))
        path.move(to: CGPoint(x: box.midX - r.width * 0.08, y: r.maxY - r.height * 0.08))
        path.addLine(to: CGPoint(x: box.midX + r.width * 0.08, y: r.maxY - r.height * 0.08))
        return path
    }

    /// Three small op-amp triangles in the classic InAmp arrangement.
    private static func instrumentationAmp(_ r: CGRect) -> Path {
        var path = Path()
        func triangle(at origin: CGPoint, width: CGFloat, height: CGFloat) {
            path.move(to: CGPoint(x: origin.x, y: origin.y))
            path.addLine(to: CGPoint(x: origin.x + width, y: origin.y + height / 2))
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + height))
            path.closeSubpath()
        }
        let w = r.width * 0.28
        let h = r.height * 0.28
        triangle(at: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.12), width: w, height: h)
        triangle(at: CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.12 - h), width: w, height: h)
        triangle(at: CGPoint(x: r.midX + r.width * 0.04, y: r.midY - h / 2), width: w, height: h)
        path.move(to: CGPoint(x: r.minX + r.width * 0.08 + w, y: r.minY + r.height * 0.12 + h / 2))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.04, y: r.midY - h * 0.18))
        path.move(to: CGPoint(x: r.minX + r.width * 0.08 + w, y: r.maxY - r.height * 0.12 - h / 2))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.04, y: r.midY + h * 0.18))
        return path
    }

    /// ADC stairstep from a rising analog slope.
    private static func adcDac(_ r: CGRect) -> Path {
        var path = Path()
        let baseY = r.maxY - r.height * 0.14
        path.move(to: CGPoint(x: r.minX, y: baseY))
        let steps = 4
        for i in 0..<steps {
            let x0 = r.minX + r.width * CGFloat(i) / CGFloat(steps)
            let x1 = r.minX + r.width * CGFloat(i + 1) / CGFloat(steps)
            let y = baseY - r.height * 0.16 * CGFloat(i + 1)
            path.addLine(to: CGPoint(x: x0 + r.width * 0.02, y: y))
            path.addLine(to: CGPoint(x: x1, y: y))
        }
        path.move(to: CGPoint(x: r.minX, y: baseY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.1))
        return path
    }

    // MARK: - Homework

    private static func voltageDivider(_ r: CGRect) -> Path {
        var path = Path()
        let top = r.minY + r.height * 0.18
        let bottom = r.maxY - r.height * 0.18
        let tapY = r.midY
        path.move(to: CGPoint(x: r.midX, y: top))
        path.addLine(to: CGPoint(x: r.midX, y: top + r.height * 0.18))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.16, y: top + r.height * 0.26))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.16, y: top + r.height * 0.26))
        path.addLine(to: CGPoint(x: r.midX, y: top + r.height * 0.34))
        path.addLine(to: CGPoint(x: r.midX, y: tapY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: tapY))
        path.addLine(to: CGPoint(x: r.midX, y: tapY))
        path.addLine(to: CGPoint(x: r.midX, y: bottom - r.height * 0.34))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.16, y: bottom - r.height * 0.26))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.16, y: bottom - r.height * 0.26))
        path.addLine(to: CGPoint(x: r.midX, y: bottom - r.height * 0.18))
        path.addLine(to: CGPoint(x: r.midX, y: bottom))
        return path
    }

    private static func seriesParallel(_ r: CGRect) -> Path {
        var path = Path()
        let leftMid = r.minX + r.width * 0.22
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: leftMid - r.width * 0.08, y: r.midY))
        path.addRect(CGRect(x: leftMid - r.width * 0.08, y: r.midY - r.height * 0.1, width: r.width * 0.16, height: r.height * 0.2))
        path.move(to: CGPoint(x: leftMid + r.width * 0.08, y: r.midY))
        path.addLine(to: CGPoint(x: leftMid + r.width * 0.14, y: r.midY))
        path.addRect(CGRect(x: leftMid + r.width * 0.14, y: r.midY - r.height * 0.1, width: r.width * 0.16, height: r.height * 0.2))
        path.move(to: CGPoint(x: leftMid + r.width * 0.3, y: r.midY))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.04, y: r.midY))

        let rightX = r.midX + r.width * 0.12
        path.move(to: CGPoint(x: rightX, y: r.midY - r.height * 0.22))
        path.addLine(to: CGPoint(x: rightX + r.width * 0.12, y: r.midY - r.height * 0.22))
        path.addRect(CGRect(x: rightX + r.width * 0.12, y: r.midY - r.height * 0.3, width: r.width * 0.14, height: r.height * 0.16))
        path.move(to: CGPoint(x: rightX + r.width * 0.26, y: r.midY - r.height * 0.22))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY - r.height * 0.22))

        path.move(to: CGPoint(x: rightX, y: r.midY + r.height * 0.22))
        path.addLine(to: CGPoint(x: rightX + r.width * 0.12, y: r.midY + r.height * 0.22))
        path.addRect(CGRect(x: rightX + r.width * 0.12, y: r.midY + r.height * 0.14, width: r.width * 0.14, height: r.height * 0.16))
        path.move(to: CGPoint(x: rightX + r.width * 0.26, y: r.midY + r.height * 0.22))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY + r.height * 0.22))
        return path
    }

    private static func resistorColor(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(x: r.minX + r.width * 0.12, y: r.midY - r.height * 0.16, width: r.width * 0.76, height: r.height * 0.32)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r.width * 0.06, height: r.width * 0.06))
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: body.minX, y: r.midY))
        path.move(to: CGPoint(x: body.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        let bands = [0.22, 0.38, 0.54, 0.7]
        for fraction in bands {
            let x = body.minX + body.width * fraction
            path.move(to: CGPoint(x: x, y: body.minY))
            path.addLine(to: CGPoint(x: x, y: body.maxY))
        }
        return path
    }

    private static func unitConverter(_ r: CGRect) -> Path {
        var path = Path()
        let midY = r.midY
        path.move(to: CGPoint(x: r.minX + r.width * 0.18, y: midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.18, y: midY))
        let head = r.width * 0.1
        path.move(to: CGPoint(x: r.minX + r.width * 0.18, y: midY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.28, y: midY - head * 0.45))
        path.move(to: CGPoint(x: r.minX + r.width * 0.18, y: midY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.28, y: midY + head * 0.45))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.18, y: midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.28, y: midY - head * 0.45))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.18, y: midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.28, y: midY + head * 0.45))
        path.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.22))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.34))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.34))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.22))
        return path
    }

    private static func frequencyWave(_ r: CGRect) -> Path {
        var path = Path()
        let coilStart = r.minX + r.width * 0.06
        let coilWidth = r.width * 0.22
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: coilStart, y: r.midY))
        let humps = 3
        let humpW = coilWidth / CGFloat(humps)
        for index in 0..<humps {
            let x = coilStart + humpW * CGFloat(index)
            path.addArc(
                center: CGPoint(x: x + humpW / 2, y: r.midY),
                radius: humpW / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
        let gap = r.width * 0.1
        path.move(to: CGPoint(x: coilStart + coilWidth, y: r.midY))
        path.addLine(to: CGPoint(x: r.midX - gap / 2, y: r.midY))
        let plateH = r.height * 0.34
        path.move(to: CGPoint(x: r.midX - gap / 2, y: r.midY - plateH / 2))
        path.addLine(to: CGPoint(x: r.midX - gap / 2, y: r.midY + plateH / 2))
        path.move(to: CGPoint(x: r.midX + gap / 2, y: r.midY - plateH / 2))
        path.addLine(to: CGPoint(x: r.midX + gap / 2, y: r.midY + plateH / 2))
        path.move(to: CGPoint(x: r.midX + gap / 2, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.move(to: CGPoint(x: r.minX + r.width * 0.52, y: r.minY + r.height * 0.2))
        for step in 0...20 {
            let t = CGFloat(step) / 20
            let y = r.minY + r.height * 0.34 - sin(t * .pi * 3) * r.height * 0.12
            path.addLine(to: CGPoint(x: r.minX + r.width * (0.52 + 0.4 * t), y: y))
        }
        return path
    }

    private static func ledRC(_ r: CGRect) -> Path {
        var path = Path()
        let ledX = r.minX + r.width * 0.2
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: ledX, y: r.midY))
        path.addLine(to: CGPoint(x: ledX + r.width * 0.14, y: r.midY - r.height * 0.18))
        path.addLine(to: CGPoint(x: ledX + r.width * 0.14, y: r.midY + r.height * 0.18))
        path.closeSubpath()
        path.move(to: CGPoint(x: ledX + r.width * 0.14, y: r.midY - r.height * 0.1))
        path.addLine(to: CGPoint(x: ledX + r.width * 0.24, y: r.midY - r.height * 0.18))
        path.move(to: CGPoint(x: ledX + r.width * 0.14, y: r.midY + r.height * 0.1))
        path.addLine(to: CGPoint(x: ledX + r.width * 0.24, y: r.midY + r.height * 0.18))
        let capX = r.midX + r.width * 0.08
        path.move(to: CGPoint(x: ledX + r.width * 0.24, y: r.midY))
        path.addLine(to: CGPoint(x: capX, y: r.midY))
        let plateH = r.height * 0.3
        path.move(to: CGPoint(x: capX, y: r.midY - plateH / 2))
        path.addLine(to: CGPoint(x: capX, y: r.midY + plateH / 2))
        path.move(to: CGPoint(x: capX + r.width * 0.08, y: r.midY - plateH / 2))
        path.addLine(to: CGPoint(x: capX + r.width * 0.08, y: r.midY + plateH / 2))
        path.move(to: CGPoint(x: capX + r.width * 0.08, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.move(to: CGPoint(x: r.minX + r.width * 0.58, y: r.maxY - r.height * 0.16))
        for step in 0...16 {
            let t = CGFloat(step) / 16
            let y = r.maxY - r.height * (0.16 + 0.42 * (1 - exp(-4 * t)))
            path.addLine(to: CGPoint(x: r.minX + r.width * (0.58 + 0.34 * t), y: y))
        }
        return path
    }

    // MARK: - Sensors

    private static func wifiStatus(_ r: CGRect) -> Path {
        var path = Path()
        let base = CGPoint(x: r.midX, y: r.maxY - r.height * 0.1)
        path.move(to: base)
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.18))
        for index in 1...3 {
            let radius = r.width * 0.12 * CGFloat(index)
            path.addArc(
                center: base,
                radius: radius,
                startAngle: .degrees(205),
                endAngle: .degrees(335),
                clockwise: false
            )
        }
        return path
    }

    private static func bluetoothScan(_ r: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: r.midX, y: r.minY + r.height * 0.1)
        let midLeft = CGPoint(x: r.midX - r.width * 0.18, y: r.midY)
        let midRight = CGPoint(x: r.midX + r.width * 0.18, y: r.midY)
        let bottom = CGPoint(x: r.midX, y: r.maxY - r.height * 0.1)
        path.move(to: top)
        path.addLine(to: midLeft)
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.04, y: r.midY - r.height * 0.08))
        path.addLine(to: bottom)
        path.move(to: bottom)
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.04, y: r.midY + r.height * 0.08))
        path.addLine(to: midRight)
        path.addLine(to: top)
        path.move(to: CGPoint(x: r.maxX - r.width * 0.14, y: r.midY - r.height * 0.16))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.midY - r.height * 0.16))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.midY - r.height * 0.22))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.midY - r.height * 0.1))
        return path
    }

    private static func noiseMeter(_ r: CGRect) -> Path {
        var path = Path()
        let mic = CGRect(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.22, width: r.width * 0.22, height: r.height * 0.42)
        path.addRoundedRect(in: mic, cornerSize: CGSize(width: mic.width * 0.4, height: mic.width * 0.4))
        path.move(to: CGPoint(x: mic.midX, y: mic.maxY))
        path.addLine(to: CGPoint(x: mic.midX, y: r.maxY - r.height * 0.14))
        path.addLine(to: CGPoint(x: mic.midX - r.width * 0.08, y: r.maxY - r.height * 0.08))
        path.move(to: CGPoint(x: mic.midX, y: r.maxY - r.height * 0.14))
        path.addLine(to: CGPoint(x: mic.midX + r.width * 0.08, y: r.maxY - r.height * 0.08))
        let bars: [CGFloat] = [0.18, 0.32, 0.48, 0.28, 0.42]
        for (index, height) in bars.enumerated() {
            let x = r.minX + r.width * (0.42 + 0.1 * CGFloat(index))
            path.move(to: CGPoint(x: x, y: r.maxY - r.height * 0.12))
            path.addLine(to: CGPoint(x: x, y: r.maxY - r.height * (0.12 + height)))
        }
        return path
    }

    private static func bubbleLevel(_ r: CGRect) -> Path {
        var path = Path()
        let tube = CGRect(x: r.minX + r.width * 0.08, y: r.midY - r.height * 0.12, width: r.width * 0.84, height: r.height * 0.24)
        path.addRoundedRect(in: tube, cornerSize: CGSize(width: tube.height / 2, height: tube.height / 2))
        let bubbleR = r.height * 0.07
        path.addEllipse(in: CGRect(x: r.midX - bubbleR, y: r.midY - bubbleR, width: bubbleR * 2, height: bubbleR * 2))
        path.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.14))
        path.addLine(to: CGPoint(x: r.midX, y: tube.minY - r.height * 0.04))
        path.move(to: CGPoint(x: r.midX - r.width * 0.06, y: r.minY + r.height * 0.1))
        path.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.04))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.06, y: r.minY + r.height * 0.1))
        return path
    }

    private static func magnetometer(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.38
        path.addEllipse(in: CGRect(x: r.midX - radius, y: r.midY - radius, width: radius * 2, height: radius * 2))
        path.move(to: CGPoint(x: r.midX, y: r.midY - radius * 0.72))
        path.addLine(to: CGPoint(x: r.midX, y: r.midY + radius * 0.72))
        path.move(to: CGPoint(x: r.midX, y: r.midY - radius * 0.72))
        path.addLine(to: CGPoint(x: r.midX - radius * 0.18, y: r.midY - radius * 0.36))
        path.move(to: CGPoint(x: r.midX, y: r.midY - radius * 0.72))
        path.addLine(to: CGPoint(x: r.midX + radius * 0.18, y: r.midY - radius * 0.36))
        for angle in stride(from: CGFloat(45), to: CGFloat(360), by: CGFloat(90)) {
            let rad = angle * .pi / 180
            path.move(to: CGPoint(x: r.midX + cos(rad) * radius * 0.55, y: r.midY + sin(rad) * radius * 0.55))
            path.addLine(to: CGPoint(x: r.midX + cos(rad) * radius * 0.78, y: r.midY + sin(rad) * radius * 0.78))
        }
        return path
    }

    private static func barometer(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.42
        path.addArc(
            center: CGPoint(x: r.midX, y: r.maxY - r.height * 0.08),
            radius: radius,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        path.move(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.08))
        path.addLine(to: CGPoint(x: r.midX + radius * 0.55, y: r.maxY - r.height * 0.42))
        for index in 0..<5 {
            let angle = CGFloat(210 + index * 30) * .pi / 180
            let inner = radius * 0.82
            let outer = radius * 0.92
            let cx = r.midX
            let cy = r.maxY - r.height * 0.08
            path.move(to: CGPoint(x: cx + cos(angle) * inner, y: cy + sin(angle) * inner))
            path.addLine(to: CGPoint(x: cx + cos(angle) * outer, y: cy + sin(angle) * outer))
        }
        return path
    }

    private static func motionSnapshot(_ r: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: r.minX + r.width * 0.22, y: r.maxY - r.height * 0.22)
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x + r.width * 0.42, y: origin.y))
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x, y: origin.y - r.height * 0.42))
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x - r.width * 0.12, y: origin.y - r.width * 0.12))
        path.move(to: CGPoint(x: r.midX + r.width * 0.12, y: r.minY + r.height * 0.2))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.22, y: r.minY + r.height * 0.34))
        path.move(to: CGPoint(x: r.midX + r.width * 0.12, y: r.minY + r.height * 0.34))
        path.addLine(to: CGPoint(x: r.midX + r.width * 0.22, y: r.minY + r.height * 0.2))
        path.addEllipse(in: CGRect(x: r.midX + r.width * 0.08, y: r.minY + r.height * 0.24, width: r.width * 0.16, height: r.width * 0.16))
        return path
    }

    private static func fieldPosition(_ r: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: r.midX, y: r.maxY - r.height * 0.08)
        let left = CGPoint(x: r.midX - r.width * 0.2, y: r.minY + r.height * 0.34)
        let right = CGPoint(x: r.midX + r.width * 0.2, y: r.minY + r.height * 0.34)
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: r.midX - r.width * 0.1, y: r.minY + r.height * 0.18, width: r.width * 0.2, height: r.width * 0.2))
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.midY))
        path.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.12))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.28))
        return path
    }

    private static func deviceHealth(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(x: r.minX + r.width * 0.14, y: r.midY - r.height * 0.2, width: r.width * 0.52, height: r.height * 0.4)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r.width * 0.05, height: r.width * 0.05))
        path.addRect(CGRect(x: body.maxX, y: body.midY - r.height * 0.08, width: r.width * 0.06, height: r.height * 0.16))
        path.move(to: CGPoint(x: body.minX + r.width * 0.1, y: body.minY + r.height * 0.1))
        path.addLine(to: CGPoint(x: body.maxX - r.width * 0.14, y: body.minY + r.height * 0.1))
        path.move(to: CGPoint(x: r.maxX - r.width * 0.16, y: r.minY + r.height * 0.22))
        path.addArc(
            center: CGPoint(x: r.maxX - r.width * 0.16, y: r.minY + r.height * 0.34),
            radius: r.width * 0.1,
            startAngle: .degrees(220),
            endAngle: .degrees(320),
            clockwise: false
        )
        path.move(to: CGPoint(x: r.maxX - r.width * 0.16, y: r.minY + r.height * 0.24))
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.16, y: r.minY + r.height * 0.44))
        return path
    }
}
