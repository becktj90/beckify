import BeckifyMath
import SwiftUI

/// Top of the dashboard. Combustion: speed inside an RPM arc.
/// EV: displayed charge ring beside speed and drive/regen.
struct SpeedHero: View {
    @ObservedObject var model: DashboardModel
    let units: DriveUnitPreference

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At accessibility text sizes the secondary line moves under the arc so
    /// it wraps instead of truncating inside the ring.
    private var secondaryBelowArc: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            switch model.layout {
            case .ev: evHero
            case .evStandard: standardEVHero
            case .powertrain: powertrainHero
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var ringSize: CGFloat {
        verticalSizeClass == .compact ? 170 : 236
    }

    // MARK: Combustion

    private var powertrainHero: some View {
        let rpm = model.value(.rpm)
        let rpmText = Text(rpm.value.map { "\(Int($0.rounded()).formatted()) rpm" } ?? "RPM —")
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(DriveTheme.muted)
            .contentTransition(.numericText())
        return VStack(spacing: 6) {
            Gauge(value: min(rpm.value ?? 0, RPMScale.max), in: 0...RPMScale.max) {
                Text("RPM")
            } currentValueLabel: {
                VStack(spacing: 2) {
                    SpeedReadout(speed: model.heroSpeed, units: units, large: true)
                    if !secondaryBelowArc { rpmText }
                }
            }
            .gaugeStyle(ArcGaugeStyle(tint: DriveTheme.accent, active: rpm.value != nil))
            .animation(reduceMotion ? nil : .snappy, value: rpm.value)
            .frame(width: ringSize, height: ringSize)
            if secondaryBelowArc { rpmText }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Speed and engine RPM")
        .accessibilityValue(spokenPowertrain(rpm: rpm.value))
    }

    // MARK: EV on standard PIDs

    /// Speed inside an arc. Standard Mode 01 has no RPM or charge on most EVs.
    private var standardEVHero: some View {
        let kph = model.heroSpeed?.kph
        let note = Text("Standard OBD · no charge or power on this profile")
            .font(.caption)
            .foregroundStyle(DriveTheme.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        return VStack(spacing: 6) {
            Gauge(value: min(kph ?? 0, SpeedScale.maxKph), in: 0...SpeedScale.maxKph) {
                Text("Speed")
            } currentValueLabel: {
                VStack(spacing: 2) {
                    SpeedReadout(speed: model.heroSpeed, units: units, large: true)
                    if !secondaryBelowArc {
                        note.padding(.horizontal, 28)
                    }
                }
            }
            .gaugeStyle(ArcGaugeStyle(tint: DriveTheme.accent, active: kph != nil))
            .animation(reduceMotion ? nil : .snappy, value: kph)
            .frame(width: ringSize, height: ringSize)
            if secondaryBelowArc { note }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Speed")
        .accessibilityValue(heroSpokenSpeed)
    }

    // MARK: EV

    private var evHero: some View {
        let soc = model.value(.displayedSocPercent)
        let amps = model.value(.hvCurrentAmps)
        let flow = HVFlowState.from(amps: amps.value)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                chargeRing(soc)
                evSide(flow: flow)
            }
            VStack(spacing: 16) {
                chargeRing(soc)
                evSide(flow: flow)
            }
        }
    }

    private func chargeRing(_ soc: DriveValue) -> some View {
        let level = DriveThresholds.chargeLevel(percent: soc.value)
        return Gauge(value: min(max(soc.value ?? 0, 0), 100), in: 0...100) {
            Text("Displayed charge")
        } currentValueLabel: {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(soc.value.map { String(format: "%.0f", $0) } ?? "—")
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if soc.value != nil {
                        Text("%")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DriveTheme.muted)
                    }
                }
                .foregroundStyle(DriveTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                Text("Displayed charge")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DriveTheme.muted)
                FreshnessBadge(freshness: soc.freshness)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
        }
        .gaugeStyle(RingGaugeStyle(tint: DriveTheme.color(for: level), active: soc.value != nil))
        .animation(reduceMotion ? nil : .snappy, value: soc.value)
        .frame(width: ringSize * 0.8, height: ringSize * 0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Displayed charge")
        .accessibilityValue(soc.value.map { String(format: "%.0f percent", $0) } ?? "Not reported")
    }

    private func evSide(flow: HVFlowState?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SpeedReadout(speed: model.heroSpeed, units: units, large: false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Speed")
                .accessibilityValue(heroSpokenSpeed)
            if let miles = model.planningRangeMiles {
                let distance = units.distance(fromKilometers: miles * DriveUnitPreference.kmPerMile)
                Label("\(Int(distance.rounded())) \(units.distanceLabel) planning", systemImage: "road.lanes")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DriveTheme.muted)
                    .monospacedDigit()
            }
        }
        .frame(minWidth: 130, alignment: .leading)
    }

    private func spokenPowertrain(rpm: Double?) -> String {
        let engine: String
        if let rpm {
            engine = "\(Int(rpm.rounded())) RPM"
        } else {
            engine = "RPM not reported"
        }
        return "\(heroSpokenSpeed), \(engine)"
    }

    private var heroSpokenSpeed: String {
        guard let speed = model.heroSpeed else { return "Speed not reported" }
        let value = Int(units.speed(fromKph: speed.kph).rounded())
        return "\(value) \(units.speed.spokenLabel), from \(speed.source.rawValue)"
    }
}

/// Display scale for the RPM arc. Not a redline.
enum RPMScale {
    static let max = 8_000.0
}

/// Display scale for the speed arc (160 km/h, about 100 mph). Not a limit.
enum SpeedScale {
    static let maxKph = 160.0
}

/// Big speed number with its unit and source (OBD or GPS).
struct SpeedReadout: View {
    let speed: (kph: Double, source: DashboardModel.SpeedSource, freshness: DriveFreshness)?
    let units: DriveUnitPreference
    let large: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var largeSize: CGFloat = 72
    @ScaledMetric(relativeTo: .largeTitle) private var smallSize: CGFloat = 52
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let display = speed.map { Int(units.speed(fromKph: $0.kph).rounded()) }
        VStack(alignment: large ? .center : .leading, spacing: 0) {
            Text(display.map { String($0) } ?? "—")
                .font(.system(size: large ? largeSize : smallSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(display == nil ? DriveTheme.muted : DriveTheme.text)
                .contentTransition(.numericText(value: Double(display ?? 0)))
                .animation(reduceMotion ? nil : .snappy, value: display)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .opacity(isStale ? 0.55 : 1)
            HStack(spacing: 6) {
                Text(units.speed.label)
                if let speed {
                    Text(speed.source.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(DriveTheme.elevated, in: Capsule())
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(DriveTheme.muted)
        }
    }

    private var isStale: Bool {
        if case .stale = speed?.freshness { return true }
        return false
    }
}

/// "Drive" / "Regen" from the sign of HV current. A dash when current is unknown.
struct FlowChip: View {
    let flow: HVFlowState?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(flow?.title ?? "—")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(DriveTheme.color(for: flow))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DriveTheme.color(for: flow).opacity(0.14), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Drive or regen")
        .accessibilityValue(flow?.title ?? "Not reported")
    }

    private var symbol: String {
        switch flow {
        case .drive: return "arrow.up.forward"
        case .regen: return "arrow.triangle.2.circlepath"
        case .idle: return "pause.fill"
        case .none: return "minus"
        }
    }
}

/// 270° arc, open at the bottom. Used for RPM.
struct ArcGaugeStyle: GaugeStyle {
    let tint: Color
    let active: Bool
    var lineWidth: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(DriveTheme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: active ? 0.75 * configuration.value : 0)
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.55), tint], center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
            configuration.currentValueLabel
        }
        .padding(lineWidth / 2)
    }
}

/// Full ring from 12 o'clock. Used for displayed charge.
struct RingGaugeStyle: GaugeStyle {
    let tint: Color
    let active: Bool
    var lineWidth: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(DriveTheme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: active ? configuration.value : 0)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            configuration.currentValueLabel
        }
        .padding(lineWidth / 2)
    }
}
