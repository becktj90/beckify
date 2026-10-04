import Foundation

/// Top-level home areas on the iOS toolbox. Field is the jobsite home;
/// Toolkit is basics, bench, and references.
public enum ToolHomeArea: String, CaseIterable, Sendable, Hashable {
    case field
    case toolkit
}

/// Display shelf inside a home area, in the order the grid shows them.
/// Field is what you carry onto a job. Toolkit is for the bench and for learning.
public enum ToolShelfKind: String, CaseIterable, Sendable, Hashable {
    // Field
    case jobsite
    case wiring
    case motors
    case power
    case controls
    case magnetics
    case instruments
    case crew
    // Toolkit
    case basics
    case electronics
    case rfOptics
    case build
    case math

    public var homeArea: ToolHomeArea {
        switch self {
        case .jobsite, .wiring, .motors, .power, .controls, .magnetics, .instruments, .crew: return .field
        case .basics, .electronics, .rfOptics, .build, .math: return .toolkit
        }
    }
}

/// Canonical home area + shelf for every tool ID (`ToolID.rawValue`).
///
/// This policy owns which home a tool opens under and which shelf it sits on.
/// `ToolboxCatalog.categories` is display/grouping color only and must stay
/// aligned to these shelves — a tool’s category color must not imply a
/// different home than this policy. Unknown future IDs default to Field
/// → Jobsite unless listed here as Toolkit (including AoE analog IDs).
public enum ToolHomeAreaPolicy {
    public static func area(forToolID id: String) -> ToolHomeArea {
        shelf(forToolID: id).homeArea
    }

    /// Unknown future IDs land on Field → Jobsite.
    public static func shelf(forToolID id: String) -> ToolShelfKind {
        shelfByTool[id] ?? .jobsite
    }

    public static var fieldToolIDs: [String] {
        ToolCalculationPolicy.knownToolIDs.filter { area(forToolID: $0) == .field }
    }

    public static var toolkitToolIDs: [String] {
        ToolCalculationPolicy.knownToolIDs.filter { area(forToolID: $0) == .toolkit }
    }

    /// Best-effort map from saved-job input labels to `ToolInputStore` field ids.
    /// Unknown keys are returned unchanged so a partial restore can still write
    /// anything that already matches a stored field name. Never throws.
    public static func storedFields(
        toolID: String,
        inputs: [String: String]
    ) -> [String: String] {
        let aliases = fieldAliases[toolID] ?? [:]
        var out: [String: String] = [:]
        for (rawKey, value) in inputs {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let field = aliases[key] ?? aliases[key.lowercased()] ?? key
            out[field] = coerceStoredValue(field: field, value: trimmed)
        }
        return out
    }

    // MARK: - Membership

    /// Default home Pinned seeds (FavoritesStore) — one-tap jobsite calcs plus Wi-Fi Path.
    /// Editable after first launch; Crew Talk and others pin via star / context menu.
    public static let fieldQuickIDs: [String] = [
        "voltageDrop", "wireAmpacity", "motorFLA",
        "receptacleSelector", "wifiStatus", "conduitFill",
    ]

    /// Which shelf each tool sits on. This map is the only place that decides it.
    private static let shelves: [(ToolShelfKind, [String])] = [
        (.jobsite, [
            "voltageDrop", "wireAmpacity", "conduitFill", "receptacleSelector", "necCircuit",
            "loadFactors", "shortCircuit", "equipmentGround",
        ]),
        (.wiring, ["cableLadder", "flexibleCable", "conductorCost", "conductorLength", "circularMils"]),
        (.motors, ["motorFLA", "motorNameplate", "motorNameplateOCR", "motorSpeed"]),
        (.power, [
            "power", "threePhasePower", "powerWizard", "transformer", "powerFactor", "batteryBank",
            "solarDesign", "tapChanger", "harmonicsTHD", "upsSizing",
        ]),
        (.controls, [
            "signalScaling", "modbusAddress", "plcTimer", "rackCurrent", "isLoopVerifier",
            "controlSystems", "controlStrategies", "phasorImpedance", "phasorDiagram", "ul508aPanelLab",
            "switchgearLogicLab",
        ]),
        (.magnetics, ["magneticsLab", "emFields", "magneticCircuit", "solenoidDesign", "empEmc"]),
        (.instruments, [
            "wifiStatus", "cellularStatus", "bluetoothScan", "noiseMeter", "acousticImager", "setupCheck", "bubbleLevel",
            "magnetometer", "barometer", "stillnessWatch", "motionSnapshot", "coupledVibration", "fieldPosition",
            "deviceHealth",
        ]),
        (.crew, ["spanishTranslator", "panelDirectory", "loadWorksheet", "cableSchedule", "referenceLibrary"]),
        (.basics, [
            "ohmsLaw", "voltageDivider", "seriesParallel", "resistorColor",
            "ledRC", "frequencyWave", "unitConverter", "timer555",
        ]),
        (.electronics, [
            "electronicsLab", "analogWorkbench", "noiseSNR", "linearRegulator", "instrumentationAmp",
            "adcDac", "transientCircuit", "diodeIV", "reactance",
        ]),
        (.rfOptics, ["rfLink", "fiberLink", "gaussianBeam"]),
        (.build, [
            "heaterDesign", "eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip",
        ]),
        (.math, ["statistics", "numberBase"]),
    ]

    private static let shelfByTool: [String: ToolShelfKind] = {
        var map: [String: ToolShelfKind] = [:]
        for (shelf, ids) in shelves { for id in ids { map[id] = shelf } }
        return map
    }()

    /// Tool IDs on a shelf, in the order the grid prefers.
    public static func toolIDs(on shelf: ToolShelfKind) -> [String] {
        shelves.first { $0.0 == shelf }?.1 ?? []
    }

    /// Saved-job keys are short labels (`V`, `I`); stored fields are longer.
    private static let fieldAliases: [String: [String: String]] = [
        "ohmsLaw": ["V": "voltage", "I": "current", "R": "resistance"],
        "power": ["V": "voltage", "I": "current", "R": "resistance", "PF": "powerFactor"],
        "voltageDrop": [
            "sys": "system", "V": "voltage", "I": "current", "L": "length",
        ],
        "conduitFill": ["n": "qty", "emt": "trade", "size": "size"],
        "wireAmpacity": ["I": "amps", "mat": "material"],
        "conductorCost": [
            "V": "voltage", "I": "load", "L": "length", "unit": "loadUnit",
            "mat": "material", "PF": "pf",
        ],
        "conductorLength": [
            "R": "resistance", "unit": "rUnit", "size": "size", "CM": "customCmil",
            "mat": "preset", "method": "method", "T": "temp",
            "tempUnit": "tempUnit", "refTemp": "refTemp", "alpha": "alpha", "rho": "rho",
            "technique": "technique", "leadR": "leadR", "jumperR": "jumperR", "qty": "qty",
        ],
        "motorFLA": ["HP": "hp", "V": "systemVolts"],
        "voltageDivider": ["Vin": "vin", "Vout": "vout", "R1": "r1", "R2": "r2"],
        "ledRC": ["Vin": "supply", "Vf": "vf", "If": "current", "R": "resistance", "C": "capacitance"],
        "timer555": ["R1": "r1", "R2": "r2", "C": "c", "R": "r1"],
        "frequencyWave": ["f": "frequency", "T": "period", "λ": "wavelength", "L": "inductance", "C": "capacitance"],
        "controlSystems": [
            "plantID": "plantID", "num": "num", "den": "den",
            "section": "section", "mode": "mode",
            "Kp": "kp", "Ki": "ki", "Kd": "kd",
            "Ku": "ku", "Pu": "pu",
        ],
        "wifiStatus": [
            "mode": "surveyMode",
            "rttTarget": "rttTarget",
            "rttHost": "rttHost",
        ],
        "cellularStatus": [
            "rttTarget": "rttTarget",
            "rttHost": "rttHost",
        ],
    ]

    private static func coerceStoredValue(field: String, value: String) -> String {
        let folded = value.lowercased()
        switch field {
        case "system":
            if folded.contains("3") || folded.contains("three") { return ElectricalSystem.threePhase.rawValue }
            if folded.contains("1") || folded.contains("single") { return ElectricalSystem.singlePhase.rawValue }
            if folded.contains("dc") { return ElectricalSystem.dc.rawValue }
            return value
        case "material":
            if folded.hasPrefix("al") { return ConductorMaterial.aluminum.rawValue }
            if folded.hasPrefix("cu") || folded.contains("copper") { return ConductorMaterial.copper.rawValue }
            return value
        case "preset":
            if folded.hasPrefix("al") { return ConductorLengthMaterial.aluminum.rawValue }
            if folded.contains("hard") { return ConductorLengthMaterial.copperHardDrawn.rawValue }
            if folded.hasPrefix("cu") || folded.contains("copper") {
                return ConductorLengthMaterial.copperAnnealed.rawValue
            }
            return value
        default:
            return value
        }
    }
}
