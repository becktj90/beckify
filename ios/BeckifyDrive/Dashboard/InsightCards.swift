import BeckifyMath
import Charts
import SwiftUI

// Energy & range cards. Every number here is an estimate built from measured
// PIDs and phone sensors plus a stated assumption; each card says which.

/// Real Wh/mi: displayed-charge drop × typed pack size ÷ GPS distance.
struct EfficiencyCard: View {
    let tracker: EfficiencyTracker
    let packKWh: Double?
    let units: DriveUnitPreference

    var body: some View {
        let whPerMile = tracker.whPerMile(packKWh: packKWh)
        let shown = whPerMile.map { units.speed == .mph ? $0 : $0 / DriveUnitPreference.kmPerMile }
        let unit = units.speed == .mph ? "Wh/mi" : "Wh/km"
        MetricCard(
            title: "Efficiency",
            symbol: "leaf.fill",
            value: shown.map { String(format: "%.0f", $0) },
            unit: unit,
            freshness: shown == nil ? .notReported : .live,
            estimated: true,
            caption: caption,
            spokenValue: shown.map { "\(Int($0.rounded())) watt hours per \(units.speed == .mph ? "mile" : "kilometer")" }
        )
    }

    private var caption: String {
        guard let packKWh else {
            return "Needs a pack size under Adapter. Charge drop × pack kWh ÷ GPS distance."
        }
        let drop = tracker.socDropPercent ?? 0
        let miles = tracker.miles ?? 0
        let distance = units.distance(fromKilometers: miles * DriveUnitPreference.kmPerMile)
        let progress = "\(String(format: "%.1f", max(drop, 0))) % used over \(String(format: "%.1f", distance)) \(units.distanceLabel)"
        if tracker.whPerMile(packKWh: packKWh) == nil {
            return "Waiting for 1 % charge drop and 1 mi of GPS distance. So far \(progress)."
        }
        return "\(progress) · \(String(format: "%.0f", packKWh)) kWh pack assumed."
    }
}

/// Planning range with temperature and headwind lines from Open-Meteo.
struct WeatherRangeCard: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var weather: WeatherService
    let locationAccess: SensorAccess
    let units: DriveUnitPreference
    let requestLocation: () -> Void
    let openSettings: () -> Void
    let openAdapter: () -> Void

    var body: some View {
        let adjustment = model.weatherAdjustment
        let shown = adjustment.map { units.distance(fromKilometers: $0.adjustedMiles * DriveUnitPreference.kmPerMile) }
        MetricCard(
            title: "Weather-adjusted range",
            symbol: "cloud.sun.fill",
            value: shown.map { String(format: "%.0f", $0) },
            unit: units.distanceLabel,
            freshness: shown == nil ? .notReported : .live,
            estimated: true,
            caption: caption(adjustment),
            spokenValue: shown.map { "\(Int($0.rounded())) \(units.distanceLabel)" }
        ) {
            VStack(alignment: .leading, spacing: 4) {
                if let adjustment {
                    line("Planning base", value: miles(adjustment.baseMiles))
                    if let temperature = adjustment.temperatureFraction, let weather = model.usableWeather {
                        line("Temperature \(Int(units.temperature(fromCelsius: weather.temperatureC).rounded()))\(units.temperature.label)", value: percent(temperature))
                    }
                    if let wind = adjustment.headwindFraction {
                        line(wind <= 0 ? "Headwind" : "Tailwind", value: percent(wind))
                    }
                }
                if model.planningRangeMiles == nil {
                    Button("Set Pack and Wh/mi", action: openAdapter)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(DriveTheme.accent)
                }
                PermissionPrompt(access: locationAccess, askTitle: "Allow Location", ask: requestLocation, openSettings: openSettings)
            }
        }
    }

    private func line(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(DriveTheme.estimated)
        }
        .font(.subheadline)
        .foregroundStyle(DriveTheme.text)
    }

    private func miles(_ value: Double) -> String {
        "\(Int(units.distance(fromKilometers: value * DriveUnitPreference.kmPerMile).rounded())) \(units.distanceLabel)"
    }

    private func percent(_ fraction: Double) -> String {
        String(format: "%+.0f %%", fraction * 100)
    }

    private func caption(_ adjustment: RangeWeatherModel.Adjustment?) -> String {
        let source: String
        if let current = weather.current {
            let minutes = Int(model.now.timeIntervalSince(current.fetchedAt) / 60)
            let age = minutes < 1 ? "just now" : "\(minutes) min ago"
            source = current.isUsable(now: model.now)
                ? "Open-Meteo, \(age)."
                : "Last weather is \(age), too old to use. Waiting for a connection."
        } else if weather.status == .failed {
            source = "Weather is offline. Range is not adjusted."
        } else if locationAccess != .allowed {
            source = "Needs Location to look up weather near you."
        } else {
            source = "Looking up weather near you."
        }
        guard adjustment != nil else {
            return model.planningRangeMiles == nil
                ? "Needs displayed charge plus pack kWh and Wh/mi you type. \(source)"
                : source
        }
        return "\(source) Temperature from AAA 2019 cold/hot tests; wind from drag 0.308 and an assumed 2.4 m² frontal area. Your Wh/mi is treated as mild, still-air driving."
    }
}

/// Share of braking energy returned to the pack.
struct RegenScoreCard: View {
    let tracker: RegenScoreTracker
    let spec: VehicleSpec

    var body: some View {
        let score = tracker.score.map { $0 * 100 }
        MetricCard(
            title: "Regen score",
            symbol: "arrow.triangle.2.circlepath",
            value: score.map { String(format: "%.0f", $0) },
            unit: "%",
            freshness: score == nil ? .notReported : .live,
            tint: DriveTheme.regen,
            estimated: true,
            caption: score == nil
                ? "Needs a few stops with HV current and speed read. Then: energy back into the pack ÷ motion energy lost slowing down."
                : "Energy back (\(spec.voltsLabel) × current) ÷ motion energy lost slowing down (\(spec.massLabel) assumed). Friction brakes, hills, and drag are not split out.",
            spokenValue: score.map { "\(Int($0.rounded())) percent" }
        ) {
            if let score {
                Gauge(value: min(score, 100), in: 0...100) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(DriveTheme.regen)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Driving smoothness from phone G, speed and pedal movement, Chauffeur to Reckless.
/// A smoothness label, not a safety or impairment test.
struct DriveSkillCard: View {
    let tracker: DriveSkillTracker

    private var tint: Color {
        switch tracker.tier {
        case .chauffeur?, .smooth?, .steady?: return DriveTheme.accent
        case .spirited?, .rough?: return DriveTheme.warning
        case .reckless?: return DriveTheme.critical
        case nil: return DriveTheme.muted
        }
    }

    var body: some View {
        let score = tracker.score
        MetricCard(
            title: "Driver score",
            symbol: "steeringwheel",
            value: score.map { String(format: "%.0f", $0) },
            unit: "/ 100",
            freshness: score == nil ? .notReported : .live,
            tint: tint,
            caption: caption,
            spokenValue: score.flatMap { value in
                tracker.tier.map { "\(Int(value.rounded())) out of 100, \($0.title)" }
            }
        ) {
            if let score, let tier = tracker.tier {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    Gauge(value: score, in: 0...100) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(tint)
                        .accessibilityHidden(true)
                }
            } else {
                ProgressView(value: tracker.calibrationFraction)
                    .tint(DriveTheme.muted)
                    .accessibilityHidden(true)
            }
        }
    }

    private var caption: String {
        guard tracker.score != nil else {
            return "Needs about 20 s of driving. Reads the phone's G sensor, speed, and pedal. Stopped time is not scored."
        }
        let events = "\(tracker.harshBrakes) hard brakes, \(tracker.harshAccels) hard launches, \(tracker.hardCorners) hard corners, \(tracker.weaves) swerves."
        return "Smoothness of the last few minutes. \(events) A smoothness label only: not a safety or impairment test."
    }
}

/// Trip energy split into driving, climbing, stopped, and regen returned.
struct TripEnergyCard: View {
    let ledger: TripEnergyLedger
    let spec: VehicleSpec

    private struct Slice: Identifiable {
        let id: String
        let label: String
        let kWh: Double
        let color: Color
    }

    var body: some View {
        let slices = [
            Slice(id: "drive", label: "Driving", kWh: ledger.drivingKWh, color: DriveTheme.accent),
            Slice(id: "climb", label: "Climbing", kWh: ledger.climbKWh, color: DriveTheme.warning),
            Slice(id: "stopped", label: "Stopped: climate, conditioning, 12 V", kWh: ledger.stoppedKWh, color: DriveTheme.cold),
        ]
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(ledger.isEmpty ? DriveTheme.muted : DriveTheme.estimated)
                Text("Trip energy")
                    .foregroundStyle(DriveTheme.muted)
                Spacer()
                EstimateBadge()
            }
            .font(.footnote.weight(.semibold))
            if ledger.isEmpty {
                Text("—")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(DriveTheme.muted)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", ledger.netKWh))
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(DriveTheme.estimated)
                    Text("kWh net")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DriveTheme.muted)
                }
                Chart(slices) { slice in
                    BarMark(x: .value("kWh", slice.kWh), y: .value("Trip", "Trip"))
                        .foregroundStyle(slice.color)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .frame(height: 16)
                .clipShape(Capsule())
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(slices) { slice in
                        legend(slice.label, kWh: slice.kWh, color: slice.color)
                    }
                    legend("Regen returned", kWh: -ledger.regenKWh, color: DriveTheme.regen)
                }
            }
            Text("\(spec.voltsLabel) nominal × measured current, integrated. Climbing is m·g·Δh at \(spec.massLabel). Climate and battery conditioning cannot be told apart, so they share the stopped bucket; the same draw while moving counts as driving.")
                .font(.caption)
                .foregroundStyle(DriveTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .driveCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trip energy, estimate")
    }

    private func legend(_ label: String, kWh: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(DriveTheme.text)
            Spacer()
            Text(String(format: "%+.2f kWh", kWh))
                .monospacedDigit()
                .foregroundStyle(DriveTheme.muted)
        }
        .font(.footnote)
    }
}

/// Pack temperature against the fast-charge window, with an ETA when warming or cooling toward it.
struct PreconditionCard: View {
    let pack: DriveValue
    let advice: PreconditionCoach.Advice
    let units: DriveUnitPreference

    var body: some View {
        let shown = pack.value.map { units.temperature(fromCelsius: $0) }
        MetricCard(
            title: "Fast-charge temp",
            symbol: "thermometer.snowflake",
            value: shown.map { String(format: "%.0f", $0) },
            unit: units.temperature.label,
            freshness: pack.freshness,
            level: level,
            caption: message + " Window: \(label(PreconditionCoach.fastChargeLowC))–\(label(PreconditionCoach.fastChargeHighC)), generic Li-ion guidance (Battery University BU-410), not GM's charge map.",
            spokenValue: shown.map { "\(Int($0.rounded())) \(units.temperature.spokenLabel). \(message)" }
        ) {
            TemperatureBandGauge(
                celsius: pack.value,
                displayRange: -20...60,
                bands: [
                    TemperatureBand(range: -20...PreconditionCoach.fastChargeLowC, color: DriveTheme.cold),
                    TemperatureBand(range: PreconditionCoach.fastChargeLowC...PreconditionCoach.fastChargeHighC, color: DriveTheme.accent),
                    TemperatureBand(range: PreconditionCoach.fastChargeHighC...60, color: DriveTheme.warning),
                ],
                units: units
            )
        }
    }

    private var level: DriveLevel {
        switch advice {
        case .inWindow, .unknown: return .normal
        case .belowWindow, .aboveWindow: return .caution
        }
    }

    private var message: String {
        switch advice {
        case .unknown:
            return "Needs pack temperature."
        case .inWindow:
            return "In the fast-charge window."
        case .belowWindow(let degrees, let minutes):
            let gap = degreeGap(degrees)
            if let minutes {
                return "\(gap) below the window. About \(Int(minutes.rounded())) min at the current warm-up rate (est.)."
            }
            return "\(gap) below the window. Precondition before a fast charge."
        case .aboveWindow(let degrees, let minutes):
            let gap = degreeGap(degrees)
            if let minutes {
                return "\(gap) above the window. About \(Int(minutes.rounded())) min at the current cool-down rate (est.)."
            }
            return "\(gap) above the window. Expect a slower fast charge."
        }
    }

    private func degreeGap(_ celsius: Double) -> String {
        let span = units.temperature == .fahrenheit ? celsius * 9 / 5 : celsius
        return "\(Int(span.rounded()))\(units.temperature.label)"
    }

    private func label(_ celsius: Double) -> String {
        "\(Int(units.temperature(fromCelsius: celsius).rounded()))\(units.temperature.label)"
    }
}

/// Daily capacity readings over months, with a fitted trend.
struct DegradationCard: View {
    let log: CapacityLog

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .foregroundStyle(log.entries.isEmpty ? DriveTheme.muted : DriveTheme.accent)
                Text("Capacity trend")
                    .foregroundStyle(DriveTheme.muted)
                Spacer()
                if log.ampHoursPerYear != nil {
                    EstimateBadge()
                }
            }
            .font(.footnote.weight(.semibold))
            if let latest = log.entries.last {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", latest.ampHours))
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(DriveTheme.measured)
                    Text("Ah latest")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DriveTheme.muted)
                    Spacer()
                    if let perYear = log.ampHoursPerYear {
                        Text(String(format: "%+.1f Ah/yr", perYear))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(DriveTheme.estimated)
                    }
                }
                if log.entries.count >= 2 {
                    Chart(log.entries) { entry in
                        LineMark(x: .value("Day", entry.day), y: .value("Ah", entry.ampHours))
                            .foregroundStyle(DriveTheme.accent)
                        PointMark(x: .value("Day", entry.day), y: .value("Ah", entry.ampHours))
                            .foregroundStyle(DriveTheme.accent)
                            .symbolSize(18)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 120)
                    .accessibilityHidden(true)
                }
            } else {
                Text("—")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(DriveTheme.muted)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(DriveTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .driveCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Capacity trend")
    }

    private var caption: String {
        let base = "One capacity reading (PID 2241A3) a day, kept on this phone. Enthusiast figure, not a GM battery-health report."
        if log.entries.isEmpty { return "No readings yet. \(base)" }
        guard log.ampHoursPerYear != nil else {
            return "\(log.entries.count) day\(log.entries.count == 1 ? "" : "s") logged. A trend needs a month. \(base)"
        }
        return "Straight-line fit over \(log.entries.count) days. \(base)"
    }
}

/// Road grade from altitude change over GPS distance.
struct GradeCard: View {
    let grade: Double?
    let source: AltitudeSource?
    let locationAccess: SensorAccess
    let requestLocation: () -> Void
    let openSettings: () -> Void

    var body: some View {
        MetricCard(
            title: "Grade",
            symbol: grade.map { $0 >= 0 ? "arrow.up.right" : "arrow.down.right" } ?? "arrow.right",
            value: grade.map { String(format: "%+.1f", $0) },
            unit: "%",
            freshness: grade == nil ? .notReported : .live,
            estimated: true,
            caption: caption,
            spokenValue: grade.map { "\(String(format: "%.1f", abs($0))) percent \($0 >= 0 ? "uphill" : "downhill")" }
        ) {
            PermissionPrompt(access: locationAccess, askTitle: "Allow Location", ask: requestLocation, openSettings: openSettings)
        }
    }

    private var caption: String {
        if locationAccess != .allowed { return "Needs Location for distance travelled." }
        guard let source else { return "Needs altitude from the barometer or GPS." }
        if grade == nil { return "Needs about 40 m of travel. Uses the \(source.rawValue)." }
        return "Altitude change over the last 200 m of GPS distance, from the \(source.rawValue)."
    }
}
