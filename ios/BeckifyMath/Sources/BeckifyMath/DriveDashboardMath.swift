import Foundation

// MARK: - Freshness

/// How a dashboard value should be drawn. Every card uses the same four states.
public enum DriveFreshness: Equatable, Sendable {
    /// Read within the last `staleAfter` seconds.
    case live
    /// Read earlier, still inside the reading book's expiry. Drawn dimmed with its age.
    case stale(ageSeconds: Int)
    /// Decoded outside the signal's plausibility range. Drawn as a dash and a warning glyph.
    case outOfRange
    /// Never read, expired, or not requested. Drawn as a dash.
    case notReported

    /// Older than this, a value is stale on the phone.
    public static let staleAfter: TimeInterval = 5

    public var showsValue: Bool {
        switch self {
        case .live, .stale: return true
        case .outOfRange, .notReported: return false
        }
    }

    public static func evaluate(
        sample: OBDSample?,
        now: Date,
        validRange: ClosedRange<Double>?,
        expireAfter: TimeInterval = OBDReadingBook.staleAfter
    ) -> DriveFreshness {
        guard let sample else { return .notReported }
        let age = now.timeIntervalSince(sample.at)
        guard age >= 0, age <= expireAfter else { return .notReported }
        guard sample.value.isFinite else { return .outOfRange }
        if let validRange, !validRange.contains(sample.value) { return .outOfRange }
        if age > staleAfter { return .stale(ageSeconds: Int(age.rounded(.down))) }
        return .live
    }
}

/// A value plus its freshness. `value` is nil unless the state shows a number.
public struct DriveValue: Equatable, Sendable {
    public var value: Double?
    public var freshness: DriveFreshness

    public init(value: Double?, freshness: DriveFreshness) {
        self.value = freshness.showsValue ? value : nil
        self.freshness = freshness
    }

    public static let notReported = DriveValue(value: nil, freshness: .notReported)

    public static func read(_ reading: OBDReading, from book: OBDReadingBook, now: Date) -> DriveValue {
        let sample = book.sample(reading)
        let range = DriveSignalTable.definition(for: reading)?.validRange
        let freshness = DriveFreshness.evaluate(sample: sample, now: now, validRange: range)
        return DriveValue(value: sample?.value, freshness: freshness)
    }
}

// MARK: - Thresholds

public enum DriveLevel: Equatable, Sendable {
    case normal
    case caution
    case critical
}

/// Bands for a temperature gauge. Only used where a source is cited below.
public enum DriveTemperatureBand: String, Equatable, Sendable {
    case cold
    case nominal
    case warm
    case hot

    public var level: DriveLevel {
        switch self {
        case .nominal: return .normal
        case .cold, .warm: return .caution
        case .hot: return .critical
        }
    }
}

public enum DriveThresholds {
    /// Low displayed-charge caution. App convention carried over from the
    /// first Drive ring color (amber under 15 %). Not a GM limit.
    public static let lowChargeCautionPercent = 15.0

    /// 12 V lead-acid resting voltage: about 12.2 V is half charged and
    /// under about 11.9 V is discharged (common flooded lead-acid open-circuit
    /// tables, e.g. Battery University BU-903). With the DC-DC converter
    /// running the bus normally reads 13–14.5 V, so a low reading while
    /// driving means the converter is not charging.
    public static let moduleVoltsCaution = 12.2
    public static let moduleVoltsCritical = 11.9

    /// Generic lithium-ion cell guidance, Battery University BU-410:
    /// charge between 0 °C and 45 °C; discharge between −20 °C and 60 °C.
    /// These are cell-level figures, not GM pack limits. The car's thermal
    /// management governs the real pack.
    public static let packColdBelowC = 0.0
    public static let packWarmFromC = 45.0
    public static let packHotFromC = 60.0

    // Motor temperature, coolant, and oil are left unthresholded: no
    // vehicle-specific limit is published for this app to cite.

    public static func chargeLevel(percent: Double?) -> DriveLevel {
        guard let percent else { return .normal }
        return percent < lowChargeCautionPercent ? .caution : .normal
    }

    public static func moduleVoltsLevel(_ volts: Double?) -> DriveLevel {
        guard let volts else { return .normal }
        if volts < moduleVoltsCritical { return .critical }
        if volts < moduleVoltsCaution { return .caution }
        return .normal
    }

    public static func packBand(celsius: Double?) -> DriveTemperatureBand? {
        guard let celsius else { return nil }
        if celsius < packColdBelowC { return .cold }
        if celsius >= packHotFromC { return .hot }
        if celsius >= packWarmFromC { return .warm }
        return .nominal
    }
}

// MARK: - HV current direction

/// Drive vs regen, from the sign of HV current only.
public enum HVFlowState: String, Equatable, Sendable {
    case drive
    case regen
    case idle

    /// Sign convention for `222414`: positive amps leave the pack (drive),
    /// negative amps enter it (regen or charge). This matches the published
    /// signed decode and the regen fixture in `OBDSessionMathTests`. Confirm it
    /// on a real car with the debug PID inspector.
    public static let dischargeIsPositive = true

    public static func from(amps: Double?) -> HVFlowState? {
        guard let amps, amps.isFinite else { return nil }
        if amps == 0 { return .idle }
        let leaving = dischargeIsPositive ? amps > 0 : amps < 0
        return leaving ? .drive : .regen
    }

    public var title: String {
        switch self {
        case .drive: return "Drive"
        case .regen: return "Regen"
        case .idle: return "Idle"
        }
    }
}

// MARK: - Sparkline buffer

/// The last `window` seconds of one signal, for a sparkline.
public struct SparklineBuffer: Equatable, Sendable {
    public struct Point: Equatable, Sendable, Identifiable {
        public var at: Date
        public var value: Double
        public var id: Date { at }

        public init(at: Date, value: Double) {
            self.at = at
            self.value = value
        }
    }

    public let window: TimeInterval
    public let capacity: Int
    public private(set) var points: [Point]

    public init(window: TimeInterval = 60, capacity: Int = 240) {
        self.window = window
        self.capacity = max(2, capacity)
        points = []
    }

    /// Adds one sample. Out-of-order and non-finite samples are dropped; a
    /// sample at the same instant as the last one replaces it.
    public mutating func append(_ value: Double, at: Date) {
        guard value.isFinite else { return }
        if let last = points.last {
            if at < last.at { return }
            if at == last.at {
                points[points.count - 1].value = value
                return
            }
        }
        points.append(Point(at: at, value: value))
        trim(now: at)
    }

    public func points(now: Date) -> [Point] {
        let cutoff = now.addingTimeInterval(-window)
        return points.filter { $0.at >= cutoff && $0.at <= now }
    }

    /// Min…max of the visible points. A flat line gets a small pad so the chart has height.
    public func range(now: Date) -> ClosedRange<Double>? {
        let visible = points(now: now).map(\.value)
        guard let low = visible.min(), let high = visible.max() else { return nil }
        if high - low < 0.000_1 {
            let pad = max(abs(high) * 0.05, 1)
            return (low - pad)...(high + pad)
        }
        return low...high
    }

    public mutating func removeAll() {
        points.removeAll()
    }

    private mutating func trim(now: Date) {
        let cutoff = now.addingTimeInterval(-window)
        if let first = points.firstIndex(where: { $0.at >= cutoff }), first > 0 {
            points.removeFirst(first)
        }
        if points.count > capacity {
            points.removeFirst(points.count - capacity)
        }
    }
}

// MARK: - Trip

/// On-device trip: distance, duration, moving average, and max speed.
/// Fed once a second with the best speed the phone has (OBD or GPS).
public struct DriveTripStats: Equatable, Sendable {
    /// Same gap rule as `OBDTripTrack`: longer gaps add no distance.
    public static let maxGap: TimeInterval = 8
    /// Below this the car counts as stopped for the moving average.
    public static let movingFloorKph = 2.0

    public private(set) var startedAt: Date?
    public private(set) var distanceKilometers: Double
    public private(set) var movingSeconds: TimeInterval
    public private(set) var maxSpeedKph: Double?
    private var lastAt: Date?
    private var lastSpeedKph: Double?

    public init() {
        startedAt = nil
        distanceKilometers = 0
        movingSeconds = 0
        maxSpeedKph = nil
        lastAt = nil
        lastSpeedKph = nil
    }

    public mutating func add(speedKph: Double?, at: Date) {
        let previousAt = lastAt
        let previousSpeed = lastSpeedKph
        guard let speedKph, speedKph.isFinite, speedKph >= 0, speedKph <= 300 else {
            lastAt = at
            lastSpeedKph = nil
            return
        }
        if startedAt == nil { startedAt = at }
        lastAt = at
        lastSpeedKph = speedKph
        maxSpeedKph = max(maxSpeedKph ?? 0, speedKph)
        guard let previousAt, let previousSpeed else { return }
        let dt = at.timeIntervalSince(previousAt)
        guard dt > 0, dt <= Self.maxGap else { return }
        let average = (speedKph + previousSpeed) / 2.0
        distanceKilometers += average * dt / 3600.0
        if average >= Self.movingFloorKph {
            movingSeconds += dt
        }
    }

    public func duration(now: Date) -> TimeInterval? {
        guard let startedAt else { return nil }
        return max(0, now.timeIntervalSince(startedAt))
    }

    /// Distance over moving time. Nil until the car has moved for a few seconds.
    public var averageMovingSpeedKph: Double? {
        guard movingSeconds >= 5 else { return nil }
        return distanceKilometers / (movingSeconds / 3600.0)
    }

    public mutating func reset() {
        self = DriveTripStats()
    }
}

// MARK: - Units

public enum DriveSpeedUnit: String, CaseIterable, Codable, Sendable {
    case mph
    case kmh

    public var label: String {
        switch self {
        case .mph: return "mph"
        case .kmh: return "km/h"
        }
    }

    public var spokenLabel: String {
        switch self {
        case .mph: return "miles per hour"
        case .kmh: return "kilometers per hour"
        }
    }
}

public enum DriveTemperatureUnit: String, CaseIterable, Codable, Sendable {
    case fahrenheit
    case celsius

    public var label: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }

    public var spokenLabel: String {
        switch self {
        case .fahrenheit: return "degrees Fahrenheit"
        case .celsius: return "degrees Celsius"
        }
    }
}

public struct DriveUnitPreference: Equatable, Sendable {
    public var speed: DriveSpeedUnit
    public var temperature: DriveTemperatureUnit

    public init(speed: DriveSpeedUnit, temperature: DriveTemperatureUnit) {
        self.speed = speed
        self.temperature = temperature
    }

    /// `identifier` is `Locale.MeasurementSystem.identifier`: `metric`, `us`, or `uk`.
    /// The UK drives in mph and reads the weather in °C.
    public static func systemDefault(measurementSystem identifier: String) -> DriveUnitPreference {
        switch identifier.lowercased() {
        case "us", "ussystem":
            return DriveUnitPreference(speed: .mph, temperature: .fahrenheit)
        case "uk", "uksystem":
            return DriveUnitPreference(speed: .mph, temperature: .celsius)
        default:
            return DriveUnitPreference(speed: .kmh, temperature: .celsius)
        }
    }

    public static let kmPerMile = 1.609344
    public static let metersPerFoot = 0.3048

    public func speed(fromKph kph: Double) -> Double {
        speed == .mph ? kph / Self.kmPerMile : kph
    }

    public func temperature(fromCelsius celsius: Double) -> Double {
        temperature == .fahrenheit ? celsius * 9.0 / 5.0 + 32.0 : celsius
    }

    public func distance(fromKilometers km: Double) -> Double {
        speed == .mph ? km / Self.kmPerMile : km
    }

    public var distanceLabel: String {
        speed == .mph ? "mi" : "km"
    }

    /// Altitude follows the speed unit: feet with mph, meters with km/h.
    public func altitude(fromMeters meters: Double) -> Double {
        speed == .mph ? meters / Self.metersPerFoot : meters
    }

    public var altitudeLabel: String {
        speed == .mph ? "ft" : "m"
    }
}
