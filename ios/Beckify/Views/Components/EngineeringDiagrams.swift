import SwiftUI
import Charts
import BeckifyMath

/// Accessible technical diagrams derived from validated calculation results.
enum EngineeringDiagrams {
    // Marker namespace for related views.
}

struct DiagramCard<Content: View>: View {
    let title: String
    let summary: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title.uppercased())
                .font(Theme.TypeRole.label)
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
            content
                .frame(maxWidth: .infinity)
                .frame(minHeight: 160)
                .padding(Theme.Space.sm)
                .background(Theme.surfaceInset, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(summary)
        }
    }
}

/// Phasor / impedance triangle for series reactance results.
struct PhasorDiagramView: View {
    let resistance: Double
    let netReactance: Double

    var body: some View {
        DiagramCard(
            title: "Phasor",
            summary: accessibilitySummary
        ) {
            Canvas { context, size in
                let inset = CGRect(origin: .zero, size: size).insetBy(dx: 18, dy: 18)
                let origin = CGPoint(x: inset.minX + 12, y: inset.midY)
                let maxLeg = max(abs(resistance), abs(netReactance), 1)
                let scale = min(inset.width, inset.height) * 0.42 / maxLeg
                let rPoint = CGPoint(x: origin.x + resistance * scale, y: origin.y)
                let tip = CGPoint(
                    x: origin.x + resistance * scale,
                    y: origin.y - netReactance * scale
                )

                var axes = Path()
                axes.move(to: CGPoint(x: inset.minX, y: origin.y))
                axes.addLine(to: CGPoint(x: inset.maxX, y: origin.y))
                axes.move(to: CGPoint(x: origin.x, y: inset.maxY))
                axes.addLine(to: CGPoint(x: origin.x, y: inset.minY))
                context.stroke(axes, with: .color(Theme.gridLine), lineWidth: 1)

                var rPath = Path()
                rPath.move(to: origin)
                rPath.addLine(to: rPoint)
                context.stroke(rPath, with: .color(Theme.accent), lineWidth: Theme.Stroke.diagram)

                var xPath = Path()
                xPath.move(to: rPoint)
                xPath.addLine(to: tip)
                context.stroke(xPath, with: .color(Theme.copper), lineWidth: Theme.Stroke.diagram)

                var zPath = Path()
                zPath.move(to: origin)
                zPath.addLine(to: tip)
                context.stroke(zPath, with: .color(Theme.good), lineWidth: Theme.Stroke.emphasis)

                context.fill(Path(ellipseIn: CGRect(x: tip.x - 3, y: tip.y - 3, width: 6, height: 6)), with: .color(Theme.good))
            }
        }
    }

    private var accessibilitySummary: String {
        let angle = atan2(netReactance, resistance) * 180 / .pi
        return "Phasor diagram. Resistance \(Format.number(resistance, digits: 2)) ohms, net reactance \(Format.number(netReactance, digits: 2)) ohms, angle \(Format.degrees(angle))."
    }
}

struct ResonanceCurveView: View {
    let frequency: Double
    let bandwidth: Double

    var body: some View {
        let f0 = max(frequency, 1)
        let bw = bandwidth.isFinite && bandwidth > 0 ? bandwidth : f0 / 10
        let points: [(Double, Double)] = stride(from: f0 - 2 * bw, through: f0 + 2 * bw, by: bw / 10).map { f in
            let x = (f - f0) / (bw / 2)
            let mag = 1 / (1 + x * x)
            return (f, mag)
        }

        DiagramCard(
            title: "Resonance",
            summary: "Resonance curve peaked at \(Format.frequency(frequency)) with bandwidth \(bandwidth.isFinite ? Format.frequency(bandwidth) : "unavailable")."
        ) {
            Chart(points, id: \.0) { point in
                LineMark(
                    x: .value("Frequency", point.0),
                    y: .value("Relative response", point.1)
                )
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Frequency", point.0),
                    y: .value("Relative response", point.1)
                )
                .foregroundStyle(Theme.accent.opacity(0.12))
            }
            .chartXAxis {
                AxisMarks(position: .bottom, values: [f0 - bw, f0, f0 + bw]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let f = value.as(Double.self) {
                            Text(Format.frequency(f))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 0.5, 1])
            }
            .chartLegend(.hidden)
        }
    }
}

struct PowerTriangleView: View {
    let realKW: Double
    let reactiveKVAR: Double
    let title: String
    let summary: String

    var body: some View {
        DiagramCard(title: title, summary: summary) {
            Canvas { context, size in
                let inset = CGRect(origin: .zero, size: size).insetBy(dx: 20, dy: 20)
                let origin = CGPoint(x: inset.minX, y: inset.maxY)
                let maxLeg = max(realKW, abs(reactiveKVAR), 1)
                let scale = min(inset.width, inset.height) * 0.75 / maxLeg
                let p = CGPoint(x: origin.x + realKW * scale, y: origin.y)
                let tip = CGPoint(x: p.x, y: origin.y - reactiveKVAR * scale)

                var base = Path()
                base.move(to: origin)
                base.addLine(to: p)
                context.stroke(base, with: .color(Theme.accent), lineWidth: Theme.Stroke.diagram)

                var rise = Path()
                rise.move(to: p)
                rise.addLine(to: tip)
                context.stroke(rise, with: .color(Theme.copper), lineWidth: Theme.Stroke.diagram)

                var hyp = Path()
                hyp.move(to: origin)
                hyp.addLine(to: tip)
                context.stroke(hyp, with: .color(Theme.good), lineWidth: Theme.Stroke.emphasis)
            }
        }
    }
}

struct SignalTransferCurveView: View {
    let rawMin: Double
    let rawMax: Double
    let euMin: Double
    let euMax: Double
    let raw: Double
    let engineering: Double
    let squareRoot: Bool

    var body: some View {
        // Preserve descending raw spans (reverse-acting loops). Only collapse
        // the zero-width case so Chart identifiers stay unique.
        let rawSpan = rawMax - rawMin
        let span = abs(rawSpan) < 1e-9 ? 1e-9 : rawSpan
        let samples = stride(from: 0.0, through: 1.0, by: 0.05).map { t -> (Double, Double) in
            let r = rawMin + t * span
            let fraction = squareRoot ? sqrt(t) : t
            let eu = euMin + fraction * (euMax - euMin)
            return (r, eu)
        }

        DiagramCard(
            title: "Transfer curve",
            summary: "Signal transfer from raw \(Format.number(rawMin, digits: 2))–\(Format.number(rawMax, digits: 2)) to engineering \(Format.number(euMin, digits: 2))–\(Format.number(euMax, digits: 2)). Current point raw \(Format.number(raw, digits: 2)) maps to \(Format.number(engineering, digits: 2))."
        ) {
            Chart {
                ForEach(samples, id: \.0) { sample in
                    LineMark(
                        x: .value("Raw", sample.0),
                        y: .value("EU", sample.1)
                    )
                    .foregroundStyle(Theme.accent)
                }
                PointMark(
                    x: .value("Raw", raw),
                    y: .value("EU", engineering)
                )
                .foregroundStyle(Theme.copper)
                .symbolSize(64)
            }
            .chartLegend(.hidden)
        }
    }
}

struct LoadFactorProfileView: View {
    let connected: Double
    let demand: Double
    let average: Double
    let capacity: Double

    var body: some View {
        let bars: [(String, Double, Color)] = [
            ("Average", average, Theme.accent2),
            ("Demand", demand, Theme.accent),
            ("Connected", connected, Theme.copper),
            ("Capacity", capacity > 0 ? capacity : max(connected, demand), Theme.muted),
        ].filter { $0.1.isFinite && $0.1 > 0 }

        DiagramCard(
            title: "Load profile",
            summary: "Load profile bars for average \(Format.number(average, digits: 1)), demand \(Format.number(demand, digits: 1)), connected \(Format.number(connected, digits: 1)), and capacity \(Format.number(capacity, digits: 1))."
        ) {
            Chart(bars, id: \.0) { bar in
                BarMark(
                    x: .value("Kind", bar.0),
                    y: .value("Load", bar.1)
                )
                .foregroundStyle(bar.2)
            }
            .chartLegend(.hidden)
        }
    }
}

struct TimerTraceView: View {
    let preset: Int
    let actualSeconds: Double
    let targetSeconds: Double
    let timebaseSeconds: Double

    var body: some View {
        DiagramCard(
            title: "Timer trace",
            summary: "Timer preset \(preset) counts at \(Format.time(timebaseSeconds)) timebase. Actual \(Format.time(actualSeconds)), requested \(Format.time(targetSeconds))."
        ) {
            Canvas { context, size in
                let inset = CGRect(origin: .zero, size: size).insetBy(dx: 16, dy: 24)
                let maxT = max(actualSeconds, targetSeconds, timebaseSeconds, 1e-6)
                let yLow = inset.maxY
                let yHigh = inset.minY + 8

                var axis = Path()
                axis.move(to: CGPoint(x: inset.minX, y: yLow))
                axis.addLine(to: CGPoint(x: inset.maxX, y: yLow))
                context.stroke(axis, with: .color(Theme.gridLine), lineWidth: 1)

                let actualX = inset.minX + CGFloat(actualSeconds / maxT) * inset.width
                var wave = Path()
                wave.move(to: CGPoint(x: inset.minX, y: yLow))
                wave.addLine(to: CGPoint(x: inset.minX, y: yHigh))
                wave.addLine(to: CGPoint(x: actualX, y: yHigh))
                wave.addLine(to: CGPoint(x: actualX, y: yLow))
                context.stroke(wave, with: .color(Theme.accent), lineWidth: Theme.Stroke.diagram)

                let targetX = inset.minX + CGFloat(targetSeconds / maxT) * inset.width
                var target = Path()
                target.move(to: CGPoint(x: targetX, y: inset.minY))
                target.addLine(to: CGPoint(x: targetX, y: inset.maxY))
                context.stroke(
                    target,
                    with: .color(Theme.warn),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
            }
        }
    }
}

struct VoltageDropRunView: View {
    let sourceVolts: Double
    let loadVolts: Double

    var body: some View {
        DiagramCard(
            title: "Feeder run",
            summary: "Conductor run from source \(Format.volts(sourceVolts)) to load \(Format.volts(loadVolts))."
        ) {
            Canvas { context, size in
                let y = size.height * 0.55
                var wire = Path()
                wire.move(to: CGPoint(x: 20, y: y))
                wire.addLine(to: CGPoint(x: size.width - 20, y: y))
                context.stroke(wire, with: .color(Theme.copper), lineWidth: 3)

                for x in [CGFloat(20), size.width - 20] {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)),
                        with: .color(Theme.accent)
                    )
                }

                let drop = max(sourceVolts - loadVolts, 0)
                let label = "ΔV \(Format.volts(drop))"
                context.draw(
                    Text(label).font(.caption.monospacedDigit()).foregroundStyle(Theme.muted),
                    at: CGPoint(x: size.width * 0.5, y: y - 22),
                    anchor: .center
                )
            }
        }
    }
}
