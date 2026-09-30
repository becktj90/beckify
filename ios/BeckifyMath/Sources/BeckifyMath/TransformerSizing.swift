import Foundation

public struct TransformerOCPD: Equatable, Sendable {
    public var percent: Int
    public var note: String
    public var ceilingAmps: Double
    public var deviceAmps: Int?
    public var roundsUp: Bool

    public init(percent: Int, note: String, ceilingAmps: Double, deviceAmps: Int?, roundsUp: Bool) {
        self.percent = percent
        self.note = note
        self.ceilingAmps = ceilingAmps
        self.deviceAmps = deviceAmps
        self.roundsUp = roundsUp
    }
}

public struct TransformerSizingResult: Equatable, Sendable {
    public var loadKVA: Double
    public var designKVA: Double
    public var selectedKVA: Double
    public var primaryFLA: Double
    public var secondaryFLA: Double
    public var turnsRatio: Double
    public var primaryOnly: TransformerOCPD
    public var primaryWithSecondary: TransformerOCPD
    public var secondaryProtection: TransformerOCPD
    public var primaryConductorMinAmps: Double
    public var secondaryConductorMinAmps: Double
    public var formula: String

    public init(
        loadKVA: Double,
        designKVA: Double,
        selectedKVA: Double,
        primaryFLA: Double,
        secondaryFLA: Double,
        turnsRatio: Double,
        primaryOnly: TransformerOCPD,
        primaryWithSecondary: TransformerOCPD,
        secondaryProtection: TransformerOCPD,
        primaryConductorMinAmps: Double,
        secondaryConductorMinAmps: Double,
        formula: String
    ) {
        self.loadKVA = loadKVA
        self.designKVA = designKVA
        self.selectedKVA = selectedKVA
        self.primaryFLA = primaryFLA
        self.secondaryFLA = secondaryFLA
        self.turnsRatio = turnsRatio
        self.primaryOnly = primaryOnly
        self.primaryWithSecondary = primaryWithSecondary
        self.secondaryProtection = secondaryProtection
        self.primaryConductorMinAmps = primaryConductorMinAmps
        self.secondaryConductorMinAmps = secondaryConductorMinAmps
        self.formula = formula
    }
}

public enum TransformerLoad: Equatable, Sendable {
    case kVA(Double)
    case kW(Double, powerFactor: Double)
    case amps(Double)
}

/// NEC Table 450.3(B) for transformers rated 1000 V or less, plus Note 1 next-size-up.
public enum TransformerSizing {
    public static func size(
        system: ElectricalSystem,
        load: TransformerLoad,
        primaryVolts: Double,
        secondaryVolts: Double,
        continuous: Bool
    ) throws -> TransformerSizingResult {
        guard system != .dc else { throw CalcError.outOfRange("Transformer sizing is for AC systems.") }
        let vp = try Positive.require(primaryVolts, name: "Primary voltage")
        let vs = try Positive.require(secondaryVolts, name: "Secondary voltage")
        guard vp <= 1000, vs <= 1000 else {
            throw CalcError.outOfRange("This calculator implements NEC Table 450.3(B) for transformers rated 1000 V or less.")
        }
        let mult = system.phaseMultiplier

        let loadKVA: Double
        switch load {
        case .kVA(let value):
            loadKVA = try Positive.require(value, name: "Load kVA")
        case .kW(let value, let pf):
            let kw = try Positive.require(value, name: "Load kW")
            guard pf.isFinite, pf > 0, pf <= 1 else {
                throw CalcError.outOfRange("Power factor must be between 0 and 1 (exclusive of 0).")
            }
            loadKVA = kw / pf
        case .amps(let value):
            let amps = try Positive.require(value, name: "Load current")
            loadKVA = (mult * vs * amps) / 1000
        }

        let designKVA = continuous ? loadKVA * 1.25 : loadKVA
        guard let selected = NECTables.standardTransformerKVA.first(where: { $0 >= designKVA }) else {
            throw CalcError.notListed("Load \(designKVA) kVA exceeds the largest standard rating in this list.")
        }

        let ip = (selected * 1000) / (mult * vp)
        let `is` = (selected * 1000) / (mult * vs)

        let p1 = primaryOnlyLimit(ip)
        let p1Ceiling = ip * Double(p1.percent) / 100
        let p1Device = p1.roundsUp
            ? NECTables.nextStandardOCPD(p1Ceiling)
            : NECTables.largestStandardOCPD(atOrBelow: p1Ceiling)

        let p2Ceiling = ip * 2.5
        let p2Device = NECTables.largestStandardOCPD(atOrBelow: p2Ceiling)
        let s2 = secondaryLimit(`is`)
        let s2Ceiling = `is` * Double(s2.percent) / 100
        let s2Device = s2.roundsUp
            ? NECTables.nextStandardOCPD(s2Ceiling)
            : NECTables.largestStandardOCPD(atOrBelow: s2Ceiling)

        return TransformerSizingResult(
            loadKVA: loadKVA,
            designKVA: designKVA,
            selectedKVA: selected,
            primaryFLA: ip,
            secondaryFLA: `is`,
            turnsRatio: vp / vs,
            primaryOnly: TransformerOCPD(
                percent: p1.percent,
                note: p1.note,
                ceilingAmps: p1Ceiling,
                deviceAmps: p1Device,
                roundsUp: p1.roundsUp
            ),
            primaryWithSecondary: TransformerOCPD(
                percent: 250,
                note: "Primary with secondary protection",
                ceilingAmps: p2Ceiling,
                deviceAmps: p2Device,
                roundsUp: false
            ),
            secondaryProtection: TransformerOCPD(
                percent: s2.percent,
                note: s2.note,
                ceilingAmps: s2Ceiling,
                deviceAmps: s2Device,
                roundsUp: s2.roundsUp
            ),
            primaryConductorMinAmps: ip * 1.25,
            secondaryConductorMinAmps: `is` * 1.25,
            formula: "I = kVA × 1000 ÷ (\(system == .threePhase ? "√3 × " : "")V)    NEC 450.3(B)"
        )
    }

    private static func primaryOnlyLimit(_ primaryAmps: Double) -> (percent: Int, note: String, roundsUp: Bool) {
        if primaryAmps >= 9 { return (125, "Primary ≥ 9 A", true) }
        if primaryAmps >= 2 { return (167, "Primary 2 A to under 9 A", false) }
        return (300, "Primary under 2 A", false)
    }

    private static func secondaryLimit(_ secondaryAmps: Double) -> (percent: Int, note: String, roundsUp: Bool) {
        if secondaryAmps >= 9 { return (125, "Secondary ≥ 9 A", true) }
        return (167, "Secondary under 9 A", false)
    }
}

/// How line voltages become a winding turns ratio.
public enum TurnsRatioBasis: String, Equatable, Sendable {
    /// Wye–wye, delta–delta, or a single winding. Np/Ns = Vp/Vs.
    case lineVoltages
    /// Delta primary, wye secondary. Np/Ns = √3 × Vp/Vs.
    case deltaPrimaryWyeSecondary
    /// Wye primary, delta secondary. Np/Ns = Vp ÷ (√3 × Vs).
    case wyePrimaryDeltaSecondary
    /// Zig-zag, autotransformer, or buck-boost. The row still uses Vp/Vs.
    case approximateLineVoltages

    public func turnsRatio(primaryVolts: Double, secondaryVolts: Double) -> Double {
        let line = primaryVolts / secondaryVolts
        switch self {
        case .lineVoltages, .approximateLineVoltages:
            return line
        case .deltaPrimaryWyeSecondary:
            return line * 3.0.squareRoot()
        case .wyePrimaryDeltaSecondary:
            return line / 3.0.squareRoot()
        }
    }

    public var note: String {
        switch self {
        case .lineVoltages:
            return "Np/Ns uses the line voltages. Wye–wye, delta–delta, and a single winding share that ratio."
        case .deltaPrimaryWyeSecondary:
            return "Delta primary, wye secondary: Np/Ns = √3 × Vp/Vs. Line voltages alone are not the winding ratio."
        case .wyePrimaryDeltaSecondary:
            return "Wye primary, delta secondary: Np/Ns = Vp ÷ (√3 × Vs)."
        case .approximateLineVoltages:
            return "This connection is not a simple two-winding pair. The row still uses Vp/Vs."
        }
    }
}

public struct ReferredImpedance: Equatable, Sendable {
    public var load: ComplexOhms
    public var referred: ComplexOhms
    public var turnsRatio: Double
    public var basis: TurnsRatioBasis
    public var formula: String

    public init(load: ComplexOhms, referred: ComplexOhms, turnsRatio: Double, basis: TurnsRatioBasis, formula: String) {
        self.load = load
        self.referred = referred
        self.turnsRatio = turnsRatio
        self.basis = basis
        self.formula = formula
    }
}

public struct StepUpLineLoss: Equatable, Sendable {
    public var loadWatts: Double
    public var powerFactor: Double
    public var lagging: Bool
    public var lowVolts: Double
    public var highVolts: Double
    public var conductorOhms: Double
    public var threePhase: Bool
    public var currentLow: Double
    public var currentHigh: Double
    public var lossLowWatts: Double
    public var lossHighWatts: Double
    public var assumptions: [String]

    public init(
        loadWatts: Double,
        powerFactor: Double,
        lagging: Bool,
        lowVolts: Double,
        highVolts: Double,
        conductorOhms: Double,
        threePhase: Bool,
        currentLow: Double,
        currentHigh: Double,
        lossLowWatts: Double,
        lossHighWatts: Double,
        assumptions: [String]
    ) {
        self.loadWatts = loadWatts
        self.powerFactor = powerFactor
        self.lagging = lagging
        self.lowVolts = lowVolts
        self.highVolts = highVolts
        self.conductorOhms = conductorOhms
        self.threePhase = threePhase
        self.currentLow = currentLow
        self.currentHigh = currentHigh
        self.lossLowWatts = lossLowWatts
        self.lossHighWatts = lossHighWatts
        self.assumptions = assumptions
    }
}

/// Ideal referral of a secondary impedance, plus a line-loss comparison at two voltages.
public enum ImpedanceReflection {
    public static let referralFormula = "Z' = Z × (Np/Ns)²"

    public static func refer(
        load: ComplexOhms,
        primaryVolts: Double,
        secondaryVolts: Double,
        basis: TurnsRatioBasis
    ) throws -> ReferredImpedance {
        let vp = try Positive.require(primaryVolts, name: "Primary voltage")
        let vs = try Positive.require(secondaryVolts, name: "Secondary voltage")
        let z = try requireLoad(load)
        let turns = basis.turnsRatio(primaryVolts: vp, secondaryVolts: vs)
        let factor = turns * turns
        return ReferredImpedance(
            load: z,
            referred: z.scaled(by: factor),
            turnsRatio: turns,
            basis: basis,
            formula: referralFormula
        )
    }

    /// Same real watts and power factor, sent at the secondary voltage or stepped up to the primary voltage.
    public static func compareLineLoss(
        system: ElectricalSystem,
        load: ComplexOhms,
        secondaryVolts: Double,
        primaryVolts: Double,
        conductorOhms: Double
    ) throws -> StepUpLineLoss {
        guard system != .dc else {
            throw CalcError.outOfRange("Line-loss comparison is for AC.")
        }
        let vs = try Positive.require(secondaryVolts, name: "Secondary voltage")
        let vp = try Positive.require(primaryVolts, name: "Primary voltage")
        guard conductorOhms.isFinite else { throw CalcError.missing("Line conductor resistance") }
        guard conductorOhms >= 0 else {
            throw CalcError.outOfRange("Line conductor resistance cannot be negative.")
        }
        let z = try requireLoad(load)
        guard abs(z.resistance) > 0 else {
            throw CalcError.outOfRange("Line-loss comparison needs real watts. A pure reactive load has no power factor to hold constant.")
        }

        let sqrt3 = 3.0.squareRoot()
        let pf = z.resistance / z.magnitude
        let threePhase = system == .threePhase
        let loadCurrent = threePhase ? (vs / sqrt3) / z.magnitude : vs / z.magnitude
        let watts = (threePhase ? 3 : 1) * loadCurrent * loadCurrent * z.resistance
        let currentLow = threePhase ? watts / (sqrt3 * vs * pf) : watts / (vs * pf)
        let currentHigh = threePhase ? watts / (sqrt3 * vp * pf) : watts / (vp * pf)
        let conductors = threePhase ? 3.0 : 2.0
        let loss: (Double) -> Double = { current in conductors * current * current * conductorOhms }
        let path = threePhase
            ? "Three-phase loss is 3 I²R. R is one conductor. Neutral current is not in this row."
            : "Single-phase loss is 2 I²R, out and back. R is one conductor."

        return StepUpLineLoss(
            loadWatts: watts,
            powerFactor: pf,
            lagging: z.reactance >= 0,
            lowVolts: vs,
            highVolts: vp,
            conductorOhms: conductorOhms,
            threePhase: threePhase,
            currentLow: currentLow,
            currentHigh: currentHigh,
            lossLowWatts: loss(currentLow),
            lossHighWatts: loss(currentHigh),
            assumptions: [
                "Same real watts and power factor at both voltages.",
                path,
                "The step-up is ideal. Core and copper loss in the transformer are not included.",
                threePhase
                    ? "Secondary Z is one phase of a balanced wye at the secondary line voltage."
                    : "Secondary Z is the load on the secondary winding.",
            ]
        )
    }

    private static func requireLoad(_ load: ComplexOhms) throws -> ComplexOhms {
        guard load.resistance.isFinite, load.reactance.isFinite else {
            throw CalcError.missing("Secondary resistance and reactance")
        }
        guard load.resistance >= 0 else {
            throw CalcError.outOfRange("Secondary resistance cannot be negative.")
        }
        guard load.magnitude > 0 else {
            throw CalcError.outOfRange("Secondary impedance cannot be a short. Enter resistance, reactance, or both.")
        }
        return load
    }
}
