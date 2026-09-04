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
            formula: "I_des = FLA×mult; pick conductor with derated ampacity ≥ I_des; VD = φ·K·I·L/CM"
        )
    }
}
