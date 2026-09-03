import SwiftUI

/// Original schematic-style artwork for the tool grid, drawn as vector paths so
/// it stays crisp at any size, follows the theme, and ships no image assets.
///
/// Each `ToolID` maps 1:1 to a distinct `GlyphKind` drawing — no unrelated tools
/// share the same schematic.
struct ToolGlyph: View {
    let kind: GlyphKind
    var size: CGFloat = 44
    var selected: Bool = false

    private var strokeColor: Color { selected ? Theme.accent : Theme.muted }

    private var lineWidth: CGFloat {
        let base = max(Theme.Stroke.icon, size * 0.055)
        return selected ? base * 1.15 : base
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.14, dy: canvasSize.height * 0.14)
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            context.stroke(kind.path(in: rect), with: .color(strokeColor), style: style)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
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
