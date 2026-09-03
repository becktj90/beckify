import Foundation

public struct VoltageDropSizingInput: Equatable, Sendable {
    public var system: ElectricalSystem
    public var supplyVolts: Double
    public var current: Double
    public var oneWayFeet: Double
    public var size: String
    public var material: ConductorMaterial
    public var parallelRuns: Int
    public var targetDropPercent: Double
    public var method: VoltageDropMethod

    public init(
        system: ElectricalSystem,
        supplyVolts: Double,
        current: Double,
        oneWayFeet: Double,
        size: String,
        material: ConductorMaterial,
        parallelRuns: Int = 1,
        targetDropPercent: Double = 3,
        method: VoltageDropMethod = .kFactorApproximation
    ) {
        self.system = system
        self.supplyVolts = supplyVolts
        self.current = current
        self.oneWayFeet = oneWayFeet
        self.size = size
        self.material = material
        self.parallelRuns = parallelRuns
        self.targetDropPercent = targetDropPercent
        self.method = method
    }
}

public enum VoltageDropMethod: String, Codable, CaseIterable, Sendable, Hashable {
    case kFactorApproximation

    public var displayName: String {
        switch self {
        case .kFactorApproximation:
            return "K-factor approximation (Ch.9 Table 9)"
        }
    }

    public var provenance: ResultProvenance { .engineeringApproximation }
}

public struct VoltageDropCandidate: Equatable, Sendable {
    public var size: String
    public var label: String
    public var dropVolts: Double
    public var dropPercent: Double
    public var receivingVolts: Double
    public var ampacity75C: Int?
    public var ampacityOK: Bool
    public var meetsTarget: Bool
    public var meetsAllConstraints: Bool
    public var lossWatts: Double?
}

public struct VoltageDropSizingResult: Equatable, Sendable {
    public var system: ElectricalSystem
    public var material: ConductorMaterial
    public var size: String
    public var label: String
    public var parallelRuns: Int
    public var method: VoltageDropMethod

    public var dropVolts: Double
    public var dropPercent: Double
    public var receivingVolts: Double
    public var supplyVolts: Double
    public var loadAmps: Double
    public var oneWayFeet: Double

    public var meets3Percent: Bool
    public var meets5Percent: Bool
    public var meetsTarget: Bool
    public var targetDropPercent: Double

    public var ampacity75C: Int?
    public var ampacityOK: Bool
    public var ampacityMinimumSize: String?
    public var voltageDropMinimumSize: String?
    public var recommendedSize: String?
    public var recommendedLabel: String?

    public var conductorLossWatts: Double?
    public var candidates: [VoltageDropCandidate]
    public var warnings: [DesignWarning]
    public var citations: [CodeCitation]
    public var formula: String

    /// Compatibility projection for existing UI / diagrams.
    public var legacy: VoltageDropResult {
        VoltageDropResult(
            dropVolts: dropVolts,
            dropPercent: dropPercent,
            receivingVolts: receivingVolts,
            meets3Percent: meets3Percent,
            meets5Percent: meets5Percent,
            conductorSize: size,
            conductorLabel: label,
            ampacity75C: ampacity75C,
            ampacityOK: ampacityOK,
            formula: formula
        )
    }

    public var seedFromAmpacityCompatible: ConductorDesignSeed {
        ConductorDesignSeed(
            sourceToolID: "voltageDrop",
            sourceSummary: "\(label) \(FormatTrace.percent(dropPercent)) drop",
            loadAmps: loadAmps,
            material: material,
            size: recommendedSize ?? size,
            system: system,
            supplyVolts: supplyVolts,
            oneWayFeet: oneWayFeet,
            parallelRuns: parallelRuns
        )
    }
}

/// Professional voltage-drop / conductor-sizing workflow built on the Chapter 9
/// Table 9 K-factor approximation. AC R+X impedance is a follow-up when Table 9
/// reactance data is wired in; this path never claims exact AC impedance.
public enum VoltageDropSizing {
    private static let kCitation = CodeCitation(
        articleOrTable: "Chapter 9 Table 9",
        units: "V",
        sourceDescription: "Approximate DC resistance constant K at 75 °C for voltage-drop estimates"
    )

    private static let noteCitation = CodeCitation(
        articleOrTable: "215.2(A)(1) Informational Note / 210.19(A) Informational Note",
        units: "%",
        sourceDescription: "3% branch / 5% feeder+branch informational voltage-drop guidance — not a universal mandatory limit"
    )

    public static func calculate(_ input: VoltageDropSizingInput) throws -> VoltageDropSizingResult {
        let i = try Positive.require(input.current, name: "Current")
        let length = try Positive.require(input.oneWayFeet, name: "One-way length")
        let vs = try Positive.require(input.supplyVolts, name: "Supply voltage")
        let target = try Positive.require(input.targetDropPercent, name: "Target voltage drop")
        let runs = try WholeCount.parse(Double(max(input.parallelRuns, 1)), name: "Parallel runs")
        guard let cm = NECTables.circularMils[input.size] else {
            throw CalcError.notListed("Unknown conductor size \(input.size).")
        }

        let selected = try candidate(
            system: input.system,
            current: i,
            oneWayFeet: length,
            supplyVolts: vs,
            size: input.size,
            material: input.material,
            parallelRuns: runs,
            targetDropPercent: target
        )

        let ampMin = try? WireAmpacity.selectConductor(
            loadAmps: i,
            material: input.material,
            insulation: .c75,
            termination: .c75,
            ambientC: 30,
            currentCarryingCount: 3,
            parallelRuns: runs,
            continuousLoad: false
        ).selected.size

        var vdMin: String?
        var recommended: String?
        var candidates: [VoltageDropCandidate] = []
        for size in NECTables.wireSizeOrder where NECTables.circularMils[size] != nil {
            guard NECTables.ampacity75C(size: size, material: input.material) != nil else { continue }
            let row = try candidate(
                system: input.system,
                current: i,
                oneWayFeet: length,
                supplyVolts: vs,
                size: size,
                material: input.material,
                parallelRuns: runs,
                targetDropPercent: target
            )
            candidates.append(row)
            if vdMin == nil, row.meetsTarget { vdMin = size }
            if recommended == nil, row.meetsAllConstraints { recommended = size }
        }

        var warnings: [DesignWarning] = [
            DesignWarning(
                severity: .info,
                message: "K-factor method is an engineering approximation from Chapter 9 Table 9 constants, not an exact AC impedance (R·cosθ + X·sinθ) calculation.",
                provenance: .engineeringApproximation
            ),
            DesignWarning(
                severity: .info,
                message: "3% and 5% voltage-drop figures are informational notes, not universal mandatory NEC limits.",
                provenance: .informationalNote
            ),
        ]
        if !selected.ampacityOK {
            warnings.append(DesignWarning(
                severity: .critical,
                message: "Selected \(selected.label) 75 °C ampacity does not meet the \(FormatTrace.amps(i)) load (≤3 CCC, 30 °C ambient check).",
                provenance: .codeRequirement
            ))
        }
        if !selected.meetsTarget {
            warnings.append(DesignWarning(
                severity: .caution,
                message: "Drop \(FormatTrace.percent(selected.dropPercent)) exceeds the preferred target \(FormatTrace.percent(target)).",
                provenance: .designPreference
            ))
        }
        if runs > 1, let minParallel = NECTables.circularMils["1/0"], cm + 1e-9 < minParallel {
            warnings.append(DesignWarning(
                severity: .critical,
                message: "Paralleling generally requires 1/0 AWG and larger (310.10(H)).",
                provenance: .codeRequirement
            ))
        }

        let formula = input.system == .threePhase
            ? "VD ≈ (√3 × K × I × L) / (CM × parallel runs)    [K-factor approximation]"
            : "VD ≈ (2 × K × I × L) / (CM × parallel runs)    [K-factor approximation]"

        return VoltageDropSizingResult(
            system: input.system,
            material: input.material,
            size: input.size,
            label: selected.label,
            parallelRuns: runs,
            method: input.method,
            dropVolts: selected.dropVolts,
            dropPercent: selected.dropPercent,
            receivingVolts: selected.receivingVolts,
            supplyVolts: vs,
            loadAmps: i,
            oneWayFeet: length,
            meets3Percent: selected.dropPercent <= 3,
            meets5Percent: selected.dropPercent <= 5,
            meetsTarget: selected.meetsTarget,
            targetDropPercent: target,
            ampacity75C: selected.ampacity75C,
            ampacityOK: selected.ampacityOK,
            ampacityMinimumSize: ampMin,
            voltageDropMinimumSize: vdMin,
            recommendedSize: recommended,
            recommendedLabel: recommended.map(NECTables.wireLabel),
            conductorLossWatts: selected.lossWatts,
            candidates: candidates,
            warnings: warnings,
            citations: [kCitation, noteCitation, NECAmpacityFactors.tableCitation],
            formula: formula
        )
    }

    private static func candidate(
        system: ElectricalSystem,
        current: Double,
        oneWayFeet: Double,
        supplyVolts: Double,
        size: String,
        material: ConductorMaterial,
        parallelRuns: Int,
        targetDropPercent: Double
    ) throws -> VoltageDropCandidate {
        guard let cm = NECTables.circularMils[size] else {
            throw CalcError.notListed("Unknown conductor size \(size).")
        }
        let m = system.voltageDropMultiplier
        let k = material.resistivityK
        let vd = m * k * current * oneWayFeet / (cm * Double(parallelRuns))
        let pct = vd / supplyVolts * 100
        let amp = NECTables.ampacity75C(size: size, material: material)
        let ampOK = amp.map { Double($0) * Double(parallelRuns) + 1e-9 >= current } ?? false
        let meetsTarget = pct <= targetDropPercent + 1e-9
        let paths = system == .threePhase ? 3.0 : 2.0
        // Approximate I²R using K/CM as Ω/ft DC resistance proxy for loss estimate.
        let rOneWay = (k / cm) * oneWayFeet / Double(parallelRuns)
        let loss = paths * current * current * rOneWay

        return VoltageDropCandidate(
            size: size,
            label: NECTables.wireLabel(size),
            dropVolts: vd,
            dropPercent: pct,
            receivingVolts: supplyVolts - vd,
            ampacity75C: amp,
            ampacityOK: ampOK,
            meetsTarget: meetsTarget,
            meetsAllConstraints: ampOK && meetsTarget,
            lossWatts: loss.isFinite ? loss : nil
        )
    }
}

extension VoltageDrop {
    public static func calculate(
        system: ElectricalSystem,
        current: Double,
        oneWayFeet: Double,
        supplyVolts: Double,
        size: String,
        material: ConductorMaterial,
        parallelRuns: Int,
        targetDropPercent: Double
    ) throws -> VoltageDropSizingResult {
        try VoltageDropSizing.calculate(
            VoltageDropSizingInput(
                system: system,
                supplyVolts: supplyVolts,
                current: current,
                oneWayFeet: oneWayFeet,
                size: size,
                material: material,
                parallelRuns: parallelRuns,
                targetDropPercent: targetDropPercent
            )
        )
    }
}
