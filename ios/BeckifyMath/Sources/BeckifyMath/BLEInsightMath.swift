import Foundation

/// One advertisement for RF-density insights. Not a person.
public struct BLEInsightSample: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var rssi: Int
    public var companyID: UInt16?
    public var kind: BLEKindHint
    public var isConnectable: Bool?
    public var looksLikeIBeacon: Bool
    public var firstSeen: Date
    public var lastSeen: Date

    public init(
        id: UUID,
        name: String,
        rssi: Int,
        companyID: UInt16?,
        kind: BLEKindHint,
        isConnectable: Bool?,
        looksLikeIBeacon: Bool,
        firstSeen: Date,
        lastSeen: Date
    ) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.companyID = companyID
        self.kind = kind
        self.isConnectable = isConnectable
        self.looksLikeIBeacon = looksLikeIBeacon
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }

    public var tallyRow: BLEScanTallyRow {
        BLEScanTallyRow(name: name, rssi: rssi, companyID: companyID)
    }
}

/// Quiet / Moderate / Busy / Very busy — always RF activity, never occupancy.
public enum BLERFActivityCaption: String, Equatable, Sendable {
    case quiet = "Quiet RF activity"
    case moderate = "Moderate RF activity"
    case busy = "Busy RF activity"
    case veryBusy = "Very busy RF activity"

    public static func from(index: Int) -> BLERFActivityCaption {
        switch index {
        case ..<20: return .quiet
        case ..<45: return .moderate
        case ..<70: return .busy
        default: return .veryBusy
        }
    }
}

/// 0…100 device / RF density from unique advertisements in the live window.
public struct BLERFActivity: Equatable, Sendable {
    public var index: Int
    public var caption: BLERFActivityCaption
    public var weightedCount: Double
    public var uniqueDevices: Int

    public init(index: Int, caption: BLERFActivityCaption, weightedCount: Double, uniqueDevices: Int) {
        self.index = index
        self.caption = caption
        self.weightedCount = weightedCount
        self.uniqueDevices = uniqueDevices
    }

    public var indexCaption: String {
        "\(index) · \(caption.rawValue)"
    }
}

/// Named / unnamed, bands, manufacturers, beacon-like vs connectable. Not occupancy.
public struct BLERoomMix: Equatable, Sendable {
    public var summary: BLEScanSummary
    public var beaconLike: Int
    public var connectableYes: Int
    public var connectableNo: Int
    public var connectableUnknown: Int

    public init(
        summary: BLEScanSummary,
        beaconLike: Int,
        connectableYes: Int,
        connectableNo: Int,
        connectableUnknown: Int
    ) {
        self.summary = summary
        self.beaconLike = beaconLike
        self.connectableYes = connectableYes
        self.connectableNo = connectableNo
        self.connectableUnknown = connectableUnknown
    }

    public var shareCaption: String {
        let total = summary.total
        guard total > 0 else { return "—" }
        return "\(beaconLike)/\(total) beacon-like · \(connectableYes)/\(total) connectable"
    }
}

/// Trend of unique advertisement IDs — still not people.
public enum BLEChurnTrend: String, Equatable, Sendable {
    case warmingUp = "RF mix still filling in"
    case busier = "Getting busier (RF)"
    case quieter = "Getting quieter (RF)"
    case steady = "Steady RF mix"
}

/// Appeared / aged-out unique IDs over a few minutes of scan history.
public struct BLEChurn: Equatable, Sendable {
    public var appeared: Int
    public var disappeared: Int
    public var trend: BLEChurnTrend
    public var windowSeconds: Int

    public init(appeared: Int, disappeared: Int, trend: BLEChurnTrend, windowSeconds: Int) {
        self.appeared = appeared
        self.disappeared = disappeared
        self.trend = trend
        self.windowSeconds = windowSeconds
    }

    public var caption: String {
        let minutes = max(1, Int((Double(windowSeconds) / 60.0).rounded()))
        let window = minutes == 1 ? "1 min" : "\(minutes) min"
        return "\(appeared) appeared · \(disappeared) aged out · \(trend.rawValue) (\(window))"
    }
}

/// Combined scan-summary insights. Framed as device / RF density, never occupancy.
public struct BLEScanInsights: Equatable, Sendable {
    public var activity: BLERFActivity
    public var mix: BLERoomMix
    public var churn: BLEChurn

    public init(activity: BLERFActivity, mix: BLERoomMix, churn: BLEChurn) {
        self.activity = activity
        self.mix = mix
        self.churn = churn
    }

    public var summary: BLEScanSummary { mix.summary }

    public var stickyLine: String {
        if summary.total == 0 {
            return summary.stickyLine
        }
        return "\(activity.caption.rawValue) · \(summary.deviceCountCaption) ≠ people"
    }

    public var copyLine: String {
        var parts = [
            "\(activity.caption.rawValue) (\(activity.index)/100).",
            "\(summary.deviceCountCaption) (not people).",
            "Named \(summary.named), unnamed \(summary.unnamed). Near \(summary.near) / mid \(summary.mid) / far \(summary.far).",
        ]
        if summary.unknownBand > 0 {
            parts.append("Unknown band \(summary.unknownBand).")
        }
        parts.append("Room mix: \(mix.shareCaption).")
        if !summary.topManufacturers.isEmpty {
            parts.append("Top manufacturers: \(summary.manufacturersCaption).")
        }
        parts.append("Churn: \(churn.caption).")
        parts.append(BLEAdvertisementMath.peopleCountDisclaimer)
        return parts.joined(separator: " ")
    }

    public static let empty = BLEInsightMath.insights(live: [], history: [], now: .distantPast, scanStarted: nil)
}

/// RF activity, room mix, and ID churn from public BLE advertisements.
///
/// Unique CoreBluetooth identifiers are **not** people. Weights prefer near-band
/// and connectable personal-ish radios and down-weight beacon / mesh ads.
public enum BLEInsightMath {
    /// Matches the scanner’s live list: advertisements heard in the last 30 s.
    public static let liveWindowSeconds: TimeInterval = 30
    /// History kept for appeared / aged-out counts.
    public static let churnWindowSeconds: TimeInterval = 180
    /// Current vs previous unique-ID buckets for busier / quieter / steady.
    public static let trendBucketSeconds: TimeInterval = 60
    /// Need two trend buckets before claiming a direction.
    public static let warmingUpSeconds: TimeInterval = 120
    /// Saturating map: ~8 weighted uniques ≈ 50, ~20 ≈ 82, 30+ approaches 100.
    public static let activityScale = 11.5
    public static let nearWeight = 1.45
    public static let midWeight = 1.00
    public static let farWeight = 0.55
    public static let unknownWeight = 0.30
    public static let infrastructureFactor = 0.35
    public static let personalFactor = 1.22
    public static let personalConnectableFactor = 1.12
    public static let otherConnectableFactor = 1.08
    public static let unnamedNoiseFactor = 0.70

    public static func isInfrastructureLike(kind: BLEKindHint, looksLikeIBeacon: Bool) -> Bool {
        looksLikeIBeacon || kind == .beacon || kind == .mesh
    }

    public static func isPersonalish(_ kind: BLEKindHint) -> Bool {
        switch kind {
        case .audio, .wearable, .fitness, .phoneEcosystem: return true
        default: return false
        }
    }

    /// Per-device weight for the activity index. Unique IDs, not people.
    public static func sampleWeight(_ sample: BLEInsightSample) -> Double {
        let band = BLERadarMath.band(rssi: sample.rssi)
        var weight: Double
        switch band {
        case .near: weight = nearWeight
        case .mid: weight = midWeight
        case .far: weight = farWeight
        case .unknown: weight = unknownWeight
        }
        if isInfrastructureLike(kind: sample.kind, looksLikeIBeacon: sample.looksLikeIBeacon) {
            weight *= infrastructureFactor
        } else if isPersonalish(sample.kind) {
            weight *= personalFactor
            if sample.isConnectable == true {
                weight *= personalConnectableFactor
            }
        } else if sample.isConnectable == true {
            weight *= otherConnectableFactor
        } else if sample.kind == .unnamedNoise {
            weight *= unnamedNoiseFactor
        }
        return weight
    }

    public static func activityIndex(weighted: Double) -> Int {
        guard weighted.isFinite, weighted > 0 else { return 0 }
        let raw = 100 * (1 - exp(-weighted / activityScale))
        guard raw.isFinite else { return 0 }
        return min(100, max(0, Int(raw.rounded())))
    }

    public static func activity(from live: [BLEInsightSample]) -> BLERFActivity {
        let weighted = live.reduce(0.0) { $0 + sampleWeight($1) }
        let index = activityIndex(weighted: weighted)
        return BLERFActivity(
            index: index,
            caption: .from(index: index),
            weightedCount: weighted,
            uniqueDevices: live.count
        )
    }

    public static func roomMix(from live: [BLEInsightSample]) -> BLERoomMix {
        let summary = BLEAdvertisementMath.summarize(live.map(\.tallyRow))
        var beaconLike = 0
        var connectableYes = 0
        var connectableNo = 0
        var connectableUnknown = 0
        for sample in live {
            if isInfrastructureLike(kind: sample.kind, looksLikeIBeacon: sample.looksLikeIBeacon) {
                beaconLike += 1
            }
            switch sample.isConnectable {
            case true?: connectableYes += 1
            case false?: connectableNo += 1
            case nil: connectableUnknown += 1
            }
        }
        return BLERoomMix(
            summary: summary,
            beaconLike: beaconLike,
            connectableYes: connectableYes,
            connectableNo: connectableNo,
            connectableUnknown: connectableUnknown
        )
    }

    /// True when the ID was heard at some point inside `[from, to]`.
    public static func wasPresent(_ sample: BLEInsightSample, from: Date, to: Date) -> Bool {
        sample.firstSeen <= to && sample.lastSeen >= from
    }

    public static func churn(
        history: [BLEInsightSample],
        now: Date,
        scanStarted: Date?,
        liveWindow: TimeInterval = liveWindowSeconds,
        trendBucket: TimeInterval = trendBucketSeconds,
        historyWindow: TimeInterval = churnWindowSeconds,
        warmingUp: TimeInterval = warmingUpSeconds
    ) -> BLEChurn {
        let windowSeconds = Int(historyWindow.rounded())
        let historyStart = now.addingTimeInterval(-historyWindow)
        let liveStart = now.addingTimeInterval(-liveWindow)
        let rows = history.filter { $0.lastSeen >= historyStart }

        let appeared = rows.filter { $0.firstSeen >= historyStart }.count
        let disappeared = rows.filter { $0.lastSeen < liveStart }.count

        let scanAge = scanStarted.map { now.timeIntervalSince($0) } ?? 0
        if scanStarted == nil || scanAge < warmingUp {
            return BLEChurn(
                appeared: appeared,
                disappeared: disappeared,
                trend: .warmingUp,
                windowSeconds: windowSeconds
            )
        }

        let recentStart = now.addingTimeInterval(-trendBucket)
        let previousStart = now.addingTimeInterval(-2 * trendBucket)
        let recent = Set(rows.filter { wasPresent($0, from: recentStart, to: now) }.map(\.id))
        let previous = Set(rows.filter { wasPresent($0, from: previousStart, to: recentStart) }.map(\.id))
        let bucketAppeared = recent.subtracting(previous).count
        let bucketDisappeared = previous.subtracting(recent).count
        let net = bucketAppeared - bucketDisappeared
        let trend: BLEChurnTrend
        if abs(net) <= 1 {
            trend = .steady
        } else if net > 1 {
            trend = .busier
        } else {
            trend = .quieter
        }
        return BLEChurn(
            appeared: appeared,
            disappeared: disappeared,
            trend: trend,
            windowSeconds: windowSeconds
        )
    }

    public static func insights(
        live: [BLEInsightSample],
        history: [BLEInsightSample],
        now: Date,
        scanStarted: Date?
    ) -> BLEScanInsights {
        BLEScanInsights(
            activity: activity(from: live),
            mix: roomMix(from: live),
            churn: churn(history: history, now: now, scanStarted: scanStarted)
        )
    }
}
