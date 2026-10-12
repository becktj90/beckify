import BeckifyMath
import SwiftUI

/// The big three for Bolt profiles: regen state, power, torque.
/// Power and torque are estimates and say so; regen state is the sign of
/// measured HV current.
struct PowerHero: View {
    @ObservedObject var model: DashboardModel
    let units: DriveUnitPreference

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        let power = model.powerKW
        let flow = model.flow
        let freshness = model.value(.hvCurrentAmps).freshness
        if horizontalSizeClass == .regular || verticalSizeClass == .compact {
            HStack(alignment: .top, spacing: 14) {
                PowerGaugeCard(powerKW: power, flow: flow, freshness: freshness, peakKW: model.insights.peakPowerKW, units: units)
                VStack(spacing: 14) {
                    RegenStateBanner(flow: flow, powerKW: power, units: units)
                    TorqueCard(torqueNm: model.torqueNm, flow: flow, peakNm: model.insights.peakTorqueNm, speedKnown: model.value(.speedKph).value != nil, units: units)
                }
            }
        } else {
            VStack(spacing: 14) {
                RegenStateBanner(flow: flow, powerKW: power, units: units)
                PowerGaugeCard(powerKW: power, flow: flow, freshness: freshness, peakKW: model.insights.peakPowerKW, units: units)
                TorqueCard(torqueNm: model.torqueNm, flow: flow, peakNm: model.insights.peakTorqueNm, speedKnown: model.value(.speedKph).value != nil, units: units)
            }
        }
    }
}

/// Gauge display scales. Rounded up from the session peak so the needle
/// does not rescale on every reply. Display only, not vehicle limits.
enum HeroScale {
    static func powerKW(peak: Double) -> Double {
        max(50, (peak / 50).rounded(.up) * 50)
    }

    static func torqueNm(peak: Double) -> Double {
        max(500, (peak / 500).rounded(.up) * 500)
    }
}

// MARK: - Power

/// Semicircle centered on zero at the top: drive sweeps right (teal),
/// regen sweeps left (green). Retro digits underneath.
struct PowerGaugeCard: View {
    let powerKW: Double?
    let flow: HVFlowState?
    let freshness: DriveFreshness
    let peakKW: Double
    let units: DriveUnitPreference

    @ScaledMetric(relativeTo: .largeTitle) private var digitHeight: CGFloat = 58
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let scale = HeroScale.powerKW(peak: peakKW)
        let fraction = powerKW.map { min(max($0 / scale, -1), 1) } ?? 0
        let shown = powerKW.map { units.power.convert(kilowatts: abs($0)) }
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(DriveTheme.estimated)
                Text("Power")
                    .foregroundStyle(DriveTheme.muted)
                Spacer()
                EstimateBadge()
                FreshnessBadge(freshness: freshness)
            }
            .font(.footnote.weight(.semibold))

            ZStack(alignment: .bottom) {
                PowerArc(fraction: fraction, active: powerKW != nil, flow: flow)
                    .animation(reduceMotion ? nil : .snappy, value: fraction)
                VStack(spacing: 2) {
                    RetroDigits(
                        text: shown.map { String(format: "%.0f", $0) } ?? "–",
                        height: digitHeight,
                        color: powerKW == nil ? DriveTheme.muted : DriveTheme.estimated
                    )
                    Text("\(units.power.label) \(direction)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DriveTheme.muted)
                }
            }
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)

            HStack {
                Text("Regen")
                Spacer()
                Text("±\(Int(units.power.convert(kilowatts: scale).rounded())) \(units.power.label)")
                    .monospacedDigit()
                Spacer()
                Text("Drive")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(DriveTheme.muted)

            Text("350 V nominal pack × measured HV current. Pack voltage is not read, so this runs high when the pack is low and low when it is full.")
                .font(.caption)
                .foregroundStyle(DriveTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .driveCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Power, estimate")
        .accessibilityValue(spoken(shown))
    }

    private var direction: String {
        switch flow {
        case .drive: return "out"
        case .regen: return "back"
        case .idle, .none: return ""
        }
    }

    private func spoken(_ shown: Double?) -> String {
        guard let shown else { return "Not reported. Needs HV current." }
        let amount = "\(Int(shown.rounded())) \(units.power.spokenLabel)"
        switch flow {
        case .regen: return "\(amount) going back into the pack"
        case .drive: return "\(amount) out of the pack"
        case .idle, .none: return amount
        }
    }
}

/// Top semicircle with a zero tick at 12 o'clock.
private struct PowerArc: View {
    /// −1…1. Negative fills left (regen), positive fills right (drive).
    let fraction: Double
    let active: Bool
    let flow: HVFlowState?

    private let lineWidth: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height * 2)
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1)
                    .stroke(DriveTheme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if active, fraction != 0 {
                    Circle()
                        .trim(from: fraction >= 0 ? 0.75 : 0.75 + 0.25 * fraction, to: fraction >= 0 ? 0.75 + 0.25 * fraction : 0.75)
                        .stroke(DriveTheme.color(for: flow), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                }
                Capsule()
                    .fill(DriveTheme.muted)
                    .frame(width: 3, height: lineWidth + 8)
                    .offset(y: -(side - lineWidth) / 2)
            }
            .frame(width: side - lineWidth, height: side - lineWidth)
            .position(x: geo.size.width / 2, y: geo.size.height)
        }
        .aspectRatio(2, contentMode: .fit)
        .padding(.top, lineWidth / 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Torque

struct TorqueCard: View {
    let torqueNm: Double?
    let flow: HVFlowState?
    let peakNm: Double
    let speedKnown: Bool
    let units: DriveUnitPreference

    @ScaledMetric(relativeTo: .largeTitle) private var digitHeight: CGFloat = 40

    var body: some View {
        let scale = HeroScale.torqueNm(peak: peakNm)
        let shown = torqueNm.map { units.torque.convert(newtonMeters: abs($0)) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(DriveTheme.estimated)
                Text("Wheel torque")
                    .foregroundStyle(DriveTheme.muted)
                Spacer()
                EstimateBadge()
            }
            .font(.footnote.weight(.semibold))
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                RetroDigits(
                    text: shown.map { String(format: "%.0f", $0) } ?? "–",
                    height: digitHeight,
                    color: torqueNm == nil ? DriveTheme.muted : DriveTheme.estimated
                )
                Text(units.torque.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DriveTheme.muted)
                if let torqueNm, torqueNm < 0 {
                    Text("braking")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DriveTheme.regen)
                }
            }
            BidirectionalBar(value: torqueNm, fullScale: scale, flow: flow)
                .frame(height: 10)
            Text(caption)
                .font(.caption)
                .foregroundStyle(DriveTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .driveCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wheel torque, estimate")
        .accessibilityValue(shown.map { "\(Int($0.rounded())) \(units.torque.spokenLabel)" } ?? caption)
    }

    private var caption: String {
        if torqueNm == nil, speedKnown {
            return "Shows above about 11 km/h (7 mph). At standstill power ÷ speed has no meaning."
        }
        return "Power × 0.32 m wheel radius ÷ speed. No drivetrain loss, so it reads high in drive and low in regen."
    }
}

// MARK: - Regen state

/// REGEN / DRIVE / IDLE from the sign of measured HV current. A dash when unknown.
struct RegenStateBanner: View {
    let flow: HVFlowState?
    let powerKW: Double?
    let units: DriveUnitPreference

    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 30

    var body: some View {
        let color = DriveTheme.color(for: flow)
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: titleSize * 0.8, weight: .bold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(flow == nil ? DriveTheme.muted : color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(detail)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DriveTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if flow == .regen, let powerKW {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", units.power.convert(kilowatts: abs(powerKW))))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(DriveTheme.estimated)
                        .contentTransition(.numericText())
                    HStack(spacing: 4) {
                        Text(units.power.label)
                        EstimateBadge()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DriveTheme.muted)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DriveTheme.cardRadius, style: .continuous)
                .fill(color.opacity(flow == .regen ? 0.18 : 0.08))
        }
        .driveCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Regen state")
        .accessibilityValue(spoken)
    }

    private var title: String {
        switch flow {
        case .regen: return "REGEN"
        case .drive: return "DRIVE"
        case .idle: return "IDLE"
        case .none: return "—"
        }
    }

    private var symbol: String {
        switch flow {
        case .regen: return "arrow.triangle.2.circlepath"
        case .drive: return "arrow.up.forward.circle.fill"
        case .idle: return "pause.circle.fill"
        case .none: return "minus.circle"
        }
    }

    private var detail: String {
        switch flow {
        case .regen: return "Current is flowing into the pack."
        case .drive: return "Current is flowing out of the pack."
        case .idle: return "No current either way."
        case .none: return "Needs HV current (PID 222414)."
        }
    }

    private var spoken: String {
        guard let flow else { return "Not reported" }
        if flow == .regen, let powerKW {
            return "Regen, about \(Int(units.power.convert(kilowatts: abs(powerKW)).rounded())) \(units.power.spokenLabel) back, estimate"
        }
        return flow.title
    }
}
