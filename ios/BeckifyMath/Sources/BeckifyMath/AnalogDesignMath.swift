import Foundation

// MARK: - Preferred resistor decades (IEC 60063)

/// IEC E24 / E96 decades. Used as a stocking hint, not a guarantee the part exists.
public enum PreferredSeries: String, Sendable, Hashable {
    case e24
    case e96

    public static let e24Mantissas: [Double] = LEDResistor.e24

    public static let e96Mantissas: [Double] = [
        1.00, 1.02, 1.05, 1.07, 1.10, 1.13, 1.15, 1.18, 1.21, 1.24, 1.27, 1.30,
        1.33, 1.37, 1.40, 1.43, 1.47, 1.50, 1.54, 1.58, 1.62, 1.65, 1.69, 1.74,
        1.78, 1.82, 1.87, 1.91, 1.96, 2.00, 2.05, 2.10, 2.15, 2.21, 2.26, 2.32,
        2.37, 2.43, 2.49, 2.55, 2.61, 2.67, 2.74, 2.80, 2.87, 2.94, 3.01, 3.09,
        3.16, 3.24, 3.32, 3.40, 3.48, 3.57, 3.65, 3.74, 3.83, 3.92, 4.02, 4.12,
        4.22, 4.32, 4.42, 4.53, 4.64, 4.75, 4.87, 4.99, 5.11, 5.23, 5.36, 5.49,
        5.62, 5.76, 5.90, 6.04, 6.19, 6.34, 6.49, 6.65, 6.81, 6.98, 7.15, 7.32,
        7.50, 7.68, 7.87, 8.06, 8.25, 8.45, 8.66, 8.87, 9.09, 9.31, 9.53, 9.76,
    ]

    public static func nearest(_ value: Double, series: PreferredSeries = .e24) -> Double {
        guard value.isFinite, value > 0 else { return .nan }
        let mantissas = series == .e24 ? e24Mantissas : e96Mantissas
        let exp = floor(log10(value))
        let scale = pow(10, exp)
        let mant = value / scale
        let candidates = mantissas + [10.0]
        let best = candidates.min(by: { abs($0 - mant) < abs($1 - mant) }) ?? mant
        return best * scale
    }
}

public struct PreferredPick: Equatable, Sendable {
    public var name: String
    public var exact: Double
    public var nearest: Double

    public init(name: String, exact: Double, nearest: Double) {
        self.name = name
        self.exact = exact
        self.nearest = nearest
    }
}

// MARK: - Op-amp golden-rule stages

public enum OpAmpTopology: String, CaseIterable, Sendable, Hashable {
    case inverting
    case noninverting
    case follower
    case difference
    case summing
    case integrator
    case differentiator

    public var displayName: String {
        switch self {
        case .inverting: return "Inverting"
        case .noninverting: return "Noninverting"
        case .follower: return "Follower"
        case .difference: return "Difference"
        case .summing: return "Summing"
        case .integrator: return "Integrator"
        case .differentiator: return "Differentiator"
        }
    }
}

public struct OpAmpStageResult: Equatable, Sendable {
    public var topology: OpAmpTopology
    public var gainVV: Double
    public var outputVolts: Double
    public var timeConstantSeconds: Double?
    public var slopeVoltsPerSecond: Double?
    public var unityGainHz: Double?
    public var formula: String
    public var resistorPicks: [PreferredPick]

    public init(
        topology: OpAmpTopology,
        gainVV: Double,
        outputVolts: Double,
        timeConstantSeconds: Double? = nil,
        slopeVoltsPerSecond: Double? = nil,
        unityGainHz: Double? = nil,
        formula: String,
        resistorPicks: [PreferredPick] = []
    ) {
        self.topology = topology
        self.gainVV = gainVV
        self.outputVolts = outputVolts
        self.timeConstantSeconds = timeConstantSeconds
        self.slopeVoltsPerSecond = slopeVoltsPerSecond
        self.unityGainHz = unityGainHz
        self.formula = formula
        self.resistorPicks = resistorPicks
    }
}

/// Ideal-op-amp stages using the two golden rules (vin+ = vin−, i_in = 0).
public enum OpAmpGolden {
    public static func inverting(vin: Double, rin: Double, rf: Double, nearestE24: Bool) throws -> OpAmpStageResult {
        let vs = try finite(vin, name: "Vin")
        let rIn = try Positive.require(rin, name: "Rin")
        let rF = try Positive.require(rf, name: "Rf")
        let gain = -rF / rIn
        return OpAmpStageResult(
            topology: .inverting,
            gainVV: gain,
            outputVolts: gain * vs,
            formula: "Vout = −(Rf / Rin) · Vin",
            resistorPicks: picks([("Rin", rIn), ("Rf", rF)], nearestE24: nearestE24)
        )
    }

    public static func noninverting(vin: Double, rg: Double, rf: Double, nearestE24: Bool) throws -> OpAmpStageResult {
        let vs = try finite(vin, name: "Vin")
        let rG = try Positive.require(rg, name: "Rg")
        let rF = try Positive.require(rf, name: "Rf")
        let gain = 1 + rF / rG
        return OpAmpStageResult(
            topology: .noninverting,
            gainVV: gain,
            outputVolts: gain * vs,
            formula: "Vout = (1 + Rf / Rg) · Vin",
            resistorPicks: picks([("Rg", rG), ("Rf", rF)], nearestE24: nearestE24)
        )
    }

    public static func follower(vin: Double) throws -> OpAmpStageResult {
        let vs = try finite(vin, name: "Vin")
        return OpAmpStageResult(
            topology: .follower,
            gainVV: 1,
            outputVolts: vs,
            formula: "Vout = Vin    (unity-gain buffer)"
        )
    }

    public static func difference(v1: Double, v2: Double, rin: Double, rf: Double, nearestE24: Bool) throws -> OpAmpStageResult {
        let a = try finite(v1, name: "V1")
        let b = try finite(v2, name: "V2")
        let rIn = try Positive.require(rin, name: "Rin")
        let rF = try Positive.require(rf, name: "Rf")
        let gain = rF / rIn
        return OpAmpStageResult(
            topology: .difference,
            gainVV: gain,
            outputVolts: gain * (b - a),
            formula: "Vout = (Rf / Rin) · (V2 − V1)    (matched pairs)",
            resistorPicks: picks([("Rin", rIn), ("Rf", rF)], nearestE24: nearestE24)
        )
    }

    public static func summing(
        v1: Double,
        r1: Double,
        v2: Double,
        r2: Double,
        rf: Double,
        nearestE24: Bool
    ) throws -> OpAmpStageResult {
        let a = try finite(v1, name: "V1")
        let b = try finite(v2, name: "V2")
        let ra = try Positive.require(r1, name: "R1")
        let rb = try Positive.require(r2, name: "R2")
        let rF = try Positive.require(rf, name: "Rf")
        let vout = -rF * (a / ra + b / rb)
        return OpAmpStageResult(
            topology: .summing,
            gainVV: .nan,
            outputVolts: vout,
            formula: "Vout = −Rf · (V1/R1 + V2/R2)",
            resistorPicks: picks([("R1", ra), ("R2", rb), ("Rf", rF)], nearestE24: nearestE24)
        )
    }

    public static func integrator(vin: Double, rin: Double, capacitance: Double, nearestE24: Bool) throws -> OpAmpStageResult {
        let vs = try finite(vin, name: "Vin")
        let rIn = try Positive.require(rin, name: "Rin")
        let c = try Positive.require(capacitance, name: "C")
        let tau = rIn * c
        let slope = -vs / tau
        let unity = 1 / (2 * Double.pi * tau)
        return OpAmpStageResult(
            topology: .integrator,
            gainVV: .nan,
            outputVolts: .nan,
            timeConstantSeconds: tau,
            slopeVoltsPerSecond: slope,
            unityGainHz: unity,
            formula: "Vout = −(1/RC) ∫ Vin dt    f_unity = 1/(2πRC)",
            resistorPicks: picks([("Rin", rIn)], nearestE24: nearestE24)
        )
    }

    public static func differentiator(
        vin: Double,
        capacitance: Double,
        rf: Double,
        frequency: Double,
        nearestE24: Bool
    ) throws -> OpAmpStageResult {
        let vs = try finite(vin, name: "Vin")
        let c = try Positive.require(capacitance, name: "C")
        let rF = try Positive.require(rf, name: "Rf")
        let f = try Positive.require(frequency, name: "Frequency")
        let mag = 2 * Double.pi * f * rF * c
        return OpAmpStageResult(
            topology: .differentiator,
            gainVV: mag,
            outputVolts: mag * vs,
            unityGainHz: 1 / (2 * Double.pi * rF * c),
            formula: "|H| = 2π f Rf C    (ideal differentiator at this frequency)",
            resistorPicks: picks([("Rf", rF)], nearestE24: nearestE24)
        )
    }

    private static func finite(_ value: Double, name: String) throws -> Double {
        guard value.isFinite else { throw CalcError.missing(name) }
        return value
    }

    private static func picks(_ pairs: [(String, Double)], nearestE24: Bool) -> [PreferredPick] {
        guard nearestE24 else { return [] }
        return pairs.map { PreferredPick(name: $0.0, exact: $0.1, nearest: PreferredSeries.nearest($0.1, series: .e24)) }
    }
}

// MARK: - Analog filters + Bode magnitude

public enum AnalogFilterFamily: String, CaseIterable, Sendable, Hashable {
    case rcLowpass
    case rcHighpass
    case sallenKeyLowpass
    case sallenKeyHighpass
    case twinTNotch
    case firstOrderAllpass

    public var displayName: String {
        switch self {
        case .rcLowpass: return "RC low-pass (1st)"
        case .rcHighpass: return "RC high-pass (1st)"
        case .sallenKeyLowpass: return "Sallen–Key LPF"
        case .sallenKeyHighpass: return "Sallen–Key HPF"
        case .twinTNotch: return "Twin-T notch"
        case .firstOrderAllpass: return "1st-order all-pass"
        }
    }
}

public struct AnalogFilterResult: Equatable, Sendable {
    public var family: AnalogFilterFamily
    public var cornerHz: Double
    public var qualityFactor: Double
    public var passbandGainVV: Double
    public var sallenKeyK: Double?
    public var suggestedCapacitance: Double
    public var formula: String
    public var bode: [PlotPoint]

    public init(
        family: AnalogFilterFamily,
        cornerHz: Double,
        qualityFactor: Double,
        passbandGainVV: Double,
        sallenKeyK: Double? = nil,
        suggestedCapacitance: Double,
        formula: String,
        bode: [PlotPoint]
    ) {
        self.family = family
        self.cornerHz = cornerHz
        self.qualityFactor = qualityFactor
        self.passbandGainVV = passbandGainVV
        self.sallenKeyK = sallenKeyK
        self.suggestedCapacitance = suggestedCapacitance
        self.formula = formula
        self.bode = bode
    }
}

extension AnalogFilterResult {
    public static func == (lhs: AnalogFilterResult, rhs: AnalogFilterResult) -> Bool {
        lhs.family == rhs.family
            && lhs.cornerHz == rhs.cornerHz
            && lhs.qualityFactor == rhs.qualityFactor
            && lhs.passbandGainVV == rhs.passbandGainVV
            && lhs.sallenKeyK == rhs.sallenKeyK
            && lhs.suggestedCapacitance == rhs.suggestedCapacitance
            && lhs.formula == rhs.formula
            && lhs.bode == rhs.bode
    }
}

/// Passive RC and equal-component Sallen–Key / Twin-T starting points.
public enum AnalogFilter {
    /// Butterworth Q for a 2nd-order section (1/√2).
    public static let butterworthQ = 1 / Double.sqrt(2)
    /// Equal-R, equal-C Sallen–Key K that yields Butterworth Q: K = 3 − 1/Q.
    public static let butterworthSallenKeyK = 3 - Double.sqrt(2)

    public static func cornerHz(resistance: Double, capacitance: Double) throws -> Double {
        let r = try Positive.require(resistance, name: "R")
        let c = try Positive.require(capacitance, name: "C")
        return 1 / (2 * Double.pi * r * c)
    }

    public static func capacitanceForCorner(resistance: Double, frequency: Double) throws -> Double {
        let r = try Positive.require(resistance, name: "R")
        let f = try Positive.require(frequency, name: "Frequency")
        return 1 / (2 * Double.pi * r * f)
    }

    /// Equal-component Sallen–Key: ω0 = 1/(RC), Q = 1/(3−K).
    public static func sallenKeyQ(k: Double) throws -> Double {
        guard k.isFinite else { throw CalcError.missing("K") }
        let denom = 3 - k
        guard denom > 0 else { throw CalcError.outOfRange("Sallen–Key K must be less than 3 or Q is undefined / unstable.") }
        return 1 / denom
    }

    public static func sallenKeyK(q: Double) throws -> Double {
        let quality = try Positive.require(q, name: "Q")
        return 3 - 1 / quality
    }

    public static func solve(
        family: AnalogFilterFamily,
        designFrequency: Double,
        resistance: Double,
        capacitance: Double,
        passbandGain: Double,
        quality: Double,
        samples: Int = 97
    ) throws -> AnalogFilterResult {
        let f0In = try Positive.require(designFrequency, name: "Frequency")
        let r = try Positive.require(resistance, name: "R")
        let cIn = try Positive.require(capacitance, name: "C")
        let gain = try Positive.require(passbandGain, name: "Gain")
        let qIn = try Positive.require(quality, name: "Q")

        let rcCorner = try cornerHz(resistance: r, capacitance: cIn)
        let suggestedC = try capacitanceForCorner(resistance: r, frequency: f0In)

        let isFirstOrder = family == .rcLowpass || family == .rcHighpass || family == .firstOrderAllpass
        let corner = isFirstOrder ? rcCorner : f0In
        var q = qIn
        var k: Double?

        switch family {
        case .sallenKeyLowpass, .sallenKeyHighpass:
            // Default the section to Butterworth when the operator leaves Q at the textbook 0.707.
            q = abs(qIn - butterworthQ) < 0.02 ? butterworthQ : qIn
            k = try sallenKeyK(q: q)
        case .twinTNotch:
            // Passive Twin-T has a shallow notch; Q ≈ 0.25 unless bootstrapped.
            if abs(qIn - butterworthQ) < 0.02 { q = 0.25 }
        case .rcLowpass, .rcHighpass, .firstOrderAllpass:
            q = 0.5
        }

        let bode = sampleBode(family: family, cornerHz: corner, q: q, gain: gain, samples: samples)
        return AnalogFilterResult(
            family: family,
            cornerHz: corner,
            qualityFactor: q,
            passbandGainVV: gain,
            sallenKeyK: k,
            suggestedCapacitance: suggestedC,
            formula: formula(for: family),
            bode: bode
        )
    }

    public static func magnitude(
        family: AnalogFilterFamily,
        frequency: Double,
        cornerHz: Double,
        q: Double,
        gain: Double
    ) -> Double {
        guard frequency > 0, cornerHz > 0, frequency.isFinite, cornerHz.isFinite else { return .nan }
        let x = frequency / cornerHz
        switch family {
        case .rcLowpass:
            return gain / sqrt(1 + x * x)
        case .rcHighpass:
            return gain * x / sqrt(1 + x * x)
        case .sallenKeyLowpass:
            return gain / secondOrderDenom(x: x, q: q)
        case .sallenKeyHighpass:
            return gain * x * x / secondOrderDenom(x: x, q: q)
        case .twinTNotch:
            return gain * abs(1 - x * x) / secondOrderDenom(x: x, q: q)
        case .firstOrderAllpass:
            return gain
        }
    }

    public static func sampleBode(
        family: AnalogFilterFamily,
        cornerHz: Double,
        q: Double,
        gain: Double,
        decades: Double = 3,
        samples: Int = 97
    ) -> [PlotPoint] {
        guard cornerHz.isFinite, cornerHz > 0, samples >= 2 else { return [] }
        let logC = log10(cornerHz)
        let lo = logC - decades
        let hi = logC + decades
        return (0..<samples).map { i in
            let f = pow(10, lo + (hi - lo) * Double(i) / Double(samples - 1))
            let mag = max(magnitude(family: family, frequency: f, cornerHz: cornerHz, q: q, gain: gain), 1e-9)
            return PlotPoint(x: f, y: 20 * log10(mag))
        }
    }

    private static func secondOrderDenom(x: Double, q: Double) -> Double {
        let quality = max(q, 1e-9)
        let re = 1 - x * x
        let im = x / quality
        return sqrt(re * re + im * im)
    }

    public static func symbolicFormula(for family: AnalogFilterFamily) -> String {
        formula(for: family)
    }

    private static func formula(for family: AnalogFilterFamily) -> String {
        switch family {
        case .rcLowpass:
            return "fc = 1/(2πRC)    |H| = G / √(1 + (f/fc)²)"
        case .rcHighpass:
            return "fc = 1/(2πRC)    |H| = G · (f/fc) / √(1 + (f/fc)²)"
        case .sallenKeyLowpass:
            return "fc = 1/(2πRC)    Q = 1/(3−K)    Butterworth Q = 1/√2 → K ≈ 1.586"
        case .sallenKeyHighpass:
            return "fc = 1/(2πRC)    |H| = G · (f/fc)² / √((1−x²)² + (x/Q)²)"
        case .twinTNotch:
            return "f0 = 1/(2πRC)    Twin-T ratios R, R, R/2 and C, C, 2C"
        case .firstOrderAllpass:
            return "fc = 1/(2πRC)    |H| = G (flat). Phase flips around fc."
        }
    }
}

// MARK: - Noise & SNR (spot / brick-wall, not SPICE)

public struct NoiseSNRResult: Equatable, Sendable {
    public var noiseBandwidthHz: Double
    public var johnsonVrms: Double
    public var shotIrms: Double
    public var shotVrms: Double
    public var ampVoltageVrms: Double
    public var ampCurrentVrms: Double
    public var totalReferredVrms: Double
    public var snrDB: Double?
    public var noiseFigureDB: Double?
    public var formula: String

    public init(
        noiseBandwidthHz: Double,
        johnsonVrms: Double,
        shotIrms: Double,
        shotVrms: Double,
        ampVoltageVrms: Double,
        ampCurrentVrms: Double,
        totalReferredVrms: Double,
        snrDB: Double?,
        noiseFigureDB: Double?,
        formula: String
    ) {
        self.noiseBandwidthHz = noiseBandwidthHz
        self.johnsonVrms = johnsonVrms
        self.shotIrms = shotIrms
        self.shotVrms = shotVrms
        self.ampVoltageVrms = ampVoltageVrms
        self.ampCurrentVrms = ampCurrentVrms
        self.totalReferredVrms = totalReferredVrms
        self.snrDB = snrDB
        self.noiseFigureDB = noiseFigureDB
        self.formula = formula
    }
}

public enum NoiseSNR {
    public static let boltzmann = 1.380649e-23
    public static let elementaryCharge = 1.602176634e-19
    /// First-order low-pass brick-wall equivalent: π/2 × 3 dB bandwidth.
    public static let firstOrderNoiseBandwidthFactor = Double.pi / 2

    public static func johnsonVrms(resistance: Double, temperatureKelvin: Double, bandwidthHz: Double) throws -> Double {
        let r = try requireNonNegative(resistance, name: "Resistance")
        let t = try Positive.require(temperatureKelvin, name: "Temperature")
        let b = try Positive.require(bandwidthHz, name: "Bandwidth")
        return sqrt(4 * boltzmann * t * r * b)
    }

    public static func shotIrms(current: Double, bandwidthHz: Double) throws -> Double {
        let i = try requireNonNegative(current, name: "Current")
        let b = try Positive.require(bandwidthHz, name: "Bandwidth")
        return sqrt(2 * elementaryCharge * i * b)
    }

    /// Input-referred RMS total: thermal + shot (through R) + amp e_n and i_n.
    ///
    /// `ampEn` is V/√Hz, `ampIn` is A/√Hz. Bandwidth is already the noise BW
    /// (Hz), not the 3 dB BW — apply `noiseBandwidth(from:factor:)` first.
    public static func solve(
        resistance: Double,
        temperatureKelvin: Double,
        bandwidthHz: Double,
        ampEn: Double,
        ampIn: Double,
        shotCurrent: Double?,
        signalVrms: Double?
    ) throws -> NoiseSNRResult {
        let r = try requireNonNegative(resistance, name: "Resistance")
        let t = try Positive.require(temperatureKelvin, name: "Temperature")
        let b = try Positive.require(bandwidthHz, name: "Bandwidth")
        guard ampEn.isFinite, ampEn >= 0 else { throw CalcError.nonPositive("Amplifier e_n") }
        guard ampIn.isFinite, ampIn >= 0 else { throw CalcError.nonPositive("Amplifier i_n") }

        let johnson = try johnsonVrms(resistance: r, temperatureKelvin: t, bandwidthHz: b)
        let en = ampEn * sqrt(b)
        let inn = ampIn * r * sqrt(b)

        var shotI = 0.0
        var shotV = 0.0
        if let iShot = shotCurrent {
            shotI = try shotIrms(current: iShot, bandwidthHz: b)
            shotV = shotI * r
        }

        let total = hypot4(johnson, shotV, en, inn)

        var snr: Double?
        if let sig = signalVrms {
            guard sig.isFinite, sig > 0 else { throw CalcError.nonPositive("Signal amplitude") }
            guard total > 0 else { throw CalcError.outOfRange("Total noise is zero — SNR is undefined.") }
            snr = 20 * log10(sig / total)
        }

        var nf: Double?
        if johnson > 0 {
            nf = 10 * log10((total * total) / (johnson * johnson))
        }

        return NoiseSNRResult(
            noiseBandwidthHz: b,
            johnsonVrms: johnson,
            shotIrms: shotI,
            shotVrms: shotV,
            ampVoltageVrms: en,
            ampCurrentVrms: inn,
            totalReferredVrms: total,
            snrDB: snr,
            noiseFigureDB: nf,
            formula: "vn = √(4kTRB)    in,shot = √(2qIB)    SNR = 20 log10(Vsig / vn,tot)"
        )
    }

    public static func noiseBandwidth(hz3dB: Double, factor: Double) throws -> Double {
        let b = try Positive.require(hz3dB, name: "Bandwidth")
        let f = try Positive.require(factor, name: "Noise-BW factor")
        return b * f
    }

    private static func requireNonNegative(_ value: Double, name: String) throws -> Double {
        guard value.isFinite else { throw CalcError.missing(name) }
        guard value >= 0 else { throw CalcError.nonPositive(name) }
        return value
    }

    private static func hypot4(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        sqrt(a * a + b * b + c * c + d * d)
    }
}

// MARK: - Linear / LDO regulator + thermal

public struct LinearRegulatorResult: Equatable, Sendable {
    public var vout: Double
    public var r1: Double
    public var r2: Double
    public var r1NearestE24: Double
    public var r2NearestE24: Double
    public var headroom: Double
    public var dropoutMargin: Double
    public var powerDissipation: Double
    public var thetaJAUsed: Double
    public var junctionC: Double
    public var junctionHigh: Bool
    public var formula: String

    public init(
        vout: Double,
        r1: Double,
        r2: Double,
        r1NearestE24: Double,
        r2NearestE24: Double,
        headroom: Double,
        dropoutMargin: Double,
        powerDissipation: Double,
        thetaJAUsed: Double,
        junctionC: Double,
        junctionHigh: Bool,
        formula: String
    ) {
        self.vout = vout
        self.r1 = r1
        self.r2 = r2
        self.r1NearestE24 = r1NearestE24
        self.r2NearestE24 = r2NearestE24
        self.headroom = headroom
        self.dropoutMargin = dropoutMargin
        self.powerDissipation = powerDissipation
        self.thetaJAUsed = thetaJAUsed
        self.junctionC = junctionC
        self.junctionHigh = junctionHigh
        self.formula = formula
    }
}

public enum LinearRegulator {
    /// Classic adjustable-regulator reference (LM317 and many clones).
    public static let defaultVref = 1.25
    /// Typical LM317 adjustment-pin current; set 0 to ignore.
    public static let defaultIadj = 50e-6
    /// AoE-style silicon rule of thumb — not a datasheet limit.
    public static let junctionWarnC = 125.0

    public static func vout(vref: Double, r1: Double, r2: Double, iadj: Double) throws -> Double {
        let v = try Positive.require(vref, name: "Vref")
        let a = try Positive.require(r1, name: "R1")
        let b = try requireNonNegative(r2, name: "R2")
        let i = try requireNonNegative(iadj, name: "Iadj")
        return v * (1 + b / a) + i * b
    }

    public static func r2(forVout vout: Double, vref: Double, r1: Double, iadj: Double) throws -> Double {
        let vo = try Positive.require(vout, name: "Vout")
        let v = try Positive.require(vref, name: "Vref")
        let a = try Positive.require(r1, name: "R1")
        let i = try requireNonNegative(iadj, name: "Iadj")
        guard vo > v else { throw CalcError.outOfRange("Vout must be greater than Vref.") }
        let denom = v / a + i
        guard denom > 0 else { throw CalcError.outOfRange("R2 is undefined for these parts.") }
        return (vo - v) / denom
    }

    public static func solve(
        vin: Double,
        voutOrTarget: Double,
        r1: Double,
        r2: Double?,
        vref: Double,
        iadj: Double,
        dropout: Double,
        loadCurrent: Double,
        ambientC: Double,
        thetaJA: Double,
        thetaJC: Double?,
        thetaSA: Double?,
        solveResistors: Bool
    ) throws -> LinearRegulatorResult {
        let vinV = try Positive.require(vin, name: "Vin")
        let vrefV = try Positive.require(vref, name: "Vref")
        let r1Ω = try Positive.require(r1, name: "R1")
        let iadjA = try requireNonNegative(iadj, name: "Iadj")
        let vdo = try requireNonNegative(dropout, name: "Dropout")
        let iLoad = try requireNonNegative(loadCurrent, name: "Load current")
        guard ambientC.isFinite else { throw CalcError.missing("Ambient") }
        let thJA = try Positive.require(thetaJA, name: "θJA")

        let r2Ω: Double
        let vout: Double
        if solveResistors {
            let target = try Positive.require(voutOrTarget, name: "Vout")
            r2Ω = try r2(forVout: target, vref: vrefV, r1: r1Ω, iadj: iadjA)
            vout = try Self.vout(vref: vrefV, r1: r1Ω, r2: r2Ω, iadj: iadjA)
        } else {
            r2Ω = try Positive.require(r2 ?? .nan, name: "R2")
            vout = try Self.vout(vref: vrefV, r1: r1Ω, r2: r2Ω, iadj: iadjA)
        }

        let headroom = vinV - vout
        let pd = max(0, headroom) * iLoad

        var thetaUsed = thJA
        if let sa = thetaSA, sa > 0 {
            let jc = thetaJC ?? 5
            guard jc.isFinite, jc > 0 else { throw CalcError.nonPositive("θJC") }
            // Package + sink in series. Free-air θJA is ignored once a sink is entered.
            thetaUsed = jc + sa
        }

        let tj = ambientC + pd * thetaUsed
        return LinearRegulatorResult(
            vout: vout,
            r1: r1Ω,
            r2: r2Ω,
            r1NearestE24: PreferredSeries.nearest(r1Ω),
            r2NearestE24: PreferredSeries.nearest(r2Ω),
            headroom: headroom,
            dropoutMargin: headroom - vdo,
            powerDissipation: pd,
            thetaJAUsed: thetaUsed,
            junctionC: tj,
            junctionHigh: tj >= junctionWarnC,
            formula: "Vout = Vref(1 + R2/R1) + Iadj·R2    Pd = (Vin − Vout)·I    Tj = Ta + Pd·θJA"
        )
    }

    private static func requireNonNegative(_ value: Double, name: String) throws -> Double {
        guard value.isFinite else { throw CalcError.missing(name) }
        guard value >= 0 else { throw CalcError.nonPositive(name) }
        return value
    }
}

// MARK: - Instrumentation / difference amplifier

public enum InAmpMode: String, CaseIterable, Sendable, Hashable {
    case threeOpAmp
    case difference

    public var displayName: String {
        switch self {
        case .threeOpAmp: return "3-op-amp InAmp"
        case .difference: return "Difference amp"
        }
    }
}

public struct InstrumentationAmpResult: Equatable, Sendable {
    public var mode: InAmpMode
    public var gain: Double
    public var vout: Double
    public var differentialIn: Double
    public var commonMode: Double
    public var outputHighHeadroom: Double
    public var outputLowHeadroom: Double
    public var outputInSwing: Bool
    public var inputCMInRange: Bool
    public var formula: String

    public init(
        mode: InAmpMode,
        gain: Double,
        vout: Double,
        differentialIn: Double,
        commonMode: Double,
        outputHighHeadroom: Double,
        outputLowHeadroom: Double,
        outputInSwing: Bool,
        inputCMInRange: Bool,
        formula: String
    ) {
        self.mode = mode
        self.gain = gain
        self.vout = vout
        self.differentialIn = differentialIn
        self.commonMode = commonMode
        self.outputHighHeadroom = outputHighHeadroom
        self.outputLowHeadroom = outputLowHeadroom
        self.outputInSwing = outputInSwing
        self.inputCMInRange = inputCMInRange
        self.formula = formula
    }
}

public enum InstrumentationAmp {
    /// Classic first-stage form G = 1 + 2R / Rg.
    public static func threeOpAmpGain(r: Double, rg: Double) throws -> Double {
        let a = try Positive.require(r, name: "R")
        let g = try Positive.require(rg, name: "Rg")
        return 1 + 2 * a / g
    }

    public static func differenceGain(rf: Double, rin: Double) throws -> Double {
        try Positive.require(rf, name: "Rf") / (try Positive.require(rin, name: "Rin"))
    }

    public static func solve(
        mode: InAmpMode,
        v2: Double,
        v1: Double,
        r: Double,
        rg: Double,
        vref: Double,
        railPos: Double,
        railNeg: Double,
        cmMin: Double,
        cmMax: Double
    ) throws -> InstrumentationAmpResult {
        let plus = try finite(v2, name: "V2")
        let minus = try finite(v1, name: "V1")
        let ref = try finite(vref, name: "Vref")
        let rp = try finite(railPos, name: "+ rail")
        let rn = try finite(railNeg, name: "− rail")
        guard rp > rn else { throw CalcError.outOfRange("Positive rail must be above the negative rail.") }
        let cmin = try finite(cmMin, name: "CM min")
        let cmax = try finite(cmMax, name: "CM max")
        guard cmax > cmin else { throw CalcError.outOfRange("CM max must be greater than CM min.") }

        let diff = plus - minus
        let cm = (plus + minus) / 2
        let gain: Double
        let formula: String
        switch mode {
        case .threeOpAmp:
            gain = try threeOpAmpGain(r: r, rg: rg)
            formula = "G = 1 + 2R / Rg    Vout = G·(V2 − V1) + Vref"
        case .difference:
            gain = try differenceGain(rf: r, rin: rg)
            formula = "G = Rf / Rin    Vout = G·(V2 − V1) + Vref    (matched 4-resistor)"
        }

        let vout = gain * diff + ref
        let high = rp - vout
        let low = vout - rn
        return InstrumentationAmpResult(
            mode: mode,
            gain: gain,
            vout: vout,
            differentialIn: diff,
            commonMode: cm,
            outputHighHeadroom: high,
            outputLowHeadroom: low,
            outputInSwing: vout <= rp && vout >= rn,
            inputCMInRange: cm >= cmin && cm <= cmax,
            formula: formula
        )
    }

    private static func finite(_ value: Double, name: String) throws -> Double {
        guard value.isFinite else { throw CalcError.missing(name) }
        return value
    }
}

// MARK: - ADC / DAC & sampling

public struct SamplingConverterResult: Equatable, Sendable {
    public var bits: Int
    public var fullScale: Double
    public var lsb: Double
    public var codeCount: Int
    public var idealQuantizationSNRdB: Double
    public var nyquistHz: Double
    public var suggestedAntiAliasHz: Double
    public var dacVoltage: Double?
    public var formula: String

    public init(
        bits: Int,
        fullScale: Double,
        lsb: Double,
        codeCount: Int,
        idealQuantizationSNRdB: Double,
        nyquistHz: Double,
        suggestedAntiAliasHz: Double,
        dacVoltage: Double?,
        formula: String
    ) {
        self.bits = bits
        self.fullScale = fullScale
        self.lsb = lsb
        self.codeCount = codeCount
        self.idealQuantizationSNRdB = idealQuantizationSNRdB
        self.nyquistHz = nyquistHz
        self.suggestedAntiAliasHz = suggestedAntiAliasHz
        self.dacVoltage = dacVoltage
        self.formula = formula
    }
}

public enum SamplingConverter {
    /// Ideal full-scale sine into a uniform mid-riser quantizer: 6.02 n + 1.76 dB.
    public static func idealQuantizationSNR(bits: Int) throws -> Double {
        let n = try requireBits(bits)
        return 6.02 * Double(n) + 1.76
    }

    public static func lsb(fullScale: Double, bits: Int) throws -> Double {
        let fs = try requireSpan(fullScale)
        let n = try requireBits(bits)
        return fs / pow(2, Double(n))
    }

    public static func dacVoltage(code: Double, fullScale: Double, bits: Int) throws -> Double {
        let n = try requireBits(bits)
        let fs = try requireSpan(fullScale)
        guard code.isFinite else { throw CalcError.missing("DAC code") }
        let maxCode = pow(2, Double(n)) - 1
        guard code >= 0, code <= maxCode else {
            throw CalcError.outOfRange("DAC code must be between 0 and \(Int(maxCode)).")
        }
        return code * (fs / pow(2, Double(n)))
    }

    public static func solve(
        bits: Double,
        fullScale: Double,
        sampleRate: Double,
        dacCode: Double?
    ) throws -> SamplingConverterResult {
        let n = try WholeCount.parse(bits, name: "Bits")
        guard n <= 32 else { throw CalcError.outOfRange("Bits must be 32 or fewer.") }
        let fs = try requireSpan(fullScale)
        let fsamp = try Positive.require(sampleRate, name: "Sample rate")
        let step = try lsb(fullScale: fs, bits: n)
        let codes = 1 << n
        let nyquist = fsamp / 2
        // Conservative starting anti-alias corner, below Nyquist — not a filter design.
        let antiAlias = 0.4 * fsamp
        var dacV: Double?
        if let code = dacCode {
            dacV = try dacVoltage(code: code, fullScale: fs, bits: n)
        }
        return SamplingConverterResult(
            bits: n,
            fullScale: fs,
            lsb: step,
            codeCount: codes,
            idealQuantizationSNRdB: try idealQuantizationSNR(bits: n),
            nyquistHz: nyquist,
            suggestedAntiAliasHz: antiAlias,
            dacVoltage: dacV,
            formula: "LSB = FS / 2ⁿ    SNR_ideal ≈ 6.02n + 1.76 dB    Nyquist = Fs/2"
        )
    }

    private static func requireBits(_ bits: Int) throws -> Int {
        guard bits >= 1 else { throw CalcError.nonPositive("Bits") }
        guard bits <= 32 else { throw CalcError.outOfRange("Bits must be 32 or fewer.") }
        return bits
    }

    private static func requireSpan(_ value: Double) throws -> Double {
        try Positive.require(value, name: "Full-scale range")
    }
}
