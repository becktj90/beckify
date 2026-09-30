import Foundation

/// Portable and industrial flexible-cable ampacity.
///
/// SO / SJO / STO families share one copper column of NEC Table 400.5(A)(1).
/// Type W uses the 90 °C copper column of Table 400.5(A)(2) as printed on
/// portable-power catalogs that cite that table. Building wire (THHN in
/// conduit) stays on Table 310.16 — this type does not invent a second copy.
///
/// Planning aid. The AHJ and the manufacturer prevail. Missing cells are
/// omitted rather than interpolated.
public enum FlexibleCableFamily: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case so
    case sjo
    case sto
    case typeW

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .so: return "SO / SOOW (600 V)"
        case .sjo: return "SJO / SJOW (300 V)"
        case .sto: return "STO / SJT (thermoplastic)"
        case .typeW: return "Type W (portable power)"
        }
    }

    /// Jacket letters that share this family's ampacity column.
    public var listedTypes: String {
        switch self {
        case .so: return "S, SO, SOW, SOO, SOOW"
        case .sjo: return "SJ, SJO, SJOW, SJOO, SJOOW"
        case .sto: return "ST, STO, STOW, STOO, STOOW, SJT, SJTW, SJTO, SJTOW, SJTOO, SJTOOW"
        case .typeW: return "Type W"
        }
    }

    public var voltageNote: String {
        switch self {
        case .so: return "Extra-hard service, typically 600 V"
        case .sjo: return "Hard service (junior), typically 300 V"
        case .sto: return "Thermoplastic portable cord. STO is typically 600 V; SJT is the 300 V junior. Same ampacity column."
        case .typeW: return "Portable power / mining cable, often 2000 V"
        }
    }

    public var usesPortableCordTable: Bool { self != .typeW }

    /// Table 400.5(A)(1) does not split SO vs SOOW into 60/75/90 ampacity columns.
    /// Insulation temperature only selects the ambient-correction column.
    public var insulationChangesBaseAmpacity: Bool { self == .typeW }
}

public struct FlexibleCableInstallNote: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var body: String

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

public struct FlexibleCableChartPoint: Equatable, Sendable, Identifiable {
    public var size: String
    public var label: String
    public var tableAmps: Double
    public var source: String
    public var isSelected: Bool
    public var isRecommended: Bool

    public var id: String { size }

    public init(
        size: String,
        label: String,
        tableAmps: Double,
        source: String,
        isSelected: Bool,
        isRecommended: Bool
    ) {
        self.size = size
        self.label = label
        self.tableAmps = tableAmps
        self.source = source
        self.isSelected = isSelected
        self.isRecommended = isRecommended
    }
}

public struct FlexibleCableSizePick: Equatable, Sendable {
    public var size: String
    public var label: String
    public var allowableAmpacity: Double
    public var tableAmps: Double
    public var source: String

    public init(size: String, label: String, allowableAmpacity: Double, tableAmps: Double, source: String) {
        self.size = size
        self.label = label
        self.allowableAmpacity = allowableAmpacity
        self.tableAmps = tableAmps
        self.source = source
    }
}

public struct FlexibleCableAmpacityInput: Equatable, Sendable {
    public var family: FlexibleCableFamily
    public var size: String
    /// When set, this circular-mil value picks the size. It is not interpolated.
    public var circularMils: Double?
    public var conductorCount: Int
    public var material: ConductorMaterial
    public var insulation: ConductorTempColumn
    public var ambientC: Double
    public var currentCarryingCount: Int
    public var continuousLoad: Bool
    public var loadAmps: Double?

    public init(
        family: FlexibleCableFamily,
        size: String,
        circularMils: Double? = nil,
        conductorCount: Int,
        material: ConductorMaterial = .copper,
        insulation: ConductorTempColumn = .c90,
        ambientC: Double = 30,
        currentCarryingCount: Int,
        continuousLoad: Bool = false,
        loadAmps: Double? = nil
    ) {
        self.family = family
        self.size = size
        self.circularMils = circularMils
        self.conductorCount = conductorCount
        self.material = material
        self.insulation = insulation
        self.ambientC = ambientC
        self.currentCarryingCount = currentCarryingCount
        self.continuousLoad = continuousLoad
        self.loadAmps = loadAmps
    }
}

public struct FlexibleCableAmpacityResult: Equatable, Sendable {
    public var family: FlexibleCableFamily
    public var size: String
    public var label: String
    public var material: ConductorMaterial
    public var conductorCount: Int
    public var currentCarryingCount: Int
    public var insulation: ConductorTempColumn
    public var ambientC: Double
    public var continuousLoad: Bool

    public var baseAmpacity: Double
    public var columnLabel: String
    public var tableName: String
    public var source: String
    public var ambientFactor: Double
    public var bundleFactor: Double
    public var allowableAmpacity: Double

    public var loadAmps: Double?
    public var requiredAmpacity: Double?
    public var passesLoad: Bool?
    public var recommendation: FlexibleCableSizePick?

    public var chart: [FlexibleCableChartPoint]
    public var installNotes: [FlexibleCableInstallNote]
    public var warnings: [String]
    public var formula: String
    public var limit: String
}

/// Lookups for NEC Table 400.5(A)(1) portable cord and Table 400.5(A)(2) Type W.
public enum FlexibleCableAmpacity {
    /// Selector ceiling. Table values above this may still be looked up.
    public static let selectionCeilingAmps: Double = 400

    public static let limitStatement = "Planning aid. The AHJ and the cable manufacturer prevail. Not a listing, not a PE stamp, and not permission to use cord as fixed wiring."

    public static let cordTableName = "NEC Table 400.5(A)(1)"
    public static let typeWTableName = "NEC Table 400.5(A)(2)"

    public static let cordSource = "NEC Table 400.5(A)(1), copper, 30°C ambient. Column A is three current-carrying conductors; Column B is two. The equipment grounding conductor is not counted. Types in this column include S, SJ, SJO, SJOW, SJOO, SJOOW, SO, SOW, SOO, SOOW, and the thermoplastic ST/STO/SJT family printed in the same column. A 90°C jacket mark does not raise this number. Not Table 310.16."

    public static let typeWSource = "NEC Table 400.5(A)(2), copper, 90°C conductor, 30°C ambient. Values as printed on Type W portable-power sheets that cite this table (Southwire, citing the 2011 Table 400.5(B) numbering; 3-conductor cells through 4/0 also match Priority Wire, General Cable / Carol, and AZ Wire). Single-conductor 4/0 at 405 A is the 90°C cell of that NEC table. 60°C and 75°C columns are not transcribed. Not Table 310.16."

    /// Table 400.5(A)(3) — percent of the 3-CCC value when more than three carry current.
    public static func bundleFactor(currentCarryingCount: Int) -> Double {
        switch currentCarryingCount {
        case ...3: return 1
        case 4...6: return 0.80
        case 7...9: return 0.70
        case 10...20: return 0.50
        case 21...30: return 0.45
        case 31...40: return 0.40
        default: return 0.35
        }
    }

    public static func installNotes(for family: FlexibleCableFamily) -> [FlexibleCableInstallNote] {
        let lead: FlexibleCableInstallNote
        switch family {
        case .so:
            lead = FlexibleCableInstallNote(
                id: "family",
                title: "SO / SOOW, not THHN",
                body: "Extra-hard service cord, 600 V. Ampacity is Table 400.5(A)(1), the same column as SJO and STO/SJT — a 90°C mark does not raise it. Fixed wire in raceway is THHN: Wire Size & Ampacity, Table 310.16. Heavier portable power is Type W."
            )
        case .sjo:
            lead = FlexibleCableInstallNote(
                id: "family",
                title: "SJO / SJOW, not SO or THHN",
                body: "Hard-service junior cord, 300 V. Same Table 400.5(A)(1) ampacities as SO / SOOW. Extra-hard or 600 V work usually wants the SO family. THHN in conduit is Table 310.16, not this column."
            )
        case .sto:
            lead = FlexibleCableInstallNote(
                id: "family",
                title: "STO / SJT, not Type W",
                body: "Thermoplastic portable cord in the same Table 400.5(A)(1) column as SO and SJO. STO is typically 600 V; SJT is the 300 V junior. Neither is THHN, and neither is Type W mining cable."
            )
        case .typeW:
            lead = FlexibleCableInstallNote(
                id: "family",
                title: "Type W, not SO or THHN",
                body: "Portable power and mining cable. This tool uses the 90°C copper column of Table 400.5(A)(2), including single conductor. SO / SJO stay on Table 400.5(A)(1) and stop at 2 AWG. THHN in conduit is Table 310.16."
            )
        }
        return [
            lead,
            FlexibleCableInstallNote(
                id: "entry",
                title: "How it enters the enclosure",
                body: "Cord and Type W end on a listed cord connector sized to the jacket (400.10). That is not a conduit-fill problem. A whip of building wire is the other path: LFMC or another Chapter 3 raceway, then Conduit Fill and Wire Size & Ampacity."
            ),
            FlexibleCableInstallNote(
                id: "enclosure",
                title: "When NEMA/IP or conduit type matters",
                body: "Ampacity does not pick the box. Wet or outdoor gear needs an enclosure that matches the spot. NEMA types and IP codes are in Reference Library — this tool does not cross a cable to one. If the last length is raceway, conduit type matters: LFMC where liquidtight, FMC only where dry, RMC or IMC for physical protection."
            ),
        ]
    }

    public static func sizes(for family: FlexibleCableFamily, currentCarryingCount: Int) -> [String] {
        if family.usesPortableCordTable, currentCarryingCount < 2 { return [] }
        let column = columnKind(family: family, currentCarryingCount: max(currentCarryingCount, 1))
        return rows(for: family).compactMap { row in
            cell(row, column: column) == nil ? nil : row.size
        }
    }

    public static func evaluate(_ input: FlexibleCableAmpacityInput) throws -> FlexibleCableAmpacityResult {
        let conductors = try WholeCount.parse(Double(input.conductorCount), name: "Conductor count")
        let ccc = try WholeCount.parse(Double(input.currentCarryingCount), name: "Current-carrying conductor count")
        guard ccc <= conductors else {
            throw CalcError.outOfRange("Current-carrying conductors (\(ccc)) cannot exceed the conductor count (\(conductors)). A grounding conductor is not current-carrying.")
        }
        guard input.material == .copper else {
            throw CalcError.notListed("Article 400 tables transcribed here are copper. No aluminum Type W or portable-cord ampacity is in this tool.")
        }
        guard input.ambientC.isFinite else {
            throw CalcError.missing("ambient temperature")
        }
        if input.family == .typeW, input.insulation != .c90 {
            throw CalcError.notListed("Type W in this tool is the 90°C column of Table 400.5(A)(2). The 60°C and 75°C columns are in the Code book and are not transcribed — do not treat the 90°C number as a \(input.insulation.displayName) listing.")
        }
        if input.family.usesPortableCordTable, ccc < 2 {
            throw CalcError.notListed("Table 400.5(A)(1) starts at two current-carrying conductors (Column B). A single conductor is Type W, Table 400.5(A)(2), in this tool.")
        }

        let size = try resolveSize(input.size, circularMils: input.circularMils, family: input.family, currentCarryingCount: ccc)
        let looked = try lookup(family: input.family, size: size, currentCarryingCount: ccc, insulation: input.insulation, ambientC: input.ambientC)

        var required: Double?
        var passes: Bool?
        var recommendation: FlexibleCableSizePick?
        if let load = input.loadAmps {
            let amps = try Positive.require(load, name: "Target load")
            let need = input.continuousLoad ? amps * 1.25 : amps
            guard need <= selectionCeilingAmps + 1e-9 else {
                throw CalcError.outOfRange("This selector stops at \(FormatTrace.amps(selectionCeilingAmps)). \(FormatTrace.amps(need)) is above that. Look up a size, or split the load. The transcribed tables are not a license to interpolate past the ceiling.")
            }
            required = need
            passes = looked.allowable + 1e-9 >= need
            recommendation = try select(
                family: input.family,
                currentCarryingCount: ccc,
                insulation: input.insulation,
                ambientC: input.ambientC,
                required: need
            )
        }

        var warnings: [String] = []
        if input.family.usesPortableCordTable {
            warnings.append("Table 400.5(A)(1) has one copper value per size and column. \(input.insulation.displayName) insulation changes ambient correction only, not the base ampacity.")
        } else {
            warnings.append("Only the 90°C Type W column is transcribed. A 75°C termination can still limit the circuit under 110.14(C). This tool does not apply a Table 310.16 cap.")
        }
        if ccc > 3 {
            warnings.append("More than three current-carrying conductors: Table 400.5(A)(3) multiplies the three-conductor value by \(formatFactor(looked.bundleFactor)).")
        }
        if input.continuousLoad {
            warnings.append("Continuous-load 125% is a planning check in the spirit of 210.19(A). Cord overcurrent protection is 240.5 and is not calculated here.")
        }
        warnings.append(limitStatement)

        let chart = chartPoints(
            family: input.family,
            currentCarryingCount: ccc,
            selected: size,
            recommended: recommendation?.size
        )

        return FlexibleCableAmpacityResult(
            family: input.family,
            size: size,
            label: label(for: size),
            material: .copper,
            conductorCount: conductors,
            currentCarryingCount: ccc,
            insulation: input.insulation,
            ambientC: input.ambientC,
            continuousLoad: input.continuousLoad,
            baseAmpacity: looked.base,
            columnLabel: looked.columnLabel,
            tableName: input.family.usesPortableCordTable ? cordTableName : typeWTableName,
            source: looked.source,
            ambientFactor: looked.ambient,
            bundleFactor: looked.bundleFactor,
            allowableAmpacity: looked.allowable,
            loadAmps: input.loadAmps,
            requiredAmpacity: required,
            passesLoad: passes,
            recommendation: recommendation,
            chart: chart,
            installNotes: installNotes(for: input.family),
            warnings: warnings,
            formula: "Allowable = table ampacity × Table 310.15(B)(1) ambient factor × Table 400.5(A)(3) adjustment. Required = load, or load × 1.25 when continuous. Smallest listed size whose allowable ≥ required, at or under 400 A.",
            limit: limitStatement
        )
    }

    // MARK: - Tables

    private struct Row {
        var size: String
        /// Table 400.5(A)(1) Column A — 3 current-carrying conductors.
        var cordA: Int?
        /// Table 400.5(A)(1) Column B — 2 current-carrying conductors.
        var cordB: Int?
        /// Table 400.5(A)(2) Type W, 90°C, 1 conductor.
        var typeW1: Int?
        /// Table 400.5(A)(2) Type W, 90°C, 2 current-carrying conductors.
        var typeW2: Int?
        /// Table 400.5(A)(2) Type W, 90°C, 3 current-carrying conductors.
        var typeW3: Int?
    }

    /// Chapter 9 Table 8 circular mils for cord sizes below 14 AWG.
    /// Larger sizes reuse `NECTables.circularMils`. 17 and 15 AWG are in the
    /// ampacity table and are not given an invented circular-mil key.
    private static let smallCircularMils: [String: Double] = [
        "18": 1620,
        "16": 2580,
    ]

    /// Portable-cord column of Table 400.5(A)(1). Even sizes match the
    /// published column (18 AWG Column A 7 A / Column B 10 A through 2 AWG
    /// 80 A / 95 A). 17 and 15 AWG are in the same column of that table.
    private static let cordRows: [Row] = [
        Row(size: "18", cordA: 7, cordB: 10),
        Row(size: "17", cordA: 9, cordB: 12),
        Row(size: "16", cordA: 10, cordB: 13),
        Row(size: "15", cordA: 12, cordB: 16),
        Row(size: "14", cordA: 15, cordB: 18),
        Row(size: "12", cordA: 20, cordB: 25),
        Row(size: "10", cordA: 25, cordB: 30),
        Row(size: "8", cordA: 35, cordB: 40),
        Row(size: "6", cordA: 45, cordB: 55),
        Row(size: "4", cordA: 60, cordB: 70),
        Row(size: "2", cordA: 80, cordB: 95),
    ]

    /// Type W 90°C copper. Cells that were not printed in a cited sheet are absent.
    /// 1-conductor 3/0, 250, and 350 kcmil are omitted on purpose.
    /// 2-conductor stops at 4/0 (361 A) — that column does not reach 400 A here.
    private static let typeWRows: [Row] = [
        Row(size: "8", typeW1: 80, typeW2: 74, typeW3: 65),
        Row(size: "6", typeW1: 105, typeW2: 99, typeW3: 87),
        Row(size: "4", typeW1: 140, typeW2: 130, typeW3: 114),
        Row(size: "2", typeW1: 190, typeW2: 174, typeW3: 152),
        Row(size: "1", typeW1: 220, typeW2: 202, typeW3: 177),
        Row(size: "1/0", typeW1: 260, typeW2: 234, typeW3: 205),
        Row(size: "2/0", typeW1: 300, typeW2: 271, typeW3: 237),
        Row(size: "3/0", typeW2: 313, typeW3: 274),
        Row(size: "4/0", typeW1: 405, typeW2: 361, typeW3: 316),
        Row(size: "250", typeW3: 352),
        Row(size: "350", typeW3: 433),
        Row(size: "500", typeW1: 700, typeW3: 536),
    ]

    private enum Column {
        case cordA
        case cordB
        case typeW1
        case typeW2
        case typeW3
    }

    private struct LookedUp {
        var base: Double
        var allowable: Double
        var ambient: Double
        var bundleFactor: Double
        var columnLabel: String
        var source: String
    }

    private static func rows(for family: FlexibleCableFamily) -> [Row] {
        family.usesPortableCordTable ? cordRows : typeWRows
    }

    private static func columnKind(family: FlexibleCableFamily, currentCarryingCount: Int) -> Column {
        if family.usesPortableCordTable {
            return currentCarryingCount <= 2 ? .cordB : .cordA
        }
        switch currentCarryingCount {
        case 1: return .typeW1
        case 2: return .typeW2
        default: return .typeW3
        }
    }

    private static func cell(_ row: Row, column: Column) -> Int? {
        switch column {
        case .cordA: return row.cordA
        case .cordB: return row.cordB
        case .typeW1: return row.typeW1
        case .typeW2: return row.typeW2
        case .typeW3: return row.typeW3
        }
    }

    private static func columnLabel(family: FlexibleCableFamily, currentCarryingCount: Int) -> String {
        if family.usesPortableCordTable {
            if currentCarryingCount <= 2 {
                return "Column B — 2 current-carrying conductors"
            }
            if currentCarryingCount == 3 {
                return "Column A — 3 current-carrying conductors"
            }
            return "Column A × Table 400.5(A)(3) — \(currentCarryingCount) current-carrying conductors"
        }
        if currentCarryingCount == 1 {
            return "1 conductor, 90°C"
        }
        if currentCarryingCount == 2 {
            return "2 current-carrying conductors, 90°C"
        }
        if currentCarryingCount == 3 {
            return "3 current-carrying conductors, 90°C"
        }
        return "3-conductor 90°C value × Table 400.5(A)(3) — \(currentCarryingCount) current-carrying conductors"
    }

    private static func lookup(
        family: FlexibleCableFamily,
        size: String,
        currentCarryingCount: Int,
        insulation: ConductorTempColumn,
        ambientC: Double
    ) throws -> LookedUp {
        let column = columnKind(family: family, currentCarryingCount: currentCarryingCount)
        guard let row = rows(for: family).first(where: { $0.size == size }),
              let baseInt = cell(row, column: column) else {
            throw CalcError.notListed("\(label(for: size)) is not listed for \(family.displayName) with \(currentCarryingCount) current-carrying conductor\(currentCarryingCount == 1 ? "" : "s"). This tool does not interpolate a missing cell.")
        }
        let ambient = NECAmpacityFactors.ambientCorrectionFactor(ambientC: ambientC, insulation: insulation)
        if ambient <= 0 {
            throw CalcError.outOfRange("Ambient \(FormatTrace.number(ambientC, digits: 0))°C is outside the \(insulation.displayName) correction range in Table 310.15(B)(1).")
        }
        let bundle = currentCarryingCount > 3 ? bundleFactor(currentCarryingCount: currentCarryingCount) : 1
        let base = Double(baseInt)
        return LookedUp(
            base: base,
            allowable: base * ambient * bundle,
            ambient: ambient,
            bundleFactor: bundle,
            columnLabel: columnLabel(family: family, currentCarryingCount: currentCarryingCount),
            source: family.usesPortableCordTable ? cordSource : typeWSource
        )
    }

    private static func select(
        family: FlexibleCableFamily,
        currentCarryingCount: Int,
        insulation: ConductorTempColumn,
        ambientC: Double,
        required: Double
    ) throws -> FlexibleCableSizePick {
        var best: FlexibleCableSizePick?
        var largest: (label: String, allowable: Double)?
        for size in sizes(for: family, currentCarryingCount: currentCarryingCount) {
            let looked = try lookup(
                family: family,
                size: size,
                currentCarryingCount: currentCarryingCount,
                insulation: insulation,
                ambientC: ambientC
            )
            if largest == nil || looked.allowable > largest!.allowable {
                largest = (label(for: size), looked.allowable)
            }
            if looked.allowable + 1e-9 >= required, best == nil {
                best = FlexibleCableSizePick(
                    size: size,
                    label: label(for: size),
                    allowableAmpacity: looked.allowable,
                    tableAmps: looked.base,
                    source: looked.source
                )
            }
        }
        if let best { return best }
        let cap = largest.map { "Largest transcribed is \($0.label) at \(FormatTrace.amps($0.allowable))." } ?? "No sizes are transcribed for this column."
        throw CalcError.notListed("No \(family.displayName) size in this transcription carries \(FormatTrace.amps(required)) under these conditions. \(cap)")
    }

    private static func chartPoints(
        family: FlexibleCableFamily,
        currentCarryingCount: Int,
        selected: String,
        recommended: String?
    ) -> [FlexibleCableChartPoint] {
        let column = columnKind(family: family, currentCarryingCount: currentCarryingCount)
        let source = family.usesPortableCordTable ? cordSource : typeWSource
        return rows(for: family).compactMap { row in
            guard let amps = cell(row, column: column) else { return nil }
            return FlexibleCableChartPoint(
                size: row.size,
                label: shortLabel(row.size),
                tableAmps: Double(amps),
                source: source,
                isSelected: row.size == selected,
                isRecommended: row.size == recommended
            )
        }
    }

    static func resolveSize(
        _ raw: String,
        circularMils: Double?,
        family: FlexibleCableFamily,
        currentCarryingCount: Int
    ) throws -> String {
        if let circularMils {
            guard circularMils.isFinite, circularMils > 0 else {
                throw CalcError.nonPositive("Circular mils")
            }
            guard let match = size(matchingCircularMils: circularMils) else {
                throw CalcError.notListed("\(FormatTrace.number(circularMils, digits: 0)) circular mils is not an exact Chapter 9 Table 8 size in this cable table. Ampacity is not interpolated.")
            }
            return try requireListed(match, family: family, currentCarryingCount: currentCarryingCount)
        }
        let key = normalizeSize(raw)
        guard !key.isEmpty else {
            throw CalcError.missing("a conductor size")
        }
        return try requireListed(key, family: family, currentCarryingCount: currentCarryingCount)
    }

    private static func requireListed(
        _ size: String,
        family: FlexibleCableFamily,
        currentCarryingCount: Int
    ) throws -> String {
        if sizes(for: family, currentCarryingCount: currentCarryingCount).contains(size) {
            return size
        }
        if rows(for: family).contains(where: { $0.size == size }) {
            throw CalcError.notListed("\(label(for: size)) is in the \(family.displayName) table, but not in the \(columnLabel(family: family, currentCarryingCount: currentCarryingCount)) column. Missing cells are left blank.")
        }
        throw CalcError.notListed("\(label(for: size)) is not a transcribed \(family.displayName) size.")
    }

    private static func size(matchingCircularMils cmil: Double) -> String? {
        var table = smallCircularMils
        for (size, value) in NECTables.circularMils {
            table[size] = value
        }
        return table.first { abs($0.value - cmil) < 0.5 }?.key
    }

    private static func normalizeSize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        text = text.replacingOccurrences(of: "awg", with: "")
        text = text.replacingOccurrences(of: "kcmil", with: "")
        text = text.replacingOccurrences(of: "mcm", with: "")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch text {
        case "00", "2/0", "2-0": return "2/0"
        case "000", "3/0", "3-0": return "3/0"
        case "0000", "4/0", "4-0": return "4/0"
        case "1/0", "0", "1-0": return "1/0"
        default: return text
        }
    }

    private static func label(for size: String) -> String {
        let kcmil: Set<String> = ["250", "300", "350", "400", "500", "600", "750", "1000"]
        return kcmil.contains(size) ? "\(size) kcmil" : "\(size) AWG"
    }

    private static func shortLabel(_ size: String) -> String {
        size
    }

    private static func formatFactor(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
