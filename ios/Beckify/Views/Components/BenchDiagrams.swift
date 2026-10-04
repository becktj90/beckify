import SwiftUI
import BeckifyMath

// MARK: - Shared drawing helpers

private enum BenchInk {
    static func label(
        _ context: GraphicsContext,
        _ text: String,
        at point: CGPoint,
        size: CGFloat = 11,
        weight: Font.Weight = .semibold,
        color: Color = Theme.foreground,
        anchor: UnitPoint = .center
    ) {
        context.draw(
            Text(text).font(.system(size: size, weight: weight, design: .rounded)).foregroundColor(color),
            at: point,
            anchor: anchor
        )
    }

    /// Dimension line with end ticks and a centered label on a small plate.
    static func dimension(
        _ context: GraphicsContext,
        from a: CGPoint,
        to b: CGPoint,
        text: String,
        color: Color = Theme.accent2,
        labelOffset: CGPoint = .zero
    ) {
        var line = Path()
        line.move(to: a)
        line.addLine(to: b)
        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let nx = -dy / length * 4
        let ny = dx / length * 4
        for end in [a, b] {
            var tick = Path()
            tick.move(to: CGPoint(x: end.x - nx, y: end.y - ny))
            tick.addLine(to: CGPoint(x: end.x + nx, y: end.y + ny))
            context.stroke(tick, with: .color(color), lineWidth: 1)
        }
        let mid = CGPoint(x: (a.x + b.x) / 2 + labelOffset.x, y: (a.y + b.y) / 2 + labelOffset.y)
        let plate = CGRect(x: mid.x - CGFloat(text.count) * 3.1 - 4, y: mid.y - 8, width: CGFloat(text.count) * 6.2 + 8, height: 16)
        context.fill(Path(roundedRect: plate, cornerRadius: 4), with: .color(Theme.surfaceRaised.opacity(0.92)))
        label(context, text, at: mid, size: 10.5, color: color)
    }
}

// MARK: - Heater coil

/// Side view of a helical heating element drawn from the calculated geometry. The front of each
/// turn is bright and the back is dim, so it reads as a real coil. Long coils draw a few turns at
/// the true pitch and diameter, then state the full turn count.
struct HeaterCoilDiagram: View {
    let geometry: HeaterCoilGeometry
    let materialLabel: String
    /// Element resistance the wire was cut for.
    var resistanceOhms: Double?

    private var drawnTurns: Double { min(geometry.turns, 8) }

    private var summary: String {
        "Helical \(materialLabel) heating element. \(Format.number(geometry.turns, digits: 1)) turns of \(Format.number(geometry.wireDiameterMM, digits: 2)) millimeter wire, coil outside diameter \(Format.number(geometry.outerDiameterMM, digits: 1)) millimeters, inside diameter \(Format.number(geometry.innerDiameterMM, digits: 1)), pitch \(Format.number(geometry.pitchMM, digits: 2)), gap \(Format.number(geometry.gapMM, digits: 2)), coil length \(Format.number(geometry.coilLengthMM, digits: 0)) millimeters."
    }

    var body: some View {
        DiagramCard(title: "Heater coil", accessibilitySummary: summary, exportName: "heater-coil") {
            EngineeringDiagramFrame(summary: summary) {
                VStack(alignment: .leading, spacing: 8) {
                    Canvas { context, size in draw(context, size) }
                        .frame(height: 230)
                    facts
                }
            }
        }
        .accessibilityIdentifier("heaterDesign.coil")
    }

    private var facts: some View {
        let g = geometry
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(Format.number(g.turns, digits: 1)) turns · wire \(Format.number(g.wireDiameterMM, digits: 2)) mm · \(materialLabel)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text("OD \(Format.number(g.outerDiameterMM, digits: 1)) mm · ID \(Format.number(g.innerDiameterMM, digits: 1)) mm · pitch \(Format.number(g.pitchMM, digits: 2)) mm · gap \(Format.number(g.gapMM, digits: 2)) mm")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text("Coil length \(Format.number(g.coilLengthMM, digits: 0)) mm from \(Format.number(g.wireLengthMM / 1000, digits: 2)) m of wire")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            if geometry.turns > 8 {
                Text("Drawn: 8 of \(Format.number(g.turns, digits: 0)) turns, at the true pitch and diameter.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize) {
        let g = geometry
        let turnsDrawn = CGFloat(drawnTurns)
        let wireMM = CGFloat(g.wireDiameterMM)
        let meanMM = CGFloat(g.meanDiameterMM)
        let outerMM = CGFloat(g.outerDiameterMM)
        let pitchMM = CGFloat(g.pitchMM)
        let gapMM = CGFloat(g.gapMM)

        let padLeft: CGFloat = 26
        let padRight: CGFloat = 54
        let padTop: CGFloat = 26
        let padBottom: CGFloat = 50
        let spanX: CGFloat = max((turnsDrawn - 1) * pitchMM + wireMM + meanMM * 0.3, 1)
        let spanY: CGFloat = outerMM
        let scaleX: CGFloat = (size.width - padLeft - padRight) / spanX
        let scaleY: CGFloat = (size.height - padTop - padBottom) / spanY
        let scale: CGFloat = min(scaleX, scaleY)
        let radius: CGFloat = meanMM / 2 * scale
        let cy: CGFloat = padTop + (size.height - padTop - padBottom) / 2
        let x0: CGFloat = padLeft + meanMM * 0.15 * scale
        let pitchPx: CGFloat = pitchMM * scale
        let wirePx: CGFloat = max(wireMM * scale, 1.6)

        // Axis.
        var axis = Path()
        axis.move(to: CGPoint(x: padLeft - 8, y: cy))
        axis.addLine(to: CGPoint(x: size.width - padRight + 8, y: cy))
        context.stroke(axis, with: .color(Theme.border), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        let steps = max(Int(drawnTurns * 48), 48)
        // Parametric helix seen from the side. `t` is in turns. Depth is cos, so the front is positive.
        func point(_ t: Double) -> (CGPoint, Double) {
            let angle = t * 2 * Double.pi
            let x: CGFloat = x0 + CGFloat(t) * pitchPx + CGFloat(cos(angle)) * radius * 0.15
            let y: CGFloat = cy - CGFloat(sin(angle)) * radius
            return (CGPoint(x: x, y: y), cos(angle))
        }
        let first = point(0).0
        let last = point(drawnTurns).0
        var leadIn = Path()
        leadIn.move(to: CGPoint(x: padLeft - 8, y: first.y))
        leadIn.addLine(to: first)
        context.stroke(leadIn, with: .color(Theme.copper), style: StrokeStyle(lineWidth: wirePx, lineCap: .round))
        var leadOut = Path()
        leadOut.move(to: last)
        leadOut.addLine(to: CGPoint(x: size.width - padRight + 8, y: last.y))
        context.stroke(leadOut, with: .color(Theme.copper), style: StrokeStyle(lineWidth: wirePx, lineCap: .round))

        // Back of every turn first, then the front over it.
        for pass in 0..<2 {
            for step in 0..<steps {
                let t0 = drawnTurns * Double(step) / Double(steps)
                let t1 = drawnTurns * Double(step + 1) / Double(steps)
                let (p0, depth0) = point(t0)
                let (p1, depth1) = point(t1)
                let front = (depth0 + depth1) / 2 >= 0
                guard front == (pass == 1) else { continue }
                var seg = Path()
                seg.move(to: p0)
                seg.addLine(to: p1)
                context.stroke(
                    seg,
                    with: .color(front ? Theme.energized : Theme.energized.opacity(0.38)),
                    style: StrokeStyle(lineWidth: front ? wirePx : wirePx * 0.8, lineCap: .round)
                )
            }
        }

        // Outside diameter.
        let odX = size.width - padRight + 20
        BenchInk.dimension(
            context,
            from: CGPoint(x: odX, y: cy - outerMM / 2 * scale),
            to: CGPoint(x: odX, y: cy + outerMM / 2 * scale),
            text: "OD \(Format.number(g.outerDiameterMM, digits: 1))",
            labelOffset: CGPoint(x: -2, y: 0)
        )

        // Pitch along the top, and the gap between two turns underneath.
        if drawnTurns >= 3 {
            let a = point(1.25).0
            let b = point(2.25).0
            let topY = cy - radius - wirePx - 8
            BenchInk.dimension(
                context,
                from: CGPoint(x: a.x, y: topY),
                to: CGPoint(x: b.x, y: topY),
                text: "pitch \(Format.number(g.pitchMM, digits: 2))"
            )
            if gapMM * scale > 6 {
                let gapY = cy + radius + wirePx + 10
                BenchInk.dimension(
                    context,
                    from: CGPoint(x: a.x + wirePx / 2, y: gapY),
                    to: CGPoint(x: a.x + wirePx / 2 + gapMM * scale, y: gapY),
                    text: "gap \(Format.number(g.gapMM, digits: 2))",
                    color: Theme.good,
                    labelOffset: CGPoint(x: 0, y: 14)
                )
            }
        }

        // Overall length of the drawn part, or of the whole coil when it all fits.
        let lengthY = size.height - 16
        let coilStart = x0
        let coilEnd = x0 + (turnsDrawn - 1) * pitchPx + wirePx
        BenchInk.dimension(
            context,
            from: CGPoint(x: coilStart, y: lengthY),
            to: CGPoint(x: coilEnd, y: lengthY),
            text: g.turns <= 8
                ? "L \(Format.number(g.coilLengthMM, digits: 0)) mm"
                : "full coil \(Format.number(g.coilLengthMM, digits: 0)) mm",
            color: Theme.accent
        )
    }
}

// MARK: - Sprocket setup

/// Two toothed sprockets and the chain between them, to scale from the calculated pitch diameters,
/// center distance, and link count.
struct SprocketSetupDiagram: View {
    let setup: SprocketSetup
    var motorRPM: Double?
    var outputRPM: Double?

    private var summary: String {
        "Drive sprocket \(setup.driveTeeth) teeth, pitch diameter \(Format.number(setup.drivePitchDiameterMM, digits: 1)) millimeters. Driven sprocket \(setup.drivenTeeth) teeth, pitch diameter \(Format.number(setup.drivenPitchDiameterMM, digits: 1)) millimeters. Ratio \(Format.number(setup.ratio, digits: 2)) to 1. Center distance \(Format.number(setup.centerDistanceMM, digits: 1)) millimeters. Chain \(setup.chainLinks) links of \(setup.chain.label)."
    }

    private var aspect: CGFloat {
        let width = setup.centerDistanceMM + (setup.driveOutsideDiameterMM + setup.drivenOutsideDiameterMM) / 2
        let height = max(setup.driveOutsideDiameterMM, setup.drivenOutsideDiameterMM)
        return min(max(CGFloat(width / max(height, 1)) * 0.82, 1.15), 3.2)
    }

    var body: some View {
        DiagramCard(title: "Sprocket setup", accessibilitySummary: summary, exportName: "sprocket-setup") {
            EngineeringDiagramFrame(summary: summary) {
                VStack(alignment: .leading, spacing: 8) {
                    Canvas { context, size in draw(context, size) }
                        .aspectRatio(aspect, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    facts
                }
            }
        }
        .accessibilityIdentifier("sprocket.diagram")
    }

    private var facts: some View {
        let s = setup
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(s.driveTeeth)T → \(s.drivenTeeth)T  ·  \(Format.number(s.ratio, digits: 2)):1  ·  \(s.chain.label)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text("Pitch Ø \(Format.number(s.drivePitchDiameterMM, digits: 1)) / \(Format.number(s.drivenPitchDiameterMM, digits: 1)) mm  ·  outside Ø \(Format.number(s.driveOutsideDiameterMM, digits: 1)) / \(Format.number(s.drivenOutsideDiameterMM, digits: 1)) mm")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text("Center distance \(Format.number(s.centerDistanceMM, digits: 1)) mm  ·  \(s.chainLinks) links (\(Format.number(s.chainLengthMM / 25.4, digits: 1)) in)  ·  wrap on small sprocket \(Format.number(s.smallWrapDegrees, digits: 0))°")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text("Planning geometry. Confirm chain length, tension, and chainline with the chain maker.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize) {
        let s = setup
        let padX: CGFloat = 22
        let padTop: CGFloat = 28
        let padBottom: CGFloat = 44
        let o1 = s.driveOutsideDiameterMM
        let o2 = s.drivenOutsideDiameterMM
        let spanX = s.centerDistanceMM + o1 / 2 + o2 / 2
        let spanY = max(o1, o2)
        let scale = min((size.width - 2 * padX) / CGFloat(spanX), (size.height - padTop - padBottom) / CGFloat(spanY))
        let cy = padTop + (size.height - padTop - padBottom) / 2
        let c1 = CGPoint(x: padX + CGFloat(o1 / 2) * scale, y: cy)
        let c2 = CGPoint(x: c1.x + CGFloat(s.centerDistanceMM) * scale, y: cy)
        let r1 = CGFloat(s.drivePitchDiameterMM / 2) * scale
        let r2 = CGFloat(s.drivenPitchDiameterMM / 2) * scale
        let pitchPx = CGFloat(s.chain.pitchMM) * scale

        drawChain(context, c1: c1, c2: c2, r1: r1, r2: r2, pitchPx: pitchPx)
        drawSprocket(context, center: c1, teeth: s.driveTeeth, pitchRadius: r1, outsideRadius: CGFloat(o1 / 2) * scale, tint: Theme.accent)
        drawSprocket(context, center: c2, teeth: s.drivenTeeth, pitchRadius: r2, outsideRadius: CGFloat(o2 / 2) * scale, tint: Theme.accent2)

        BenchInk.label(context, "\(s.driveTeeth)T", at: c1, size: max(min(r1 * 0.45, 20), 11), color: Theme.foreground)
        BenchInk.label(context, "\(s.drivenTeeth)T", at: c2, size: max(min(r2 * 0.4, 22), 11), color: Theme.foreground)

        // Hubs.
        for center in [c1, c2] {
            context.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(Theme.muted))
        }

        // Titles above each sprocket.
        let driveTitle = motorRPM.map { "Drive · \(Format.number($0, digits: 0)) rpm" } ?? "Drive"
        let drivenTitle = outputRPM.map { "Driven · \(Format.number($0, digits: 0)) rpm" } ?? "Driven"
        BenchInk.label(context, driveTitle, at: CGPoint(x: c1.x, y: 12), size: 11, color: Theme.accent)
        BenchInk.label(context, drivenTitle, at: CGPoint(x: c2.x, y: 12), size: 11, color: Theme.accent2)

        // Center distance, and pitch diameters beneath each sprocket.
        let baseY = size.height - 26
        BenchInk.dimension(context, from: CGPoint(x: c1.x, y: baseY), to: CGPoint(x: c2.x, y: baseY), text: "C = \(Format.number(s.centerDistanceMM, digits: 1)) mm", color: Theme.good)
        BenchInk.label(context, "Ø\(Format.number(s.drivePitchDiameterMM, digits: 1))", at: CGPoint(x: c1.x, y: size.height - 8), size: 10, weight: .medium, color: Theme.muted)
        BenchInk.label(context, "Ø\(Format.number(s.drivenPitchDiameterMM, digits: 1))", at: CGPoint(x: c2.x, y: size.height - 8), size: 10, weight: .medium, color: Theme.muted)
        BenchInk.label(
            context,
            "\(s.chainLinks) links",
            at: CGPoint(x: (c1.x + c2.x) / 2, y: cy - max(r1, r2) * 0.55 - 10),
            size: 10.5,
            color: Theme.copper
        )
    }

    private func drawSprocket(
        _ context: GraphicsContext,
        center: CGPoint,
        teeth: Int,
        pitchRadius: CGFloat,
        outsideRadius: CGFloat,
        tint: Color
    ) {
        let rootRadius = max(pitchRadius - (outsideRadius - pitchRadius) * 1.1, pitchRadius * 0.7)
        var gear = Path()
        let toothAngle = 2 * Double.pi / Double(teeth)
        for index in 0..<teeth {
            let a = Double(index) * toothAngle
            let corners: [(Double, CGFloat)] = [
                (a - toothAngle * 0.5, rootRadius),
                (a - toothAngle * 0.2, outsideRadius),
                (a + toothAngle * 0.2, outsideRadius),
                (a + toothAngle * 0.5, rootRadius),
            ]
            for (offset, corner) in corners.enumerated() {
                let point = CGPoint(
                    x: center.x + CGFloat(cos(corner.0)) * corner.1,
                    y: center.y + CGFloat(sin(corner.0)) * corner.1
                )
                if index == 0 && offset == 0 { gear.move(to: point) } else { gear.addLine(to: point) }
            }
        }
        gear.closeSubpath()
        context.fill(gear, with: .color(tint.opacity(0.22)))
        context.stroke(gear, with: .color(tint), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - pitchRadius, y: center.y - pitchRadius, width: pitchRadius * 2, height: pitchRadius * 2)),
            with: .color(tint.opacity(0.7)),
            style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
        )
    }

    /// External-tangent chain run plus the wrap around each pitch circle. Math coordinates, y up,
    /// then flipped to the screen.
    private func drawChain(_ context: GraphicsContext, c1: CGPoint, c2: CGPoint, r1: CGFloat, r2: CGFloat, pitchPx: CGFloat) {
        let center = c2.x - c1.x
        let sinPhi = max(min((r2 - r1) / center, 0.999), -0.999)
        let phi = asin(Double(sinPhi))
        func screen(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
            CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y - CGFloat(sin(angle)) * radius)
        }
        func arc(_ center: CGPoint, _ radius: CGFloat, from: Double, to: Double) -> [CGPoint] {
            let count = max(Int(abs(to - from) * Double(radius) / 3), 12)
            return (0...count).map { step in
                screen(center, radius, from + (to - from) * Double(step) / Double(count))
            }
        }
        let upperAngle = Double.pi / 2 + phi
        let lowerLeft = 3 * Double.pi / 2 - phi
        let lowerRight = -Double.pi / 2 - phi
        var path = Path()
        // Top run, right wrap, bottom run, left wrap.
        path.move(to: screen(c1, r1, upperAngle))
        path.addLine(to: screen(c2, r2, upperAngle))
        for point in arc(c2, r2, from: upperAngle, to: lowerRight).dropFirst() { path.addLine(to: point) }
        path.addLine(to: screen(c1, r1, lowerLeft))
        for point in arc(c1, r1, from: lowerLeft, to: upperAngle).dropFirst() { path.addLine(to: point) }
        // Dashes read as links. The gap is a bit smaller than a link.
        let link = max(pitchPx, 2.5)
        context.stroke(
            path,
            with: .color(Theme.copper),
            style: StrokeStyle(lineWidth: max(min(link * 0.5, 4), 1.6), lineJoin: .round, dash: [link * 0.7, link * 0.3])
        )
    }
}

// MARK: - Battery pack (isometric)

/// Isometric 3D view of the finished S×P pack with series groups, nickel strips, and overall dimensions.
struct PackIsometricDiagram: View {
    let model: PackModel3D
    var nominalVolts: Double?
    var energyWattHours: Double?

    private var architecture: String { "\(model.series)S\(model.parallel)P" }

    private var summary: String {
        "Isometric view of a \(architecture) battery pack of \(model.cells.count) cells. Overall \(Format.number(model.lengthMM, digits: 0)) by \(Format.number(model.widthMM, digits: 0)) by \(Format.number(model.heightMM, digits: 1)) millimeters, cells and nickel only."
    }

    var body: some View {
        DiagramCard(title: "Finished pack · 3D", accessibilitySummary: summary, exportName: "battery-pack-3d", allowsMagnify: false) {
            EngineeringDiagramFrame(summary: summary) {
                VStack(alignment: .leading, spacing: 8) {
                    Canvas { context, size in draw(context, size) }
                        .frame(height: 360)
                    facts
                }
            }
        }
        .accessibilityIdentifier("packDesigner.iso")
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(architecture) · \(model.cells.count) cells · \(model.honeycomb ? "honeycomb" : "grid") packing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text("\(Format.number(model.lengthMM, digits: 0)) × \(Format.number(model.widthMM, digits: 0)) × \(Format.number(model.heightMM, digits: 1)) mm (L × W × H)\(nominalVolts.map { " · \(Format.volts($0)) nominal" } ?? "")\(energyWattHours.map { " · \(Format.number($0, digits: 0)) Wh" } ?? "")")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text("Cells and nickel only. Add heat-shrink or holders, fish paper, BMS, wiring, and the enclosure.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    /// Projection of a point in pack millimeters, before scale and origin.
    private func project(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
        CGPoint(x: (x - y) * 0.8660254, y: (x + y) * 0.5 - z)
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize) {
        let m = model
        let corners: [CGPoint] = [
            project(0, 0, 0), project(m.lengthMM, 0, 0), project(0, m.widthMM, 0), project(m.lengthMM, m.widthMM, 0),
            project(0, 0, m.heightMM), project(m.lengthMM, 0, m.heightMM), project(0, m.widthMM, m.heightMM), project(m.lengthMM, m.widthMM, m.heightMM),
        ]
        let minX = corners.map(\.x).min() ?? 0
        let maxX = corners.map(\.x).max() ?? 1
        let minY = corners.map(\.y).min() ?? 0
        let maxY = corners.map(\.y).max() ?? 1
        let padX: CGFloat = 54
        let padTop: CGFloat = 40
        let padBottom: CGFloat = 54
        let scale = min(
            (size.width - 2 * padX) / max(maxX - minX, 1),
            (size.height - padTop - padBottom) / max(maxY - minY, 1)
        )
        let originX = padX + (size.width - 2 * padX - (maxX - minX) * scale) / 2 - minX * scale
        let originY = padTop + (size.height - padTop - padBottom - (maxY - minY) * scale) / 2 - minY * scale
        func p(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
            let raw = project(x, y, z)
            return CGPoint(x: originX + raw.x * scale, y: originY + raw.y * scale)
        }

        // Floor shadow.
        var floor = Path()
        floor.move(to: p(0, 0, 0))
        floor.addLine(to: p(m.lengthMM, 0, 0))
        floor.addLine(to: p(m.lengthMM, m.widthMM, 0))
        floor.addLine(to: p(0, m.widthMM, 0))
        floor.closeSubpath()
        context.fill(floor, with: .color(Theme.border.opacity(0.35)))

        let radius = m.cellDiameterMM / 2
        let a = CGFloat(radius * 1.2247449) * scale
        let b = CGFloat(radius * 0.7071068) * scale
        let wrap = Color(red: 0.14, green: 0.32, blue: 0.58)
        let wrapLight = Color(red: 0.22, green: 0.45, blue: 0.75)
        let cellTop = m.heightMM - m.stripThicknessMM
        let bottomZ = m.stripThicknessMM

        // Back-to-front so nearer cells cover farther ones.
        let ordered = m.cells.sorted { ($0.x + $0.y) < ($1.x + $1.y) }
        for cell in ordered {
            let top = p(cell.x, cell.y, cellTop)
            let bottom = p(cell.x, cell.y, bottomZ)
            context.fill(Path(ellipseIn: CGRect(x: bottom.x - a, y: bottom.y - b, width: a * 2, height: b * 2)), with: .color(wrap))
            context.fill(Path(CGRect(x: top.x - a, y: top.y, width: a * 2, height: bottom.y - top.y)), with: .color(wrap))
            // Light on the left edge, so the wrap reads as round.
            context.fill(Path(CGRect(x: top.x - a, y: top.y, width: a * 0.55, height: bottom.y - top.y)), with: .color(wrapLight.opacity(0.55)))
            let topRect = CGRect(x: top.x - a, y: top.y - b, width: a * 2, height: b * 2)
            context.fill(Path(ellipseIn: topRect), with: .color(Color(white: 0.78)))
            context.stroke(Path(ellipseIn: topRect), with: .color(Color(white: 0.45)), lineWidth: 0.6)
            let button = topRect.insetBy(dx: a * 0.55, dy: b * 0.55)
            context.fill(Path(ellipseIn: button), with: .color(Color(white: 0.92)))
        }

        // Nickel strips across each pair of series groups on the top face.
        var column = 0
        while column + 1 < m.series {
            let xs = m.cells.filter { $0.column == column || $0.column == column + 1 }
            let x0 = (xs.map(\.x).min() ?? 0) - radius * 0.55
            let x1 = (xs.map(\.x).max() ?? 0) + radius * 0.55
            let y0 = (xs.map(\.y).min() ?? 0) - radius * 0.9
            let y1 = (xs.map(\.y).max() ?? 0) + radius * 0.9
            var strip = Path()
            strip.move(to: p(x0, y0, m.heightMM))
            strip.addLine(to: p(x1, y0, m.heightMM))
            strip.addLine(to: p(x1, y1, m.heightMM))
            strip.addLine(to: p(x0, y1, m.heightMM))
            strip.closeSubpath()
            context.fill(strip, with: .color(Color(white: 0.85).opacity(0.5)))
            context.stroke(strip, with: .color(Color(white: 0.95).opacity(0.8)), lineWidth: 0.8)
            column += 2
        }

        // Pack leads. B− on the first group, B+ on the last.
        func lead(_ column: Int, _ text: String, _ tint: Color) {
            guard let cell = m.cells.first(where: { $0.column == column && $0.row == 0 }) else { return }
            let start = p(cell.x, cell.y - radius * 0.2, m.heightMM)
            let end = CGPoint(x: start.x + (column == 0 ? -26 : 26), y: start.y - 24)
            var wire = Path()
            wire.move(to: start)
            wire.addLine(to: end)
            context.stroke(wire, with: .color(tint), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            BenchInk.label(context, text, at: CGPoint(x: end.x + (column == 0 ? -4 : 4), y: end.y - 8), size: 11, weight: .bold, color: tint)
        }
        lead(0, "B−", Theme.muted)
        lead(m.series - 1, "B+", Theme.bad)

        // Series and parallel callouts.
        BenchInk.label(
            context,
            "\(m.series) groups in series →",
            at: CGPoint(x: (p(0, 0, m.heightMM).x + p(m.lengthMM, 0, m.heightMM).x) / 2 + 12, y: (p(0, 0, m.heightMM).y + p(m.lengthMM, 0, m.heightMM).y) / 2 - 28),
            size: 10.5,
            color: Theme.accent
        )

        // Overall dimensions along the box edges.
        let off = max(m.cellDiameterMM * 0.9, 10)
        BenchInk.dimension(
            context,
            from: p(0, m.widthMM + off, 0),
            to: p(m.lengthMM, m.widthMM + off, 0),
            text: "L \(Format.number(m.lengthMM, digits: 0)) mm",
            labelOffset: CGPoint(x: 0, y: 12)
        )
        BenchInk.dimension(
            context,
            from: p(m.lengthMM + off, 0, 0),
            to: p(m.lengthMM + off, m.widthMM, 0),
            text: "W \(Format.number(m.widthMM, digits: 0)) mm",
            color: Theme.good,
            labelOffset: CGPoint(x: 16, y: 6)
        )
        BenchInk.dimension(
            context,
            from: p(0, m.widthMM + off * 0.2, 0).applying(CGAffineTransform(translationX: -34, y: 0)),
            to: p(0, m.widthMM + off * 0.2, m.heightMM).applying(CGAffineTransform(translationX: -34, y: 0)),
            text: "H \(Format.number(m.heightMM, digits: 1))",
            color: Theme.copper,
            labelOffset: CGPoint(x: -6, y: 0)
        )
        BenchInk.label(
            context,
            "\(m.parallel) cells in parallel per group",
            at: CGPoint(x: p(m.lengthMM, m.widthMM / 2, 0).x + 8, y: p(m.lengthMM, m.widthMM / 2, 0).y + 40),
            size: 10,
            weight: .medium,
            color: Theme.muted
        )
        BenchInk.label(context, "\(architecture)  ·  \(m.cells.count) cells", at: CGPoint(x: size.width / 2, y: 14), size: 14, weight: .bold, color: Theme.foreground)
    }
}

// MARK: - Nickel strip

/// Strip cross-section beside a top view of the same strip welded across two 18650 cells. The strip
/// width is to scale against the cell. The cross-section thickness is exaggerated so it can be seen.
struct NickelStripDiagram: View {
    let result: NickelStripResult
    private let cellDiameterMM = 18.0

    private var summary: String {
        "Nickel strip \(Format.number(result.widthMM, digits: 1)) millimeters wide and \(Format.number(result.thicknessMM, digits: 2)) thick, cross section \(Format.number(result.crossSectionMM2, digits: 2)) square millimeters. Planning current \(Format.number(result.continuousAmps, digits: 1)) amps continuous and \(Format.number(result.pulseAmps, digits: 1)) amps in a short pulse."
    }

    var body: some View {
        DiagramCard(title: "Strip on cells", accessibilitySummary: summary, exportName: "nickel-strip") {
            EngineeringDiagramFrame(summary: summary) {
                VStack(alignment: .leading, spacing: 8) {
                    Canvas { context, size in draw(context, size) }
                        .frame(height: 230)
                    Text("Cross-section thickness is exaggerated. In the top view the strip width is to scale against an 18 mm cell. Weld spots show a typical layout, not a weld spec.")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .accessibilityIdentifier("nickelStrip.diagram")
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize) {
        let r = result
        let split = size.width * 0.28

        // Cross-section, left.
        let sectionW = min(split - 24, 70)
        let aspect = r.widthMM / max(r.thicknessMM, 0.01)
        let sectionH = max(min(sectionW / CGFloat(aspect) * 1.0, 40), 8)
        let sx = (split - sectionW) / 2
        let sy = size.height / 2 - sectionH / 2
        let section = CGRect(x: sx, y: sy, width: sectionW, height: sectionH)
        context.fill(Path(roundedRect: section, cornerRadius: 1.5), with: .color(Color(white: 0.82)))
        context.stroke(Path(roundedRect: section, cornerRadius: 1.5), with: .color(Color(white: 0.55)), lineWidth: 1)
        BenchInk.label(context, "Cross-section", at: CGPoint(x: split / 2, y: 14), size: 10.5, weight: .medium, color: Theme.muted)
        BenchInk.dimension(
            context,
            from: CGPoint(x: section.minX, y: section.maxY + 14),
            to: CGPoint(x: section.maxX, y: section.maxY + 14),
            text: "w \(Format.number(r.widthMM, digits: 1))",
            labelOffset: CGPoint(x: 0, y: 13)
        )
        BenchInk.dimension(
            context,
            from: CGPoint(x: section.maxX + 12, y: section.minY),
            to: CGPoint(x: section.maxX + 12, y: section.maxY),
            text: "t \(Format.number(r.thicknessMM, digits: 2))",
            color: Theme.good,
            labelOffset: CGPoint(x: 0, y: -16)
        )
        BenchInk.label(context, "\(Format.number(r.crossSectionMM2, digits: 2)) mm²", at: CGPoint(x: split / 2, y: size.height - 12), size: 11, weight: .bold, color: Theme.foreground)

        // Divider.
        var divider = Path()
        divider.move(to: CGPoint(x: split, y: 12))
        divider.addLine(to: CGPoint(x: split, y: size.height - 12))
        context.stroke(divider, with: .color(Theme.border), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

        // Top view, right: two cells and the strip.
        let areaX = split + 14
        let areaW = size.width - areaX - 12
        let mmWidth = cellDiameterMM * 2 + 6
        let scale = min(areaW / CGFloat(mmWidth), (size.height - 70) / CGFloat(cellDiameterMM + 4))
        let cy = size.height / 2 + 4
        let leftCenter = CGPoint(x: areaX + CGFloat(cellDiameterMM / 2 + 1) * scale, y: cy)
        let rightCenter = CGPoint(x: leftCenter.x + CGFloat(cellDiameterMM + 1) * scale, y: cy)
        let radius = CGFloat(cellDiameterMM / 2) * scale
        for center in [leftCenter, rightCenter] {
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.14, green: 0.32, blue: 0.58)))
            context.stroke(Path(ellipseIn: rect), with: .color(Color(white: 0.7)), lineWidth: 1)
            let button = rect.insetBy(dx: radius * 0.45, dy: radius * 0.45)
            context.fill(Path(ellipseIn: button), with: .color(Color(white: 0.2)))
        }
        let stripWidthPx = min(CGFloat(r.widthMM) * scale, radius * 2.4)
        let strip = CGRect(
            x: leftCenter.x - radius * 0.95,
            y: cy - stripWidthPx / 2,
            width: rightCenter.x - leftCenter.x + radius * 1.9,
            height: stripWidthPx
        )
        context.fill(Path(roundedRect: strip, cornerRadius: 2), with: .color(Color(white: 0.86).opacity(0.92)))
        context.stroke(Path(roundedRect: strip, cornerRadius: 2), with: .color(Color(white: 1).opacity(0.9)), lineWidth: 0.8)
        // Weld spots, two rows on each cell.
        for center in [leftCenter, rightCenter] {
            for dx in [-radius * 0.28, radius * 0.28] {
                for dy in [-stripWidthPx * 0.22, stripWidthPx * 0.22] {
                    let spot = CGRect(x: center.x + dx - 3, y: cy + dy - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: spot), with: .color(Theme.energized.opacity(0.85)))
                    context.stroke(Path(ellipseIn: spot), with: .color(Color(white: 0.35)), lineWidth: 0.6)
                }
            }
        }
        BenchInk.label(context, "Top view · 18 mm cells", at: CGPoint(x: areaX + areaW / 2, y: 14), size: 10.5, weight: .medium, color: Theme.muted)
        BenchInk.dimension(
            context,
            from: CGPoint(x: strip.maxX + 5, y: strip.minY),
            to: CGPoint(x: strip.maxX + 5, y: strip.maxY),
            text: "\(Format.number(r.widthMM, digits: 1))",
            labelOffset: CGPoint(x: -1, y: 0)
        )

        // Current arrow along the strip.
        let arrowY = strip.minY - 12
        var arrow = Path()
        arrow.move(to: CGPoint(x: strip.minX + 6, y: arrowY))
        arrow.addLine(to: CGPoint(x: strip.maxX - 8, y: arrowY))
        arrow.move(to: CGPoint(x: strip.maxX - 14, y: arrowY - 4))
        arrow.addLine(to: CGPoint(x: strip.maxX - 8, y: arrowY))
        arrow.addLine(to: CGPoint(x: strip.maxX - 14, y: arrowY + 4))
        context.stroke(arrow, with: .color(Theme.good), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        BenchInk.label(
            context,
            "\(Format.number(r.continuousAmps, digits: 1)) A cont · \(Format.number(r.pulseAmps, digits: 1)) A pulse",
            at: CGPoint(x: (strip.minX + strip.maxX) / 2, y: arrowY - 11),
            size: 11,
            weight: .bold,
            color: Theme.good
        )
    }
}
