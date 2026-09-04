import Foundation

/// Insulation / termination temperature columns used with Table 310.16.
public enum ConductorTempColumn: Int, Codable, CaseIterable, Sendable, Hashable {
    case c60 = 60
    case c75 = 75
    case c90 = 90

    public var displayName: String { "\(rawValue) °C" }

    public var tableIndex: Int {
        switch self {
        case .c60: return 0
        case .c75: return 1
        case .c90: return 2
        }
    }
}

/// NEC Table 310.15(B)(1) ambient correction and 310.15(C)(1) CCC adjustment.
///
/// Factors apply to the conductor's own insulation column; usable ampacity is
/// then capped by the termination column per 110.14(C).
public enum NECAmpacityFactors {
    public static let ambientCitation = CodeCitation(
        articleOrTable: "Table 310.15(B)(1)",
        units: "factor",
        sourceDescription: "Ambient temperature correction based on 30 °C Table 310.16"
    )

    public static let cccCitation = CodeCitation(
        articleOrTable: "Table 310.15(C)(1)",
        units: "factor",
        sourceDescription: "Adjustment for more than three current-carrying conductors in a raceway or cable"
    )

    public static let tableCitation = CodeCitation(
        articleOrTable: "Table 310.16",
        units: "A",
        sourceDescription: "Allowable ampacity, ≤3 CCC, 30 °C ambient"
    )

    public static let terminationCitation = CodeCitation(
        articleOrTable: "110.14(C)",
        units: "A",
        sourceDescription: "Conductor ampacity limited by equipment termination temperature rating"
    )

    /// Returns 0 when ambient exceeds the insulation's tabulated range.
    public static func ambientCorrectionFactor(ambientC: Double, insulation: ConductorTempColumn) -> Double {
        guard ambientC.isFinite else { return 0 }
        let table: [(Double, Double)]
        switch insulation {
        case .c60:
            table = [(25, 1.08), (30, 1.0), (35, 0.91), (40, 0.82), (45, 0.71), (50, 0.58), (55, 0.41)]
        case .c75:
            table = [
                (25, 1.05), (30, 1.0), (35, 0.94), (40, 0.88), (45, 0.82), (50, 0.75),
                (55, 0.67), (60, 0.58), (65, 0.47), (70, 0.33),
            ]
        case .c90:
            table = [
                (25, 1.04), (30, 1.0), (35, 0.96), (40, 0.91), (45, 0.87), (50, 0.82),
                (55, 0.76), (60, 0.71), (65, 0.65), (70, 0.58), (75, 0.50), (80, 0.41), (85, 0.29),
            ]
        }
        for (maxTemp, factor) in table {
            if ambientC <= maxTemp { return factor }
        }
        return 0
    }

    public static func cccAdjustmentFactor(currentCarryingCount: Int) throws -> Double {
        guard currentCarryingCount >= 1 else {
            throw CalcError.nonPositive("Current-carrying conductor count")
        }
        switch currentCarryingCount {
        case 1...3: return 1.0
        case 4...6: return 0.8
        case 7...9: return 0.7
        case 10...20: return 0.5
        case 21...30: return 0.45
        case 31...40: return 0.4
        default: return 0.35
        }
    }

    public static func ampacity(size: String, material: ConductorMaterial, column: ConductorTempColumn) -> Int? {
        let row: [Int]?
        switch material {
        case .copper: row = NECTables.ampacityCopper[size]
        case .aluminum: row = NECTables.ampacityAluminum[size]
        }
        guard let cols = row, cols.indices.contains(column.tableIndex) else { return nil }
        return cols[column.tableIndex]
    }
}
