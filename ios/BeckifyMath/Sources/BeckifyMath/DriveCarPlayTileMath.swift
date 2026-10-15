import Foundation

// MARK: - CarPlay gauge tiles
//
// Driving-task apps may not draw their own CarPlay screens; they fill Apple's
// templates. The tiles below are the data behind the image cards on the
// CarPlay list template: the app draws each tile in the phone dashboard's
// style and hands CarPlay the picture plus a short title and note.
// Values never drawn without a reading: a missing value is "—" with no gauge.

/// One gauge tile on the CarPlay screen.
public struct DriveCarPlayTile: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case charge
        case power
        case flow
        case speed
        case range
        case weatherRange
        case efficiency
        case packTemp
        case rpm
        case coolant
        case fuel
        case moduleVolts
        case ambient
    }

    /// How the tile draws its reading.
    public enum Gauge: Equatable, Sendable {
        /// Full circle from 12 o'clock, 0…1 (displayed charge).
        case ring(fraction: Double)
        /// Semicircle with zero at the top, −1…1 (regen left, drive right).
        case bipolar(fraction: Double)
        /// 270° sweep open at the bottom, 0…1 (speed, RPM).
        case arc(fraction: Double)
        /// Horizontal bar, 0…1 (temperature, fuel, 12 V).
        case bar(fraction: Double)
        /// Icon and number only. Used where no cited scale exists.
        case symbol
    }

    /// Color role; the app maps it to its theme.
    public enum Tone: String, Sendable {
        case accent
        case regen
        case caution
        case critical
        case cold
        case estimated
        case muted
    }

    public var kind: Kind
    /// Card title, e.g. "Charge".
    public var title: String
    /// The big number or word drawn on the tile, e.g. "65", "REGEN", or "—".
    public var value: String
    /// Unit drawn under the number, e.g. "%", "hp", "mph". Empty when none.
    public var unit: String
    /// Card subtitle: source or caveat, e.g. "OBD", "est.", "Not read".
    public var note: String
    /// Nil when the reading is missing.
    public var gauge: Gauge?
    public var tone: Tone
    /// SF Symbol name for the tile's corner icon.
    public var symbol: String
    public var isEstimate: Bool
    /// Extra readings for the large detail card, e.g. PEAK 42 hp, TORQUE 180 lb-ft.
    public var readouts: [Readout]
    /// Words at the two ends of the gauge, e.g. REGEN / DRIVE or E / F.
    public var scaleLabels: ScaleLabels?

    /// One line of the detail card's readout panel. Value is "—" when not read.
    public struct Readout: Equatable, Sendable {
        public var label: String
        public var value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    public struct ScaleLabels: Equatable, Sendable {
        public var low: String
        public var high: String

        public init(low: String, high: String) {
            self.low = low
            self.high = high
        }
    }

    public var id: String { kind.rawValue }

    /// "65 %" style text for the fallback image titles and VoiceOver.
    public var spoken: String {
        guard gauge != nil || value != DriveCarPlayTiles.missing else { return "\(title), not read" }
        let reading = unit.isEmpty ? value : "\(value) \(unit)"
        return isEstimate ? "\(title) \(reading) est." : "\(title) \(reading)"
    }

    public init(
        kind: Kind,
        title: String,
        value: String,
        unit: String,
        note: String,
        gauge: Gauge?,
        tone: Tone,
        symbol: String,
        isEstimate: Bool,
        readouts: [Readout] = [],
        scaleLabels: ScaleLabels? = nil
    ) {
        self.kind = kind
        self.title = title
        self.value = value
        self.unit = unit
        self.note = note
        self.gauge = gauge
        self.tone = tone
        self.symbol = symbol
        self.isEstimate = isEstimate
        self.readouts = readouts
        self.scaleLabels = scaleLabels
    }
}

/// Everything the tiles read. Measured values are nil when not reported.
public struct DriveCarPlayTileInputs: Equatable, Sendable {
    public var layout: DriveLayout
    public var socPercent: Double?
    public var powerKW: Double?
    public var peakPowerKW: Double
    public var flow: HVFlowState?
    public var speedKph: Double?
    /// "OBD" or "GPS".
    public var speedSource: String?
    public var rangeMiles: Double?
    public var weatherRangeMiles: Double?
    public var whPerMile: Double?
    public var packTempC: Double?
    public var rpm: Double?
    public var coolantC: Double?
    public var fuelPercent: Double?
    public var moduleVolts: Double?
    public var ambientC: Double?
    /// Detail-card extras. All optional; a missing one reads "—".
    public var hvCurrentAmps: Double?
    public var torqueNm: Double?
    public var tripKm: Double?
    public var maxSpeedKph: Double?
    public var avgSpeedKph: Double?
    public var regenKWh: Double?
    public var netKWh: Double?
    /// 0…1 share of braking energy recovered.
    public var regenScore: Double?
    public var motorTempC: Double?
    /// True when range uses the profile's published pack size or Wh/mi.
    public var planningUsesDefaults: Bool
    /// Range band ends, miles: planning efficiency vs. this trip's measured one.
    public var rangeLowMiles: Double?
    public var rangeHighMiles: Double?

    public init(
        layout: DriveLayout,
        socPercent: Double? = nil,
        powerKW: Double? = nil,
        peakPowerKW: Double = 0,
        flow: HVFlowState? = nil,
        speedKph: Double? = nil,
        speedSource: String? = nil,
        rangeMiles: Double? = nil,
        weatherRangeMiles: Double? = nil,
        whPerMile: Double? = nil,
        packTempC: Double? = nil,
        rpm: Double? = nil,
        coolantC: Double? = nil,
        fuelPercent: Double? = nil,
        moduleVolts: Double? = nil,
        ambientC: Double? = nil,
        hvCurrentAmps: Double? = nil,
        torqueNm: Double? = nil,
        tripKm: Double? = nil,
        maxSpeedKph: Double? = nil,
        avgSpeedKph: Double? = nil,
        regenKWh: Double? = nil,
        netKWh: Double? = nil,
        regenScore: Double? = nil,
        motorTempC: Double? = nil,
        planningUsesDefaults: Bool = false,
        rangeLowMiles: Double? = nil,
        rangeHighMiles: Double? = nil
    ) {
        self.layout = layout
        self.socPercent = socPercent
        self.powerKW = powerKW
        self.peakPowerKW = peakPowerKW
        self.flow = flow
        self.speedKph = speedKph
        self.speedSource = speedSource
        self.rangeMiles = rangeMiles
        self.weatherRangeMiles = weatherRangeMiles
        self.whPerMile = whPerMile
        self.packTempC = packTempC
        self.rpm = rpm
        self.coolantC = coolantC
        self.fuelPercent = fuelPercent
        self.moduleVolts = moduleVolts
        self.ambientC = ambientC
        self.hvCurrentAmps = hvCurrentAmps
        self.torqueNm = torqueNm
        self.tripKm = tripKm
        self.maxSpeedKph = maxSpeedKph
        self.avgSpeedKph = avgSpeedKph
        self.regenKWh = regenKWh
        self.netKWh = netKWh
        self.regenScore = regenScore
        self.motorTempC = motorTempC
        self.planningUsesDefaults = planningUsesDefaults
        self.rangeLowMiles = rangeLowMiles
        self.rangeHighMiles = rangeHighMiles
    }
}

public enum DriveCarPlayTiles {
    public static let missing = "—"

    /// Display scales, not vehicle limits. They match the phone dashboard.
    public static let speedScaleKph = 160.0
    public static let rpmScale = 8_000.0

    /// Power arc full scale, rounded up from the session peak so the arc does
    /// not rescale on every reply (same rule as the phone hero).
    public static func powerScaleKW(peak: Double) -> Double {
        max(50, (max(0, peak) / 50).rounded(.up) * 50)
    }

    /// Pack bar spans the BU-410 discharge window, −20 °C to 60 °C.
    public static let packBarLowC = -20.0
    public static let packBarHighC = 60.0

    /// 12 V bar spans 11–15 V around the BU-903 resting points.
    public static let voltsBarLow = 11.0
    public static let voltsBarHigh = 15.0

    /// Tiles in CarPlay order. Two rows of four on EV profiles.
    public static func make(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> [DriveCarPlayTile] {
        tiles(input, units: units).map { detailed($0, input, units: units) }
    }

    static func tiles(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> [DriveCarPlayTile] {
        switch input.layout {
        case .ev:
            return [
                charge(input),
                power(input, units: units),
                regenRing(input),
                speed(input, units: units),
                range(input, units: units),
                weatherRange(input, units: units),
                efficiency(input, units: units),
                packTemp(input, units: units),
            ]
        case .evStandard:
            return [
                speed(input, units: units),
                moduleVolts(input),
                ambient(input, units: units),
            ]
        case .powertrain:
            return [
                speed(input, units: units),
                rpm(input),
                coolant(input, units: units),
                fuel(input),
                moduleVolts(input),
                ambient(input, units: units),
            ]
        }
    }

    /// Row headline above the tiles, e.g. "DRIVE · Live · Bolt EUV".
    public static func headline(flow: HVFlowState?, link: String) -> String {
        guard let flow else { return link }
        return "\(flow.title.uppercased()) · \(link)"
    }

    // MARK: Tiles

    static func charge(_ input: DriveCarPlayTileInputs) -> DriveCarPlayTile {
        guard let soc = finite(input.socPercent) else {
            return notRead(.charge, title: "Charge", symbol: "battery.75percent")
        }
        let level = DriveThresholds.chargeLevel(percent: soc)
        return DriveCarPlayTile(
            kind: .charge, title: "Charge", value: String(format: "%.0f", soc), unit: "%",
            note: "Displayed", gauge: .ring(fraction: clamp(soc / 100)),
            tone: level == .normal ? .accent : .caution, symbol: "battery.75percent", isEstimate: false
        )
    }

    static func power(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        guard let kw = finite(input.powerKW) else {
            return notRead(.power, title: "Power", symbol: "bolt.fill", estimate: true)
        }
        let scale = powerScaleKW(peak: max(input.peakPowerKW, abs(kw)))
        let tone: DriveCarPlayTile.Tone
        switch input.flow {
        case .regen: tone = .regen
        case .drive: tone = .estimated
        case .idle, .none: tone = .muted
        }
        return DriveCarPlayTile(
            kind: .power, title: "Power",
            value: String(format: "%.0f", units.power.convert(kilowatts: abs(kw))),
            unit: units.power.label, note: "est.",
            gauge: .bipolar(fraction: max(-1, min(1, kw / scale))),
            tone: tone, symbol: "bolt.fill", isEstimate: true
        )
    }

    static func flow(_ input: DriveCarPlayTileInputs) -> DriveCarPlayTile {
        guard let flow = input.flow else {
            return notRead(.flow, title: "Regen", symbol: "arrow.triangle.2.circlepath")
        }
        let symbol: String
        let tone: DriveCarPlayTile.Tone
        switch flow {
        case .regen: symbol = "arrow.triangle.2.circlepath"; tone = .regen
        case .drive: symbol = "arrow.up.forward.circle.fill"; tone = .accent
        case .idle: symbol = "pause.circle.fill"; tone = .muted
        }
        return DriveCarPlayTile(
            kind: .flow, title: "Regen", value: flow.title.uppercased(), unit: "",
            note: "HV current", gauge: .symbol, tone: tone, symbol: symbol, isEstimate: false
        )
    }

    /// Regen score as a ring: the share of braking energy kept this trip.
    static func regenRing(_ input: DriveCarPlayTileInputs) -> DriveCarPlayTile {
        guard let score = finite(input.regenScore), score >= 0 else {
            return notRead(.flow, title: "Regen", symbol: "leaf.arrow.triangle.circlepath")
        }
        let fraction = clamp(score)
        return DriveCarPlayTile(
            kind: .flow, title: "Regen", value: String(format: "%.0f", fraction * 100), unit: "%",
            note: "Kept", gauge: .ring(fraction: fraction), tone: .regen,
            symbol: "leaf.arrow.triangle.circlepath", isEstimate: true
        )
    }

    /// "180–214 mi" when the range band exists, else nil.
    static func bandText(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> String? {
        guard let low = finite(input.rangeLowMiles), let high = finite(input.rangeHighMiles) else { return nil }
        let lo = units.distance(fromKilometers: low * DriveUnitPreference.kmPerMile)
        let hi = units.distance(fromKilometers: high * DriveUnitPreference.kmPerMile)
        return "\(String(format: "%.0f–%.0f", lo, hi)) \(units.distanceLabel)"
    }

    static func speed(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        guard let kph = finite(input.speedKph), kph >= 0 else {
            return notRead(.speed, title: "Speed", symbol: "speedometer")
        }
        return DriveCarPlayTile(
            kind: .speed, title: "Speed", value: String(format: "%.0f", units.speed(fromKph: kph)),
            unit: units.speed.label, note: input.speedSource ?? "OBD",
            gauge: .arc(fraction: clamp(kph / speedScaleKph)), tone: .accent, symbol: "speedometer", isEstimate: false
        )
    }

    static func range(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        guard let miles = finite(input.rangeMiles), miles >= 0 else {
            return notRead(.range, title: "Range", symbol: "road.lanes", note: "Set pack and Wh/mi")
        }
        // A band mixes in this trip's measured Wh/mi, so it is always an estimate.
        let band = bandText(input, units: units)
        let estimate = input.planningUsesDefaults || band != nil
        return DriveCarPlayTile(
            kind: .range, title: "Range",
            value: String(format: "%.0f", units.distance(fromKilometers: miles * DriveUnitPreference.kmPerMile)),
            unit: units.distanceLabel,
            note: band.map { "\($0) est." } ?? (input.planningUsesDefaults ? "EPA default" : "Planning"),
            gauge: .symbol,
            tone: estimate ? .estimated : .accent,
            symbol: "road.lanes", isEstimate: estimate
        )
    }

    static func weatherRange(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        guard let miles = finite(input.weatherRangeMiles), miles >= 0 else {
            return notRead(.weatherRange, title: "Weather range", symbol: "cloud.sun.fill", estimate: true)
        }
        return DriveCarPlayTile(
            kind: .weatherRange, title: "Weather range",
            value: String(format: "%.0f", units.distance(fromKilometers: miles * DriveUnitPreference.kmPerMile)),
            unit: units.distanceLabel, note: "est.", gauge: .symbol, tone: .estimated,
            symbol: "cloud.sun.fill", isEstimate: true
        )
    }

    static func efficiency(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        guard let whPerMile = finite(input.whPerMile), whPerMile > 0 else {
            return notRead(.efficiency, title: "Efficiency", symbol: "leaf.fill", estimate: true)
        }
        let perMile = units.speed == .mph
        return DriveCarPlayTile(
            kind: .efficiency, title: "Efficiency",
            value: String(format: "%.0f", perMile ? whPerMile : whPerMile / DriveUnitPreference.kmPerMile),
            unit: perMile ? "Wh/mi" : "Wh/km", note: "est.", gauge: .symbol, tone: .estimated,
            symbol: "leaf.fill", isEstimate: true
        )
    }

    static func packTemp(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        guard let celsius = finite(input.packTempC) else {
            return notRead(.packTemp, title: "Pack", symbol: "thermometer.medium")
        }
        let band = DriveThresholds.packBand(celsius: celsius) ?? .nominal
        let tone: DriveCarPlayTile.Tone
        switch band {
        case .cold: tone = .cold
        case .nominal: tone = .accent
        case .warm: tone = .caution
        case .hot: tone = .critical
        }
        return DriveCarPlayTile(
            kind: .packTemp, title: "Pack",
            value: String(format: "%.0f", units.temperature(fromCelsius: celsius)),
            unit: units.temperature.label, note: band.rawValue.capitalized,
            gauge: .bar(fraction: clamp((celsius - packBarLowC) / (packBarHighC - packBarLowC))),
            tone: tone, symbol: "thermometer.medium", isEstimate: false
        )
    }

    static func rpm(_ input: DriveCarPlayTileInputs) -> DriveCarPlayTile {
        guard let rpm = finite(input.rpm), rpm >= 0 else {
            return notRead(.rpm, title: "RPM", symbol: "gauge.with.dots.needle.67percent")
        }
        return DriveCarPlayTile(
            kind: .rpm, title: "RPM", value: String(format: "%.0f", rpm), unit: "rpm", note: "OBD",
            gauge: .arc(fraction: clamp(rpm / rpmScale)), tone: .accent,
            symbol: "gauge.with.dots.needle.67percent", isEstimate: false
        )
    }

    static func coolant(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        guard let celsius = finite(input.coolantC) else {
            return notRead(.coolant, title: "Coolant", symbol: "thermometer.variable")
        }
        // No published limit to cite, so no bar and no warning color.
        return DriveCarPlayTile(
            kind: .coolant, title: "Coolant",
            value: String(format: "%.0f", units.temperature(fromCelsius: celsius)),
            unit: units.temperature.label, note: "OBD", gauge: .symbol, tone: .accent,
            symbol: "thermometer.variable", isEstimate: false
        )
    }

    static func fuel(_ input: DriveCarPlayTileInputs) -> DriveCarPlayTile {
        guard let percent = finite(input.fuelPercent) else {
            return notRead(.fuel, title: "Fuel", symbol: "fuelpump.fill")
        }
        return DriveCarPlayTile(
            kind: .fuel, title: "Fuel", value: String(format: "%.0f", percent), unit: "%", note: "In the tank",
            gauge: .bar(fraction: clamp(percent / 100)), tone: .accent, symbol: "fuelpump.fill", isEstimate: false
        )
    }

    static func moduleVolts(_ input: DriveCarPlayTileInputs) -> DriveCarPlayTile {
        guard let volts = finite(input.moduleVolts) else {
            return notRead(.moduleVolts, title: "12 V", symbol: "minus.plus.batteryblock")
        }
        let tone: DriveCarPlayTile.Tone
        switch DriveThresholds.moduleVoltsLevel(volts) {
        case .normal: tone = .accent
        case .caution: tone = .caution
        case .critical: tone = .critical
        }
        return DriveCarPlayTile(
            kind: .moduleVolts, title: "12 V", value: String(format: "%.1f", volts), unit: "V", note: "Module",
            gauge: .bar(fraction: clamp((volts - voltsBarLow) / (voltsBarHigh - voltsBarLow))),
            tone: tone, symbol: "minus.plus.batteryblock", isEstimate: false
        )
    }

    static func ambient(_ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        guard let celsius = finite(input.ambientC) else {
            return notRead(.ambient, title: "Outside", symbol: "thermometer.sun")
        }
        return DriveCarPlayTile(
            kind: .ambient, title: "Outside",
            value: String(format: "%.0f", units.temperature(fromCelsius: celsius)),
            unit: units.temperature.label, note: "OBD", gauge: .symbol, tone: .accent,
            symbol: "thermometer.sun", isEstimate: false
        )
    }

    // MARK: Detail card

    /// Adds the readout panel and gauge end labels for the large card.
    static func detailed(_ tile: DriveCarPlayTile, _ input: DriveCarPlayTileInputs, units: DriveUnitPreference) -> DriveCarPlayTile {
        var tile = tile
        tile.readouts = readouts(tile.kind, input, units: units)
        tile.scaleLabels = tile.gauge == nil ? nil : scaleLabels(tile.kind, input, units: units)
        return tile
    }

    static func readouts(
        _ kind: DriveCarPlayTile.Kind,
        _ input: DriveCarPlayTileInputs,
        units: DriveUnitPreference
    ) -> [DriveCarPlayTile.Readout] {
        typealias R = DriveCarPlayTile.Readout
        let range = R(label: "RANGE", value: distance(input.rangeMiles.map { $0 * DriveUnitPreference.kmPerMile }, units))
        let weather = R(label: "WEATHER", value: distance(input.weatherRangeMiles.map { $0 * DriveUnitPreference.kmPerMile }, units))
        let pack = R(label: "PACK", value: temperature(input.packTempC, units))
        let outside = R(label: "OUTSIDE", value: temperature(input.ambientC, units))
        let motor = R(label: "MOTOR", value: temperature(input.motorTempC, units))
        let coolant = R(label: "COOLANT", value: temperature(input.coolantC, units))
        let charge = R(label: "CHARGE", value: format(input.socPercent, "%.0f %%"))
        let amps = R(label: "HV AMPS", value: format(input.hvCurrentAmps, "%.0f A"))
        let net = R(label: "NET USED", value: format(input.netKWh, "%.1f kWh"))
        let regen = R(label: "RECOVERED", value: format(input.regenKWh, "%.1f kWh"))
        let trip = R(label: "TRIP", value: distance(input.tripKm, units, decimals: 1))
        let avg = R(label: "AVG", value: speed(input.avgSpeedKph, units))
        let top = R(label: "TOP", value: speed(input.maxSpeedKph, units))
        let speedNow = R(label: "SPEED", value: speed(input.speedKph, units))
        let rpm = R(label: "RPM", value: format(input.rpm, "%.0f"))
        let volts = R(label: "12 V", value: format(input.moduleVolts, "%.1f V"))
        let peak = R(
            label: "PEAK",
            value: input.peakPowerKW > 0
                ? "\(Int(units.power.convert(kilowatts: input.peakPowerKW).rounded())) \(units.power.label)"
                : missing
        )
        let torque = R(
            label: "TORQUE",
            value: finite(input.torqueNm).map {
                "\(Int(units.torque.convert(newtonMeters: abs($0)).rounded())) \(units.torque.label)"
            } ?? missing
        )
        let score = R(label: "REGEN SCORE", value: format(input.regenScore.map { $0 * 100 }, "%.0f %%"))
        let efficiency = R(label: "EFFICIENCY", value: whPer(input.whPerMile, units))

        switch kind {
        case .charge: return [range, pack, net]
        case .power: return [peak, torque, amps]
        case .flow: return [score, regen, amps]
        case .speed: return [avg, top, trip]
        case .range:
            // The card draws three readouts; the band takes the efficiency slot when it shows.
            if let band = bandText(input, units: units) {
                return [R(label: "BAND", value: band), charge, weather]
            }
            return [charge, weather, efficiency]
        case .weatherRange: return [range, outside, pack]
        case .efficiency: return [trip, net, regen]
        case .packTemp: return [motor, outside, charge]
        case .rpm: return [speedNow, coolant, volts]
        case .coolant: return [outside, rpm, volts]
        case .fuel: return [trip, avg, top]
        case .moduleVolts: return [speedNow, outside, trip]
        case .ambient: return [speedNow, volts, trip]
        }
    }

    static func scaleLabels(
        _ kind: DriveCarPlayTile.Kind,
        _ input: DriveCarPlayTileInputs,
        units: DriveUnitPreference
    ) -> DriveCarPlayTile.ScaleLabels? {
        typealias S = DriveCarPlayTile.ScaleLabels
        switch kind {
        case .charge, .fuel: return S(low: "E", high: "F")
        case .power: return S(low: "REGEN", high: "DRIVE")
        case .speed: return S(low: "0", high: String(format: "%.0f", units.speed(fromKph: speedScaleKph)))
        case .rpm: return S(low: "0", high: "8k")
        case .packTemp: return S(low: "COLD", high: "HOT")
        case .moduleVolts: return S(low: "11", high: "15")
        case .flow, .range, .weatherRange, .efficiency, .coolant, .ambient: return nil
        }
    }

    static func format(_ value: Double?, _ pattern: String) -> String {
        finite(value).map { String(format: pattern, $0) } ?? missing
    }

    static func temperature(_ celsius: Double?, _ units: DriveUnitPreference) -> String {
        finite(celsius).map { String(format: "%.0f", units.temperature(fromCelsius: $0)) + " " + units.temperature.label } ?? missing
    }

    static func speed(_ kph: Double?, _ units: DriveUnitPreference) -> String {
        guard let kph = finite(kph), kph >= 0 else { return missing }
        return String(format: "%.0f", units.speed(fromKph: kph)) + " " + units.speed.label
    }

    static func distance(_ km: Double?, _ units: DriveUnitPreference, decimals: Int = 0) -> String {
        guard let km = finite(km), km >= 0 else { return missing }
        return String(format: "%.\(decimals)f", units.distance(fromKilometers: km)) + " " + units.distanceLabel
    }

    static func whPer(_ whPerMile: Double?, _ units: DriveUnitPreference) -> String {
        guard let whPerMile = finite(whPerMile), whPerMile > 0 else { return missing }
        return units.speed == .mph
            ? String(format: "%.0f Wh/mi", whPerMile)
            : String(format: "%.0f Wh/km", whPerMile / DriveUnitPreference.kmPerMile)
    }

    // MARK: Helpers

    static func notRead(
        _ kind: DriveCarPlayTile.Kind,
        title: String,
        symbol: String,
        estimate: Bool = false,
        note: String = "Not read"
    ) -> DriveCarPlayTile {
        DriveCarPlayTile(
            kind: kind, title: title, value: missing, unit: "", note: note,
            gauge: nil, tone: .muted, symbol: symbol, isEstimate: estimate
        )
    }

    static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

// MARK: - Readings list

/// One row of CarPlay's readings list, e.g. "Charge" "88 %" "Displayed".
public struct DriveCarPlayReading: Equatable, Sendable {
    public var title: String
    public var value: String
    public var detail: String
    public var symbol: String

    public init(title: String, value: String, detail: String, symbol: String) {
        self.title = title
        self.value = value
        self.detail = detail
        self.symbol = symbol
    }
}

public struct DriveCarPlayReadingSection: Equatable, Sendable {
    public var header: String
    public var rows: [DriveCarPlayReading]

    public init(header: String, rows: [DriveCarPlayReading]) {
        self.header = header
        self.rows = rows
    }
}

/// Every value the app has, grouped for CarPlay's list. Missing values read "—".
public enum DriveCarPlayReadings {
    public static func make(
        _ input: DriveCarPlayTileInputs,
        units: DriveUnitPreference,
        link: String
    ) -> [DriveCarPlayReadingSection] {
        typealias T = DriveCarPlayTiles
        typealias Row = DriveCarPlayReading
        func row(_ tile: DriveCarPlayTile) -> Row {
            let reading = tile.value == T.missing || tile.unit.isEmpty ? tile.value : "\(tile.value) \(tile.unit)"
            return Row(title: tile.title, value: reading, detail: tile.note, symbol: tile.symbol)
        }
        func extra(_ title: String, _ value: String, _ detail: String, _ symbol: String) -> Row {
            Row(title: title, value: value, detail: value == T.missing ? "Not read" : detail, symbol: symbol)
        }
        let amps = extra("HV current", T.format(input.hvCurrentAmps, "%.0f A"), "OBD", "bolt.horizontal.fill")
        let motor = extra("Motor temp", T.temperature(input.motorTempC, units), "OBD", "engine.combustion.fill")
        let outside = extra("Outside", T.temperature(input.ambientC, units), "OBD", "thermometer.sun")
        let volts = extra("12 V", T.format(input.moduleVolts, "%.1f V"), "Module", "minus.plus.batteryblock")
        let torque = extra(
            "Torque",
            T.finite(input.torqueNm).map { "\(Int(units.torque.convert(newtonMeters: abs($0)).rounded())) \(units.torque.label)" } ?? T.missing,
            "est.", "gearshape.2.fill"
        )
        let peak = extra(
            "Peak power",
            input.peakPowerKW > 0 ? "\(Int(units.power.convert(kilowatts: input.peakPowerKW).rounded())) \(units.power.label)" : T.missing,
            "This trip, est.", "bolt.fill"
        )
        let top = extra("Top speed", T.speed(input.maxSpeedKph, units), "This trip", "gauge.high")
        let avg = extra("Avg speed", T.speed(input.avgSpeedKph, units), "Moving, this trip", "gauge.medium")
        let trip = extra("Trip", T.distance(input.tripKm, units, decimals: 1), "Since connect", "point.topleft.down.to.point.bottomright.curvepath")
        let net = extra("Energy used", T.format(input.netKWh, "%.1f kWh"), "Net, est.", "bolt.batteryblock")
        let recovered = extra("Recovered", T.format(input.regenKWh, "%.1f kWh"), "Regen, est.", "arrow.triangle.2.circlepath")
        let score = extra("Regen score", T.format(input.regenScore.map { $0 * 100 }, "%.0f %%"), "Braking energy kept", "leaf.arrow.triangle.circlepath")
        let linkRow = Row(title: "Link", value: link, detail: "", symbol: "antenna.radiowaves.left.and.right")

        switch input.layout {
        case .ev:
            return [
                DriveCarPlayReadingSection(header: "Battery", rows: [
                    row(T.charge(input)), row(T.power(input, units: units)), row(T.flow(input)),
                    amps, row(T.packTemp(input, units: units)), motor, volts,
                ]),
                DriveCarPlayReadingSection(header: "Range and energy", rows: [
                    row(T.range(input, units: units)), row(T.weatherRange(input, units: units)),
                    row(T.efficiency(input, units: units)), net, recovered, score,
                ]),
                DriveCarPlayReadingSection(header: "Drive", rows: [
                    row(T.speed(input, units: units)), torque, peak, top, avg, trip,
                ]),
                DriveCarPlayReadingSection(header: "Outside and link", rows: [outside, linkRow]),
            ]
        case .evStandard, .powertrain:
            var car = [row(T.speed(input, units: units))]
            if input.layout == .powertrain {
                car += [row(T.rpm(input)), row(T.coolant(input, units: units)), row(T.fuel(input))]
            }
            car += [volts, outside]
            return [
                DriveCarPlayReadingSection(header: "Car", rows: car),
                DriveCarPlayReadingSection(header: "Trip", rows: [top, avg, trip]),
                DriveCarPlayReadingSection(header: "Link", rows: [linkRow]),
            ]
        }
    }
}
