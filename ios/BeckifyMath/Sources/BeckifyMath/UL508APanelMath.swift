import Foundation

/// Planning math for an industrial control panel.
///
/// Original formulas and shop notes. The official standard, the listing, and
/// the authority having jurisdiction govern the panel. Nothing here is a
/// certification or a reprint of copyrighted standard text.
public enum UL508APanelMath {
    public static let disclaimer =
        "Educational planning aid. UL 508A, listed combinations, the adopted NEC, NFPA 79, the customer specification, and the AHJ govern. Not a UL certification."

    public static let assumedSCCRLabel = "Assumed per UL 508A Table SB4.1"
    public static let letThroughLabel = "Planning peak, Table SB4.2 style"
}

// MARK: - Install environment, enclosure, wire, conduit

public enum PanelInstallEnvironment: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case indoorDry
    case indoorDustDrip
    case washdown
    case outdoor
    case corrosive
    case hazardousPointer

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .indoorDry: return "Indoor, dry"
        case .indoorDustDrip: return "Indoor dust or dripping"
        case .washdown: return "Washdown"
        case .outdoor: return "Outdoor"
        case .corrosive: return "Corrosive"
        case .hazardousPointer: return "Hazardous location (pointer only)"
        }
    }
}

public enum PanelCircuitClass: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case powerFeeder
    case powerBranch
    case internalPower
    case control
    case class2

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .powerFeeder: return "Power feeder"
        case .powerBranch: return "Power branch"
        case .internalPower: return "Internal power wiring"
        case .control: return "Control circuit"
        case .class2: return "Class 2 / limited energy"
        }
    }
}

public struct WiringMethodAdvice: Equatable, Sendable {
    public var environment: PanelInstallEnvironment
    public var circuit: PanelCircuitClass
    public var wireTypes: [String]
    public var conduitTypes: [String]
    public var preferredRaceways: [RacewayKind]
    public var why: String
    public var avoid: String
    public var verify: String

    public init(
        environment: PanelInstallEnvironment,
        circuit: PanelCircuitClass,
        wireTypes: [String],
        conduitTypes: [String],
        preferredRaceways: [RacewayKind],
        why: String,
        avoid: String,
        verify: String
    ) {
        self.environment = environment
        self.circuit = circuit
        self.wireTypes = wireTypes
        self.conduitTypes = conduitTypes
        self.preferredRaceways = preferredRaceways
        self.why = why
        self.avoid = avoid
        self.verify = verify
    }
}

public enum PanelWiringAdvice {
    /// Tools that already own fill, grounding, and NEC ampacity. Do not rebuild them here.
    public static let crossLinkToolIDs = ["wireAmpacity", "conduitFill", "equipmentGround", "motorFLA"]

    public static let verifyNote =
        "Verify the adopted NEC, the listing, and the AHJ. Insulation letters and raceway types here are a starting pick, not a listing."

    public static func recommend(
        environment: PanelInstallEnvironment,
        circuit: PanelCircuitClass
    ) -> WiringMethodAdvice {
        if circuit == .class2 {
            return WiringMethodAdvice(
                environment: environment,
                circuit: circuit,
                wireTypes: ["Class 2 cable, or the conductors supplied with the listed source"],
                conduitTypes: ["Keep Class 2 separated from power. A barrier or a separate raceway is the usual shop method."],
                preferredRaceways: [],
                why: "Limited-energy circuits are not sized or routed like a power feeder. Separation is the point.",
                avoid: "Do not pull Class 2 in the same raceway as power conductors unless the wiring method you are using explicitly allows it.",
                verify: verifyNote
            )
        }

        switch environment {
        case .indoorDry:
            return WiringMethodAdvice(
                environment: environment,
                circuit: circuit,
                wireTypes: indoorDryWires(circuit),
                conduitTypes: ["EMT for a dry exposed run", "RMC or IMC where the run is subject to damage"],
                preferredRaceways: [.emt, .rmc],
                why: "A dry indoor room is the usual EMT and THHN/THWN-2 job. Inside the enclosure, machine-tool wire is the flexible choice.",
                avoid: "Do not treat EMT or a dry-only jacket as a washdown or outdoor method.",
                verify: verifyNote
            )
        case .indoorDustDrip:
            return WiringMethodAdvice(
                environment: environment,
                circuit: circuit,
                wireTypes: indoorDryWires(circuit),
                conduitTypes: ["EMT or RMC into a dust-tight enclosure", "LFMC for a short drop to a vibrating machine"],
                preferredRaceways: [.emt, .rmc, .lfmc],
                why: "Dust and dripping oil want a tight enclosure and fittings. The conductors can stay in the dry-and-wet dual-rated family.",
                avoid: "A Type 1 box with open knockouts does not match this room.",
                verify: verifyNote
            )
        case .washdown:
            return WiringMethodAdvice(
                environment: environment,
                circuit: circuit,
                wireTypes: wetWires(circuit),
                conduitTypes: ["LFMC at the enclosure", "RMC for the exposed rigid run"],
                preferredRaceways: [.lfmc, .rmc],
                why: "Hose-down needs a wet-rated jacket and a liquidtight entry. EMT couplings are a leak path.",
                avoid: "EMT is a poor fit for washdown. A dry-only THHN legend is the wrong jacket once the raceway is wet.",
                verify: verifyNote
            )
        case .outdoor:
            return WiringMethodAdvice(
                environment: environment,
                circuit: circuit,
                wireTypes: wetWires(circuit),
                conduitTypes: ["RMC or IMC", "PVC Schedule 40 or 80 where sunlight and burial rules allow", "LFMC for a short equipment whip"],
                preferredRaceways: [.rmc, .imc, .pvc40, .lfmc],
                why: "Outdoor raceways are a wet location. Pick a wet-rated conductor and a raceway the AHJ accepts in the weather.",
                avoid: "Do not default to EMT outdoors. Use it only where the AHJ accepts that method for this exposure.",
                verify: verifyNote
            )
        case .corrosive:
            return WiringMethodAdvice(
                environment: environment,
                circuit: circuit,
                wireTypes: wetWires(circuit),
                conduitTypes: ["PVC Schedule 40 or 80", "PVC-coated rigid, or stainless, where metal is required", "LFMC with fittings rated for the same environment"],
                preferredRaceways: [.pvc80, .pvc40, .lfmc],
                why: "Corrosion eats bare steel. Nonmetallic or coated raceway, and a 4X-style enclosure, is the usual planning pair.",
                avoid: "Bare EMT or uncoated RMC in a chemical or salt atmosphere is a short life.",
                verify: verifyNote
            )
        case .hazardousPointer:
            return WiringMethodAdvice(
                environment: environment,
                circuit: circuit,
                wireTypes: ["No insulation pick from this screen — the classification decides"],
                conduitTypes: ["Rigid metal conduit is the method people discuss first. Seals, fittings, and the listing are not chosen here."],
                preferredRaceways: [.rmc],
                why: "This is a pointer, not a Class, Division, or Zone design. Stop and use the area classification.",
                avoid: "Do not treat a NEMA 4X box, EMT, or a color chart as a hazardous-location wiring method.",
                verify: "Classified locations follow the adopted NEC articles for the class and division or zone, plus the listing. This tool does not design that."
            )
        }
    }

    private static func indoorDryWires(_ circuit: PanelCircuitClass) -> [String] {
        switch circuit {
        case .internalPower, .control:
            return ["MTW inside the enclosure", "THHN/THWN-2 where the same conductor continues into a dry raceway"]
        case .powerFeeder, .powerBranch:
            return ["THHN/THWN-2", "XHHW-2 where you want a stiffer wet-and-dry feeder"]
        case .class2:
            return []
        }
    }

    private static func wetWires(_ circuit: PanelCircuitClass) -> [String] {
        switch circuit {
        case .internalPower, .control:
            return ["MTW inside the enclosure", "THWN-2 or XHHW-2 for any conductor that enters a wet raceway"]
        case .powerFeeder, .powerBranch:
            return ["THWN-2 (the wet half of a THHN/THWN-2 dual rate)", "XHHW-2"]
        case .class2:
            return []
        }
    }
}

public struct EnclosureGuide: Equatable, Sendable, Identifiable {
    public var id: String
    public var nemaType: String
    public var title: String
    public var ipAnalogy: String
    public var analogyOnly: Bool
    public var whenToPick: String
    public var notFor: String
    public var environment: PanelInstallEnvironment

    public init(
        id: String,
        nemaType: String,
        title: String,
        ipAnalogy: String,
        analogyOnly: Bool = true,
        whenToPick: String,
        notFor: String,
        environment: PanelInstallEnvironment
    ) {
        self.id = id
        self.nemaType = nemaType
        self.title = title
        self.ipAnalogy = ipAnalogy
        self.analogyOnly = analogyOnly
        self.whenToPick = whenToPick
        self.notFor = notFor
        self.environment = environment
    }
}

public enum PanelEnclosureGuide {
    public static let rows: [EnclosureGuide] = [
        EnclosureGuide(
            id: "1",
            nemaType: "Type 1",
            title: "Indoor, general",
            ipAnalogy: "Often compared with IP20. Analogy only — the tests are not the same.",
            whenToPick: "A dry electrical room. Falling dirt, not rain, not washdown.",
            notFor: "Outdoor, hose-down, or corrosive air.",
            environment: .indoorDry
        ),
        EnclosureGuide(
            id: "12",
            nemaType: "Type 12",
            title: "Indoor dust and dripping",
            ipAnalogy: "Often compared with IP54. Analogy only.",
            whenToPick: "A shop with dust, dripping noncorrosive liquid, or light oil seepage.",
            notFor: "Outdoor weather or a daily hose-down.",
            environment: .indoorDustDrip
        ),
        EnclosureGuide(
            id: "13",
            nemaType: "Type 13",
            title: "Indoor oil and coolant",
            ipAnalogy: "Often compared with IP54. Analogy only.",
            whenToPick: "Oil and coolant spray indoors, next to a machine tool.",
            notFor: "Outdoor or a corrosion problem. Oil resistance is not a 4X claim.",
            environment: .indoorDustDrip
        ),
        EnclosureGuide(
            id: "3R",
            nemaType: "Type 3R",
            title: "Outdoor rain",
            ipAnalogy: "Often compared with IP24. Analogy only. Not dust-tight and not a hose test.",
            whenToPick: "Rain, sleet, and ice on an outdoor wall when you do not need a hose-down rating.",
            notFor: "Washdown, windblown dust as a design basis, or corrosive chemical.",
            environment: .outdoor
        ),
        EnclosureGuide(
            id: "4",
            nemaType: "Type 4",
            title: "Hose-down",
            ipAnalogy: "Often compared with IP66. Analogy only — do not stamp an IP code from a NEMA type.",
            whenToPick: "Indoor or outdoor hose-down, splashing, and windblown dust.",
            notFor: "A corrosion requirement. That is the X.",
            environment: .washdown
        ),
        EnclosureGuide(
            id: "4X",
            nemaType: "Type 4X",
            title: "Hose-down plus corrosion",
            ipAnalogy: "Often compared with IP66, plus a corrosion conversation. Analogy only. Stainless, polycarbonate, and coated steel are not interchangeable.",
            whenToPick: "Washdown or outdoor service where the air or the chemicals attack steel.",
            notFor: "Assuming every 4X door survives every chemical. Read the material.",
            environment: .corrosive
        ),
        EnclosureGuide(
            id: "haz",
            nemaType: "Type 7 / Type 9",
            title: "Hazardous-location pointer",
            ipAnalogy: "No IP analogy. An IP rating does not classify a location.",
            whenToPick: "Only after the area is classified. This row is a reminder that those enclosure types exist.",
            notFor: "Picking Class, Division, Zone, seals, or a wiring method. That design is not in this tool.",
            environment: .hazardousPointer
        ),
    ]

    public static let clearancePrompts: [String] = [
        "Plan working clearance in front of the door for the voltage and the conditions the adopted Code uses. Measure the room. This checklist does not reprint those dimensions.",
        "Confirm wire-bending space for the incoming conductor size before the backplate is drilled.",
        "The door swing should not be the only way out of the working space.",
        "The disconnect handle should be reachable with the door closed and lockable open.",
    ]

    public static func guide(id: String) -> EnclosureGuide? {
        rows.first { $0.id == id }
    }
}

public struct DisconnectPlan: Equatable, Sendable {
    public var minimumAmps: Double
    public var reminders: [String]

    public init(minimumAmps: Double, reminders: [String]) {
        self.minimumAmps = minimumAmps
        self.reminders = reminders
    }
}

public enum PanelDisconnect {
    public static func plan(calculatedLoadAmps: Double, switchesMotor: Bool) throws -> DisconnectPlan {
        let amps = try Positive.require(calculatedLoadAmps, name: "Calculated load")
        var notes = [
            "Size the disconnect at least as large as the calculated panel load.",
            "Put it on the supply side, operable from outside the enclosure, and able to be locked open.",
            "A through-the-door handle is the usual shop build. Confirm the listing for the enclosure type you picked.",
        ]
        if switchesMotor {
            notes.append("When the disconnect switches a motor, it also needs a horsepower rating for that motor. Ampacity alone is not the motor rating.")
        }
        return DisconnectPlan(minimumAmps: amps, reminders: notes)
    }
}

// MARK: - Wire colors (convention, not a statute)

public enum ConductorColorFamily: String, CaseIterable, Sendable, Identifiable {
    case powerDistribution
    case controlPanel
    case iec

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .powerDistribution: return "Distribution / power"
        case .controlPanel: return "Control panel"
        case .iec: return "IEC / EU note"
        }
    }
}

public struct ConductorSwatch: Equatable, Sendable, Identifiable {
    public var name: String
    public var hex: String
    public var ringHex: String?

    public var id: String { name + hex + (ringHex ?? "") }

    public init(name: String, hex: String, ringHex: String? = nil) {
        self.name = name
        self.hex = hex
        self.ringHex = ringHex
    }
}

public struct ConductorColorRole: Equatable, Sendable, Identifiable {
    public var id: String
    public var family: ConductorColorFamily
    public var role: String
    public var swatches: [ConductorSwatch]
    public var guidance: String
    /// Short label so the UI never reads like a statute.
    public var authority: String

    public init(
        id: String,
        family: ConductorColorFamily,
        role: String,
        swatches: [ConductorSwatch],
        guidance: String,
        authority: String
    ) {
        self.id = id
        self.family = family
        self.role = role
        self.swatches = swatches
        self.guidance = guidance
        self.authority = authority
    }
}

public enum PanelConductorColors {
    public static let powerAuthority =
        "North American convention and identification practice. The adopted NEC, the AHJ, and the project spec win."
    public static let controlAuthority =
        "Common shop convention. Verify the customer spec, UL 508A, and NFPA 79. A color on this card is a planning aid, not a statute."
    public static let iecAuthority =
        "IEC / European identification convention. Not an AS/NZS design and not a substitute for the job specification."

    public static let roles: [ConductorColorRole] = [
        ConductorColorRole(
            id: "grounded",
            family: .powerDistribution,
            role: "Grounded conductor",
            swatches: [
                ConductorSwatch(name: "White", hex: "#F4F4F4"),
                ConductorSwatch(name: "Gray", hex: "#9AA0A6"),
            ],
            guidance: "White or gray for the grounded circuit conductor. Use gray when white would be confused with another system in the same enclosure. It carries current. It is not the equipment ground.",
            authority: powerAuthority
        ),
        ConductorColorRole(
            id: "grounding",
            family: .powerDistribution,
            role: "Equipment grounding",
            swatches: [
                ConductorSwatch(name: "Green", hex: "#1B7F3A"),
                ConductorSwatch(name: "Green-yellow", hex: "#1B7F3A", ringHex: "#E2B100"),
                ConductorSwatch(name: "Bare", hex: "#C5C8CE"),
            ],
            guidance: "Green, green with a yellow stripe, or bare. Reserved for the equipment grounding conductor. Do not land a hot or a neutral on it.",
            authority: powerAuthority
        ),
        ConductorColorRole(
            id: "y208",
            family: .powerDistribution,
            role: "208Y/120 ungrounded",
            swatches: [
                ConductorSwatch(name: "Black", hex: "#1A1A1A"),
                ConductorSwatch(name: "Red", hex: "#C0392B"),
                ConductorSwatch(name: "Blue", hex: "#1F4E9A"),
            ],
            guidance: "Black, red, and blue are the common phase colors for a 208Y/120 panel. Shops differ on A-B-C order — match the drawing and the facility standard.",
            authority: powerAuthority
        ),
        ConductorColorRole(
            id: "y480",
            family: .powerDistribution,
            role: "480Y/277 ungrounded",
            swatches: [
                ConductorSwatch(name: "Brown", hex: "#6B3E26"),
                ConductorSwatch(name: "Orange", hex: "#E07A1F"),
                ConductorSwatch(name: "Yellow", hex: "#E2B100"),
            ],
            guidance: "Brown, orange, and yellow are the common phase colors for 480Y/277. Gray is the usual grounded conductor so it is not mistaken for a 208 V white.",
            authority: powerAuthority
        ),
        ConductorColorRole(
            id: "split",
            family: .powerDistribution,
            role: "120/240 single-phase",
            swatches: [
                ConductorSwatch(name: "Black", hex: "#1A1A1A"),
                ConductorSwatch(name: "Red", hex: "#C0392B"),
                ConductorSwatch(name: "White", hex: "#F4F4F4"),
            ],
            guidance: "Two ungrounded legs, commonly black and red, and a white grounded conductor. Green or bare stays the equipment ground.",
            authority: powerAuthority
        ),
        ConductorColorRole(
            id: "highleg",
            family: .powerDistribution,
            role: "High leg",
            swatches: [ConductorSwatch(name: "Orange", hex: "#E07A1F")],
            guidance: "On a 4-wire delta, the phase with the higher voltage to the neutral is identified orange, or by another durable mark. That is an identification practice in the adopted Code — confirm it. Do not treat the high leg as a 120 V phase.",
            authority: "Code identification practice. Confirm the adopted NEC article and the AHJ. This screen does not quote it."
        ),
        ConductorColorRole(
            id: "corner",
            family: .powerDistribution,
            role: "Corner-grounded delta",
            swatches: [
                ConductorSwatch(name: "White", hex: "#F4F4F4"),
                ConductorSwatch(name: "Gray", hex: "#9AA0A6"),
            ],
            guidance: "The grounded phase is identified as a grounded conductor, white or gray. It carries normal current. It is not an equipment ground and it is not a wye neutral. Mark the system on the panel so the next person does not bond it like a ground.",
            authority: powerAuthority
        ),
        ConductorColorRole(
            id: "ac-control",
            family: .controlPanel,
            role: "AC control, ungrounded",
            swatches: [ConductorSwatch(name: "Red", hex: "#C0392B")],
            guidance: "Red is the usual color for AC control conductors that are de-energized when the panel disconnect opens.",
            authority: controlAuthority
        ),
        ConductorColorRole(
            id: "dc-control",
            family: .controlPanel,
            role: "DC control, ungrounded",
            swatches: [ConductorSwatch(name: "Blue", hex: "#1F4E9A")],
            guidance: "Blue is the usual color for DC control conductors supplied from this panel.",
            authority: controlAuthority
        ),
        ConductorColorRole(
            id: "foreign",
            family: .controlPanel,
            role: "Foreign / interlock voltage",
            swatches: [ConductorSwatch(name: "Yellow", hex: "#E2B100")],
            guidance: "Yellow flags a conductor that can stay live with the panel disconnect open — another panel, a foreign source, or an interlock. Check it before you touch it.",
            authority: controlAuthority
        ),
        ConductorColorRole(
            id: "ac-grounded-control",
            family: .controlPanel,
            role: "AC control, grounded",
            swatches: [
                ConductorSwatch(name: "White", hex: "#F4F4F4"),
                ConductorSwatch(name: "Gray", hex: "#9AA0A6"),
            ],
            guidance: "White or gray for the grounded AC control conductor. Keep it distinct from a power neutral if both land in the same can.",
            authority: controlAuthority
        ),
        ConductorColorRole(
            id: "dc-common",
            family: .controlPanel,
            role: "DC common",
            swatches: [ConductorSwatch(name: "White/blue", hex: "#F4F4F4", ringHex: "#1F4E9A")],
            guidance: "White with a blue stripe is the usual grounded DC control conductor.",
            authority: controlAuthority
        ),
        ConductorColorRole(
            id: "control-ground",
            family: .controlPanel,
            role: "Equipment ground",
            swatches: [
                ConductorSwatch(name: "Green", hex: "#1B7F3A"),
                ConductorSwatch(name: "Green-yellow", hex: "#1B7F3A", ringHex: "#E2B100"),
            ],
            guidance: "Green or green-yellow, same job as on the power side. Do not use it as a control common.",
            authority: controlAuthority
        ),
        ConductorColorRole(
            id: "iec-phase",
            family: .iec,
            role: "IEC phases",
            swatches: [
                ConductorSwatch(name: "Brown", hex: "#8B5A2B"),
                ConductorSwatch(name: "Black", hex: "#1A1A1A"),
                ConductorSwatch(name: "Grey", hex: "#8E8E8E"),
            ],
            guidance: "Brown, black, and grey are the common line colors in IEC-style installations. Do not recolor a 480Y/277 panel this way unless the job specification says so.",
            authority: iecAuthority
        ),
        ConductorColorRole(
            id: "iec-neutral",
            family: .iec,
            role: "IEC neutral",
            swatches: [ConductorSwatch(name: "Blue", hex: "#2E5AAC")],
            guidance: "Blue is the usual neutral. In a North American panel, blue is often a 208 V phase or a DC control wire — do not mix the two languages on one job.",
            authority: iecAuthority
        ),
        ConductorColorRole(
            id: "iec-pe",
            family: .iec,
            role: "IEC protective earth",
            swatches: [ConductorSwatch(name: "Green-yellow", hex: "#1B7F3A", ringHex: "#E2B100")],
            guidance: "Green-yellow is the protective earth. It lines up with the North American green-yellow ground, not with a neutral.",
            authority: iecAuthority
        ),
    ]

    public static func roles(in family: ConductorColorFamily) -> [ConductorColorRole] {
        roles.filter { $0.family == family }
    }

    /// AS/NZS is the international code in Settings. The IEC card is the note for that mode.
    public static func emphasizeIEC(code: ElectricalCode) -> Bool {
        code == .asnzs
    }
}

// MARK: - Internal wire ampacity (Table 28.1 style)

public enum PanelTerminalColumn: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case c60
    case c75

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .c60: return "60°C terminals"
        case .c75: return "75°C terminals"
        }
    }

    public var detail: String {
        switch self {
        case .c60: return "Use when the terminal is unmarked or marked 60°C only."
        case .c75: return "Use when the terminal is marked 75°C or 60/75°C."
        }
    }
}

public struct PanelWireChoice: Equatable, Sendable {
    public var size: String
    public var ampacity: Int
    public var column: PanelTerminalColumn
    public var controlOnly: Bool

    public init(size: String, ampacity: Int, column: PanelTerminalColumn, controlOnly: Bool) {
        self.size = size
        self.ampacity = ampacity
        self.column = column
        self.controlOnly = controlOnly
    }
}

public enum PanelWireAmpacity {
    public static let caption =
        "Planning copper ampacities for industrial-control-panel wiring, with 60°C and 75°C terminal columns. 14 AWG and larger use the same copper numbers as the familiar power-column pair. 18 and 16 AWG are control sizes. Not a reprint of the standard table, and not NEC field-wiring small-conductor limits."

    /// 18 and 16 AWG control sizes, then 14 AWG and up from the copper 60°C / 75°C columns.
    public static func rows(column: PanelTerminalColumn, includeControlSizes: Bool) -> [(size: String, amps: Int, controlOnly: Bool)] {
        var out: [(String, Int, Bool)] = []
        if includeControlSizes, column == .c60 {
            out.append(("18", 7, true))
            out.append(("16", 10, true))
        }
        let index = column == .c60 ? 0 : 1
        for size in NECTables.wireSizeOrder {
            guard let cols = NECTables.ampacityCopper[size], cols.count > index else { continue }
            out.append((size, cols[index], false))
        }
        return out
    }

    public static func smallest(
        requiredAmps: Double,
        column: PanelTerminalColumn,
        includeControlSizes: Bool
    ) throws -> PanelWireChoice {
        let need = try Positive.require(requiredAmps, name: "Required amps")
        guard let row = rows(column: column, includeControlSizes: includeControlSizes).first(where: { Double($0.amps) + 1e-9 >= need }) else {
            throw CalcError.notListed("No planning size in this column covers \(need) A.")
        }
        return PanelWireChoice(size: row.size, ampacity: row.amps, column: column, controlOnly: row.controlOnly)
    }
}

// MARK: - Feeder

public struct FeederLoadInput: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, Hashable {
        case motor
        case heater
        case other
    }

    public var name: String
    public var kind: Kind
    public var fullLoadAmps: Double
    /// Branch protective device for this load, when you already know it.
    public var branchDeviceAmps: Double?

    public init(name: String, kind: Kind, fullLoadAmps: Double, branchDeviceAmps: Double? = nil) {
        self.name = name
        self.kind = kind
        self.fullLoadAmps = fullLoadAmps
        self.branchDeviceAmps = branchDeviceAmps
    }
}

public struct FeederSizingResult: Equatable, Sendable {
    public var largestMotorFLC: Double
    public var remainingMotorFLC: Double
    public var heaterFLC: Double
    public var otherFLC: Double
    public var minimumConductorAmps: Double
    public var largestBranchDeviceAmps: Double
    public var branchDeviceIsPlanning: Bool
    public var overcurrentBasisAmps: Double
    public var conductorAmpacityUsed: Double
    public var maximumFeederOCPD: Double
    public var suggestedSize: String?
    public var suggestedAmpacity: Int?
    public var formula: String

    public init(
        largestMotorFLC: Double,
        remainingMotorFLC: Double,
        heaterFLC: Double,
        otherFLC: Double,
        minimumConductorAmps: Double,
        largestBranchDeviceAmps: Double,
        branchDeviceIsPlanning: Bool,
        overcurrentBasisAmps: Double,
        conductorAmpacityUsed: Double,
        maximumFeederOCPD: Double,
        suggestedSize: String?,
        suggestedAmpacity: Int?,
        formula: String
    ) {
        self.largestMotorFLC = largestMotorFLC
        self.remainingMotorFLC = remainingMotorFLC
        self.heaterFLC = heaterFLC
        self.otherFLC = otherFLC
        self.minimumConductorAmps = minimumConductorAmps
        self.largestBranchDeviceAmps = largestBranchDeviceAmps
        self.branchDeviceIsPlanning = branchDeviceIsPlanning
        self.overcurrentBasisAmps = overcurrentBasisAmps
        self.conductorAmpacityUsed = conductorAmpacityUsed
        self.maximumFeederOCPD = maximumFeederOCPD
        self.suggestedSize = suggestedSize
        self.suggestedAmpacity = suggestedAmpacity
        self.formula = formula
    }
}

public enum PanelFeederSizing {
    /// Conductor minimum: 125% of the largest motor FLC, 125% of heaters, 100% of the rest.
    /// Feeder OCPD maximum: the larger of (largest branch device + 125% heaters + other FLCs) and the conductor ampacity.
    public static func size(
        loads: [FeederLoadInput],
        conductorAmpacity: Double?,
        terminal: PanelTerminalColumn = .c75
    ) throws -> FeederSizingResult {
        guard !loads.isEmpty else { throw CalcError.missing("at least one load") }
        for load in loads {
            _ = try Positive.require(load.fullLoadAmps, name: load.name.isEmpty ? "Load current" : load.name)
            if let device = load.branchDeviceAmps {
                _ = try Positive.require(device, name: "Branch device")
            }
        }

        let motors = loads.filter { $0.kind == .motor }
        let largestMotor = motors.map(\.fullLoadAmps).max() ?? 0
        let remainingMotors = motors.map(\.fullLoadAmps).reduce(0, +) - largestMotor
        let heaters = loads.filter { $0.kind == .heater }.map(\.fullLoadAmps).reduce(0, +)
        let others = loads.filter { $0.kind == .other }.map(\.fullLoadAmps).reduce(0, +)
        let minimum = 1.25 * largestMotor + 1.25 * heaters + remainingMotors + others

        let enteredDevices = loads.compactMap(\.branchDeviceAmps)
        let branchDeviceIsPlanning: Bool
        let largestDevice: Double
        if let entered = enteredDevices.max() {
            largestDevice = entered
            branchDeviceIsPlanning = false
        } else if largestMotor > 0 {
            let percent = MotorNameplate.scpdPercent(motorType: .squirrelCageOther, device: .inverseTimeBreaker)
            let raw = largestMotor * percent / 100
            guard let standard = NECTables.nextStandardOCPD(raw) else {
                throw CalcError.notListed("No standard device covers the planning branch breaker.")
            }
            largestDevice = Double(standard)
            branchDeviceIsPlanning = true
        } else {
            throw CalcError.missing("largest branch protective device")
        }

        let basis = largestDevice + 1.25 * heaters + remainingMotors + others
        let suggested = try? PanelWireAmpacity.smallest(
            requiredAmps: minimum,
            column: terminal,
            includeControlSizes: false
        )
        let conductorTerm: Double
        if let conductorAmpacity {
            conductorTerm = try Positive.require(conductorAmpacity, name: "Conductor ampacity")
        } else if let suggested {
            conductorTerm = Double(suggested.ampacity)
        } else {
            throw CalcError.notListed("Enter a conductor ampacity. The planning table does not cover this load.")
        }

        return FeederSizingResult(
            largestMotorFLC: largestMotor,
            remainingMotorFLC: remainingMotors,
            heaterFLC: heaters,
            otherFLC: others,
            minimumConductorAmps: minimum,
            largestBranchDeviceAmps: largestDevice,
            branchDeviceIsPlanning: branchDeviceIsPlanning,
            overcurrentBasisAmps: basis,
            conductorAmpacityUsed: conductorTerm,
            maximumFeederOCPD: max(basis, conductorTerm),
            suggestedSize: suggested?.size,
            suggestedAmpacity: suggested?.ampacity,
            formula: "Imin = 1.25·largest motor + 1.25·heaters + other FLCs; feeder OCPD ≤ max(largest BCPD + 1.25·heaters + other FLCs, conductor ampacity)"
        )
    }
}

// MARK: - Branch / group motor

public enum BranchDeviceChoice: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case inverseTimeBreaker
    case timeDelayFuse
    case classCCFuse
    case nontimeDelayFuse
    case instantaneousBreaker

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .inverseTimeBreaker: return "Inverse-time breaker"
        case .timeDelayFuse: return "Time-delay fuse"
        case .classCCFuse: return "Class CC fuse"
        case .nontimeDelayFuse: return "Nontime-delay fuse"
        case .instantaneousBreaker: return "Instantaneous-trip breaker"
        }
    }

    var motorDevice: MotorSCPDDevice {
        switch self {
        case .inverseTimeBreaker: return .inverseTimeBreaker
        case .timeDelayFuse: return .dualElementFuse
        case .classCCFuse, .nontimeDelayFuse: return .nontimeDelayFuse
        case .instantaneousBreaker: return .instantaneousBreaker
        }
    }
}

public struct BranchMotorResult: Equatable, Sendable {
    public var percent: Double
    public var rawAmps: Double
    public var nextStandardAmps: Int?
    public var conductorMinAmps: Double
    public var overloadPercent: Double
    public var overloadAmps: Double
    public var notes: [String]
    public var formula: String

    public init(
        percent: Double,
        rawAmps: Double,
        nextStandardAmps: Int?,
        conductorMinAmps: Double,
        overloadPercent: Double,
        overloadAmps: Double,
        notes: [String],
        formula: String
    ) {
        self.percent = percent
        self.rawAmps = rawAmps
        self.nextStandardAmps = nextStandardAmps
        self.conductorMinAmps = conductorMinAmps
        self.overloadPercent = overloadPercent
        self.overloadAmps = overloadAmps
        self.notes = notes
        self.formula = formula
    }
}

public enum GroupProtectiveDevice: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case inverseTimeBreaker
    case timeDelayFuse
    case classCCFuse

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .inverseTimeBreaker: return "Breaker"
        case .timeDelayFuse: return "Time-delay fuse"
        case .classCCFuse: return "Class CC fuse"
        }
    }

    /// Planning percent of the largest motor only. The other motors add at 100%.
    public var percentOfLargest: Double {
        switch self {
        case .inverseTimeBreaker: return 250
        case .timeDelayFuse: return 175
        case .classCCFuse: return 300
        }
    }
}

public struct GroupMotorTap: Equatable, Sendable {
    public var flc: Double
    public var loadSideMinAmps: Double

    public init(flc: Double, loadSideMinAmps: Double) {
        self.flc = flc
        self.loadSideMinAmps = loadSideMinAmps
    }
}

public struct GroupMotorResult: Equatable, Sendable {
    public var largestFLC: Double
    public var percent: Double
    public var rawAmps: Double
    public var nextStandardAmps: Int?
    public var tapMinAmps: Double
    public var motors: [GroupMotorTap]
    public var formula: String
    public var notes: [String]

    public init(
        largestFLC: Double,
        percent: Double,
        rawAmps: Double,
        nextStandardAmps: Int?,
        tapMinAmps: Double,
        motors: [GroupMotorTap],
        formula: String,
        notes: [String]
    ) {
        self.largestFLC = largestFLC
        self.percent = percent
        self.rawAmps = rawAmps
        self.nextStandardAmps = nextStandardAmps
        self.tapMinAmps = tapMinAmps
        self.motors = motors
        self.formula = formula
        self.notes = notes
    }
}

public enum PanelBranchSizing {
    public static func singleMotor(
        flc: Double,
        device: BranchDeviceChoice,
        motorType: MotorNameplateType = .squirrelCageOther,
        serviceFactor: Double? = nil,
        temperatureRiseC: Double? = nil
    ) throws -> BranchMotorResult {
        let current = try Positive.require(flc, name: "Motor FLC")
        let percent = MotorNameplate.scpdPercent(motorType: motorType, device: device.motorDevice)
        let raw = current * percent / 100
        let overload = MotorNameplate.overloadPercent(serviceFactor: serviceFactor, temperatureRiseC: temperatureRiseC)
        var notes = [
            "Branch short-circuit device and the overload are different jobs. The overload is sized from FLC, not from the breaker.",
            "Table FLC for conductor and short-circuit sizing lives in Motor FLA. Nameplate current is for the overload when you have the plate.",
            "A group of motors on one device uses the group rule, not this single-motor multiplier on every motor.",
        ]
        if device == .classCCFuse {
            notes.append("Class CC is planned on the nontime-delay percentage for this motor type. Confirm the fuse is the device the controller was evaluated with.")
        }
        return BranchMotorResult(
            percent: percent,
            rawAmps: raw,
            nextStandardAmps: NECTables.nextStandardOCPD(raw),
            conductorMinAmps: MotorFLA.conductorAmps(fla: current),
            overloadPercent: overload.pct,
            overloadAmps: current * overload.pct / 100,
            notes: notes,
            formula: "BCPD ≤ % × FLC (motor-type row); conductor ≥ 125% × FLC; overload ≤ pickup % × FLC"
        )
    }

    public static func group(
        motorFLCs: [Double],
        device: GroupProtectiveDevice
    ) throws -> GroupMotorResult {
        guard motorFLCs.count >= 2 else { throw CalcError.missing("at least two motors") }
        let currents = try motorFLCs.map { try Positive.require($0, name: "Motor FLC") }
        let largest = currents.max() ?? 0
        let rest = currents.reduce(0, +) - largest
        let raw = largest * device.percentOfLargest / 100 + rest
        let standard = NECTables.nextStandardOCPD(raw)
        let deviceAmps = Double(standard ?? 0)
        let tapBasis = standard == nil ? raw : deviceAmps
        let notes = [
            "Every power device in the group has to be marked for group installation, and the group device cannot exceed that marking.",
            "Tap conductors to each manual controller are planned at not less than one tenth of the group branch device.",
            "On the load side of a manual controller marked for tap protection, plan the conductors at not less than 125% of that motor FLC.",
        ]
        return GroupMotorResult(
            largestFLC: largest,
            percent: device.percentOfLargest,
            rawAmps: raw,
            nextStandardAmps: standard,
            tapMinAmps: tapBasis / 10,
            motors: currents.map { GroupMotorTap(flc: $0, loadSideMinAmps: MotorFLA.conductorAmps(fla: $0)) },
            formula: "Group device ≤ %·largest FLC + other motor FLCs; tap ≥ 1/10 of that device",
            notes: notes
        )
    }
}

// MARK: - SCCR

public enum SCCRComponentKind: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case busBar
    case circuitBreaker
    case currentShunt
    case fuseHolder
    case overloadRelay
    case switchOther
    case motorController0to50
    case motorController51to200
    case motorController201to400
    case motorController401to600
    case motorController601to900
    case motorController901to1600
    case miniatureFuse
    case receptacleGFCI
    case receptacleOther
    case supplementaryProtector
    case switchUnit
    case terminalOrPDB

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .busBar: return "Bus bar"
        case .circuitBreaker: return "Circuit breaker, including GFCI type"
        case .currentShunt: return "Current shunt"
        case .fuseHolder: return "Fuse holder"
        case .overloadRelay: return "Overload relay"
        case .switchOther: return "Switch, other than mercury-tube"
        case .motorController0to50: return "Motor controller, 0–50 HP"
        case .motorController51to200: return "Motor controller, 51–200 HP"
        case .motorController201to400: return "Motor controller, 201–400 HP"
        case .motorController401to600: return "Motor controller, 401–600 HP"
        case .motorController601to900: return "Motor controller, 601–900 HP"
        case .motorController901to1600: return "Motor controller, 901–1600 HP"
        case .miniatureFuse: return "Miniature or miscellaneous fuse"
        case .receptacleGFCI: return "Receptacle, GFCI type"
        case .receptacleOther: return "Receptacle, other than GFCI"
        case .supplementaryProtector: return "Supplementary protector"
        case .switchUnit: return "Switch unit"
        case .terminalOrPDB: return "Terminal block or power distribution block"
        }
    }

    /// Planning default, kA rms. Labeled assumed per the SB4.1 practice, not a certification.
    public var assumedKiloamps: Double {
        switch self {
        case .busBar, .currentShunt, .fuseHolder, .miniatureFuse, .receptacleOther, .terminalOrPDB:
            return 10
        case .circuitBreaker, .overloadRelay, .switchOther, .motorController0to50, .switchUnit:
            return 5
        case .motorController51to200: return 10
        case .motorController201to400: return 18
        case .motorController401to600: return 30
        case .motorController601to900: return 42
        case .motorController901to1600: return 85
        case .receptacleGFCI: return 2
        case .supplementaryProtector: return 0.2
        }
    }

    public var assumptionNote: String {
        switch self {
        case .miniatureFuse:
            return "Planning default 10 kA. Miniature fuses are a low-voltage practice — confirm the circuit is within the voltage the listing allows."
        case .switchUnit:
            return "Planning default 5 kA. Some older summaries print a lower switch-unit row. Confirm the edition you build to."
        case .supplementaryProtector:
            return "0.2 kA will usually set the panel. A supplementary protector is not a branch device and is a poor power-circuit choice."
        case .motorController0to50, .motorController51to200, .motorController201to400,
             .motorController401to600, .motorController601to900, .motorController901to1600:
            return "Horsepower-band default for an unmarked controller. A tested combination with a specific upstream device can be much higher — enter that marked value instead."
        default:
            return UL508APanelMath.assumedSCCRLabel
        }
    }
}

public enum SCCRRatingSource: String, Codable, Sendable {
    case marked
    case assumedSB41
}

public enum SCCRRole: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case feederProtectiveDevice
    case branchProtectiveDevice
    case loadSideComponent
    case feederComponent
    case controlPrimaryDevice
    case transformerSecondaryComponent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .feederProtectiveDevice: return "Feeder protective device"
        case .branchProtectiveDevice: return "Branch protective device"
        case .loadSideComponent: return "Load-side component"
        case .feederComponent: return "Feeder component"
        case .controlPrimaryDevice: return "Control primary device"
        case .transformerSecondaryComponent: return "Transformer secondary"
        }
    }
}

public struct SCCRComponent: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var role: SCCRRole
    public var kiloamps: Double
    public var volts: Double
    public var source: SCCRRatingSource

    public init(
        id: String = UUID().uuidString,
        name: String,
        role: SCCRRole,
        kiloamps: Double,
        volts: Double,
        source: SCCRRatingSource
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.kiloamps = kiloamps
        self.volts = volts
        self.source = source
    }
}

public enum PanelFuseClass: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case cc
    case j
    case t600
    case t300
    case rk1
    case rk5

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cc: return "Class CC"
        case .j: return "Class J"
        case .t600: return "Class T, 600 V"
        case .t300: return "Class T, 300 V"
        case .rk1: return "Class RK1"
        case .rk5: return "Class RK5"
        }
    }
}

struct FuseLetThroughRow: Equatable, Sendable {
    var amps: Double
    var ip50: Double
    var ip100: Double
    var ip200: Double
}

public enum PanelFuseLetThrough {
    /// Peak kiloamperes at the 50 / 100 / 200 kA planning columns.
    /// Intermediate ampere ratings use the next listed case size.
    private static let rows: [PanelFuseClass: [FuseLetThroughRow]] = [
        .cc: [
            FuseLetThroughRow(amps: 15, ip50: 3, ip100: 3, ip200: 4),
            FuseLetThroughRow(amps: 20, ip50: 3, ip100: 4, ip200: 5),
            FuseLetThroughRow(amps: 30, ip50: 6, ip100: 7.5, ip200: 12),
        ],
        .j: sharedJ,
        .t600: sharedJ,
        .t300: [
            FuseLetThroughRow(amps: 30, ip50: 5, ip100: 7, ip200: 9),
            FuseLetThroughRow(amps: 60, ip50: 7, ip100: 9, ip200: 12),
            FuseLetThroughRow(amps: 100, ip50: 9, ip100: 12, ip200: 12),
            FuseLetThroughRow(amps: 200, ip50: 13, ip100: 16, ip200: 20),
            FuseLetThroughRow(amps: 400, ip50: 22, ip100: 28, ip200: 35),
            FuseLetThroughRow(amps: 600, ip50: 29, ip100: 37, ip200: 46),
            FuseLetThroughRow(amps: 800, ip50: 37, ip100: 50, ip200: 65),
            FuseLetThroughRow(amps: 1200, ip50: 50, ip100: 65, ip200: 80),
        ],
        .rk1: [
            FuseLetThroughRow(amps: 30, ip50: 6, ip100: 10, ip200: 12),
            FuseLetThroughRow(amps: 60, ip50: 10, ip100: 12, ip200: 16),
            FuseLetThroughRow(amps: 100, ip50: 14, ip100: 16, ip200: 20),
            FuseLetThroughRow(amps: 200, ip50: 18, ip100: 22, ip200: 30),
            FuseLetThroughRow(amps: 400, ip50: 33, ip100: 35, ip200: 50),
            FuseLetThroughRow(amps: 600, ip50: 43, ip100: 50, ip200: 70),
        ],
        .rk5: [
            FuseLetThroughRow(amps: 30, ip50: 11, ip100: 11, ip200: 14),
            FuseLetThroughRow(amps: 60, ip50: 20, ip100: 21, ip200: 26),
            FuseLetThroughRow(amps: 100, ip50: 22, ip100: 25, ip200: 32),
            FuseLetThroughRow(amps: 200, ip50: 32, ip100: 40, ip200: 50),
            FuseLetThroughRow(amps: 400, ip50: 50, ip100: 60, ip200: 75),
            FuseLetThroughRow(amps: 600, ip50: 65, ip100: 80, ip200: 100),
        ],
    ]

    private static let sharedJ: [FuseLetThroughRow] = [
        FuseLetThroughRow(amps: 30, ip50: 6, ip100: 7.5, ip200: 12),
        FuseLetThroughRow(amps: 60, ip50: 8, ip100: 10, ip200: 16),
        FuseLetThroughRow(amps: 100, ip50: 12, ip100: 14, ip200: 20),
        FuseLetThroughRow(amps: 200, ip50: 16, ip100: 20, ip200: 30),
        FuseLetThroughRow(amps: 400, ip50: 25, ip100: 30, ip200: 45),
        FuseLetThroughRow(amps: 600, ip50: 35, ip100: 45, ip200: 70),
        FuseLetThroughRow(amps: 800, ip50: 50, ip100: 55, ip200: 75),
    ]

    public static func peakKiloamps(
        fuseClass: PanelFuseClass,
        amps: Double,
        prospectiveKiloamps: Double
    ) throws -> (caseAmps: Double, peakKA: Double, columnKA: Double) {
        let rating = try Positive.require(amps, name: "Fuse amperes")
        let prospective = try Positive.require(prospectiveKiloamps, name: "Prospective fault")
        guard prospective <= 200 else {
            throw CalcError.notListed("Prospective fault is above the 200 kA planning column. Confirm the fuse let-through curve.")
        }
        let column: Double = prospective <= 50 ? 50 : (prospective <= 100 ? 100 : 200)
        guard let table = rows[fuseClass], let row = table.first(where: { $0.amps + 1e-9 >= rating }) else {
            throw CalcError.notListed("No planning case size covers a \(rating) A \(fuseClass.title) fuse.")
        }
        let peak: Double
        switch column {
        case 50: peak = row.ip50
        case 100: peak = row.ip100
        default: peak = row.ip200
        }
        return (row.amps, peak, column)
    }
}

public enum PanelCurrentLimit: Equatable, Sendable {
    case none
    case fuse(fuseClass: PanelFuseClass, amps: Double, prospectiveKA: Double, interruptKA: Double)
    case breaker(peakLetThroughKA: Double, prospectiveKA: Double, interruptKA: Double)
    case transformer(va: Double, secondaryVolts: Double, percentZ: Double?, phases: Int, primaryInterruptKA: Double)
}

public struct SCCRPathLine: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var role: SCCRRole
    public var rawKA: Double
    public var effectiveKA: Double
    public var volts: Double
    public var raised: Bool
    public var limiting: Bool
    public var note: String

    public init(
        id: String,
        name: String,
        role: SCCRRole,
        rawKA: Double,
        effectiveKA: Double,
        volts: Double,
        raised: Bool,
        limiting: Bool,
        note: String
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.rawKA = rawKA
        self.effectiveKA = effectiveKA
        self.volts = volts
        self.raised = raised
        self.limiting = limiting
        self.note = note
    }
}

public struct PanelSCCRResult: Equatable, Sendable {
    public var panelKA: Double
    public var panelVolts: Double
    public var paths: [SCCRPathLine]
    public var letThroughKA: Double?
    public var currentLimitApplied: Bool
    public var transformer: TransformerIscResult?
    public var marking: String
    public var notes: [String]

    public init(
        panelKA: Double,
        panelVolts: Double,
        paths: [SCCRPathLine],
        letThroughKA: Double?,
        currentLimitApplied: Bool,
        transformer: TransformerIscResult?,
        marking: String,
        notes: [String]
    ) {
        self.panelKA = panelKA
        self.panelVolts = panelVolts
        self.paths = paths
        self.letThroughKA = letThroughKA
        self.currentLimitApplied = currentLimitApplied
        self.transformer = transformer
        self.marking = marking
        self.notes = notes
    }

    public var limitingNames: [String] {
        paths.filter(\.limiting).map(\.name)
    }
}

public enum PanelSCCR {
    /// Lowest finite positive rating. The panel cannot be marked above its weakest applicable path.
    public static func limitingKiloamps(_ values: [Double]) throws -> Double {
        guard !values.isEmpty else { throw CalcError.missing("at least one SCCR") }
        var lowest = Double.greatestFiniteMagnitude
        for value in values {
            let ok = try Positive.require(value, name: "SCCR")
            lowest = min(lowest, ok)
        }
        return lowest
    }

    public static func aggregate(
        components: [SCCRComponent],
        limit: PanelCurrentLimit
    ) throws -> PanelSCCRResult {
        guard !components.isEmpty else { throw CalcError.missing("at least one power-circuit component") }
        for component in components {
            _ = try Positive.require(component.kiloamps, name: component.name.isEmpty ? "SCCR" : component.name)
            _ = try Positive.require(component.volts, name: "Voltage")
        }

        var effective = components.map(\.kiloamps)
        var raised = Array(repeating: false, count: components.count)
        var notes = Array(repeating: "", count: components.count)
        var extra: [String] = []
        var letThrough: Double?
        var applied = false
        var transformer: TransformerIscResult?

        switch limit {
        case .none:
            extra.append("No current-limiting credit. The panel is the lowest component rating.")
        case .fuse(let fuseClass, let amps, let prospective, let interrupt):
            let interruptKA = try Positive.require(interrupt, name: "Fuse interrupting rating")
            let looked = try PanelFuseLetThrough.peakKiloamps(
                fuseClass: fuseClass,
                amps: amps,
                prospectiveKiloamps: prospective
            )
            letThrough = looked.peakKA
            let ceiling = min(looked.columnKA, interruptKA)
            extra.append("\(UL508APanelMath.letThroughLabel): \(fuseClass.title) \(FormatKA.amps(looked.caseAmps)) A case, \(FormatKA.ka(looked.peakKA)) kA peak at the \(FormatKA.ka(looked.columnKA)) kA column.")
            if interruptKA + 1e-9 < looked.columnKA {
                extra.append("Fuse interrupting rating is below that column, so the credit cannot exceed the fuse.")
            }
            for index in components.indices {
                guard components[index].role == .loadSideComponent else {
                    notes[index] = "Not raised. Let-through credit is for load-side branch components, not the feeder device, a feeder component, or a branch breaker interrupting rating."
                    continue
                }
                if components[index].kiloamps + 1e-9 >= looked.peakKA {
                    effective[index] = ceiling
                    raised[index] = true
                    applied = true
                    notes[index] = "Raw rating is at least the planning peak, so this pass raises the component to the fault column used."
                } else {
                    notes[index] = "Raw rating is below the planning peak. Current-limiting credit does not apply to this component."
                }
            }
        case .breaker(let peak, let prospective, let interrupt):
            let peakKA = try Positive.require(peak, name: "Breaker peak let-through")
            let prospectiveKA = try Positive.require(prospective, name: "Prospective fault")
            let interruptKA = try Positive.require(interrupt, name: "Breaker interrupting rating")
            letThrough = peakKA
            let ceiling = min(prospectiveKA, interruptKA)
            extra.append("Current-limiting breaker credit uses the peak you entered. The breaker must be listed and marked current-limiting. This tool does not check that mark.")
            for index in components.indices where components[index].role == .loadSideComponent {
                if components[index].kiloamps + 1e-9 >= peakKA {
                    effective[index] = ceiling
                    raised[index] = true
                    applied = true
                    notes[index] = "Raw rating covers the entered peak, so this pass uses the prospective fault, capped by the breaker interrupting rating."
                } else {
                    notes[index] = "Raw rating is below the entered peak. No credit on this component."
                }
            }
        case .transformer(let va, let volts, let percentZ, let phases, let primaryIR):
            let primary = try Positive.require(primaryIR, name: "Primary device interrupting rating")
            let isc = try PanelTransformerFault.secondaryIsc(
                va: va,
                secondaryVolts: volts,
                percentZ: percentZ,
                phases: phases
            )
            transformer = isc
            let secondaryIndexes = components.indices.filter { components[$0].role == .transformerSecondaryComponent }
            if secondaryIndexes.isEmpty {
                extra.append("Transformer fault is calculated. Add the secondary components before this path can raise or limit the panel.")
            } else {
                let allCover = secondaryIndexes.allSatisfy { components[$0].kiloamps + 1e-9 >= isc.iscKA }
                if allCover {
                    applied = true
                    for index in secondaryIndexes {
                        effective[index] = primary
                        raised[index] = true
                        notes[index] = "Every secondary component is at least the calculated fault, so this pass assigns the primary device interrupting rating."
                    }
                } else {
                    for index in secondaryIndexes {
                        notes[index] = "A secondary component is below the calculated fault. The transformer does not raise this path."
                    }
                }
            }
            extra.append(isc.assumedUnmarkedZ
                ? "Unmarked impedance, or a value under 2.1%, is planned at 2.1% so the secondary fault is not understated."
                : "Secondary fault uses the impedance you entered.")
        }

        let panelKA = try limitingKiloamps(effective)
        let panelVolts = components.map(\.volts).min() ?? 0
        let paths: [SCCRPathLine] = components.indices.map { index in
            SCCRPathLine(
                id: components[index].id,
                name: components[index].name,
                role: components[index].role,
                rawKA: components[index].kiloamps,
                effectiveKA: effective[index],
                volts: components[index].volts,
                raised: raised[index],
                limiting: abs(effective[index] - panelKA) < 1e-6,
                note: notes[index]
            )
        }
        extra.append("Control-circuit coils and pilot devices on the load side of the control primary device are not in this minimum. The primary device itself is, when you include it.")
        extra.append("Slash-voltage ratings can limit the system further. The volts shown are the lowest voltage you entered.")
        return PanelSCCRResult(
            panelKA: panelKA,
            panelVolts: panelVolts,
            paths: paths,
            letThroughKA: letThrough,
            currentLimitApplied: applied,
            transformer: transformer,
            marking: planningMarking(sccrKA: panelKA, volts: panelVolts),
            notes: extra
        )
    }

    public static func planningMarking(sccrKA: Double, volts: Double) -> String {
        "Planning mark: short-circuit current rating \(FormatKA.ka(sccrKA)) kA rms symmetrical, \(FormatKA.volts(volts)) V maximum. Confirm the listing method and the nameplate wording before it is applied."
    }
}

enum FormatKA {
    static func ka(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.05 { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    static func amps(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.05 { return String(format: "%.0f", value) }
        return String(format: "%.0f", value.rounded())
    }

    static func volts(_ value: Double) -> String {
        String(format: "%.0f", value.rounded())
    }
}

// MARK: - Transformer secondary fault

public struct TransformerIscResult: Equatable, Sendable {
    public var fullLoadAmps: Double
    public var iscAmps: Double
    public var iscKA: Double
    public var percentZUsed: Double
    public var assumedUnmarkedZ: Bool
    public var formula: String

    public init(
        fullLoadAmps: Double,
        iscAmps: Double,
        iscKA: Double,
        percentZUsed: Double,
        assumedUnmarkedZ: Bool,
        formula: String
    ) {
        self.fullLoadAmps = fullLoadAmps
        self.iscAmps = iscAmps
        self.iscKA = iscKA
        self.percentZUsed = percentZUsed
        self.assumedUnmarkedZ = assumedUnmarkedZ
        self.formula = formula
    }
}

public enum PanelTransformerFault {
    public static let unmarkedPercentZ = 2.1

    /// Secondary short-circuit current. Three-phase uses √3. Unmarked %Z, or a value under 2.1%, is planned at 2.1%.
    public static func secondaryIsc(
        va: Double,
        secondaryVolts: Double,
        percentZ: Double?,
        phases: Int
    ) throws -> TransformerIscResult {
        let voltAmps = try Positive.require(va, name: "Transformer VA")
        guard phases == 1 || phases == 3 else {
            throw CalcError.outOfRange("Phase must be 1 or 3.")
        }
        let assumed: Bool
        let usedZ: Double
        if let percentZ {
            if percentZ <= 0 { throw CalcError.nonPositive("Impedance %") }
            if percentZ < unmarkedPercentZ {
                assumed = true
                usedZ = unmarkedPercentZ
            } else {
                assumed = false
                usedZ = percentZ
            }
        } else {
            assumed = true
            usedZ = unmarkedPercentZ
        }
        let system: ElectricalSystem = phases == 3 ? .threePhase : .singlePhase
        let fault = try ShortCircuit.transformerSecondary(
            kVA: voltAmps / 1000,
            secondaryVolts: secondaryVolts,
            impedancePercent: usedZ,
            system: system
        )
        return TransformerIscResult(
            fullLoadAmps: fault.fullLoadAmps,
            iscAmps: fault.availableFaultAmps,
            iscKA: fault.availableFaultAmps / 1000,
            percentZUsed: usedZ,
            assumedUnmarkedZ: assumed,
            formula: "Isc ≈ VA / (\(phases == 3 ? "√3·" : "")V·%Z). Unmarked or under 2.1% uses 2.1%."
        )
    }
}

// MARK: - Control transformer

public struct ControlTransformerPlan: Equatable, Sendable {
    public var primaryFLA: Double
    public var secondaryFLA: Double
    public var primaryPercent: Double
    public var primaryCeilingAmps: Double
    public var primaryDeviceAmps: Int?
    public var secondaryCeilingAmps: Double
    public var secondaryDeviceAmps: Int?
    public var bandNote: String
    public var sccrNote: String
    public var limitedEnergyNote: String

    public init(
        primaryFLA: Double,
        secondaryFLA: Double,
        primaryPercent: Double,
        primaryCeilingAmps: Double,
        primaryDeviceAmps: Int?,
        secondaryCeilingAmps: Double,
        secondaryDeviceAmps: Int?,
        bandNote: String,
        sccrNote: String,
        limitedEnergyNote: String
    ) {
        self.primaryFLA = primaryFLA
        self.secondaryFLA = secondaryFLA
        self.primaryPercent = primaryPercent
        self.primaryCeilingAmps = primaryCeilingAmps
        self.primaryDeviceAmps = primaryDeviceAmps
        self.secondaryCeilingAmps = secondaryCeilingAmps
        self.secondaryDeviceAmps = secondaryDeviceAmps
        self.bandNote = bandNote
        self.sccrNote = sccrNote
        self.limitedEnergyNote = limitedEnergyNote
    }
}

public enum PanelControlTransformer {
    public static let sccrNote =
        "When control power is tapped from the feeder, the primary protective device is part of the power-circuit SCCR. Devices on its load side — coils, pilot lights, a PLC — are not. A supplementary protector is not that primary device."

    public static let limitedEnergyNote =
        "A Class 2 supply or other limited-energy secondary is a different circuit. Do not size it like a power branch, and keep it separated from power wiring."

    /// Planning primary bands used for a control transformer: 500% at or under 2 A, 167% through 9 A, 125% above that.
    public static func plan(va: Double, primaryVolts: Double, secondaryVolts: Double) throws -> ControlTransformerPlan {
        let voltAmps = try Positive.require(va, name: "Transformer VA")
        let primaryV = try Positive.require(primaryVolts, name: "Primary voltage")
        let secondaryV = try Positive.require(secondaryVolts, name: "Secondary voltage")
        let primary = voltAmps / primaryV
        let secondary = voltAmps / secondaryV
        let percent: Double
        let roundsUp: Bool
        let band: String
        if primary <= 2 {
            percent = 500
            roundsUp = true
            band = "Primary current is 2 A or less, so the planning primary device is 500% of primary current, next standard size."
        } else if primary <= 9 {
            percent = 167
            roundsUp = true
            band = "Primary current is over 2 A through 9 A, so the planning primary device is 167%, next standard size."
        } else {
            percent = 125
            roundsUp = false
            band = "Primary current is over 9 A, so the planning primary device is 125%, not above that ceiling."
        }
        let primaryCeiling = primary * percent / 100
        let primaryDevice = roundsUp
            ? NECTables.nextStandardOCPD(primaryCeiling)
            : NECTables.largestStandardOCPD(atOrBelow: primaryCeiling)
        let secondaryCeiling = secondary * 1.25
        return ControlTransformerPlan(
            primaryFLA: primary,
            secondaryFLA: secondary,
            primaryPercent: percent,
            primaryCeilingAmps: primaryCeiling,
            primaryDeviceAmps: primaryDevice,
            secondaryCeilingAmps: secondaryCeiling,
            secondaryDeviceAmps: NECTables.largestStandardOCPD(atOrBelow: secondaryCeiling) ?? NECTables.nextStandardOCPD(secondaryCeiling),
            bandNote: band + " Power transformers with both primary and secondary protection still belong in Transformer Sizing (450.3(B)).",
            sccrNote: sccrNote,
            limitedEnergyNote: limitedEnergyNote
        )
    }
}

// MARK: - Nameplate prompts

public struct NameplatePrompt: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var detail: String

    public init(id: String, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public enum PanelNameplate {
    public static let prompts: [NameplatePrompt] = [
        NameplatePrompt(id: "mfr", title: "Builder name", detail: "Who built the panel, where a field tech can ask a question."),
        NameplatePrompt(id: "voltage", title: "Voltage, phases, frequency", detail: "Every supply, including a slash-voltage limit if a device requires a solidly grounded wye."),
        NameplatePrompt(id: "flc", title: "Full-load current", detail: "The panel FLC for each incoming supply. This is the feeder-sizing number, not a breaker frame."),
        NameplatePrompt(id: "sccr", title: "SCCR", detail: "rms symmetrical amperes or kiloamperes, and the voltage. Use the weakest applicable path."),
        NameplatePrompt(id: "ocpd", title: "Required protective device", detail: "When the SCCR depends on a specific upstream fuse or breaker, say so. A substituted device can void the number."),
        NameplatePrompt(id: "motor", title: "Largest motor", detail: "Horsepower or full-load current of the largest motor the panel supplies."),
        NameplatePrompt(id: "enclosure", title: "Enclosure type", detail: "The NEMA or UL type you actually built, not the type you wished for."),
        NameplatePrompt(id: "diagram", title: "Schematic", detail: "A diagram number that matches the drawings left in the pocket or the job file."),
        NameplatePrompt(id: "field", title: "Field wiring", detail: "What the installer must land, and any device the installer must supply."),
    ]
}
