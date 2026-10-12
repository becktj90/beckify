import BeckifyMath
import SwiftUI

/// HV current, signed: a bar centered on zero, drive vs regen color, and a 60 s trace.
struct HVCurrentCard: View {
    let value: DriveValue
    let history: [SparklineBuffer.Point]

    var body: some View {
        let flow = HVFlowState.from(amps: value.value)
        let scale = CurrentBarScale.fullScale(values: history.map(\.value) + [value.value ?? 0])
        MetricCard(
            title: "HV current",
            symbol: "bolt.horizontal.fill",
            value: value.value.map { String(format: "%+.1f", $0) },
            unit: "A",
            freshness: value.freshness,
            tint: DriveTheme.color(for: flow),
            caption: "PID 222414 · header 7E1 · + leaves the pack, − is regen or charge. Amps only: no kW without a measured pack voltage.",
            history: history,
            historyBaseline: 0,
            spokenValue: value.value.map { "\(String(format: "%.1f", $0)) amps, \(flow?.title ?? "")" }
        ) {
            VStack(alignment: .leading, spacing: 6) {
                FlowChip(flow: flow)
                BidirectionalBar(value: value.value, fullScale: scale, flow: flow)
                    .frame(height: 10)
                HStack {
                    Text("Regen")
                    Spacer()
                    Text("±\(Int(scale)) A")
                        .monospacedDigit()
                    Spacer()
                    Text("Drive")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(DriveTheme.muted)
                .accessibilityHidden(true)
            }
        }
    }
}

/// A capsule with a center tick. Fill grows left for regen and right for drive.
struct BidirectionalBar: View {
    let value: Double?
    let fullScale: Double
    let flow: HVFlowState?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let half = width / 2
            let fraction = value.map { min(max($0 / max(fullScale, 1), -1), 1) } ?? 0
            let fill = abs(CGFloat(fraction)) * half
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DriveTheme.track)
                Capsule()
                    .fill(DriveTheme.color(for: flow))
                    .frame(width: max(fill, value == nil ? 0 : 3))
                    .offset(x: fraction >= 0 ? half : half - fill)
                    .animation(reduceMotion ? nil : .snappy, value: fraction)
                Rectangle()
                    .fill(DriveTheme.muted)
                    .frame(width: 2)
                    .offset(x: half - 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One colored band on a temperature gauge, in °C.
struct TemperatureBand: Identifiable {
    let range: ClosedRange<Double>
    let color: Color
    var id: Double { range.lowerBound }

    /// Bands from `DriveThresholds` (generic Li-ion cell guidance), drawn over −20…70 °C.
    static let pack: [TemperatureBand] = [
        TemperatureBand(range: -20...DriveThresholds.packColdBelowC, color: DriveTheme.cold),
        TemperatureBand(range: DriveThresholds.packColdBelowC...DriveThresholds.packWarmFromC, color: DriveTheme.accent),
        TemperatureBand(range: DriveThresholds.packWarmFromC...DriveThresholds.packHotFromC, color: DriveTheme.warning),
        TemperatureBand(range: DriveThresholds.packHotFromC...70, color: DriveTheme.critical),
    ]
}

/// Linear temperature gauge. With `bands` nil the track is neutral: no
/// threshold is implied where none is published.
struct TemperatureBandGauge: View {
    let celsius: Double?
    let displayRange: ClosedRange<Double>
    let bands: [TemperatureBand]?
    let units: DriveUnitPreference

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    if let bands {
                        HStack(spacing: 2) {
                            ForEach(bands) { band in
                                Capsule()
                                    .fill(band.color.opacity(0.35))
                                    .frame(width: max(0, width * span(band.range) - 2))
                            }
                        }
                    } else {
                        Capsule().fill(DriveTheme.track)
                    }
                    if let celsius {
                        Circle()
                            .fill(markerColor(celsius))
                            .overlay(Circle().strokeBorder(DriveTheme.background, lineWidth: 2))
                            .frame(width: 14, height: 14)
                            .offset(x: position(celsius) * width - 7)
                    }
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            HStack {
                Text(label(displayRange.lowerBound))
                Spacer()
                Text(label(displayRange.upperBound))
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(DriveTheme.muted)
        }
        .accessibilityHidden(true)
    }

    private func span(_ range: ClosedRange<Double>) -> CGFloat {
        let total = displayRange.upperBound - displayRange.lowerBound
        guard total > 0 else { return 0 }
        return CGFloat((range.upperBound - range.lowerBound) / total)
    }

    private func position(_ celsius: Double) -> CGFloat {
        let total = displayRange.upperBound - displayRange.lowerBound
        guard total > 0 else { return 0 }
        return CGFloat(min(max((celsius - displayRange.lowerBound) / total, 0), 1))
    }

    private func markerColor(_ celsius: Double) -> Color {
        guard let bands else { return DriveTheme.text }
        return bands.first { $0.range.contains(celsius) }?.color ?? DriveTheme.text
    }

    private func label(_ celsius: Double) -> String {
        "\(Int(units.temperature(fromCelsius: celsius).rounded()))\(units.temperature.label)"
    }
}

/// Power-electronics slot with no published request for this vehicle.
struct NotReportedCard: View {
    let title: String
    let symbol: String
    let source: String

    var body: some View {
        MetricCard(
            title: title,
            symbol: symbol,
            value: nil,
            unit: "",
            freshness: .notReported,
            caption: "Not reported by this vehicle. \(source)"
        )
    }
}
