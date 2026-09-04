import Foundation

/// Top-level home areas on the iOS toolbox. Field is the jobsite home;
/// Toolkit is basics, bench homework, and references.
public enum ToolHomeArea: String, CaseIterable, Sendable, Hashable {
    case field
    case toolkit
}

/// Display shelf inside a home area. Sensors live on Field → Instruments.
public enum ToolShelfKind: String, CaseIterable, Sendable, Hashable {
    case jobsite
    case power
    case controls
    case instruments
    case basics
    case bench
    case reference

    public var homeArea: ToolHomeArea {
        switch self {
        case .jobsite, .power, .controls, .instruments: return .field
        case .basics, .bench, .reference: return .toolkit
        }
    }
}

/// Single source of truth for Field vs Toolkit. Keys match `ToolID.rawValue`.
///
/// Category membership on the iOS catalog can stay as-is for color / merge
/// friendliness; this policy decides which home area a tool opens under.
/// Unknown future IDs default to Field (the primary home) unless listed here
/// as Toolkit — including AoE analog IDs that are not on `main` yet.
public enum ToolHomeAreaPolicy {
    public static func area(forToolID id: String) -> ToolHomeArea {
        if toolkitIDs.contains(id) { return .toolkit }
        return .field
    }

    public static func shelf(forToolID id: String) -> ToolShelfKind {
        if instrumentIDs.contains(id) { return .instruments }
        if basicsIDs.contains(id) { return .basics }
        if benchIDs.contains(id) { return .bench }
        if referenceIDs.contains(id) { return .reference }
        if powerIDs.contains(id) { return .power }
        if controlsIDs.contains(id) { return .controls }
        return .jobsite
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

    /// Homework / bench / reference — including AoE analog IDs from open PRs
    /// so those tools land in Toolkit when they merge, without this PR adding ToolIDs.
    private static let toolkitIDs: Set<String> = [
        "ohmsLaw", "voltageDivider", "seriesParallel", "resistorColor",
        "ledRC", "frequencyWave", "unitConverter", "timer555",
        "reactance", "phasorDiagram", "numberBase", "magneticCircuit",
        "fiberLink", "gaussianBeam", "transientCircuit", "diodeIV", "rfLink",
        "referenceLibrary",
        "analogWorkbench", "noiseSNR", "linearRegulator",
        "instrumentationAmp", "adcDac",
    ]

    private static let basicsIDs: Set<String> = [
        "ohmsLaw", "voltageDivider", "seriesParallel", "resistorColor",
        "ledRC", "frequencyWave", "unitConverter", "timer555",
    ]

    private static let benchIDs: Set<String> = [
        "reactance", "phasorDiagram", "numberBase", "magneticCircuit",
        "fiberLink", "gaussianBeam", "transientCircuit", "diodeIV", "rfLink",
        "analogWorkbench", "noiseSNR", "linearRegulator",
        "instrumentationAmp", "adcDac",
    ]

    private static let referenceIDs: Set<String> = [
        "referenceLibrary",
    ]

    private static let instrumentIDs: Set<String> = [
        "wifiStatus", "bluetoothScan", "noiseMeter", "bubbleLevel",
        "magnetometer", "barometer", "motionSnapshot", "fieldPosition",
        "deviceHealth",
    ]

    private static let powerIDs: Set<String> = [
        "power", "powerWizard", "transformer", "powerFactor", "batteryBank",
        "solarDesign", "tapChanger", "harmonicsTHD", "upsSizing",
        "heaterDesign", "solenoidDesign", "empEmc",
        "eBikeTorqueRPM", "eBikeSprocket", "eBikeRange", "eBikePackDesigner", "nickelStrip",
    ]

    private static let controlsIDs: Set<String> = [
        "signalScaling", "modbusAddress", "plcTimer", "rackCurrent",
    ]

    /// Saved-job keys are short labels (`V`, `I`); stored fields are longer.
    private static let fieldAliases: [String: [String: String]] = [
        "ohmsLaw": ["V": "voltage", "I": "current", "R": "resistance"],
        "power": ["V": "voltage", "I": "current", "R": "resistance", "PF": "powerFactor"],
        "voltageDrop": [
            "sys": "system", "V": "voltage", "I": "current", "L": "length",
        ],
        "conduitFill": ["n": "qty", "emt": "trade", "size": "size"],
        "wireAmpacity": ["I": "amps", "mat": "material"],
        "motorFLA": ["HP": "hp", "V": "systemVolts"],
        "voltageDivider": ["Vin": "vin", "Vout": "vout", "R1": "r1", "R2": "r2"],
        "ledRC": ["Vin": "supply", "Vf": "vf", "If": "current", "R": "resistance", "C": "capacitance"],
        "timer555": ["R1": "r1", "R2": "r2", "C": "c", "R": "r1"],
        "frequencyWave": ["f": "frequency", "T": "period", "λ": "wavelength", "L": "inductance", "C": "capacitance"],
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
        default:
            return value
        }
    }
}
