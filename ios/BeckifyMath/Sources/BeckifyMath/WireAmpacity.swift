import Foundation

public struct AmpacityDeratingInput: Equatable, Sendable {
    public var size: String
    public var material: ConductorMaterial
    public var insulation: ConductorTempColumn
    public var termination: ConductorTempColumn
    public var ambientC: Double
    public var currentCarryingCount: Int
    public var parallelRuns: Int
    public var continuousLoad: Bool
    public var loadAmps: Double?
    public var ocpdAmps: Double?

    public init(
        size: String,
        material: ConductorMaterial,
        insulation: ConductorTempColumn = .c90,
        termination: ConductorTempColumn = .c75,
        ambientC: Double = 30,
        currentCarryingCount: Int = 3,
        parallelRuns: Int = 1,
        continuousLoad: Bool = false,
        loadAmps: Double? = nil,
        ocpdAmps: Double? = nil
    ) {
        self.size = size
        self.material = material
        self.insulation = insulation
        self.termination = termination
        self.ambientC = ambientC
        self.currentCarryingCount = currentCarryingCount
        self.parallelRuns = parallelRuns
        self.continuousLoad = continuousLoad
        self.loadAmps = loadAmps
        self.ocpdAmps = ocpdAmps
    }
}

public struct AmpacityDeratingResult: Equatable, Sendable {
    public var size: String
    public var label: String
    public var material: ConductorMaterial
    public var insulation: ConductorTempColumn
    public var termination: ConductorTempColumn
    public var ambientC: Double
    public var currentCarryingCount: Int
    public var parallelRuns: Int
    public var continuousLoad: Bool

    public var baseAmpacity: Double
    public var ambientFactor: Double
    public var cccFactor: Double
    public var correctedAmpacity: Double
    public var terminationCap: Double
    public var usablePerRun: Double
    public var usableTotal: Double
    public var limitedByTermination: Bool

    public var loadAmps: Double?
    public var requiredAmpacity: Double?
    public var passesLoad: Bool?
    public var marginAmps: Double?

    public var recommendedOCPD: Int?
    public var ocpdOK: Bool?
    public var nextLargerSize: String?

    public var trace: [CalculationTraceStep]
    public var warnings: [DesignWarning]
    public var citations: [CodeCitation]
    public var formula: String

    public var seedForVoltageDrop: ConductorDesignSeed {
        ConductorDesignSeed(
            sourceToolID: "wireAmpacity",
            sourceSummary: "\(label) \(material.displayName), usable \(FormatTrace.amps(usableTotal))",
            loadAmps: loadAmps ?? usableTotal,
            material: material,
            size: size,
            parallelRuns: parallelRuns,
            insulationCelsius: insulation.rawValue,
            terminationCelsius: termination.rawValue
        )
    }
}

public struct ConductorSelectionResult: Equatable, Sendable {
    public var loadAmps: Double
    public var requiredAmpacity: Double
    public var continuousLoad: Bool
    public var material: ConductorMaterial
    public var insulation: ConductorTempColumn
    public var termination: ConductorTempColumn
    public var ambientC: Double
    public var currentCarryingCount: Int
    public var parallelRuns: Int
    public var selected: AmpacityDeratingResult
    public var nextLarger: AmpacityDeratingResult?
    public var formula: String
}

/// NEC Table 310.16 ampacity with ambient correction, CCC adjustment, and
/// termination capping — calculation order is explicit in the result trace.
public enum WireAmpacity {
    public static var table310_16_75C: [AmpacityRow] {
        NECTables.wireSizeOrder.map { size in
            AmpacityRow(
                size: size,
                label: NECTables.wireLabel(size),
                copper75C: NECTables.ampacity75C(size: size, material: .copper),
                aluminum75C: NECTables.ampacity75C(size: size, material: .aluminum)
            )
        }
    }

    /// Compatibility wrapper: 75 °C column, ≤3 CCC, 30 °C ambient, noncontinuous.
    public static func smallestConductor(loadAmps: Double, material: ConductorMaterial) throws -> WireSizeResult {
        let pick = try selectConductor(
            loadAmps: loadAmps,
            material: material,
            insulation: .c75,
            termination: .c75,
            ambientC: 30,
            currentCarryingCount: 3,
            parallelRuns: 1,
            continuousLoad: false
        )
        return WireSizeResult(
            loadAmps: pick.loadAmps,
            material: material,
            size: pick.selected.size,
            label: pick.selected.label,
            ampacity: Int(pick.selected.usablePerRun.rounded(.towardZero)),
            formula: pick.formula
        )
    }

    public static func evaluate(_ input: AmpacityDeratingInput) throws -> AmpacityDeratingResult {
        let runs = try WholeCount.parse(Double(max(input.parallelRuns, 1)), name: "Parallel runs")
        let ccc = try WholeCount.parse(Double(input.currentCarryingCount), name: "Current-carrying conductor count")
        guard input.ambientC.isFinite else {
            throw CalcError.missing("ambient temperature")
        }
        guard input.termination.rawValue <= input.insulation.rawValue else {
            throw CalcError.outOfRange(
                "Termination rating (\(input.termination.displayName)) cannot exceed insulation rating (\(input.insulation.displayName))."
            )
        }

        guard let base = NECAmpacityFactors.ampacity(size: input.size, material: input.material, column: input.insulation).map(Double.init) else {
            throw CalcError.notListed("No Table 310.16 listing for \(NECTables.wireLabel(input.size)) \(input.material.displayName) at \(input.insulation.displayName).")
        }
        guard let termCap = NECAmpacityFactors.ampacity(size: input.size, material: input.material, column: input.termination).map(Double.init) else {
            throw CalcError.notListed("No Table 310.16 termination column for \(NECTables.wireLabel(input.size)) \(input.material.displayName) at \(input.termination.displayName).")
        }

        let ambient = NECAmpacityFactors.ambientCorrectionFactor(ambientC: input.ambientC, insulation: input.insulation)
        if ambient <= 0 {
            throw CalcError.outOfRange(
                "Ambient \(FormatTrace.number(input.ambientC, digits: 0)) °C exceeds the usable range for \(input.insulation.displayName) insulation (Table 310.15(B)(1))."
            )
        }
        let bundle = try NECAmpacityFactors.cccAdjustmentFactor(currentCarryingCount: ccc)
        let corrected = base * ambient * bundle
        let usablePerRun = min(corrected, termCap)
        let usableTotal = usablePerRun * Double(runs)
        let limitedByTermination = corrected > termCap + 1e-9

        var warnings: [DesignWarning] = []
        if limitedByTermination {
            warnings.append(DesignWarning(
                severity: .caution,
                message: "\(input.insulation.displayName) insulation was used for correction/adjustment, but usable ampacity is capped by the \(input.termination.displayName) termination column (110.14(C)).",
                provenance: .codeRequirement
            ))
        }
        if runs > 1, let cm = NECTables.circularMils[input.size], let minParallel = NECTables.circularMils["1/0"], cm + 1e-9 < minParallel {
            warnings.append(DesignWarning(
                severity: .critical,
                message: "NEC 310.10(H) generally permits paralleling only for 1/0 AWG and larger. Verify exceptions before paralleling \(NECTables.wireLabel(input.size)).",
                provenance: .codeRequirement
            ))
        }

        var required: Double?
        var passes: Bool?
        var margin: Double?
        if let load = input.loadAmps {
            let amps = try Positive.require(load, name: "Load current")
            let need = input.continuousLoad ? amps * 1.25 : amps
            required = need
            passes = usableTotal + 1e-9 >= need
            margin = usableTotal - need
            if passes == false {
                warnings.append(DesignWarning(
                    severity: .critical,
                    message: "Usable ampacity \(FormatTrace.amps(usableTotal)) is below required \(FormatTrace.amps(need)).",
                    provenance: .codeRequirement
                ))
            }
        }

        var ocpdOK: Bool?
        var recommendedOCPD: Int?
        if let need = required {
            recommendedOCPD = NECTables.nextStandardOCPD(need)
        }
        if let ocpd = input.ocpdAmps {
            let device = try Positive.require(ocpd, name: "OCPD rating")
            if let smallMax = smallConductorMaxOCPD(size: input.size), device > Double(smallMax) + 1e-9 {
                ocpdOK = false
                warnings.append(DesignWarning(
                    severity: .critical,
                    message: "240.4(D) generally limits \(NECTables.wireLabel(input.size)) overcurrent protection to \(smallMax) A unless an exception applies.",
                    provenance: .codeRequirement
                ))
            } else if let usable = Optional(usableTotal) {
                ocpdOK = device <= usable + 1e-9 || (recommendedOCPD.map { device <= Double($0) + 1e-9 } ?? false)
            }
        }

        let next = nextLargerSize(after: input.size, material: input.material)

        let trace: [CalculationTraceStep] = [
            CalculationTraceStep(
                id: "base",
                title: "Base table ampacity",
                value: base,
                displayValue: FormatTrace.amps(base),
                provenance: .codeRequirement,
                citation: NECAmpacityFactors.tableCitation,
                note: "\(input.insulation.displayName) column"
            ),
            CalculationTraceStep(
                id: "ambient",
                title: "Temperature correction",
                value: base * ambient,
                displayValue: "×\(FormatTrace.number(ambient, digits: 2))",
                factor: ambient,
                provenance: .codeRequirement,
                citation: NECAmpacityFactors.ambientCitation,
                note: "Ambient \(FormatTrace.number(input.ambientC, digits: 0)) °C"
            ),
            CalculationTraceStep(
                id: "ccc",
                title: "CCC adjustment",
                value: corrected,
                displayValue: "×\(FormatTrace.number(bundle, digits: 2))",
                factor: bundle,
                provenance: .codeRequirement,
                citation: NECAmpacityFactors.cccCitation,
                note: "\(ccc) current-carrying"
            ),
            CalculationTraceStep(
                id: "termination",
                title: "Terminal temperature limit",
                value: termCap,
                displayValue: FormatTrace.amps(termCap),
                provenance: .codeRequirement,
                citation: NECAmpacityFactors.terminationCitation,
                note: "\(input.termination.displayName) column"
            ),
            CalculationTraceStep(
                id: "usable",
                title: "Final allowable ampacity",
                value: usableTotal,
                displayValue: FormatTrace.amps(usableTotal),
                provenance: .codeRequirement,
                citation: NECAmpacityFactors.tableCitation,
                note: runs > 1 ? "\(runs) parallel runs × \(FormatTrace.amps(usablePerRun))" : "Per conductor / raceway set"
            ),
        ]

        return AmpacityDeratingResult(
            size: input.size,
            label: NECTables.wireLabel(input.size),
            material: input.material,
            insulation: input.insulation,
            termination: input.termination,
            ambientC: input.ambientC,
            currentCarryingCount: ccc,
            parallelRuns: runs,
            continuousLoad: input.continuousLoad,
            baseAmpacity: base,
            ambientFactor: ambient,
            cccFactor: bundle,
            correctedAmpacity: corrected,
            terminationCap: termCap,
            usablePerRun: usablePerRun,
            usableTotal: usableTotal,
            limitedByTermination: limitedByTermination,
            loadAmps: input.loadAmps.flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
            requiredAmpacity: required,
            passesLoad: passes,
            marginAmps: margin,
            recommendedOCPD: recommendedOCPD,
            ocpdOK: ocpdOK,
            nextLargerSize: next,
            trace: trace,
            warnings: warnings,
            citations: [
                NECAmpacityFactors.tableCitation,
                NECAmpacityFactors.ambientCitation,
                NECAmpacityFactors.cccCitation,
                NECAmpacityFactors.terminationCitation,
            ],
            formula: "I_allow = min(I_base × F_ambient × F_CCC, I_termination) × parallel runs"
        )
    }

    public static func selectConductor(
        loadAmps: Double,
        material: ConductorMaterial,
        insulation: ConductorTempColumn = .c90,
        termination: ConductorTempColumn = .c75,
        ambientC: Double = 30,
        currentCarryingCount: Int = 3,
        parallelRuns: Int = 1,
        continuousLoad: Bool = false
    ) throws -> ConductorSelectionResult {
        let amps = try Positive.require(loadAmps, name: "Load current")
        let required = continuousLoad ? amps * 1.25 : amps
        let runs = try WholeCount.parse(Double(max(parallelRuns, 1)), name: "Parallel runs")

        var selected: AmpacityDeratingResult?
        for size in NECTables.wireSizeOrder {
            guard NECAmpacityFactors.ampacity(size: size, material: material, column: insulation) != nil else { continue }
            let result = try evaluate(AmpacityDeratingInput(
                size: size,
                material: material,
                insulation: insulation,
                termination: termination,
                ambientC: ambientC,
                currentCarryingCount: currentCarryingCount,
                parallelRuns: runs,
                continuousLoad: continuousLoad,
                loadAmps: amps
            ))
            if result.usableTotal + 1e-9 >= required {
                selected = result
                break
            }
        }
        guard let pick = selected else {
            throw CalcError.notListed(
                "Load \(FormatTrace.amps(amps)) (required \(FormatTrace.amps(required))) exceeds 1000 kcmil \(material.displayName) under these conditions. Increase parallel runs or relax ambient/CCC."
            )
        }

        var next: AmpacityDeratingResult?
        if let nextSize = pick.nextLargerSize {
            next = try? evaluate(AmpacityDeratingInput(
                size: nextSize,
                material: material,
                insulation: insulation,
                termination: termination,
                ambientC: ambientC,
                currentCarryingCount: currentCarryingCount,
                parallelRuns: runs,
                continuousLoad: continuousLoad,
                loadAmps: amps
            ))
        }

        return ConductorSelectionResult(
            loadAmps: amps,
            requiredAmpacity: required,
            continuousLoad: continuousLoad,
            material: material,
            insulation: insulation,
            termination: termination,
            ambientC: ambientC,
            currentCarryingCount: currentCarryingCount,
            parallelRuns: runs,
            selected: pick,
            nextLarger: next,
            formula: continuousLoad
                ? "Required = 1.25 × load; size by Table 310.16 with 310.15 factors and 110.14(C) cap"
                : "Required = load; size by Table 310.16 with 310.15 factors and 110.14(C) cap"
        )
    }

    private static func nextLargerSize(after size: String, material: ConductorMaterial) -> String? {
        guard let idx = NECTables.wireSizeOrder.firstIndex(of: size) else { return nil }
        for candidate in NECTables.wireSizeOrder.dropFirst(idx + 1) {
            if NECAmpacityFactors.ampacity(size: candidate, material: material, column: .c75) != nil {
                return candidate
            }
        }
        return nil
    }

    private static func smallConductorMaxOCPD(size: String) -> Int? {
        switch size {
        case "14": return 15
        case "12": return 20
        case "10": return 30
        default: return nil
        }
    }
}

/// One stage on the derating stack. Ampacity is the circuit total
/// (per conductor × parallel runs). `perConductorAmps` is the trace value.
public struct DeratingStackStage: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var ampacity: Double
    public var perConductorAmps: Double

    public init(id: String, title: String, ampacity: Double, perConductorAmps: Double) {
        self.id = id
        self.title = title
        self.ampacity = ampacity
        self.perConductorAmps = perConductorAmps
    }
}

/// How usable ampacity sits against the required current this tool already reports.
/// No near-miss band: the result is meets or below, or there is no load to compare.
public enum DeratingStackVerdict: Equatable, Sendable {
    case notCompared
    case meetsRequired
    case belowRequired
}

/// Numbers for `DeratingStack`. Four stages, same math as the ampacity trace:
/// 310.16 base, ambient correction, CCC bundling, then the 110.14(C) cap.
/// Bundling and the terminal stage are never longer than the stage before them.
/// Ambient can be longer than the base when the correction factor is above 1.
public struct DeratingStackReadout: Equatable, Sendable {
    public static let stageIDs = ["base", "ambient", "bundling", "terminal"]

    /// Spoken and shown after the ampacity numbers.
    public static let methodLine = "Table 310.16, then ambient correction, bundling, and the 110.14(C) cap."

    public var stages: [DeratingStackStage]
    /// Required ampacity the result already compares to usable total. Nil when no load was entered.
    public var designCurrent: Double?
    public var verdict: DeratingStackVerdict
    public var parallelRuns: Int
    public var usableAmps: Double
    public var limitedByTermination: Bool
    public var terminationColumn: String
    public var terminationCapAmps: Double

    public init?(result: AmpacityDeratingResult) {
        let runs = result.parallelRuns
        guard runs >= 1,
              result.baseAmpacity.isFinite, result.baseAmpacity > 0,
              result.ambientFactor.isFinite, result.ambientFactor > 0,
              result.cccFactor.isFinite, result.cccFactor > 0, result.cccFactor <= 1 + 1e-12,
              result.correctedAmpacity.isFinite, result.correctedAmpacity > 0,
              result.usablePerRun.isFinite, result.usablePerRun > 0,
              result.usableTotal.isFinite, result.usableTotal > 0,
              result.terminationCap.isFinite, result.terminationCap > 0
        else { return nil }

        let base = result.baseAmpacity
        let afterAmbient = base * result.ambientFactor
        let afterBundling = result.correctedAmpacity
        let afterTerminal = result.usablePerRun
        guard afterAmbient.isFinite, afterAmbient > 0,
              afterBundling <= afterAmbient + 1e-6,
              afterTerminal <= afterBundling + 1e-6,
              abs(afterTerminal * Double(runs) - result.usableTotal) <= 1e-4
        else { return nil }

        let multiplier = Double(runs)
        stages = [
            DeratingStackStage(id: "base", title: "310.16", ampacity: base * multiplier, perConductorAmps: base),
            DeratingStackStage(id: "ambient", title: "Ambient", ampacity: afterAmbient * multiplier, perConductorAmps: afterAmbient),
            DeratingStackStage(id: "bundling", title: "Bundling", ampacity: afterBundling * multiplier, perConductorAmps: afterBundling),
            DeratingStackStage(id: "terminal", title: "110.14(C)", ampacity: afterTerminal * multiplier, perConductorAmps: afterTerminal),
        ]
        let required = result.requiredAmpacity
        if let required, required.isFinite, required > 0 {
            designCurrent = required
            if let passes = result.passesLoad {
                verdict = passes ? .meetsRequired : .belowRequired
            } else {
                verdict = result.usableTotal + 1e-9 >= required ? .meetsRequired : .belowRequired
            }
        } else {
            designCurrent = nil
            verdict = .notCompared
        }
        parallelRuns = runs
        usableAmps = result.usableTotal
        limitedByTermination = result.limitedByTermination
        terminationColumn = result.termination.displayName
        terminationCapAmps = result.terminationCap
    }

    public var usableLabel: String { Self.ampsLabel(usableAmps) }
    public var designCurrentLabel: String? { designCurrent.map(Self.ampsLabel) }
    public var terminationCapLabel: String { Self.ampsLabel(terminationCapAmps) }

    public var scaleAmpacity: Double {
        let peak = stages.map(\.ampacity).max() ?? usableAmps
        guard let designCurrent else { return peak }
        return max(peak, designCurrent)
    }

    /// Share of the common scale. Terminal is never a larger share than bundling.
    public func plottedFraction(stageID: String) -> Double? {
        guard scaleAmpacity > 0, let stage = stages.first(where: { $0.id == stageID }) else { return nil }
        return stage.ampacity / scaleAmpacity
    }

    public var clampSentence: String {
        if limitedByTermination {
            return "Clamped at the \(terminationColumn) column, \(terminationCapLabel)."
        }
        return "\(terminationColumn) column \(terminationCapLabel) does not reduce ampacity."
    }

    public var perConductorClause: String? {
        guard parallelRuns > 1 else { return nil }
        let parts = stages.map { "\($0.title) \(Self.ampsLabel($0.perConductorAmps))" }
        return "Per conductor: \(parts.joined(separator: ", "))."
    }

    /// Visible line under the stack. The same words close the VoiceOver summary.
    public var caption: String {
        var parts: [String] = []
        if parallelRuns > 1 {
            parts.append("\(parallelRuns) parallel runs.")
            if let perConductorClause {
                parts.append(perConductorClause)
            }
        }
        parts.append(clampSentence)
        parts.append(Self.methodLine)
        return parts.joined(separator: " ")
    }

    /// VoiceOver. Usable amps and required amps first, then each stage, then the method.
    public var announcement: String {
        let lead: String
        if let designCurrentLabel {
            lead = "\(usableLabel) usable, \(designCurrentLabel) required."
        } else {
            lead = "\(usableLabel) usable."
        }
        let stageSentence = stages.map { "\($0.title) \(Self.ampsLabel($0.ampacity))" }.joined(separator: ". ") + "."
        var parts = [lead, stageSentence]
        switch verdict {
        case .meetsRequired:
            parts.append("Meets required.")
        case .belowRequired:
            parts.append("Below required.")
        case .notCompared:
            break
        }
        parts.append(caption)
        return parts.joined(separator: " ")
    }

    /// Same rounding as the Toolbox `Format.amps` / `Format.volts` rows, so the picture and the result cannot drift.
    public static func ampsLabel(_ value: Double) -> String { siLabel(value, unit: "A") }

    public static func siLabel(_ value: Double, unit: String) -> String {
        guard value.isFinite else { return "—" }
        let magnitude = abs(value)
        if magnitude == 0 { return "0 \(unit)" }
        let decade = floor(log10(magnitude) / 3) * 3
        let clamped = min(12.0, max(-12.0, decade))
        let scaled = magnitude / pow(10, clamped)
        let prefix: String
        switch Int(clamped) {
        case 12: prefix = "T"
        case 9: prefix = "G"
        case 6: prefix = "M"
        case 3: prefix = "k"
        case 0: prefix = ""
        case -3: prefix = "m"
        case -6: prefix = "µ"
        case -9: prefix = "n"
        case -12: prefix = "p"
        default: prefix = ""
        }
        let digits = scaled >= 100 ? 0 : (scaled >= 10 ? 1 : 2)
        let signed = value < 0 ? -scaled : scaled
        let body = grouped(signed, digits: digits)
        return prefix.isEmpty ? "\(body) \(unit)" : "\(body) \(prefix)\(unit)"
    }

    private static func grouped(_ value: Double, digits: Int) -> String {
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

/// Tiny formatting helpers inside BeckifyMath (UI Format lives in the app).
enum FormatTrace {
    static func amps(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f A", value) }
        if value >= 10 { return String(format: "%.1f A", value) }
        return String(format: "%.2f A", value)
    }

    static func number(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }

    static func volts(_ value: Double) -> String {
        String(format: "%.1f V", value)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.2f %%", value)
    }
}

// Preserve legacy row/result types used by the UI table card.
public struct AmpacityRow: Equatable, Sendable {
    public var size: String
    public var label: String
    public var copper75C: Int?
    public var aluminum75C: Int?

    public init(size: String, label: String, copper75C: Int?, aluminum75C: Int?) {
        self.size = size
        self.label = label
        self.copper75C = copper75C
        self.aluminum75C = aluminum75C
    }
}

public struct WireSizeResult: Equatable, Sendable {
    public var loadAmps: Double
    public var material: ConductorMaterial
    public var size: String
    public var label: String
    public var ampacity: Int
    public var formula: String

    public init(loadAmps: Double, material: ConductorMaterial, size: String, label: String, ampacity: Int, formula: String) {
        self.loadAmps = loadAmps
        self.material = material
        self.size = size
        self.label = label
        self.ampacity = ampacity
        self.formula = formula
    }
}
