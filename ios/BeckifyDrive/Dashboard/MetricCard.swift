import BeckifyMath
import Charts
import SwiftUI

/// Fitness/Health-style card: SF Symbol + label, one large value, a unit, and
/// an optional sparkline or accessory. A missing value is an em dash, never 0.
struct MetricCard<Accessory: View>: View {
    let title: String
    let symbol: String
    /// Formatted number. Ignored unless `freshness` shows a value.
    let value: String?
    let unit: String
    let freshness: DriveFreshness
    var level: DriveLevel = .normal
    var tint: Color? = nil
    /// Estimated values get the "est." badge and the estimated color.
    var estimated: Bool = false
    var caption: String? = nil
    var history: [SparklineBuffer.Point] = []
    var historyBaseline: Double? = nil
    /// Spoken value, e.g. "62 miles per hour". Defaults to value + unit.
    var spokenValue: String? = nil
    @ViewBuilder var accessory: () -> Accessory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shows: Bool { freshness.showsValue && value != nil }
    private var color: Color { tint ?? DriveTheme.color(for: level) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // One row when the title fits whole; otherwise the badges drop to
            // their own row so the title never hyphenates (iPhone SE, large text).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    titleLabel.fixedSize()
                    Spacer(minLength: 4)
                    badges
                }
                VStack(alignment: .leading, spacing: 4) {
                    titleLabel
                    badges
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(shows ? (value ?? "—") : "—")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(shows ? valueColor : DriveTheme.muted)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy, value: value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if shows, !unit.isEmpty {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DriveTheme.muted)
                        .lineLimit(1)
                }
            }
            .opacity(isStale ? 0.55 : 1)
            accessory()
            if shows, history.count >= 2 {
                Sparkline(points: history, tint: color, baseline: historyBaseline)
                    .frame(height: 30)
                    .opacity(isStale ? 0.45 : 1)
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(DriveTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .driveCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    private var titleLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(shows ? color : DriveTheme.muted)
                .accessibilityHidden(true)
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DriveTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            if estimated {
                EstimateBadge()
            }
            FreshnessBadge(freshness: freshness)
        }
    }

    private var valueColor: Color {
        if level != .normal { return color }
        return estimated ? DriveTheme.estimated : DriveTheme.measured
    }

    private var isStale: Bool {
        if case .stale = freshness { return true }
        return false
    }

    private var accessibilityValue: String {
        switch freshness {
        case .notReported:
            return caption ?? "Not reported"
        case .outOfRange:
            return "Reading out of range, not shown"
        case .live, .stale:
            var spoken = spokenValue ?? [value, unit].compactMap { $0 }.joined(separator: " ")
            if estimated { spoken += ", estimate" }
            if case .stale(let age) = freshness {
                return "\(spoken), \(age) seconds old"
            }
            return spoken
        }
    }
}

extension MetricCard where Accessory == EmptyView {
    init(
        title: String,
        symbol: String,
        value: String?,
        unit: String,
        freshness: DriveFreshness,
        level: DriveLevel = .normal,
        tint: Color? = nil,
        estimated: Bool = false,
        caption: String? = nil,
        history: [SparklineBuffer.Point] = [],
        historyBaseline: Double? = nil,
        spokenValue: String? = nil
    ) {
        self.init(
            title: title,
            symbol: symbol,
            value: value,
            unit: unit,
            freshness: freshness,
            level: level,
            tint: tint,
            estimated: estimated,
            caption: caption,
            history: history,
            historyBaseline: historyBaseline,
            spokenValue: spokenValue,
            accessory: { EmptyView() }
        )
    }
}

/// Top-right state on every card: nothing when live, age when stale, a warning when out of range.
struct FreshnessBadge: View {
    let freshness: DriveFreshness

    var body: some View {
        switch freshness {
        case .live:
            Circle()
                .fill(DriveTheme.accent)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
        case .stale(let age):
            Text("\(age) s ago")
                .fixedSize()
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DriveTheme.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DriveTheme.elevated, in: Capsule())
        case .outOfRange:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DriveTheme.warning)
        case .notReported:
            EmptyView()
        }
    }
}

/// Last 60 s of one signal. Axes hidden; it shows shape, not numbers.
struct Sparkline: View {
    let points: [SparklineBuffer.Point]
    let tint: Color
    var baseline: Double? = nil

    var body: some View {
        Chart {
            if let baseline {
                RuleMark(y: .value("Zero", baseline))
                    .foregroundStyle(DriveTheme.track)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            ForEach(points) { point in
                LineMark(
                    x: .value("Time", point.at),
                    y: .value("Value", point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: SparklineScale.domain(values: points.map(\.value), baseline: baseline) ?? 0...1)
        .accessibilityHidden(true)
    }
}

/// Inline button on a phone card whose sensor is not allowed yet.
struct PermissionPrompt: View {
    let access: SensorAccess
    let askTitle: String
    let ask: () -> Void
    let openSettings: () -> Void

    var body: some View {
        switch access {
        case .notAsked:
            Button(askTitle, action: ask)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DriveTheme.accent)
        case .denied:
            Button("Enable in Settings", action: openSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DriveTheme.accent)
        case .allowed, .unavailable:
            EmptyView()
        }
    }
}

/// A card's section header: SF Symbol + title, Health style.
struct DashboardSectionHeader: View {
    let section: DashboardSection

    var body: some View {
        Label(section.title, systemImage: section.symbol)
            .driveSectionLabel()
            .padding(.leading, 4)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }
}
