import SwiftUI
import Charts
import BeckifyMath

// MARK: - Shared diagram helpers

struct EngineeringDiagramFrame<Content: View>: View {
    var summary: String
    @ViewBuilder var content: Content

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
    }
}

// MARK: - Voltage drop conductor run

struct VoltageDropDiagram: View {
    let supply: Double
    let drop: Double
    let receiving: Double
    let dropPercent: Double

    private var summary: String {
        "Conductor run from \(Format.volts(supply)) supply to \(Format.volts(receiving)) load. Drop \(Format.volts(drop)), \(Format.percent(dropPercent))."
    }

    var body: some View {
        DiagramCard(title: "Conductor run", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let y = h * 0.55
                    ZStack {
                        // Source node
                        Circle()
                            .stroke(Theme.accent, lineWidth: Theme.Stroke.emphasis)
                            .frame(width: 16, height: 16)
                            .position(x: 18, y: y)
                        // Load node
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Theme.energized, lineWidth: Theme.Stroke.emphasis)
                            .frame(width: 18, height: 18)
                            .position(x: w - 18, y: y)
                        // Declining potential polyline
                        Path { path in
                            path.move(to: CGPoint(x: 28, y: y))
                            path.addLine(to: CGPoint(x: w * 0.45, y: y - h * 0.12))
                            path.addLine(to: CGPoint(x: w - 28, y: y + h * 0.08))
                        }
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        Text(Format.volts(supply))
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                            .position(x: 40, y: y - 28)
                        Text("−\(Format.volts(drop))")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(dropPercent > 5 ? Theme.bad : (dropPercent > 3 ? Theme.warn : Theme.good))
                            .position(x: w * 0.5, y: y - 36)
                        Text(Format.volts(receiving))
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                            .position(x: w - 44, y: y - 28)
                    }
                }
            }
        }
    }

    static func model(from r: VoltageDropResult) -> VoltageDropDiagram? {
        guard r.dropVolts.isFinite, r.receivingVolts.isFinite else { return nil }
        // supply recovered from receiving + drop
        let supply = r.receivingVolts + r.dropVolts
        return VoltageDropDiagram(
            supply: supply,
            drop: r.dropVolts,
            receiving: r.receivingVolts,
            dropPercent: r.dropPercent
        )
    }
}

// MARK: - Power triangle

struct PowerTriangleDiagram: View {
    let kw: Double
    let kvar: Double
    let kva: Double
    var title: String = "Power triangle"

    private var summary: String {
        "Power triangle. True \(Format.number(kw, digits: 2)) kW, reactive \(Format.number(kvar, digits: 2)) kVAR, apparent \(Format.number(kva, digits: 2)) kVA."
    }

    private var hasFiniteLegs: Bool {
        kw.isFinite && kvar.isFinite && kva.isFinite && kva > 0
    }

    var body: some View {
        DiagramCard(title: title, accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let origin = CGPoint(x: w * 0.14, y: h * 0.82)
                    let maxLeg = min(w * 0.7, h * 0.7)
                    let scale = max(kva, 0.001)
                    let pLen = hasFiniteLegs ? CGFloat(kw / scale) * maxLeg : 0
                    let qLen = hasFiniteLegs ? CGFloat(abs(kvar) / scale) * maxLeg : 0
                    Path { path in
                        guard hasFiniteLegs else { return }
                        path.move(to: origin)
                        path.addLine(to: CGPoint(x: origin.x + pLen, y: origin.y))
                        path.addLine(to: CGPoint(x: origin.x + pLen, y: origin.y - qLen))
                        path.closeSubpath()
                    }
                    .stroke(Theme.accent, lineWidth: 2)
                    .background(
                        Path { path in
                            guard hasFiniteLegs else { return }
                            path.move(to: origin)
                            path.addLine(to: CGPoint(x: origin.x + pLen, y: origin.y))
                            path.addLine(to: CGPoint(x: origin.x + pLen, y: origin.y - qLen))
                            path.closeSubpath()
                        }
                        .fill(Theme.chartFill)
                    )
                    Text("kW")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .position(x: origin.x + pLen / 2, y: origin.y + 12)
                    Text("kVAR")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .position(x: origin.x + pLen + 22, y: origin.y - qLen / 2)
                    Text("kVA")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                        .position(x: origin.x + pLen / 2 - 8, y: origin.y - qLen / 2 - 8)
                }
            }
        }
    }
}

// MARK: - Reactance phasor

struct ReactancePhasorDiagram: View {
    let resistance: Double
    let netReactance: Double
    let impedance: Double
    let angleDegrees: Double

    private var summary: String {
        "Phasor diagram. R \(Format.number(resistance, digits: 2)) ohms, net X \(Format.number(netReactance, digits: 2)) ohms, Z \(Format.number(impedance, digits: 2)) ohms at \(Format.degrees(angleDegrees))."
    }

    var body: some View {
        DiagramCard(title: "Phasor", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    let c = CGPoint(x: geo.size.width * 0.2, y: geo.size.height * 0.7)
                    let scale = min(geo.size.width, geo.size.height) * 0.55 / max(impedance, 0.001)
                    let rx = CGFloat(resistance) * scale
                    let xy = CGFloat(netReactance) * scale
                    Path { path in
                        path.move(to: c)
                        path.addLine(to: CGPoint(x: c.x + rx, y: c.y))
                    }
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    Path { path in
                        path.move(to: CGPoint(x: c.x + rx, y: c.y))
                        path.addLine(to: CGPoint(x: c.x + rx, y: c.y - xy))
                    }
                    .stroke(Theme.energized, lineWidth: 2)
                    Path { path in
                        path.move(to: c)
                        path.addLine(to: CGPoint(x: c.x + rx, y: c.y - xy))
                    }
                    .stroke(Theme.accent2, lineWidth: 2.5)
                }
            }
        }
    }
}

// MARK: - Signal scaling transfer curve

struct SignalScalingChart: View {
    let rawMin: Double
    let rawMax: Double
    let euMin: Double
    let euMax: Double
    let rawValue: Double
    let engineeringValue: Double
    let curve: SignalCurve

    private var summary: String {
        "Transfer curve from raw \(Format.number(rawMin, digits: 2))–\(Format.number(rawMax, digits: 2)) to engineering \(Format.number(euMin, digits: 2))–\(Format.number(euMax, digits: 2)). Point at raw \(Format.number(rawValue, digits: 2)) maps to \(Format.number(engineeringValue, digits: 2))."
    }

    private var samples: [(raw: Double, eu: Double)] {
        let steps = 24
        return (0...steps).compactMap { step in
            let t = Double(step) / Double(steps)
            let raw = rawMin + (rawMax - rawMin) * t
            let span = rawMax - rawMin
            guard span != 0 else { return nil }
            let norm = (raw - rawMin) / span
            let shaped: Double
            switch curve {
            case .linear: shaped = norm
            case .squareRoot: shaped = max(0, norm).squareRoot()
            }
            let eu = euMin + shaped * (euMax - euMin)
            return (raw, eu)
        }
    }

    var body: some View {
        DiagramCard(title: "Transfer curve", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    LineMark(
                        x: .value("Raw", sample.raw),
                        y: .value("EU", sample.eu)
                    )
                    .foregroundStyle(Theme.chartPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                PointMark(
                    x: .value("Raw", rawValue),
                    y: .value("EU", engineeringValue)
                )
                .foregroundStyle(Theme.energized)
                .symbolSize(64)
            }
            .chartXAxisLabel("Raw")
            .chartYAxisLabel("EU")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Load factor demand profile

struct LoadFactorChart: View {
    let average: Double
    let peak: Double
    let capacity: Double

    private var summary: String {
        "Demand profile. Average \(Format.number(average, digits: 1)), peak \(Format.number(peak, digits: 1)), capacity \(Format.number(capacity, digits: 1))."
    }

    var body: some View {
        DiagramCard(title: "Demand profile", accessibilitySummary: summary) {
            Chart {
                BarMark(x: .value("Metric", "Avg"), y: .value("kW", average))
                    .foregroundStyle(Theme.chartPrimary)
                BarMark(x: .value("Metric", "Peak"), y: .value("kW", peak))
                    .foregroundStyle(Theme.chartSecondary)
                RuleMark(y: .value("Capacity", capacity))
                    .foregroundStyle(Theme.bad)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Capacity")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
            }
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Conduit fill packing

struct ConduitFillDiagram: View {
    let fillPercent: Double
    let limitPercent: Double
    let conductorCount: Int

    private var summary: String {
        "Conduit cross-section filled \(Format.percent(fillPercent)) of a \(Format.percent(limitPercent)) limit with \(conductorCount) conductors."
    }

    var body: some View {
        DiagramCard(title: "Raceway fill", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height) * 0.8
                    let origin = CGPoint(x: (geo.size.width - side) / 2, y: (geo.size.height - side) / 2)
                    let raceway = CGRect(x: origin.x, y: origin.y, width: side, height: side)
                    ZStack {
                        Circle()
                            .stroke(Theme.accent, lineWidth: 2)
                            .frame(width: side, height: side)
                            .position(x: raceway.midX, y: raceway.midY)
                        let count = max(1, min(conductorCount, 12))
                        ForEach(0..<count, id: \.self) { index in
                            let angle = Double(index) / Double(count) * 2 * Double.pi - Double.pi / 2
                            let radius = side * 0.28
                            let cx = raceway.midX + CGFloat(cos(angle)) * radius
                            let cy = raceway.midY + CGFloat(sin(angle)) * radius
                            let wire = side * 0.12
                            Circle()
                                .stroke(fillPercent > limitPercent ? Theme.bad : Theme.energized, lineWidth: 1.5)
                                .frame(width: wire, height: wire)
                                .position(x: cx, y: cy)
                        }
                        Text(Format.percent(fillPercent))
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(fillPercent > limitPercent ? Theme.bad : Theme.good)
                            .position(x: raceway.midX, y: raceway.midY)
                    }
                }
            }
        }
    }
}

// MARK: - 555 waveform sketch

struct Timer555WaveformDiagram: View {
    let frequency: Double
    let dutyPercent: Double

    private var summary: String {
        "Astable output waveform near \(Format.frequency(frequency)) with \(Format.percent(dutyPercent)) duty cycle."
    }

    var body: some View {
        DiagramCard(title: "Output waveform", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    let duty = min(max(dutyPercent / 100, 0.05), 0.95)
                    let w = geo.size.width
                    let high = geo.size.height * 0.25
                    let low = geo.size.height * 0.75
                    let period = w / 3
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: low))
                        for cycle in 0..<3 {
                            let x0 = CGFloat(cycle) * period
                            path.addLine(to: CGPoint(x: x0, y: low))
                            path.addLine(to: CGPoint(x: x0, y: high))
                            path.addLine(to: CGPoint(x: x0 + period * duty, y: high))
                            path.addLine(to: CGPoint(x: x0 + period * duty, y: low))
                            path.addLine(to: CGPoint(x: x0 + period, y: low))
                        }
                    }
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .miter))
                }
            }
        }
    }
}

// MARK: - Short-circuit emphasis

struct ShortCircuitDiagram: View {
    let faultAmps: Double

    private var summary: String {
        "Simplified transformer secondary fault path. Fault current \(Format.amps(faultAmps))."
    }

    var body: some View {
        DiagramCard(title: "Fault path", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.accent, lineWidth: 2)
                            .frame(width: 64, height: 40)
                            .overlay(Text("XFMR").font(.caption2.weight(.bold)).foregroundStyle(Theme.muted))
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Theme.bad)
                        VStack(spacing: 2) {
                            Text(Format.amps(faultAmps))
                                .font(.title3.monospacedDigit().weight(.bold))
                                .foregroundStyle(Theme.bad)
                            Text("Isc (infinite bus)")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Text("Design aid — verify with utility data and interrupting ratings.")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
