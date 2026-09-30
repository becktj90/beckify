import Foundation

/// On-device preference keys. Values stay in UserDefaults and are not uploaded.
public enum ToolboxPreferenceKey {
    public static let electricalCode = "com.beckify.toolbox.electricalCode"
    public static let preferredUnits = "com.beckify.toolbox.preferredUnits"
    public static let appearance = "com.beckify.toolbox.appearance"
}

/// Wiring code the toolbox calculates against. Default is NEC.
///
/// Add a case here when a code has real table paths. Do not add a case that
/// only relabels NEC results.
public enum ElectricalCode: String, Codable, CaseIterable, Sendable, Hashable {
    case nec
    case asnzs

    public var displayName: String {
        switch self {
        case .nec: return "NEC (US)"
        case .asnzs: return "AS/NZS"
        }
    }

    public var detail: String {
        switch self {
        case .nec:
            return "NFPA 70, National Electrical Code. Default for this app."
        case .asnzs:
            return "AS/NZS 3000 Wiring Rules, with cable resistance from IEC 60228. AS/NZS 3008 current-carrying capacity is not transcribed."
        }
    }

    /// Common nominal supply used as the example for this code. Not the only legal voltage.
    public var nominalSupply: NominalSupply {
        switch self {
        case .nec:
            return NominalSupply(
                singlePhaseVolts: 120,
                threePhaseLineVolts: 480,
                frequencyHz: 60,
                note: "Common US utilization used as the example (120 V 1Ø, 480 V 3Ø, 60 Hz). The NEC does not fix one utilization voltage."
            )
        case .asnzs:
            return NominalSupply(
                singlePhaseVolts: 230,
                threePhaseLineVolts: 400,
                frequencyHz: 50,
                note: "AS/NZS nominal low voltage is 230 V single-phase and 400 V three-phase at 50 Hz (AS 60038, as applied by AS/NZS 3000)."
            )
        }
    }
}

/// Codes named so a later build can add them. They are not selectable.
public enum PlannedElectricalCode: String, CaseIterable, Sendable, Hashable {
    case iec60364 = "IEC 60364"
    case cec = "CEC (Canada)"
    case bs7671 = "BS 7671"

    public var displayName: String { rawValue }
    public var status: String { "Not in this build" }
}

public struct NominalSupply: Equatable, Sendable {
    public var singlePhaseVolts: Double
    public var threePhaseLineVolts: Double
    public var frequencyHz: Double
    public var note: String

    public var summary: String {
        "\(Int(singlePhaseVolts)) V 1Ø · \(Int(threePhaseLineVolts)) V 3Ø · \(Int(frequencyHz)) Hz"
    }
}

public enum FieldLengthUnit: String, Codable, CaseIterable, Sendable, Hashable {
    case feet
    case metres

    public var symbol: String {
        switch self {
        case .feet: return "ft"
        case .metres: return "m"
        }
    }

    /// International foot: 0.3048 m exactly. `value` is already in this unit.
    public func metres(from value: Double) -> Double {
        switch self {
        case .metres: return value
        case .feet: return value * 0.3048
        }
    }

    public func feet(from value: Double) -> Double {
        switch self {
        case .feet: return value
        case .metres: return value / 0.3048
        }
    }
}

/// Length unit for Voltage Drop. Conductor identity stays with the code (AWG vs mm²).
public enum PreferredUnitSystem: String, Codable, CaseIterable, Sendable, Hashable {
    case followCode
    case imperial
    case metric

    public var displayName: String {
        switch self {
        case .followCode: return "Follow electrical code"
        case .imperial: return "Imperial (feet)"
        case .metric: return "Metric (metres)"
        }
    }

    public func lengthUnit(for code: ElectricalCode) -> FieldLengthUnit {
        switch self {
        case .imperial: return .feet
        case .metric: return .metres
        case .followCode: return code == .asnzs ? .metres : .feet
        }
    }
}

public enum ElectricalCodeNoticeKind: String, Equatable, Sendable {
    /// The numbers on screen follow the selected code.
    case activeNative
    /// The tool has no AS/NZS path. Results must stay labeled NEC.
    case necLabeledFallback
}

public struct ElectricalCodeNotice: Equatable, Sendable {
    public var kind: ElectricalCodeNoticeKind
    public var title: String
    public var message: String
    /// One-line chip. The message is still the accessibility label.
    public var showsDetail: Bool

    public var accessibilityLabel: String {
        showsDetail ? "\(title). \(message)" : "\(title). \(message)"
    }
}

/// Which catalog tools have a real second code path.
///
/// Tool IDs match `ToolID.rawValue` in the app. Unknown IDs get no banner.
public enum ElectricalCodeSupport {
    public static let nativeToolIDs: Set<String> = [
        "voltageDrop",
        "power",
        "receptacleSelector",
    ]

    /// NEC-table tools. Selecting AS/NZS must not relabel their results.
    public static let necOnlyToolIDs: Set<String> = [
        "wireAmpacity",
        "conduitFill",
        "equipmentGround",
        "motorFLA",
        "transformer",
        "necCircuit",
        "conductorCost",
        "loadWorksheet",
        "motorNameplate",
        "conductorLength",
    ]

    public static func notice(toolID: String, code: ElectricalCode) -> ElectricalCodeNotice? {
        let watched = nativeToolIDs.union(necOnlyToolIDs)
        guard watched.contains(toolID) else { return nil }

        switch code {
        case .nec:
            return ElectricalCodeNotice(
                kind: .activeNative,
                title: "Code: NEC (US)",
                message: "Default. Where this tool cites a table, that table is NEC. Design aid — not a PE or AEE stamp.",
                showsDetail: false
            )
        case .asnzs:
            if nativeToolIDs.contains(toolID) {
                return nativeASNZSNotice(toolID)
            }
            return ElectricalCodeNotice(
                kind: .necLabeledFallback,
                title: "AS/NZS not available for this tool yet — showing NEC",
                message: fallbackDetail(toolID),
                showsDetail: true
            )
        }
    }

    private static func nativeASNZSNotice(_ toolID: String) -> ElectricalCodeNotice {
        let message: String
        switch toolID {
        case "voltageDrop":
            message = "Metric sizes. Drop is resistance-only from IEC 60228 maximum R, corrected for temperature, with reactance omitted — not an AS/NZS 3008 mV/A·m table. The 5% figure is AS/NZS 3000:2018 Clause 3.6.2 for the installation from the point of supply. Earthing uses Table 5.1. Current-carrying capacity is not checked."
        case "power":
            message = "P, kVA, kW, and kVAR are the same identities either way. Nominal supply shown for AS/NZS is 230 V single-phase and 400 V three-phase at 50 Hz."
        case "receptacleSelector":
            message = "AS/NZS ranks AS/NZS 3112 Type I ahead of other household faces near 230 V. NEMA and IEC rows stay in the list when they fit. Not a listing."
        default:
            message = "This tool follows AS/NZS for the path it implements. Design aid — not a PE or AEE stamp."
        }
        return ElectricalCodeNotice(
            kind: .activeNative,
            title: "Code: AS/NZS",
            message: message,
            showsDetail: true
        )
    }

    private static func fallbackDetail(_ toolID: String) -> String {
        switch toolID {
        case "wireAmpacity":
            return "Ampacity here is NEC Table 310.16. AS/NZS 3008 current-carrying capacity is not in this tool. The equipment grounding conductor is NEC Table 250.122, not AS/NZS Table 5.1. Use Voltage Drop for an AS/NZS resistance check and Table 5.1 earth."
        case "conduitFill":
            return "Fill is NEC Chapter 9. Count EGC still adds a Table 250.122 conductor only when that toggle is on. AS/NZS conduit space factors are not in this tool."
        case "equipmentGround":
            return "This screen is NEC 2023 Table 250.122 only. AS/NZS protective-earth sizing (Table 5.1) is on Voltage Drop, not here. The sizes below stay labeled NEC."
        case "motorFLA":
            return "Full-load current is NEC Table 430.248 or 430.250. AS/NZS motor tables are not in this tool."
        case "transformer":
            return "Protection is NEC 450.3(B). AS/NZS transformer protection is not in this tool."
        case "necCircuit":
            return "This pass is NEC ampacity, voltage drop, and OCPD. It does not become an AS/NZS circuit calc. Use Voltage Drop for the AS/NZS resistance path."
        case "conductorCost":
            return "Sizes and ampacity are NEC. The ranking does not switch to AS/NZS 3008."
        case "loadWorksheet":
            return "Demand is NEC Table 220.42. AS/NZS maximum-demand tables are not in this tool."
        case "motorNameplate":
            return "Overload, SCPD, and conductor rows cite the NEC. AS/NZS motor protection is not in this tool."
        case "conductorLength":
            return "Circular mils are NEC Chapter 9 Table 8. Metric resistance for a known mm² size is on Voltage Drop, not this screen."
        default:
            return "Results below are NEC (US). They are not AS/NZS figures."
        }
    }
}
