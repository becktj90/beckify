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

/// Point geometry for the conductor run, resolved in `Double` space so the
/// view builders below stay free of `Double`/`CGFloat` mixing.
private struct VoltageDropLayout {
    let width: CGFloat
    let axisY: CGFloat
    let sagY: CGFloat
    let loadY: CGFloat

    init(size: CGSize) {
        let w: Double = Double(size.width)
        let h: Double = Double(size.height)
        let y: Double = h * 0.55

        width = CGFloat(w)
        axisY = CGFloat(y)
        sagY = CGFloat(y - h * 0.12)
        loadY = CGFloat(y + h * 0.08)
    }

    var runPath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 28, y: axisY))
        path.addLine(to: CGPoint(x: width * 0.45, y: sagY))
        path.addLine(to: CGPoint(x: width - 28, y: loadY))
        return path
    }
}

struct VoltageDropDiagram: View {
    let supply: Double
    let drop: Double
    let receiving: Double
    let dropPercent: Double

    private var summary: String {
        "Conductor run from \(Format.volts(supply)) supply to \(Format.volts(receiving)) load. Drop \(Format.volts(drop)), \(Format.percent(dropPercent))."
    }

    private var dropTone: Color {
        if dropPercent > 5 { return Theme.bad }
        if dropPercent > 3 { return Theme.warn }
        return Theme.good
    }

    var body: some View {
        DiagramCard(title: "Conductor run", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    conductorRun(VoltageDropLayout(size: geo.size))
                }
            }
        }
    }

    @ViewBuilder
    private func conductorRun(_ layout: VoltageDropLayout) -> some View {
        ZStack {
            // Source node
            Circle()
                .stroke(Theme.accent, lineWidth: Theme.Stroke.emphasis)
                .frame(width: 16, height: 16)
                .position(x: 18, y: layout.axisY)
            // Load node
            RoundedRectangle(cornerRadius: 3)
                .stroke(Theme.energized, lineWidth: Theme.Stroke.emphasis)
                .frame(width: 18, height: 18)
                .position(x: layout.width - 18, y: layout.axisY)
            // Declining potential polyline
            layout.runPath
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            potentialLabels(layout)
        }
    }

    @ViewBuilder
    private func potentialLabels(_ layout: VoltageDropLayout) -> some View {
        label(Format.volts(supply), tone: Theme.foreground)
            .position(x: 40, y: layout.axisY - 28)
        label("−\(Format.volts(drop))", tone: dropTone)
            .position(x: layout.width * 0.5, y: layout.axisY - 36)
        label(Format.volts(receiving), tone: Theme.foreground)
            .position(x: layout.width - 44, y: layout.axisY - 28)
    }

    private func label(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(tone)
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

/// Leg lengths in points plus the shared triangle path, so the stroke and its
/// fill reuse one path instead of rebuilding the same expression twice.
private struct PowerTriangleLayout {
    let origin: CGPoint
    let realLeg: CGFloat
    let reactiveLeg: CGFloat
    let isDrawable: Bool

    init(size: CGSize, kw: Double, kvar: Double, kva: Double) {
        let w: Double = Double(size.width)
        let h: Double = Double(size.height)
        let drawable: Bool = kw.isFinite && kvar.isFinite && kva.isFinite && kva > 0
        let maxLeg: Double = min(w * 0.7, h * 0.7)
        let scale: Double = max(kva, 0.001)

        origin = CGPoint(x: CGFloat(w * 0.14), y: CGFloat(h * 0.82))
        realLeg = drawable ? CGFloat(kw / scale * maxLeg) : 0
        reactiveLeg = drawable ? CGFloat(abs(kvar) / scale * maxLeg) : 0
        isDrawable = drawable
    }

    var trianglePath: Path {
        var path = Path()
        guard isDrawable else { return path }
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x + realLeg, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + realLeg, y: origin.y - reactiveLeg))
        path.closeSubpath()
        return path
    }
}

struct PowerTriangleDiagram: View {
    let kw: Double
    let kvar: Double
    let kva: Double
    var title: String = "Power triangle"

    private var summary: String {
        "Power triangle. True \(Format.number(kw, digits: 2)) kW, reactive \(Format.number(kvar, digits: 2)) kVAR, apparent \(Format.number(kva, digits: 2)) kVA."
    }

    var body: some View {
        DiagramCard(title: title, accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    triangle(PowerTriangleLayout(size: geo.size, kw: kw, kvar: kvar, kva: kva))
                }
            }
        }
    }

    @ViewBuilder
    private func triangle(_ layout: PowerTriangleLayout) -> some View {
        layout.trianglePath
            .stroke(Theme.accent, lineWidth: 2)
            .background(layout.trianglePath.fill(Theme.chartFill))

        legLabels(layout)
    }

    @ViewBuilder
    private func legLabels(_ layout: PowerTriangleLayout) -> some View {
        let origin: CGPoint = layout.origin
        let p: CGFloat = layout.realLeg
        let q: CGFloat = layout.reactiveLeg

        Text("kW")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
            .position(x: origin.x + p / 2, y: origin.y + 12)
        Text("kVAR")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
            .position(x: origin.x + p + 22, y: origin.y - q / 2)
        Text("kVA")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.accent2)
            .position(x: origin.x + p / 2 - 8, y: origin.y - q / 2 - 8)
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

/// Raceway bore plus the conductor ring positions, so the per-conductor
/// trigonometry no longer type-checks alongside the enclosing `ZStack`.
private struct ConduitFillLayout {
    let center: CGPoint
    let bore: CGFloat
    let conductorCount: Int
    let conductorDiameter: CGFloat
    let ringRadius: CGFloat

    init(size: CGSize, conductorCount: Int) {
        let side: Double = min(Double(size.width), Double(size.height)) * 0.8
        let originX: Double = (Double(size.width) - side) / 2
        let originY: Double = (Double(size.height) - side) / 2

        center = CGPoint(x: CGFloat(originX + side / 2), y: CGFloat(originY + side / 2))
        bore = CGFloat(side)
        self.conductorCount = max(1, min(conductorCount, 12))
        conductorDiameter = CGFloat(side * 0.12)
        ringRadius = CGFloat(side * 0.28)
    }

    func conductorCenter(_ index: Int) -> CGPoint {
        let angle: Double = Double(index) / Double(conductorCount) * 2 * Double.pi - Double.pi / 2
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * ringRadius,
            y: center.y + CGFloat(sin(angle)) * ringRadius
        )
    }
}

struct ConduitFillDiagram: View {
    let fillPercent: Double
    let limitPercent: Double
    let conductorCount: Int

    private var summary: String {
        "Conduit cross-section filled \(Format.percent(fillPercent)) of a \(Format.percent(limitPercent)) limit with \(conductorCount) conductors."
    }

    private var isOverLimit: Bool { fillPercent > limitPercent }

    var body: some View {
        DiagramCard(title: "Raceway fill", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    crossSection(ConduitFillLayout(size: geo.size, conductorCount: conductorCount))
                }
            }
        }
    }

    @ViewBuilder
    private func crossSection(_ layout: ConduitFillLayout) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.accent, lineWidth: 2)
                .frame(width: layout.bore, height: layout.bore)
                .position(layout.center)

            conductors(layout)

            Text(Format.percent(fillPercent))
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(isOverLimit ? Theme.bad : Theme.good)
                .position(layout.center)
        }
    }

    private func conductors(_ layout: ConduitFillLayout) -> some View {
        ForEach(0..<layout.conductorCount, id: \.self) { index in
            Circle()
                .stroke(isOverLimit ? Theme.bad : Theme.energized, lineWidth: 1.5)
                .frame(width: layout.conductorDiameter, height: layout.conductorDiameter)
                .position(layout.conductorCenter(index))
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

// MARK: - Motor torque-speed curve

struct MotorTorqueCurveChart: View {
    let horsepower: Double
    let ratedRPM: Double
    let ratedTorqueLbFt: Double

    private var points: [(rpm: Double, torqueLbFt: Double)] {
        MotorTorque.curve(horsepower: horsepower, minRPM: max(200, ratedRPM * 0.3), maxRPM: ratedRPM * 2.2)
    }

    private var summary: String {
        "Constant \(Format.number(horsepower, digits: 1)) horsepower torque curve. Rated point \(Format.number(ratedTorqueLbFt, digits: 2)) pound-feet at \(Format.number(ratedRPM, digits: 0)) RPM."
    }

    var body: some View {
        DiagramCard(title: "Torque vs. speed", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("RPM", point.rpm), y: .value("Torque", point.torqueLbFt))
                        .foregroundStyle(Theme.chartPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                PointMark(x: .value("RPM", ratedRPM), y: .value("Torque", ratedTorqueLbFt))
                    .foregroundStyle(Theme.energized)
                    .symbolSize(64)
            }
            .chartXAxisLabel("RPM")
            .chartYAxisLabel("lb·ft")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - RF path loss vs. distance

struct PathLossDistanceChart: View {
    let frequencyMHz: Double
    let currentDistance: Double
    let currentLossDB: Double

    private var points: [(distance: Double, lossDB: Double)] {
        FreeSpacePathLoss.distanceSweep(
            frequencyMHz: frequencyMHz,
            minMetres: max(1, currentDistance * 0.05),
            maxMetres: max(currentDistance * 4, 10)
        )
    }

    private var summary: String {
        "Free-space path loss versus distance at \(Format.number(frequencyMHz, digits: 0)) megahertz. Current point \(Format.number(currentDistance, digits: 1)) metres, \(Format.number(currentLossDB, digits: 1)) decibels."
    }

    var body: some View {
        DiagramCard(title: "Loss vs. distance", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Distance", point.distance), y: .value("Loss", point.lossDB))
                        .foregroundStyle(Theme.chartPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                PointMark(x: .value("Distance", currentDistance), y: .value("Loss", currentLossDB))
                    .foregroundStyle(Theme.energized)
                    .symbolSize(64)
            }
            .chartXScale(type: .log)
            .chartXAxisLabel("Distance (m, log)")
            .chartYAxisLabel("dB")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Phasor plot

struct PhasorPolarDiagram: View {
    let phasors: [Phasor]
    let resultantMagnitude: Double
    let resultantAngleDegrees: Double

    private var maxMagnitude: Double {
        max(phasors.map(\.magnitude).max() ?? 1, resultantMagnitude, 1)
    }

    private var summary: String {
        "Phasor diagram with \(phasors.count) inputs. Resultant \(Format.number(resultantMagnitude, digits: 2)) at \(Format.number(resultantAngleDegrees, digits: 1)) degrees."
    }

    private static let palette: [Color] = [Theme.chartPrimary, Theme.chartSecondary, Theme.chartTertiary]

    var body: some View {
        DiagramCard(title: "Phasor plot", accessibilitySummary: summary) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 * 0.82
                let scale = radius / CGFloat(maxMagnitude)

                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(Theme.chartGrid),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )

                for (index, phasor) in phasors.enumerated() {
                    let rad = phasor.angleDegrees * .pi / 180
                    let length = CGFloat(phasor.magnitude) * scale
                    let tip = CGPoint(x: center.x + cos(rad) * length, y: center.y - sin(rad) * length)
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: tip)
                    let color = Self.palette[index % Self.palette.count]
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    context.fill(
                        Path(ellipseIn: CGRect(x: tip.x - 3, y: tip.y - 3, width: 6, height: 6)),
                        with: .color(color)
                    )
                }

                guard resultantMagnitude > 0 else { return }
                let rad = resultantAngleDegrees * .pi / 180
                let length = CGFloat(resultantMagnitude) * scale
                let tip = CGPoint(x: center.x + cos(rad) * length, y: center.y - sin(rad) * length)
                var resultantPath = Path()
                resultantPath.move(to: center)
                resultantPath.addLine(to: tip)
                context.stroke(resultantPath, with: .color(Theme.bad), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3]))
            }
            .frame(height: 180)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - RC/RL transient response curve

struct TransientResponseChart: View {
    let curve: [(time: Double, value: Double)]
    let currentTime: Double
    let currentValue: Double
    let unit: String
    var timeConstant: Double? = nil

    private var summary: String {
        "Step response curve. At \(Format.number(currentTime, digits: 3)) s, value is \(Format.number(currentValue, digits: 3)) \(unit)."
    }

    private var points: [PlotPoint] {
        curve.map { PlotPoint(x: $0.time, y: $0.value) }
    }

    var body: some View {
        DiagramCard(title: "Response curve", accessibilitySummary: summary, exportName: "transient-response") {
            EngineerLinePlot(
                series: [EngineerSeries(name: unit, points: points, color: Theme.chartPrimary, fills: true)],
                xLabel: "Time (s)",
                yLabel: unit,
                markers: [
                    EngineerMarker(x: currentTime, y: currentValue, label: "t", color: Theme.energized),
                ],
                xGuides: timeConstant.map { [EngineerGuide(value: $0, label: "τ", axis: .x)] } ?? []
            )
        }
    }
}

// MARK: - Diode forward I-V curve

struct DiodeIVChart: View {
    let curve: [(voltage: Double, current: Double)]
    let operatingVoltage: Double
    let operatingCurrent: Double

    private var summary: String {
        "Forward I-V curve. Operating point \(Format.number(operatingVoltage, digits: 3)) V, \(Format.number(operatingCurrent * 1000, digits: 3)) mA."
    }

    private var points: [PlotPoint] {
        curve.map { PlotPoint(x: $0.voltage, y: $0.current * 1000) }
    }

    var body: some View {
        DiagramCard(title: "Forward I-V curve", accessibilitySummary: summary, exportName: "diode-iv") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "I_f", points: points, color: Theme.chartPrimary, fills: false)],
                xLabel: "V (V)",
                yLabel: "I (mA)",
                markers: [
                    EngineerMarker(
                        x: operatingVoltage,
                        y: operatingCurrent * 1000,
                        label: "Q",
                        color: Theme.energized
                    ),
                ]
            )
        }
    }
}

// MARK: - Battery bank usable capacity

struct BatteryBankChart: View {
    let usableWattHours: Double
    let totalWattHours: Double
    let runtimeHours: Double

    private var summary: String {
        "Usable \(Format.number(usableWattHours, digits: 0)) watt-hours of \(Format.number(totalWattHours, digits: 0)) total. Runtime \(Format.number(runtimeHours, digits: 2)) hours."
    }

    var body: some View {
        DiagramCard(title: "Usable capacity", accessibilitySummary: summary, exportName: "battery-bank") {
            Chart {
                BarMark(x: .value("Metric", "Total"), y: .value("Wh", totalWattHours))
                    .foregroundStyle(Theme.chartGrid)
                BarMark(x: .value("Metric", "Usable"), y: .value("Wh", usableWattHours))
                    .foregroundStyle(Theme.chartPrimary)
            }
            .chartYAxisLabel("Wh")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Ampacity derating waterfall

struct AmpacityWaterfallDiagram: View {
    let steps: [CalculationTraceStep]

    private var summary: String {
        let parts = steps.map { "\($0.title) \($0.displayValue)" }
        return "Ampacity calculation stages: " + parts.joined(separator: ", then ")
    }

    var body: some View {
        DiagramCard(title: "Ampacity waterfall", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 18, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.foreground)
                                if let note = step.note {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            Spacer(minLength: 8)
                            Text(step.displayValue)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(index == steps.count - 1 ? Theme.good : Theme.foreground)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(step.title): \(step.displayValue). \(step.note ?? "")")

                        if index < steps.count - 1 {
                            Image(systemName: "arrow.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.muted)
                                .padding(.leading, 4)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Shared engineer XY plot (Swift Charts — Charty-class craft)

struct EngineerSeries: Identifiable {
    var id: String { name }
    var name: String
    var points: [PlotPoint]
    var color: Color
    var fills: Bool = false
}

struct EngineerMarker: Identifiable {
    var id: String { "\(label)-\(x)-\(y)" }
    var x: Double
    var y: Double
    var label: String
    var color: Color
}

struct EngineerGuide: Identifiable {
    enum Axis { case x, y }
    var id: String { "\(label)-\(value)-\(axis)" }
    var value: Double
    var label: String
    var axis: Axis
}

/// Multi-series XY plot with grid, units, markers, and τ-style guides —
/// detailed enough for lab notes, exportable via the parent `DiagramCard`.
struct EngineerLinePlot: View {
    var series: [EngineerSeries]
    var xLabel: String
    var yLabel: String
    var markers: [EngineerMarker] = []
    var xGuides: [EngineerGuide] = []
    var yGuides: [EngineerGuide] = []
    var logX: Bool = false
    var height: CGFloat = 200

    var body: some View {
        let chart = Chart {
            ForEach(series) { s in
                ForEach(Array(s.points.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value(xLabel, point.x),
                        y: .value(yLabel, point.y),
                        series: .value("Series", s.name)
                    )
                    .foregroundStyle(by: .value("Series", s.name))
                    .lineStyle(StrokeStyle(lineWidth: 2.25, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    if s.fills {
                        AreaMark(
                            x: .value(xLabel, point.x),
                            y: .value(yLabel, point.y),
                            series: .value("Series", s.name)
                        )
                        .foregroundStyle(by: .value("Series", s.name))
                        .opacity(0.14)
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            ForEach(markers) { mark in
                PointMark(x: .value(xLabel, mark.x), y: .value(yLabel, mark.y))
                    .foregroundStyle(mark.color)
                    .symbolSize(72)
                    .annotation(position: .top, spacing: 4) {
                        Text(mark.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(mark.color)
                    }
            }
            ForEach(xGuides) { guide in
                RuleMark(x: .value(guide.label, guide.value))
                    .foregroundStyle(Theme.muted.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(guide.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
            }
            ForEach(yGuides) { guide in
                RuleMark(y: .value(guide.label, guide.value))
                    .foregroundStyle(Theme.muted.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(guide.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
            }
        }
        .chartForegroundStyleScale(
            domain: series.map(\.name),
            range: series.map(\.color)
        )
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.chartGrid)
                AxisTick()
                AxisValueLabel(format: floatingFormat)
                    .font(.caption2.monospacedDigit())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.chartGrid)
                AxisTick()
                AxisValueLabel(format: floatingFormat)
                    .font(.caption2.monospacedDigit())
            }
        }
        .chartXAxisLabel(xLabel, position: .bottom, alignment: .center)
        .chartYAxisLabel(yLabel, position: .leading, alignment: .center)
        .chartLegend(series.count > 1 ? .visible : .hidden)
        .frame(height: height)
        .accessibilityHidden(true)

        if logX {
            chart.chartXScale(type: .log)
        } else {
            chart
        }
    }

    private var floatingFormat: FloatingPointFormatStyle<Double> {
        .number.precision(.significantDigits(1...4))
    }
}

// MARK: - RC charge / discharge (LED·RC tool)

struct RCChargeDischargeChart: View {
    let tau: Double
    var finalValue: Double = 1

    private var charge: [PlotPoint] { PlotSampling.rcCharge(tau: tau, finalValue: finalValue) }
    private var discharge: [PlotPoint] { PlotSampling.rcDischarge(tau: tau, initialValue: finalValue) }

    private var summary: String {
        "RC charge and discharge over 5τ. τ = \(Format.time(tau)). At one τ the capacitor is ~63% charged or discharged."
    }

    var body: some View {
        DiagramCard(title: "Charge / discharge", accessibilitySummary: summary, exportName: "rc-charge-discharge") {
            EngineerLinePlot(
                series: [
                    EngineerSeries(name: "Charge", points: charge, color: Theme.chartPrimary, fills: true),
                    EngineerSeries(name: "Discharge", points: discharge, color: Theme.chartSecondary, fills: false),
                ],
                xLabel: "Time (s)",
                yLabel: "v / V",
                markers: [
                    EngineerMarker(
                        x: tau,
                        y: finalValue * (1 - exp(-1)),
                        label: "0.63 V",
                        color: Theme.energized
                    ),
                ],
                xGuides: [
                    EngineerGuide(value: tau, label: "τ", axis: .x),
                    EngineerGuide(value: 5 * tau, label: "5τ", axis: .x),
                ],
                height: 220
            )
        }
    }
}

// MARK: - Frequency / period sine wave

struct SineWaveChart: View {
    let frequency: Double
    var amplitude: Double = 1
    var cycles: Double = 2

    private var points: [PlotPoint] {
        PlotSampling.sineWave(frequencyHz: frequency, cycles: cycles, amplitude: amplitude)
    }

    private var summary: String {
        "\(Format.number(cycles, digits: 0))-cycle sine at \(Format.frequency(frequency)), amplitude \(Format.number(amplitude, digits: 2))."
    }

    var body: some View {
        DiagramCard(title: "Waveform", accessibilitySummary: summary, exportName: "sine-wave") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "v(t)", points: points, color: Theme.chartPrimary, fills: false)],
                xLabel: "Time (s)",
                yLabel: "Amplitude",
                yGuides: [
                    EngineerGuide(value: 0, label: "0", axis: .y),
                ],
                height: 200
            )
        }
    }
}

// MARK: - Ohm's law load line

struct OhmsLawLoadLineChart: View {
    let voltage: Double
    let current: Double
    let resistance: Double

    private var points: [PlotPoint] { PlotSampling.ohmsLoadLine(voltage: voltage, current: current) }

    private var summary: String {
        "Load line through \(Format.volts(voltage)), \(Format.amps(current)). R = \(Format.number(resistance, digits: 3)) Ω."
    }

    var body: some View {
        DiagramCard(title: "V–I load line", accessibilitySummary: summary, exportName: "ohms-load-line") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "Load line", points: points, color: Theme.chartPrimary, fills: true)],
                xLabel: "Voltage (V)",
                yLabel: "Current (A)",
                markers: [
                    EngineerMarker(x: voltage, y: current, label: "OP", color: Theme.energized),
                ],
                height: 200
            )
        }
    }
}

// MARK: - Series RLC impedance magnitude

struct ResonanceImpedanceChart: View {
    let resistance: Double
    let inductance: Double
    let capacitance: Double
    let resonantFrequency: Double

    private var points: [PlotPoint] {
        PlotSampling.seriesImpedanceMagnitude(
            resistance: resistance,
            inductance: inductance,
            capacitance: capacitance,
            fMin: max(resonantFrequency / 20, 1e-3),
            fMax: resonantFrequency * 20
        )
    }

    private var summary: String {
        "Series |Z| vs frequency. Resonance near \(Format.frequency(resonantFrequency)), R = \(Format.number(resistance, digits: 3)) Ω."
    }

    var body: some View {
        DiagramCard(title: "|Z| vs frequency", accessibilitySummary: summary, exportName: "rlc-impedance") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "|Z|", points: points, color: Theme.chartPrimary, fills: true)],
                xLabel: "Frequency (Hz)",
                yLabel: "|Z| (Ω)",
                xGuides: [
                    EngineerGuide(value: resonantFrequency, label: "f₀", axis: .x),
                ],
                logX: true,
                height: 220
            )
        }
    }
}

// MARK: - Reactance X_L / X_C vs frequency

struct ReactanceSweepChart: View {
    let inductance: Double
    let capacitance: Double
    let frequency: Double

    private var curves: (xl: [PlotPoint], xc: [PlotPoint]) {
        let lo = max(frequency / 20, 0.1)
        let hi = max(frequency * 20, lo * 10)
        return PlotSampling.reactanceVsFrequency(
            inductance: inductance,
            capacitance: capacitance,
            fMin: lo,
            fMax: hi
        )
    }

    private var summary: String {
        "X_L rises and X_C falls with frequency. Marker at \(Format.frequency(frequency))."
    }

    var body: some View {
        let xl = 2 * Double.pi * frequency * inductance
        let xc = 1 / (2 * Double.pi * frequency * capacitance)
        return DiagramCard(title: "X_L & X_C vs f", accessibilitySummary: summary, exportName: "reactance-sweep") {
            EngineerLinePlot(
                series: [
                    EngineerSeries(name: "X_L", points: curves.xl, color: Theme.chartPrimary, fills: false),
                    EngineerSeries(name: "X_C", points: curves.xc, color: Theme.chartSecondary, fills: false),
                ],
                xLabel: "Frequency (Hz)",
                yLabel: "Reactance (Ω)",
                markers: [
                    EngineerMarker(x: frequency, y: xl, label: "X_L", color: Theme.chartPrimary),
                    EngineerMarker(x: frequency, y: xc, label: "X_C", color: Theme.chartSecondary),
                ],
                logX: true,
                height: 220
            )
        }
    }
}

// MARK: - 555 monostable capacitor charge

struct MonostableCapChargeChart: View {
    let pulseWidth: Double
    var vcc: Double = 5

    private var points: [PlotPoint] {
        PlotSampling.monostableCapVoltage(pulseWidth: pulseWidth, vcc: vcc)
    }

    private var summary: String {
        "Timing capacitor charges toward \(Format.volts(vcc)) and trips at ⅔ Vcc when t = \(Format.time(pulseWidth))."
    }

    var body: some View {
        DiagramCard(title: "Capacitor charge", accessibilitySummary: summary, exportName: "555-monostable") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "Vc", points: points, color: Theme.chartPrimary, fills: true)],
                xLabel: "Time (s)",
                yLabel: "Vc (V)",
                markers: [
                    EngineerMarker(x: pulseWidth, y: vcc * 2 / 3, label: "⅔ Vcc", color: Theme.energized),
                ],
                xGuides: [EngineerGuide(value: pulseWidth, label: "t", axis: .x)],
                yGuides: [EngineerGuide(value: vcc * 2 / 3, label: "⅔", axis: .y)],
                height: 210
            )
        }
    }
}

// MARK: - Solenoid design visualizations

/// Every pixel value the coil cross-section needs, resolved once in `Double`
/// space and handed to the view layers as explicit `CGFloat`. Keeping the
/// unit-to-point math out of the view builders is what lets the Swift type
/// checker finish: mixing `Double` metres with `CGFloat` points inside a
/// `ZStack` made the whole body one unsolvable expression.
private struct SolenoidCrossSectionLayout {
    let centerX: CGFloat
    let centerY: CGFloat
    let halfLength: CGFloat
    let meanRadius: CGFloat
    let layerCount: Int
    let layerWidth: CGFloat
    let layerStep: CGFloat
    let canvasHeight: CGFloat

    init(size: CGSize, lengthM: Double, meanRadiusM: Double, outerRadiusM: Double, layers: Int) {
        let w: Double = Double(size.width)
        let h: Double = Double(size.height)
        let maxR: Double = max(outerRadiusM, meanRadiusM, 1e-6)
        let scaleY: Double = (h * 0.78) / max(lengthM, 1e-6)
        let scaleX: Double = (w * 0.28) / maxR
        let scale: Double = min(scaleX, scaleY)
        let count: Int = max(1, min(layers, 8))
        let bandWidth: Double = (outerRadiusM - meanRadiusM) * scale / Double(count)

        centerX = CGFloat(w * 0.5)
        centerY = CGFloat(h * 0.52)
        halfLength = CGFloat(lengthM * scale / 2)
        meanRadius = CGFloat(meanRadiusM * scale)
        layerCount = count
        layerWidth = CGFloat(max(5, bandWidth - 1))
        layerStep = CGFloat(bandWidth)
        canvasHeight = CGFloat(h)
    }

    var coilHeight: CGFloat { halfLength * 2 }
    var boreWidth: CGFloat { meanRadius * 2 }
    var glowEndRadius: CGFloat { max(meanRadius * 1.4, 20) }
    var axisTip: CGPoint { CGPoint(x: centerX, y: centerY - halfLength * 0.85) }
    var axisTail: CGPoint { CGPoint(x: centerX, y: centerY + halfLength * 0.85) }

    func windingInset(_ layer: Int) -> CGFloat { CGFloat(layer) * layerStep }
}

/// Soft field glow inside the bore.
private struct SolenoidBoreGlow: View {
    let layout: SolenoidCrossSectionLayout

    var body: some View {
        Capsule()
            .fill(glow)
            .frame(width: layout.meanRadius * 2.2, height: layout.halfLength * 2.1)
            .position(x: layout.centerX, y: layout.centerY)
    }

    private var glow: RadialGradient {
        RadialGradient(
            colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0.04), .clear],
            center: .center,
            startRadius: 2,
            endRadius: layout.glowEndRadius
        )
    }
}

/// One mirrored pair of winding bands, left and right of the bore.
private struct SolenoidWindingLayer: View {
    let layout: SolenoidCrossSectionLayout
    let layer: Int

    var body: some View {
        let inset: CGFloat = layout.windingInset(layer)
        let shade: Double = 0.55 - Double(layer) * 0.04
        Group {
            band(shade: shade)
                .position(x: layout.centerX - layout.meanRadius - inset - 4, y: layout.centerY)
            band(shade: shade)
                .position(x: layout.centerX + layout.meanRadius + inset + 4, y: layout.centerY)
        }
    }

    private func band(shade: Double) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Theme.energized.opacity(shade))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Theme.energized.opacity(0.9), lineWidth: 1)
            )
            .frame(width: layout.layerWidth, height: layout.coilHeight)
    }
}

private struct SolenoidWindingStack: View {
    let layout: SolenoidCrossSectionLayout

    var body: some View {
        ForEach(0..<layout.layerCount, id: \.self) { layer in
            SolenoidWindingLayer(layout: layout, layer: layer)
        }
    }
}

private struct SolenoidBoreOutline: View {
    let layout: SolenoidCrossSectionLayout

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            .frame(width: layout.boreWidth, height: layout.coilHeight)
            .position(x: layout.centerX, y: layout.centerY)
    }
}

/// Axis line, arrow head, and the `B` marker.
private struct SolenoidAxisArrow: View {
    let layout: SolenoidCrossSectionLayout

    var body: some View {
        let tip: CGPoint = layout.axisTip
        Group {
            Path { path in
                path.move(to: layout.axisTail)
                path.addLine(to: tip)
            }
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))

            Path { path in
                path.move(to: tip)
                path.addLine(to: CGPoint(x: tip.x - 6, y: tip.y + 10))
                path.move(to: tip)
                path.addLine(to: CGPoint(x: tip.x + 6, y: tip.y + 10))
            }
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            Text("B")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .position(x: layout.centerX + 14, y: layout.centerY - layout.halfLength * 0.7)
        }
    }
}

private struct SolenoidDimensionLabels: View {
    let layout: SolenoidCrossSectionLayout
    let lengthLabel: String
    let boreLabel: String

    var body: some View {
        Group {
            label(lengthLabel)
                .position(x: layout.centerX, y: 14)
            label(boreLabel)
                .position(x: layout.centerX, y: layout.canvasHeight - 12)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(Theme.muted)
    }
}

struct SolenoidCrossSectionDiagram: View {
    let lengthM: Double
    let meanRadiusM: Double
    let outerRadiusM: Double
    let layers: Int
    let bCenterTesla: Double

    private var summary: String {
        "Solenoid cross-section. Length \(Format.number(lengthM * 1000, digits: 0)) mm, mean radius \(Format.number(meanRadiusM * 1000, digits: 1)) mm, \(layers) layers. Center B \(Format.number(bCenterTesla * 1000, digits: 2)) mT."
    }

    private var lengthLabel: String {
        "ℓ \(Format.number(lengthM * 1000, digits: 0)) mm"
    }

    private var boreLabel: String {
        "Ø \(Format.number(meanRadiusM * 2000, digits: 1)) mm"
    }

    var body: some View {
        DiagramCard(title: "Coil cross-section", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    crossSection(crossSectionLayout(for: geo.size))
                }
                .frame(height: 200)
            }
        }
    }

    private func crossSectionLayout(for size: CGSize) -> SolenoidCrossSectionLayout {
        SolenoidCrossSectionLayout(
            size: size,
            lengthM: lengthM,
            meanRadiusM: meanRadiusM,
            outerRadiusM: outerRadiusM,
            layers: layers
        )
    }

    @ViewBuilder
    private func crossSection(_ layout: SolenoidCrossSectionLayout) -> some View {
        ZStack {
            SolenoidBoreGlow(layout: layout)
            SolenoidWindingStack(layout: layout)
            SolenoidBoreOutline(layout: layout)
            SolenoidAxisArrow(layout: layout)
            SolenoidDimensionLabels(layout: layout, lengthLabel: lengthLabel, boreLabel: boreLabel)
        }
    }
}

struct SolenoidBCurrentChart: View {
    let points: [SolenoidPlotPoint]
    let operatingCurrent: Double
    let operatingB: Double

    private var summary: String {
        "Center flux density versus current. Operating point \(Format.number(operatingCurrent, digits: 2)) A, \(Format.number(operatingB * 1000, digits: 2)) mT."
    }

    var body: some View {
        DiagramCard(title: "B vs. current", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("I", point.x), y: .value("B", point.y * 1000))
                        .foregroundStyle(Theme.chartPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                PointMark(x: .value("I", operatingCurrent), y: .value("B", operatingB * 1000))
                    .foregroundStyle(Theme.energized)
                    .symbolSize(72)
            }
            .chartXAxisLabel("Current (A)")
            .chartYAxisLabel("B (mT)")
            .frame(height: 170)
            .accessibilityHidden(true)
        }
    }
}

struct SolenoidForceGapChart: View {
    let points: [SolenoidPlotPoint]
    let operatingGapMm: Double?
    let operatingForce: Double?

    private var summary: String {
        if let g = operatingGapMm, let f = operatingForce {
            return "Plunger force versus air gap. At \(Format.number(g, digits: 2)) mm, force \(Format.number(f, digits: 3)) N."
        }
        return "Plunger force versus air gap estimate for the designed ampere-turns."
    }

    var body: some View {
        DiagramCard(title: "Force vs. air gap", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Gap", point.x), y: .value("Force", point.y))
                        .foregroundStyle(Theme.chartSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                if let g = operatingGapMm, let f = operatingForce {
                    PointMark(x: .value("Gap", g), y: .value("Force", f))
                        .foregroundStyle(Theme.energized)
                        .symbolSize(72)
                }
            }
            .chartXAxisLabel("Air gap (mm)")
            .chartYAxisLabel("Force (N)")
            .frame(height: 170)
            .accessibilityHidden(true)
        }
    }
}

struct SolenoidAxialFieldChart: View {
    let points: [SolenoidPlotPoint]
    let lengthM: Double
    let bCenter: Double

    private var summary: String {
        "On-axis flux density along the coil. Center \(Format.number(bCenter * 1000, digits: 2)) mT over \(Format.number(lengthM * 1000, digits: 0)) mm length."
    }

    var body: some View {
        DiagramCard(title: "Axial B(z)", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(x: .value("z", point.x), y: .value("B", point.y * 1000))
                        .foregroundStyle(Theme.chartFill)
                    LineMark(x: .value("z", point.x), y: .value("B", point.y * 1000))
                        .foregroundStyle(Theme.chartPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                RuleMark(x: .value("End−", -lengthM * 500))
                    .foregroundStyle(Theme.muted.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                RuleMark(x: .value("End+", lengthM * 500))
                    .foregroundStyle(Theme.muted.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartXAxisLabel("z from center (mm)")
            .chartYAxisLabel("B (mT)")
            .frame(height: 180)
            .accessibilityHidden(true)
        }
    }
}
