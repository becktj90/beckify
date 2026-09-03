import SwiftUI

/// Original schematic-style artwork for the tool grid, drawn as vector paths so
/// it stays crisp at any size, follows the theme, and ships no image assets.
///
/// These are drawn from the standard circuit symbols an EE would sketch by
/// hand — a resistor zigzag, an op-amp triangle — not traced from any existing
/// app's icon set.
struct ToolGlyph: View {
    let kind: GlyphKind
    var size: CGFloat = 44

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: canvasSize.width * 0.14, dy: canvasSize.height * 0.14)
            let stroke = GraphicsContext.Shading.color(Theme.accent)
            let line = max(1.6, canvasSize.width * 0.055)
            let style = StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
            context.stroke(kind.path(in: rect), with: stroke, style: style)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension GlyphKind {
    /// Schematic symbol that reads as the job, not a literal picture of it.
    static func forTool(_ id: ToolID) -> GlyphKind {
        switch id {
        case .ohmsLaw, .voltageDivider, .seriesParallel: return .resistor
        case .resistorColor: return .ruler
        case .power, .powerWizard: return .sine
        case .transformer: return .transformer
        case .reactance, .frequencyWave: return .inductor
        case .powerFactor: return .opAmp
        case .ledRC, .unitConverter: return .capacitor
        case .timer555, .plcTimer: return .timer
        case .motorFLA: return .motor
        case .conduitFill: return .conduit
        case .receptacleSelector: return .receptacle
        case .wireAmpacity, .circularMils: return .ruler
        case .voltageDrop: return .battery
        case .shortCircuit: return .breaker
        case .loadFactors: return .meter
        case .signalScaling: return .signal
        case .modbusAddress: return .network
        case .wifiStatus, .bluetoothScan: return .network
        case .noiseMeter, .motionSnapshot: return .waveform
        case .bubbleLevel, .magnetometer, .barometer, .fieldPosition: return .meter
        case .deviceHealth: return .battery
        }
    }
}

enum GlyphKind {
    case resistor
    case capacitor
    case inductor
    case opAmp
    case waveform
    case sine
    case transformer
    case motor
    case conduit
    case receptacle
    case breaker
    case meter
    case timer
    case battery
    case ground
    case panel
    case camera
    case signal
    case network
    case ruler

    // swiftlint:disable:next cyclomatic_complexity
    func path(in rect: CGRect) -> Path {
        switch self {
        case .resistor: return Self.resistor(rect)
        case .capacitor: return Self.capacitor(rect)
        case .inductor: return Self.inductor(rect)
        case .opAmp: return Self.opAmp(rect)
        case .waveform: return Self.waveform(rect)
        case .sine: return Self.sine(rect)
        case .transformer: return Self.transformer(rect)
        case .motor: return Self.motor(rect)
        case .conduit: return Self.conduit(rect)
        case .receptacle: return Self.receptacle(rect)
        case .breaker: return Self.breaker(rect)
        case .meter: return Self.meter(rect)
        case .timer: return Self.timer(rect)
        case .battery: return Self.battery(rect)
        case .ground: return Self.ground(rect)
        case .panel: return Self.panel(rect)
        case .camera: return Self.camera(rect)
        case .signal: return Self.signal(rect)
        case .network: return Self.network(rect)
        case .ruler: return Self.ruler(rect)
        }
    }

    // MARK: - Passives

    private static func resistor(_ r: CGRect) -> Path {
        var path = Path()
        let midY = r.midY
        let zigWidth = r.width * 0.6
        let start = r.minX + (r.width - zigWidth) / 2
        let step = zigWidth / 6
        let peak = r.height * 0.22

        path.move(to: CGPoint(x: r.minX, y: midY))
        path.addLine(to: CGPoint(x: start, y: midY))
        for index in 0..<6 {
            let x = start + step * (CGFloat(index) + 0.5)
            path.addLine(to: CGPoint(x: x, y: midY + (index.isMultiple(of: 2) ? -peak : peak)))
        }
        path.addLine(to: CGPoint(x: start + zigWidth, y: midY))
        path.addLine(to: CGPoint(x: r.maxX, y: midY))
        return path
    }

    private static func capacitor(_ r: CGRect) -> Path {
        var path = Path()
        let gap = r.width * 0.16
        let plateHeight = r.height * 0.62

        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: r.midX - gap / 2, y: r.midY))
        path.move(to: CGPoint(x: r.midX - gap / 2, y: r.midY - plateHeight / 2))
        path.addLine(to: CGPoint(x: r.midX - gap / 2, y: r.midY + plateHeight / 2))
        path.move(to: CGPoint(x: r.midX + gap / 2, y: r.midY - plateHeight / 2))
        path.addLine(to: CGPoint(x: r.midX + gap / 2, y: r.midY + plateHeight / 2))
        path.move(to: CGPoint(x: r.midX + gap / 2, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return path
    }

    private static func inductor(_ r: CGRect) -> Path {
        var path = Path()
        let coilWidth = r.width * 0.62
        let start = r.minX + (r.width - coilWidth) / 2
        let humps = 4
        let humpWidth = coilWidth / CGFloat(humps)

        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: start, y: r.midY))
        for index in 0..<humps {
            let x = start + humpWidth * CGFloat(index)
            path.addArc(
                center: CGPoint(x: x + humpWidth / 2, y: r.midY),
                radius: humpWidth / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
        path.move(to: CGPoint(x: start + coilWidth, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return path
    }

    // MARK: - Active devices

    private static func opAmp(_ r: CGRect) -> Path {
        var path = Path()
        let bodyLeft = r.minX + r.width * 0.22
        let bodyRight = r.maxX - r.width * 0.12

        path.move(to: CGPoint(x: bodyLeft, y: r.minY))
        path.addLine(to: CGPoint(x: bodyRight, y: r.midY))
        path.addLine(to: CGPoint(x: bodyLeft, y: r.maxY))
        path.closeSubpath()

        let inputHigh = r.minY + r.height * 0.28
        let inputLow = r.maxY - r.height * 0.28
        path.move(to: CGPoint(x: r.minX, y: inputHigh))
        path.addLine(to: CGPoint(x: bodyLeft, y: inputHigh))
        path.move(to: CGPoint(x: r.minX, y: inputLow))
        path.addLine(to: CGPoint(x: bodyLeft, y: inputLow))

        // "+" on the non-inverting input, "−" on the inverting one.
        let mark = r.width * 0.09
        let markX = bodyLeft + r.width * 0.12
        path.move(to: CGPoint(x: markX - mark / 2, y: inputHigh))
        path.addLine(to: CGPoint(x: markX + mark / 2, y: inputHigh))
        path.move(to: CGPoint(x: markX, y: inputHigh - mark / 2))
        path.addLine(to: CGPoint(x: markX, y: inputHigh + mark / 2))
        path.move(to: CGPoint(x: markX - mark / 2, y: inputLow))
        path.addLine(to: CGPoint(x: markX + mark / 2, y: inputLow))
        return path
    }

    private static func motor(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.38
        path.addEllipse(in: CGRect(
            x: r.midX - radius, y: r.midY - radius,
            width: radius * 2, height: radius * 2
        ))
        // An "M" inside the rotor circle.
        let inset = radius * 0.55
        path.move(to: CGPoint(x: r.midX - inset, y: r.midY + inset * 0.8))
        path.addLine(to: CGPoint(x: r.midX - inset, y: r.midY - inset * 0.8))
        path.addLine(to: CGPoint(x: r.midX, y: r.midY + inset * 0.2))
        path.addLine(to: CGPoint(x: r.midX + inset, y: r.midY - inset * 0.8))
        path.addLine(to: CGPoint(x: r.midX + inset, y: r.midY + inset * 0.8))
        return path
    }

    private static func transformer(_ r: CGRect) -> Path {
        var path = Path()
        let coreX = r.midX
        path.move(to: CGPoint(x: coreX - r.width * 0.04, y: r.minY))
        path.addLine(to: CGPoint(x: coreX - r.width * 0.04, y: r.maxY))
        path.move(to: CGPoint(x: coreX + r.width * 0.04, y: r.minY))
        path.addLine(to: CGPoint(x: coreX + r.width * 0.04, y: r.maxY))

        // Three winding humps each side of the core.
        let humpRadius = r.height * 0.14
        for index in 0..<3 {
            let y = r.minY + r.height * (0.26 + 0.24 * CGFloat(index))
            path.addArc(
                center: CGPoint(x: coreX - r.width * 0.04, y: y),
                radius: humpRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: coreX + r.width * 0.04, y: y),
                radius: humpRadius,
                startAngle: .degrees(270),
                endAngle: .degrees(90),
                clockwise: false
            )
        }
        return path
    }

    // MARK: - Waves

    private static func waveform(_ r: CGRect) -> Path {
        // A charging exponential — the RC/transient family.
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        for step in 0...40 {
            let t = CGFloat(step) / 40
            let y = r.maxY - r.height * (1 - exp(-3 * t))
            path.addLine(to: CGPoint(x: r.minX + r.width * t, y: y))
        }
        return path
    }

    private static func sine(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        for step in 0...48 {
            let t = CGFloat(step) / 48
            let y = r.midY - sin(t * .pi * 2) * r.height * 0.38
            path.addLine(to: CGPoint(x: r.minX + r.width * t, y: y))
        }
        return path
    }

    private static func signal(_ r: CGRect) -> Path {
        // A 4-20 mA ramp against its live zero.
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY))
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.move(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.2))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.06))
        return path
    }

    // MARK: - Field gear

    private static func conduit(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.42
        path.addEllipse(in: CGRect(
            x: r.midX - radius, y: r.midY - radius,
            width: radius * 2, height: radius * 2
        ))
        // Three conductors inside the raceway.
        let inner = radius * 0.3
        for angle in stride(from: CGFloat(90), to: CGFloat(450), by: CGFloat(120)) {
            let radians = angle * .pi / 180
            let center = CGPoint(
                x: r.midX + cos(radians) * radius * 0.45,
                y: r.midY + sin(radians) * radius * 0.45
            )
            path.addEllipse(in: CGRect(
                x: center.x - inner, y: center.y - inner,
                width: inner * 2, height: inner * 2
            ))
        }
        return path
    }

    private static func receptacle(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.42
        path.addEllipse(in: CGRect(
            x: r.midX - radius, y: r.midY - radius,
            width: radius * 2, height: radius * 2
        ))
        let slot = radius * 0.42
        path.move(to: CGPoint(x: r.midX - radius * 0.42, y: r.midY - slot))
        path.addLine(to: CGPoint(x: r.midX - radius * 0.42, y: r.midY + slot * 0.2))
        path.move(to: CGPoint(x: r.midX + radius * 0.42, y: r.midY - slot))
        path.addLine(to: CGPoint(x: r.midX + radius * 0.42, y: r.midY + slot * 0.2))
        path.addEllipse(in: CGRect(
            x: r.midX - slot * 0.35, y: r.midY + slot * 0.45,
            width: slot * 0.7, height: slot * 0.7
        ))
        return path
    }

    private static func breaker(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.midX - r.width * 0.16, y: r.maxY))
        // Hinged contact, thrown open.
        path.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.18))
        path.move(to: CGPoint(x: r.midX + r.width * 0.2, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addEllipse(in: CGRect(
            x: r.midX - r.width * 0.22, y: r.maxY - r.height * 0.06,
            width: r.width * 0.12, height: r.width * 0.12
        ))
        return path
    }

    private static func panel(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: r, cornerSize: CGSize(width: r.width * 0.1, height: r.width * 0.1))
        // Breaker rows, two-up like a real directory.
        for index in 0..<3 {
            let y = r.minY + r.height * (0.3 + 0.2 * CGFloat(index))
            path.move(to: CGPoint(x: r.minX + r.width * 0.16, y: y))
            path.addLine(to: CGPoint(x: r.midX - r.width * 0.06, y: y))
            path.move(to: CGPoint(x: r.midX + r.width * 0.06, y: y))
            path.addLine(to: CGPoint(x: r.maxX - r.width * 0.16, y: y))
        }
        return path
    }

    private static func camera(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX, y: r.minY + r.height * 0.18,
            width: r.width, height: r.height * 0.66
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r.width * 0.12, height: r.width * 0.12))
        let lens = min(body.width, body.height) * 0.3
        path.addEllipse(in: CGRect(
            x: body.midX - lens, y: body.midY - lens,
            width: lens * 2, height: lens * 2
        ))
        path.move(to: CGPoint(x: r.minX + r.width * 0.28, y: body.minY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.06))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.62, y: r.minY + r.height * 0.06))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: body.minY))
        return path
    }

    private static func meter(_ r: CGRect) -> Path {
        var path = Path()
        let radius = min(r.width, r.height) * 0.42
        path.addArc(
            center: CGPoint(x: r.midX, y: r.midY + radius * 0.3),
            radius: radius,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        path.move(to: CGPoint(x: r.midX, y: r.midY + radius * 0.3))
        path.addLine(to: CGPoint(x: r.midX + radius * 0.62, y: r.midY - radius * 0.42))
        return path
    }

    private static func timer(_ r: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: r.insetBy(dx: r.width * 0.12, dy: 0),
            cornerSize: CGSize(width: r.width * 0.08, height: r.width * 0.08)
        )
        // DIP legs, four per side.
        for index in 0..<4 {
            let y = r.minY + r.height * (0.2 + 0.2 * CGFloat(index))
            path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: y))
            path.addLine(to: CGPoint(x: r.minX, y: y))
            path.move(to: CGPoint(x: r.maxX - r.width * 0.12, y: y))
            path.addLine(to: CGPoint(x: r.maxX, y: y))
        }
        return path
    }

    private static func battery(_ r: CGRect) -> Path {
        var path = Path()
        for index in 0..<2 {
            let x = r.minX + r.width * (0.34 + 0.24 * CGFloat(index))
            let tall = r.height * (index == 0 ? 0.6 : 0.3)
            path.move(to: CGPoint(x: x, y: r.midY - tall / 2))
            path.addLine(to: CGPoint(x: x, y: r.midY + tall / 2))
        }
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.34, y: r.midY))
        path.move(to: CGPoint(x: r.minX + r.width * 0.58, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return path
    }

    private static func ground(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addLine(to: CGPoint(x: r.midX, y: r.midY - r.height * 0.08))
        for index in 0..<3 {
            let y = r.midY - r.height * 0.08 + r.height * 0.16 * CGFloat(index)
            let halfWidth = r.width * (0.38 - 0.11 * CGFloat(index))
            path.move(to: CGPoint(x: r.midX - halfWidth, y: y))
            path.addLine(to: CGPoint(x: r.midX + halfWidth, y: y))
        }
        return path
    }

    private static func network(_ r: CGRect) -> Path {
        var path = Path()
        let node = min(r.width, r.height) * 0.11
        let points = [
            CGPoint(x: r.midX, y: r.minY + node),
            CGPoint(x: r.minX + node, y: r.maxY - node),
            CGPoint(x: r.maxX - node, y: r.maxY - node),
        ]
        for point in points {
            path.addEllipse(in: CGRect(
                x: point.x - node, y: point.y - node,
                width: node * 2, height: node * 2
            ))
        }
        path.move(to: CGPoint(x: points[0].x, y: points[0].y + node))
        path.addLine(to: CGPoint(x: points[1].x, y: points[1].y - node))
        path.move(to: CGPoint(x: points[0].x, y: points[0].y + node))
        path.addLine(to: CGPoint(x: points[2].x, y: points[2].y - node))
        path.move(to: CGPoint(x: points[1].x + node, y: points[1].y))
        path.addLine(to: CGPoint(x: points[2].x - node, y: points[2].y))
        return path
    }

    private static func ruler(_ r: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: r.minX, y: r.midY - r.height * 0.24,
            width: r.width, height: r.height * 0.48
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: r.width * 0.06, height: r.width * 0.06))
        for index in 1..<5 {
            let x = body.minX + body.width * 0.2 * CGFloat(index)
            let tick = index.isMultiple(of: 2) ? body.height * 0.55 : body.height * 0.32
            path.move(to: CGPoint(x: x, y: body.minY))
            path.addLine(to: CGPoint(x: x, y: body.minY + tick))
        }
        return path
    }
}
