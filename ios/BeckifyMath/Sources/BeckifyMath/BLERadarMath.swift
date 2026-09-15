import Foundation

/// Rough RSSI proximity band for the BLE Scanner radar. Not a rangefinder class.
public enum BLERadarBand: String, CaseIterable, Equatable, Sendable {
    case near = "Near"
    case mid = "Mid"
    case far = "Far"
    case unknown = "Unknown"
}

/// One peripheral’s place on the radar. Angle is a stable layout slot, not bearing.
public struct BLERadarPlacement: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var rssi: Int
    public var band: BLERadarBand
    public var estimatedMeters: Double?
    public var angleDegrees: Double
    public var normalizedRadius: Double

    public init(
        id: UUID,
        rssi: Int,
        band: BLERadarBand,
        estimatedMeters: Double?,
        angleDegrees: Double,
        normalizedRadius: Double
    ) {
        self.id = id
        self.rssi = rssi
        self.band = band
        self.estimatedMeters = estimatedMeters
        self.angleDegrees = angleDegrees
        self.normalizedRadius = normalizedRadius
    }
}

/// Uncalibrated BLE advertisement RSSI helpers for a polar layout.
///
/// Radius uses a log-distance estimate with a typical 1 m reference. That is a
/// homework / field-note band — not calibrated ranging. Angle is hashed from
/// the CoreBluetooth identifier so dots stay put; it is **not** angle-of-arrival.
/// iOS does not expose BLE AoA to third-party apps.
public enum BLERadarMath {
    /// CoreBluetooth uses 127 when advertisement RSSI is unavailable.
    public static let unavailableRSSI = 127
    /// Common BLE homework reference at 1 m. Not a measured Tx power.
    public static let referenceRSSIAtOneMeter = -59
    public static let pathLossExponent = 2.0
    public static let minEstimateMeters = 0.3
    public static let maxEstimateMeters = 20.0
    public static let nearRSSIFloor = -60
    public static let midRSSIFloor = -80
    public static let minPlotRadius = 0.22
    public static let maxPlotRadius = 0.92
    /// Advertised TX Power Level is only used as P₀ when it looks like RSSI at 1 m.
    public static let txPowerAsOneMeterMin = -90
    public static let txPowerAsOneMeterMax = -20

    public static func isUsableRSSI(_ rssi: Int) -> Bool {
        rssi != unavailableRSSI && rssi >= -127 && rssi <= 20
    }

    /// CoreBluetooth `CBAdvertisementDataTxPowerLevelKey` is radiated TX, not always RSSI@1 m.
    /// Only the typical measured-power band (−90…−20 dBm) replaces the homework P₀.
    public static func usesTxPowerForDistance(_ txPowerDBm: Int?) -> Bool {
        guard let tx = txPowerDBm else { return false }
        return tx >= txPowerAsOneMeterMin && tx <= txPowerAsOneMeterMax
    }

    public static func distanceReferenceRSSI(txPowerDBm: Int?) -> Int {
        usesTxPowerForDistance(txPowerDBm) ? txPowerDBm! : referenceRSSIAtOneMeter
    }

    public static func band(rssi: Int) -> BLERadarBand {
        guard isUsableRSSI(rssi) else { return .unknown }
        if rssi >= nearRSSIFloor { return .near }
        if rssi >= midRSSIFloor { return .mid }
        return .far
    }

    /// Log-distance estimate clamped to a displayable band. `nil` if RSSI is unusable.
    public static func estimatedMeters(rssi: Int, txPowerDBm: Int? = nil) -> Double? {
        guard isUsableRSSI(rssi) else { return nil }
        let p0 = Double(distanceReferenceRSSI(txPowerDBm: txPowerDBm))
        let raw = pow(10, (p0 - Double(rssi)) / (10 * pathLossExponent))
        guard raw.isFinite else { return nil }
        return min(maxEstimateMeters, max(minEstimateMeters, raw))
    }

    public static func estimatedMetersCaption(rssi: Int, txPowerDBm: Int? = nil) -> String {
        let usedTX = usesTxPowerForDistance(txPowerDBm)
        guard let meters = estimatedMeters(rssi: rssi, txPowerDBm: txPowerDBm) else { return "— est." }
        let suffix = usedTX ? " m est. · TX" : " m est."
        if meters <= minEstimateMeters + 0.001 {
            return "< \(formatMeters(minEstimateMeters))\(suffix)"
        }
        if meters >= maxEstimateMeters - 0.001 {
            return "> \(formatMeters(maxEstimateMeters))\(suffix)"
        }
        return "\(formatMeters(meters))\(suffix)"
    }

    /// 0 = center (stronger / nearer), 1 = outer ring. Unknown RSSI sits on the rim.
    public static func normalizedRadius(rssi: Int) -> Double {
        guard let meters = estimatedMeters(rssi: rssi) else { return maxPlotRadius }
        let span = maxEstimateMeters - minEstimateMeters
        let t = span > 0 ? (meters - minEstimateMeters) / span : 1
        let clamped = min(1, max(0, t))
        return minPlotRadius + (maxPlotRadius - minPlotRadius) * clamped
    }

    /// Deterministic 0..<360 slot from the identifier. Not a compass heading.
    public static func baseAngleDegrees(identifier: UUID) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        withUnsafeBytes(of: identifier.uuid) { raw in
            for byte in raw {
                hash ^= UInt64(byte)
                hash = hash &* 1_099_511_628_211
            }
        }
        return Double(hash % 360)
    }

    public static func normalizeDegrees(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        var deg = value.truncatingRemainder(dividingBy: 360)
        if deg < 0 { deg += 360 }
        return deg
    }

    /// Signed shortest arc from `from` to `to` in (−180, 180].
    public static func shortestAngleDelta(from: Double, to: Double) -> Double {
        var delta = normalizeDegrees(to) - normalizeDegrees(from)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return delta
    }

    /// Spread hashed angles so nearby slots do not sit on top of each other.
    /// Order is UUID-sorted so the same set always lands the same way.
    public static func layoutAngles(
        identifiers: [UUID],
        minSeparationDegrees: Double = 10
    ) -> [UUID: Double] {
        let sep = minSeparationDegrees.isFinite && minSeparationDegrees > 0 ? minSeparationDegrees : 10
        var placed: [(UUID, Double)] = []
        for id in identifiers.sorted(by: { $0.uuidString < $1.uuidString }) {
            var angle = baseAngleDegrees(identifier: id)
            var attempts = 0
            while attempts < 36 {
                let conflict = placed.contains {
                    abs(shortestAngleDelta(from: $0.1, to: angle)) < sep
                }
                if !conflict { break }
                angle = normalizeDegrees(angle + sep)
                attempts += 1
            }
            placed.append((id, angle))
        }
        return Dictionary(uniqueKeysWithValues: placed)
    }

    public static func placements(from items: [(id: UUID, rssi: Int)]) -> [BLERadarPlacement] {
        let angles = layoutAngles(identifiers: items.map(\.id))
        return items.map { item in
            BLERadarPlacement(
                id: item.id,
                rssi: item.rssi,
                band: band(rssi: item.rssi),
                estimatedMeters: estimatedMeters(rssi: item.rssi),
                angleDegrees: angles[item.id] ?? baseAngleDegrees(identifier: item.id),
                normalizedRadius: normalizedRadius(rssi: item.rssi)
            )
        }
    }

    public static func formatMeters(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if value >= 10 { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}
