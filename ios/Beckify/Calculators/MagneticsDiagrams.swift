import SwiftUI
import BeckifyMath

// MARK: - Shared drawing

enum FieldSketch {
    static func arrow(
        _ context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        color: Color,
        width: CGFloat = 2
    ) {
        var shaft = Path()
        shaft.move(to: from)
        shaft.addLine(to: to)
        context.stroke(shaft, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        let angle = atan2(to.y - from.y, to.x - from.x)
        let head: CGFloat = 9
        var tip = Path()
        tip.move(to: to)
        tip.addLine(to: CGPoint(
            x: to.x - head * cos(angle - 0.45),
            y: to.y - head * sin(angle - 0.45)
        ))
        tip.move(to: to)
        tip.addLine(to: CGPoint(
            x: to.x - head * cos(angle + 0.45),
            y: to.y - head * sin(angle + 0.45)
        ))
        context.stroke(tip, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    static func label(
        _ context: inout GraphicsContext,
        _ text: String,
        at point: CGPoint,
        color: Color = Theme.foreground,
        weight: Font.Weight = .semibold
    ) {
        context.draw(
            Text(text)
                .font(.caption2.monospacedDigit().weight(weight))
                .foregroundStyle(color),
            at: point
        )
    }

    static func axes(
        _ context: inout GraphicsContext,
        in size: CGSize,
        xTitle: String,
        yTitle: String,
        inset: CGFloat = 28
    ) -> CGRect {
        let plot = CGRect(
            x: inset,
            y: 16,
            width: max(size.width - inset - 12, 40),
            height: max(size.height - inset - 18, 40)
        )
        var frame = Path()
        frame.move(to: CGPoint(x: plot.minX, y: plot.minY))
        frame.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        frame.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(frame, with: .color(Theme.muted.opacity(0.85)), style: StrokeStyle(lineWidth: 1.2))
        label(&context, xTitle, at: CGPoint(x: plot.midX, y: size.height - 10), color: Theme.muted, weight: .medium)
        label(&context, yTitle, at: CGPoint(x: 8, y: plot.midY), color: Theme.muted, weight: .medium)
        label(&context, "0", at: CGPoint(x: plot.minX - 8, y: plot.maxY + 8), color: Theme.muted, weight: .regular)
        return plot
    }
}

// MARK: - Core

struct MagneticCoreDiagram: View {
    var flux: Double
    var mmf: Double
    var gapFraction: Double
    var hasGap: Bool
    var steelB: Double
    var gapB: Double?

    private var summary: String {
        let gap = hasGap ? "Air gap takes \(Format.percent(gapFraction * 100)) of the ampere-turns." : "No air gap."
        return "Series core sketch. Flux \(Format.number(flux * 1e3, digits: 3)) mWb, MMF \(Format.number(mmf, digits: 1)) At. \(gap) Not to scale. MMF plays volts, flux plays amps, reluctance plays ohms."
    }

    var body: some View {
        DiagramCard(title: "Core path", accessibilitySummary: summary, exportName: "magnetic-core") {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    draw(&context, size: size)
                }
                .frame(height: 230)
                Text("MMF plays volts. Flux plays amps. Reluctance plays ohms.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(hasGap
                     ? "Gap share \(Format.percent(gapFraction * 100)). Steel B \(Format.number(steelB, digits: 3)) T\(gapB.map { ", gap B \(Format.number($0, digits: 3)) T" } ?? "")."
                     : "Closed steel. B \(Format.number(steelB, digits: 3)) T. H along this path is NI / ℓ and does not depend on µr.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Sketch, not to scale. Leakage around the coil is omitted.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let left = size.width * 0.18
        let right = size.width * 0.78
        let top = size.height * 0.16
        let bottom = size.height * 0.72
        let thick = max(10, size.width * 0.045)
        let steel = Theme.foreground.opacity(0.88)
        bar(&context, CGRect(x: left - thick / 2, y: top, width: thick, height: bottom - top), color: steel)
        bar(&context, CGRect(x: left, y: top - thick / 2, width: right - left, height: thick), color: steel)
        bar(&context, CGRect(x: left, y: bottom - thick / 2, width: right - left, height: thick), color: steel)
        if hasGap {
            let gapTop = (top + bottom) / 2 - 14
            bar(&context, CGRect(x: right - thick / 2, y: top, width: thick, height: gapTop - top), color: steel)
            bar(&context, CGRect(x: right - thick / 2, y: gapTop + 28, width: thick, height: bottom - (gapTop + 28)), color: steel)
            FieldSketch.label(&context, "gap", at: CGPoint(x: right + 22, y: (top + bottom) / 2), color: Theme.warn)
        } else {
            bar(&context, CGRect(x: right - thick / 2, y: top, width: thick, height: bottom - top), color: steel)
        }
        let coilY = (top + bottom) / 2
        for index in -2...2 {
            var tick = Path()
            let y = coilY + CGFloat(index) * 9
            tick.move(to: CGPoint(x: left - thick, y: y))
            tick.addLine(to: CGPoint(x: left + thick, y: y))
            context.stroke(tick, with: .color(Theme.copper), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        FieldSketch.label(&context, "NI", at: CGPoint(x: left - 28, y: coilY), color: Theme.copper)
        let fluxY = top + thick + 16
        let direction: CGFloat = flux >= 0 ? 1 : -1
        let start = CGPoint(x: left + 28, y: fluxY)
        let end = CGPoint(x: right - 28, y: fluxY)
        if direction > 0 {
            FieldSketch.arrow(&context, from: start, to: end, color: Theme.accent, width: 2.4)
        } else {
            FieldSketch.arrow(&context, from: end, to: start, color: Theme.accent, width: 2.4)
        }
        FieldSketch.label(&context, "Φ", at: CGPoint(x: (left + right) / 2, y: fluxY - 14), color: Theme.accent)
        FieldSketch.label(
            &context,
            "mean path",
            at: CGPoint(x: (left + right) / 2, y: bottom + 28),
            color: Theme.muted,
            weight: .regular
        )
    }

    private func bar(_ context: inout GraphicsContext, _ rect: CGRect, color: Color) {
        let path = Path(roundedRect: rect, cornerRadius: 3)
        context.fill(path, with: .color(color))
    }
}

struct ThreeLegDiagram: View {
    var coilFlux: Double
    var leftFlux: Double
    var rightFlux: Double
    var gapFraction: Double

    private var summary: String {
        "Three-leg core. Center flux \(Format.number(coilFlux * 1e3, digits: 3)) mWb splits to left \(Format.number(leftFlux * 1e3, digits: 3)) and right \(Format.number(rightFlux * 1e3, digits: 3)) mWb. Gap share \(Format.percent(gapFraction * 100)). Flux into the center leaves through the sides."
    }

    var body: some View {
        DiagramCard(title: "Three-leg path", accessibilitySummary: summary, exportName: "three-leg-core") {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    draw(&context, size: size)
                }
                .frame(height: 240)
                Text("Flux in equals flux out at the center node. Each loop’s ampere-turns still sum to NI.")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Sketch, not to scale. A new reluctance starts where area, material, or the gap changes.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let yTop = size.height * 0.18
        let yBot = size.height * 0.78
        let xs = [size.width * 0.18, size.width * 0.5, size.width * 0.82]
        let thick: CGFloat = 12
        let steel = Theme.foreground.opacity(0.88)
        var yoke = Path()
        let yokeRadii = RectangleCornerRadii(topLeading: 3, bottomLeading: 3, bottomTrailing: 3, topTrailing: 3)
        yoke.addRoundedRect(in: CGRect(x: xs[0] - thick / 2, y: yTop - thick / 2, width: xs[2] - xs[0] + thick, height: thick), cornerRadii: yokeRadii)
        yoke.addRoundedRect(in: CGRect(x: xs[0] - thick / 2, y: yBot - thick / 2, width: xs[2] - xs[0] + thick, height: thick), cornerRadii: yokeRadii)
        context.fill(yoke, with: .color(steel))
        for (index, x) in xs.enumerated() {
            let gap = index != 1
            if gap {
                let mid = (yTop + yBot) / 2
                fillLeg(&context, x: x, y0: yTop, y1: mid - 16, thick: thick, color: steel)
                fillLeg(&context, x: x, y0: mid + 16, y1: yBot, thick: thick, color: steel)
                FieldSketch.label(&context, "gap", at: CGPoint(x: x, y: mid), color: Theme.warn, weight: .regular)
            } else {
                fillLeg(&context, x: x, y0: yTop, y1: yBot, thick: thick, color: steel)
                for step in -2...2 {
                    var tick = Path()
                    let y = (yTop + yBot) / 2 + CGFloat(step) * 8
                    tick.move(to: CGPoint(x: x - 16, y: y))
                    tick.addLine(to: CGPoint(x: x + 16, y: y))
                    context.stroke(tick, with: .color(Theme.copper), lineWidth: 2)
                }
            }
        }
        let up = coilFlux >= 0
        FieldSketch.arrow(
            &context,
            from: CGPoint(x: xs[1], y: up ? yBot - 36 : yTop + 36),
            to: CGPoint(x: xs[1], y: up ? yTop + 36 : yBot - 36),
            color: Theme.accent
        )
        FieldSketch.label(&context, "Φc", at: CGPoint(x: xs[1] + 26, y: (yTop + yBot) / 2 - 28), color: Theme.accent)
        FieldSketch.label(&context, "ΦL", at: CGPoint(x: xs[0] - 22, y: yTop + 36), color: Theme.good)
        FieldSketch.label(&context, "ΦR", at: CGPoint(x: xs[2] + 22, y: yTop + 36), color: Theme.good)
    }

    private func fillLeg(_ context: inout GraphicsContext, x: CGFloat, y0: CGFloat, y1: CGFloat, thick: CGFloat, color: Color) {
        let rect = CGRect(x: x - thick / 2, y: min(y0, y1), width: thick, height: abs(y1 - y0))
        context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
    }
}

struct MachineRoleDiagram: View {
    enum Role { case transformer, motor, generator }
    var role: Role
    var detail: String

    private var summary: String {
        switch role {
        case .transformer:
            return "Transformer sketch. Two windings share one core flux. \(detail)"
        case .motor:
            return "Motor sketch. A current in the gap field produces force on one conductor. \(detail)"
        case .generator:
            return "Generator sketch. A conductor moving across the gap field produces emf. \(detail)"
        }
    }

    var body: some View {
        DiagramCard(
            title: roleTitle,
            accessibilitySummary: summary,
            exportName: "machine-\(roleTitle)"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    switch role {
                    case .transformer: transformer(&context, size: size)
                    case .motor: conductor(&context, size: size, moving: false)
                    case .generator: conductor(&context, size: size, moving: true)
                    }
                }
                .frame(height: 200)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var roleTitle: String {
        switch role {
        case .transformer: return "Shared flux"
        case .motor: return "Force on a conductor"
        case .generator: return "Conductor cutting flux"
        }
    }

    private func transformer(_ context: inout GraphicsContext, size: CGSize) {
        let core = CGRect(x: size.width * 0.28, y: 28, width: size.width * 0.44, height: size.height * 0.62)
        context.stroke(Path(roundedRect: core, cornerRadius: 8), with: .color(Theme.foreground), lineWidth: 10)
        coil(&context, x: core.minX, y: core.midY, label: "N1", color: Theme.copper)
        coil(&context, x: core.maxX, y: core.midY, label: "N2", color: Theme.accent)
        FieldSketch.arrow(
            &context,
            from: CGPoint(x: core.minX + 24, y: core.minY + 22),
            to: CGPoint(x: core.maxX - 24, y: core.minY + 22),
            color: Theme.good
        )
        FieldSketch.label(&context, "Φ shared", at: CGPoint(x: core.midX, y: core.minY + 8), color: Theme.good)
    }

    private func conductor(_ context: inout GraphicsContext, size: CGSize, moving: Bool) {
        let plot = FieldSketch.axes(&context, in: size, xTitle: moving ? "motion" : "force axis", yTitle: "B")
        var gap = Path()
        gap.move(to: CGPoint(x: plot.minX + 8, y: plot.midY - 28))
        gap.addLine(to: CGPoint(x: plot.maxX - 8, y: plot.midY - 28))
        gap.move(to: CGPoint(x: plot.minX + 8, y: plot.midY + 28))
        gap.addLine(to: CGPoint(x: plot.maxX - 8, y: plot.midY + 28))
        context.stroke(gap, with: .color(Theme.foreground.opacity(0.7)), lineWidth: 3)
        FieldSketch.arrow(
            &context,
            from: CGPoint(x: plot.midX - 36, y: plot.midY - 18),
            to: CGPoint(x: plot.midX - 36, y: plot.minY + 8),
            color: Theme.accent
        )
        FieldSketch.label(&context, "B", at: CGPoint(x: plot.midX - 52, y: plot.midY - 8), color: Theme.accent)
        let dot = CGRect(x: plot.midX - 8, y: plot.midY - 8, width: 16, height: 16)
        context.fill(Path(ellipseIn: dot), with: .color(Theme.copper))
        if moving {
            FieldSketch.arrow(
                &context,
                from: CGPoint(x: plot.midX + 16, y: plot.midY),
                to: CGPoint(x: plot.maxX - 16, y: plot.midY),
                color: Theme.energized
            )
            FieldSketch.label(&context, "v", at: CGPoint(x: plot.maxX - 24, y: plot.midY - 14), color: Theme.energized)
            FieldSketch.label(&context, "e", at: CGPoint(x: plot.midX, y: plot.midY + 18), color: Theme.good)
        } else {
            FieldSketch.arrow(
                &context,
                from: CGPoint(x: plot.midX, y: plot.midY + 12),
                to: CGPoint(x: plot.midX, y: plot.maxY - 8),
                color: Theme.good
            )
            FieldSketch.label(&context, "F", at: CGPoint(x: plot.midX + 16, y: plot.maxY - 16), color: Theme.good)
            FieldSketch.label(&context, "I", at: CGPoint(x: plot.midX + 18, y: plot.midY), color: Theme.copper)
        }
    }

    private func coil(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, label: String, color: Color) {
        for step in -2...2 {
            var tick = Path()
            let yy = y + CGFloat(step) * 8
            tick.move(to: CGPoint(x: x - 14, y: yy))
            tick.addLine(to: CGPoint(x: x + 14, y: yy))
            context.stroke(tick, with: .color(color), lineWidth: 2)
        }
        FieldSketch.label(&context, label, at: CGPoint(x: x, y: y + 36), color: color)
    }
}

// MARK: - EM sketches

struct FaradayLoopDiagram: View {
    var circulation: String
    var emf: Double
    var startB: Double?
    var endB: Double?
    var seconds: Double?

    private var summary: String {
        "Loop with B toward you. Induced emf \(Format.number(emf, digits: 4)) V. Circulation \(circulation). \(startB == nil ? "Single rate." : "B versus time is the average slope between the two readings.")"
    }

    var body: some View {
        DiagramCard(title: "Loop and polarity", accessibilitySummary: summary, exportName: "faraday-loop") {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    drawLoop(&context, size: size)
                }
                .frame(height: 210)
                if let startB, let endB, let seconds, seconds > 0 {
                    Canvas { context, size in
                        drawRamp(&context, size: size, start: startB, end: endB, seconds: seconds)
                    }
                    .frame(height: 140)
                }
                Text(circulation == "none"
                     ? "Steady flux. No induced current on this loop."
                     : "Positive B is toward you. The arrow is the induced current that opposes the change.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func drawLoop(_ context: inout GraphicsContext, size: CGSize) {
        let side = min(size.width, size.height) * 0.42
        let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2 - 6, width: side, height: side)
        context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(Theme.foreground), lineWidth: 3)
        for column in 0..<3 {
            for row in 0..<3 {
                let x = rect.minX + side * (CGFloat(column) + 0.5) / 3
                let y = rect.minY + side * (CGFloat(row) + 0.5) / 3
                let dot = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                context.stroke(Path(ellipseIn: dot), with: .color(Theme.accent), lineWidth: 1.4)
            }
        }
        FieldSketch.label(&context, "B toward you", at: CGPoint(x: rect.midX, y: rect.minY - 16), color: Theme.accent)
        if circulation != "none" {
            let clockwise = circulation == "clockwise"
            var arc = Path()
            arc.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: side * 0.62,
                startAngle: .degrees(clockwise ? 200 : 20),
                endAngle: .degrees(clockwise ? 20 : 200),
                clockwise: clockwise
            )
            context.stroke(arc, with: .color(Theme.copper), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            let tip = CGPoint(
                x: rect.midX + side * 0.62,
                y: rect.midY
            )
            FieldSketch.arrow(
                &context,
                from: CGPoint(x: tip.x - 1, y: tip.y + (clockwise ? 10 : -10)),
                to: tip,
                color: Theme.copper
            )
            FieldSketch.label(
                &context,
                clockwise ? "clockwise" : "counterclockwise",
                at: CGPoint(x: rect.midX, y: rect.maxY + 22),
                color: Theme.copper
            )
        }
    }

    private func drawRamp(_ context: inout GraphicsContext, size: CGSize, start: Double, end: Double, seconds: Double) {
        let plot = FieldSketch.axes(&context, in: size, xTitle: "t (s)", yTitle: "B (T)")
        let low = min(start, end, 0)
        let high = max(start, end, 0)
        let span = max(high - low, 1e-9)
        func point(_ t: Double, _ b: Double) -> CGPoint {
            CGPoint(
                x: plot.minX + CGFloat(t / seconds) * plot.width,
                y: plot.maxY - CGFloat((b - low) / span) * plot.height
            )
        }
        var line = Path()
        line.move(to: point(0, start))
        line.addLine(to: point(seconds, end))
        context.stroke(line, with: .color(Theme.accent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        FieldSketch.label(&context, Format.number(seconds, digits: 3), at: CGPoint(x: plot.maxX, y: plot.maxY + 10), color: Theme.muted, weight: .regular)
        FieldSketch.label(&context, Format.number(high, digits: 2), at: CGPoint(x: plot.minX + 28, y: plot.minY + 4), color: Theme.muted, weight: .regular)
    }
}

struct ChargePlaneDiagram: View {
    var charges: [EMFields.PointCharge]
    var point: FieldVector
    var field: FieldVector

    private var summary: String {
        "Charge plane. Test point x \(Format.number(point.x, digits: 3)) m, y \(Format.number(point.y, digits: 3)) m, z \(Format.number(point.z, digits: 3)) m. E \(Format.number(field.magnitude, digits: 3)) V/m."
    }

    var body: some View {
        DiagramCard(title: "Charge plane", accessibilitySummary: summary, exportName: "point-charges") {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    draw(&context, size: size)
                }
                .frame(height: 260)
                Text("Axes are metres in the x–y plane. z is the caption, not a third drawn axis. The arrow is E at the test point.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let plot = FieldSketch.axes(&context, in: size, xTitle: "x (m)", yTitle: "y")
        var xs = charges.map(\.x) + [point.x]
        var ys = charges.map(\.y) + [point.y]
        if xs.max() == xs.min() { xs.append((xs.first ?? 0) + 1) }
        if ys.max() == ys.min() { ys.append((ys.first ?? 0) + 1) }
        let minX = (xs.min() ?? -1) - 0.2
        let maxX = (xs.max() ?? 1) + 0.2
        let minY = (ys.min() ?? -1) - 0.2
        let maxY = (ys.max() ?? 1) + 0.2
        func map(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(
                x: plot.minX + CGFloat((x - minX) / (maxX - minX)) * plot.width,
                y: plot.maxY - CGFloat((y - minY) / (maxY - minY)) * plot.height
            )
        }
        for (index, charge) in charges.enumerated() {
            let center = map(charge.x, charge.y)
            let radius: CGFloat = 9
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let color: Color = charge.coulombs >= 0 ? Theme.bad : Theme.accent
            context.fill(Path(ellipseIn: rect), with: .color(color))
            FieldSketch.label(&context, "q\(index + 1)", at: CGPoint(x: center.x, y: center.y - 16), color: color)
        }
        let origin = map(point.x, point.y)
        context.stroke(Path(ellipseIn: CGRect(x: origin.x - 4, y: origin.y - 4, width: 8, height: 8)), with: .color(Theme.good), lineWidth: 2)
        let mag = field.magnitude
        if mag > 0 {
            let scale = min(plot.width, plot.height) * 0.28 / CGFloat(max(mag, 1e-9))
            let dx = CGFloat(field.x) * min(scale, 48)
            let dy = CGFloat(-field.y) * min(scale, 48)
            let clamped = max(hypot(dx, dy), 18)
            let ux = dx / max(hypot(dx, dy), 0.001) * clamped
            let uy = dy / max(hypot(dx, dy), 0.001) * clamped
            FieldSketch.arrow(&context, from: origin, to: CGPoint(x: origin.x + ux, y: origin.y + uy), color: Theme.good, width: 2.4)
        }
        FieldSketch.label(&context, "E", at: CGPoint(x: origin.x + 14, y: origin.y + 16), color: Theme.good)
        FieldSketch.label(&context, Format.number(maxX, digits: 2), at: CGPoint(x: plot.maxX, y: plot.maxY + 10), color: Theme.muted, weight: .regular)
    }
}

struct LorentzSketchDiagram: View {
    var velocity: FieldVector
    var force: FieldVector
    var magnetic: FieldVector
    var path: String
    var radius: Double?

    private var summary: String {
        var text = "Lorentz sketch. Path \(path). Force \(Format.number(force.magnitude, digits: 3)) N."
        if let radius {
            text += " Arc radius \(Format.number(radius, digits: 3)) m when E is negligible."
        }
        text += " Not a tracked trajectory."
        return text
    }

    var body: some View {
        DiagramCard(title: "Initial path", accessibilitySummary: summary, exportName: "lorentz-path") {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    draw(&context, size: size)
                }
                .frame(height: 230)
                Text(path == "curves"
                     ? "Magnetic term dominates. The curve is the sense of v × B, not a solved flight."
                     : "Electric term dominates or the terms mix. The arrow is the initial force.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let plot = FieldSketch.axes(&context, in: size, xTitle: "sketch x", yTitle: "sketch y")
        let origin = CGPoint(x: plot.midX, y: plot.midY)
        func unit(_ vector: FieldVector) -> CGPoint {
            let mag = max(vector.magnitude, 1e-12)
            return CGPoint(x: CGFloat(vector.x / mag), y: CGFloat(-vector.y / mag))
        }
        let v = unit(velocity.magnitude > 0 ? velocity : FieldVector(x: 1, y: 0, z: 0))
        let f = unit(force.magnitude > 0 ? force : FieldVector(x: 0, y: 1, z: 0))
        let reach = min(plot.width, plot.height) * 0.34
        FieldSketch.arrow(
            &context,
            from: origin,
            to: CGPoint(x: origin.x + v.x * reach, y: origin.y + v.y * reach),
            color: Theme.energized
        )
        FieldSketch.label(&context, "v", at: CGPoint(x: origin.x + v.x * reach, y: origin.y + v.y * reach - 12), color: Theme.energized)
        if path == "curves" {
            var arc = Path()
            arc.addArc(
                center: CGPoint(x: origin.x + f.x * reach * 0.8, y: origin.y + f.y * reach * 0.8),
                radius: reach * 0.72,
                startAngle: .degrees(210),
                endAngle: .degrees(20),
                clockwise: false
            )
            context.stroke(arc, with: .color(Theme.accent), style: StrokeStyle(lineWidth: 2.2, dash: [5, 4]))
            FieldSketch.label(&context, "curves", at: CGPoint(x: plot.maxX - 28, y: plot.minY + 12), color: Theme.accent)
        } else {
            FieldSketch.arrow(
                &context,
                from: origin,
                to: CGPoint(x: origin.x + f.x * reach, y: origin.y + f.y * reach),
                color: Theme.good
            )
            FieldSketch.label(&context, "F", at: CGPoint(x: origin.x + f.x * reach + 10, y: origin.y + f.y * reach), color: Theme.good)
        }
        if abs(magnetic.z) >= abs(magnetic.x), abs(magnetic.z) >= abs(magnetic.y), magnetic.magnitude > 0 {
            FieldSketch.label(
                &context,
                magnetic.z >= 0 ? "B toward you" : "B away",
                at: CGPoint(x: plot.minX + 48, y: plot.minY + 8),
                color: Theme.accent
            )
        }
    }
}

struct SampleFieldDiagram: View {
    var field: EMFields.SampleField
    var point: FieldVector

    private var summary: String {
        let value = field.value(at: point)
        return "\(field.title) sample in the x–y plane. At x \(Format.number(point.x, digits: 2)), y \(Format.number(point.y, digits: 2)) the vector is \(Format.number(value.x, digits: 2)), \(Format.number(value.y, digits: 2)), \(Format.number(value.z, digits: 2)). Divergence \(Format.number(field.divergence, digits: 0)). Curl z \(Format.number(field.curl.z, digits: 0))."
    }

    var body: some View {
        DiagramCard(title: "Sample field", accessibilitySummary: summary, exportName: "sample-field") {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    draw(&context, size: size)
                }
                .frame(height: 230)
                Text("Arrows are the canned field on z = 0. Axes are the coordinates you typed, not a site survey.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let plot = FieldSketch.axes(&context, in: size, xTitle: "x", yTitle: "y")
        let steps = 5
        for row in 0..<steps {
            for column in 0..<steps {
                let x = -1.0 + 2.0 * Double(column) / Double(steps - 1)
                let y = -1.0 + 2.0 * Double(row) / Double(steps - 1)
                let value = field.value(at: FieldVector(x: x, y: y, z: 0))
                let origin = CGPoint(
                    x: plot.minX + CGFloat(column) / CGFloat(steps - 1) * plot.width,
                    y: plot.maxY - CGFloat(row) / CGFloat(steps - 1) * plot.height
                )
                let mag = max(value.magnitude, 1e-9)
                let reach: CGFloat = 16
                let tip = CGPoint(
                    x: origin.x + CGFloat(value.x / mag) * reach,
                    y: origin.y - CGFloat(value.y / mag) * reach
                )
                FieldSketch.arrow(&context, from: origin, to: tip, color: Theme.accent, width: 1.4)
            }
        }
        let marker = CGPoint(
            x: plot.minX + CGFloat((point.x + 1) / 2) * plot.width,
            y: plot.maxY - CGFloat((point.y + 1) / 2) * plot.height
        )
        if marker.x >= plot.minX, marker.x <= plot.maxX, marker.y >= plot.minY, marker.y <= plot.maxY {
            context.fill(Path(ellipseIn: CGRect(x: marker.x - 3, y: marker.y - 3, width: 6, height: 6)), with: .color(Theme.energized))
        }
    }
}
