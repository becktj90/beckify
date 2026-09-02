import Foundation

/// NEC reference tables used by the v1 calculators.
///
/// Values are transcribed from the published NEC so the iOS app and the
/// website toolbox share one auditable set of numbers. This is a design aid,
/// not a substitute for the code book or a PE stamp.
public enum NECTables: Sendable {
    /// Ordered smallest → largest. Integer-like keys sort poorly as strings.
    public static let wireSizeOrder: [String] = [
        "14", "12", "10", "8", "6", "4", "3", "2", "1",
        "1/0", "2/0", "3/0", "4/0",
        "250", "300", "350", "400", "500", "600", "700", "750", "800", "900", "1000",
    ]

    private static let kcmil: Set<String> = [
        "250", "300", "350", "400", "500", "600", "700", "750", "800", "900", "1000",
    ]

    public static func wireLabel(_ size: String) -> String {
        kcmil.contains(size) ? "\(size) kcmil" : "\(size) AWG"
    }

    /// NEC Chapter 9 Table 8 — circular mils.
    public static let circularMils: [String: Double] = [
        "14": 4110, "12": 6530, "10": 10380, "8": 16510, "6": 26240,
        "4": 41740, "3": 52620, "2": 66360, "1": 83690,
        "1/0": 105600, "2/0": 133100, "3/0": 167800, "4/0": 211600,
        "250": 250000, "300": 300000, "350": 350000, "400": 400000, "500": 500000,
        "600": 600000, "700": 700000, "750": 750000, "800": 800000, "900": 900000, "1000": 1000000,
    ]

    /// NEC Table 310.16 — allowable ampacity, ≤3 CCC, 30 °C ambient (NEC 2023).
    /// Indexed [60 °C, 75 °C, 90 °C]. `nil` means the size is not listed.
    public static let ampacityCopper: [String: [Int]] = [
        "14": [15, 20, 25], "12": [20, 25, 30], "10": [30, 35, 40], "8": [40, 50, 55],
        "6": [55, 65, 75], "4": [70, 85, 95], "3": [85, 100, 115], "2": [95, 115, 130],
        "1": [110, 130, 145], "1/0": [125, 150, 170], "2/0": [145, 175, 195],
        "3/0": [165, 200, 225], "4/0": [195, 230, 260], "250": [215, 255, 290],
        "300": [240, 285, 320], "350": [260, 310, 350], "400": [280, 335, 380],
        "500": [320, 380, 430], "600": [350, 420, 475], "700": [385, 460, 520],
        "750": [400, 475, 535], "800": [410, 490, 555], "900": [435, 520, 585],
        "1000": [455, 545, 615],
    ]

    public static let ampacityAluminum: [String: [Int]] = [
        "12": [15, 20, 25], "10": [25, 30, 35], "8": [35, 40, 45],
        "6": [40, 50, 55], "4": [55, 65, 75], "3": [65, 75, 85], "2": [75, 90, 100],
        "1": [85, 100, 115], "1/0": [100, 120, 135], "2/0": [115, 135, 150],
        "3/0": [130, 155, 175], "4/0": [150, 180, 205], "250": [170, 205, 230],
        "300": [195, 230, 260], "350": [210, 250, 280], "400": [225, 270, 305],
        "500": [260, 310, 350], "600": [285, 340, 385], "700": [315, 375, 425],
        "750": [320, 385, 435], "800": [330, 395, 445], "900": [355, 425, 480],
        "1000": [375, 445, 500],
    ]

    public static func ampacity75C(size: String, material: ConductorMaterial) -> Int? {
        switch material {
        case .copper:
            guard let cols = ampacityCopper[size], cols.count > 1 else { return nil }
            return cols[1]
        case .aluminum:
            guard let cols = ampacityAluminum[size], cols.count > 1 else { return nil }
            return cols[1]
        }
    }

    /// NEC Chapter 9 Table 4 — EMT total internal area (in²), not the 40 % column.
    public static let emtArea: [(trade: String, area: Double)] = [
        ("1/2", 0.304), ("3/4", 0.533), ("1", 0.864), ("1-1/4", 1.496),
        ("1-1/2", 2.036), ("2", 3.356), ("2-1/2", 4.788), ("3", 7.393),
        ("3-1/2", 9.893), ("4", 12.720),
    ]

    /// NEC Chapter 9 Table 5 — THHN / THWN-2 conductor area including insulation (in²).
    public static let thhnArea: [String: Double] = [
        "14": 0.0097, "12": 0.0133, "10": 0.0211, "8": 0.0366, "6": 0.0507,
        "4": 0.0824, "3": 0.0973, "2": 0.1158, "1": 0.1562,
        "1/0": 0.1855, "2/0": 0.2223, "3/0": 0.2679, "4/0": 0.3237,
        "250": 0.3970, "300": 0.4608, "350": 0.5242, "400": 0.5863, "500": 0.7073,
        "600": 0.8676, "700": 0.9887, "750": 1.0496, "800": 1.1085, "900": 1.2311, "1000": 1.3478,
    ]

    /// NEC Chapter 9 Table 1 — maximum fill of a raceway.
    public static func table1FillPercent(conductorCount: Int) -> Double {
        switch conductorCount {
        case 1: return 53
        case 2: return 31
        default: return 40
        }
    }

    /// NEC 2023 Table 240.6(A) standard overcurrent device ratings (A).
    /// 10 A was added in NEC 2023 for inverse-time breakers.
    public static let standardOCPD: [Int] = [
        10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150, 175, 200,
        225, 250, 300, 350, 400, 450, 500, 600, 700, 800, 1000, 1200, 1600, 2000,
        2500, 3000, 4000, 5000, 6000,
    ]

    public static func nextStandardOCPD(_ amps: Double) -> Int? {
        standardOCPD.first { Double($0) >= amps }
    }

    public static func largestStandardOCPD(atOrBelow amps: Double) -> Int? {
        standardOCPD.last { Double($0) <= amps }
    }

    /// ANSI/NEMA standard dry-type transformer kVA ratings.
    public static let standardTransformerKVA: [Double] = [
        1, 1.5, 2, 3, 5, 7.5, 10, 15, 25, 30, 37.5, 45, 50, 75, 100, 112.5, 150, 167,
        200, 225, 250, 300, 333, 400, 500, 750, 1000, 1500, 2000, 2500, 3000,
    ]
}
