import Foundation

/// Code edition used by the v1 dimensional tables. New editions should add cases
/// and parallel datasets rather than overwriting these numbers in views.
public enum NECCodeEdition: String, Codable, Sendable, Hashable {
    case nec2023 = "NEC 2023"

    public var displayName: String { rawValue }
}

/// Provenance for a numeric dimensional dataset. Commentary is not stored.
public struct DimensionalSource: Equatable, Sendable, Codable, Hashable {
    public var edition: NECCodeEdition
    public var table: String
    public var units: String
    public var sizeRange: String
    public var verifiedOn: String
    public var notes: String

    public init(
        edition: NECCodeEdition = .nec2023,
        table: String,
        units: String,
        sizeRange: String,
        verifiedOn: String = NECDimensionalCatalog.verifiedOn,
        notes: String = ""
    ) {
        self.edition = edition
        self.table = table
        self.units = units
        self.sizeRange = sizeRange
        self.verifiedOn = verifiedOn
        self.notes = notes
    }
}

/// Shared catalog metadata. Numbers match `artifacts/beckify/public/toolbox/js/nec-data.js`.
public enum NECDimensionalCatalog: Sendable {
    public static let edition: NECCodeEdition = .nec2023
    public static let verifiedOn = "2026-09-03"
    public static let transcriptionNote =
        "Numeric values transcribed from NEC 2023 Chapter 9 Tables 1, 4, and 5 — the same dataset as the website toolbox nec-data.js. Not a substitute for the adopted code book."

    /// NEC Chapter 9 Table 4 metric designators paired with US trade sizes.
    public static let metricDesignator: [String: String] = [
        "1/2": "16", "3/4": "21", "1": "27", "1-1/4": "35", "1-1/2": "41",
        "2": "53", "2-1/2": "63", "3": "78", "3-1/2": "91", "4": "103",
        "5": "129", "6": "155",
    ]

    public static let tradeSizeOrder: [String] = [
        "1/2", "3/4", "1", "1-1/4", "1-1/2", "2", "2-1/2", "3", "3-1/2", "4", "5", "6",
    ]
}

public enum RacewayType: String, Codable, CaseIterable, Sendable, Hashable {
    case emt
    case imc
    case rmc
    case pvc40
    case pvc80
    case ent
    case fmc
    case lfmc

    public var displayName: String {
        switch self {
        case .emt: return "EMT"
        case .imc: return "IMC"
        case .rmc: return "RMC"
        case .pvc40: return "PVC Schedule 40"
        case .pvc80: return "PVC Schedule 80"
        case .ent: return "ENT"
        case .fmc: return "FMC"
        case .lfmc: return "LFMC"
        }
    }

    /// Raceway article used only for the “confirm permitted bends” recommendation.
    public var bendArticle: String {
        switch self {
        case .emt: return "358.26"
        case .imc: return "342.26"
        case .rmc: return "344.26"
        case .pvc40, .pvc80: return "352.26"
        case .ent: return "362.26"
        case .fmc: return "348.26"
        case .lfmc: return "350.26"
        }
    }

    public var source: DimensionalSource {
        DimensionalSource(
            table: "Chapter 9 Table 4 — \(displayName) total internal area",
            units: "in²",
            sizeRange: orderedTradeSizes.joined(separator: ", ") + " in",
            notes: "Full internal area, not the precomputed 40% column."
        )
    }

    /// Trade size → total internal area (in²).
    public var areas: [String: Double] {
        switch self {
        case .emt:
            return [
                "1/2": 0.304, "3/4": 0.533, "1": 0.864, "1-1/4": 1.496, "1-1/2": 2.036,
                "2": 3.356, "2-1/2": 4.788, "3": 7.393, "3-1/2": 9.893, "4": 12.720,
            ]
        case .imc:
            return [
                "1/2": 0.342, "3/4": 0.586, "1": 0.959, "1-1/4": 1.647, "1-1/2": 2.225,
                "2": 3.630, "2-1/2": 5.135, "3": 7.922, "3-1/2": 10.584, "4": 13.631,
            ]
        case .rmc:
            return [
                "1/2": 0.314, "3/4": 0.549, "1": 0.887, "1-1/4": 1.526, "1-1/2": 2.071,
                "2": 3.408, "2-1/2": 4.866, "3": 7.499, "3-1/2": 10.010, "4": 12.882,
                "5": 20.212, "6": 29.158,
            ]
        case .pvc40:
            return [
                "1/2": 0.285, "3/4": 0.508, "1": 0.832, "1-1/4": 1.453, "1-1/2": 1.986,
                "2": 3.291, "2-1/2": 4.695, "3": 7.268, "3-1/2": 9.737, "4": 12.554,
                "5": 19.761, "6": 28.567,
            ]
        case .pvc80:
            return [
                "1/2": 0.217, "3/4": 0.409, "1": 0.688, "1-1/4": 1.237, "1-1/2": 1.711,
                "2": 2.874, "2-1/2": 4.119, "3": 6.442, "3-1/2": 8.688, "4": 11.258,
                "5": 17.855, "6": 25.598,
            ]
        case .ent:
            return [
                "1/2": 0.285, "3/4": 0.508, "1": 0.832, "1-1/4": 1.453, "1-1/2": 1.986, "2": 3.291,
            ]
        case .fmc:
            return [
                "1/2": 0.317, "3/4": 0.533, "1": 0.817, "1-1/4": 1.277, "1-1/2": 1.858,
                "2": 3.269, "2-1/2": 4.909, "3": 7.069, "3-1/2": 9.621, "4": 12.566,
            ]
        case .lfmc:
            return [
                "1/2": 0.314, "3/4": 0.541, "1": 0.873, "1-1/4": 1.528, "1-1/2": 1.981,
                "2": 3.246, "2-1/2": 4.881, "3": 7.475, "3-1/2": 9.731, "4": 12.692,
            ]
        }
    }

    public var orderedTradeSizes: [String] {
        NECDimensionalCatalog.tradeSizeOrder.filter { areas[$0] != nil }
    }

    public var orderedAreas: [(trade: String, area: Double)] {
        orderedTradeSizes.compactMap { trade in
            guard let area = areas[trade] else { return nil }
            return (trade, area)
        }
    }

    public func area(for tradeSize: String) -> Double? {
        areas[tradeSize]
    }

    public func metricDesignator(for tradeSize: String) -> String? {
        guard areas[tradeSize] != nil else { return nil }
        return NECDimensionalCatalog.metricDesignator[tradeSize]
    }

    /// Equivalent circular ID from listed Table 4 area. Used only for jamming screening.
    public func derivedInternalDiameterInches(for tradeSize: String) -> Double? {
        guard let area = areas[tradeSize], area > 0, area.isFinite else { return nil }
        return 2 * (area / Double.pi).squareRoot()
    }
}

public enum ConductorInsulation: String, Codable, CaseIterable, Sendable, Hashable {
    case thhnTHWN2
    case xhhw2
    case rhhRhw2
    case compactAluminum
    case bare
    case custom

    public var displayName: String {
        switch self {
        case .thhnTHWN2: return "THHN / THWN-2"
        case .xhhw2: return "XHHW / XHHW-2"
        case .rhhRhw2: return "RHH / RHW / RHW-2"
        case .compactAluminum: return "Compact aluminum"
        case .bare: return "Bare / covered (custom)"
        case .custom: return "Custom / manufacturer"
        }
    }

    public var hasListedTable5Area: Bool {
        switch self {
        case .thhnTHWN2, .xhhw2, .rhhRhw2: return true
        case .compactAluminum, .bare, .custom: return false
        }
    }

    public var source: DimensionalSource {
        switch self {
        case .thhnTHWN2:
            return DimensionalSource(
                table: "Chapter 9 Table 5 — THHN / THWN / THWN-2",
                units: "in²",
                sizeRange: "14 AWG through 1000 kcmil",
                notes: "Insulated conductor area including insulation. Copper and aluminum use the same Table 5 column for this type."
            )
        case .xhhw2:
            return DimensionalSource(
                table: "Chapter 9 Table 5 — XHHW / XHHW-2",
                units: "in²",
                sizeRange: "14 AWG through 1000 kcmil"
            )
        case .rhhRhw2:
            return DimensionalSource(
                table: "Chapter 9 Table 5 — RHH / RHW / RHW-2",
                units: "in²",
                sizeRange: "14 AWG through 1000 kcmil"
            )
        case .compactAluminum:
            return DimensionalSource(
                table: "Chapter 9 Table 5A is not in this dataset",
                units: "in² (manufacturer)",
                sizeRange: "requires custom area",
                notes: "Compact-aluminum dimensions are not transcribed here. Enter a manufacturer or Table 5A value."
            )
        case .bare:
            return DimensionalSource(
                table: "Chapter 9 Table 8 overall diameter is not in this dataset",
                units: "in² (manufacturer)",
                sizeRange: "requires custom area",
                notes: "Bare or covered grounding-conductor fill uses overall dimensions, not circular-mil metal area."
            )
        case .custom:
            return DimensionalSource(
                table: "Manufacturer / product data",
                units: "in² or in OD",
                sizeRange: "as marked",
                notes: "User-supplied area or outside diameter."
            )
        }
    }

    /// Listed Table 5 areas. Empty when the type is not in this dataset.
    public var listedAreas: [String: Double] {
        switch self {
        case .thhnTHWN2:
            return [
                "14": 0.0097, "12": 0.0133, "10": 0.0211, "8": 0.0366, "6": 0.0507,
                "4": 0.0824, "3": 0.0973, "2": 0.1158, "1": 0.1562,
                "1/0": 0.1855, "2/0": 0.2223, "3/0": 0.2679, "4/0": 0.3237,
                "250": 0.3970, "300": 0.4608, "350": 0.5242, "400": 0.5863, "500": 0.7073,
                "600": 0.8676, "700": 0.9887, "750": 1.0496, "800": 1.1085, "900": 1.2311, "1000": 1.3478,
            ]
        case .xhhw2:
            return [
                "14": 0.0139, "12": 0.0181, "10": 0.0243, "8": 0.0437, "6": 0.0590,
                "4": 0.0814, "3": 0.0962, "2": 0.1146, "1": 0.1534,
                "1/0": 0.1825, "2/0": 0.2190, "3/0": 0.2642, "4/0": 0.3197,
                "250": 0.3904, "300": 0.4536, "350": 0.5166, "400": 0.5782, "500": 0.6984,
                "600": 0.8709, "700": 0.9923, "750": 1.0532, "800": 1.1122, "900": 1.2351, "1000": 1.3519,
            ]
        case .rhhRhw2:
            return [
                "14": 0.0293, "12": 0.0353, "10": 0.0437, "8": 0.0835, "6": 0.1041,
                "4": 0.1333, "3": 0.1521, "2": 0.1750, "1": 0.2660,
                "1/0": 0.3039, "2/0": 0.3505, "3/0": 0.4072, "4/0": 0.4754,
                "250": 0.6291, "300": 0.7088, "350": 0.7870, "400": 0.8626, "500": 1.0082,
                "600": 1.2135, "700": 1.3561, "750": 1.4272, "800": 1.4957, "900": 1.6377, "1000": 1.7719,
            ]
        case .compactAluminum, .bare, .custom:
            return [:]
        }
    }

    public func listedArea(for size: String) -> Double? {
        listedAreas[size]
    }
}

public enum ConductorPurpose: String, Codable, CaseIterable, Sendable, Hashable {
    case phase
    case neutral
    case equipmentGround
    case control
    case spare

    public var displayName: String {
        switch self {
        case .phase: return "Phase / ungrounded"
        case .neutral: return "Neutral"
        case .equipmentGround: return "Equipment grounding"
        case .control: return "Control"
        case .spare: return "Spare"
        }
    }

    /// Default CCC flag when the user has not overridden. Neutral stays undecided.
    public var defaultCountsAsCurrentCarrying: Bool? {
        switch self {
        case .phase, .control: return true
        case .equipmentGround, .spare: return false
        case .neutral: return nil
        }
    }
}

public enum RacewayRunKind: String, Codable, CaseIterable, Sendable, Hashable {
    case normal
    case nipple

    public var displayName: String {
        switch self {
        case .normal: return "Normal run"
        case .nipple: return "Nipple"
        }
    }
}

public enum InstallationLocation: String, Codable, CaseIterable, Sendable, Hashable {
    case dry
    case wet

    public var displayName: String {
        switch self {
        case .dry: return "Dry"
        case .wet: return "Wet"
        }
    }
}

public enum PullingMethod: String, Codable, CaseIterable, Sendable, Hashable {
    case unspecified
    case hand
    case fishTape
    case tugger
    case other

    public var displayName: String {
        switch self {
        case .unspecified: return "Not specified"
        case .hand: return "Hand"
        case .fishTape: return "Fish tape"
        case .tugger: return "Tugger / puller"
        case .other: return "Other"
        }
    }
}

public enum ConduitFillPreset: String, Codable, CaseIterable, Sendable, Hashable {
    case singlePhaseBranch
    case threePhaseFeeder
    case threePhaseFeederWithNeutralAndEGC
    case controlCircuit
    case custom

    public var displayName: String {
        switch self {
        case .singlePhaseBranch: return "Single-phase branch circuit"
        case .threePhaseFeeder: return "Three-phase feeder"
        case .threePhaseFeederWithNeutralAndEGC: return "Three-phase feeder with N and EGC"
        case .controlCircuit: return "Control circuit"
        case .custom: return "Custom schedule"
        }
    }
}
