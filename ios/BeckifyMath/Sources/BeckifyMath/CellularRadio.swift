import Foundation

/// Radio generation implied by a CoreTelephony RAT string. Not a measured RF level.
public enum CellularGeneration: String, Equatable, Sendable {
    case fiveG = "5G"
    case fourG = "4G"
    case threeG = "3G"
    case twoG = "2G"
    case unknown = "Unknown"
}

/// Human-readable mapping of a `CTRadioAccessTechnology*` constant.
public struct CellularRATIdentity: Equatable, Sendable, Identifiable {
    public var raw: String
    public var label: String
    public var generation: CellularGeneration

    public var id: String { raw.isEmpty ? label : raw }

    public init(raw: String, label: String, generation: CellularGeneration) {
        self.raw = raw
        self.label = label
        self.generation = generation
    }

    public var generationLabel: String { generation.rawValue }

    /// Sticky-answer style: "LTE (4G)" or "5G NR (SA)".
    public var compact: String {
        if generation == .unknown { return label }
        if label.contains(generation.rawValue) { return label }
        return "\(label) (\(generation.rawValue))"
    }

    /// Longer family name for the parameter board — still not an RF level.
    public var technologyDetail: String {
        switch generation {
        case .fiveG:
            return label.contains("NSA") ? "5G NR non-standalone (LTE anchor)" : "5G NR standalone"
        case .fourG:
            return "4G LTE"
        case .threeG:
            return "3G (\(label))"
        case .twoG:
            return "2G (\(label))"
        case .unknown:
            return label
        }
    }
}

/// Typical planning bands for cellular RF metrics. **Reference only — not measured.**
public struct CellularReferenceMetric: Equatable, Sendable, Identifiable {
    public var symbol: String
    public var name: String
    public var unit: String
    public var meaning: String
    public var excellent: String
    public var good: String
    public var fair: String
    public var poor: String

    public var id: String { symbol }

    public init(
        symbol: String,
        name: String,
        unit: String,
        meaning: String,
        excellent: String,
        good: String,
        fair: String,
        poor: String
    ) {
        self.symbol = symbol
        self.name = name
        self.unit = unit
        self.meaning = meaning
        self.excellent = excellent
        self.good = good
        self.fair = fair
        self.poor = poor
    }
}

/// App Store–safe cellular *identity* helpers: RAT labels, PLMN display, reference bands.
/// iOS does not expose cellular RSRP / RSRQ / SINR / RSSI / dBm to third-party apps.
/// Do not invent those numbers here.
public enum CellularRadioIdentity {
    public static let ratPrefix = "CTRadioAccessTechnology"

    /// Known CoreTelephony RAT constants in generation order (5G → 2G).
    public static let catalog: [CellularRATIdentity] = [
        .init(raw: "CTRadioAccessTechnologyNR", label: "5G NR (SA)", generation: .fiveG),
        .init(raw: "CTRadioAccessTechnologyNRNSA", label: "5G NR (NSA)", generation: .fiveG),
        .init(raw: "CTRadioAccessTechnologyLTE", label: "LTE", generation: .fourG),
        .init(raw: "CTRadioAccessTechnologyWCDMA", label: "WCDMA", generation: .threeG),
        .init(raw: "CTRadioAccessTechnologyHSDPA", label: "HSDPA", generation: .threeG),
        .init(raw: "CTRadioAccessTechnologyHSUPA", label: "HSUPA", generation: .threeG),
        .init(raw: "CTRadioAccessTechnologyeHRPD", label: "eHRPD", generation: .threeG),
        .init(raw: "CTRadioAccessTechnologyCDMAEVDORev0", label: "EV-DO Rev 0", generation: .threeG),
        .init(raw: "CTRadioAccessTechnologyCDMAEVDORevA", label: "EV-DO Rev A", generation: .threeG),
        .init(raw: "CTRadioAccessTechnologyCDMAEVDORevB", label: "EV-DO Rev B", generation: .threeG),
        .init(raw: "CTRadioAccessTechnologyCDMA1x", label: "CDMA 1x", generation: .twoG),
        .init(raw: "CTRadioAccessTechnologyEdge", label: "EDGE", generation: .twoG),
        .init(raw: "CTRadioAccessTechnologyGPRS", label: "GPRS", generation: .twoG),
    ]

    /// Typical LTE/NR discussion bands. Labeled as reference — never treat as a live reading.
    public static let typicalMetrics: [CellularReferenceMetric] = [
        CellularReferenceMetric(
            symbol: "RSRP",
            name: "Reference Signal Received Power",
            unit: "dBm",
            meaning: "Wanted-cell reference-signal power at the UE. Lower (more negative) is weaker.",
            excellent: "≥ −80",
            good: "−80 to −90",
            fair: "−90 to −100",
            poor: "< −100"
        ),
        CellularReferenceMetric(
            symbol: "RSRQ",
            name: "Reference Signal Received Quality",
            unit: "dB",
            meaning: "Reference quality vs. serving-cell RSSI. Sensitive to load and interference.",
            excellent: "≥ −10",
            good: "−10 to −15",
            fair: "−15 to −20",
            poor: "< −20"
        ),
        CellularReferenceMetric(
            symbol: "SINR",
            name: "Signal to Interference plus Noise",
            unit: "dB",
            meaning: "Wanted signal vs. interference and noise. Drives MCS more than raw RSRP.",
            excellent: "≥ 20",
            good: "13 to 20",
            fair: "0 to 13",
            poor: "< 0"
        ),
        CellularReferenceMetric(
            symbol: "RSSI",
            name: "Received Signal Strength Indicator",
            unit: "dBm",
            meaning: "Broadband received power (signal + noise + interference). Coarser than RSRP.",
            excellent: "> −70",
            good: "−70 to −85",
            fair: "−85 to −100",
            poor: "< −100"
        ),
    ]

    /// Map a CoreTelephony RAT string (or a bare suffix such as `LTE`) to a label.
    public static func identify(_ raw: String?) -> CellularRATIdentity {
        let trimmed = cleaned(raw) ?? ""
        if trimmed.isEmpty {
            return CellularRATIdentity(raw: "", label: "Not reported", generation: .unknown)
        }
        let token = normalizeRATToken(trimmed)
        if let known = catalog.first(where: { normalizeRATToken($0.raw) == token }) {
            return CellularRATIdentity(raw: trimmed, label: known.label, generation: known.generation)
        }
        return CellularRATIdentity(raw: trimmed, label: "Unknown (\(trimmed))", generation: .unknown)
    }

    /// Unique service identifiers from RAT and carrier dictionaries, RAT keys first.
    public static func serviceIDs(ratKeys: [String], carrierKeys: [String] = []) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for key in ratKeys + carrierKeys {
            guard let id = cleaned(key), seen.insert(id).inserted else { continue }
            out.append(id)
        }
        return out
    }

    public static func serviceCountLabel(_ count: Int) -> String {
        if count <= 0 { return "none reported" }
        if count == 1 { return "1 service" }
        return "\(count) services"
    }

    /// CoreTelephony service identifiers are long hex strings — keep a short display form.
    public static func shortServiceID(_ id: String) -> String {
        guard let cleaned = cleaned(id) else { return "—" }
        if cleaned.count <= 8 { return cleaned }
        return "…" + String(cleaned.suffix(4))
    }

    public static func plmn(mcc: String?, mnc: String?) -> String? {
        guard let mcc = cleaned(mcc), let mnc = cleaned(mnc) else { return nil }
        return "\(mcc)-\(mnc)"
    }

    public static func displayISO(_ iso: String?) -> String? {
        cleaned(iso)?.uppercased()
    }

    /// Empty, whitespace, or Apple’s `--` placeholder means “not provided”.
    public static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if t == "--" || t == "—" || t == "-" { return nil }
        return t
    }

    public static func displayField(_ value: String?) -> String {
        cleaned(value) ?? "—"
    }

    /// Generation scale used by the instrument gauge (2G → 5G). Not RF bars.
    public static let generationOrder: [CellularGeneration] = [.twoG, .threeG, .fourG, .fiveG]

    /// 0 = unknown, 1 = 2G … 4 = 5G.
    public static func generationStep(_ generation: CellularGeneration) -> Int {
        switch generation {
        case .unknown: return 0
        case .twoG: return 1
        case .threeG: return 2
        case .fourG: return 3
        case .fiveG: return 4
        }
    }

    /// 0…1 fill for a generation arc. Unknown is 0 — never a fabricated RSRP.
    public static func generationFill(_ generation: CellularGeneration) -> Double {
        let step = generationStep(generation)
        return step == 0 ? 0 : Double(step) / 4.0
    }

    /// Median RTT (ms) that empties the latency gauge. Matches Wi-Fi Path's poor band.
    public static let rttGaugeEmptyMS: Double = 250

    /// Legend ticks under the RTT gauge. Last tick is `rttGaugeEmptyMS`.
    public static let rttGaugeLegendLabels = ["<25", "<60", "<120", "≥\(Int(rttGaugeEmptyMS))"]

    /// 0…1 fill for a latency gauge: lower median RTT fills more. Nil / invalid is 0.
    public static func rttFill(medianMS: Double?) -> Double {
        guard let medianMS, medianMS.isFinite, medianMS >= 0 else { return 0 }
        return min(1, max(0, 1 - medianMS / rttGaugeEmptyMS))
    }

    public static func normalizeRATToken(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let slash = s.lastIndex(of: "/") {
            s = String(s[s.index(after: slash)...])
        }
        if s.hasPrefix(ratPrefix) {
            s = String(s.dropFirst(ratPrefix.count))
        }
        return s.lowercased()
    }
}
