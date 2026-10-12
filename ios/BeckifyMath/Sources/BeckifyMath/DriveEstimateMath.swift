import Foundation

// Estimates for Beckify Drive. Every value here is derived from measured PIDs
// plus a stated assumption. The dashboard badges each one "est." and shows the
// assumption next to it. Nothing here is a decode of the car's own figure.

// MARK: - Power and torque

public enum DriveEstimates {
    /// Bolt EV / EUV pack: 96 cell groups in series. 96 × 3.65 V nominal NMC
    /// cell ≈ 350 V, which is GM's published nominal pack voltage. Real pack
    /// voltage sags under load and rises with charge, so power is an estimate.
    public static let boltNominalPackVolts = 350.0

    /// 215/50R17 (Bolt EV stock tire): 17 in rim (431.8 mm) + 2 × 107.5 mm
    /// sidewall = 646.8 mm diameter, 0.323 m free radius. 0.32 m allows for
    /// deflection under load.
    public static let boltWheelRadiusMeters = 0.32

    /// Below this, P × r / v blows up toward standstill, so torque shows a dash.
    public static let torqueMinimumSpeedMps = 3.0

    /// Bolt EV curb weight 3,563 lb (1,616 kg, GM 2017 spec) plus an 80 kg driver.
    public static let boltTestMassKg = 1_696.0

    public static let gravity = 9.806_65

    /// Pack power, kW: nominal volts × HV current. + is drive, − is regen.
    public static func packPowerKW(amps: Double?, volts: Double = boltNominalPackVolts) -> Double? {
        guard let amps, amps.isFinite, volts > 0 else { return nil }
        return volts * amps / 1_000
    }

    /// Regen power magnitude, kW. Nil unless current is flowing into the pack.
    public static func regenPowerKW(amps: Double?, volts: Double = boltNominalPackVolts) -> Double? {
        guard let power = packPowerKW(amps: amps, volts: volts), power < 0 else { return nil }
        return -power
    }

    /// Wheel torque, N·m: τ = P × r / v. Pack power with no drivetrain loss, so
    /// it reads high in drive and low in regen. Negative while regenerating.
    public static func wheelTorqueNm(
        powerKW: Double?,
        speedKph: Double?,
        radiusMeters: Double = boltWheelRadiusMeters
    ) -> Double? {
        guard let powerKW, let speedKph, powerKW.isFinite, speedKph.isFinite, radiusMeters > 0 else { return nil }
        let mps = speedKph / 3.6
        guard mps >= torqueMinimumSpeedMps else { return nil }
        return powerKW * 1_000 * radiusMeters / mps
    }
}

// MARK: - Power and torque units

public enum DrivePowerUnit: String, CaseIterable, Codable, Sendable {
    case kilowatts
    case horsepower

    /// 1 mechanical horsepower = 745.699872 W.
    public static let wattsPerHorsepower = 745.699_872

    public var label: String {
        switch self {
        case .kilowatts: return "kW"
        case .horsepower: return "hp"
        }
    }

    public var spokenLabel: String {
        switch self {
        case .kilowatts: return "kilowatts"
        case .horsepower: return "horsepower"
        }
    }

    public func convert(kilowatts: Double) -> Double {
        switch self {
        case .kilowatts: return kilowatts
        case .horsepower: return kilowatts * 1_000 / Self.wattsPerHorsepower
        }
    }
}

public enum DriveTorqueUnit: String, CaseIterable, Codable, Sendable {
    case newtonMeters
    case poundFeet

    /// 1 lbf·ft = 1.3558179483 N·m.
    public static let newtonMetersPerPoundFoot = 1.355_817_948_3

    public var label: String {
        switch self {
        case .newtonMeters: return "Nm"
        case .poundFeet: return "lb-ft"
        }
    }

    public var spokenLabel: String {
        switch self {
        case .newtonMeters: return "newton meters"
        case .poundFeet: return "pound feet"
        }
    }

    public func convert(newtonMeters: Double) -> Double {
        switch self {
        case .newtonMeters: return newtonMeters
        case .poundFeet: return newtonMeters / Self.newtonMetersPerPoundFoot
        }
    }
}

// MARK: - True efficiency

/// Real Wh/mi from displayed-charge burn over GPS distance. The pack size is
/// the user's typed figure, so the result is an estimate.
public struct EfficiencyTracker: Equatable, Sendable {
    /// Displayed charge moves in 100/255 ≈ 0.4 % steps; wait for a real drop.
    public static let minimumSocDropPercent = 1.0
    public static let minimumMiles = 1.0

    public private(set) var startSocPercent: Double?
    public private(set) var startMiles: Double?
    public private(set) var lastSocPercent: Double?
    public private(set) var lastMiles: Double?

    public init() {}

    /// `gpsMiles` is a running GPS distance. Displayed charge is the measured PID.
    public mutating func update(socPercent: Double?, gpsMiles: Double) {
        guard let socPercent, socPercent.isFinite, gpsMiles.isFinite else { return }
        if startSocPercent == nil {
            startSocPercent = socPercent
            startMiles = gpsMiles
        }
        lastSocPercent = socPercent
        lastMiles = gpsMiles
    }

    public var socDropPercent: Double? {
        guard let startSocPercent, let lastSocPercent else { return nil }
        return startSocPercent - lastSocPercent
    }

    public var miles: Double? {
        guard let startMiles, let lastMiles else { return nil }
        return lastMiles - startMiles
    }

    public func whPerMile(packKWh: Double?) -> Double? {
        guard let packKWh, packKWh > 0, packKWh <= 200,
              let drop = socDropPercent, drop >= Self.minimumSocDropPercent,
              let miles, miles >= Self.minimumMiles
        else { return nil }
        return drop / 100 * packKWh * 1_000 / miles
    }

    public mutating func reset() {
        self = EfficiencyTracker()
    }
}

// MARK: - Regen score

/// Share of braking energy returned to the pack: regen energy (nominal volts ×
/// current into the pack) over kinetic energy shed while slowing (½ m Δv²).
/// Both sides are estimates; friction braking, grade, and drag are not split out.
public struct RegenScoreTracker: Equatable, Sendable {
    public static let maxGap: TimeInterval = 8
    /// Below this much slowing energy (about one stop from 25 km/h) there is no score.
    public static let minimumDecelJoules = 40_000.0

    public let massKg: Double
    public let packVolts: Double
    public private(set) var decelJoules: Double = 0
    public private(set) var regenJoules: Double = 0
    private var last: (speedMps: Double, amps: Double, at: Date)?

    public init(massKg: Double = DriveEstimates.boltTestMassKg, packVolts: Double = DriveEstimates.boltNominalPackVolts) {
        self.massKg = massKg
        self.packVolts = packVolts
    }

    public static func == (lhs: RegenScoreTracker, rhs: RegenScoreTracker) -> Bool {
        lhs.decelJoules == rhs.decelJoules && lhs.regenJoules == rhs.regenJoules && lhs.massKg == rhs.massKg
    }

    public mutating func add(speedKph: Double?, amps: Double?, at: Date) {
        guard let speedKph, let amps, speedKph.isFinite, amps.isFinite, speedKph >= 0 else {
            last = nil
            return
        }
        let speed = speedKph / 3.6
        defer { last = (speed, amps, at) }
        guard let last else { return }
        let dt = at.timeIntervalSince(last.at)
        guard dt > 0, dt <= Self.maxGap else { return }
        if speed < last.speedMps {
            decelJoules += 0.5 * massKg * (last.speedMps * last.speedMps - speed * speed)
            let averageAmps = (amps + last.amps) / 2
            if averageAmps < 0 {
                regenJoules += packVolts * -averageAmps * dt
            }
        }
    }

    /// 0…1. Capped at 1 because the nominal-volt estimate can overshoot.
    public var score: Double? {
        guard decelJoules >= Self.minimumDecelJoules else { return nil }
        return min(regenJoules / decelJoules, 1)
    }

    public mutating func reset() {
        self = RegenScoreTracker(massKg: massKg, packVolts: packVolts)
    }
}

// MARK: - Trip energy breakdown

/// Splits trip pack energy (nominal volts × current, integrated) into
/// estimated buckets. Climate and battery conditioning cannot be told apart
/// from the PIDs read, so they share the "while stopped" bucket, and the same
/// draw while moving lands in "driving".
public struct TripEnergyLedger: Equatable, Sendable {
    public static let maxGap: TimeInterval = 8
    public static let stoppedBelowKph = 1.0

    public let massKg: Double
    public let packVolts: Double
    /// Out of the pack while moving, minus the climb share.
    public private(set) var movingJoules: Double = 0
    /// Potential energy gained climbing, m·g·Δh. Not adjusted for drivetrain loss.
    public private(set) var climbJoules: Double = 0
    /// Out of the pack while stopped: climate, battery conditioning, 12 V.
    public private(set) var stoppedJoules: Double = 0
    /// Back into the pack.
    public private(set) var regenJoules: Double = 0
    private var lastAt: Date?
    private var lastAltitude: Double?

    public init(massKg: Double = DriveEstimates.boltTestMassKg, packVolts: Double = DriveEstimates.boltNominalPackVolts) {
        self.massKg = massKg
        self.packVolts = packVolts
    }

    public mutating func add(amps: Double?, speedKph: Double?, altitudeMeters: Double?, at: Date) {
        defer {
            lastAt = at
            if let altitudeMeters, altitudeMeters.isFinite { lastAltitude = altitudeMeters }
        }
        guard let lastAt else { return }
        let dt = at.timeIntervalSince(lastAt)
        guard dt > 0, dt <= Self.maxGap, let amps, amps.isFinite else { return }
        let joules = packVolts * amps * dt
        let moving = (speedKph ?? 0) >= Self.stoppedBelowKph
        if joules < 0 {
            regenJoules += -joules
        } else if moving {
            movingJoules += joules
        } else {
            stoppedJoules += joules
        }
        if moving, let altitudeMeters, let lastAltitude, altitudeMeters > lastAltitude {
            climbJoules += massKg * DriveEstimates.gravity * (altitudeMeters - lastAltitude)
        }
    }

    public var drivingKWh: Double { max(movingJoules - climbJoules, 0) / 3.6e6 }
    /// Never more than what left the pack while moving.
    public var climbKWh: Double { min(climbJoules, movingJoules) / 3.6e6 }
    public var stoppedKWh: Double { stoppedJoules / 3.6e6 }
    public var regenKWh: Double { regenJoules / 3.6e6 }
    public var netKWh: Double { (movingJoules + stoppedJoules - regenJoules) / 3.6e6 }
    public var isEmpty: Bool { movingJoules == 0 && stoppedJoules == 0 && regenJoules == 0 }

    public mutating func reset() {
        self = TripEnergyLedger(massKg: massKg, packVolts: packVolts)
    }
}

// MARK: - Weather-adjusted range

public enum RangeWeatherModel {
    /// AAA, "Electric Vehicle Range Testing", Feb 2019: with HVAC in use, range
    /// fell 41 % at 20 °F and 17 % at 95 °F against the 75 °F baseline.
    /// Linear between those points and held flat outside them.
    public static let temperaturePointsF: [(f: Double, fraction: Double)] = [
        (20, -0.41), (75, 0), (95, -0.17),
    ]

    /// Air density at 15 °C, sea level (ISA).
    public static let airDensity = 1.225
    /// GM 2017 Bolt EV drag coefficient, 0.308.
    public static let dragCoefficient = 0.308
    /// Assumed frontal area, m². GM does not publish one.
    public static let frontalAreaM2 = 2.4
    /// Assumed rolling-resistance coefficient for low-rolling-resistance EV tires.
    public static let rollingResistance = 0.009
    /// Below this the wind term is noise next to accessories, so no adjustment.
    public static let windMinimumKph = 25.0

    /// Range change from temperature alone (−0.41 = 41 % less range).
    public static func temperatureFraction(celsius: Double?) -> Double? {
        guard let celsius, celsius.isFinite else { return nil }
        let f = celsius * 9 / 5 + 32
        let points = temperaturePointsF
        if f <= points[0].f { return points[0].fraction }
        if f >= points[points.count - 1].f { return points[points.count - 1].fraction }
        for (a, b) in zip(points, points.dropFirst()) where f <= b.f {
            let t = (f - a.f) / (b.f - a.f)
            return a.fraction + t * (b.fraction - a.fraction)
        }
        return nil
    }

    /// Headwind component, m/s. Positive into the car's face. `windFromDegrees`
    /// is meteorological (where it blows from); course is where the car heads.
    public static func headwindMps(windSpeedMps: Double?, windFromDegrees: Double?, courseDegrees: Double?) -> Double? {
        guard let windSpeedMps, let windFromDegrees, let courseDegrees,
              windSpeedMps.isFinite, windFromDegrees.isFinite, courseDegrees.isFinite, courseDegrees >= 0
        else { return nil }
        let delta = (windFromDegrees - courseDegrees) * .pi / 180
        return windSpeedMps * cos(delta)
    }

    /// Range change from headwind at a steady speed (−0.08 = 8 % less range).
    /// Road-load energy per meter: ½ρCdA·v_air² + Crr·m·g.
    public static func headwindFraction(speedKph: Double?, headwindMps: Double?, massKg: Double = DriveEstimates.boltTestMassKg) -> Double? {
        guard let speedKph, let headwindMps, speedKph >= windMinimumKph, headwindMps.isFinite else { return nil }
        let v = speedKph / 3.6
        let air = max(v + headwindMps, 0)
        let rolling = rollingResistance * massKg * DriveEstimates.gravity
        let aero = 0.5 * airDensity * dragCoefficient * frontalAreaM2
        let still = aero * v * v + rolling
        let windy = aero * air * air + rolling
        guard still > 0, windy > 0 else { return nil }
        return still / windy - 1
    }

    public struct Adjustment: Equatable, Sendable {
        public var baseMiles: Double
        public var temperatureFraction: Double?
        public var headwindFraction: Double?

        public var adjustedMiles: Double {
            baseMiles * (1 + (temperatureFraction ?? 0)) * (1 + (headwindFraction ?? 0))
        }
    }

    public static func adjust(baseMiles: Double?, celsius: Double?, speedKph: Double?, headwindMps: Double?) -> Adjustment? {
        guard let baseMiles, baseMiles > 0 else { return nil }
        let temperature = temperatureFraction(celsius: celsius)
        let wind = headwindFraction(speedKph: speedKph, headwindMps: headwindMps)
        guard temperature != nil || wind != nil else { return nil }
        return Adjustment(baseMiles: baseMiles, temperatureFraction: temperature, headwindFraction: wind)
    }
}

// MARK: - Open-Meteo

/// Current conditions from Open-Meteo (open-meteo.com, no key). Coordinates
/// are rounded to 0.01° (about 1 km) before they leave the phone.
public struct OpenMeteoCurrent: Equatable, Sendable, Codable {
    public var temperatureC: Double
    public var windSpeedMps: Double
    public var windFromDegrees: Double
    public var fetchedAt: Date
    public var latitude: Double
    public var longitude: Double

    public init(temperatureC: Double, windSpeedMps: Double, windFromDegrees: Double, fetchedAt: Date, latitude: Double, longitude: Double) {
        self.temperatureC = temperatureC
        self.windSpeedMps = windSpeedMps
        self.windFromDegrees = windFromDegrees
        self.fetchedAt = fetchedAt
        self.latitude = latitude
        self.longitude = longitude
    }

    public static func roundedCoordinate(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    public static func requestURL(latitude: Double, longitude: Double) -> URL? {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180 else { return nil }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", roundedCoordinate(latitude))),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", roundedCoordinate(longitude))),
            URLQueryItem(name: "current", value: "temperature_2m,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "wind_speed_unit", value: "ms"),
        ]
        return components?.url
    }

    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let wind_speed_10m: Double
            let wind_direction_10m: Double
        }
        let latitude: Double
        let longitude: Double
        let current: Current
    }

    public static func decode(_ data: Data, fetchedAt: Date) -> OpenMeteoCurrent? {
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
        let current = response.current
        guard current.temperature_2m.isFinite, current.wind_speed_10m >= 0, (0...360).contains(current.wind_direction_10m) else {
            return nil
        }
        return OpenMeteoCurrent(
            temperatureC: current.temperature_2m,
            windSpeedMps: current.wind_speed_10m,
            windFromDegrees: current.wind_direction_10m,
            fetchedAt: fetchedAt,
            latitude: response.latitude,
            longitude: response.longitude
        )
    }

    /// Refetch after 15 minutes or about 10 km of travel.
    public static let refreshAfter: TimeInterval = 15 * 60
    public static let refreshAfterKm = 10.0
    /// Older than this, the dashboard says the weather is stale and stops adjusting range.
    public static let usableFor: TimeInterval = 3 * 60 * 60

    public func needsRefresh(now: Date, latitude: Double, longitude: Double) -> Bool {
        if now.timeIntervalSince(fetchedAt) >= Self.refreshAfter { return true }
        return Self.distanceKm(self.latitude, self.longitude, latitude, longitude) >= Self.refreshAfterKm
    }

    public func isUsable(now: Date) -> Bool {
        let age = now.timeIntervalSince(fetchedAt)
        return age >= 0 && age <= Self.usableFor
    }

    /// Haversine on a 6371 km sphere.
    public static func distanceKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6_371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(a.squareRoot(), (1 - a).squareRoot())
    }
}
