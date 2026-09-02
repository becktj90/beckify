import Foundation

public struct OhmsLawResult: Equatable, Sendable {
    public var voltage: Double
    public var current: Double
    public var resistance: Double
    public var power: Double

    public var formula: String { "V = I × R    P = V × I" }

    public init(voltage: Double, current: Double, resistance: Double, power: Double) {
        self.voltage = voltage
        self.current = current
        self.resistance = resistance
        self.power = power
    }
}

/// Solve Ohm's law from any two of V, I, R. Power follows from P = V × I.
public enum OhmsLaw {
    public static func solve(voltage: Double?, current: Double?, resistance: Double?) throws -> OhmsLawResult {
        let hasV = voltage.flatMap { $0.isFinite ? $0 : nil }
        let hasI = current.flatMap { $0.isFinite ? $0 : nil }
        let hasR = resistance.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }

        var v = hasV
        var i = hasI
        var r = hasR
        let known = [v, i, r].compactMap { $0 }.count
        guard known == 2 else { throw CalcError.needTwoOfThree }

        if v == nil, let i, let r {
            v = i * r
        } else if i == nil, let v, let r {
            guard r != 0 else { throw CalcError.nonPositive("Resistance") }
            i = v / r
        } else if r == nil, let v, let i {
            guard i != 0 else { throw CalcError.nonPositive("Current") }
            r = v / i
        }

        guard let vv = v, let iv = i, let rv = r else { throw CalcError.needTwoOfThree }
        return OhmsLawResult(voltage: vv, current: iv, resistance: rv, power: vv * iv)
    }
}
