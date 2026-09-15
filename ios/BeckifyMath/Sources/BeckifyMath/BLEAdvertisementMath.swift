import Foundation

/// Heuristic role label from public advertisement fields. Not device identity.
public enum BLEKindHint: String, CaseIterable, Equatable, Sendable {
    case audio = "Audio"
    case wearable = "Wearable-ish"
    case mesh = "Mesh"
    case fitness = "Fitness"
    case beacon = "Beacon-like"
    case phoneEcosystem = "Phone-ecosystem"
    case unnamedNoise = "Unnamed noise"
    case unknown = "Unknown"

    /// List-row chip: skip Unknown / Unnamed noise so the list stays scannable.
    public var showsAsChip: Bool {
        switch self {
        case .unknown, .unnamedNoise: return false
        default: return true
        }
    }

    /// Detail-sheet value. Keeps the word “hint” so it is not read as identity.
    public var detailValue: String {
        switch self {
        case .unknown: return "No hint"
        default: return "\(rawValue) hint"
        }
    }
}

/// Company ID plus leftover manufacturer-specific bytes. Payload is not decoded.
public struct BLEManufacturerParse: Equatable, Sendable {
    public var companyID: UInt16
    public var companyName: String
    public var payloadByteCount: Int
    /// Public iBeacon AD prefix `0x02 0x15` after Apple’s company ID. UUID is not extracted.
    public var looksLikeIBeacon: Bool

    public init(companyID: UInt16, companyName: String, payloadByteCount: Int, looksLikeIBeacon: Bool) {
        self.companyID = companyID
        self.companyName = companyName
        self.payloadByteCount = payloadByteCount
        self.looksLikeIBeacon = looksLikeIBeacon
    }
}

/// Service-data UUID plus size. Hex only when the payload is short.
public struct BLEServiceDataSummary: Equatable, Sendable {
    public var uuid: String
    public var byteCount: Int
    public var previewHex: String?

    public init(uuid: String, byteCount: Int, previewHex: String?) {
        self.uuid = uuid
        self.byteCount = byteCount
        self.previewHex = previewHex
    }

    public var sizeCaption: String {
        byteCount == 1 ? "1 B" : "\(byteCount) B"
    }
}

/// One scan row for the summary tally. UI maps CoreBluetooth fields into this.
public struct BLEScanTallyRow: Equatable, Sendable {
    public var name: String
    public var rssi: Int
    public var companyID: UInt16?

    public init(name: String, rssi: Int, companyID: UInt16?) {
        self.name = name
        self.rssi = rssi
        self.companyID = companyID
    }
}

public struct BLEManufacturerCount: Equatable, Sendable {
    public var companyID: UInt16
    public var name: String
    public var count: Int

    public init(companyID: UInt16, name: String, count: Int) {
        self.companyID = companyID
        self.name = name
        self.count = count
    }

    public var caption: String { "\(name) \(count)" }
}

/// Named / unnamed / band / manufacturer roll-up. Not an occupancy estimate.
public struct BLEScanSummary: Equatable, Sendable {
    public var total: Int
    public var named: Int
    public var unnamed: Int
    public var near: Int
    public var mid: Int
    public var far: Int
    public var unknownBand: Int
    public var topManufacturers: [BLEManufacturerCount]

    public init(
        total: Int,
        named: Int,
        unnamed: Int,
        near: Int,
        mid: Int,
        far: Int,
        unknownBand: Int,
        topManufacturers: [BLEManufacturerCount]
    ) {
        self.total = total
        self.named = named
        self.unnamed = unnamed
        self.near = near
        self.mid = mid
        self.far = far
        self.unknownBand = unknownBand
        self.topManufacturers = topManufacturers
    }

    public var deviceCountCaption: String {
        "\(total) device" + (total == 1 ? "" : "s")
    }

    public var stickyLine: String {
        "\(deviceCountCaption) ≠ people"
    }

    public var namedCaption: String {
        "\(named) named / \(unnamed) unnamed"
    }

    public var bandCaption: String {
        "\(near) / \(mid) / \(far)"
    }

    public var manufacturersCaption: String {
        if topManufacturers.isEmpty { return "—" }
        return topManufacturers.map(\.caption).joined(separator: ", ")
    }

    public var copyLine: String {
        var parts = [
            "\(deviceCountCaption) (not people).",
            "Named \(named), unnamed \(unnamed). Near \(near) / mid \(mid) / far \(far).",
        ]
        if unknownBand > 0 {
            parts.append("Unknown band \(unknownBand).")
        }
        if !topManufacturers.isEmpty {
            parts.append("Top manufacturers: \(manufacturersCaption).")
        }
        parts.append(BLEAdvertisementMath.peopleCountDisclaimer)
        return parts.joined(separator: " ")
    }
}

/// Public CoreBluetooth advertisement helpers. No Continuity / GATT decoding.
///
/// Company IDs are a **lean** subset of Bluetooth SIG Assigned Numbers,
/// Company Identifiers: https://www.bluetooth.com/specifications/assigned-numbers/
public enum BLEAdvertisementMath {
    public static let unnamedDisplayName = "Unnamed"
    public static let appleCompanyID: UInt16 = 0x004C
    public static let hexDumpLimit = 16
    public static let peopleCountDisclaimer =
        "Device count ≠ people. RF activity, mix, and churn are unique BLE IDs — not occupancy or a headcount. One person can carry many radios; cars, printers, and mesh inflate counts. Apple rotates identifiers."

    /// SIG Assigned Numbers §7 Company Identifiers — short labels, not the legal name.
    private static let knownCompanies: [UInt16: String] = [
        0x0002: "Intel",
        0x0006: "Microsoft",
        0x000D: "Texas Instruments",
        0x000F: "Broadcom",
        0x004C: "Apple",
        0x0059: "Nordic",
        0x006B: "Polar",
        0x0075: "Samsung",
        0x0087: "Garmin",
        0x009E: "Bose",
        0x00E0: "Google",
        0x012D: "Sony",
        0x0157: "Huami",
        0x02E5: "Espressif",
        0x0499: "Ruuvi",
        0x067C: "Tile",
    ]

    private static let meshServices: Set<String> = ["1827", "1828"]
    private static let beaconServices: Set<String> = ["FEAA"]
    private static let audioServices: Set<String> = [
        "1844", "1845", "1846", "1847", "1848",
        "184E", "184F", "1850", "1853", "1854", "1855", "1858",
        "FDF0",
    ]
    private static let fitnessServices: Set<String> = [
        "1808", "180D", "1810", "1814", "1816", "1818", "1819",
        "181F", "1822", "1826", "183E",
    ]
    private static let tileServices: Set<String> = ["FEEC", "FEED"]
    private static let fastPairServices: Set<String> = ["FE2C"]

    public static func displayName(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? unnamedDisplayName : trimmed
    }

    public static func isNamed(_ name: String) -> Bool {
        displayName(name) != unnamedDisplayName
    }

    public static func formatCompanyID(_ id: UInt16) -> String {
        String(format: "0x%04X", id)
    }

    public static func unknownCompanyName(id: UInt16) -> String {
        "Company \(formatCompanyID(id))"
    }

    public static func companyName(id: UInt16) -> String {
        knownCompanies[id] ?? unknownCompanyName(id: id)
    }

    public static func isKnownCompany(id: UInt16) -> Bool {
        knownCompanies[id] != nil
    }

    /// Manufacturer Specific Data: company ID is uint16 little-endian, then vendor bytes.
    public static func parseManufacturerData(_ bytes: [UInt8]) -> BLEManufacturerParse? {
        guard bytes.count >= 2 else { return nil }
        let companyID = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        let payload = Array(bytes.dropFirst(2))
        let looksLikeIBeacon = companyID == appleCompanyID
            && payload.count >= 2
            && payload[0] == 0x02
            && payload[1] == 0x15
        return BLEManufacturerParse(
            companyID: companyID,
            companyName: companyName(id: companyID),
            payloadByteCount: payload.count,
            looksLikeIBeacon: looksLikeIBeacon
        )
    }

    public static func parseManufacturerData(_ data: Data) -> BLEManufacturerParse? {
        parseManufacturerData(Array(data))
    }

    /// Collapse 16-bit UUIDs that CoreBluetooth expands onto the Bluetooth base UUID.
    public static func shortServiceKey(_ uuid: String) -> String {
        let raw = uuid.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let compact = raw.replacingOccurrences(of: "-", with: "")
        if compact.count == 32,
           compact.hasPrefix("0000"),
           compact.hasSuffix("00001000800000805F9B34FB") {
            return String(compact.dropFirst(4).prefix(4))
        }
        if compact.count == 4 || compact.count == 8 {
            return compact
        }
        return raw
    }

    public static func summarizeServiceData(uuid: String, bytes: [UInt8]) -> BLEServiceDataSummary {
        let preview: String?
        if bytes.isEmpty {
            preview = nil
        } else if bytes.count <= hexDumpLimit {
            preview = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        } else {
            preview = nil
        }
        return BLEServiceDataSummary(
            uuid: shortServiceKey(uuid),
            byteCount: bytes.count,
            previewHex: preview
        )
    }

    public static func serviceDataCaption(_ entries: [BLEServiceDataSummary]) -> String {
        if entries.isEmpty { return "None advertised" }
        return entries.map { "\($0.uuid) (\($0.sizeCaption))" }.joined(separator: ", ")
    }

    /// Kind / role hint from company ID + well-known service UUIDs. Not a people class.
    public static func kindHint(
        name: String,
        companyID: UInt16?,
        serviceIDs: [String],
        serviceDataUUIDs: [String] = [],
        looksLikeIBeacon: Bool = false
    ) -> BLEKindHint {
        let keys = Set((serviceIDs + serviceDataUUIDs).map(shortServiceKey))
        let lowered = name.lowercased()

        if keys.contains(where: { meshServices.contains($0) }) || lowered.contains("mesh") {
            return .mesh
        }
        if looksLikeIBeacon
            || keys.contains(where: { beaconServices.contains($0) })
            || companyID == 0x0499 {
            return .beacon
        }
        if keys.contains(where: { audioServices.contains($0) }) || companyID == 0x009E {
            return .audio
        }
        if keys.contains(where: { fitnessServices.contains($0) })
            || companyID == 0x0087
            || companyID == 0x006B {
            return .fitness
        }
        if keys.contains(where: { tileServices.contains($0) })
            || companyID == 0x067C
            || companyID == 0x0157 {
            return .wearable
        }
        if companyID == appleCompanyID
            || companyID == 0x00E0
            || companyID == 0x0006
            || keys.contains(where: { fastPairServices.contains($0) }) {
            return .phoneEcosystem
        }
        if !isNamed(name) && companyID == nil && keys.isEmpty {
            return .unnamedNoise
        }
        return .unknown
    }

    /// One short list subtitle: kind when specific, else a known manufacturer.
    public static func rowChip(kind: BLEKindHint, companyID: UInt16?) -> String? {
        if kind.showsAsChip { return kind.rawValue }
        if let id = companyID, isKnownCompany(id: id) {
            return companyName(id: id)
        }
        return nil
    }

    public static func summarize(
        _ rows: [BLEScanTallyRow],
        topManufacturers: Int = 3
    ) -> BLEScanSummary {
        var named = 0
        var unnamed = 0
        var near = 0
        var mid = 0
        var far = 0
        var unknownBand = 0
        var byCompany: [UInt16: Int] = [:]
        for row in rows {
            if isNamed(row.name) { named += 1 } else { unnamed += 1 }
            switch BLERadarMath.band(rssi: row.rssi) {
            case .near: near += 1
            case .mid: mid += 1
            case .far: far += 1
            case .unknown: unknownBand += 1
            }
            if let id = row.companyID {
                byCompany[id, default: 0] += 1
            }
        }
        let ranked = byCompany
            .map { BLEManufacturerCount(companyID: $0.key, name: companyName(id: $0.key), count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.companyID < $1.companyID
            }
        let limit = max(0, topManufacturers)
        return BLEScanSummary(
            total: rows.count,
            named: named,
            unnamed: unnamed,
            near: near,
            mid: mid,
            far: far,
            unknownBand: unknownBand,
            topManufacturers: Array(ranked.prefix(limit))
        )
    }
}
