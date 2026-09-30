import SwiftUI
import BeckifyMath

struct ThreePhasePowerView: View {
    @EnvironmentObject private var jobs: JobStore
    @AppStorage(ToolboxPreferenceKey.electricalCode) private var codeRaw = ElectricalCode.nec.rawValue
    @StoredChoice(.threePhasePower, "topology", default: ThreePhaseTopology.wyeWye) private var topology
    @StoredInput(.threePhasePower, "vll", default: "480") private var vll
    @StoredInput(.threePhasePower, "r", default: "8") private var resistance
    @StoredInput(.threePhasePower, "x", default: "6") private var reactance
    @StoredInput(.threePhasePower, "rline", default: "0") private var lineResistance
    @StoredInput(.threePhasePower, "xline", default: "0") private var lineReactance
    @StoredInput(.threePhasePower, "jobName", default: "Three-phase") private var jobName
    @State private var session = ExplicitCalculationState<ThreePhasePowerResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var code: ElectricalCode { ElectricalCode(rawValue: codeRaw) ?? .nec }

    private var inputFingerprint: String {
        "\(code.rawValue)|\(topology)|\(vll)|\(resistance)|\(reactance)|\(lineResistance)|\(lineReactance)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .threePhasePower,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .threePhasePower,
                symbolic: ThreePhasePower.formula,
                substituted: substituted,
                meaning: "θ is the angle of the load phase impedance. A delta load is entered as connected, then solved as Z ÷ 3. Line ohms are one conductor in that phase."
            )
            MenuField(title: "Connection", selection: $topology, options: ThreePhaseTopology.allCases) { $0.title }
            NumberField(title: "Line voltage", unit: "V", text: $vll, fieldID: "vll", onSubmit: calculate)
            NumberField(title: "Phase resistance", unit: "Ω", text: $resistance, fieldID: "r", onSubmit: calculate)
            NumberField(title: "Phase reactance", unit: "Ω", text: $reactance, fieldID: "x", onSubmit: calculate)
            NumberField(title: "Line resistance", unit: "Ω", text: $lineResistance, fieldID: "rline", onSubmit: calculate)
            NumberField(title: "Line reactance", unit: "Ω", text: $lineReactance, fieldID: "xline", onSubmit: calculate)
            Text("X is ohms. Positive X lags. Frequency stays inside that number. Line R is one conductor.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(code.nominalSupply.note)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            ThreePhaseConnectionDiagram(topology: topology, result: freshResult)
            ThreePhaseArrowDiagram(topology: topology, result: freshResult)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: loadExample,
                exampleTitle: "\(Int(code.nominalSupply.threePhaseLineVolts)) V Y–Y, 8 + j6 Ω"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                results(r)
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    @ViewBuilder
    private func results(_ r: ThreePhasePowerResult) -> some View {
        let stale = session.isStale
        ResultCard(title: "Line and phase", copyText: copyText) {
            ResultRow(label: "Connection", value: r.topology.title, emphasis: true)
            ResultRow(label: "Source V_LL", value: Format.volts(r.sourceLineVolts))
            ResultRow(label: "Source Vφ", value: Format.volts(r.sourcePhaseVolts))
            ResultRow(label: "Source Iφ", value: Format.amps(r.sourcePhaseCurrent))
            ResultRow(label: "Load V_LL", value: Format.volts(r.loadLineVolts), emphasis: true)
            ResultRow(label: "Load Vφ", value: Format.volts(r.loadPhaseVolts))
            ResultRow(label: "I_L", value: Format.amps(r.lineCurrent), emphasis: true, tone: Theme.good)
            ResultRow(label: "Load Iφ", value: Format.amps(r.loadPhaseCurrent))
            ResultRow(
                label: "Neutral",
                value: r.topology.neutralPresent ? "\(Format.amps(r.neutralAmps)) balanced" : "No neutral"
            )
        }
        .opacity(stale ? 0.72 : 1)

        PowerTriangleDiagram(
            kw: r.watts / 1000,
            kvar: r.vars / 1000,
            kva: r.voltAmps / 1000,
            title: triangleTitle(r)
        )
        .opacity(stale ? 0.72 : 1)

        ResultCard(title: "Complex power", copyText: copyText) {
            ResultRow(label: "P", value: Format.watts(r.watts), emphasis: true, tone: Theme.good)
            ResultRow(label: "Q", value: "\(Format.number(r.vars, digits: 2)) VAR", emphasis: true)
            ResultRow(label: "|S|", value: "\(Format.number(r.voltAmps, digits: 2)) VA", emphasis: true)
            ResultRow(label: "S", value: complexPower(r))
            ResultRow(label: "PF", value: "\(Format.percent(r.powerFactor * 100)) \(r.lagging ? "lagging" : "leading")")
            ResultRow(label: "θ", value: Format.degrees(r.phaseAngleDegrees))
            ResultRow(label: "Line loss", value: Format.watts(r.lineLossWatts))
            ResultRow(label: "Source P", value: Format.watts(r.sourceWatts))
        }
        .opacity(stale ? 0.72 : 1)

        ResultCard(title: "One phase") {
            ResultRow(label: "Z_Y", value: ohms(r.equivalentWye))
            ResultRow(label: "Z_line", value: ohms(r.line))
            Text(r.reading)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Text("Three equal phases sum to a steady P. A single phase still pulses.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(stale ? 0.72 : 1)

        SaveJobBar(jobName: $jobName, canSave: !stale) {
            jobs.save(SavedJob(
                name: jobName,
                toolID: .threePhasePower,
                inputs: [
                    "topology": topology.title,
                    "Vll": vll,
                    "R": resistance,
                    "X": reactance,
                ],
                outputs: [
                    "P": Format.watts(r.watts),
                    "S": "\(Format.number(r.voltAmps, digits: 1)) VA",
                    "IL": Format.amps(r.lineCurrent),
                ]
            ))
        }
    }

    private func triangleTitle(_ r: ThreePhasePowerResult) -> String {
        if abs(r.powerFactor - 1) < 0.000_5 { return "Power triangle · unity" }
        return r.lagging ? "Power triangle · lagging" : "Power triangle · leading"
    }

    private func complexPower(_ r: ThreePhasePowerResult) -> String {
        let sign = r.vars < 0 ? "−" : "+"
        return "\(Format.number(r.watts, digits: 1)) \(sign) j\(Format.number(abs(r.vars), digits: 1)) VA"
    }

    private func loadExample() {
        topology = .wyeWye
        vll = String(Int(code.nominalSupply.threePhaseLineVolts))
        resistance = "8"
        reactance = "6"
        lineResistance = "0"
        lineReactance = "0"
        session.prepareForNewInputs()
    }

    private func calculate() {
        session.calculate {
            try ThreePhasePower.solve(
                topology: topology,
                lineToLineVolts: vll.parsedDouble ?? .nan,
                load: ComplexOhms(
                    resistance: resistance.parsedDouble ?? .nan,
                    reactance: reactance.parsedDouble ?? .nan
                ),
                line: ComplexOhms(
                    resistance: lineResistance.parsedDouble ?? .nan,
                    reactance: lineReactance.parsedDouble ?? .nan
                )
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        vll = ""
        resistance = ""
        reactance = ""
        lineResistance = "0"
        lineReactance = "0"
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  P \(Format.watts(r.watts))  ·  |S| \(Format.number(r.voltAmps, digits: 1)) VA"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.topology.title)  ·  \(Format.watts(r.watts))  ·  \(Format.amps(r.lineCurrent))"
    }

    private var copyText: String? { sticky }

    private var freshResult: ThreePhasePowerResult? {
        session.isStale ? nil : session.displayedResult
    }
}

private func ohms(_ z: ComplexOhms) -> String {
    let sign = z.reactance < 0 ? "−" : "+"
    return "\(Format.number(z.resistance, digits: 3)) \(sign) j\(Format.number(abs(z.reactance), digits: 3)) Ω"
}

// MARK: - Connection

private struct ThreePhaseConnectionDiagram: View {
    var topology: ThreePhaseTopology
    var result: ThreePhasePowerResult?

    private var summary: String {
        var parts = [
            "\(topology.title) connection. Source \(topology.sourceIsWye ? "wye" : "delta"), load \(topology.loadIsWye ? "wye" : "delta").",
            topology.sourceIsWye ? "Source V_LL = √3 Vφ and I_L = Iφ." : "Source V_LL = Vφ and I_L = √3 Iφ.",
            topology.loadIsWye ? "Load V_LL = √3 Vφ and I_L = Iφ." : "Load V_LL = Vφ and I_L = √3 Iφ.",
        ]
        if let result {
            parts.append("Load line \(Format.volts(result.loadLineVolts)), line current \(Format.amps(result.lineCurrent)).")
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        DiagramCard(title: "\(topology.title) connection", accessibilitySummary: summary, exportName: "three-phase-connection") {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    draw(context: context, size: size)
                }
                .frame(height: 210)
                .accessibilityHidden(true)
                Text(sideLine(source: true))
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(sideLine(source: false))
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(topology.reading)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sideLine(source: Bool) -> String {
        let wye = source ? topology.sourceIsWye : topology.loadIsWye
        let name = source ? "Source" : "Load"
        let ratioV = wye ? "V_LL = √3 Vφ" : "V_LL = Vφ"
        let ratioI = wye ? "I_L = Iφ" : "I_L = √3 Iφ"
        guard let result else { return "\(name). \(ratioV). \(ratioI)." }
        let volts = source ? result.sourceLineVolts : result.loadLineVolts
        let phase = source ? result.sourcePhaseVolts : result.loadPhaseVolts
        let iPhase = source ? result.sourcePhaseCurrent : result.loadPhaseCurrent
        return "\(name). \(ratioV) — \(Format.volts(volts)) / \(Format.volts(phase)). \(ratioI) — \(Format.amps(result.lineCurrent)) / \(Format.amps(iPhase))."
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let source = CGRect(x: 8, y: 16, width: size.width * 0.32, height: size.height - 28)
        let load = CGRect(x: size.width * 0.68 - 8, y: 16, width: size.width * 0.32, height: size.height - 28)
        frame(context, source, "Source")
        frame(context, load, "Load")
        bank(context, source, wye: topology.sourceIsWye, accent: Theme.accent)
        bank(context, load, wye: topology.loadIsWye, accent: Theme.energized)
        lines(context, from: source.maxX, to: load.minX, top: source.minY, height: source.height)
    }

    private func frame(_ context: GraphicsContext, _ rect: CGRect, _ title: String) {
        context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(Theme.border), lineWidth: 1)
        context.draw(
            Text(title).font(.caption2).foregroundColor(Theme.muted),
            at: CGPoint(x: rect.minX + 28, y: rect.minY + 12)
        )
    }

    private func bank(_ context: GraphicsContext, _ rect: CGRect, wye: Bool, accent: Color) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        if wye {
            let n = p(0.50, 0.58)
            stroke(context, n, p(0.50, 0.30), accent)
            stroke(context, n, p(0.24, 0.82), accent)
            stroke(context, n, p(0.76, 0.82), accent)
            dot(context, n, Theme.foreground)
            context.draw(Text("N").font(.caption2).foregroundColor(Theme.muted), at: CGPoint(x: n.x + 10, y: n.y + 2), anchor: .leading)
        } else {
            stroke(context, p(0.22, 0.32), p(0.78, 0.32), accent)
            stroke(context, p(0.78, 0.32), p(0.50, 0.82), accent)
            stroke(context, p(0.50, 0.82), p(0.22, 0.32), accent)
        }
        context.draw(
            Text(wye ? "Y" : "Δ").font(.caption.weight(.semibold)).foregroundColor(accent),
            at: p(0.50, 0.16)
        )
    }

    private func lines(_ context: GraphicsContext, from: CGFloat, to: CGFloat, top: CGFloat, height: CGFloat) {
        let xs = from + 10
        let xe = to - 10
        guard xe > xs + 8 else { return }
        let currents = [0.34, 0.56, 0.78]
        for (index, frac) in currents.enumerated() {
            let y = top + height * frac
            let start = CGPoint(x: xs, y: y)
            let end = CGPoint(x: xe, y: y)
            arrow(context, start, end, Theme.energized, head: index == 1)
        }
        let label = result.map { "I_L  \(Format.amps($0.lineCurrent))" } ?? "I_L"
        context.draw(
            Text(label).font(.caption2.weight(.semibold)).foregroundColor(Theme.energized),
            at: CGPoint(x: (xs + xe) / 2, y: top + height * 0.34 - 12)
        )
    }

    private func stroke(_ context: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ color: Color) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }

    private func dot(_ context: GraphicsContext, _ point: CGPoint, _ color: Color) {
        let mark = Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
        context.fill(mark, with: .color(color))
    }

    private func arrow(_ context: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ color: Color, head: Bool) {
        stroke(context, a, b, color)
        guard head else { return }
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        var tip = Path()
        tip.move(to: CGPoint(x: mid.x - 7, y: mid.y - 5))
        tip.addLine(to: CGPoint(x: mid.x + 1, y: mid.y))
        tip.addLine(to: CGPoint(x: mid.x - 7, y: mid.y + 5))
        context.stroke(tip, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Line and phase arrows

private struct ThreePhaseArrowDiagram: View {
    var topology: ThreePhaseTopology
    var result: ThreePhasePowerResult?

    private var split: Bool {
        topology.sourceIsWye != topology.loadIsWye
    }

    private var summary: String {
        var line = "Line and phase arrows for \(topology.title)."
        if let result {
            line += " Load Vφ \(Format.volts(result.loadPhaseVolts)), V_LL \(Format.volts(result.loadLineVolts)), Iφ \(Format.amps(result.loadPhaseCurrent)), I_L \(Format.amps(result.lineCurrent))."
        } else if topology.loadIsWye {
            line += " Wye voltage line leads phase by 30° and is √3 times longer. Currents match."
        } else {
            line += " Delta voltage line and phase match. Line current is √3 times phase current and lags 30°."
        }
        return line
    }

    var body: some View {
        DiagramCard(title: "Line and phase", accessibilitySummary: summary, exportName: "three-phase-arrows") {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    draw(context: context, size: size)
                }
                .frame(height: split ? 250 : 168)
                .accessibilityHidden(true)
                Text(caption)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var caption: String {
        if split {
            return "Top is the source. Bottom is the load. Copper arrows are voltage. Teal arrows are current."
        }
        return "Source and load use the same ratios. Copper arrows are voltage. Teal arrows are current."
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        if split {
            band(
                context,
                CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.5),
                title: "Source",
                wye: topology.sourceIsWye,
                phaseVolts: result?.sourcePhaseVolts,
                lineVolts: result?.sourceLineVolts,
                phaseAmps: result?.sourcePhaseCurrent,
                lineAmps: result?.lineCurrent
            )
            band(
                context,
                CGRect(x: 0, y: size.height * 0.5, width: size.width, height: size.height * 0.5),
                title: "Load",
                wye: topology.loadIsWye,
                phaseVolts: result?.loadPhaseVolts,
                lineVolts: result?.loadLineVolts,
                phaseAmps: result?.loadPhaseCurrent,
                lineAmps: result?.lineCurrent
            )
        } else {
            band(
                context,
                CGRect(x: 0, y: 0, width: size.width, height: size.height),
                title: "Source and load",
                wye: topology.loadIsWye,
                phaseVolts: result?.loadPhaseVolts,
                lineVolts: result?.loadLineVolts,
                phaseAmps: result?.loadPhaseCurrent,
                lineAmps: result?.lineCurrent
            )
        }
    }

    private func band(
        _ context: GraphicsContext,
        _ rect: CGRect,
        title: String,
        wye: Bool,
        phaseVolts: Double?,
        lineVolts: Double?,
        phaseAmps: Double?,
        lineAmps: Double?
    ) {
        context.draw(
            Text(title).font(.caption2).foregroundColor(Theme.muted),
            at: CGPoint(x: rect.minX + 36, y: rect.minY + 10)
        )
        let left = CGRect(x: rect.minX, y: rect.minY + 8, width: rect.width * 0.5, height: rect.height - 8)
        let right = CGRect(x: rect.midX, y: rect.minY + 8, width: rect.width * 0.5, height: rect.height - 8)
        let vPhase = phaseVolts ?? (wye ? 1 : 1)
        let vLine = lineVolts ?? (wye ? 3.0.squareRoot() : 1)
        let iPhase = phaseAmps ?? 1
        let iLine = lineAmps ?? (wye ? 1 : 3.0.squareRoot())
        arrows(
            context,
            left,
            phase: vPhase,
            line: vLine,
            lead: wye ? 30 : 0,
            phaseName: phaseVolts.map { "Vφ \(Format.number($0, digits: 0))" } ?? "Vφ",
            lineName: lineVolts.map { "V_LL \(Format.number($0, digits: 0))" } ?? (wye ? "V_LL √3" : "V_LL"),
            phaseColor: Theme.energized.opacity(0.85),
            lineColor: Theme.energized
        )
        arrows(
            context,
            right,
            phase: iPhase,
            line: iLine,
            lead: wye ? 0 : -30,
            phaseName: phaseAmps.map { "Iφ \(Format.number($0, digits: 1))" } ?? "Iφ",
            lineName: lineAmps.map { "I_L \(Format.number($0, digits: 1))" } ?? (wye ? "I_L" : "I_L √3"),
            phaseColor: Theme.accent.opacity(0.85),
            lineColor: Theme.accent
        )
    }

    private func arrows(
        _ context: GraphicsContext,
        _ rect: CGRect,
        phase: Double,
        line: Double,
        lead: Double,
        phaseName: String,
        lineName: String,
        phaseColor: Color,
        lineColor: Color
    ) {
        let origin = CGPoint(x: rect.minX + 28, y: rect.maxY - 22)
        let room = min(rect.width * 0.42, rect.height * 0.62)
        let peak = max(phase, line, 0.001)
        let same = abs(phase - line) / peak < 0.04 && abs(lead) < 1
        if same {
            let end = CGPoint(x: origin.x + room, y: origin.y)
            shaft(context, origin, end, lineColor)
            context.draw(
                Text(lineName).font(.caption2.weight(.semibold)).foregroundColor(lineColor),
                at: CGPoint(x: origin.x + room * 0.55, y: origin.y - 14)
            )
            return
        }
        let phaseEnd = CGPoint(x: origin.x + CGFloat(phase / peak) * room, y: origin.y)
        let rad = lead * .pi / 180
        let lineEnd = CGPoint(
            x: origin.x + CGFloat(cos(rad) * line / peak) * room,
            y: origin.y - CGFloat(sin(rad) * line / peak) * room
        )
        shaft(context, origin, phaseEnd, phaseColor)
        shaft(context, origin, lineEnd, lineColor)
        context.draw(Text(phaseName).font(.caption2).foregroundColor(phaseColor), at: CGPoint(x: phaseEnd.x, y: phaseEnd.y + 12), anchor: .top)
        context.draw(Text(lineName).font(.caption2.weight(.semibold)).foregroundColor(lineColor), at: CGPoint(x: lineEnd.x + 4, y: lineEnd.y - 8), anchor: .bottomLeading)
    }

    private func shaft(_ context: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ color: Color) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        let angle = atan2(b.y - a.y, b.x - a.x)
        let head: CGFloat = 7
        var tip = Path()
        tip.move(to: b)
        tip.addLine(to: CGPoint(x: b.x - head * cos(angle - 0.45), y: b.y - head * sin(angle - 0.45)))
        tip.move(to: b)
        tip.addLine(to: CGPoint(x: b.x - head * cos(angle + 0.45), y: b.y - head * sin(angle + 0.45)))
        context.stroke(tip, with: .color(color), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
    }
}
