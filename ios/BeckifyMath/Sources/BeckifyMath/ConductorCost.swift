import Foundation

/// How the optimizer interprets the load field.
public enum ConductorLoadUnit: String, Codable, CaseIterable, Sendable, Hashable {
    case amps
    case kva
    case kw

    public var displayName: String {
        switch self {
        case .amps: return "A"
        case .kva: return "kVA"
        case .kw: return "kW"
        }
    }
}

/// Written LV construction used for fill and first-cost (insulated cores + EGC).
public enum LVConstruction: String, Codable, CaseIterable, Sendable, Hashable {
    case twoPlusE = "2c+e"
    case threePlusE = "3c+e"
    case fourPlusE = "4c+e"

    public var displayName: String {
        switch self {
        case .twoPlusE: return "2C+E"
        case .threePlusE: return "3C+E"
        case .fourPlusE: return "4C+E"
        }
    }

    public var insulatedCores: Int {
        switch self {
        case .twoPlusE: return 2
        case .threePlusE: return 3
        case .fourPlusE: return 4
        }
    }

    public var conductorsPerRun: Int { insulatedCores + 1 }

    public static func `default`(for system: ElectricalSystem) -> LVConstruction {
        system == .threePhase ? .fourPlusE : .threePlusE
    }
}

public struct ConductorCostInput: Equatable, Sendable {
    public var system: ElectricalSystem
    public var supplyVolts: Double
    public var loadValue: Double
    public var loadUnit: ConductorLoadUnit
    public var powerFactor: Double
    public var material: ConductorMaterial
    public var insulation: ConductorTempColumn
    public var termination: ConductorTempColumn
    public var ambientC: Double
    public var currentCarryingCount: Int
    public var continuousLoad: Bool
    public var oneWayFeet: Double
    public var targetDropPercent: Double
    public var maxParallelRuns: Int
    public var construction: LVConstruction
    /// User planning allowance in $/kft. When nil or ≤ 0, the default book is used per size.
    public var dollarsPerKft: Double?
    public var dollarsPerKwh: Double?
    public var hoursPerYear: Double?

    public init(
        system: ElectricalSystem = .threePhase,
        supplyVolts: Double,
        loadValue: Double,
        loadUnit: ConductorLoadUnit = .amps,
        powerFactor: Double = 0.9,
        material: ConductorMaterial = .copper,
        insulation: ConductorTempColumn = .c90,
        termination: ConductorTempColumn = .c75,
        ambientC: Double = 30,
        currentCarryingCount: Int = 3,
        continuousLoad: Bool = false,
        oneWayFeet: Double,
        targetDropPercent: Double = 3,
        maxParallelRuns: Int = 4,
        construction: LVConstruction? = nil,
        dollarsPerKft: Double? = nil,
        dollarsPerKwh: Double? = nil,
        hoursPerYear: Double? = nil
    ) {
        self.system = system
        self.supplyVolts = supplyVolts
        self.loadValue = loadValue
        self.loadUnit = loadUnit
        self.powerFactor = powerFactor
        self.material = material
        self.insulation = insulation
        self.termination = termination
        self.ambientC = ambientC
        self.currentCarryingCount = currentCarryingCount
        self.continuousLoad = continuousLoad
        self.oneWayFeet = oneWayFeet
        self.targetDropPercent = targetDropPercent
        self.maxParallelRuns = maxParallelRuns
        self.construction = construction ?? LVConstruction.default(for: system)
        self.dollarsPerKft = dollarsPerKft
        self.dollarsPerKwh = dollarsPerKwh
        self.hoursPerYear = hoursPerYear
    }
}

public struct ConductorCostOption: Equatable, Sendable {
    public var size: String
    public var label: String
    public var parallelRuns: Int
    public var usableAmpacity: Double
    public var requiredPerRun: Double
    public var ampacityOK: Bool
    public var dropVolts: Double
    public var dropPercent: Double
    public var meetsVoltageDrop: Bool
    public var suggestedEMT: String?
    public var conductorsPerRun: Int
    public var insulatedCores: Int
    public var firstCost: Double
    public var i2rWatts: Double?
    public var annualEnergyCost: Double?
    public var lifecycleCost: Double?
    public var dollarsPerKftUsed: Double
    public var usedUserPrice: Bool
    public var typeString: String
}

public struct ConductorCostResult: Equatable, Sendable {
    public var loadAmps: Double
    public var designCurrent: Double
    public var currentBasis: String
    public var material: ConductorMaterial
    public var system: ElectricalSystem
    public var supplyVolts: Double
    public var oneWayFeet: Double
    public var insulation: ConductorTempColumn
    public var termination: ConductorTempColumn
    public var options: [ConductorCostOption]
    public var recommended: ConductorCostOption
    public var priceSource: String
    public var formula: String
    public var warnings: [DesignWarning]
    public var citations: [CodeCitation]
    public var modeledEnergy: Bool

    public var seed: ConductorDesignSeed {
        let costLabel: String
        if recommended.firstCost >= 100 {
            costLabel = String(format: "$%.0f", recommended.firstCost)
        } else {
            costLabel = String(format: "$%.2f", recommended.firstCost)
        }
        return ConductorDesignSeed(
            sourceToolID: "conductorCost",
            sourceSummary: "\(recommended.typeString), \(costLabel) planning",
            loadAmps: loadAmps,
            material: material,
            size: recommended.size,
            system: system,
            supplyVolts: supplyVolts,
            oneWayFeet: oneWayFeet,
            parallelRuns: recommended.parallelRuns,
            insulationCelsius: insulation.rawValue,
            terminationCelsius: termination.rawValue
        )
    }
}

/// Planning-allowance comparison of compliant sizes and parallel runs.
/// Not a live quote, LME ticker, or bid.
public enum ConductorCost {
    /// Shared planning book, $/ft. Same numbers as the website toolbox.
    public static let planningPricePerFootCopper: [String: Double] = [
        "14": 0.12, "12": 0.18, "10": 0.28, "8": 0.52, "6": 0.80, "4": 1.25,
        "3": 1.55, "2": 1.95, "1": 2.45, "1/0": 3.00, "2/0": 3.75, "3/0": 4.65,
        "4/0": 5.75, "250": 6.85, "300": 8.10, "350": 9.40, "400": 10.70,
        "500": 13.20, "600": 16.00, "700": 18.20, "750": 19.80, "800": 21.00,
        "900": 23.50, "1000": 26.00,
    ]

    public static let planningPricePerFootAluminum: [String: Double] = [
        "12": 0.09, "10": 0.13, "8": 0.20, "6": 0.30, "4": 0.42, "3": 0.50,
        "2": 0.60, "1": 0.72, "1/0": 0.88, "2/0": 1.05, "3/0": 1.28, "4/0": 1.55,
        "250": 1.85, "300": 2.15, "350": 2.45, "400": 2.75, "500": 3.40,
        "600": 4.05, "700": 4.70, "750": 5.00, "800": 5.30, "900": 5.90, "1000": 6.60,
    ]

    public static func planningDollarsPerKft(size: String, material: ConductorMaterial) -> Double? {
        planningPricePerFoot(size: size, material: material).map { $0 * 1000 }
    }

    public static func planningPricePerFoot(size: String, material: ConductorMaterial) -> Double? {
        switch material {
        case .copper: return planningPricePerFootCopper[size]
        case .aluminum: return planningPricePerFootAluminum[size]
        }
    }

    public static func loadCurrent(
        system: ElectricalSystem,
        supplyVolts: Double,
        loadValue: Double,
        loadUnit: ConductorLoadUnit,
        powerFactor: Double
    ) throws -> (amps: Double, basis: String) {
        let vs = try Positive.require(supplyVolts, name: "Supply voltage")
        let load = try Positive.require(loadValue, name: "Load")
        let three = system == .threePhase
        switch loadUnit {
        case .amps:
            return (load, "Entered directly")
        case .kva:
            let amps = three ? (load * 1000) / (Foundation.sqrt(3.0) * vs) : (load * 1000) / vs
            return (amps, three ? "I = kVA×1000 / (√3 × V)" : "I = kVA×1000 / V")
        case .kw:
            let pf = try Positive.require(powerFactor, name: "Power factor")
            guard pf <= 1 else { throw CalcError.outOfRange("Power factor must be between 0 and 1.") }
            let amps = three
                ? (load * 1000) / (Foundation.sqrt(3.0) * vs * pf)
                : (load * 1000) / (vs * pf)
            return (amps, three ? "I = kW×1000 / (√3 × V × PF)" : "I = kW×1000 / (V × PF)")
        }
    }

    public static func optimize(_ input: ConductorCostInput) throws -> ConductorCostResult {
        if input.termination.rawValue > input.insulation.rawValue {
            throw CalcError.outOfRange(
                "Termination rating (\(input.termination.displayName)) cannot exceed insulation rating (\(input.insulation.displayName))."
            )
        }
        let (current, basis) = try loadCurrent(
            system: input.system,
            supplyVolts: input.supplyVolts,
            loadValue: input.loadValue,
            loadUnit: input.loadUnit,
            powerFactor: input.powerFactor
        )
        let length = try Positive.require(input.oneWayFeet, name: "One-way length")
        let vs = try Positive.require(input.supplyVolts, name: "Supply voltage")
        let target = try Positive.require(input.targetDropPercent, name: "Maximum voltage drop")
        let maxRuns = try WholeCount.parse(Double(max(input.maxParallelRuns, 1)), name: "Max parallel runs")
        let ccc = try WholeCount.parse(Double(input.currentCarryingCount), name: "Current-carrying conductor count")
        if let kft = input.dollarsPerKft, kft.isFinite, kft < 0 {
            throw CalcError.outOfRange("Planning $/kft cannot be negative.")
        }
        let userKft = input.dollarsPerKft.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let designCurrent = input.continuousLoad ? current * 1.25 : current
        let minParallelCM = NECTables.circularMils["1/0"] ?? 105_600
        let energyReady = (input.dollarsPerKwh ?? 0) > 0 && (input.hoursPerYear ?? 0) > 0

        var options: [ConductorCostOption] = []
        for runs in 1...maxRuns {
            for size in NECTables.wireSizeOrder {
                if runs > 1 {
                    guard let cm = NECTables.circularMils[size], cm + 1e-9 >= minParallelCM else { continue }
                }
                let amp = try? WireAmpacity.evaluate(AmpacityDeratingInput(
                    size: size,
                    material: input.material,
                    insulation: input.insulation,
                    termination: input.termination,
                    ambientC: input.ambientC,
                    currentCarryingCount: ccc,
                    parallelRuns: runs,
                    continuousLoad: input.continuousLoad,
                    loadAmps: current
                ))
                guard let amp, amp.usableTotal + 1e-9 >= designCurrent else { continue }

                let vd = try VoltageDropSizing.calculate(VoltageDropSizingInput(
                    system: input.system,
                    supplyVolts: vs,
                    current: current,
                    oneWayFeet: length,
                    size: size,
                    material: input.material,
                    parallelRuns: runs,
                    targetDropPercent: target
                ))
                guard vd.meetsTarget else { continue }

                let bookFt = planningPricePerFoot(size: size, material: input.material)
                let pricePerFt: Double
                let usedUser: Bool
                if let userKft {
                    pricePerFt = userKft / 1000
                    usedUser = true
                } else if let bookFt {
                    pricePerFt = bookFt
                    usedUser = false
                } else {
                    continue
                }

                let first = pricePerFt * length * Double(input.construction.insulatedCores) * Double(runs)
                let i2r = i2rWatts(
                    current: current,
                    size: size,
                    material: input.material,
                    oneWayFeet: length,
                    runs: runs,
                    system: input.system
                )
                let annual: Double?
                if energyReady, let i2r {
                    annual = (i2r / 1000) * (input.dollarsPerKwh ?? 0) * (input.hoursPerYear ?? 0)
                } else {
                    annual = nil
                }

                let fillGroups = [
                    ConduitFillGroup(
                        quantity: input.construction.conductorsPerRun,
                        size: size,
                        insulation: .thhn
                    ),
                ]
                let emt = try? ConduitFill.suggestedTradeSize(groups: fillGroups, raceway: .emt)

                let matTag = input.material == .copper ? "Cu" : "Al"
                let insulTag: String
                switch input.insulation {
                case .c90: insulTag = "THHN"
                case .c75: insulTag = "THWN"
                case .c60: insulTag = "TW"
                }
                let runPrefix = runs > 1 ? "\(runs) × " : ""
                let typeString = "\(runPrefix)\(input.construction.displayName) \(NECTables.wireLabel(size)) \(matTag) \(insulTag)"
                    .replacingOccurrences(of: "  ", with: " ")

                options.append(ConductorCostOption(
                    size: size,
                    label: NECTables.wireLabel(size),
                    parallelRuns: runs,
                    usableAmpacity: amp.usableTotal,
                    requiredPerRun: designCurrent / Double(runs),
                    ampacityOK: true,
                    dropVolts: vd.dropVolts,
                    dropPercent: vd.dropPercent,
                    meetsVoltageDrop: true,
                    suggestedEMT: emt,
                    conductorsPerRun: input.construction.conductorsPerRun,
                    insulatedCores: input.construction.insulatedCores,
                    firstCost: first,
                    i2rWatts: i2r,
                    annualEnergyCost: annual,
                    lifecycleCost: annual.map { first + $0 },
                    dollarsPerKftUsed: pricePerFt * 1000,
                    usedUserPrice: usedUser,
                    typeString: typeString
                ))
            }
        }

        guard !options.isEmpty else {
            throw CalcError.notListed(
                "No conductor from 14 AWG to 1000 kcmil satisfies both ampacity and the \(FormatTrace.percent(target)) voltage-drop limit, up to \(maxRuns) parallel run(s). Increase the allowed runs or relax the voltage-drop limit."
            )
        }

        // First-cost is the modeled ranking. When I²R energy is present, lifecycle
        // (first + one year of modeled energy) is the tie-breaker after first-cost.
        let ranked = options.sorted { lhs, rhs in
            if abs(lhs.firstCost - rhs.firstCost) > 1e-9 { return lhs.firstCost < rhs.firstCost }
            if energyReady {
                let lLife = lhs.lifecycleCost ?? lhs.firstCost
                let rLife = rhs.lifecycleCost ?? rhs.firstCost
                if abs(lLife - rLife) > 1e-9 { return lLife < rLife }
            }
            if lhs.parallelRuns != rhs.parallelRuns { return lhs.parallelRuns < rhs.parallelRuns }
            let lcm = NECTables.circularMils[lhs.size] ?? 0
            let rcm = NECTables.circularMils[rhs.size] ?? 0
            return lcm < rcm
        }

        let recommended = ranked[0]
        var warnings: [DesignWarning] = [
            DesignWarning(
                severity: .info,
                message: "Planning allowance only — not a live market quote, LME print, or bid. Enter your takeoff $/kft when you have one.",
                provenance: .engineeringApproximation
            ),
            DesignWarning(
                severity: .info,
                message: "Voltage drop uses the Chapter 9 Table 9 K-factor approximation. 3% / 5% figures are informational notes, not a hard NEC limit.",
                provenance: .informationalNote
            ),
            DesignWarning(
                severity: .info,
                message: "Parallel runs are offered only for 1/0 AWG and larger (310.10(G) spirit). Every conductor of a paralleled set must be the same length, size, and material.",
                provenance: .codeRequirement
            ),
        ]
        if input.continuousLoad {
            warnings.append(DesignWarning(
                severity: .info,
                message: "Continuous load is sized at 125% (210.19(A) / 215.2(A)). I²R energy uses the operating current, not the 125% design current.",
                provenance: .codeRequirement
            ))
        }

        return ConductorCostResult(
            loadAmps: current,
            designCurrent: designCurrent,
            currentBasis: basis,
            material: input.material,
            system: input.system,
            supplyVolts: vs,
            oneWayFeet: length,
            insulation: input.insulation,
            termination: input.termination,
            options: ranked,
            recommended: recommended,
            priceSource: userKft != nil
                ? "User planning $/kft"
                : "Default planning allowance book (not a quote)",
            formula: input.continuousLoad
                ? "Required = 1.25 × I; rank compliant size×runs by modeled first-cost"
                : "Required = I; rank compliant size×runs by modeled first-cost",
            warnings: warnings,
            citations: [
                NECAmpacityFactors.tableCitation,
                NECAmpacityFactors.ambientCitation,
                NECAmpacityFactors.cccCitation,
                NECAmpacityFactors.terminationCitation,
                CodeCitation(
                    articleOrTable: "310.10(G)",
                    units: "",
                    sourceDescription: "Paralleled conductors generally 1/0 AWG and larger, same length/size/material"
                ),
                CodeCitation(
                    articleOrTable: "Chapter 9 Table 9",
                    units: "V",
                    sourceDescription: "K-factor voltage-drop approximation"
                ),
                CodeCitation(
                    articleOrTable: "Chapter 9 Table 8",
                    units: "Ω/kft",
                    sourceDescription: "DC resistance used for optional I²R energy"
                ),
                CodeCitation(
                    articleOrTable: "Chapter 9 Tables 1 / 4 / 5",
                    units: "in²",
                    sourceDescription: "Suggested EMT from THHN areas at Table 1 fill"
                ),
            ],
            modeledEnergy: energyReady
        )
    }

    /// I²R from operating current and Chapter 9 Table 8 DC Ω/kft.
    /// 3Ø: 3 × I² × R_one_way; 1Ø/DC: 2 × I² × R_one_way.
    public static func i2rWatts(
        current: Double,
        size: String,
        material: ConductorMaterial,
        oneWayFeet: Double,
        runs: Int,
        system: ElectricalSystem
    ) -> Double? {
        guard current > 0, oneWayFeet > 0, runs >= 1 else { return nil }
        guard let rKft = NECTables.dcResistanceOhmPerKft[material]?[size] else { return nil }
        let rOneWay = rKft * (oneWayFeet / 1000) / Double(runs)
        let paths = system == .threePhase ? 3.0 : 2.0
        return paths * current * current * rOneWay
    }
}

