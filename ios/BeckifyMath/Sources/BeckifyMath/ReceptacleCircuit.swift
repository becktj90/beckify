import Foundation

/// Occupancy for a general-purpose receptacle branch circuit.
public enum ReceptacleOccupancy: String, Codable, CaseIterable, Sendable, Hashable {
    case dwelling
    case nonDwelling

    public var displayName: String {
        switch self {
        case .dwelling: return "Dwelling"
        case .nonDwelling: return "Commercial / non-dwelling"
        }
    }
}

/// How the receptacles are chained on the run.
public enum ReceptacleFeedMethod: String, Codable, CaseIterable, Sendable, Hashable {
    case pigtail
    case throughFeed

    public var displayName: String {
        switch self {
        case .pigtail: return "Pigtailed"
        case .throughFeed: return "Through-feed (device terminals)"
        }
    }
}

public struct ReceptacleCircuitInput: Equatable, Sendable {
    public var breakerAmps: Int
    public var volts: Double
    public var occupancy: ReceptacleOccupancy
    public var continuous: Bool
    public var size: String
    public var material: ConductorMaterial
    public var oneWayFeet: Double
    /// Optional planned connected load in VA (≈ W for resistive loads).
    public var plannedLoadVA: Double?
    public var feed: ReceptacleFeedMethod

    public init(
        breakerAmps: Int = 20,
        volts: Double = 120,
        occupancy: ReceptacleOccupancy = .nonDwelling,
        continuous: Bool = true,
        size: String = "12",
        material: ConductorMaterial = .copper,
        oneWayFeet: Double = 75,
        plannedLoadVA: Double? = nil,
        feed: ReceptacleFeedMethod = .pigtail
    ) {
        self.breakerAmps = breakerAmps
        self.volts = volts
        self.occupancy = occupancy
        self.continuous = continuous
        self.size = size
        self.material = material
        self.oneWayFeet = oneWayFeet
        self.plannedLoadVA = plannedLoadVA
        self.feed = feed
    }
}

public struct ReceptacleCircuitResult: Equatable, Sendable {
    public var input: ReceptacleCircuitInput
    /// Circuit rating × voltage.
    public var circuitVA: Double
    /// 80 % of circuit VA when continuous, otherwise 100 %.
    public var usableVA: Double
    /// NEC 220.14(I) count at 180 VA per yoke, 100 % of the circuit.
    public var nonDwellingCountFull: Int
    /// NEC 220.14(I) count at 180 VA per yoke, 80 % continuous.
    public var nonDwellingCountContinuous: Int
    /// The count that applies to the chosen toggle (non-dwelling).
    public var nonDwellingCount: Int
    /// Dwelling practical guidance (not an NEC limit).
    public var dwellingGuidance: ClosedRange<Int>
    /// True when a NEMA 5-20R is allowed on this circuit rating (Table 210.21(B)(3)).
    public var nema520Permitted: Bool
    /// True when the conductor meets the 240.4(D) small-conductor limit for the breaker.
    public var conductorOK: Bool
    public var minimumConductorLabel: String
    public var plannedAmps: Double?
    /// Planned VA as a percent of the full circuit VA.
    public var plannedPercentOfCircuit: Double?
    public var plannedFitsUsable: Bool?
    /// Current the voltage drop check used.
    public var vdAmps: Double
    public var vdUsesPlannedLoad: Bool
    public var voltageDrop: VoltageDropResult
    public var notes: [String]

    /// Count headline for the chosen occupancy (dwelling shows the upper guidance value).
    public var headlineCount: Int {
        input.occupancy == .nonDwelling ? nonDwellingCount : dwellingGuidance.upperBound
    }
}

/// NEMA 5-20R receptacles chained on one 120 V general-purpose branch circuit.
/// Cites NEC 2023 section numbers only. Design aid; the AHJ governs.
public enum ReceptacleCircuit {
    /// NEC 220.14(I): each single or duplex yoke (or multiple on one yoke) counts 180 VA.
    public static let vaPerYoke: Double = 180
    public static let continuousFactor: Double = 0.8
    public static let supportedBreakers: [Int] = [15, 20]

    /// floor(VA / 180) with a tiny epsilon so 1440/180 = 8 survives float noise.
    public static func yokeCount(circuitVA: Double, continuous: Bool) -> Int {
        guard circuitVA.isFinite, circuitVA > 0 else { return 0 }
        let usable = continuous ? circuitVA * continuousFactor : circuitVA
        return Int((usable / vaPerYoke + 1e-9).rounded(.down))
    }

    /// Common field practice for dwellings: about 2 A per outlet at 80 %
    /// up to the 220.14(I) continuous count. Not an NEC limit.
    public static func dwellingGuidance(breakerAmps: Int, volts: Double) -> ClosedRange<Int> {
        let high = yokeCount(circuitVA: Double(breakerAmps) * volts, continuous: true)
        let low = min(high, Int((Double(breakerAmps) * continuousFactor / 2).rounded(.down)))
        return max(1, low)...max(1, high)
    }

    /// NEC 240.4(D) small-conductor minimum for the breaker.
    public static func minimumConductor(breakerAmps: Int, material: ConductorMaterial) -> String {
        switch (material, breakerAmps <= 15) {
        case (.copper, true): return "14"
        case (.copper, false): return "12"
        case (.aluminum, true): return "12"
        case (.aluminum, false): return "10"
        }
    }

    private static let sizeOrder = ["14", "12", "10", "8", "6", "4", "3", "2", "1", "1/0", "2/0", "3/0", "4/0"]

    public static func conductorMeetsMinimum(size: String, breakerAmps: Int, material: ConductorMaterial) -> Bool {
        let minSize = minimumConductor(breakerAmps: breakerAmps, material: material)
        guard let have = sizeOrder.firstIndex(of: size) else {
            // Larger than 4/0 (kcmil) always clears a 15/20 A minimum.
            return NECTables.circularMils[size] != nil
        }
        guard let need = sizeOrder.firstIndex(of: minSize) else { return false }
        return have >= need
    }

    public static func solve(_ input: ReceptacleCircuitInput) throws -> ReceptacleCircuitResult {
        guard supportedBreakers.contains(input.breakerAmps) else {
            throw CalcError.outOfRange("Circuit rating must be 15 A or 20 A for 5-15R / 5-20R general-purpose receptacles.")
        }
        let volts = try Positive.require(input.volts, name: "Voltage")
        let feet = try Positive.require(input.oneWayFeet, name: "One-way length")
        var planned: Double?
        if let p = input.plannedLoadVA {
            guard p.isFinite, p >= 0 else { throw CalcError.nonPositive("Planned load") }
            planned = p > 0 ? p : nil
        }

        let circuitVA = Double(input.breakerAmps) * volts
        let usableVA = input.continuous ? circuitVA * continuousFactor : circuitVA
        let full = yokeCount(circuitVA: circuitVA, continuous: false)
        let cont = yokeCount(circuitVA: circuitVA, continuous: true)
        let guidance = dwellingGuidance(breakerAmps: input.breakerAmps, volts: volts)
        let nema520 = input.breakerAmps >= 20
        let conductorOK = conductorMeetsMinimum(size: input.size, breakerAmps: input.breakerAmps, material: input.material)
        let minLabel = NECTables.wireLabel(minimumConductor(breakerAmps: input.breakerAmps, material: input.material))

        let plannedAmps = planned.map { $0 / volts }
        let vdAmps = plannedAmps ?? usableVA / volts
        let vd = try VoltageDrop.calculate(
            system: .singlePhase,
            current: vdAmps,
            oneWayFeet: feet,
            supplyVolts: volts,
            size: input.size,
            material: input.material
        )

        var notes: [String] = []
        if !nema520 {
            notes.append("A 15 A circuit takes 5-15R receptacles when there are two or more (Table 210.21(B)(3)). A 5-20R needs a 20 A circuit unless it is a single receptacle on an individual branch circuit (210.21(B)(1)).")
        }
        if !conductorOK {
            notes.append("\(NECTables.wireLabel(input.size)) \(input.material.displayName.lowercased()) is below the 240.4(D) minimum of \(minLabel) for a \(input.breakerAmps) A breaker.")
        }
        if input.material == .aluminum {
            notes.append("Aluminum on 15/20 A receptacles needs devices marked CO/ALR (406.3). Most 5-20R devices are copper only.")
        }
        switch input.occupancy {
        case .nonDwelling:
            notes.append("Non-dwelling: 220.14(I) counts 180 VA per single or duplex yoke. \(full) at 100 %, \(cont) treated as continuous (210.19(A), 210.20(A)).")
        case .dwelling:
            notes.append("Dwelling: the NEC sets no receptacle count for general-purpose circuits. Their load is inside the 3 VA/ft² general lighting load (220.14(J), Table 220.12). The \(guidance.lowerBound)–\(guidance.upperBound) range is common practice, not code.")
            notes.append("Kitchen/dining small-appliance (two or more 20 A), laundry, and bathroom receptacles need their own 20 A circuits (210.11(C)(1)–(3)). Don't count them here.")
            notes.append("Check GFCI (210.8), AFCI (210.12), and tamper-resistant (406.12) requirements for the rooms served.")
        }
        notes.append("Cord-and-plug equipment on a multi-outlet circuit should stay at or under 80 % of the rating (210.23(A)).")
        switch input.feed {
        case .pigtail:
            notes.append("Pigtailing keeps downstream outlets live if one device fails. Each pigtail splice adds to box fill.")
        case .throughFeed:
            notes.append("Through-feed carries the whole downstream load across each device's terminals. Use screw terminals, not backstab push-ins. A multiwire neutral must be pigtailed (300.13(B)).")
        }
        notes.append("Box fill: count conductors, devices (2 each per yoke), and clamps per 314.16.")
        notes.append("Voltage drop lumps the load at the far receptacle, which is conservative. 3 % branch / 5 % total are Informational Notes to 210.19(A), not hard limits.")
        notes.append("Based on the 2023 NEC. Local amendments and the AHJ govern.")

        return ReceptacleCircuitResult(
            input: input,
            circuitVA: circuitVA,
            usableVA: usableVA,
            nonDwellingCountFull: full,
            nonDwellingCountContinuous: cont,
            nonDwellingCount: input.continuous ? cont : full,
            dwellingGuidance: guidance,
            nema520Permitted: nema520,
            conductorOK: conductorOK,
            minimumConductorLabel: minLabel,
            plannedAmps: plannedAmps,
            plannedPercentOfCircuit: planned.map { $0 / circuitVA * 100 },
            plannedFitsUsable: planned.map { $0 <= usableVA + 1e-9 },
            vdAmps: vdAmps,
            vdUsesPlannedLoad: plannedAmps != nil,
            voltageDrop: vd,
            notes: notes
        )
    }
}
