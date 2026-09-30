import Foundation

/// When a phase arrangement implies an equipment grounding conductor.
///
/// DC and “phase conductors only” do not. A multiwire branch and a 3Ø feeder do.
/// 1Ø 2-wire equipment that is grounded also does — the caller picks the context.
public enum EquipmentGroundingContext: String, Codable, CaseIterable, Sendable, Hashable {
    case none
    case singlePhase
    case multiwire
    case threePhase

    public var displayName: String {
        switch self {
        case .none: return "Phase conductors only"
        case .singlePhase: return "1Ø"
        case .multiwire: return "Multiwire"
        case .threePhase: return "3Ø"
        }
    }

    public var impliesEquipmentGround: Bool { self != .none }

    /// 3Ø and multiwire usually include one EGC. Fill still waits for an explicit count toggle.
    public var countsInRacewayByDefault: Bool {
        self == .threePhase || self == .multiwire
    }

    public static func from(system: ElectricalSystem) -> EquipmentGroundingContext {
        switch system {
        case .dc: return .none
        case .singlePhase: return .singlePhase
        case .threePhase: return .threePhase
        }
    }

    public static func from(phases: Int) -> EquipmentGroundingContext {
        switch phases {
        case 3: return .threePhase
        case 1: return .singlePhase
        default: return .none
        }
    }

    public static func from(receptacle phase: ReceptaclePhaseKind) -> EquipmentGroundingContext {
        switch phase {
        case .singlePhase2Wire: return .singlePhase
        case .singlePhase3Wire: return .multiwire
        case .threePhase: return .threePhase
        }
    }
}

/// One Table 250.122 recommendation. A design aid, not a PE stamp.
public struct EquipmentGroundingRecommendation: Equatable, Sendable {
    public var size: String
    public var label: String
    public var material: ConductorMaterial
    public var context: EquipmentGroundingContext
    /// “Not exceeding” column of the table row that was used.
    public var tableRatingAmps: Int
    /// Amps that selected the row (entered OCPD, or the inferred standard device).
    public var basisAmps: Double
    /// The load or device amps the caller supplied, before inference.
    public var enteredAmps: Double
    public var ampsAreOCPDRating: Bool
    public var cappedToUngroundedConductor: Bool
    public var citation: CodeCitation
    public var notes: [String]

    public var basisLabel: String {
        if ampsAreOCPDRating {
            return "OCPD \(FormatTrace.amps(enteredAmps)) entered"
        }
        return "Next 240.6(A) device \(FormatTrace.amps(basisAmps)) from \(FormatTrace.amps(enteredAmps))"
    }

    public var copyLine: String {
        "EGC \(label) \(material.displayName) · \(citation.shortLabel) · ≤ \(tableRatingAmps) A"
    }
}

/// NEC 2023 Table 250.122 — minimum equipment grounding conductor.
///
/// The table is keyed by the rating of the overcurrent device ahead of the
/// equipment, not by conductor ampacity. Values are a transcription for a
/// design aid. Confirm the current Code and the AHJ.
public enum EquipmentGrounding {
    /// Each row is the maximum OCPD rating that row covers, then copper, then aluminum.
    /// Aluminum `1200` is 1200 kcmil (not in the Chapter 9 size list used elsewhere).
    public static let table250_122: [(maxOCPD: Int, copper: String, aluminum: String)] = [
        (15, "14", "12"),
        (20, "12", "10"),
        (60, "10", "8"),
        (100, "8", "6"),
        (200, "6", "4"),
        (300, "4", "2"),
        (400, "3", "1"),
        (500, "2", "1/0"),
        (600, "1", "2/0"),
        (800, "1/0", "3/0"),
        (1000, "2/0", "4/0"),
        (1200, "3/0", "250"),
        (1600, "4/0", "350"),
        (2000, "250", "400"),
        (2500, "350", "600"),
        (3000, "400", "600"),
        (4000, "500", "750"),
        (5000, "700", "1200"),
        (6000, "800", "1200"),
    ]

    public static let citation = CodeCitation(
        edition: .nec2023,
        articleOrTable: "Table 250.122",
        units: "AWG or kcmil",
        sourceDescription: "Minimum equipment grounding conductor for the OCPD ahead of the equipment. Transcribed from NEC 2023 Table 250.122. Confirm the current Code and the AHJ. Not a PE stamp. Not Table 250.66 (grounding electrode conductor).",
        lastVerified: "2026-09-30"
    )

    public static func conductorLabel(_ size: String) -> String {
        if size == "1200" { return "1200 kcmil" }
        return NECTables.wireLabel(size)
    }

    /// `nil` when the context does not imply a ground, the amps are unusable,
    /// or the rating is above the last transcribed row (6000 A).
    public static func recommend(
        amps: Double,
        material: ConductorMaterial = .copper,
        context: EquipmentGroundingContext,
        ampsAreOCPDRating: Bool,
        ungroundedSize: String? = nil,
        extraNote: String? = nil
    ) -> EquipmentGroundingRecommendation? {
        guard context.impliesEquipmentGround else { return nil }
        guard amps.isFinite, amps > 0 else { return nil }

        let basis: Double
        if ampsAreOCPDRating {
            basis = amps
        } else if let next = NECTables.nextStandardOCPD(amps) {
            basis = Double(next)
        } else {
            return nil
        }

        guard let row = table250_122.first(where: { Double($0.maxOCPD) + 1e-9 >= basis }) else {
            return nil
        }

        var size = material == .copper ? row.copper : row.aluminum
        var capped = false
        var notes: [String] = [
            "NEC 2023 Table 250.122 sizes the EGC from the OCPD ahead of the equipment, not from ampacity. Confirm the current Code and the AHJ. Not a PE stamp.",
            "250.122(B) proportional increase when ungrounded conductors are upsized for voltage drop is not applied here.",
            "A service grounding electrode conductor is Table 250.66, not this row.",
        ]

        if let ungrounded = ungroundedSize,
           let egcCM = NECTables.circularMils[size],
           let phaseCM = NECTables.circularMils[ungrounded] {
            if phaseCM + 1e-6 < egcCM {
                size = ungrounded
                capped = true
                notes.append("250.122(A): the EGC is not required to be larger than the ungrounded conductors (\(conductorLabel(ungrounded))). Confirm those conductors are themselves protected.")
            } else if phaseCM > egcCM + 1e-6 {
                notes.append("Ungrounded conductors are larger than this table minimum. 250.122(B) may require a larger EGC if the increase was for voltage drop.")
            }
        }

        if let extraNote, !extraNote.isEmpty {
            notes.insert(extraNote, at: 0)
        }

        return EquipmentGroundingRecommendation(
            size: size,
            label: conductorLabel(size),
            material: material,
            context: context,
            tableRatingAmps: row.maxOCPD,
            basisAmps: basis,
            enteredAmps: amps,
            ampsAreOCPDRating: ampsAreOCPDRating,
            cappedToUngroundedConductor: capped,
            citation: citation,
            notes: notes
        )
    }
}
