import Foundation

public enum NECCircuitLoadType: String, Codable, CaseIterable, Sendable {
    case continuous
    case noncontinuous
    case motor

    public var label: String {
        switch self {
        case .continuous: return "Continuous (×1.25)"
        case .noncontinuous: return "Noncontinuous (×1.0)"
        case .motor: return "Motor branch (×1.25 conductors)"
        }
    }

    public var conductorMultiplier: Double {
        switch self {
        case .continuous, .motor: return 1.25
        case .noncontinuous: return 1.0
        }
    }

    public var ocpdMultiplier: Double {
        switch self {
        case .continuous: return 1.25
        case .noncontinuous: return 1.0
        case .motor: return 2.5 // inverse-time breaker discussion default; confirm Table 430.52
        }
    }
}

public struct NECCircuitResult: Equatable, Sendable {
    public var fla: Double
    public var designAmps: Double
    public var ambientFactor: Double
    public var cccFactor: Double
    public var totalDerating: Double
    public var conductorSize: String
    public var baseAmpacity: Double
    public var deratedAmpacity: Double
    public var vdVolts: Double
    public var vdPercent: Double
    public var ocpdAmps: Int?
    public var formula: String
    /// Supply the drop was calculated from. Kept on the result so a stale picture does not follow a later edit.
    public var supplyVolts: Double
    public var oneWayFeet: Double
}

/// Ampacity chip on the voltage-drop strip. Meet when usable ampacity covers design current, short when it does not.
public enum NECCircuitAmpacityVerdict: Equatable, Sendable {
    case meets
    case short
}

/// Numbers for the NEC circuit picture: one voltage-drop run, plus the ampacity chip on that strip.
/// This tool has no preferred drop target. The 3% and 5% marks stay informational.
public struct NECCircuitRunReadout: Equatable, Sendable {
    public var supplyVolts: Double
    public var dropVolts: Double
    public var receivingVolts: Double
    public var dropPercent: Double
    public var oneWayFeet: Double
    public var parallelRuns: Int
    public var designAmps: Double
    public var usableAmps: Double
    public var verdict: NECCircuitAmpacityVerdict

    public init?(result: NECCircuitResult) {
        guard result.supplyVolts.isFinite, result.supplyVolts > 0,
              result.vdVolts.isFinite, result.vdVolts >= 0,
              result.vdPercent.isFinite, result.vdPercent >= 0,
              result.oneWayFeet.isFinite, result.oneWayFeet > 0,
              result.designAmps.isFinite, result.designAmps > 0,
              result.deratedAmpacity.isFinite, result.deratedAmpacity > 0
        else { return nil }
        let receiving = result.supplyVolts - result.vdVolts
        guard receiving.isFinite else { return nil }
        supplyVolts = result.supplyVolts
        dropVolts = result.vdVolts
        receivingVolts = receiving
        dropPercent = result.vdPercent
        oneWayFeet = result.oneWayFeet
        parallelRuns = 1
        designAmps = result.designAmps
        usableAmps = result.deratedAmpacity
        verdict = usableAmps + 1e-9 >= designAmps ? .meets : .short
    }

    public var designLabel: String { DeratingStackReadout.ampsLabel(designAmps) }
    public var usableLabel: String { DeratingStackReadout.ampsLabel(usableAmps) }
    public var dropVoltsLabel: String { DeratingStackReadout.siLabel(dropVolts, unit: "V") }
    public var supplyLabel: String { DeratingStackReadout.siLabel(supplyVolts, unit: "V") }
    public var receivingLabel: String { DeratingStackReadout.siLabel(receivingVolts, unit: "V") }
    public var dropPercentLabel: String { Self.percentLabel(dropPercent) }
    public var oneWayLabel: String { "\(Self.quantityLabel(oneWayFeet, digits: 1)) ft" }

    /// Visible chip. Usable amps, the verdict, and the design current the result row already shows.
    public var chipLine: String {
        switch verdict {
        case .meets: return "\(usableLabel) usable · MEETS \(designLabel)"
        case .short: return "\(usableLabel) usable · SHORT \(designLabel)"
        }
    }

    /// VoiceOver. Design current, drop, and the ampacity verdict come first. The canvas is not the value.
    public var announcement: String {
        let verdictSentence: String
        switch verdict {
        case .meets:
            verdictSentence = "\(usableLabel) usable, meets \(designLabel) required."
        case .short:
            verdictSentence = "\(usableLabel) usable, short of \(designLabel) required."
        }
        let runs = parallelRuns == 1 ? "1 parallel run" : "\(parallelRuns) parallel runs"
        return [
            "\(designLabel) design.",
            "\(dropVoltsLabel) drop, \(dropPercentLabel).",
            verdictSentence,
            "\(supplyLabel) supply.",
            "\(receivingLabel) load.",
            "\(oneWayLabel) one-way.",
            "\(runs).",
            "3% and 5% marks are informational.",
        ].joined(separator: " ")
    }

    public static func percentLabel(_ value: Double) -> String {
        "\(quantityLabel(value, digits: 2)) %"
    }

    /// Same rounding as the Toolbox `Format.number` row.
    public static func quantityLabel(_ value: Double, digits: Int) -> String {
        guard value.isFinite else { return "—" }
        let magnitude = abs(value)
        if magnitude >= 1_000_000 { return String(format: "%.2e", value) }
        if magnitude != 0 && magnitude < 0.001 { return String(format: "%.3e", value) }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = digits
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }
}

/// One-shot NEC branch/feeder sketch: design current → derated ampacity → VD → OCPD.
public enum NECCircuitCalc {
    public static func solve(
        fla: Double? = nil,
        loadKW: Double? = nil,
        voltage: Double,
        phases: Int,
        powerFactor: Double = 0.9,
        loadType: NECCircuitLoadType = .continuous,
        oneWayFeet: Double,
        ambientC: Double = 30,
        material: ConductorMaterial = .copper,
        insulation: ConductorTempColumn = .c90,
        termination: ConductorTempColumn = .c75,
        currentCarryingCount: Int = 3
    ) throws -> NECCircuitResult {
        let v = try Positive.require(voltage, name: "System voltage")
        let dist = try Positive.require(oneWayFeet, name: "One-way distance")
        guard phases == 1 || phases == 3 else {
            throw CalcError.outOfRange("Phases must be 1 or 3.")
        }

        let resolvedFLA: Double
        if let given = fla, given.isFinite, given > 0 {
            resolvedFLA = given
        } else if let kw = loadKW {
            let p = try Positive.require(kw, name: "Load")
            let pf = try Positive.require(powerFactor, name: "Power factor")
            guard pf <= 1 else { throw CalcError.outOfRange("Power factor must be ≤ 1.") }
            resolvedFLA = phases == 3
                ? (p * 1000) / (sqrt(3) * v * pf)
                : (p * 1000) / (v * pf)
        } else {
            throw CalcError.missing("FLA or load kW")
        }

        let designI = resolvedFLA * loadType.conductorMultiplier
        let ambient = NECAmpacityFactors.ambientCorrectionFactor(ambientC: ambientC, insulation: insulation)
        guard ambient > 0 else {
            throw CalcError.outOfRange("Ambient exceeds insulation rating. Choose a higher temperature column or cooler ambient.")
        }
        let ccc = try NECAmpacityFactors.cccAdjustmentFactor(currentCarryingCount: currentCarryingCount)
        let derate = ambient * ccc

        let selection = try WireAmpacity.selectConductor(
            loadAmps: resolvedFLA,
            material: material,
            insulation: insulation,
            termination: termination,
            ambientC: ambientC,
            currentCarryingCount: currentCarryingCount,
            parallelRuns: 1,
            continuousLoad: loadType != .noncontinuous
        )

        let size = selection.selected.size
        let base = Double(NECAmpacityFactors.ampacity(size: size, material: material, column: insulation) ?? 0)
        let cm = NECTables.circularMils[size] ?? 0
        let k = material == .copper ? 12.9 : 21.2
        let phaseFactor = phases == 3 ? sqrt(3) : 2.0
        let vdVolts = cm > 0 ? phaseFactor * k * resolvedFLA * dist / cm : 0
        let vdPct = vdVolts / v * 100
        let ocpdNeed = resolvedFLA * loadType.ocpdMultiplier
        let ocpd = NECTables.nextStandardOCPD(ocpdNeed)

        return NECCircuitResult(
            fla: resolvedFLA,
            designAmps: designI,
            ambientFactor: ambient,
            cccFactor: ccc,
            totalDerating: derate,
            conductorSize: size,
            baseAmpacity: base,
            deratedAmpacity: selection.selected.usableTotal,
            vdVolts: vdVolts,
            vdPercent: vdPct,
            ocpdAmps: ocpd,
            formula: "I_des = FLA×mult; pick conductor with derated ampacity ≥ I_des; VD = φ·K·I·L/CM",
            supplyVolts: v,
            oneWayFeet: dist
        )
    }
}
