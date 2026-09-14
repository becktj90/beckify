import Foundation

// MARK: - Query

public enum ReceptaclePhaseKind: String, Codable, CaseIterable, Sendable, Hashable {
    case singlePhase2Wire
    case singlePhase3Wire
    case threePhase

    public var displayName: String {
        switch self {
        case .singlePhase2Wire: return "1Ø 2-wire"
        case .singlePhase3Wire: return "1Ø 3-wire"
        case .threePhase: return "3Ø"
        }
    }
}

public enum ReceptacleEnvironment: String, Codable, CaseIterable, Sendable, Hashable {
    case indoorDry
    case damp
    case wetOutdoor
    case washdown
    case hazardous

    public var displayName: String {
        switch self {
        case .indoorDry: return "Indoor dry"
        case .damp: return "Damp"
        case .wetOutdoor: return "Wet / outdoor"
        case .washdown: return "Washdown"
        case .hazardous: return "Hazardous"
        }
    }
}

public enum ReceptacleFamily: String, Codable, CaseIterable, Sendable, Hashable {
    case nemaStraight
    case nemaLocking
    case iec60309
    case internationalHousehold
    case switchedDisconnect

    public var displayName: String {
        switch self {
        case .nemaStraight: return "NEMA straight-blade"
        case .nemaLocking: return "NEMA locking"
        case .iec60309: return "IEC 60309 pin-and-sleeve"
        case .internationalHousehold: return "International household"
        case .switchedDisconnect: return "Switched disconnect (Meltric)"
        }
    }
}

public enum ReceptacleFamilyFilter: String, Codable, CaseIterable, Sendable, Hashable {
    case any
    case straight
    case locking
    case iecPinSleeve
    case household
    case switchedDisconnect

    public var displayName: String {
        switch self {
        case .any: return "Any family"
        case .straight: return "Straight-blade (NEMA)"
        case .locking: return "Locking / twist-lock"
        case .iecPinSleeve: return "IEC 60309"
        case .household: return "International household"
        case .switchedDisconnect: return "Meltric / switched disconnect"
        }
    }

    public func matches(_ family: ReceptacleFamily) -> Bool {
        switch self {
        case .any: return true
        case .straight: return family == .nemaStraight
        case .locking: return family == .nemaLocking
        case .iecPinSleeve: return family == .iec60309
        case .household: return family == .internationalHousehold
        case .switchedDisconnect: return family == .switchedDisconnect
        }
    }
}

public enum NeutralChoice: String, Codable, CaseIterable, Sendable, Hashable {
    case auto
    case none
    case required

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .none: return "No neutral"
        case .required: return "With neutral"
        }
    }
}

public struct ReceptacleQuery: Equatable, Sendable {
    public var volts: Double
    public var phase: ReceptaclePhaseKind
    public var amps: Double
    public var environment: ReceptacleEnvironment
    public var family: ReceptacleFamilyFilter
    public var isolatedGround: Bool
    public var preferGFCI: Bool
    public var frequencyHz: Double
    public var neutral: NeutralChoice

    public init(
        volts: Double,
        phase: ReceptaclePhaseKind,
        amps: Double,
        environment: ReceptacleEnvironment = .indoorDry,
        family: ReceptacleFamilyFilter = .any,
        isolatedGround: Bool = false,
        preferGFCI: Bool = false,
        frequencyHz: Double = 60,
        neutral: NeutralChoice = .auto
    ) {
        self.volts = volts
        self.phase = phase
        self.amps = amps
        self.environment = environment
        self.family = family
        self.isolatedGround = isolatedGround
        self.preferGFCI = preferGFCI
        self.frequencyHz = frequencyHz
        self.neutral = neutral
    }
}

public enum ReceptacleVoltagePreset: String, CaseIterable, Sendable, Hashable {
    case v120 = "120"
    case v208 = "208"
    case v230 = "230"
    case v240 = "240"
    case v277 = "277"
    case v400 = "400"
    case v480 = "480"
    case v600 = "600"
    case custom = "Custom"

    public var volts: Double? {
        switch self {
        case .custom: return nil
        default: return Double(rawValue)
        }
    }
}

public enum ReceptacleAmpPreset: String, CaseIterable, Sendable, Hashable {
    case a10 = "10"
    case a13 = "13"
    case a15 = "15"
    case a16 = "16"
    case a20 = "20"
    case a30 = "30"
    case a32 = "32"
    case a50 = "50"
    case a60 = "60"
    case a63 = "63"
    case a100 = "100"
    case a125 = "125"
    case a150 = "150"
    case a200 = "200"
    case a250 = "250"
    case a300 = "300"
    case a315 = "315"
    case a350 = "350"
    case a400 = "400"
    case custom = "Custom"

    public var amps: Double? {
        switch self {
        case .custom: return nil
        default: return Double(rawValue)
        }
    }
}

// MARK: - Face / pinout (schematic, not manufacturer artwork)

public enum ContactKind: String, Codable, Sendable, Hashable {
    case line1
    case line2
    case line3
    case neutral
    case ground

    public var shortLabel: String {
        switch self {
        case .line1: return "L1"
        case .line2: return "L2"
        case .line3: return "L3"
        case .neutral: return "N"
        case .ground: return "E"
        }
    }

    public var nemaLetter: String {
        switch self {
        case .line1: return "X"
        case .line2: return "Y"
        case .line3: return "Z"
        case .neutral: return "W"
        case .ground: return "G"
        }
    }
}

public enum PinShape: String, Codable, Sendable, Hashable {
    case slotVertical
    case slotHorizontal
    case slotT
    case slotSlantedLeft
    case slotSlantedRight
    case uGround
    case round
    case roundLarge
    /// Schuko (Type F) earth clips at the rim — schematic, not a listing drawing.
    case earthClip
    /// Rectangular pin used on BS 1363 (Type G).
    case slotRect
}

public struct FacePin: Equatable, Sendable, Hashable {
    public var kind: ContactKind
    public var label: String
    /// Degrees from 12 o’clock, clockwise. Used for IEC clock-face drawings.
    public var clockAngle: Double?
    /// Normalized canvas position, origin center, +y up, roughly −1…1.
    public var x: Double
    public var y: Double
    public var shape: PinShape

    public init(
        kind: ContactKind,
        label: String,
        clockAngle: Double? = nil,
        x: Double,
        y: Double,
        shape: PinShape
    ) {
        self.kind = kind
        self.label = label
        self.clockAngle = clockAngle
        self.x = x
        self.y = y
        self.shape = shape
    }
}

public enum FaceKind: String, Codable, Sendable, Hashable {
    case nemaStraight
    case nemaLocking
    case iecClock
    case pinSleeve
    case household
}

public struct FaceDiagram: Equatable, Sendable, Hashable {
    public var kind: FaceKind
    public var pins: [FacePin]
    public var earthHour: Int?
    public var keywayAtSix: Bool
    public var caption: String

    public init(
        kind: FaceKind,
        pins: [FacePin],
        earthHour: Int? = nil,
        keywayAtSix: Bool = false,
        caption: String
    ) {
        self.kind = kind
        self.pins = pins
        self.earthHour = earthHour
        self.keywayAtSix = keywayAtSix
        self.caption = caption
    }
}

// MARK: - Catalog part numbers (only when a public page was cited)

public struct CatalogPartNumber: Equatable, Sendable, Hashable {
    public var maker: String
    public var partNumber: String
    public var note: String
    /// Public catalog or product page. Empty means do not present as verified.
    public var sourceURL: String

    public init(maker: String, partNumber: String, note: String = "", sourceURL: String) {
        self.maker = maker
        self.partNumber = partNumber
        self.note = note
        self.sourceURL = sourceURL
    }
}

public struct ReceptacleConfig: Equatable, Sendable, Identifiable, Hashable {
    public var id: String
    public var code: String
    public var family: ReceptacleFamily
    public var voltsLow: Double
    public var voltsHigh: Double
    public var voltageLabel: String
    public var phase: ReceptaclePhaseKind
    public var poles: Int
    public var wires: Int
    public var hasNeutral: Bool
    public var hasGround: Bool
    public var amps: Double
    public var iecEarthHour: Int?
    public var iecPolesLabel: String?
    public var iecColor: String?
    public var frequencyHz: Double?
    public var face: FaceDiagram
    public var catalog: [CatalogPartNumber]
    public var isolatedGroundCatalog: [CatalogPartNumber]
    public var gfciApplies: Bool

    public var polesWiresLabel: String { "\(poles)P\(wires)W" }

    public var summary: String {
        if family == .iec60309, let poles = iecPolesLabel {
            if let hour = iecEarthHour {
                return "IEC 60309 \(poles) \(FormatAmps.amps(amps)) \(hour)h"
            }
            return "IEC 60309-1 \(poles) \(FormatAmps.amps(amps))"
        }
        return code
    }
}

public struct ReceptacleMatch: Equatable, Sendable, Identifiable {
    public var config: ReceptacleConfig
    public var score: Double
    public var reasons: [String]
    public var caveats: [String]
    public var catalog: [CatalogPartNumber]
    public var catalogFallback: String?

    public var id: String { config.id }
}

/// Locale-free amp formatting for match copy (BeckifyMath has no UI Format helper).
enum FormatAmps {
    /// Whole amps as `15A`; fractional custom loads keep up to two decimals (`12.5A`).
    static func amps(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let nearest = value.rounded()
        if abs(value - nearest) < 1e-9 {
            return "\(Int(nearest))A"
        }
        var formatted = String(format: "%.2f", value)
        while formatted.hasSuffix("0") {
            formatted.removeLast()
        }
        if formatted.hasSuffix(".") {
            formatted.removeLast()
        }
        return "\(formatted)A"
    }
}

// MARK: - IEC 60309-2 clock (Table 210, public summary)

public enum IEC60309 {
    public enum PoleSet: String, CaseIterable, Sendable {
        case twoPlusE = "2P+E"
        case threePlusE = "3P+E"
        case threePlusNE = "3P+N+E"
    }

    /// Earth-contact clock hour for a voltage / pole set, or nil if this table has no row.
    /// Hours are as viewed on the socket with the major keyway at 6 o’clock.
    public static func earthHour(volts: Double, poles: PoleSet, frequencyHz: Double) -> Int? {
        let v = volts
        let hz = frequencyHz
        switch poles {
        case .twoPlusE:
            if v >= 100 && v <= 130 { return 4 }
            if abs(v - 277) <= 12, hz >= 55 { return 5 }
            if v >= 200 && v <= 250 { return 6 }
            if v >= 380 && v <= 415 { return 9 }
            if v >= 460 && v <= 520 { return 7 }
            return nil
        case .threePlusE:
            if v >= 100 && v <= 130 { return 4 }
            if v >= 200 && v <= 250 { return 9 }
            if v >= 380 && v <= 415 { return 6 }
            if v >= 440 && v <= 460, hz >= 55 { return 11 }
            if v >= 461 && v <= 520 { return 7 }
            if v >= 550 && v <= 690 { return 5 }
            return nil
        case .threePlusNE:
            if v >= 100 && v <= 130 { return 4 }
            if v >= 200 && v <= 250 { return 9 }
            if v >= 346 && v <= 415 { return 6 }
            if v >= 460 && v <= 520 { return 7 }
            if v >= 550 && v <= 690 { return 5 }
            return nil
        }
    }

    public static func housingColor(volts: Double) -> String {
        if volts < 50 { return "violet / white (ELV)" }
        if volts <= 130 { return "yellow" }
        if abs(volts - 277) <= 12 { return "grey (NA 277 V)" }
        if volts <= 250 { return "blue" }
        if volts <= 480 { return "red" }
        return "black"
    }
}

// MARK: - Selector

public enum ReceptacleSelector {
    public static let standardVoltages = [120.0, 208, 230, 240, 277, 400, 480, 600]
    public static let standardAmps = [10.0, 13, 15, 16, 20, 30, 32, 50, 60, 63, 100, 125, 150, 200, 250, 300, 315, 350, 400]

    public static var allConfigs: [ReceptacleConfig] { catalog }

    public static func select(_ query: ReceptacleQuery) throws -> [ReceptacleMatch] {
        let volts = try Positive.require(query.volts, name: "Voltage")
        let amps = try Positive.require(query.amps, name: "Current")
        guard volts <= 1000 else {
            throw CalcError.outOfRange("This selector covers utilization voltages through 600 V class, not medium voltage.")
        }
        guard amps <= 400 else {
            throw CalcError.outOfRange("This selector’s tables stop at 400 A. Confirm current catalog above that.")
        }

        var matches: [ReceptacleMatch] = []
        for config in catalog {
            guard query.family.matches(config.family) else { continue }
            guard config.phase == query.phase else { continue }
            guard config.amps + 0.01 >= amps else { continue }
            guard voltageFits(volts, config: config, phase: query.phase, neutral: query.neutral) else { continue }
            if let hz = config.frequencyHz, abs(hz - query.frequencyHz) > 5 { continue }
            if query.neutral == .required && !config.hasNeutral { continue }
            if query.neutral == .none && config.hasNeutral { continue }

            let match = score(config, query: query, volts: volts, amps: amps)
            if match.score > 0 {
                matches.append(match)
            }
        }

        matches.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.config.amps != $1.config.amps { return $0.config.amps < $1.config.amps }
            return $0.config.code < $1.config.code
        }

        if matches.isEmpty {
            throw CalcError.notListed(
                "No NEMA / IEC / household / Meltric row in this table for \(trim(volts)) V \(query.phase.displayName) \(trim(amps)) A. Try another family, poles/neutral, or confirm current catalog."
            )
        }
        return Array(matches.prefix(8))
    }

    /// Public IEC hour used by tests and the live UI.
    public static func iecEarthHour(volts: Double, poles: IEC60309.PoleSet, frequencyHz: Double) -> Int? {
        IEC60309.earthHour(volts: volts, poles: poles, frequencyHz: frequencyHz)
    }
}

// MARK: - Matching internals

extension ReceptacleSelector {
    static func voltageFits(
        _ volts: Double,
        config: ReceptacleConfig,
        phase: ReceptaclePhaseKind,
        neutral: NeutralChoice
    ) -> Bool {
        if volts + 0.5 >= config.voltsLow && volts - 0.5 <= config.voltsHigh {
            return true
        }
        // 208 V line-to-line sits in the 250 V NEMA window (6- and 15-series, IEC 200–250).
        if abs(volts - 208) <= 1, config.voltsLow <= 208, config.voltsHigh >= 240 {
            return phase != .singlePhase3Wire || config.hasNeutral
        }
        // 120 V utilization on a 125 V NEMA class.
        if abs(volts - 120) <= 1, config.voltsLow <= 125, config.voltsHigh >= 120 {
            return true
        }
        // 480 V on a 277/480 wye row only when a neutral is in play.
        if abs(volts - 480) <= 1, config.voltageLabel.contains("277/480") {
            return phase == .threePhase && (neutral == .required || (neutral == .auto && config.hasNeutral))
        }
        return false
    }

    static func score(
        _ config: ReceptacleConfig,
        query: ReceptacleQuery,
        volts: Double,
        amps: Double
    ) -> ReceptacleMatch {
        var score = 0.0
        var reasons: [String] = []
        var caveats: [String] = []

        reasons.append("\(config.voltageLabel) covers \(trim(volts)) V")
        reasons.append("\(config.polesWiresLabel) matches \(query.phase.displayName)\(config.hasNeutral ? " with N" : "")")
        if config.amps == amps || (config.family == .iec60309 && iecDual(config.amps) == iecDual(amps)) {
            score += 50
            reasons.append("\(FormatAmps.amps(config.amps)) device rating")
        } else {
            score += max(15, 40 - (config.amps - amps))
            reasons.append("\(FormatAmps.amps(config.amps)) ≥ \(FormatAmps.amps(amps)) load")
        }

        score += 100
        if query.family != .any && query.family.matches(config.family) {
            score += 25
        }
        // High-amp industrial: Meltric Decontactors are the usual North American answer above NEMA locking.
        if config.family == .switchedDisconnect && amps >= 60 {
            score += 12
        }
        if query.family == .switchedDisconnect && config.family == .switchedDisconnect {
            score += 10
        }

        // Typical North American 3Ø: 480/600 motors are 3P+E; 208Y is 3P+N+E.
        if query.phase == .threePhase {
            if volts >= 440 && !config.hasNeutral { score += 10 }
            if abs(volts - 208) <= 2 && config.hasNeutral { score += 10 }
            if abs(volts - 240) <= 2 && !config.hasNeutral { score += 6 }
        }

        switch query.environment {
        case .indoorDry:
            if config.family == .nemaStraight { score += 16 }
            if config.family == .nemaLocking { score += 12 }
            if config.family == .internationalHousehold { score += 18 }
        case .damp:
            if config.family == .iec60309 || config.family == .switchedDisconnect { score += 10 }
            if config.family == .internationalHousehold {
                score -= 6
                caveats.append("Damp location: household faces need a listed enclosure / IP rating. This app does not pick a weatherproof box.")
            }
            caveats.append("Damp location: use a damp-listed or WR device and a listed cover. This app does not pick a weatherproof box.")
        case .wetOutdoor:
            if config.family == .iec60309 { score += 22 }
            if config.family == .switchedDisconnect { score += 20 }
            if config.family == .nemaStraight || config.family == .nemaLocking || config.family == .internationalHousehold {
                score -= 8
                caveats.append("NEMA / household faces outdoors need a listed weatherproof cover — not selected here.")
            }
        case .washdown:
            if config.family == .iec60309 { score += 24 }
            if config.id.contains("dsn") { score += 8 }
            if config.family == .nemaStraight || config.family == .internationalHousehold { score -= 20 }
            caveats.append("Washdown: prefer a watertight IEC 60309 or Type 4X switch-rated inlet. Confirm IP / Type rating on the listing.")
        case .hazardous:
            score -= 5
            caveats.append("Hazardous location: this is not a classified-area stamp. See the listing (Class/Division or Zone) on a specifically listed fitting — Appleton / Crouse-Hinds / similar. Confirm current catalog.")
        }

        if config.gfciApplies && (query.preferGFCI || query.environment == .damp || query.environment == .wetOutdoor) {
            score += 6
            if config.family == .internationalHousehold {
                caveats.append("Personnel RCD/RCBO often applies on household sockets. This tool does not invent an RCD SKU — specify a listed device.")
            } else {
                caveats.append("GFCI often applies on 125 V receptacles in damp/wet/kitchen/garage locations. Specify a listed GFCI device; this tool does not invent a GFCI SKU.")
            }
        } else if query.preferGFCI && !config.gfciApplies {
            caveats.append("Personnel GFCI is not a standard NEMA/IEC face option at this voltage. Use a listed GFCI breaker or a listed 250 V GFCI product and confirm current catalog.")
        }

        if config.family == .switchedDisconnect, config.id.contains("meltric-dr") {
            caveats.append("Meltric DR is standard-duty pin-and-sleeve — not a switch-rated disconnect. Do not make or break under load. Confirm current catalog.")
        }

        if config.family == .iec60309, config.iecEarthHour == nil {
            caveats.append("IEC 60309-2 clock-face devices typically stop at 125 A. This row is a high-current IEC 60309-1 match — confirm the current manufacturer catalog.")
        }

        if let hour = config.iecEarthHour {
            reasons.append("IEC earth contact at \(hour)h (socket view, keyway at 6 o’clock)")
            if query.frequencyHz == 50, config.frequencyHz == 60 {
                caveats.append("This IEC clock row is 60 Hz (e.g. 277 V 5h). 50 Hz does not use that clock.")
            }
        }

        var catalog = config.catalog
        if query.isolatedGround {
            if !config.isolatedGroundCatalog.isEmpty {
                catalog = config.isolatedGroundCatalog + catalog
                reasons.append("Isolated-ground catalog rows included where a public PN was cited")
            } else {
                caveats.append("Isolated ground requested — no public IG SKU is cited for this face. Confirm current catalog.")
            }
        }

        if catalog.isEmpty {
            return ReceptacleMatch(
                config: config,
                score: score,
                reasons: reasons,
                caveats: caveats,
                catalog: [],
                catalogFallback: "Confirm current catalog — no public part number is cited for this configuration."
            )
        }

        return ReceptacleMatch(
            config: config,
            score: score,
            reasons: reasons,
            caveats: caveats,
            catalog: catalog,
            catalogFallback: nil
        )
    }

    static func iecDual(_ amps: Double) -> Double {
        switch amps {
        case 16, 20: return 20
        case 30, 32: return 32
        case 60, 63: return 63
        case 100, 125: return 125
        case 300, 315: return 315
        default: return amps
        }
    }

    static func trim(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%.1f", value)
    }
}

// MARK: - Face builders

enum ReceptacleFaces {
    static func nema5_15() -> FaceDiagram {
        FaceDiagram(
            kind: .nemaStraight,
            pins: [
                FacePin(kind: .neutral, label: "W", x: -0.32, y: 0.18, shape: .slotVertical),
                FacePin(kind: .line1, label: "X", x: 0.32, y: 0.18, shape: .slotVertical),
                FacePin(kind: .ground, label: "G", x: 0, y: -0.42, shape: .uGround),
            ],
            caption: "NEMA 5-15R socket view — W (N) left, X (hot) right, G down. Schematic, not a listing drawing."
        )
    }

    static func nema5_20() -> FaceDiagram {
        FaceDiagram(
            kind: .nemaStraight,
            pins: [
                FacePin(kind: .neutral, label: "W", x: -0.32, y: 0.18, shape: .slotT),
                FacePin(kind: .line1, label: "X", x: 0.32, y: 0.18, shape: .slotVertical),
                FacePin(kind: .ground, label: "G", x: 0, y: -0.42, shape: .uGround),
            ],
            caption: "NEMA 5-20R socket view — T-slot is W (N). Schematic, not a listing drawing."
        )
    }

    static func nema6_15() -> FaceDiagram {
        FaceDiagram(
            kind: .nemaStraight,
            pins: [
                FacePin(kind: .line1, label: "X", x: -0.32, y: 0.22, shape: .slotHorizontal),
                FacePin(kind: .line2, label: "Y", x: 0.32, y: 0.22, shape: .slotHorizontal),
                FacePin(kind: .ground, label: "G", x: 0, y: -0.42, shape: .uGround),
            ],
            caption: "NEMA 6-15R socket view — two hots, no N. Schematic, not a listing drawing."
        )
    }

    static func nema6_20() -> FaceDiagram {
        FaceDiagram(
            kind: .nemaStraight,
            pins: [
                FacePin(kind: .line1, label: "X", x: -0.32, y: 0.22, shape: .slotT),
                FacePin(kind: .line2, label: "Y", x: 0.32, y: 0.22, shape: .slotHorizontal),
                FacePin(kind: .ground, label: "G", x: 0, y: -0.42, shape: .uGround),
            ],
            caption: "NEMA 6-20R socket view — T-slot + horizontal hot. Schematic, not a listing drawing."
        )
    }

    static func nema14() -> FaceDiagram {
        FaceDiagram(
            kind: .nemaStraight,
            pins: [
                FacePin(kind: .line1, label: "X", x: -0.38, y: 0.28, shape: .slotHorizontal),
                FacePin(kind: .line2, label: "Y", x: 0.38, y: 0.28, shape: .slotHorizontal),
                FacePin(kind: .neutral, label: "W", x: 0.28, y: -0.18, shape: .slotVertical),
                FacePin(kind: .ground, label: "G", x: -0.12, y: -0.42, shape: .uGround),
            ],
            caption: "NEMA 14-series socket view — X/Y hots, W neutral, G. Schematic, not a listing drawing."
        )
    }

    static func nema15() -> FaceDiagram {
        FaceDiagram(
            kind: .nemaStraight,
            pins: [
                FacePin(kind: .line1, label: "X", x: -0.38, y: 0.22, shape: .slotHorizontal),
                FacePin(kind: .line2, label: "Y", x: 0.38, y: 0.22, shape: .slotHorizontal),
                FacePin(kind: .line3, label: "Z", x: 0.0, y: 0.42, shape: .slotVertical),
                FacePin(kind: .ground, label: "G", x: 0, y: -0.42, shape: .uGround),
            ],
            caption: "NEMA 15-series 3Ø socket view — X/Y/Z, G, no N. Schematic, not a listing drawing."
        )
    }

    static func locking(wires: Int, hasNeutral: Bool, hasThirdHot: Bool) -> FaceDiagram {
        var pins: [FacePin] = []
        // Clockwise from ground at 6 o’clock. Labels only — not a WD-6 tracing.
        let ground = FacePin(kind: .ground, label: "G", clockAngle: 180, x: 0, y: -0.55, shape: .roundLarge)
        pins.append(ground)
        if wires == 3 {
            pins.append(FacePin(kind: .line1, label: "X", clockAngle: 300, x: -0.48, y: 0.28, shape: .round))
            pins.append(FacePin(kind: .neutral, label: hasNeutral ? "W" : "Y", clockAngle: 60, x: 0.48, y: 0.28, shape: .round))
            if !hasNeutral {
                pins[2] = FacePin(kind: .line2, label: "Y", clockAngle: 60, x: 0.48, y: 0.28, shape: .round)
            }
        } else if hasThirdHot && hasNeutral {
            pins.append(FacePin(kind: .line1, label: "X", clockAngle: 252, x: -0.52, y: -0.05, shape: .round))
            pins.append(FacePin(kind: .line2, label: "Y", clockAngle: 324, x: -0.22, y: 0.52, shape: .round))
            pins.append(FacePin(kind: .line3, label: "Z", clockAngle: 36, x: 0.48, y: 0.32, shape: .round))
            pins.append(FacePin(kind: .neutral, label: "W", clockAngle: 108, x: 0.42, y: -0.28, shape: .round))
        } else if hasThirdHot {
            pins.append(FacePin(kind: .line1, label: "X", clockAngle: 270, x: -0.55, y: 0.0, shape: .round))
            pins.append(FacePin(kind: .line2, label: "Y", clockAngle: 0, x: 0.0, y: 0.55, shape: .round))
            pins.append(FacePin(kind: .line3, label: "Z", clockAngle: 90, x: 0.55, y: 0.0, shape: .round))
        } else {
            pins.append(FacePin(kind: .line1, label: "X", clockAngle: 270, x: -0.52, y: 0.12, shape: .round))
            pins.append(FacePin(kind: .line2, label: "Y", clockAngle: 0, x: 0.12, y: 0.52, shape: .round))
            pins.append(FacePin(kind: .neutral, label: "W", clockAngle: 90, x: 0.52, y: 0.12, shape: .round))
        }
        return FaceDiagram(
            kind: .nemaLocking,
            pins: pins,
            keywayAtSix: false,
            caption: "NEMA locking socket view — round contacts, G keyed. Schematic, not a listing drawing."
        )
    }

    static func iec(poles: IEC60309.PoleSet, hour: Int) -> FaceDiagram {
        let earthAngle = Double(hour) * 30.0
        func xy(_ angle: Double) -> (Double, Double) {
            let rad = (angle - 90) * .pi / 180
            return (0.58 * cos(rad), -0.58 * sin(rad))
        }
        var pins: [FacePin] = []
        let e = xy(earthAngle)
        pins.append(FacePin(kind: .ground, label: "E", clockAngle: earthAngle, x: e.0, y: e.1, shape: .roundLarge))

        let others: [(ContactKind, String)]
        switch poles {
        case .twoPlusE:
            others = [(.line1, "L"), (.neutral, "N")]
        case .threePlusE:
            others = [(.line1, "L1"), (.line2, "L2"), (.line3, "L3")]
        case .threePlusNE:
            others = [(.line1, "L1"), (.line2, "L2"), (.line3, "L3"), (.neutral, "N")]
        }
        let step = 360.0 / Double(others.count + 1)
        for (i, item) in others.enumerated() {
            let ang = earthAngle + step * Double(i + 1)
            let p = xy(ang)
            pins.append(FacePin(kind: item.0, label: item.1, clockAngle: ang, x: p.0, y: p.1, shape: .round))
        }
        return FaceDiagram(
            kind: .iecClock,
            pins: pins,
            earthHour: hour,
            keywayAtSix: true,
            caption: "IEC 60309-2 socket view — keyway at 6 o’clock, earth at \(hour)h. Relative pin spacing is schematic; confirm terminal markings."
        )
    }

    static func meltric(hasNeutral: Bool, hots: Int) -> FaceDiagram {
        pinSleeve(
            hasNeutral: hasNeutral,
            hots: hots,
            caption: "Switch-rated pin-and-sleeve schematic (Meltric Decontactor). Not manufacturer artwork — confirm terminal markings."
        )
    }

    static func pinSleeve(hasNeutral: Bool, hots: Int, caption: String) -> FaceDiagram {
        var pins: [FacePin] = [
            FacePin(kind: .ground, label: "G", x: 0, y: -0.55, shape: .roundLarge),
        ]
        if hots >= 1 {
            pins.append(FacePin(kind: .line1, label: "L1", x: -0.48, y: 0.2, shape: .round))
        }
        if hots >= 2 {
            pins.append(FacePin(kind: .line2, label: "L2", x: 0.48, y: 0.2, shape: .round))
        }
        if hots >= 3 {
            pins.append(FacePin(kind: .line3, label: "L3", x: 0, y: 0.52, shape: .round))
        }
        if hasNeutral {
            pins.append(FacePin(kind: .neutral, label: "N", x: 0.42, y: -0.22, shape: .round))
        }
        return FaceDiagram(
            kind: .pinSleeve,
            pins: pins,
            caption: caption
        )
    }

    static func householdTypeC() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .line1, label: "L", x: 0.28, y: 0.05, shape: .round),
                FacePin(kind: .neutral, label: "N", x: -0.28, y: 0.05, shape: .round),
            ],
            caption: "Type C / CEE 7/16 Europlug — two round pins, no earth. Schematic, not manufacturer artwork. Typical 2.5 A."
        )
    }

    static func householdSchuko() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .line1, label: "L", x: 0.32, y: 0.02, shape: .round),
                FacePin(kind: .neutral, label: "N", x: -0.32, y: 0.02, shape: .round),
                FacePin(kind: .ground, label: "E", x: 0, y: 0.78, shape: .earthClip),
                FacePin(kind: .ground, label: "E", x: 0, y: -0.78, shape: .earthClip),
            ],
            caption: "Type F Schuko (CEE 7/3) socket view — L/N round, earth clips at the rim. Schematic, not a listing drawing."
        )
    }

    static func householdTypeE() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .line1, label: "L", x: 0.32, y: 0.08, shape: .round),
                FacePin(kind: .neutral, label: "N", x: -0.32, y: 0.08, shape: .round),
                FacePin(kind: .ground, label: "E", x: 0, y: -0.48, shape: .roundLarge),
            ],
            caption: "Type E (CEE 7/5) socket view — earth pin projects from the socket. Schematic, not a listing drawing."
        )
    }

    static func householdBS1363() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .ground, label: "E", x: 0, y: 0.42, shape: .slotRect),
                FacePin(kind: .neutral, label: "N", x: -0.36, y: -0.22, shape: .slotRect),
                FacePin(kind: .line1, label: "L", x: 0.36, y: -0.22, shape: .slotRect),
            ],
            caption: "BS 1363 Type G socket view — E up, N left, L right (UK). Schematic, not a listing drawing. 13 A fused plug."
        )
    }

    static func householdTypeI() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .ground, label: "E", x: 0, y: 0.42, shape: .slotVertical),
                FacePin(kind: .line1, label: "L", x: -0.32, y: -0.28, shape: .slotSlantedLeft),
                FacePin(kind: .neutral, label: "N", x: 0.32, y: -0.28, shape: .slotSlantedRight),
            ],
            caption: "AS/NZS 3112 Type I socket view — earth up, L/N slanted. Schematic, not a listing drawing."
        )
    }

    static func householdTypeJ() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .line1, label: "L", x: 0.30, y: 0.12, shape: .round),
                FacePin(kind: .neutral, label: "N", x: -0.30, y: 0.12, shape: .round),
                FacePin(kind: .ground, label: "E", x: 0, y: -0.42, shape: .round),
            ],
            caption: "SEV 1011 Type J (Switzerland) socket view — three round contacts, earth offset. Schematic, not a listing drawing."
        )
    }

    static func householdTypeK() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .line1, label: "L", x: 0.30, y: 0.10, shape: .round),
                FacePin(kind: .neutral, label: "N", x: -0.30, y: 0.10, shape: .round),
                FacePin(kind: .ground, label: "E", x: 0, y: -0.48, shape: .roundLarge),
            ],
            caption: "Type K (Denmark DS 60884-2-D1) socket view — half-round earth at the bottom. Schematic, not a listing drawing."
        )
    }

    static func householdTypeL() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .line1, label: "L", x: -0.38, y: 0, shape: .round),
                FacePin(kind: .ground, label: "E", x: 0, y: 0, shape: .round),
                FacePin(kind: .neutral, label: "N", x: 0.38, y: 0, shape: .round),
            ],
            caption: "CEI 23-50 Type L socket view — three in a line, earth center. Schematic, not a listing drawing."
        )
    }

    static func householdTypeM() -> FaceDiagram {
        FaceDiagram(
            kind: .household,
            pins: [
                FacePin(kind: .ground, label: "E", x: 0, y: 0.42, shape: .roundLarge),
                FacePin(kind: .line1, label: "L", x: -0.38, y: -0.28, shape: .round),
                FacePin(kind: .neutral, label: "N", x: 0.38, y: -0.28, shape: .round),
            ],
            caption: "BS 546 Type M socket view — large round pins, earth up. Schematic, not a listing drawing."
        )
    }
}

// MARK: - Catalog

extension ReceptacleSelector {
    // Public product pages cited when a PN is attached. Do not invent SKUs.
    private static let hubbellStraight = "https://hubbellcdn.com/catalogpage/WDK_B-11_CatalogPage.pdf"
    private static let hubbell5462 = "https://www.hubbell.com/wiringdevice-kellems/en/products/straight-blade-devices-receptacles-duplex-specification-grade-2-pole-3-wire-grounding-20a-250v-6-20r-brown-single-pack/p/161037"
    private static let hubbell9450 = "https://www.hubbell.com/wiringdevice-kellems/en/products/p/162158"
    private static let hubbellTwist = "https://hubbellcdn.com/literature/EP_WDK_MFG_00069-CANEN-sept2022.pdf"
    private static let hubbellL16 = "https://border-states-assets.azureedge.net/SKU_649253_ATT_Catalog_URL_1.pdf"
    private static let leviton5262 = "https://images.salsify.com/image/upload/s--WmQqNy1H--/1fc1f4e6645dc7cba1e5b1d66ac3619a05f3cbe3.pdf"
    private static let levitonLock = "https://leviton.com/content/dam/leviton/commercial-industrial/product_documents/line-cards/power-solutions-for-data-centers-linecard-ci-q1253A-leviton.pdf"
    private static let leviton2610 = "https://leviton.com/products/2610-r"
    private static let ps5262 = "https://www.legrand.us/p/view-asset?downloadUrl=https%3A%2F%2Flegrand.webdamdb.com%2Fdirectdownload.php%3Fti%3D55654495%26tok%3DmHMNWnqA6PSBAWIy7ovj2ARR&title=Straight+Blade+Receptacles+Heavy-Duty+15+%26+20A%2C+125V+Cutsheet"
    private static let psL630 = "https://www.legrand.us/wiring-devices/plugs-and-connectors/turnlok/turnlok-spec-grade-locking-devices-30a-single-receptacle/p/l630r"
    private static let psL530 = "https://www.legrand.us/wiring-devices/plugs-and-connectors/turnlok/30a-nema-l530-single-receptacle/p/l530r"
    private static let eaton5362 = "https://www.eaton.com/content/dam/eaton/products/wiring-devices-and-connectivity/wiring-devices/nema-straightblade/specification_grade_straight_blade_receptacles-brochure.pdf"
    private static let eatonL630 = "https://www.eaton.com/us/en-us/skuPage.L630R.html"
    private static let hubbell430R6W = "https://www.hubbell.com/wiringdevice-kellems/en/products/heavy-duty-products-iec-pin-and-sleeve-devices-industrial-grade-female-receptacle-3032-a-380-415-vac-4x-and-ip69k/p/2622557"
    private static let hubbellIECDual = "https://hubbellcdn.com/literature/Wiring_WLBP004.pdf"
    private static let hubbell430R7 = "https://evecsa.com/wp-content/uploads/2020/02/Page_G-8-G-19.pdf"
    private static let hubbell530R9 = "https://www.hubbell.com/wiringdevice-kellems/en/products/heavy-duty-products-iec-pin-and-sleeve-devices-industrial-grade-female-receptacle-30a-3-phase-wye-120208v-ac-watertight/p/162443"
    private static let hubbell530R7 = "https://www.hubbell.com/wiringdevice-kellems/en/products/heavy-duty-products-iec-pin-and-sleeve-devices-industrial-grade-female-receptacle-30a-3-phase-wye-277480v-ac-4-pole-5-wire-grounding-watertight/p/162442"
    private static let meltricDS20 = "https://meltric.com/media/contentmanager/content/meltric-catalog-ds20-en.pdf"
    private static let meltricDS30 = "https://meltric.com/media/contentmanager/content/meltric-catalog-ds30-en.pdf"
    private static let meltricDS60 = "https://meltric.com/media/contentmanager/content/meltric-catalog-ds60-en.pdf"
    private static let meltricDS100 = "https://meltric.com/media/contentmanager/content/meltric-catalog-ds100-en.pdf"
    private static let meltricDS200 = "https://meltric.com/media/contentmanager/content/meltric-catalog-ds200-en.pdf"
    private static let meltricDSN20 = "https://meltric.com/media/contentmanager/content/meltric-catalog-dsn20-en.pdf"
    private static let meltricDSN30 = "https://meltric.com/media/contentmanager/content/meltric-catalog-dsn30-en.pdf"
    private static let meltricDSN60 = "https://meltric.com/media/contentmanager/content/meltric-catalog-dsn60-en.pdf"
    private static let meltricDSN100 = "https://meltric.com/media/contentmanager/content/meltric-catalog-dsn100-en.pdf"
    private static let meltricDSN150 = "https://meltric.com/media/contentmanager/content/meltric-catalog-dsn150-en.pdf"
    private static let meltricDR250 = "https://meltric.com/media/contentmanager/content/meltric-catalog-dr250-en.pdf"
    private static let meltricDR400 = "https://meltric.com/media/contentmanager/content/meltric-catalog-dr400-en.pdf"

    static var catalog: [ReceptacleConfig] { nemaStraight + nemaLocking + iecRows + householdRows + meltricRows }

    static var nemaStraight: [ReceptacleConfig] {
        var rows: [ReceptacleConfig] = []
        func add5(_ amps: Double, face: FaceDiagram, catalog: [CatalogPartNumber], ig: [CatalogPartNumber] = []) {
            rows.append(nema(
                code: "5-\(int(amps))R",
                family: .nemaStraight,
                lo: 110, hi: 125, label: "125 V",
                phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: true,
                amps: amps, face: face, catalog: catalog, ig: ig, gfci: true
            ))
        }
        add5(
            15,
            face: ReceptacleFaces.nema5_15(),
            catalog: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "HBL5262", note: "duplex", sourceURL: hubbellStraight),
                CatalogPartNumber(maker: "Leviton", partNumber: "5262", note: "duplex", sourceURL: leviton5262),
                CatalogPartNumber(maker: "Pass & Seymour", partNumber: "5262", note: "duplex", sourceURL: ps5262),
                CatalogPartNumber(maker: "Eaton Arrow Hart", partNumber: "AH5262", note: "duplex", sourceURL: eaton5362),
            ],
            ig: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "IG5262", note: "isolated ground", sourceURL: hubbellStraight),
                CatalogPartNumber(maker: "Leviton", partNumber: "5262-IG", note: "isolated ground", sourceURL: levitonLock),
            ]
        )
        add5(
            20,
            face: ReceptacleFaces.nema5_20(),
            catalog: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "HBL5362", note: "duplex", sourceURL: hubbellStraight),
                CatalogPartNumber(maker: "Leviton", partNumber: "5362", note: "duplex", sourceURL: leviton5262),
                CatalogPartNumber(maker: "Pass & Seymour", partNumber: "5362", note: "duplex", sourceURL: ps5262),
                CatalogPartNumber(maker: "Eaton Arrow Hart", partNumber: "AH5362", note: "duplex", sourceURL: eaton5362),
            ],
            ig: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "IG5362", note: "isolated ground", sourceURL: hubbellStraight),
                CatalogPartNumber(maker: "Leviton", partNumber: "5362-IG", note: "isolated ground", sourceURL: levitonLock),
            ]
        )
        add5(30, face: ReceptacleFaces.nema5_15(), catalog: [])
        add5(50, face: ReceptacleFaces.nema5_15(), catalog: [])

        func add6(_ amps: Double, face: FaceDiagram, catalog: [CatalogPartNumber]) {
            rows.append(nema(
                code: "6-\(int(amps))R",
                family: .nemaStraight,
                lo: 208, hi: 250, label: "250 V",
                phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: false,
                amps: amps, face: face, catalog: catalog, gfci: false
            ))
        }
        add6(15, face: ReceptacleFaces.nema6_15(), catalog: [])
        add6(
            20,
            face: ReceptacleFaces.nema6_20(),
            catalog: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "HBL5462", note: "duplex", sourceURL: hubbell5462),
            ]
        )
        add6(30, face: ReceptacleFaces.nema6_15(), catalog: [])
        add6(50, face: ReceptacleFaces.nema6_15(), catalog: [])

        for a in [15.0, 20, 30, 50, 60] {
            var parts: [CatalogPartNumber] = []
            if a == 50 {
                parts = [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL9450A", note: "single 14-50R", sourceURL: hubbell9450)]
            }
            rows.append(nema(
                code: "14-\(int(a))R",
                family: .nemaStraight,
                lo: 220, hi: 250, label: "125/250 V",
                phase: .singlePhase3Wire, poles: 3, wires: 4, hasN: true,
                amps: a, face: ReceptacleFaces.nema14(), catalog: parts, gfci: false
            ))
        }
        for a in [15.0, 20, 30, 50, 60] {
            rows.append(nema(
                code: "15-\(int(a))R",
                family: .nemaStraight,
                lo: 208, hi: 250, label: "250 V 3Ø",
                phase: .threePhase, poles: 3, wires: 4, hasN: false,
                amps: a, face: ReceptacleFaces.nema15(), catalog: [], gfci: false
            ))
        }
        return rows
    }

    static var nemaLocking: [ReceptacleConfig] {
        var rows: [ReceptacleConfig] = []
        func L(
            _ series: String,
            amps: [Double],
            lo: Double, hi: Double, label: String,
            phase: ReceptaclePhaseKind, poles: Int, wires: Int, hasN: Bool,
            thirdHot: Bool,
            pns: [Double: [CatalogPartNumber]] = [:],
            ig: [Double: [CatalogPartNumber]] = [:]
        ) {
            for a in amps {
                rows.append(nema(
                    code: "L\(series)-\(int(a))R",
                    family: .nemaLocking,
                    lo: lo, hi: hi, label: label,
                    phase: phase, poles: poles, wires: wires, hasN: hasN,
                    amps: a,
                    face: ReceptacleFaces.locking(wires: wires, hasNeutral: hasN, hasThirdHot: thirdHot),
                    catalog: pns[a] ?? [],
                    ig: ig[a] ?? [],
                    gfci: series == "5"
                ))
            }
        }

        L("5", amps: [15, 20, 30], lo: 110, hi: 125, label: "125 V",
          phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: true, thirdHot: false,
          pns: [
            20: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2310", note: "flush", sourceURL: hubbellTwist),
                CatalogPartNumber(maker: "Leviton", partNumber: "2310", note: "", sourceURL: levitonLock),
            ],
            30: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2610", note: "flush", sourceURL: hubbellTwist),
                CatalogPartNumber(maker: "Leviton", partNumber: "2610", note: "", sourceURL: leviton2610),
                CatalogPartNumber(maker: "Pass & Seymour", partNumber: "L530R", note: "Turnlok", sourceURL: psL530),
            ],
          ],
          ig: [
            30: [CatalogPartNumber(maker: "Leviton", partNumber: "2610-IG", note: "isolated ground", sourceURL: levitonLock)],
          ])

        L("6", amps: [15, 20, 30], lo: 208, hi: 250, label: "250 V",
          phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: false, thirdHot: false,
          pns: [
            20: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2320", note: "flush", sourceURL: hubbellTwist),
                CatalogPartNumber(maker: "Leviton", partNumber: "2320", note: "", sourceURL: levitonLock),
            ],
            30: [
                CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2620", note: "flush", sourceURL: hubbellTwist),
                CatalogPartNumber(maker: "Leviton", partNumber: "2620", note: "", sourceURL: levitonLock),
                CatalogPartNumber(maker: "Pass & Seymour", partNumber: "L630R", note: "Turnlok", sourceURL: psL630),
                CatalogPartNumber(maker: "Eaton Arrow Hart", partNumber: "L630R", note: "", sourceURL: eatonL630),
            ],
          ],
          ig: [
            30: [CatalogPartNumber(maker: "Leviton", partNumber: "2620-IG", note: "isolated ground", sourceURL: levitonLock)],
          ])

        L("7", amps: [15, 20, 30], lo: 265, hi: 277, label: "277 V",
          phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: true, thirdHot: false,
          pns: [
            20: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2330", note: "flush L7-20R", sourceURL: hubbellTwist)],
            30: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2630", note: "flush L7-30R", sourceURL: hubbellTwist)],
          ])

        L("8", amps: [20, 30], lo: 440, hi: 480, label: "480 V",
          phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: false, thirdHot: false)

        L("9", amps: [20, 30], lo: 550, hi: 600, label: "600 V",
          phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: false, thirdHot: false)

        L("14", amps: [20, 30], lo: 220, hi: 250, label: "125/250 V",
          phase: .singlePhase3Wire, poles: 3, wires: 4, hasN: true, thirdHot: false,
          pns: [
            20: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2410", note: "flush", sourceURL: hubbellTwist)],
            30: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2710", note: "flush", sourceURL: hubbellTwist)],
          ])

        L("15", amps: [20, 30, 50], lo: 208, hi: 250, label: "250 V 3Ø",
          phase: .threePhase, poles: 3, wires: 4, hasN: false, thirdHot: true,
          pns: [
            20: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2420", note: "flush", sourceURL: hubbellTwist)],
            30: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2720", note: "flush", sourceURL: hubbellTwist)],
          ])

        L("16", amps: [20, 30], lo: 440, hi: 480, label: "480 V 3Ø",
          phase: .threePhase, poles: 3, wires: 4, hasN: false, thirdHot: true,
          pns: [
            20: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2430", note: "flush L16-20R", sourceURL: hubbellTwist)],
            30: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2730", note: "flush L16-30R", sourceURL: hubbellL16)],
          ])

        L("17", amps: [30], lo: 550, hi: 600, label: "600 V 3Ø",
          phase: .threePhase, poles: 3, wires: 4, hasN: false, thirdHot: true,
          pns: [
            30: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2740", note: "flush L17-30R", sourceURL: hubbellL16)],
          ])

        L("21", amps: [20, 30], lo: 200, hi: 208, label: "120/208 V 3ØY",
          phase: .threePhase, poles: 4, wires: 5, hasN: true, thirdHot: true,
          pns: [
            20: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2510", note: "flush L21-20R", sourceURL: hubbellTwist)],
            30: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2810", note: "flush L21-30R", sourceURL: hubbellTwist)],
          ])

        L("22", amps: [20, 30], lo: 460, hi: 480, label: "277/480 V 3ØY",
          phase: .threePhase, poles: 4, wires: 5, hasN: true, thirdHot: true,
          pns: [
            20: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2520", note: "flush L22-20R", sourceURL: hubbellTwist)],
            30: [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL2820", note: "flush L22-30R", sourceURL: hubbellTwist)],
          ])

        L("23", amps: [20, 30], lo: 550, hi: 600, label: "347/600 V 3ØY",
          phase: .threePhase, poles: 4, wires: 5, hasN: true, thirdHot: true)

        return rows
    }

    static var iecRows: [ReceptacleConfig] {
        let ampsList = [16.0, 20, 30, 32, 60, 63, 100, 125]
        var rows: [ReceptacleConfig] = []

        struct IECFace {
            var poles: IEC60309.PoleSet
            var phase: ReceptaclePhaseKind
            var hasN: Bool
            var poleCount: Int
            var wireCount: Int
            var hour: Int
            var lo: Double
            var hi: Double
            var label: String
            var color: String
            var freq: Double?
        }

        let faces: [IECFace] = [
            IECFace(poles: .twoPlusE, phase: .singlePhase2Wire, hasN: true, poleCount: 2, wireCount: 3, hour: 4, lo: 100, hi: 130, label: "100–130 V", color: "yellow", freq: nil),
            IECFace(poles: .twoPlusE, phase: .singlePhase2Wire, hasN: true, poleCount: 2, wireCount: 3, hour: 6, lo: 200, hi: 250, label: "200–250 V", color: "blue", freq: nil),
            IECFace(poles: .twoPlusE, phase: .singlePhase2Wire, hasN: true, poleCount: 2, wireCount: 3, hour: 5, lo: 265, hi: 277, label: "277 V", color: "grey", freq: 60),
            IECFace(poles: .twoPlusE, phase: .singlePhase2Wire, hasN: false, poleCount: 2, wireCount: 3, hour: 7, lo: 460, hi: 500, label: "480–500 V", color: "red", freq: nil),
            IECFace(poles: .threePlusE, phase: .threePhase, hasN: false, poleCount: 3, wireCount: 4, hour: 9, lo: 200, hi: 250, label: "200–250 V 3Ø", color: "blue", freq: nil),
            IECFace(poles: .threePlusE, phase: .threePhase, hasN: false, poleCount: 3, wireCount: 4, hour: 6, lo: 380, hi: 415, label: "380–415 V 3Ø", color: "red", freq: nil),
            IECFace(poles: .threePlusE, phase: .threePhase, hasN: false, poleCount: 3, wireCount: 4, hour: 7, lo: 460, hi: 500, label: "480–500 V 3Ø", color: "red", freq: nil),
            IECFace(poles: .threePlusE, phase: .threePhase, hasN: false, poleCount: 3, wireCount: 4, hour: 5, lo: 550, hi: 690, label: "600–690 V 3Ø", color: "black", freq: nil),
            IECFace(poles: .threePlusNE, phase: .threePhase, hasN: true, poleCount: 4, wireCount: 5, hour: 9, lo: 200, hi: 250, label: "120/208–144/250 V 3ØY", color: "blue", freq: nil),
            IECFace(poles: .threePlusNE, phase: .threePhase, hasN: true, poleCount: 4, wireCount: 5, hour: 6, lo: 346, hi: 415, label: "200/346–240/415 V 3ØY", color: "red", freq: nil),
            IECFace(poles: .threePlusNE, phase: .threePhase, hasN: true, poleCount: 4, wireCount: 5, hour: 7, lo: 460, hi: 500, label: "277/480–288/500 V 3ØY", color: "red", freq: nil),
            IECFace(poles: .threePlusNE, phase: .threePhase, hasN: true, poleCount: 4, wireCount: 5, hour: 5, lo: 550, hi: 690, label: "347/600–400/690 V 3ØY", color: "black", freq: nil),
        ]

        for a in ampsList {
            for face in faces {
                let id = "iec-\(face.poles.rawValue)-\(int(a))A-\(face.hour)h"
                let code = "IEC 60309 \(face.poles.rawValue) \(int(a))A \(face.hour)h"
                rows.append(ReceptacleConfig(
                    id: id,
                    code: code,
                    family: .iec60309,
                    voltsLow: face.lo,
                    voltsHigh: face.hi,
                    voltageLabel: face.label,
                    phase: face.phase,
                    poles: face.poleCount,
                    wires: face.wireCount,
                    hasNeutral: face.hasN,
                    hasGround: true,
                    amps: a,
                    iecEarthHour: face.hour,
                    iecPolesLabel: face.poles.rawValue,
                    iecColor: face.color,
                    frequencyHz: face.freq,
                    face: ReceptacleFaces.iec(poles: face.poles, hour: face.hour),
                    catalog: iecParts(poles: face.poles, amps: a, hour: face.hour),
                    isolatedGroundCatalog: [],
                    gfciApplies: face.lo <= 130
                ))
            }
        }

        // IEC 60309-1 preferred high-current steps. Clock-face (60309-2) typically stops at 125 A.
        // No SKUs — manufacturer high-current catalogs differ. Dual 300/315 as published industrially.
        let highCurrent = [200.0, 250, 315, 400]
        for a in highCurrent {
            for face in faces {
                let id = "iec-hc-\(face.poles.rawValue)-\(int(a))A-\(int(face.lo))v"
                let code = "IEC 60309-1 \(face.poles.rawValue) \(int(a))A \(face.label)"
                rows.append(ReceptacleConfig(
                    id: id,
                    code: code,
                    family: .iec60309,
                    voltsLow: face.lo,
                    voltsHigh: face.hi,
                    voltageLabel: face.label,
                    phase: face.phase,
                    poles: face.poleCount,
                    wires: face.wireCount,
                    hasNeutral: face.hasN,
                    hasGround: true,
                    amps: a,
                    iecEarthHour: nil,
                    iecPolesLabel: face.poles.rawValue,
                    iecColor: face.color,
                    frequencyHz: face.freq,
                    face: ReceptacleFaces.pinSleeve(
                        hasNeutral: face.hasN,
                        hots: face.poleCount >= 3 ? 3 : (face.hasN ? 1 : 2),
                        caption: "IEC 60309-1 high-current pin-and-sleeve schematic. Clock-face 60309-2 typically stops at 125 A. Confirm terminal markings and current catalog."
                    ),
                    catalog: [],
                    isolatedGroundCatalog: [],
                    gfciApplies: false
                ))
            }
        }
        return rows
    }

    static func iecParts(poles: IEC60309.PoleSet, amps: Double, hour: Int) -> [CatalogPartNumber] {
        // Only attach Hubbell PNs seen on a public catalog page.
        if poles == .threePlusE, (amps == 30 || amps == 32) {
            switch hour {
            case 6:
                return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL430R6W", note: "watertight 30/32 A 3P+E 6h", sourceURL: hubbell430R6W)]
            case 9:
                return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL430R9W", note: "watertight 30 A 3P+E 9h", sourceURL: hubbellIECDual)]
            case 7:
                return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL430R7W", note: "watertight 30 A 3P+E 7h", sourceURL: hubbell430R7)]
            case 5:
                return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL430R5W", note: "watertight 30 A 3P+E 5h", sourceURL: hubbell430R7)]
            default: break
            }
        }
        if poles == .twoPlusE, (amps == 30 || amps == 32), hour == 6 {
            return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL330R6W", note: "watertight 30/32 A 2P+E 6h", sourceURL: hubbellIECDual)]
        }
        if poles == .threePlusNE, (amps == 30 || amps == 32) {
            switch hour {
            case 9:
                return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL530R9W", note: "watertight 30 A 3P+N+E 9h", sourceURL: hubbell530R9)]
            case 7:
                return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL530R7W", note: "watertight 30 A 3P+N+E 7h", sourceURL: hubbell530R7)]
            default: break
            }
        }
        if poles == .threePlusE, (amps == 60 || amps == 63) {
            switch hour {
            case 6:
                return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL460R6W", note: "watertight 60/63 A 3P+E 6h", sourceURL: hubbellIECDual)]
            case 9:
                return [CatalogPartNumber(maker: "Hubbell", partNumber: "HBL460R9W", note: "watertight 60/63 A 3P+E 9h", sourceURL: hubbellIECDual)]
            default: break
            }
        }
        return []
    }

    static var householdRows: [ReceptacleConfig] {
        func row(
            id: String,
            code: String,
            lo: Double, hi: Double, label: String,
            amps: Double,
            face: FaceDiagram,
            poles: Int = 2,
            wires: Int = 3,
            hasN: Bool = true
        ) -> ReceptacleConfig {
            ReceptacleConfig(
                id: id,
                code: code,
                family: .internationalHousehold,
                voltsLow: lo,
                voltsHigh: hi,
                voltageLabel: label,
                phase: .singlePhase2Wire,
                poles: poles,
                wires: wires,
                hasNeutral: hasN,
                hasGround: wires >= 3,
                amps: amps,
                iecEarthHour: nil,
                iecPolesLabel: nil,
                iecColor: nil,
                frequencyHz: nil,
                face: face,
                catalog: [],
                isolatedGroundCatalog: [],
                gfciApplies: true
            )
        }

        return [
            row(
                id: "hh-type-c-europlug",
                code: "Type C (CEE 7/16 Europlug)",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 2.5,
                face: ReceptacleFaces.householdTypeC(),
                wires: 2, hasN: true
            ),
            row(
                id: "hh-type-f-schuko",
                code: "Type F Schuko (CEE 7/3)",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 16,
                face: ReceptacleFaces.householdSchuko()
            ),
            row(
                id: "hh-type-e-french",
                code: "Type E (CEE 7/5)",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 16,
                face: ReceptacleFaces.householdTypeE()
            ),
            row(
                id: "hh-type-g-bs1363",
                code: "Type G BS 1363",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 13,
                face: ReceptacleFaces.householdBS1363()
            ),
            row(
                id: "hh-type-i-10",
                code: "Type I AS/NZS 3112 10 A",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 10,
                face: ReceptacleFaces.householdTypeI()
            ),
            row(
                id: "hh-type-i-15",
                code: "Type I AS/NZS 3112 15 A",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 15,
                face: ReceptacleFaces.householdTypeI()
            ),
            row(
                id: "hh-type-j-sev",
                code: "Type J SEV 1011",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 10,
                face: ReceptacleFaces.householdTypeJ()
            ),
            row(
                id: "hh-type-k-dk",
                code: "Type K (DS 60884-2-D1)",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 16,
                face: ReceptacleFaces.householdTypeK()
            ),
            row(
                id: "hh-type-l-10",
                code: "Type L CEI 23-50 10 A",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 10,
                face: ReceptacleFaces.householdTypeL()
            ),
            row(
                id: "hh-type-l-16",
                code: "Type L CEI 23-50 16 A",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 16,
                face: ReceptacleFaces.householdTypeL()
            ),
            row(
                id: "hh-type-m-bs546",
                code: "Type M BS 546 15 A",
                lo: 220, hi: 250, label: "220–250 V",
                amps: 15,
                face: ReceptacleFaces.householdTypeM()
            ),
        ]
    }

    static var meltricRows: [ReceptacleConfig] {
        func row(
            id: String,
            code: String,
            lo: Double, hi: Double, label: String,
            phase: ReceptaclePhaseKind, poles: Int, wires: Int, hasN: Bool, hots: Int,
            amps: Double,
            parts: [CatalogPartNumber]
        ) -> ReceptacleConfig {
            ReceptacleConfig(
                id: id,
                code: code,
                family: .switchedDisconnect,
                voltsLow: lo,
                voltsHigh: hi,
                voltageLabel: label,
                phase: phase,
                poles: poles,
                wires: wires,
                hasNeutral: hasN,
                hasGround: true,
                amps: amps,
                iecEarthHour: nil,
                iecPolesLabel: nil,
                iecColor: nil,
                frequencyHz: nil,
                face: ReceptacleFaces.meltric(hasNeutral: hasN, hots: hots),
                catalog: parts,
                isolatedGroundCatalog: [],
                gfciApplies: lo <= 130
            )
        }

        struct MeltricFace {
            var key: String
            var polesLabel: String
            var configCode: String
            var lo: Double
            var hi: Double
            var label: String
            var phase: ReceptaclePhaseKind
            var poles: Int
            var wires: Int
            var hasN: Bool
            var hots: Int
            var voltsTag: String
        }

        // North American UL/CSA grid published on DS / DSN series catalog pages.
        let faces: [MeltricFace] = [
            MeltricFace(key: "1P+N+G-120", polesLabel: "1P+N+G", configCode: "165", lo: 110, hi: 120, label: "120 V", phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: true, hots: 1, voltsTag: "120 V"),
            MeltricFace(key: "3P+N+G-208", polesLabel: "3P+N+G", configCode: "167", lo: 200, hi: 208, label: "120/208 V 3ØY", phase: .threePhase, poles: 4, wires: 5, hasN: true, hots: 3, voltsTag: "208 V"),
            MeltricFace(key: "1P+N+G-125", polesLabel: "1P+N+G", configCode: "075", lo: 110, hi: 125, label: "125 V", phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: true, hots: 1, voltsTag: "125 V"),
            MeltricFace(key: "2P+N+G-250", polesLabel: "2P+N+G", configCode: "076", lo: 220, hi: 250, label: "125/250 V", phase: .singlePhase3Wire, poles: 3, wires: 4, hasN: true, hots: 2, voltsTag: "250 V"),
            MeltricFace(key: "2P+G-208", polesLabel: "2P+G", configCode: "162", lo: 200, hi: 220, label: "208 V", phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: false, hots: 2, voltsTag: "208 V"),
            MeltricFace(key: "3P+G-208", polesLabel: "3P+G", configCode: "163", lo: 200, hi: 220, label: "208 V 3Ø", phase: .threePhase, poles: 3, wires: 4, hasN: false, hots: 3, voltsTag: "208 V"),
            MeltricFace(key: "2P+G-250", polesLabel: "2P+G", configCode: "072", lo: 220, hi: 250, label: "250 V", phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: false, hots: 2, voltsTag: "250 V"),
            MeltricFace(key: "3P+G-250", polesLabel: "3P+G", configCode: "073", lo: 208, hi: 250, label: "250 V 3Ø", phase: .threePhase, poles: 3, wires: 4, hasN: false, hots: 3, voltsTag: "250 V"),
            MeltricFace(key: "1P+N+G-277", polesLabel: "1P+N+G", configCode: "045", lo: 265, hi: 277, label: "277 V", phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: true, hots: 1, voltsTag: "277 V"),
            MeltricFace(key: "3P+N+G-480", polesLabel: "3P+N+G", configCode: "047", lo: 460, hi: 480, label: "277/480 V 3ØY", phase: .threePhase, poles: 4, wires: 5, hasN: true, hots: 3, voltsTag: "480 V"),
            MeltricFace(key: "3P+N+G-600", polesLabel: "3P+N+G", configCode: "147", lo: 550, hi: 600, label: "347/600 V 3ØY", phase: .threePhase, poles: 4, wires: 5, hasN: true, hots: 3, voltsTag: "600 V"),
            MeltricFace(key: "2P+G-480", polesLabel: "2P+G", configCode: "042", lo: 440, hi: 480, label: "480 V", phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: false, hots: 2, voltsTag: "480 V"),
            MeltricFace(key: "3P+G-480", polesLabel: "3P+G", configCode: "043", lo: 440, hi: 480, label: "480 V 3Ø", phase: .threePhase, poles: 3, wires: 4, hasN: false, hots: 3, voltsTag: "480 V"),
            MeltricFace(key: "2P+G-600", polesLabel: "2P+G", configCode: "142", lo: 550, hi: 600, label: "600 V", phase: .singlePhase2Wire, poles: 2, wires: 3, hasN: false, hots: 2, voltsTag: "600 V"),
            MeltricFace(key: "3P+G-600", polesLabel: "3P+G", configCode: "143", lo: 550, hi: 600, label: "600 V 3Ø", phase: .threePhase, poles: 3, wires: 4, hasN: false, hots: 3, voltsTag: "600 V"),
        ]

        struct Series {
            var slug: String
            var name: String
            var amps: Double
            var prefix: String
            var ampDigit: String
            var url: String
            var note: String
            /// DSN20 120/208 rows use different suffixes + -K16 on the public page.
            var configOverride: [String: String] = [:]
        }

        let seriesList: [Series] = [
            Series(slug: "ds20", name: "DS20", amps: 20, prefix: "33", ampDigit: "1", url: meltricDS20, note: "DS20 receptacle"),
            Series(slug: "ds30", name: "DS30", amps: 30, prefix: "33", ampDigit: "3", url: meltricDS30, note: "DS30 receptacle"),
            Series(slug: "ds60", name: "DS60", amps: 60, prefix: "33", ampDigit: "6", url: meltricDS60, note: "DS60 receptacle"),
            Series(slug: "ds100", name: "DS100", amps: 100, prefix: "33", ampDigit: "9", url: meltricDS100, note: "DS100 receptacle"),
            Series(slug: "ds200", name: "DS200", amps: 200, prefix: "37", ampDigit: "2", url: meltricDS200, note: "DS200 metal receptacle"),
            Series(
                slug: "dsn20", name: "DSN20", amps: 20, prefix: "63", ampDigit: "1", url: meltricDSN20, note: "DSN20 Type 4X receptacle",
                configOverride: [
                    "165": "125-K16",
                    "167": "127-K16",
                    "162": "122-K16",
                    "163": "123-K16",
                ]
            ),
            Series(slug: "dsn30", name: "DSN30", amps: 30, prefix: "63", ampDigit: "3", url: meltricDSN30, note: "DSN30 Type 4X receptacle"),
            Series(slug: "dsn60", name: "DSN60", amps: 60, prefix: "63", ampDigit: "6", url: meltricDSN60, note: "DSN60 Type 4X receptacle"),
            Series(slug: "dsn100", name: "DSN100", amps: 100, prefix: "63", ampDigit: "8", url: meltricDSN100, note: "DSN100 Type 4X receptacle"),
            Series(slug: "dsn150", name: "DSN150", amps: 150, prefix: "63", ampDigit: "9", url: meltricDSN150, note: "DSN150 Type 4X receptacle"),
        ]

        var rows: [ReceptacleConfig] = []
        for series in seriesList {
            for face in faces {
                let body = series.configOverride[face.configCode] ?? face.configCode
                let pn = "\(series.prefix)-\(series.ampDigit)4\(body)"
                rows.append(row(
                    id: "meltric-\(series.slug)-\(face.key)",
                    code: "Meltric \(series.name) \(face.polesLabel) \(face.voltsTag)",
                    lo: face.lo, hi: face.hi, label: face.label,
                    phase: face.phase, poles: face.poles, wires: face.wires, hasN: face.hasN, hots: face.hots,
                    amps: series.amps,
                    parts: [CatalogPartNumber(maker: "Meltric", partNumber: pn, note: series.note, sourceURL: series.url)]
                ))
            }
        }

        // DR250 / DR400 — related high-amp series. PNs only as printed (suffixes included).
        let dr250: [(String, String, Double, Double, String, ReceptaclePhaseKind, Int, Int, Bool, Int, String)] = [
            ("1P+N+G-125", "1P+N+G", 110, 125, "125 V", .singlePhase2Wire, 2, 3, true, 1, "39-24035-K07"),
            ("2P+N+G-250", "2P+N+G", 220, 250, "125/250 V", .singlePhase3Wire, 3, 4, true, 2, "39-24036-K07"),
            ("2P+G-208", "2P+G", 200, 220, "208 V", .singlePhase2Wire, 2, 3, false, 2, "39-24232-K16"),
            ("3P+G-208", "3P+G", 200, 220, "208 V 3Ø", .threePhase, 3, 4, false, 3, "39-24233-K16"),
            ("2P+G-250", "2P+G", 220, 250, "250 V", .singlePhase2Wire, 2, 3, false, 2, "39-24032-K07"),
            ("3P+G-250", "3P+G", 208, 250, "250 V 3Ø", .threePhase, 3, 4, false, 3, "39-24033-K07"),
            ("1P+N+G-277", "1P+N+G", 265, 277, "277 V", .singlePhase2Wire, 2, 3, true, 1, "39-24245-K04"),
            ("3P+N+G-480", "3P+N+G", 460, 480, "277/480 V 3ØY", .threePhase, 4, 5, true, 3, "39-24247-K04"),
            ("3P+N+G-600", "3P+N+G", 550, 600, "347/600 V 3ØY", .threePhase, 4, 5, true, 3, "39-24027-K14"),
            ("2P+G-480", "2P+G", 440, 480, "480 V", .singlePhase2Wire, 2, 3, false, 2, "39-24242-K04"),
            ("3P+G-480", "3P+G", 440, 480, "480 V 3Ø", .threePhase, 3, 4, false, 3, "39-24243-K04"),
            ("2P+G-600", "2P+G", 550, 600, "600 V", .singlePhase2Wire, 2, 3, false, 2, "39-24022-K14"),
            ("3P+G-600", "3P+G", 550, 600, "600 V 3Ø", .threePhase, 3, 4, false, 3, "39-24023-K14"),
        ]
        for item in dr250 {
            let voltsTag = item.4.replacingOccurrences(of: " 3ØY", with: "").replacingOccurrences(of: " 3Ø", with: "")
            rows.append(row(
                id: "meltric-dr250-\(item.0)",
                code: "Meltric DR250 \(item.1) \(voltsTag)",
                lo: item.2, hi: item.3, label: item.4,
                phase: item.5, poles: item.6, wires: item.7, hasN: item.8, hots: item.9,
                amps: 250,
                parts: [CatalogPartNumber(maker: "Meltric", partNumber: item.10, note: "DR250 receptacle (not switch-rated)", sourceURL: meltricDR250)]
            ))
        }

        let dr400: [(String, String, Double, Double, String, String)] = [
            ("3P+G-208", "208 V 3Ø", 200, 220, "39-44163-172", "208 V"),
            ("3P+G-250", "250 V 3Ø", 208, 250, "39-44073-172", "250 V"),
            ("3P+G-480", "480 V 3Ø", 440, 480, "39-44043-172", "480 V"),
            ("3P+G-600", "600 V 3Ø", 550, 600, "39-44143-172", "600 V"),
        ]
        for item in dr400 {
            rows.append(row(
                id: "meltric-dr400-\(item.0)",
                code: "Meltric DR400 3P+G \(item.5)",
                lo: item.2, hi: item.3, label: item.1,
                phase: .threePhase, poles: 3, wires: 4, hasN: false, hots: 3,
                amps: 400,
                parts: [CatalogPartNumber(maker: "Meltric", partNumber: item.4, note: "DR400 3P+G + 2 pilot (as listed)", sourceURL: meltricDR400)]
            ))
        }

        return rows
    }

    static func nema(
        code: String,
        family: ReceptacleFamily,
        lo: Double, hi: Double, label: String,
        phase: ReceptaclePhaseKind, poles: Int, wires: Int, hasN: Bool,
        amps: Double, face: FaceDiagram,
        catalog: [CatalogPartNumber],
        ig: [CatalogPartNumber] = [],
        gfci: Bool
    ) -> ReceptacleConfig {
        ReceptacleConfig(
            id: "nema-\(code)",
            code: code,
            family: family,
            voltsLow: lo,
            voltsHigh: hi,
            voltageLabel: label,
            phase: phase,
            poles: poles,
            wires: wires,
            hasNeutral: hasN,
            hasGround: true,
            amps: amps,
            iecEarthHour: nil,
            iecPolesLabel: nil,
            iecColor: nil,
            frequencyHz: nil,
            face: face,
            catalog: catalog,
            isolatedGroundCatalog: ig,
            gfciApplies: gfci
        )
    }

    static func int(_ amps: Double) -> Int { Int(amps.rounded()) }
}
