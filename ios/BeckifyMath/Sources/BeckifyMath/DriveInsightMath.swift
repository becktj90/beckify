import Foundation

// MARK: - Trend

public enum TrendMath {
    /// Least-squares slope of y over x. Nil for fewer than two distinct x values.
    public static func slope(_ points: [(x: Double, y: Double)]) -> Double? {
        let clean = points.filter { $0.x.isFinite && $0.y.isFinite }
        guard clean.count >= 2 else { return nil }
        let n = Double(clean.count)
        let meanX = clean.map(\.x).reduce(0, +) / n
        let meanY = clean.map(\.y).reduce(0, +) / n
        var numerator = 0.0
        var denominator = 0.0
        for point in clean {
            numerator += (point.x - meanX) * (point.y - meanY)
            denominator += (point.x - meanX) * (point.x - meanX)
        }
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }

    /// Units per minute from a sparkline. Needs at least `minimumSpan` seconds of data.
    public static func slopePerMinute(_ points: [SparklineBuffer.Point], minimumSpan: TimeInterval = 30) -> Double? {
        guard let first = points.first, let last = points.last,
              last.at.timeIntervalSince(first.at) >= minimumSpan
        else { return nil }
        let pairs = points.map { (x: $0.at.timeIntervalSince(first.at) / 60, y: $0.value) }
        return slope(pairs)
    }
}

// MARK: - Preconditioning coach

/// Pack temperature against the fast-charge window.
public enum PreconditionCoach {
    /// Battery University BU-410, "Charging at High and Low Temperatures":
    /// Li-ion can be fast charged between 5 °C and 45 °C; below 5 °C the
    /// charge current should be reduced. Cell-level guidance, not GM's
    /// charge map. The car decides the real charge rate.
    public static let fastChargeLowC = 5.0
    public static let fastChargeHighC = 45.0

    public enum Advice: Equatable, Sendable {
        case unknown
        case inWindow
        /// `degrees` to warm; `minutes` only when the pack is already warming.
        case belowWindow(degrees: Double, minutes: Double?)
        case aboveWindow(degrees: Double, minutes: Double?)
    }

    /// `trendPerMinute` is the measured pack-temperature slope, °C/min.
    public static func advice(packC: Double?, trendPerMinute: Double?) -> Advice {
        guard let packC, packC.isFinite else { return .unknown }
        if packC < fastChargeLowC {
            let gap = fastChargeLowC - packC
            return .belowWindow(degrees: gap, minutes: minutes(gap: gap, rate: trendPerMinute))
        }
        if packC > fastChargeHighC {
            let gap = packC - fastChargeHighC
            return .aboveWindow(degrees: gap, minutes: minutes(gap: gap, rate: trendPerMinute.map { -$0 }))
        }
        return .inWindow
    }

    /// Minutes at the current rate, only when moving toward the window at a
    /// readable rate (≥ 0.05 °C/min) and under two hours away.
    static func minutes(gap: Double, rate: Double?) -> Double? {
        guard let rate, rate.isFinite, rate >= 0.05 else { return nil }
        let minutes = gap / rate
        return minutes <= 120 ? minutes : nil
    }
}

// MARK: - Road grade

/// Road grade from altitude against horizontal distance travelled.
public struct GradeEstimator: Equatable, Sendable {
    /// Fit over the last 200 m; need at least 40 m of travel for a number.
    public static let windowMeters = 200.0
    public static let minimumSpanMeters = 40.0
    /// Readouts past ±25 % are almost always altimeter noise on a road.
    public static let plausibleLimitPercent = 25.0

    private var samples: [Sample] = []

    struct Sample: Equatable, Sendable {
        var distance: Double
        var altitude: Double
    }

    public init() {}

    /// `distanceMeters` is a running horizontal distance; `altitudeMeters`
    /// prefers barometric relative altitude, which is steadier than GPS.
    public mutating func add(distanceMeters: Double, altitudeMeters: Double?) {
        guard distanceMeters.isFinite, let altitudeMeters, altitudeMeters.isFinite else { return }
        if let last = samples.last {
            if distanceMeters < last.distance { samples.removeAll() }
            else if distanceMeters - last.distance < 1 { return }
        }
        samples.append(Sample(distance: distanceMeters, altitude: altitudeMeters))
        let cutoff = distanceMeters - Self.windowMeters
        samples.removeAll { $0.distance < cutoff }
    }

    /// Grade, percent. Positive is uphill.
    public var gradePercent: Double? {
        guard let first = samples.first, let last = samples.last,
              last.distance - first.distance >= Self.minimumSpanMeters,
              let slope = TrendMath.slope(samples.map { (x: $0.distance, y: $0.altitude) })
        else { return nil }
        let percent = slope * 100
        return abs(percent) <= Self.plausibleLimitPercent ? percent : nil
    }

    public mutating func reset() {
        samples.removeAll()
    }
}

// MARK: - Capacity log (degradation curve)

/// One capacity reading per day, kept on the phone for the degradation chart.
public struct CapacityLog: Equatable, Sendable, Codable {
    public struct Entry: Equatable, Sendable, Codable, Identifiable {
        public var day: Date
        public var ampHours: Double
        public var id: Date { day }

        public init(day: Date, ampHours: Double) {
            self.day = day
            self.ampHours = ampHours
        }
    }

    public static let maxEntries = 1_100
    /// A trend needs a month of history and a few points.
    public static let minimumTrendDays = 30.0
    public static let minimumTrendEntries = 3

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries.sorted { $0.day < $1.day }
    }

    /// Start of the UTC day, so one reading per calendar day survives.
    public static func day(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.startOfDay(for: date)
    }

    /// Keeps the latest reading of each day. Values outside 0…300 Ah are ignored.
    public mutating func record(ampHours: Double, at date: Date) {
        guard ampHours.isFinite, ampHours > 0, ampHours <= 300 else { return }
        let day = Self.day(for: date)
        if let index = entries.firstIndex(where: { $0.day == day }) {
            entries[index].ampHours = ampHours
        } else {
            entries.append(Entry(day: day, ampHours: ampHours))
            entries.sort { $0.day < $1.day }
        }
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }

    /// Ah per year, least squares. Nil until there is a month of data.
    public var ampHoursPerYear: Double? {
        guard entries.count >= Self.minimumTrendEntries,
              let first = entries.first, let last = entries.last,
              last.day.timeIntervalSince(first.day) >= Self.minimumTrendDays * 86_400
        else { return nil }
        let points = entries.map { (x: $0.day.timeIntervalSince(first.day) / (365.25 * 86_400), y: $0.ampHours) }
        return TrendMath.slope(points)
    }

    /// Change since the first entry, percent.
    public var percentSinceFirst: Double? {
        guard entries.count >= 2, let first = entries.first, let last = entries.last, first.ampHours > 0 else { return nil }
        return (last.ampHours - first.ampHours) / first.ampHours * 100
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data?) -> CapacityLog {
        guard let data, let log = try? JSONDecoder().decode(CapacityLog.self, from: data) else { return CapacityLog() }
        return CapacityLog(entries: log.entries)
    }
}
