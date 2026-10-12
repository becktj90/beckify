import BeckifyMath
import SwiftUI

/// How a reading is converted, formatted, and spoken.
enum MetricKind {
    case percent(digits: Int)
    case temperature
    case volts
    case ampHours

    func convert(_ value: Double, _ units: DriveUnitPreference) -> Double {
        switch self {
        case .temperature: return units.temperature(fromCelsius: value)
        case .percent, .volts, .ampHours: return value
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .percent(let digits): return String(format: "%.\(digits)f", value)
        case .temperature: return String(format: "%.0f", value)
        case .volts: return String(format: "%.2f", value)
        case .ampHours: return String(format: "%.1f", value)
        }
    }

    func unit(_ units: DriveUnitPreference) -> String {
        switch self {
        case .percent: return "%"
        case .temperature: return units.temperature.label
        case .volts: return "V"
        case .ampHours: return "Ah"
        }
    }

    func spokenUnit(_ units: DriveUnitPreference) -> String {
        switch self {
        case .percent: return "percent"
        case .temperature: return units.temperature.spokenLabel
        case .volts: return "volts"
        case .ampHours: return "amp hours"
        }
    }
}

/// One dashboard card by id.
struct DashboardCardView: View {
    let card: DashboardCardID
    @ObservedObject var model: DashboardModel
    @ObservedObject var sensors: PhoneSensorStore
    let units: DriveUnitPreference
    let openAdapter: () -> Void

    var body: some View {
        switch card {
        // Combustion and hybrid
        case .coolant:
            reading(.coolantC, title: "Coolant", symbol: "thermometer.medium", kind: .temperature, caption: "Mode 01 PID 05")
        case .engineLoad:
            reading(.engineLoadPercent, title: "Engine load", symbol: "gauge.with.dots.needle.33percent", kind: .percent(digits: 0), caption: "Calculated load · not torque")
        case .throttle:
            reading(.throttlePercent, title: "Throttle", symbol: "gauge.medium", kind: .percent(digits: 0), caption: "Mode 01 PID 11")
        case .fuel:
            reading(.fuelLevelPercent, title: "Fuel level", symbol: "fuelpump.fill", kind: .percent(digits: 0), caption: "Fuel in the tank · not battery charge")
        case .ambient:
            reading(.ambientC, title: "Ambient", symbol: "thermometer.sun.fill", kind: .temperature, caption: "Mode 01 PID 46")
        case .moduleVolts:
            moduleVolts
        // EV battery
        case .hvCurrent:
            HVCurrentCard(value: model.value(.hvCurrentAmps), history: model.history(.hvCurrentAmps))
        case .packTemp:
            packTemp
        case .capacity:
            reading(.capacityAh, title: "Capacity", symbol: "battery.100", kind: .ampHours, caption: "PID 2241A3 · enthusiast figure · not a GM certificate")
        case .remainingLifeHD:
            reading(.hybridRemainingLifeHDPercent, title: "Remaining life (HD)", symbol: "heart.text.square", kind: .percent(digits: 1), caption: "PID 2243AF · not a warranty state of health")
        case .planningRange:
            planningRange
        // EV motor
        case .motorTemp:
            motorTemp
        case .driveState:
            driveState
        // EV power electronics
        case .inverterTemp:
            notReported(.inverterTemp, id: "inverterTemp", symbol: "thermometer.high")
        case .dcdcOutput:
            notReported(.dcdcOutput, id: "dcdcOutput", symbol: "arrow.left.arrow.right")
        case .charger:
            notReported(.charger, id: "charger", symbol: "powerplug.fill")
        // Phone
        case .gpsSpeed:
            gpsSpeed
        case .altitude:
            altitude
        case .compass:
            compass
        case .gForce:
            GForceCard(
                feed: sensors.gForce,
                locationAccess: sensors.locationAccess,
                requestLocation: sensors.requestLocation,
                openSettings: sensors.openSettings
            )
        case .barometer:
            barometer
        case .phoneBattery:
            phoneBattery
        case .trip:
            TripCard(trip: model.trip, source: model.tripSource, now: model.now, units: units, reset: model.resetTrip)
        }
    }

    // MARK: Generic reading

    private func reading(
        _ reading: OBDReading,
        title: String,
        symbol: String,
        kind: MetricKind,
        level: DriveLevel = .normal,
        caption: String?
    ) -> some View {
        let value = model.value(reading)
        let converted = value.value.map { kind.convert($0, units) }
        return MetricCard(
            title: title,
            symbol: symbol,
            value: converted.map(kind.format),
            unit: kind.unit(units),
            freshness: value.freshness,
            level: level,
            caption: caption,
            history: convertedHistory(model.history(reading), kind),
            spokenValue: converted.map { "\(kind.format($0)) \(kind.spokenUnit(units))" }
        )
    }

    private func convertedHistory(_ history: [SparklineBuffer.Point], _ kind: MetricKind) -> [SparklineBuffer.Point] {
        history.map { SparklineBuffer.Point(at: $0.at, value: kind.convert($0.value, units)) }
    }

    // MARK: 12 V

    private var moduleVolts: some View {
        let value = model.value(.moduleVolts)
        let caption = model.layout == .ev
            ? "Mode 01 PID 42 · accessory bus the DC-DC keeps up · not the pack. Amber under 12.2 V, red under 11.9 V (lead-acid resting levels)."
            : "Mode 01 PID 42 · control module voltage. Amber under 12.2 V, red under 11.9 V (lead-acid resting levels)."
        return reading(
            .moduleVolts,
            title: "12 V bus",
            symbol: "minus.plus.batteryblock.fill",
            kind: .volts,
            level: DriveThresholds.moduleVoltsLevel(value.value),
            caption: caption
        )
    }

    // MARK: Temperatures with a gauge

    private var packTemp: some View {
        let value = model.value(.packTempC)
        let band = DriveThresholds.packBand(celsius: value.value)
        let converted = value.value.map { units.temperature(fromCelsius: $0) }
        return MetricCard(
            title: "Pack temp",
            symbol: "thermometer.medium",
            value: converted.map { String(format: "%.0f", $0) },
            unit: units.temperature.label,
            freshness: value.freshness,
            level: band?.level ?? .normal,
            caption: "PID 22434F · bands are generic Li-ion cell guidance (Battery University), not GM pack limits.",
            history: convertedHistory(model.history(.packTempC), .temperature),
            spokenValue: converted.map { "\(Int($0.rounded())) \(units.temperature.spokenLabel)\(band.map { ", \($0.rawValue)" } ?? "")" }
        ) {
            TemperatureBandGauge(celsius: value.value, displayRange: -20...70, bands: TemperatureBand.pack, units: units)
        }
    }

    private var motorTemp: some View {
        let value = model.value(.motorTempC)
        let converted = value.value.map { units.temperature(fromCelsius: $0) }
        return MetricCard(
            title: "Motor temp",
            symbol: "thermometer.medium",
            value: converted.map { String(format: "%.0f", $0) },
            unit: units.temperature.label,
            freshness: value.freshness,
            caption: "PID 2228CB · no published limit, so no warning color.",
            history: convertedHistory(model.history(.motorTempC), .temperature),
            spokenValue: converted.map { "\(Int($0.rounded())) \(units.temperature.spokenLabel)" }
        ) {
            TemperatureBandGauge(celsius: value.value, displayRange: -20...150, bands: nil, units: units)
        }
    }

    // MARK: EV derived

    private var driveState: some View {
        let amps = model.value(.hvCurrentAmps)
        let flow = HVFlowState.from(amps: amps.value)
        return MetricCard(
            title: "Drive / regen",
            symbol: "arrow.triangle.2.circlepath",
            value: flow?.title,
            unit: "",
            freshness: amps.freshness,
            tint: DriveTheme.color(for: flow),
            caption: "From the sign of HV current only."
        )
    }

    private var planningRange: some View {
        let soc = model.value(.displayedSocPercent)
        let miles = model.planningRangeMiles
        let distance = miles.map { units.distance(fromKilometers: $0 * DriveUnitPreference.kmPerMile) }
        let caption: String
        if miles != nil, let kWh = model.planning.usableKWh, let wh = model.planning.whPerMile {
            caption = String(format: "Planning only · %.0f kWh assumed · %.0f Wh/mi · not the car's estimate", kWh, wh)
        } else if soc.value == nil {
            caption = "Needs displayed charge from the car, plus pack kWh and Wh/mi you type."
        } else {
            caption = "Type pack kWh and Wh/mi under Adapter. Nominal pack size is an assumption."
        }
        return MetricCard(
            title: "Planning range",
            symbol: "road.lanes",
            value: distance.map { String(format: "%.0f", $0) },
            unit: units.distanceLabel,
            freshness: miles == nil ? .notReported : soc.freshness,
            caption: caption
        ) {
            if miles == nil {
                Button("Set Pack and Wh/mi", action: openAdapter)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(DriveTheme.accent)
            }
        }
    }

    private func notReported(_ card: DashboardCardID, id: String, symbol: String) -> some View {
        NotReportedCard(
            title: card.title,
            symbol: symbol,
            source: DriveSignalTable.definition(id: id)?.source ?? ""
        )
    }

    // MARK: Phone

    private func locationFreshness(_ value: Double?) -> DriveFreshness {
        guard let value, let at = sensors.lastLocationAt else { return .notReported }
        return DriveFreshness.evaluate(sample: OBDSample(value: value, at: at), now: model.now, validRange: nil)
    }

    private var locationCaption: String? {
        switch sensors.locationAccess {
        case .notAsked: return "Uses Location while the app is open. Stays on this phone."
        case .denied: return "Location is off for Beckify Drive."
        case .unavailable: return "Location is not available on this device."
        case .allowed: return nil
        }
    }

    private var locationPrompt: some View {
        PermissionPrompt(
            access: sensors.locationAccess,
            askTitle: "Allow Location",
            ask: sensors.requestLocation,
            openSettings: sensors.openSettings
        )
    }

    private var gpsSpeed: some View {
        let kph = sensors.gpsSpeedKph
        let speed = kph.map { units.speed(fromKph: $0) }
        return MetricCard(
            title: "GPS speed",
            symbol: "location.fill",
            value: speed.map { String(format: "%.0f", $0) },
            unit: units.speed.label,
            freshness: locationFreshness(kph),
            caption: locationCaption ?? "From the phone's GPS · a check on the car's speed reading.",
            spokenValue: speed.map { "\(Int($0.rounded())) \(units.speed.spokenLabel)" }
        ) {
            locationPrompt
        }
    }

    private var altitude: some View {
        let meters = sensors.altitudeMeters
        let shown = meters.map { units.altitude(fromMeters: $0) }
        var caption = locationCaption ?? "GPS altitude above sea level."
        if let change = sensors.relativeAltitudeMeters {
            let shownChange = String(format: "%+.0f", units.altitude(fromMeters: change))
            caption = "Barometric change \(shownChange) \(units.altitudeLabel) since the dashboard opened."
        }
        return MetricCard(
            title: "Altitude",
            symbol: "mountain.2.fill",
            value: shown.map { String(format: "%.0f", $0) },
            unit: units.altitudeLabel,
            freshness: locationFreshness(meters),
            caption: caption
        ) {
            locationPrompt
        }
    }

    private var compass: some View {
        let heading = sensors.headingDegrees
        return MetricCard(
            title: "Heading",
            symbol: "location.north.line.fill",
            value: heading.map { "\(Int($0.rounded()) % 360)°" },
            unit: heading.flatMap { CompassMath.cardinal(degrees: $0) } ?? "",
            freshness: heading == nil ? .notReported : .live,
            caption: locationCaption,
            spokenValue: heading.map { "\(Int($0.rounded()) % 360) degrees, \(CompassMath.cardinal(degrees: $0) ?? "")" }
        ) {
            if let heading {
                Image(systemName: "location.north.fill")
                    .font(.title3)
                    .foregroundStyle(DriveTheme.accent)
                    .rotationEffect(.degrees(-heading))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityHidden(true)
            }
            locationPrompt
        }
    }

    private var barometer: some View {
        let kPa = sensors.pressureKPa
        let shown = kPa.map { units.pressure(fromKilopascals: $0) }
        let freshness: DriveFreshness
        if let kPa, let at = sensors.lastAltimeterAt {
            freshness = DriveFreshness.evaluate(sample: OBDSample(value: kPa, at: at), now: model.now, validRange: nil)
        } else {
            freshness = .notReported
        }
        let caption: String
        switch sensors.motionAccess {
        case .notAsked: caption = "Uses the phone's barometer. Asks for Motion & Fitness."
        case .denied: caption = "Motion & Fitness is off for Beckify Drive."
        case .unavailable: caption = "This device has no barometer."
        case .allowed: caption = "Phone barometer · cabin pressure, not a weather station."
        }
        return MetricCard(
            title: "Barometer",
            symbol: "barometer",
            value: shown.map { String(format: "%.\(units.pressureDigits)f", $0) },
            unit: units.pressureLabel,
            freshness: freshness,
            caption: caption
        ) {
            PermissionPrompt(
                access: sensors.motionAccess,
                askTitle: "Allow Motion & Fitness",
                ask: sensors.requestMotion,
                openSettings: sensors.openSettings
            )
        }
    }

    private var phoneBattery: some View {
        let level = sensors.batteryLevel.map { $0 * 100 }
        let symbol: String
        if sensors.batteryCharging {
            symbol = "battery.100.bolt"
        } else if let level, level < 20 {
            symbol = "battery.25"
        } else if let level, level < 60 {
            symbol = "battery.50"
        } else {
            symbol = "battery.100"
        }
        return MetricCard(
            title: "Phone battery",
            symbol: symbol,
            value: level.map { String(format: "%.0f", $0) },
            unit: "%",
            freshness: level == nil ? .notReported : .live,
            level: (level ?? 100) < 20 ? .caution : .normal,
            caption: sensors.batteryCharging ? "Charging" : "Navigation and Bluetooth draw power. Plug in for long drives.",
            spokenValue: level.map { "\(Int($0.rounded())) percent\(sensors.batteryCharging ? ", charging" : "")" }
        )
    }
}
