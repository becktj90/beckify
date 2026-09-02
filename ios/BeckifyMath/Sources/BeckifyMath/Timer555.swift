import Foundation

public struct Astable555Result: Equatable, Sendable {
    public var timeHigh: Double
    public var timeLow: Double
    public var period: Double
    public var frequency: Double
    public var dutyPercent: Double
    public var diodeSteering: Bool
    public var formula: String

    public init(
        timeHigh: Double,
        timeLow: Double,
        period: Double,
        frequency: Double,
        dutyPercent: Double,
        diodeSteering: Bool,
        formula: String
    ) {
        self.timeHigh = timeHigh
        self.timeLow = timeLow
        self.period = period
        self.frequency = frequency
        self.dutyPercent = dutyPercent
        self.diodeSteering = diodeSteering
        self.formula = formula
    }
}

public struct Monostable555Result: Equatable, Sendable {
    public var pulseWidth: Double
    public var maxRetriggerHz: Double
    public var formula: String

    public init(pulseWidth: Double, maxRetriggerHz: Double, formula: String) {
        self.pulseWidth = pulseWidth
        self.maxRetriggerHz = maxRetriggerHz
        self.formula = formula
    }
}

/// 555 timer. Coefficients come from the 1/3–2/3 Vcc divider: ln(2) astable, ln(3) monostable.
public enum Timer555 {
    public static let ln2 = Foundation.log(2.0)
    public static let ln3 = Foundation.log(3.0)

    public static func astable(r1: Double, r2: Double, capacitance: Double, diodeSteering: Bool) throws -> Astable555Result {
        let R1 = try Positive.require(r1, name: "R1")
        let R2 = try Positive.require(r2, name: "R2")
        let C = try Positive.require(capacitance, name: "C")
        let tHigh = diodeSteering ? ln2 * R1 * C : ln2 * (R1 + R2) * C
        let tLow = ln2 * R2 * C
        let period = tHigh + tLow
        let freq = 1 / period
        let duty = (tHigh / period) * 100
        let formula = diodeSteering
            ? "t1 = ln(2) × R1 × C    t2 = ln(2) × R2 × C    D = R1 / (R1 + R2)"
            : "t1 = ln(2) × (R1 + R2) × C    t2 = ln(2) × R2 × C    f ≈ 1.44 / ((R1 + 2·R2) × C)"
        return Astable555Result(
            timeHigh: tHigh,
            timeLow: tLow,
            period: period,
            frequency: freq,
            dutyPercent: duty,
            diodeSteering: diodeSteering,
            formula: formula
        )
    }

    public static func monostable(resistance: Double, capacitance: Double) throws -> Monostable555Result {
        let r = try Positive.require(resistance, name: "R")
        let c = try Positive.require(capacitance, name: "C")
        let t = ln3 * r * c
        return Monostable555Result(
            pulseWidth: t,
            maxRetriggerHz: 1 / t,
            formula: "t = ln(3) × R × C ≈ 1.1 × R × C"
        )
    }
}
