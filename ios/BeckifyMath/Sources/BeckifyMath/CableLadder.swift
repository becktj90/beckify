import Foundation

/// Cable-tray planning: NEC Article 392 fill, a NEMA VE 1-style hanger check,
/// and field notes for the box, the conduit drop, and the cable type.
///
/// Numbers transcribed from published tables are labeled. A width between
/// published rows is linear interpolation. A width outside the published
/// range is extrapolated and cannot earn a clean pass. This is a design aid —
/// confirm the code book, the manufacturer load table, and the AHJ.
public enum CableLadderTrayType: String, Codable, CaseIterable, Sendable, Hashable {
    case ladder
    case ventilated
    case solidBottom
    case channel

    public var displayName: String {
        switch self {
        case .ladder: return "Ladder"
        case .ventilated: return "Ventilated trough"
        case .solidBottom: return "Solid bottom"
        case .channel: return "Ventilated channel"
        }
    }

    public var hasRungs: Bool {
        self == .ladder || self == .ventilated
    }
}

public enum CableLadderCover: String, Codable, CaseIterable, Sendable, Hashable {
    case none
    case ventilated
    case solid

    public var displayName: String {
        switch self {
        case .none: return "No cover"
        case .ventilated: return "Ventilated cover"
        case .solid: return "Solid cover"
        }
    }
}

public enum CableLadderContents: String, Codable, CaseIterable, Sendable, Hashable {
    case singleConductor
    case multiconductorMixed
    case controlSignalOnly

    public var displayName: String {
        switch self {
        case .singleConductor: return "Single conductors"
        case .multiconductorMixed: return "Multiconductor, power or mixed"
        case .controlSignalOnly: return "Control and signal only"
        }
    }
}

/// Where the tray is mounted. Drives the NEMA 250 box note and the conduit drop.
/// These are planning picks from the Reference Library, not a listing.
public enum CableLadderEnvironment: String, Codable, CaseIterable, Sendable, Hashable {
    case indoorDry
    case indoorDustDrip
    case outdoorRain
    case washdown
    case corrosive

    public var displayName: String {
        switch self {
        case .indoorDry: return "Indoor, dry"
        case .indoorDustDrip: return "Indoor, dust and drip"
        case .outdoorRain: return "Outdoor, rain"
        case .washdown: return "Wash-down"
        case .corrosive: return "Corrosive or coastal"
        }
    }

    public var wantsWetListing: Bool {
        switch self {
        case .outdoorRain, .washdown, .corrosive: return true
        case .indoorDry, .indoorDustDrip: return false
        }
    }
}

public enum CableLadderOrientation: String, Codable, CaseIterable, Sendable, Hashable {
    case horizontal
    case vertical

    public var displayName: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        }
    }
}

public enum CableLadderRailMaterial: String, Codable, CaseIterable, Sendable, Hashable {
    case steel
    case aluminum

    public var displayName: String {
        switch self {
        case .steel: return "Steel"
        case .aluminum: return "Aluminum"
        }
    }
}

/// Distribution color names from Reference Library → Conductor Colors.
/// A legend only — tray cable is often black.
public enum CableLadderColorSystem: String, Codable, CaseIterable, Sendable, Hashable {
    case low120
    case high277

    public var displayName: String {
        switch self {
        case .low120: return "120/208 V — black, red, blue"
        case .high277: return "277/480 V — brown, orange, yellow"
        }
    }

    public var systemTitle: String {
        switch self {
        case .low120: return "120/208 V"
        case .high277: return "277/480 V"
        }
    }
}

public enum CableLadderCableRole: String, Codable, CaseIterable, Sendable, Hashable {
    case phaseA
    case phaseB
    case phaseC
    case neutral
    case egc
    case control
    case signal
    case unmarked

    public var displayName: String {
        switch self {
        case .phaseA: return "Phase A"
        case .phaseB: return "Phase B"
        case .phaseC: return "Phase C"
        case .neutral: return "Neutral"
        case .egc: return "EGC"
        case .control: return "Control"
        case .signal: return "Signal"
        case .unmarked: return "Unmarked"
        }
    }

    public var letter: String {
        switch self {
        case .phaseA: return "A"
        case .phaseB: return "B"
        case .phaseC: return "C"
        case .neutral: return "N"
        case .egc: return "G"
        case .control: return "CTL"
        case .signal: return "SIG"
        case .unmarked: return ""
        }
    }

    public var isPowerIdentification: Bool {
        switch self {
        case .phaseA, .phaseB, .phaseC, .neutral, .egc: return true
        case .control, .signal, .unmarked: return false
        }
    }

    /// Stable legend order.
    public static let legendOrder: [CableLadderCableRole] = [
        .phaseA, .phaseB, .phaseC, .neutral, .egc, .control, .signal, .unmarked,
    ]
}

public enum CableLadderStatus: String, Equatable, Sendable {
    case pass
    case warn
    case fail

    public var label: String {
        switch self {
        case .pass: return "PASS"
        case .warn: return "WARN"
        case .fail: return "FAIL"
        }
    }

    var rank: Int {
        switch self {
        case .pass: return 0
        case .warn: return 1
        case .fail: return 2
        }
    }

    public static func worse(_ lhs: CableLadderStatus, _ rhs: CableLadderStatus) -> CableLadderStatus {
        lhs.rank >= rhs.rank ? lhs : rhs
    }
}

public struct CableLadderCableInput: Equatable, Sendable {
    public enum Sizing: Equatable, Sendable {
        /// One insulated conductor. Area is NEC Chapter 9 Table 5 — the same
        /// table Conduit Fill uses. Not a jacketed multiconductor cable.
        case table5(size: String, insulation: ConductorInsulationKind, material: ConductorMaterial)
        /// Jacket outside diameter. Weight is optional lb per 1000 ft of one cable.
        case overallDiameter(inches: Double, weightLbPerKft: Double?)
    }

    public var count: Int
    public var sizing: Sizing
    public var role: CableLadderCableRole

    public init(count: Int, sizing: Sizing, role: CableLadderCableRole = .unmarked) {
        self.count = count
        self.sizing = sizing
        self.role = role
    }
}

public struct CableLadderInput: Equatable, Sendable {
    public var trayType: CableLadderTrayType
    public var cover: CableLadderCover
    public var contents: CableLadderContents
    public var widthInches: Double
    public var depthInches: Double
    public var rungSpacingInches: Double
    public var lengthFeet: Double
    public var railMaterial: CableLadderRailMaterial
    public var environment: CableLadderEnvironment
    public var orientation: CableLadderOrientation
    public var supportSpanFeet: Double
    public var ambientC: Double
    public var shielded: Bool
    public var divider: Bool
    public var exposedRun: Bool
    public var flexibleDrop: Bool
    public var tintByRole: Bool
    public var colorSystem: CableLadderColorSystem
    public var cables: [CableLadderCableInput]

    public init(
        trayType: CableLadderTrayType = .ladder,
        cover: CableLadderCover = .none,
        contents: CableLadderContents = .singleConductor,
        widthInches: Double = 12,
        depthInches: Double = 4,
        rungSpacingInches: Double = 9,
        lengthFeet: Double = 80,
        railMaterial: CableLadderRailMaterial = .steel,
        environment: CableLadderEnvironment = .indoorDry,
        orientation: CableLadderOrientation = .horizontal,
        supportSpanFeet: Double = 8,
        ambientC: Double = 30,
        shielded: Bool = false,
        divider: Bool = false,
        exposedRun: Bool = false,
        flexibleDrop: Bool = false,
        tintByRole: Bool = true,
        colorSystem: CableLadderColorSystem = .low120,
        cables: [CableLadderCableInput]
    ) {
        self.trayType = trayType
        self.cover = cover
        self.contents = contents
        self.widthInches = widthInches
        self.depthInches = depthInches
        self.rungSpacingInches = rungSpacingInches
        self.lengthFeet = lengthFeet
        self.railMaterial = railMaterial
        self.environment = environment
        self.orientation = orientation
        self.supportSpanFeet = supportSpanFeet
        self.ambientC = ambientC
        self.shielded = shielded
        self.divider = divider
        self.exposedRun = exposedRun
        self.flexibleDrop = flexibleDrop
        self.tintByRole = tintByRole
        self.colorSystem = colorSystem
        self.cables = cables
    }
}

public struct CableLadderCircle: Equatable, Sendable, Identifiable {
    public var id: Int
    public var diameterInches: Double
    public var centerXInches: Double
    public var centerYInches: Double
    public var role: CableLadderCableRole
    public var fits: Bool
}

public struct CableLadderLegendEntry: Equatable, Sendable, Identifiable {
    public var id: String { role.rawValue }
    public var role: CableLadderCableRole
    public var colorName: String
    public var letter: String
    public var caption: String
}

public struct CableLadderLegend: Equatable, Sendable {
    public var systemTitle: String
    public var tintEnabled: Bool
    public var entries: [CableLadderLegendEntry]
    public var disclaimer: String
}

public struct CableLadderSpecChip: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var value: String
    public var detail: String
    /// When true, the installation note keeps the result from a clean pass.
    public var raisesWarning: Bool
}

public struct CableLadderLoadCheck: Equatable, Sendable {
    public var cableLbPerFt: Double
    public var weightComplete: Bool
    /// "8A" when the span is a published NEMA VE 1 span and the load fits.
    public var matchedClass: String?
    /// A, B, or C from the 50 / 75 / 100 lb/ft letters. Nil when the load is over 100.
    public var workingLetter: String?
    public var spanIsPublishedNEMA: Bool
    public var exceedsClassC: Bool
    public var note: String
}

public struct CableLadderResult: Equatable, Sendable {
    public var status: CableLadderStatus
    public var reasons: [String]
    public var cableArea: Double
    public var allowableArea: Double?
    public var codePercent: Double
    public var codePercentLabel: String
    public var basis: String
    public var extrapolated: Bool
    public var usableCrossSection: Double
    public var stackHeightInches: Double
    public var stackPercent: Double
    public var circles: [CableLadderCircle]
    public var supportStationsFeet: [Double]
    public var load: CableLadderLoadCheck
    public var bendRadiusInches: Double
    public var bendNote: String
    public var specChips: [CableLadderSpecChip]
    public var legend: CableLadderLegend
    public var notes: [String]
    public var formula: String
    public var conduitDropLabel: String
    public var accessibilitySummary: String
}

/// Published Article 392 area tables and the small helpers the tests lock.
public enum CableLadderTables {
    /// NEC Table 392.22(A). Column 1 is ladder or ventilated trough.
    /// Column 2 is solid bottom. 9 in solid bottom is the published 8.0 in²,
    /// not the straight line between 6 and 12.
    public static let multiconductorRows: [(width: Double, ladder: Double, solid: Double)] = [
        (6, 7.0, 5.5),
        (9, 10.5, 8.0),
        (12, 14.0, 11.0),
        (18, 21.0, 16.5),
        (24, 28.0, 22.0),
        (30, 35.0, 27.5),
        (36, 42.0, 33.0),
    ]

    /// NEC Table 392.22(B)(1) Column 1 — single conductors smaller than 1000 kcmil.
    public static let singleConductorRows: [(width: Double, column1: Double)] = [
        (6, 6.5),
        (12, 13.0),
        (18, 19.5),
        (24, 26.0),
        (30, 32.5),
        (36, 39.0),
    ]

    /// NEC Table 392.22(A)(5). Column 1 is one multiconductor cable.
    /// Column 2 is more than one.
    public static let channelRows: [(width: Double, one: Double, many: Double)] = [
        (3, 2.3, 1.3),
        (4, 4.5, 2.5),
        (6, 7.0, 3.8),
    ]

    /// NEMA VE 1 class spans this tool will name. The letter is the working load.
    public static let nemaSpansFeet: [Double] = [8, 12, 16, 20]
    public static let classALbPerFt = 50.0
    public static let classBLbPerFt = 75.0
    public static let classCLbPerFt = 100.0

    /// Single conductors in ladder or ventilated trough: max rung spacing.
    /// NEC 392.10. Planning check, not a fill area.
    public static let maxSingleConductorRungSpacingInches = 9.0

    /// WARN above this share of the cited limit. FAIL above 100%.
    public static let warnPercent = 80.0

    public static func multiconductorAllowable(
        widthInches: Double,
        solidBottom: Bool
    ) -> (area: Double, extrapolated: Bool) {
        let rows = multiconductorRows.map { row in
            (width: row.width, area: solidBottom ? row.solid : row.ladder)
        }
        return interpolate(widthInches: widthInches, rows: rows)
    }

    public static func singleConductorColumn1(widthInches: Double) -> (area: Double, extrapolated: Bool) {
        interpolate(
            widthInches: widthInches,
            rows: singleConductorRows.map { (width: $0.width, area: $0.column1) }
        )
    }

    public static func channelAllowable(
        widthInches: Double,
        cableCount: Int
    ) -> (area: Double, extrapolated: Bool) {
        let one = cableCount <= 1
        let rows = channelRows.map { row in
            (width: row.width, area: one ? row.one : row.many)
        }
        return interpolate(widthInches: widthInches, rows: rows)
    }

    /// 392.22(A)(2) / (A)(4). Depth used in the percent is capped at 6 in.
    public static func controlSignalAllowable(
        widthInches: Double,
        depthInches: Double,
        solidBottom: Bool
    ) -> Double {
        let depth = min(depthInches, 6)
        let fraction = solidBottom ? 0.40 : 0.50
        return widthInches * depth * fraction
    }

    public static func diameterInches(areaSquareInches: Double) -> Double {
        guard areaSquareInches > 0 else { return 0 }
        return 2 * Foundation.sqrt(areaSquareInches / .pi)
    }

    public static func isAtLeastOneOught(_ size: String) -> Bool {
        guard
            let index = NECTables.wireSizeOrder.firstIndex(of: size),
            let oneOught = NECTables.wireSizeOrder.firstIndex(of: "1/0")
        else { return false }
        return index >= oneOught
    }

    public static func isOneThousandKcmilOrLarger(_ size: String) -> Bool {
        size == "1000"
    }

    /// Pass at or under 80% of the cited limit. Warn through 100%. Fail above 100%.
    public static func fillStatus(percentOfLimit: Double) -> CableLadderStatus {
        if percentOfLimit > 100 + 1e-6 { return .fail }
        if percentOfLimit > warnPercent + 1e-6 { return .warn }
        return .pass
    }

    public static func supportStations(runLengthFeet: Double, spanFeet: Double) throws -> [Double] {
        let length = try Positive.require(runLengthFeet, name: "Run length")
        let span = try Positive.require(spanFeet, name: "Support span")
        let interior = Int((length / span).rounded(.down))
        if interior > 500 {
            throw CalcError.outOfRange("Support span is very short for this run. Use a longer span.")
        }
        var stations = [0.0]
        var x = span
        while x < length - 1e-6 {
            stations.append(x)
            x += span
        }
        if let last = stations.last, abs(last - length) > 1e-6 {
            stations.append(length)
        }
        return stations
    }

    public static func interpolate(
        widthInches: Double,
        rows: [(width: Double, area: Double)]
    ) -> (area: Double, extrapolated: Bool) {
        let sorted = rows.sorted { $0.width < $1.width }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else {
            return (0, true)
        }
        if let exact = sorted.first(where: { abs($0.width - widthInches) < 1e-9 }) {
            return (exact.area, false)
        }
        if widthInches < first.width {
            let next = sorted[1]
            let slope = (next.area - first.area) / (next.width - first.width)
            return (first.area + slope * (widthInches - first.width), true)
        }
        if widthInches > last.width {
            let prev = sorted[sorted.count - 2]
            let slope = (last.area - prev.area) / (last.width - prev.width)
            return (last.area + slope * (widthInches - last.width), true)
        }
        for index in 0..<(sorted.count - 1) {
            let left = sorted[index]
            let right = sorted[index + 1]
            if widthInches >= left.width, widthInches <= right.width {
                let t = (widthInches - left.width) / (right.width - left.width)
                return (left.area + t * (right.area - left.area), false)
            }
        }
        return (last.area, true)
    }
}

public enum CableLadder {
    public static let legendDisclaimer = "Convention aid only. Same color names as Reference Library conductor colors (NEC 200.6 / 250.119 / 210.5). A tray-cable jacket is often black — this tint is not the jacket and not a listing."

    public static let planningBanner = "Planning estimate — verify the manufacturer load table and the AHJ. Not a PE stamp."

    private static let maxCableCount = 400

    public static func colorLegend(
        system: CableLadderColorSystem,
        roles: [CableLadderCableRole],
        tintEnabled: Bool
    ) -> CableLadderLegend {
        let present = Set(roles)
        let entries = CableLadderCableRole.legendOrder.compactMap { role -> CableLadderLegendEntry? in
            guard present.contains(role) else { return nil }
            return CableLadderLegendEntry(
                role: role,
                colorName: colorName(role: role, system: system),
                letter: role.letter,
                caption: caption(role: role, system: system)
            )
        }
        return CableLadderLegend(
            systemTitle: system.systemTitle,
            tintEnabled: tintEnabled,
            entries: entries,
            disclaimer: legendDisclaimer
        )
    }

    public static func calculate(_ input: CableLadderInput) throws -> CableLadderResult {
        let width = try Positive.require(input.widthInches, name: "Inside width")
        let depth = try Positive.require(input.depthInches, name: "Usable depth")
        let rung = try Positive.require(input.rungSpacingInches, name: "Rung spacing")
        let length = try Positive.require(input.lengthFeet, name: "Run length")
        let span = try Positive.require(input.supportSpanFeet, name: "Support span")
        guard input.ambientC.isFinite else {
            throw CalcError.outOfRange("Ambient temperature must be a real number.")
        }
        guard !input.cables.isEmpty else {
            throw CalcError.missing("at least one cable row")
        }

        var expanded: [ResolvedCable] = []
        var weightLbPerFt = 0.0
        var weightComplete = true
        var totalCount = 0
        var sawTable5InMulticonductor = false
        var sawSmallSingle = false
        var sawUnknownSingleSize = false

        for cable in input.cables {
            let count = try WholeCount.parse(Double(cable.count), name: "Cable count")
            totalCount += count
            if totalCount > maxCableCount {
                throw CalcError.outOfRange("This sketch stops at \(maxCableCount) cables. Split the run or reduce the count.")
            }
            let resolved = try resolve(cable.sizing, role: cable.role)
            if input.contents == .multiconductorMixed || input.contents == .controlSignalOnly {
                if case .table5 = cable.sizing { sawTable5InMulticonductor = true }
            }
            if input.contents == .singleConductor {
                switch cable.sizing {
                case .table5(let size, _, _):
                    if !CableLadderTables.isAtLeastOneOught(size) { sawSmallSingle = true }
                case .overallDiameter:
                    sawUnknownSingleSize = true
                }
            }
            if let perFoot = resolved.lbPerFt {
                weightLbPerFt += perFoot * Double(count)
            } else {
                weightComplete = false
            }
            for _ in 0..<count {
                expanded.append(resolved)
            }
        }

        let solidColumn = usesSolidBottomColumn(type: input.trayType, cover: input.cover)
        let limit = try fillLimit(
            input: input,
            width: width,
            depth: depth,
            solidColumn: solidColumn,
            cables: expanded
        )

        let packMode = packMode(input: input, solidColumn: solidColumn, cables: expanded)
        let circles = pack(cables: expanded, width: width, depth: depth, mode: packMode)
        let stackHeight = circles.map { $0.centerYInches + $0.diameterInches / 2 }.max() ?? 0
        let stackPercent = stackHeight / depth * 100
        let anyMiss = circles.contains { !$0.fits }

        var status = CableLadderStatus.pass
        var reasons: [String] = []
        func raise(_ next: CableLadderStatus, _ reason: String) {
            if next != .pass { reasons.append(reason) }
            status = CableLadderStatus.worse(status, next)
        }

        switch CableLadderTables.fillStatus(percentOfLimit: limit.codePercent) {
        case .fail:
            raise(.fail, limit.overLimitReason)
        case .warn:
            raise(.warn, "Over 80% of the cited fill limit.")
        case .pass:
            break
        }
        if anyMiss || stackHeight > depth + 1e-6 {
            raise(.fail, "A cable does not fit in the inside width or the usable depth.")
        } else if stackPercent > CableLadderTables.warnPercent + 1e-6 {
            raise(.warn, "The packed stack is over 80% of the usable depth.")
        }
        if limit.extrapolated {
            raise(.warn, "Inside width is outside the published table — the allowable area is a planning extrapolation.")
        }
        if input.trayType.hasRungs,
           input.contents == .singleConductor,
           rung > CableLadderTables.maxSingleConductorRungSpacingInches + 1e-9 {
            raise(.warn, "Rung spacing is over 9 in. NEC 392.10 limits single conductors in ladder or ventilated trough to 9 in rung spacing.")
        }
        if input.contents == .controlSignalOnly {
            if expanded.contains(where: \.role.isPowerIdentification) {
                raise(.warn, "A phase, neutral, or EGC row is under the control-and-signal fill rule. That rule is not for power cables.")
            } else if expanded.contains(where: { $0.role == .unmarked }) {
                raise(.warn, "An unmarked row is under the control-and-signal fill rule. Mark it or split the tray.")
            }
        }
        if sawSmallSingle {
            raise(.warn, "Single conductors smaller than 1/0 AWG are not a cable-tray wiring method under NEC 392.10. Smaller THHN belongs in a raceway.")
        }
        if sawUnknownSingleSize {
            raise(.warn, "Overall OD does not show AWG. Single conductors in tray still have to be 1/0 or larger and marked for tray use.")
        }
        if sawTable5InMulticonductor {
            raise(.warn, "Chapter 9 Table 5 is one insulated conductor, not a jacketed multiconductor cable. Enter the overall OD.")
        }

        let load = loadCheck(
            lbPerFt: weightLbPerFt,
            spanFeet: span,
            weightComplete: weightComplete,
            material: input.railMaterial
        )
        if load.exceedsClassC, weightComplete {
            raise(.warn, "Estimated bare-metal load is over 100 lb/ft (NEMA VE 1 class C). Check the manufacturer load class.")
        }

        let chips = specChips(input: input, sawSmallSingle: sawSmallSingle, sawTable5: sawTable5InMulticonductor)

        if status == .pass {
            reasons = ["Within the cited fill limit and the usable depth."]
        }

        let maxOD = expanded.map(\.diameter).max() ?? 0
        let bendMultiple = input.shielded ? 12.0 : 8.0
        let bend = maxOD * bendMultiple
        let bendNote = "Minimum bend \(FormatTrace.number(bend, digits: 2)) in is \(Int(bendMultiple))× the largest OD. Common manufacturer / ICEA planning note (8× unshielded, 12× shielded). Not an NEC 392 rule for circuits 1000 V or less. Confirm the cable spec."

        var notes = limit.notes
        notes.append(contentsOf: installationNotes(input: input, rung: rung))
        notes.append(bendNote)
        notes.append(load.note)
        notes.append("Metal cable tray must be grounded and bonded (NEC 392.60). Size a separate EGC in Equipment Grounding — a green tint on this sketch does not size it.")
        notes.append(planningBanner)

        let legend = colorLegend(
            system: input.colorSystem,
            roles: expanded.map(\.role),
            tintEnabled: input.tintByRole
        )
        let stations = try CableLadderTables.supportStations(runLengthFeet: length, spanFeet: span)
        let drop = chips.first { $0.id == "conduit" }?.value ?? "Raceway"
        let summary = accessibilitySummary(
            codePercent: limit.codePercent,
            status: status,
            legend: legend,
            drop: drop,
            length: length
        )

        return CableLadderResult(
            status: status,
            reasons: reasons,
            cableArea: expanded.reduce(0) { $0 + $1.area },
            allowableArea: limit.allowableArea,
            codePercent: limit.codePercent,
            codePercentLabel: limit.percentLabel,
            basis: limit.basis,
            extrapolated: limit.extrapolated,
            usableCrossSection: width * depth,
            stackHeightInches: stackHeight,
            stackPercent: stackPercent,
            circles: circles,
            supportStationsFeet: stations,
            load: load,
            bendRadiusInches: bend,
            bendNote: bendNote,
            specChips: chips,
            legend: legend,
            notes: notes,
            formula: limit.formula,
            conduitDropLabel: drop,
            accessibilitySummary: summary
        )
    }

    // MARK: - Fill limit

    private struct FillLimit {
        var allowableArea: Double?
        var codePercent: Double
        var percentLabel: String
        var basis: String
        var formula: String
        var extrapolated: Bool
        var notes: [String]
        var overLimitReason: String
    }

    private static func fillLimit(
        input: CableLadderInput,
        width: Double,
        depth: Double,
        solidColumn: Bool,
        cables: [ResolvedCable]
    ) throws -> FillLimit {
        let area = cables.reduce(0) { $0 + $1.area }
        if input.trayType == .channel {
            let published = CableLadderTables.channelAllowable(widthInches: width, cableCount: cables.count)
            let percent = percent(area, of: published.area)
            var notes = [
                "Ventilated channel uses Table 392.22(A)(5). One cable uses Column 1. More than one uses Column 2.",
            ]
            if input.contents == .singleConductor {
                notes.append("392.22(B) single-conductor rules are written for ladder or ventilated trough. This channel number is the (A)(5) area, as a planning stand-in.")
            }
            if input.contents == .controlSignalOnly {
                notes.append("The 50% and 40% control rules are for ladder, trough, and solid bottom. This channel result stays on Table 392.22(A)(5).")
            }
            if input.cover != .none {
                notes.append("A cover does not change the channel table in this tool.")
            }
            return FillLimit(
                allowableArea: published.area,
                codePercent: percent,
                percentLabel: "Percent of Table 392.22(A)(5)",
                basis: cables.count <= 1
                    ? "Table 392.22(A)(5) Column 1 — one cable"
                    : "Table 392.22(A)(5) Column 2 — more than one cable",
                formula: "fill % = cable area / Table 392.22(A)(5) allowable",
                extrapolated: published.extrapolated,
                notes: notes,
                overLimitReason: "Over the Table 392.22(A)(5) area."
            )
        }

        if input.contents == .controlSignalOnly {
            let allowable = CableLadderTables.controlSignalAllowable(
                widthInches: width,
                depthInches: depth,
                solidBottom: solidColumn
            )
            let fraction = solidColumn ? 40.0 : 50.0
            let percent = percent(area, of: allowable)
            let article = solidColumn ? "392.22(A)(4) — 40% of interior area" : "392.22(A)(2) — 50% of interior area"
            return FillLimit(
                allowableArea: allowable,
                codePercent: percent,
                percentLabel: "Percent of the \(Int(fraction))% control/signal allowance",
                basis: "\(article). Depth used in the allowance is capped at 6 in.",
                formula: "fill % = cable area / (width × min(depth, 6 in) × \(Int(fraction))%)",
                extrapolated: false,
                notes: [
                    "Control and signal only. A depth over 6 in still uses 6 in in this percent (392.22). The sketch still packs into the depth you entered.",
                ],
                overLimitReason: "Over the control-and-signal fill allowance."
            )
        }

        let openLadderFamily = (input.trayType == .ladder || input.trayType == .ventilated) && !solidColumn
        if input.contents == .singleConductor, openLadderFamily {
            return singleConductorLimit(width: width, area: area, cables: cables)
        }

        let published = CableLadderTables.multiconductorAllowable(widthInches: width, solidBottom: solidColumn)
        let percent = percent(area, of: published.area)
        var notes: [String] = []
        var basis = solidColumn
            ? "Table 392.22(A) Column 2 — solid bottom"
            : "Table 392.22(A) Column 1 — ladder or ventilated trough"
        if input.cover == .solid, input.trayType != .solidBottom {
            basis = "Table 392.22(A) Column 2 — planning treatment for a solid cover"
            notes.append("A solid unventilated cover on ladder or ventilated trough uses the solid-bottom areas in this tool. That is a planning treatment. Confirm it with the AHJ.")
        }
        if input.contents == .singleConductor, !openLadderFamily {
            notes.append("392.22(B) single-conductor fill is for an open ladder or ventilated trough. This result uses the multiconductor column as a planning stand-in.")
        }
        if input.cover == .ventilated {
            notes.append("Ventilated cover: the fill column is unchanged. Ampacity can still change under 392.80 — not calculated here.")
        }
        return FillLimit(
            allowableArea: published.area,
            codePercent: percent,
            percentLabel: "Percent of Table 392.22(A)",
            basis: basis,
            formula: "fill % = cable area / Table 392.22(A) allowable",
            extrapolated: published.extrapolated,
            notes: notes,
            overLimitReason: "Over the Table 392.22(A) area."
        )
    }

    private static func singleConductorLimit(
        width: Double,
        area: Double,
        cables: [ResolvedCable]
    ) -> FillLimit {
        let column = CableLadderTables.singleConductorColumn1(widthInches: width)
        let large = cables.filter(\.isLargeKcmil)
        let small = cables.filter { !$0.isLargeKcmil }
        if large.count == cables.count {
            let sumD = large.reduce(0) { $0 + $1.diameter }
            let percent = percent(sumD, of: width)
            return FillLimit(
                allowableArea: nil,
                codePercent: percent,
                percentLabel: "Percent of inside width (single layer)",
                basis: "392.22(B)(1)(a) — 1000 kcmil and larger, one layer. Sum of diameters compared with the inside width.",
                formula: "fill % = sum of diameters / inside width",
                extrapolated: false,
                notes: ["1000 kcmil and larger single conductors are a single-layer check, not the Column 1 area."],
                overLimitReason: "Sum of diameters exceeds the inside width."
            )
        }
        if large.isEmpty {
            let percent = percent(area, of: column.area)
            return FillLimit(
                allowableArea: column.area,
                codePercent: percent,
                percentLabel: "Percent of Table 392.22(B)(1) Column 1",
                basis: "392.22(B)(1)(b) — single conductors smaller than 1000 kcmil.",
                formula: "fill % = cable area / Table 392.22(B)(1) Column 1",
                extrapolated: column.extrapolated,
                notes: [],
                overLimitReason: "Over Table 392.22(B)(1) Column 1."
            )
        }
        let sd = large.reduce(0) { $0 + $1.diameter }
        let smallLimit = column.area - 1.1 * sd
        let smallArea = small.reduce(0) { $0 + $1.area }
        let areaPercent = smallLimit > 1e-9 ? percent(smallArea, of: smallLimit) : (smallArea > 0 ? 999 : 0)
        let diameterPercent = percent(sd, of: width)
        let governing = max(areaPercent, diameterPercent)
        return FillLimit(
            allowableArea: smallLimit,
            codePercent: governing,
            percentLabel: "Worse of small-cable area and large-cable single layer",
            basis: "392.22(B)(1)(c) — smaller-cable area ≤ Column 1 − 1.1×Sd. 1000 kcmil and larger stay in one layer.",
            formula: "fill % = worse of (small area / (Column 1 − 1.1×Sd)) and (Sd / width)",
            extrapolated: column.extrapolated,
            notes: ["Sd is the sum of the diameters of the 1000 kcmil and larger single conductors."],
            overLimitReason: "Mixed 1000 kcmil single conductors exceed 392.22(B)(1)(c)."
        )
    }

    // MARK: - Packing

    private enum PackMode {
        case shelf
        case singleLayer
        case largeThenSmall
    }

    private static func packMode(
        input: CableLadderInput,
        solidColumn: Bool,
        cables: [ResolvedCable]
    ) -> PackMode {
        let open = (input.trayType == .ladder || input.trayType == .ventilated) && !solidColumn
        guard input.contents == .singleConductor, open else { return .shelf }
        if cables.allSatisfy(\.isLargeKcmil) { return .singleLayer }
        if cables.contains(where: \.isLargeKcmil) { return .largeThenSmall }
        return .shelf
    }

    private static func pack(
        cables: [ResolvedCable],
        width: Double,
        depth: Double,
        mode: PackMode
    ) -> [CableLadderCircle] {
        switch mode {
        case .singleLayer:
            return place(cables, width: width, depth: depth, y0: 0, allowWrap: false).circles
        case .largeThenSmall:
            let large = cables.filter(\.isLargeKcmil)
            let small = cables.filter { !$0.isLargeKcmil }
            let first = place(large, width: width, depth: depth, y0: 0, allowWrap: false)
            let second = place(small, width: width, depth: depth, y0: first.maxY, allowWrap: true)
            return reindex(first.circles + second.circles)
        case .shelf:
            return place(cables, width: width, depth: depth, y0: 0, allowWrap: true).circles
        }
    }

    private struct Placement {
        var circles: [CableLadderCircle]
        var maxY: Double
    }

    private static func place(
        _ cables: [ResolvedCable],
        width: Double,
        depth: Double,
        y0: Double,
        allowWrap: Bool
    ) -> Placement {
        let ordered = cables.sorted { $0.diameter > $1.diameter }
        var circles: [CableLadderCircle] = []
        var x = 0.0
        var y = y0
        var rowH = 0.0
        for (offset, cable) in ordered.enumerated() {
            let d = cable.diameter
            if allowWrap, x > 1e-9, x + d > width + 1e-6 {
                y += rowH
                x = 0
                rowH = 0
            }
            let fitsWidth = x + d <= width + 1e-6 && d <= width + 1e-6
            let fitsDepth = y + d <= depth + 1e-6
            circles.append(CableLadderCircle(
                id: offset,
                diameterInches: d,
                centerXInches: x + d / 2,
                centerYInches: y + d / 2,
                role: cable.role,
                fits: fitsWidth && fitsDepth
            ))
            x += d
            rowH = max(rowH, d)
        }
        return Placement(circles: circles, maxY: y + rowH)
    }

    private static func reindex(_ circles: [CableLadderCircle]) -> [CableLadderCircle] {
        circles.enumerated().map { index, circle in
            var copy = circle
            copy.id = index
            return copy
        }
    }

    // MARK: - Weight and supports

    public static func loadCheck(
        lbPerFt: Double,
        spanFeet: Double,
        weightComplete: Bool,
        material: CableLadderRailMaterial
    ) -> CableLadderLoadCheck {
        let materialNote = "Rail material is \(material.displayName.lowercased()). NEMA VE 1 class is a listed product rating — this tool does not change the letter for aluminum. Read the manufacturer table for that metal and width."
        guard weightComplete else {
            return CableLadderLoadCheck(
                cableLbPerFt: lbPerFt,
                weightComplete: false,
                matchedClass: nil,
                workingLetter: nil,
                spanIsPublishedNEMA: publishedSpan(spanFeet) != nil,
                exceedsClassC: false,
                note: "Cable weight is incomplete. An overall-OD row needs lb/kft before a load class is shown. \(materialNote)"
            )
        }
        let letter: String?
        let exceeds: Bool
        if lbPerFt <= CableLadderTables.classALbPerFt + 1e-9 {
            letter = "A"
            exceeds = false
        } else if lbPerFt <= CableLadderTables.classBLbPerFt + 1e-9 {
            letter = "B"
            exceeds = false
        } else if lbPerFt <= CableLadderTables.classCLbPerFt + 1e-9 {
            letter = "C"
            exceeds = false
        } else {
            letter = nil
            exceeds = true
        }
        let published = publishedSpan(spanFeet)
        let matched: String?
        if let published, let letter, !exceeds {
            matched = "\(Int(published))\(letter)"
        } else {
            matched = nil
        }
        let weightWords = "Bare-metal book weight is \(FormatTrace.number(lbPerFt, digits: 2)) lb/ft (same lb/kft as Conductor Length). Insulation and jacket are not in that book, so the tray sees more than this."
        let classWords: String
        if exceeds {
            classWords = "That is over 100 lb/ft, which is past NEMA VE 1 class C in this tool. Check the manufacturer load class. The sketch still uses your span."
        } else if let matched, let letter {
            classWords = "At \(Int(published ?? spanFeet)) ft that fits NEMA VE 1 class \(matched) (\(letterLoad(letter)) lb/ft working load). Planning check — not the maker’s table."
        } else if let letter {
            classWords = "The load fits a class \(letter) working load (\(letterLoad(letter)) lb/ft), but \(FormatTrace.number(spanFeet, digits: 1)) ft is not a NEMA VE 1 span in this tool (8, 12, 16, or 20 ft). Do not read it as a listed class."
        } else {
            classWords = "No class letter."
        }
        return CableLadderLoadCheck(
            cableLbPerFt: lbPerFt,
            weightComplete: true,
            matchedClass: matched,
            workingLetter: letter,
            spanIsPublishedNEMA: published != nil,
            exceedsClassC: exceeds,
            note: "\(weightWords) \(classWords) \(materialNote)"
        )
    }

    private static func letterLoad(_ letter: String) -> Int {
        switch letter {
        case "A": return 50
        case "B": return 75
        default: return 100
        }
    }

    private static func publishedSpan(_ span: Double) -> Double? {
        CableLadderTables.nemaSpansFeet.first { abs($0 - span) <= 0.05 }
    }

    // MARK: - Installation chips

    private static func specChips(
        input: CableLadderInput,
        sawSmallSingle: Bool,
        sawTable5: Bool
    ) -> [CableLadderSpecChip] {
        [nemaChip(input), ipChip(input), conduitChip(input), cableChip(input, sawSmallSingle: sawSmallSingle, sawTable5: sawTable5)]
    }

    private static func nemaChip(_ input: CableLadderInput) -> CableLadderSpecChip {
        let (value, name) = nema250(input.environment)
        var detail = "\(name). Reference Library, NEMA 250. An open tray is not a NEMA 250 enclosure — this type is for the box or fitting at the transition, not a listing of the ladder. It is also not the NEMA VE 1 load class."
        if input.cover == .solid {
            detail += " A solid cover is not itself a NEMA 3R or 4 rating."
        }
        return CableLadderSpecChip(id: "nema", title: "NEMA 250", value: value, detail: detail, raisesWarning: false)
    }

    private static func ipChip(_ input: CableLadderInput) -> CableLadderSpecChip {
        switch input.environment {
        case .indoorDry:
            return CableLadderSpecChip(
                id: "ip",
                title: "IP",
                value: "—",
                detail: "No IP code is assigned. NEMA 250 and IEC 60529 are not a conversion chart in this tool.",
                raisesWarning: false
            )
        case .indoorDustDrip:
            return CableLadderSpecChip(
                id: "ip",
                title: "IP",
                value: "See IP5X",
                detail: "Dust and drip is a Type 12 story. Reference Library IP5X means dust-protected. That is not a claimed equivalent and not a listing.",
                raisesWarning: false
            )
        case .outdoorRain:
            return CableLadderSpecChip(
                id: "ip",
                title: "IP",
                value: "—",
                detail: "No IP code is assigned for rain. Type 3R is rain, sleet, and ice. Type 3 is the library row that also names windblown dust.",
                raisesWarning: false
            )
        case .washdown:
            return CableLadderSpecChip(
                id: "ip",
                title: "IP",
                value: "IPX6",
                detail: "Reference Library: IPX6 is roughly the NEMA 4 hose test. That is the only crosswalk this app states. It is not a certification of this tray.",
                raisesWarning: false
            )
        case .corrosive:
            return CableLadderSpecChip(
                id: "ip",
                title: "IP",
                value: "IPX6 note",
                detail: "Corrosion is a material (Type 4X — stainless or nonmetallic in the library), not an IP digit. IPX6 remains only the hose note.",
                raisesWarning: false
            )
        }
    }

    private static func conduitChip(_ input: CableLadderInput) -> CableLadderSpecChip {
        if input.flexibleDrop {
            return CableLadderSpecChip(
                id: "conduit",
                title: "Conduit drop",
                value: "LFMC",
                detail: "Planning pick: a short LFMC whip at the equipment (Reference Library — liquidtight, flexible). The tray run is not LFMC. Leave the tray through a listed tray-to-conduit fitting. The NEMA 250 type stays on the box.",
                raisesWarning: false
            )
        }
        switch input.environment {
        case .indoorDry:
            return CableLadderSpecChip(
                id: "conduit",
                title: "Conduit drop",
                value: "EMT",
                detail: "Planning pick: EMT. Reference Library: set-screw fittings are dry locations; compression is the wet-rated EMT fitting if this room is actually damp.",
                raisesWarning: false
            )
        case .indoorDustDrip:
            return CableLadderSpecChip(
                id: "conduit",
                title: "Conduit drop",
                value: "EMT",
                detail: "Planning pick: EMT with compression fittings. Reference Library calls compression the wet-rated EMT fitting. Type 12 is the box.",
                raisesWarning: false
            )
        case .outdoorRain:
            return CableLadderSpecChip(
                id: "conduit",
                title: "Conduit drop",
                value: "RMC",
                detail: "Planning pick: RMC. IMC is the lighter threaded option in the reference library. PVC Schedule 80 if the route is corrosive or buried. Compression EMT only when the fitting is listed raintight.",
                raisesWarning: false
            )
        case .washdown:
            return CableLadderSpecChip(
                id: "conduit",
                title: "Conduit drop",
                value: "RMC",
                detail: "Planning pick: RMC, or a listed stainless raceway. LFMC is a short whip, not the tray. Type 4 is the box.",
                raisesWarning: false
            )
        case .corrosive:
            return CableLadderSpecChip(
                id: "conduit",
                title: "Conduit drop",
                value: "PVC Sch 80",
                detail: "Planning pick: PVC Schedule 80. RMC needs corrosion protection. Type 4X is the box (stainless or nonmetallic in the reference library).",
                raisesWarning: false
            )
        }
    }

    private static func cableChip(
        _ input: CableLadderInput,
        sawSmallSingle: Bool,
        sawTable5: Bool
    ) -> CableLadderSpecChip {
        var detail = ""
        var value = ""
        var warn = false
        switch input.contents {
        case .singleConductor:
            if sawSmallSingle {
                value = "Not tray wire"
                detail = "NEC 392.10: single conductors in cable tray are 1/0 AWG or larger and must be listed and marked for tray use. Smaller THHN stays in a raceway. Table 5 area is still drawn so you can see the fill."
                warn = true
            } else {
                value = "1/0+ and tray-marked"
                detail = "THHN, XHHW, and RHW here are Chapter 9 insulation columns, not a tray-cable (TC) listing. The reel has to be marked for cable tray use."
            }
        case .multiconductorMixed:
            if input.exposedRun {
                value = "TC-ER"
                detail = "Planning pick: power tray cable with an exposed-run marking. TC-ER may leave the tray for a short run to equipment only where NEC 336.10(7) is met — secured, protected from damage, and only in the occupancies that section allows. It is not permission to skip a conduit drop in every building."
            } else {
                value = "TC or MC"
                detail = "Planning pick: a cable listed for tray (TC or MC, or another method in Table 392.10(A)). Overall OD is the jacket."
            }
            if sawTable5 {
                detail += " A row used Table 5. That area is one conductor, not the jacket."
                warn = true
            }
        case .controlSignalOnly:
            value = input.exposedRun ? "Listed ER mark" : "TC, ITC, or PLTC"
            detail = "Control and signal cables in tray are listed multiconductor types (TC, ITC, PLTC, and the other Table 392.10(A) methods), not loose THHN. The 1/0 rule is for single conductors. An exposed-run marking is printed on the cable — TC-ER is Article 336, and a control cable does not inherit it."
        }
        if input.environment.wantsWetListing {
            detail += " Wet or outdoor: the cable needs a wet-location listing, and sunlight resistance where it is exposed. Reference Library: THHN is 90 °C dry; THWN-2 and XHHW-2 are the wet markings. Read the reel."
        }
        return CableLadderSpecChip(id: "cable", title: "Cable type", value: value, detail: detail, raisesWarning: warn)
    }

    private static func nema250(_ environment: CableLadderEnvironment) -> (String, String) {
        switch environment {
        case .indoorDry: return ("1", "Type 1 — indoor, general purpose")
        case .indoorDustDrip: return ("12", "Type 12 — industrial dust and drip")
        case .outdoorRain: return ("3R", "Type 3R — outdoor, rainproof")
        case .washdown: return ("4", "Type 4 — hose-directed water")
        case .corrosive: return ("4X", "Type 4X — watertight, corrosion resistant")
        }
    }

    private static func installationNotes(input: CableLadderInput, rung: Double) -> [String] {
        var notes: [String] = []
        if input.orientation == .vertical {
            notes.append("Vertical run: fasten the cables to the transverse members (NEC 392.30(B)(1)). Support marks still follow the span you entered. This tool does not invent a second vertical maximum.")
        }
        if input.ambientC > 30 {
            notes.append("Ambient is above the 30 °C Table 310.16 basis. Ampacity, including 392.80 tray rules, is not calculated here. Use Wire Size & Ampacity.")
        }
        if input.divider {
            notes.append("A barrier between power and control does not add fill area. This percent is one combined cross-section. Run the two fills separately if the AHJ wants them split.")
        }
        if input.trayType.hasRungs {
            notes.append("Rung spacing is \(FormatTrace.number(rung, digits: 2)) in on the sketch. It changes the 392.10 single-conductor check. It does not change area fill.")
        } else {
            notes.append("Rung spacing is ignored for \(input.trayType.displayName.lowercased()). Solid bottom and channel do not use the 9 in ladder rung rule.")
        }
        if input.cover == .solid {
            notes.append("Ampacity under a cover (392.80) is not calculated here.")
        }
        return notes
    }

    // MARK: - Cable resolution

    private struct ResolvedCable {
        var area: Double
        var diameter: Double
        var role: CableLadderCableRole
        var lbPerFt: Double?
        var isLargeKcmil: Bool
    }

    private static func resolve(_ sizing: CableLadderCableInput.Sizing, role: CableLadderCableRole) throws -> ResolvedCable {
        switch sizing {
        case .table5(let size, let insulation, let material):
            guard let area = NECTables.conductorArea(size: size, insulation: insulation) else {
                throw CalcError.notListed("No \(insulation.displayName) area listed for \(NECTables.wireLabel(size)).")
            }
            guard let cmil = NECTables.circularMils[size] else {
                throw CalcError.notListed("No circular-mil area listed for \(NECTables.wireLabel(size)).")
            }
            let lengthMaterial: ConductorLengthMaterial = material == .aluminum ? .aluminum : .copperAnnealed
            let lbPerKft = ConductorLength.bookLbPerKft(circularMils: cmil, material: lengthMaterial)
            return ResolvedCable(
                area: area,
                diameter: CableLadderTables.diameterInches(areaSquareInches: area),
                role: role,
                lbPerFt: lbPerKft / 1000,
                isLargeKcmil: CableLadderTables.isOneThousandKcmilOrLarger(size)
            )
        case .overallDiameter(let inches, let weight):
            let od = try Positive.require(inches, name: "Overall diameter")
            let area = .pi * (od / 2) * (od / 2)
            let perFoot: Double?
            if let weight {
                let lb = try Positive.require(weight, name: "Cable weight")
                perFoot = lb / 1000
            } else {
                perFoot = nil
            }
            return ResolvedCable(
                area: area,
                diameter: od,
                role: role,
                lbPerFt: perFoot,
                isLargeKcmil: false
            )
        }
    }

    private static func usesSolidBottomColumn(type: CableLadderTrayType, cover: CableLadderCover) -> Bool {
        if type == .solidBottom { return true }
        if cover == .solid, type == .ladder || type == .ventilated { return true }
        return false
    }

    private static func percent(_ value: Double, of limit: Double) -> Double {
        guard limit > 1e-9 else { return value > 0 ? 999 : 0 }
        return value / limit * 100
    }

    private static func colorName(role: CableLadderCableRole, system: CableLadderColorSystem) -> String {
        switch role {
        case .phaseA: return system == .low120 ? "Black" : "Brown"
        case .phaseB: return system == .low120 ? "Red" : "Orange"
        case .phaseC: return system == .low120 ? "Blue" : "Yellow"
        case .neutral: return system == .low120 ? "White" : "Grey"
        case .egc: return "Green"
        case .control, .signal: return "Not a phase color"
        case .unmarked: return "Untinted"
        }
    }

    private static func caption(role: CableLadderCableRole, system: CableLadderColorSystem) -> String {
        switch role {
        case .phaseA, .phaseB, .phaseC:
            return "\(system.systemTitle) phase convention. Legend only."
        case .neutral:
            return system == .low120 ? "Grounded conductor — white. Legend only." : "Grounded conductor — grey. Legend only."
        case .egc:
            return "Green, green/yellow, or bare. The tint does not size the EGC."
        case .control:
            return "Not a phase color. UL 508A control colors stay in Reference Library so they do not collide with phase red or blue."
        case .signal:
            return "Not a phase color."
        case .unmarked:
            return "No phase, neutral, or EGC mark."
        }
    }

    private static func accessibilitySummary(
        codePercent: Double,
        status: CableLadderStatus,
        legend: CableLadderLegend,
        drop: String,
        length: Double
    ) -> String {
        let fill = "Cable tray fill \(FormatTrace.number(codePercent, digits: 1)) percent, status \(status.label)."
        let tint = legend.tintEnabled ? "Circles tinted as a convention aid." : "Circle tint is off."
        let names = legend.entries.map { entry in
            let letter = entry.letter.isEmpty ? entry.role.displayName : entry.letter
            return "\(letter) \(entry.colorName)"
        }.joined(separator: ", ")
        let legendWords = names.isEmpty ? "" : " Legend: \(names)."
        return "\(fill) \(tint)\(legendWords) Run \(FormatTrace.number(length, digits: 0)) feet. Conduit drop \(drop)."
    }
}
