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
