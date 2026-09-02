import Foundation

// MARK: - Voltage divider

public struct VoltageDividerResult: Equatable, Sendable {
    public var vin: Double
    public var vout: Double
    public var r1: Double
    public var r2: Double
    public var current: Double
    public var formula: String

    public init(vin: Double, vout: Double, r1: Double, r2: Double, current: Double, formula: String) {
        self.vin = vin
        self.vout = vout
        self.r1 = r1
        self.r2 = r2
        self.current = current
        self.formula = formula
    }
}

/// Unloaded divider: Vout is across R2 to ground. R1 is the top resistor.
public enum VoltageDivider {
    public static func fromResistors(vin: Double, r1: Double, r2: Double) throws -> VoltageDividerResult {
        let vs = try Positive.require(vin, name: "Vin")
        let top = try Positive.require(r1, name: "R1")
        let bottom = try Positive.require(r2, name: "R2")
        let vout = vs * bottom / (top + bottom)
        return VoltageDividerResult(
            vin: vs, vout: vout, r1: top, r2: bottom,
            current: vs / (top + bottom),
            formula: "Vout = Vin × R2 / (R1 + R2)"
        )
    }

    public static func solveR2(vin: Double, vout: Double, r1: Double) throws -> VoltageDividerResult {
        let vs = try Positive.require(vin, name: "Vin")
        let vo = try Positive.require(vout, name: "Vout")
        let top = try Positive.require(r1, name: "R1")
        guard vo < vs else { throw CalcError.outOfRange("Vout must be less than Vin for this divider.") }
        let bottom = vo * top / (vs - vo)
        return VoltageDividerResult(
            vin: vs, vout: vo, r1: top, r2: bottom,
            current: vs / (top + bottom),
            formula: "R2 = R1 × Vout / (Vin − Vout)"
        )
    }

    public static func solveR1(vin: Double, vout: Double, r2: Double) throws -> VoltageDividerResult {
        let vs = try Positive.require(vin, name: "Vin")
        let vo = try Positive.require(vout, name: "Vout")
        let bottom = try Positive.require(r2, name: "R2")
        guard vo < vs else { throw CalcError.outOfRange("Vout must be less than Vin for this divider.") }
        let top = bottom * (vs - vo) / vo
        return VoltageDividerResult(
            vin: vs, vout: vo, r1: top, r2: bottom,
            current: vs / (top + bottom),
            formula: "R1 = R2 × (Vin − Vout) / Vout"
        )
    }
}

// MARK: - Series / parallel

public enum NetworkKind: String, Sendable, Hashable {
    case series
    case parallel
}

public enum SeriesParallel {
    public static func resistors(_ values: [Double], kind: NetworkKind) throws -> Double {
        try combine(values, kind: kind, name: "Resistance", parallelMeansReciprocal: true)
    }

    public static func capacitors(_ values: [Double], kind: NetworkKind) throws -> Double {
        try combine(values, kind: kind, name: "Capacitance", parallelMeansReciprocal: false)
    }

    /// Resistors: series sums, parallel reciprocals. Capacitors are the opposite.
    private static func combine(_ values: [Double], kind: NetworkKind, name: String, parallelMeansReciprocal: Bool) throws -> Double {
        guard values.count >= 2 else { throw CalcError.missing("at least two \(name.lowercased()) values") }
        var parts: [Double] = []
        for (i, v) in values.enumerated() {
            parts.append(try Positive.require(v, name: "\(name) \(i + 1)"))
        }
        let reciprocal = (kind == .parallel) == parallelMeansReciprocal
        if reciprocal {
            let sumInv = parts.reduce(0.0) { $0 + 1.0 / $1 }
            guard sumInv > 0, sumInv.isFinite else { throw CalcError.outOfRange("\(name) combination is undefined.") }
            return 1.0 / sumInv
        }
        return parts.reduce(0, +)
    }
}

// MARK: - Resistor color code

public enum ResistorBand: String, CaseIterable, Sendable, Identifiable {
    case black, brown, red, orange, yellow, green, blue, violet, gray, white, gold, silver

    public var id: String { rawValue }

    public var displayName: String { rawValue.capitalized }

    public var digit: Int? {
        switch self {
        case .black: return 0
        case .brown: return 1
        case .red: return 2
        case .orange: return 3
        case .yellow: return 4
        case .green: return 5
        case .blue: return 6
        case .violet: return 7
        case .gray: return 8
        case .white: return 9
        case .gold, .silver: return nil
        }
    }

    public var multiplier: Double? {
        switch self {
        case .black: return 1
        case .brown: return 10
        case .red: return 100
        case .orange: return 1_000
        case .yellow: return 10_000
        case .green: return 100_000
        case .blue: return 1_000_000
        case .violet: return 10_000_000
        case .gray: return 100_000_000
        case .white: return 1_000_000_000
        case .gold: return 0.1
        case .silver: return 0.01
        }
    }

    public var tolerancePercent: Double? {
        switch self {
        case .brown: return 1
        case .red: return 2
        case .green: return 0.5
        case .blue: return 0.25
        case .violet: return 0.1
        case .gray: return 0.05
        case .gold: return 5
        case .silver: return 10
        default: return nil
        }
    }

    public static func fromDigit(_ d: Int) -> ResistorBand? {
        allCases.first { $0.digit == d }
    }

    public static func fromMultiplier(_ m: Double) -> ResistorBand? {
        allCases.first { band in
            guard let x = band.multiplier else { return false }
            return abs(x - m) / max(m, 1e-18) < 1e-9
        }
    }
}

public struct ColorCodeResult: Equatable, Sendable {
    public var ohms: Double
    public var tolerancePercent: Double
    public var bands: [ResistorBand]
    public var formula: String

    public init(ohms: Double, tolerancePercent: Double, bands: [ResistorBand], formula: String) {
        self.ohms = ohms
        self.tolerancePercent = tolerancePercent
        self.bands = bands
        self.formula = formula
    }
}

public enum ResistorColorCode {
    public static func decode4(d1: ResistorBand, d2: ResistorBand, multiplier: ResistorBand, tolerance: ResistorBand) throws -> ColorCodeResult {
        guard let a = d1.digit, let b = d2.digit else {
            throw CalcError.outOfRange("Gold and silver are not digit bands.")
        }
        guard let m = multiplier.multiplier else {
            throw CalcError.outOfRange("That band is not a multiplier.")
        }
        guard let t = tolerance.tolerancePercent else {
            throw CalcError.outOfRange("That band is not a tolerance.")
        }
        let ohms = (Double(a * 10 + b)) * m
        return ColorCodeResult(ohms: ohms, tolerancePercent: t, bands: [d1, d2, multiplier, tolerance], formula: "R = (10×d1 + d2) × 10^n")
    }

    public static func decode5(d1: ResistorBand, d2: ResistorBand, d3: ResistorBand, multiplier: ResistorBand, tolerance: ResistorBand) throws -> ColorCodeResult {
        guard let a = d1.digit, let b = d2.digit, let c = d3.digit else {
            throw CalcError.outOfRange("Gold and silver are not digit bands.")
        }
        guard let m = multiplier.multiplier else {
            throw CalcError.outOfRange("That band is not a multiplier.")
        }
        guard let t = tolerance.tolerancePercent else {
            throw CalcError.outOfRange("That band is not a tolerance.")
        }
        let ohms = (Double(a * 100 + b * 10 + c)) * m
        return ColorCodeResult(ohms: ohms, tolerancePercent: t, bands: [d1, d2, d3, multiplier, tolerance], formula: "R = (100×d1 + 10×d2 + d3) × 10^n")
    }

    public static func encode(ohms: Double, bands: Int, tolerance: ResistorBand = .gold) throws -> ColorCodeResult {
        let r = try Positive.require(ohms, name: "Resistance")
        guard bands == 4 || bands == 5 else {
            throw CalcError.outOfRange("Use 4-band or 5-band encoding.")
        }
        guard let t = tolerance.tolerancePercent else {
            throw CalcError.outOfRange("That band is not a tolerance.")
        }
        let digits = bands == 4 ? 2 : 3
        let significandMax = digits == 2 ? 99.0 : 999.0
        var mag = r
        var multiplier = 1.0
        while mag >= significandMax + 0.5 {
            mag /= 10
            multiplier *= 10
            if multiplier > 1_000_000_000 { throw CalcError.outOfRange("Resistance is too large for this color code.") }
        }
        while mag < pow(10, Double(digits - 1)) && multiplier > 0.01 {
            mag *= 10
            multiplier /= 10
        }
        var rounded = mag.rounded()
        if rounded >= pow(10, Double(digits)) {
            rounded /= 10
            multiplier *= 10
            if multiplier > 1_000_000_000 { throw CalcError.outOfRange("Resistance is too large for this color code.") }
        }
        guard let multBand = ResistorBand.fromMultiplier(multiplier) else {
            throw CalcError.outOfRange("No multiplier band for this value.")
        }
        var digitBands: [ResistorBand] = []
        var n = Int(rounded)
        var stack: [Int] = []
        for _ in 0..<digits {
            stack.append(n % 10)
            n /= 10
        }
        for d in stack.reversed() {
            guard let band = ResistorBand.fromDigit(d) else {
                throw CalcError.outOfRange("Could not encode a digit.")
            }
            digitBands.append(band)
        }
        let all = digitBands + [multBand, tolerance]
        let ohmsOut = rounded * multiplier
        return ColorCodeResult(
            ohms: ohmsOut,
            tolerancePercent: t,
            bands: all,
            formula: bands == 4 ? "4-band encode" : "5-band encode"
        )
    }
}

// MARK: - Units

public enum SIPrefix: String, CaseIterable, Sendable, Identifiable {
    case pico = "p"
    case nano = "n"
    case micro = "µ"
    case milli = "m"
    case none = ""
    case kilo = "k"
    case mega = "M"
    case giga = "G"

    public var id: String { rawValue.isEmpty ? "1" : rawValue }

    public var factor: Double {
        switch self {
        case .pico: return 1e-12
        case .nano: return 1e-9
        case .micro: return 1e-6
        case .milli: return 1e-3
        case .none: return 1
        case .kilo: return 1e3
        case .mega: return 1e6
        case .giga: return 1e9
        }
    }

    public var label: String {
        rawValue.isEmpty ? "(none)" : rawValue
    }
}

public enum UnitConvert {
    public static func si(value: Double, from: SIPrefix, to: SIPrefix) throws -> Double {
        guard value.isFinite else { throw CalcError.missing("Value") }
        return value * from.factor / to.factor
    }

    /// Voltage or current ratio: dB = 20 log10(ratio).
    public static func voltageDB(ratio: Double) throws -> Double {
        let r = try Positive.require(ratio, name: "Ratio")
        return 20 * log10(r)
    }

    public static func voltageRatio(fromDB db: Double) throws -> Double {
        guard db.isFinite else { throw CalcError.missing("dB") }
        return pow(10, db / 20)
    }

    /// Power ratio: dB = 10 log10(ratio).
    public static func powerDB(ratio: Double) throws -> Double {
        let r = try Positive.require(ratio, name: "Ratio")
        return 10 * log10(r)
    }

    public static func powerRatio(fromDB db: Double) throws -> Double {
        guard db.isFinite else { throw CalcError.missing("dB") }
        return pow(10, db / 10)
    }

    public static func celsius(fromFahrenheit f: Double) throws -> Double {
        guard f.isFinite else { throw CalcError.missing("Temperature") }
        return (f - 32) * 5 / 9
    }

    public static func fahrenheit(fromCelsius c: Double) throws -> Double {
        guard c.isFinite else { throw CalcError.missing("Temperature") }
        return c * 9 / 5 + 32
    }

    public static let metersPerFoot: Double = 0.3048
    public static let mmPerMil: Double = 0.0254

    public static func meters(fromFeet ft: Double) throws -> Double {
        guard ft.isFinite else { throw CalcError.missing("Length") }
        return ft * metersPerFoot
    }

    public static func feet(fromMeters m: Double) throws -> Double {
        guard m.isFinite else { throw CalcError.missing("Length") }
        return m / metersPerFoot
    }

    public static func mm(fromMils mils: Double) throws -> Double {
        guard mils.isFinite else { throw CalcError.missing("Length") }
        return mils * mmPerMil
    }

    public static func mils(fromMM mm: Double) throws -> Double {
        guard mm.isFinite else { throw CalcError.missing("Length") }
        return mm / mmPerMil
    }
}

// MARK: - Frequency / LC

public struct FrequencyResult: Equatable, Sendable {
    public var frequency: Double
    public var period: Double
    public var wavelength: Double
    public var formula: String

    public init(frequency: Double, period: Double, wavelength: Double, formula: String) {
        self.frequency = frequency
        self.period = period
        self.wavelength = wavelength
        self.formula = formula
    }
}

public enum Wave {
    public static let speedOfLight: Double = 299_792_458

    public static func fromFrequency(_ hz: Double) throws -> FrequencyResult {
        let f = try Positive.require(hz, name: "Frequency")
        return FrequencyResult(frequency: f, period: 1 / f, wavelength: speedOfLight / f, formula: "T = 1/f    λ = c/f")
    }

    public static func fromPeriod(_ seconds: Double) throws -> FrequencyResult {
        let t = try Positive.require(seconds, name: "Period")
        return try fromFrequency(1 / t)
    }

    public static func fromWavelength(_ meters: Double) throws -> FrequencyResult {
        let λ = try Positive.require(meters, name: "Wavelength")
        return try fromFrequency(speedOfLight / λ)
    }

    public static func lcResonance(inductance: Double, capacitance: Double) throws -> FrequencyResult {
        let l = try Positive.require(inductance, name: "L")
        let c = try Positive.require(capacitance, name: "C")
        let f = 1 / (2 * Double.pi * sqrt(l * c))
        return FrequencyResult(frequency: f, period: 1 / f, wavelength: speedOfLight / f, formula: "f = 1 / (2π √(LC))")
    }
}

// MARK: - LED + RC

public struct LEDResistorResult: Equatable, Sendable {
    public var resistance: Double
    public var current: Double
    public var drop: Double
    public var power: Double
    public var nearestE24: Double
    public var formula: String

    public init(resistance: Double, current: Double, drop: Double, power: Double, nearestE24: Double, formula: String) {
        self.resistance = resistance
        self.current = current
        self.drop = drop
        self.power = power
        self.nearestE24 = nearestE24
        self.formula = formula
    }
}

public struct RCTimeResult: Equatable, Sendable {
    public var tau: Double
    public var fiveTau: Double
    public var formula: String

    public init(tau: Double, fiveTau: Double, formula: String) {
        self.tau = tau
        self.fiveTau = fiveTau
        self.formula = formula
    }
}

public enum LEDResistor {
    public static let e24: [Double] = [
        1.0, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2.0, 2.2, 2.4, 2.7, 3.0,
        3.3, 3.6, 3.9, 4.3, 4.7, 5.1, 5.6, 6.2, 6.8, 7.5, 8.2, 9.1,
    ]

    public static func size(supply: Double, forward: Double, current: Double) throws -> LEDResistorResult {
        let vs = try Positive.require(supply, name: "Supply")
        let vf = try Positive.require(forward, name: "Vf")
        let i = try Positive.require(current, name: "Current")
        guard vs > vf else { throw CalcError.outOfRange("Supply must be greater than LED Vf.") }
        let drop = vs - vf
        let r = drop / i
        return LEDResistorResult(
            resistance: r,
            current: i,
            drop: drop,
            power: drop * i,
            nearestE24: nearestE24(r),
            formula: "R = (Vin − Vf) / If"
        )
    }

    public static func nearestE24(_ ohms: Double) -> Double {
        guard ohms.isFinite, ohms > 0 else { return .nan }
        let exp = floor(log10(ohms))
        let scale = pow(10, exp)
        let mant = ohms / scale
        let best = e24.min(by: { abs($0 - mant) < abs($1 - mant) }) ?? mant
        return best * scale
    }
}

public enum RCTime {
    public static func tau(resistance: Double, capacitance: Double) throws -> RCTimeResult {
        let r = try Positive.require(resistance, name: "R")
        let c = try Positive.require(capacitance, name: "C")
        let t = r * c
        return RCTimeResult(tau: t, fiveTau: 5 * t, formula: "τ = R × C    (~5τ to settle)")
    }
}
