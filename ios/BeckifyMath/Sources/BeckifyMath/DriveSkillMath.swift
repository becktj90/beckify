import Foundation

/// How smooth the driving has been, best to worst. A smoothness label from the
/// phone's G sensor, speed and pedal: it says nothing about whether a driver is
/// impaired or safe.
public enum DriveSkillTier: String, CaseIterable, Sendable {
    case chauffeur
    case smooth
    case steady
    case spirited
    case rough
    case reckless

    public var title: String {
        switch self {
        case .chauffeur: return "Chauffeur"
        case .smooth: return "Smooth"
        case .steady: return "Steady"
        case .spirited: return "Spirited"
        case .rough: return "Rough"
        case .reckless: return "Reckless"
        }
    }

    /// Lowest score that earns the tier.
    public var lowerBound: Double {
        switch self {
        case .chauffeur: return 90
        case .smooth: return 75
        case .steady: return 60
        case .spirited: return 40
        case .rough: return 20
        case .reckless: return 0
        }
    }

    public static func tier(for score: Double) -> DriveSkillTier {
        let value = score.isFinite ? score : 0
        return allCases.first { value >= $0.lowerBound } ?? .reckless
    }
}

/// Scores driving smoothness from once-a-second G peaks, speed and pedal movement.
///
/// Each second the car is moving (8 km/h or more), the hardest braking, launch,
/// and cornering of that second are compared with comfort limits. The excess
/// builds penalty points, and the penalty fades with a half-life, so one hard
/// stop dents the score and smooth miles heal it. The score is 100 minus the
/// penalty. Nothing shows until 20 s of moving data, and time stopped is not scored.
///
/// When the phone's G sensor is not lined up with the car (no GPS course yet),
/// braking and launch come from the change in OBD or GPS speed instead; cornering
/// is not scored then.
public struct DriveSkillTracker: Equatable, Sendable {
    public static let movingKph = 8.0
    /// Gaps longer than this (app suspended, link lost) are not scored.
    public static let maxGapSeconds = 10.0

    // Comfort limit (no penalty up to here) and hard limit (full penalty at or above), in g.
    static let brake = (comfort: 0.15, hard: 0.40)
    static let accel = (comfort: 0.15, hard: 0.35)
    static let lateral = (comfort: 0.20, hard: 0.45)
    /// Pedal movement, percent per second.
    static let pedal = (comfort: 30.0, hard: 90.0)
    /// Penalty points per second at full roughness.
    static let pointsPerSecond = 40.0
    /// Lateral G that counts as a swerve when it flips sides within `weaveSeconds`.
    static let weaveG = 0.20
    static let weaveSeconds = 6.0
    static let weavePenalty = 6.0
    /// An event is counted when its normalized excess reaches this, once per run.
    static let eventStart = 0.6
    static let eventEnd = 0.3

    public let halfLifeSeconds: Double
    public let calibrationSeconds: Double
    public private(set) var movingSeconds = 0.0
    public private(set) var penalty = 0.0
    public private(set) var harshBrakes = 0
    public private(set) var harshAccels = 0
    public private(set) var hardCorners = 0
    public private(set) var weaves = 0

    private var lastAt: Date?
    private var lastSpeedKph: Double?
    private var lastThrottle: Double?
    private var lastLateralSign = 0.0
    private var lastLateralAt: Date?
    private var brakeActive = false
    private var accelActive = false
    private var cornerActive = false

    public init(halfLifeSeconds: Double = 90, calibrationSeconds: Double = 20) {
        self.halfLifeSeconds = max(1, halfLifeSeconds)
        self.calibrationSeconds = max(1, calibrationSeconds)
    }

    /// 0…100, higher is smoother. Nil until there is enough moving data.
    public var score: Double? {
        guard movingSeconds >= calibrationSeconds else { return nil }
        return min(100, max(0, 100 - penalty))
    }

    public var tier: DriveSkillTier? {
        score.map(DriveSkillTier.tier(for:))
    }

    /// 0…1 progress toward the first score.
    public var calibrationFraction: Double {
        min(1, movingSeconds / calibrationSeconds)
    }

    public mutating func add(window: GWindow?, speedKph: Double?, throttlePercent: Double?, at: Date) {
        let previousAt = lastAt
        let previousSpeed = lastSpeedKph
        let previousThrottle = lastThrottle
        lastAt = at
        lastSpeedKph = Self.finite(speedKph)
        lastThrottle = Self.finite(throttlePercent)

        guard let previousAt else { return }
        let dt = at.timeIntervalSince(previousAt)
        guard dt > 0, dt <= Self.maxGapSeconds else { return }

        penalty *= pow(0.5, dt / halfLifeSeconds)

        guard let speed = Self.finite(speedKph), speed >= Self.movingKph else {
            brakeActive = false
            accelActive = false
            cornerActive = false
            return
        }
        movingSeconds += dt

        var brakeG = 0.0
        var accelG = 0.0
        var lateralG = 0.0
        if let window, window.samples > 0 {
            brakeG = window.peakBrakeG
            accelG = window.peakAccelG
            lateralG = window.peakLateralG
        } else if let previousSpeed {
            let g = min(1.5, max(-1.5, (speed - previousSpeed) / 3.6 / 9.80665 / dt))
            if g < 0 { brakeG = -g } else { accelG = g }
        }

        let xBrake = Self.normalized(brakeG, Self.brake)
        let xAccel = Self.normalized(accelG, Self.accel)
        let xLateral = Self.normalized(abs(lateralG), Self.lateral)
        var xPedal = 0.0
        if let throttle = Self.finite(throttlePercent), let previousThrottle {
            xPedal = Self.normalized(abs(throttle - previousThrottle) / dt, Self.pedal)
        }

        let roughness = min(1, 0.55 * xBrake + 0.40 * xAccel + 0.50 * xLateral + 0.15 * xPedal)
        penalty += roughness * roughness * Self.pointsPerSecond * dt

        Self.count(xBrake, active: &brakeActive, events: &harshBrakes)
        Self.count(xAccel, active: &accelActive, events: &harshAccels)
        Self.count(xLateral, active: &cornerActive, events: &hardCorners)

        if abs(lateralG) >= Self.weaveG {
            let sign: Double = lateralG > 0 ? 1 : -1
            if lastLateralSign != 0, sign != lastLateralSign,
               let lastLateralAt, at.timeIntervalSince(lastLateralAt) <= Self.weaveSeconds {
                weaves += 1
                penalty += Self.weavePenalty
            }
            lastLateralSign = sign
            lastLateralAt = at
        }
    }

    public mutating func reset() {
        self = DriveSkillTracker(halfLifeSeconds: halfLifeSeconds, calibrationSeconds: calibrationSeconds)
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private static func normalized(_ value: Double, _ limits: (comfort: Double, hard: Double)) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, (value - limits.comfort) / (limits.hard - limits.comfort)))
    }

    private static func count(_ excess: Double, active: inout Bool, events: inout Int) {
        if excess >= eventStart {
            if !active {
                events += 1
                active = true
            }
        } else if excess < eventEnd {
            active = false
        }
    }
}
