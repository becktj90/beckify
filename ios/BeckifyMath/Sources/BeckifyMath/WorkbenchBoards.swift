import Foundation

// MARK: - Seatable op-amp parts

/// A real op-amp package that fits the breadboard's DIP footprint, with the pin numbers a builder needs.
/// The numbers come from the same industry pinouts as `PartPinouts`. Unused amplifiers on a dual or quad
/// part are tied off on the board (output to IN−, IN+ to ground).
public struct WorkbenchOpAmpPart: Equatable, Sendable, Identifiable {
    public struct Amp: Equatable, Sendable {
        public var letter: String
        public var inMinus: Int
        public var inPlus: Int
        public var out: Int

        public init(_ letter: String, inMinus: Int, inPlus: Int, out: Int) {
            self.letter = letter
            self.inMinus = inMinus
            self.inPlus = inPlus
            self.out = out
        }
    }

    public var id: String
    public var name: String
    public var pinCount: Int
    public var amps: [Amp]
    public var vPlus: Int
    public var vMinus: Int

    public init(id: String, name: String, pinCount: Int, amps: [Amp], vPlus: Int, vMinus: Int) {
        self.id = id
        self.name = name
        self.pinCount = pinCount
        self.amps = amps
        self.vPlus = vPlus
        self.vMinus = vMinus
    }

    /// The amplifier the board wires up.
    public var primary: Amp { amps[0] }
    public var spares: [Amp] { Array(amps.dropFirst()) }
    public var packageLabel: String { "DIP-\(pinCount)" }

    public var kindLabel: String {
        switch amps.count {
        case 1: return "single"
        case 2: return "dual"
        default: return "quad"
        }
    }

    /// Pin names from the shared pinout catalog, in pin order. Falls back to the pin number.
    public var pinLabels: [String] {
        let catalog = PartPinouts.part(id: id)?.pins ?? []
        return (1...pinCount).map { number in
            catalog.first { $0.number == number }?.name ?? "pin \(number)"
        }
    }

    /// "IN− pin 2, IN+ pin 3, OUT pin 6" for the amplifier the board uses.
    public var primarySummary: String {
        let amp = primary
        return "IN− pin \(amp.inMinus), IN+ pin \(amp.inPlus), OUT pin \(amp.out), V+ pin \(vPlus), V− pin \(vMinus)"
    }
}

/// Typed values the stage boards need. Anything a topology does not use stays nil.
public struct WorkbenchStageValues: Equatable, Sendable {
    public var vin: Double?
    public var v1: Double?
    public var v2: Double?
    public var rin: Double?
    public var rf: Double?
    public var rg: Double?
    public var r1: Double?
    public var r2: Double?
    public var capacitance: Double?
    /// Solved output, shown as a chip on the board when it is finite.
    public var outputVolts: Double?

    public init(
        vin: Double? = nil, v1: Double? = nil, v2: Double? = nil,
        rin: Double? = nil, rf: Double? = nil, rg: Double? = nil,
        r1: Double? = nil, r2: Double? = nil,
        capacitance: Double? = nil, outputVolts: Double? = nil
    ) {
        self.vin = vin
        self.v1 = v1
        self.v2 = v2
        self.rin = rin
        self.rf = rf
        self.rg = rg
        self.r1 = r1
        self.r2 = r2
        self.capacitance = capacitance
        self.outputVolts = outputVolts
    }
}

/// Part values for a filter board. `capacitance` is the C that goes on the board.
public struct WorkbenchFilterValues: Equatable, Sendable {
    public var resistance: Double
    public var capacitance: Double
    public var cornerHz: Double
    public var quality: Double
    public var sallenKeyK: Double?

    public init(resistance: Double, capacitance: Double, cornerHz: Double, quality: Double, sallenKeyK: Double? = nil) {
        self.resistance = resistance
        self.capacitance = capacitance
        self.cornerHz = cornerHz
        self.quality = quality
        self.sallenKeyK = sallenKeyK
    }
}

public enum WorkbenchBoards {
    /// Parts that sit in a DIP-8 or DIP-14 footprint. The SOT-23 MCP6001 stays a pinout-only part.
    public static let opAmpParts: [WorkbenchOpAmpPart] = [
        single("lm741"), single("tl071"), single("op07"),
        dual("lm358"), dual("tl072"), dual("ne5532"),
        quad("lm324"), quad("tl074"),
    ]

    public static let defaultPartID = "lm741"

    /// Where the last board that ran out of room gave up. For tests and debugging.
    nonisolated(unsafe) static var lastFailure = ""

    public static func opAmpPart(id: String) -> WorkbenchOpAmpPart? {
        opAmpParts.first { $0.id == id }
    }

    private static func name(_ id: String) -> String {
        PartPinouts.part(id: id)?.name ?? id.uppercased()
    }

    private static func single(_ id: String) -> WorkbenchOpAmpPart {
        WorkbenchOpAmpPart(
            id: id, name: name(id), pinCount: 8,
            amps: [.init("A", inMinus: 2, inPlus: 3, out: 6)],
            vPlus: 7, vMinus: 4
        )
    }

    private static func dual(_ id: String) -> WorkbenchOpAmpPart {
        WorkbenchOpAmpPart(
            id: id, name: name(id), pinCount: 8,
            amps: [.init("A", inMinus: 2, inPlus: 3, out: 1), .init("B", inMinus: 6, inPlus: 5, out: 7)],
            vPlus: 8, vMinus: 4
        )
    }

    private static func quad(_ id: String) -> WorkbenchOpAmpPart {
        WorkbenchOpAmpPart(
            id: id, name: name(id), pinCount: 14,
            amps: [
                .init("A", inMinus: 2, inPlus: 3, out: 1), .init("B", inMinus: 6, inPlus: 5, out: 7),
                .init("C", inMinus: 9, inPlus: 10, out: 8), .init("D", inMinus: 13, inPlus: 12, out: 14),
            ],
            vPlus: 4, vMinus: 11
        )
    }

    /// The part values a filter family puts on the board. First-order filters use the reference C the
    /// corner was computed from. Second-order sections and the twin-T use the C that lands on the design frequency.
    public static func filterValues(
        family: AnalogFilterFamily,
        result: AnalogFilterResult,
        resistance: Double,
        referenceCapacitance: Double
    ) -> WorkbenchFilterValues {
        let capacitance = AnalogFilter.usesQuality(family) ? result.suggestedCapacitance : referenceCapacitance
        return WorkbenchFilterValues(
            resistance: resistance,
            capacitance: capacitance,
            cornerHz: result.cornerHz,
            quality: result.qualityFactor,
            sallenKeyK: result.sallenKeyK
        )
    }

    // MARK: Stage boards

    public static func stage(
        _ topology: OpAmpTopology,
        values: WorkbenchStageValues,
        part: WorkbenchOpAmpPart
    ) -> BreadboardLayout? {
        var builder = BreadboardBuilder(blankSolution(for: topology))
        let seat = WBSeat(part: part, origin: 12)
        switch topology {
        case .inverting: return builder.wbInverting(seat, values)
        case .noninverting: return builder.wbNoninverting(seat, values)
        case .follower: return builder.wbFollower(seat, values)
        case .difference: return builder.wbDifference(seat, values)
        case .summing: return builder.wbSumming(seat, values)
        case .integrator: return builder.wbIntegrator(seat, values)
        case .differentiator: return builder.wbDifferentiator(seat, values)
        }
    }

    // MARK: Filter boards

    public static func filter(
        _ family: AnalogFilterFamily,
        values: WorkbenchFilterValues,
        part: WorkbenchOpAmpPart
    ) -> BreadboardLayout? {
        guard filterLimitation(family, values: values) == nil else { return nil }
        var builder = BreadboardBuilder(blankSolution(for: .firstOrderFilter))
        let seat = WBSeat(part: part, origin: 12)
        switch family {
        case .rcLowpass: return builder.wbRC(values, lowpass: true)
        case .rcHighpass: return builder.wbRC(values, lowpass: false)
        case .sallenKeyLowpass: return builder.wbSallenKey(seat, values, lowpass: true)
        case .sallenKeyHighpass: return builder.wbSallenKey(seat, values, lowpass: false)
        case .twinTNotch: return builder.wbTwinT(values)
        case .firstOrderAllpass: return builder.wbAllpass(seat, values)
        }
    }

    /// The passband gain the drawn circuit actually has. The Bode plot can show any gain, a circuit shows one.
    public static func realizedGain(_ family: AnalogFilterFamily, values: WorkbenchFilterValues) -> Double {
        switch family {
        case .sallenKeyLowpass, .sallenKeyHighpass: return max(values.sallenKeyK ?? 1, 1)
        case .rcLowpass, .rcHighpass, .twinTNotch, .firstOrderAllpass: return 1
        }
    }

    /// Why a family cannot be drawn for these numbers, or nil when it can. The board is not drawn in that case.
    public static func filterLimitation(_ family: AnalogFilterFamily, values: WorkbenchFilterValues) -> String? {
        switch family {
        case .sallenKeyLowpass, .sallenKeyHighpass:
            if let k = values.sallenKeyK, k < 0.999 {
                return "Q below 0.5 needs a section with gain under 1. An op-amp stage cannot give that, so no board is drawn. Use Q of 0.5 or more."
            }
        case .twinTNotch:
            if abs(values.quality - 0.25) > 0.02 {
                return "A passive twin-T has Q ≈ 0.25. A sharper notch needs a bootstrapped or active twin-T, which this board does not draw."
            }
        default: break
        }
        return nil
    }

    /// A line to show when the requested passband gain is not the one the drawn circuit gives.
    public static func filterGainNote(_ family: AnalogFilterFamily, values: WorkbenchFilterValues, requestedGain: Double) -> String? {
        guard requestedGain.isFinite, requestedGain > 0 else { return nil }
        let real = realizedGain(family, values: values)
        guard abs(real - requestedGain) > 0.01 * max(real, 1) else { return nil }
        let shown = BreadboardFormat.trim(real)
        switch family {
        case .sallenKeyLowpass, .sallenKeyHighpass:
            return "The circuit shown has passband gain K = \(shown), which its Q sets. The Passband gain field only scales the Bode plot."
        default:
            return "The circuit shown has a passband gain of \(shown). The Passband gain field only scales the Bode plot. Add a gain stage to realize it."
        }
    }

    /// Filter families whose board carries an op-amp. The rest are passive and ignore the part.
    public static func filterUsesOpAmp(_ family: AnalogFilterFamily) -> Bool {
        switch family {
        case .sallenKeyLowpass, .sallenKeyHighpass, .firstOrderAllpass: return true
        case .rcLowpass, .rcHighpass, .twinTNotch: return false
        }
    }

    private static func blankSolution(for topology: OpAmpTopology) -> LabSolution {
        let circuit: ElectronicsCircuit
        switch topology {
        case .inverting: circuit = .invertingAmp
        case .noninverting, .follower: circuit = .nonInvertingAmp
        case .difference: circuit = .diffAmp
        case .summing: circuit = .summingAmp
        case .integrator: circuit = .integrator
        case .differentiator: circuit = .differentiator
        }
        return blankSolution(for: circuit)
    }

    private static func blankSolution(for circuit: ElectronicsCircuit) -> LabSolution {
        LabSolution(
            circuit: circuit, headline: "", elements: [], nodes: [], branches: [],
            quantities: [], steps: [], notes: []
        )
    }
}

// MARK: - Seat geometry

/// Where a part's pins land. Pins 1…n/2 run along row e from the notch end, the rest come back along row f.
struct WBSeat {
    let part: WorkbenchOpAmpPart
    let origin: Int

    var perRow: Int { part.pinCount / 2 }
    func isTop(_ pin: Int) -> Bool { pin <= perRow }

    func column(_ pin: Int) -> Int {
        isTop(pin) ? origin + pin - 1 : origin + part.pinCount - pin
    }

    var sumCol: Int { column(part.primary.inMinus) }
    var plusCol: Int { column(part.primary.inPlus) }
    var outCol: Int { column(part.primary.out) }
    var outIsTop: Bool { isTop(part.primary.out) }
    var rightEdge: Int { origin + perRow - 1 }
    /// Free columns to the right of the package, nearest first.
    var crossCol: Int { rightEdge + 2 }
    var bridgeCol: Int { rightEdge + 4 }
    var gndA: Int { rightEdge + 6 }
    var gndB: Int { rightEdge + 7 }
}

enum WBHalf { case top, bottom }

struct WBEnd {
    var col: Int
    var net: String

    init(_ col: Int, _ net: String) {
        self.col = col
        self.net = net
    }
}

/// Fixed left-hand columns shared by the stage and filter boards.
private enum WBLeft {
    static let vin = 7
    static let v2 = 8
    /// Where the output lands in the top half, left of the package.
    static let out = 9
    /// The junction between the two Sallen–Key arms.
    static let junction = 11
}

// MARK: - Placement engine

extension BreadboardBuilder {
    private static let topLanes: [BBRow] = [.b, .c, .d, .a]
    private static let bottomLanes: [BBRow] = [.i, .h, .g, .j]
    /// Closest to the package first. Short hops and tie-offs go here.
    private static let topNear: [BBRow] = [.d, .c, .b, .a]
    private static let bottomNear: [BBRow] = [.g, .h, .i, .j]

    mutating func fail(_ line: Int, _ id: String = "") {
        failed = true
        if failure.isEmpty { failure = "WorkbenchBoards.swift:\(line) \(id)" }
    }

    func isTaken(_ hole: BBHole) -> Bool {
        if bodyHoles.contains(hole) { return true }
        if components.contains(where: { $0.leads.contains { $0.hole == hole } }) { return true }
        if jumpers.contains(where: { $0.a == hole || $0.b == hole }) { return true }
        return supplies.contains { $0.leads.contains { $0.hole == hole } }
    }

    /// Claims the first row that is free along the whole span, so two parts never lie across each other.
    mutating func claimLane(_ c1: Int, _ c2: Int, half: WBHalf, prefer: [BBRow]? = nil) -> BBRow? {
        let low = min(c1, c2)
        let high = max(c1, c2)
        guard low >= 1, high <= BreadboardBoard.columns else { return nil }
        let order = prefer ?? (half == .top ? Self.topLanes : Self.bottomLanes)
        for row in order {
            let span = (low...high).map { BBHole(column: $0, row: row) }
            if span.allSatisfy({ !isTaken($0) }) {
                for hole in span { bodyHoles.insert(hole) }
                return row
            }
        }
        return nil
    }

    func nearLanes(_ half: WBHalf) -> [BBRow] {
        half == .top ? Self.topNear : Self.bottomNear
    }

    mutating func wbWire(
        _ id: String, _ net: String, _ color: BBWireColor,
        from c1: Int, to c2: Int, half: WBHalf, prefer: [BBRow]? = nil
    ) {
        guard c1 != c2, let row = claimLane(c1, c2, half: half, prefer: prefer) else {
            fail(#line, id)
            return
        }
        jumper(id, net, c1, row, c2, row, color)
    }

    /// A short vertical wire from the row beside the rail up to the rail itself.
    mutating func wbRail(_ id: String, _ net: String, _ color: BBWireColor, col: Int, half: WBHalf, rail: BBRow) {
        let lane: BBRow = half == .top ? .a : .j
        let start = BBHole(column: col, row: lane)
        let end = BBHole(column: col, row: rail)
        guard !isTaken(start), !isTaken(end) else {
            fail(#line, id)
            return
        }
        bodyHoles.insert(start)
        jumper(id, net, col, lane, col, rail, color)
    }

    /// Joins the top and bottom half of one column across the gutter.
    mutating func wbCross(_ id: String, _ net: String, _ color: BBWireColor, col: Int) {
        let top = BBHole(column: col, row: .e)
        let bottom = BBHole(column: col, row: .f)
        guard !isTaken(top), !isTaken(bottom) else {
            fail(#line, id)
            return
        }
        jumper(id, net, col, .e, col, .f, color)
    }

    mutating func wbResistor(
        _ id: String, _ name: String, _ ohms: Double?, _ a: WBEnd, _ b: WBEnd,
        half: WBHalf = .top, prefer: [BBRow]? = nil
    ) {
        guard let ohms, ohms > 0, let row = claimLane(a.col, b.col, half: half, prefer: prefer) else {
            fail(#line, id)
            return
        }
        resistor(id, name, ohms, hole(a.col, row, a.net), hole(b.col, row, b.net))
    }

    mutating func wbCapacitor(
        _ id: String, _ name: String, _ farads: Double?, positive: WBEnd, negative: WBEnd,
        half: WBHalf = .top, prefer: [BBRow]? = nil
    ) {
        guard let farads, farads > 0, let row = claimLane(positive.col, negative.col, half: half, prefer: prefer) else {
            fail(#line, id)
            return
        }
        wbNonPolarCapacitor(id, name, farads, hole(positive.col, row, positive.net), hole(negative.col, row, negative.net))
    }

    /// Filter and amplifier caps sit in bipolar signal paths, so they are drawn as film or ceramic parts at every value.
    /// An electrolytic there would be reverse-biased for half of every cycle.
    mutating func wbNonPolarCapacitor(_ id: String, _ name: String, _ farads: Double, _ a: BBLead, _ b: BBLead) {
        components.append(BBComponent(
            id: id,
            part: .ceramic(farads: farads, label: "\(name) \(BreadboardFormat.farads(farads))"),
            leads: [a, b]
        ))
    }

    /// A part standing across the gutter in one column. The top half is lead 0.
    mutating func wbVerticalResistor(_ id: String, _ name: String, _ ohms: Double?, col: Int, top: String, bottom: String) {
        let upper = BBHole(column: col, row: .e)
        let lower = BBHole(column: col, row: .f)
        guard let ohms, ohms > 0, !isTaken(upper), !isTaken(lower) else {
            fail(#line, id)
            return
        }
        resistor(id, name, ohms, hole(col, .e, top), hole(col, .f, bottom))
    }

    mutating func wbVerticalCapacitor(_ id: String, _ name: String, _ farads: Double?, col: Int, top: String, bottom: String) {
        let upper = BBHole(column: col, row: .e)
        let lower = BBHole(column: col, row: .f)
        guard let farads, farads > 0, !isTaken(upper), !isTaken(lower) else {
            fail(#line, id)
            return
        }
        wbNonPolarCapacitor(id, name, farads, hole(col, .e, top), hole(col, .f, bottom))
    }

    /// A signal source standing in as a cell. Its + lead is in `plusCol`, its − lead three columns left on the ground rail.
    mutating func wbCell(_ id: String, label: String, net: String, plusCol: Int) {
        let minusCol = plusCol - 3
        guard let row = claimLane(minusCol, plusCol, half: .top, prefer: [.d, .c, .b]) else {
            fail(#line)
            return
        }
        components.append(BBComponent(id: id, part: .source(label: label), leads: [
            hole(plusCol, row, net),
            hole(minusCol, row, "GND"),
        ]))
        wbRail("g\(id)", "GND", .black, col: minusCol, half: .top, rail: .topMinus)
    }

    func leadHole(_ id: String, _ index: Int) -> BBHole? {
        guard let component = components.first(where: { $0.id == id }), index < component.leads.count else { return nil }
        return component.leads[index].hole
    }

    // MARK: Seating a real package

    /// Seats the package, powers it from ±V, ties off every spare amplifier, and brings the output to the
    /// top half at the shared output column. `sumNet` and `plusNet` name the nets on the used amplifier's inputs.
    mutating func wbSeatOpAmp(
        _ seat: WBSeat,
        sumNet: String,
        plusNet: String,
        bottomOutput: Bool = false
    ) {
        let part = seat.part
        let amp = part.primary
        var nets: [Int: String] = [:]
        for pin in 1...part.pinCount { nets[pin] = "NC\(pin)" }
        nets[amp.inMinus] = sumNet
        nets[amp.inPlus] = plusNet
        nets[amp.out] = "Vout"
        nets[part.vPlus] = "+V"
        nets[part.vMinus] = "−V"
        for spare in part.spares {
            nets[spare.inMinus] = "TIE\(spare.letter)"
            nets[spare.out] = "TIE\(spare.letter)"
            nets[spare.inPlus] = "GND"
        }
        let labels = part.pinLabels
        let pins: [(String, String)] = (1...part.pinCount).map { (labels[$0 - 1], nets[$0] ?? "") }
        _ = dip("u", part.name, origin: seat.origin, pins: pins)

        // Supply pins. +V is on the red rails, −V on the bottom blue rail.
        let plusCol = seat.column(part.vPlus)
        if seat.isTop(part.vPlus) {
            wbRail("v+", "+V", .red, col: plusCol, half: .top, rail: .topPlus)
        } else {
            wbRail("v+", "+V", .red, col: plusCol, half: .bottom, rail: .botPlus)
        }
        let minusCol = seat.column(part.vMinus)
        if seat.isTop(part.vMinus) {
            // −V only exists on the bottom rail, so hop right, cross the gutter, and drop down.
            wbWire("v-hop", "−V", .blue, from: minusCol, to: seat.crossCol, half: .top, prefer: [.a, .b, .c, .d])
            wbCross("v-cross", "−V", .blue, col: seat.crossCol)
            wbRail("v-rail", "−V", .blue, col: seat.crossCol, half: .bottom, rail: .botMinus)
        } else {
            wbRail("v-", "−V", .blue, col: minusCol, half: .bottom, rail: .botMinus)
        }

        // Spare amplifiers: output to IN−, IN+ to ground, so no input floats.
        var bridged = false
        for spare in part.spares {
            let half: WBHalf = seat.isTop(spare.inMinus) ? .top : .bottom
            wbWire(
                "tie\(spare.letter)", "TIE\(spare.letter)", .white,
                from: seat.column(spare.inMinus), to: seat.column(spare.out),
                half: half, prefer: half == .top ? [.a, .d, .c, .b] : nearLanes(half)
            )
            if half == .top {
                wbRail("gnd\(spare.letter)", "GND", .black, col: seat.column(spare.inPlus), half: .top, rail: .topMinus)
            } else {
                if !bridged {
                    let hole = BBHole(column: seat.bridgeCol, row: .g)
                    guard !isTaken(hole) else {
                        fail(#line)
                        return
                    }
                    bodyHoles.insert(hole)
                    jumper("gnd-bridge", "GND", seat.bridgeCol, .topMinus, seat.bridgeCol, .g, .black)
                    bridged = true
                }
                wbWire(
                    "gnd\(spare.letter)", "GND", .black,
                    from: seat.column(spare.inPlus), to: seat.bridgeCol,
                    half: .bottom, prefer: [.i, .h, .j]
                )
            }
        }

        // Output to the shared column in the top half. A single-amp part has OUT on the bottom row.
        let target = WBLeft.out
        if seat.outIsTop {
            wbWire("out", "Vout", .green, from: seat.outCol, to: target, half: .top, prefer: [.d, .c, .b, .a])
            if bottomOutput { wbCross("out-x", "Vout", .green, col: target) }
        } else {
            wbWire("out", "Vout", .green, from: seat.outCol, to: target, half: .bottom, prefer: [.i, .h, .g, .j])
            wbCross("out-x", "Vout", .green, col: target)
        }
    }

    // MARK: Finishing

    /// Returns nil when a placement ran out of room, so the app never draws a board that is wrong.
    func wbFinish(_ specific: String, meters: [BBMeter] = []) -> BreadboardLayout? {
        guard !failed else {
            WorkbenchBoards.lastFailure = failure
            return nil
        }
        var layout = finish(caption(specific))
        layout.meters = meters
        return layout
    }

    func wbVoltageChip(_ id: String, _ title: String, _ volts: Double?, at hole: BBHole?) -> BBMeter? {
        guard let volts, volts.isFinite, let hole else { return nil }
        return BBMeter(id: id, kind: .voltage, title: title, reading: LabKit.si(volts, unit: "V"), hole: hole)
    }

    func wbVoltsLabel(_ value: Double?, fallback: String) -> String {
        guard let value, value.isFinite else { return fallback }
        return BreadboardFormat.trim(value) + " V"
    }

    /// Which pins the used amplifier takes, and what happens to the rest of the package.
    func wbPartSentence(_ seat: WBSeat) -> String {
        let part = seat.part
        let amp = part.primary
        var text = "\(part.name) (\(part.kindLabel) op-amp, \(part.packageLabel)): notch to the left, pin 1 at the lower left, pins count counter-clockwise like the real package. "
        if part.spares.isEmpty {
            text += "IN− is pin \(amp.inMinus), IN+ pin \(amp.inPlus), OUT pin \(amp.out), V+ pin \(part.vPlus), V− pin \(part.vMinus). "
        } else {
            text += "Amp \(amp.letter) is wired: IN− pin \(amp.inMinus), IN+ pin \(amp.inPlus), OUT pin \(amp.out). V+ is pin \(part.vPlus) and V− is pin \(part.vMinus). "
            let spares = part.spares.map { "\($0.letter) (pins \($0.inMinus), \($0.inPlus), \($0.out))" }.joined(separator: ", ")
            text += "Spare amp \(spares) is tied off with white jumpers: output to IN−, IN+ to ground, so no input floats. "
        }
        text += "Red jumpers are +V, blue is −V, black is ground, green is Vout. Both rails are ±V. "
        return text
    }
}

// MARK: - Op-amp stage boards

extension BreadboardBuilder {
    private func cellLabel(_ name: String, _ volts: Double?) -> String {
        guard let volts, volts.isFinite else { return name }
        return "\(name) \(BreadboardFormat.trim(volts)) V"
    }

    private func stageMeters(vin: Double?, vinNet: String, output: Double?) -> [BBMeter] {
        var meters: [BBMeter] = []
        let vinHole = components.first { $0.id == "vin" }?.leads.first?.hole
        if let chip = wbVoltageChip("v-vin", vinNet, vin, at: vinHole) { meters.append(chip) }
        let voutHole = components.first { $0.id == "rf" || $0.id == "c" }?.leads.first { $0.net == "Vout" }?.hole
            ?? jumpers.first { $0.id == "out" }?.b
        if let chip = wbVoltageChip("v-vout", "Vout", output, at: voutHole) { meters.append(chip) }
        return meters
    }

    mutating func wbInverting(_ seat: WBSeat, _ v: WorkbenchStageValues) -> BreadboardLayout? {
        dualSupply()
        wbSeatOpAmp(seat, sumNet: "SUM", plusNet: "GND")
        wbRail("plus-gnd", "GND", .black, col: seat.plusCol, half: .top, rail: .topMinus)
        wbCell("vin", label: cellLabel("Vin", v.vin), net: "Vin", plusCol: WBLeft.vin)
        wbResistor("rin", "Rin", v.rin, WBEnd(WBLeft.vin, "Vin"), WBEnd(seat.sumCol, "SUM"))
        wbResistor("rf", "Rf", v.rf, WBEnd(WBLeft.out, "Vout"), WBEnd(seat.sumCol, "SUM"))
        return wbFinish(
            wbPartSentence(seat)
                + "Inverting stage: Rin brings Vin to the − input and Rf feeds the output back to it. IN+ is on ground, so the − input sits at a virtual ground and Vout = −(Rf/Rin)·Vin.",
            meters: stageMeters(vin: v.vin, vinNet: "Vin", output: v.outputVolts)
        )
    }

    mutating func wbNoninverting(_ seat: WBSeat, _ v: WorkbenchStageValues) -> BreadboardLayout? {
        dualSupply()
        wbSeatOpAmp(seat, sumNet: "SUM", plusNet: "Vin")
        wbCell("vin", label: cellLabel("Vin", v.vin), net: "Vin", plusCol: WBLeft.vin)
        wbWire("in", "Vin", .yellow, from: WBLeft.vin, to: seat.plusCol, half: .top)
        wbRail("rg-gnd", "GND", .black, col: seat.gndA, half: .top, rail: .topMinus)
        wbResistor("rf", "Rf", v.rf, WBEnd(WBLeft.out, "Vout"), WBEnd(seat.sumCol, "SUM"))
        wbResistor("rg", "Rg", v.rg, WBEnd(seat.sumCol, "SUM"), WBEnd(seat.gndA, "GND"))
        return wbFinish(
            wbPartSentence(seat)
                + "Non-inverting stage: the yellow jumper takes Vin to IN+. Rf feeds Vout back to IN− and Rg returns IN− to ground, so Vout = (1 + Rf/Rg)·Vin.",
            meters: stageMeters(vin: v.vin, vinNet: "Vin", output: v.outputVolts)
        )
    }

    mutating func wbFollower(_ seat: WBSeat, _ v: WorkbenchStageValues) -> BreadboardLayout? {
        dualSupply()
        wbSeatOpAmp(seat, sumNet: "Vout", plusNet: "Vin")
        wbCell("vin", label: cellLabel("Vin", v.vin), net: "Vin", plusCol: WBLeft.vin)
        wbWire("in", "Vin", .yellow, from: WBLeft.vin, to: seat.plusCol, half: .top)
        wbWire("fb", "Vout", .green, from: WBLeft.out, to: seat.sumCol, half: .top)
        return wbFinish(
            wbPartSentence(seat)
                + "Voltage follower: the yellow jumper takes Vin to IN+ and the green jumper ties Vout straight to IN−. Gain is 1 and the input draws almost no current.",
            meters: stageMeters(vin: v.vin, vinNet: "Vin", output: v.outputVolts)
        )
    }

    mutating func wbDifference(_ seat: WBSeat, _ v: WorkbenchStageValues) -> BreadboardLayout? {
        dualSupply()
        wbSeatOpAmp(seat, sumNet: "SUM", plusNet: "PLUS")
        wbRail("rf2-gnd", "GND", .black, col: seat.gndA, half: .top, rail: .topMinus)
        wbCell("vin", label: cellLabel("V1", v.v1), net: "V1", plusCol: WBLeft.vin)
        wbCell("vin2", label: cellLabel("V2", v.v2), net: "V2", plusCol: WBLeft.v2)
        wbResistor("rin", "Rin", v.rin, WBEnd(WBLeft.vin, "V1"), WBEnd(seat.sumCol, "SUM"))
        wbResistor("rin2", "Rin", v.rin, WBEnd(WBLeft.v2, "V2"), WBEnd(seat.plusCol, "PLUS"))
        wbResistor("rf", "Rf", v.rf, WBEnd(WBLeft.out, "Vout"), WBEnd(seat.sumCol, "SUM"))
        wbResistor("rf2", "Rf", v.rf, WBEnd(seat.plusCol, "PLUS"), WBEnd(seat.gndA, "GND"))
        var meters = stageMeters(vin: v.v1, vinNet: "V1", output: v.outputVolts)
        let v2Hole = components.first { $0.id == "vin2" }?.leads.first?.hole
        if let chip = wbVoltageChip("v-v2", "V2", v.v2, at: v2Hole) { meters.append(chip) }
        return wbFinish(
            wbPartSentence(seat)
                + "Difference amplifier: V1 goes through Rin to IN−, V2 through a matched Rin to IN+. The matched Rf pair sets the gain: Rf from Vout to IN− and Rf from IN+ to ground. Vout = (Rf/Rin)·(V2 − V1) when the pairs match.",
            meters: meters
        )
    }

    mutating func wbSumming(_ seat: WBSeat, _ v: WorkbenchStageValues) -> BreadboardLayout? {
        dualSupply()
        wbSeatOpAmp(seat, sumNet: "SUM", plusNet: "GND")
        wbRail("plus-gnd", "GND", .black, col: seat.plusCol, half: .top, rail: .topMinus)
        wbCell("vin", label: cellLabel("V1", v.v1), net: "V1", plusCol: WBLeft.vin)
        wbCell("vin2", label: cellLabel("V2", v.v2), net: "V2", plusCol: WBLeft.v2)
        wbResistor("r1", "R1", v.r1, WBEnd(WBLeft.vin, "V1"), WBEnd(seat.sumCol, "SUM"))
        wbResistor("r2", "R2", v.r2, WBEnd(WBLeft.v2, "V2"), WBEnd(seat.sumCol, "SUM"))
        wbResistor("rf", "Rf", v.rf, WBEnd(WBLeft.out, "Vout"), WBEnd(seat.sumCol, "SUM"))
        var meters = stageMeters(vin: v.v1, vinNet: "V1", output: v.outputVolts)
        let v2Hole = components.first { $0.id == "vin2" }?.leads.first?.hole
        if let chip = wbVoltageChip("v-v2", "V2", v.v2, at: v2Hole) { meters.append(chip) }
        return wbFinish(
            wbPartSentence(seat)
                + "Summing amplifier: V1 and V2 each feed IN− through their own resistor, IN+ is on ground, and Rf closes the loop. Vout = −Rf·(V1/R1 + V2/R2).",
            meters: meters
        )
    }

    mutating func wbIntegrator(_ seat: WBSeat, _ v: WorkbenchStageValues) -> BreadboardLayout? {
        dualSupply()
        wbSeatOpAmp(seat, sumNet: "SUM", plusNet: "GND")
        wbRail("plus-gnd", "GND", .black, col: seat.plusCol, half: .top, rail: .topMinus)
        wbCell("vin", label: cellLabel("Vin", v.vin), net: "Vin", plusCol: WBLeft.vin)
        wbResistor("rin", "Rin", v.rin, WBEnd(WBLeft.vin, "Vin"), WBEnd(seat.sumCol, "SUM"))
        wbCapacitor("c", "C", v.capacitance, positive: WBEnd(seat.sumCol, "SUM"), negative: WBEnd(WBLeft.out, "Vout"))
        return wbFinish(
            wbPartSentence(seat)
                + "Integrator: Rin feeds IN− and C closes the loop, so Vout ramps at −Vin/(Rin·C). A real one adds a large resistor across C to stop the output drifting to a rail. The ideal model leaves it out.",
            meters: stageMeters(vin: v.vin, vinNet: "Vin", output: nil)
        )
    }

    mutating func wbDifferentiator(_ seat: WBSeat, _ v: WorkbenchStageValues) -> BreadboardLayout? {
        dualSupply()
        wbSeatOpAmp(seat, sumNet: "SUM", plusNet: "GND")
        wbRail("plus-gnd", "GND", .black, col: seat.plusCol, half: .top, rail: .topMinus)
        wbCell("vin", label: cellLabel("Vin", v.vin), net: "Vin", plusCol: WBLeft.vin)
        wbCapacitor("c", "C", v.capacitance, positive: WBEnd(WBLeft.vin, "Vin"), negative: WBEnd(seat.sumCol, "SUM"))
        wbResistor("rf", "Rf", v.rf, WBEnd(WBLeft.out, "Vout"), WBEnd(seat.sumCol, "SUM"))
        return wbFinish(
            wbPartSentence(seat)
                + "Differentiator: C couples Vin into IN− and Rf closes the loop, so |Vout/Vin| = 2π·f·Rf·C. A real one adds a small series resistor with C to tame high-frequency gain. The ideal model leaves it out.",
            meters: stageMeters(vin: v.vin, vinNet: "Vin", output: v.outputVolts)
        )
    }
}

// MARK: - Filter boards

extension BreadboardBuilder {
    private func hz(_ value: Double) -> String {
        BreadboardFormat.trim(value) + "Hz"
    }

    /// First-order RC. The source is the red rail, ground is the blue rails.
    mutating func wbRC(_ f: WorkbenchFilterValues, lowpass: Bool) -> BreadboardLayout? {
        singleSupply("Vin", "Vin", "GND")
        let a = 6, b = 12, c = 18
        wbRail("vin", "Vin", .red, col: a, half: .top, rail: .topPlus)
        wbRail("gnd", "GND", .black, col: c, half: .top, rail: .topMinus)
        if lowpass {
            wbResistor("r", "R", f.resistance, WBEnd(a, "Vin"), WBEnd(b, "Vout"))
            wbCapacitor("c", "C", f.capacitance, positive: WBEnd(b, "Vout"), negative: WBEnd(c, "GND"))
        } else {
            wbCapacitor("c", "C", f.capacitance, positive: WBEnd(a, "Vin"), negative: WBEnd(b, "Vout"))
            wbResistor("r", "R", f.resistance, WBEnd(b, "Vout"), WBEnd(c, "GND"))
        }
        let probe = wbVoltageChip("v-out", "Vout", nil, at: nil)
        _ = probe
        let shape = lowpass
            ? "Low-pass: R is in series and C shunts the output to ground."
            : "High-pass: C is in series and R shunts the output to ground."
        return wbFinish("\(shape) Corner fc = 1/(2πRC) = \(hz(f.cornerHz)). The red rail is the source, the blue rails are ground, and Vout is the middle node. No IC: a passive RC needs none, and a load will pull the corner.")
    }

    /// Twin-T notch. Series R–R and C–C paths, with 2C and R/2 to ground standing across the gutter.
    mutating func wbTwinT(_ f: WorkbenchFilterValues) -> BreadboardLayout? {
        singleSupply("Vin", "Vin", "GND")
        let vin = 6, a = 12, b = 16, out = 20
        wbRail("vin", "Vin", .red, col: vin, half: .top, rail: .topPlus)
        wbResistor("r1", "R", f.resistance, WBEnd(vin, "Vin"), WBEnd(a, "NA"))
        wbResistor("r2", "R", f.resistance, WBEnd(a, "NA"), WBEnd(out, "Vout"))
        wbCapacitor("c1", "C", f.capacitance, positive: WBEnd(vin, "Vin"), negative: WBEnd(b, "NB"))
        wbCapacitor("c2", "C", f.capacitance, positive: WBEnd(b, "NB"), negative: WBEnd(out, "Vout"))
        wbVerticalCapacitor("c3", "2C", f.capacitance * 2, col: a, top: "NA", bottom: "GND")
        wbRail("c3-gnd", "GND", .black, col: a, half: .bottom, rail: .botMinus)
        wbVerticalResistor("r3", "R/2", f.resistance / 2, col: b, top: "NB", bottom: "GND")
        wbRail("r3-gnd", "GND", .black, col: b, half: .bottom, rail: .botMinus)
        return wbFinish("Twin-T notch: one T of R–R with 2C to ground, one T of C–C with R/2 to ground, both from Vin to Vout. The 2C and R/2 parts stand across the gutter and return to ground on the bottom blue rail. Notch f0 = 1/(2πRC) = \(hz(f.cornerHz)). Passive, so the notch is shallow and a load shifts it.")
    }

    /// First-order all-pass: an RC on IN+, and two equal resistors around IN−.
    mutating func wbAllpass(_ seat: WBSeat, _ f: WorkbenchFilterValues) -> BreadboardLayout? {
        dualSupply()
        wbSeatOpAmp(seat, sumNet: "SUM", plusNet: "PLUS")
        wbRail("c-gnd", "GND", .black, col: seat.gndA, half: .top, rail: .topMinus)
        wbCell("vin", label: "Vin", net: "Vin", plusCol: WBLeft.vin)
        wbResistor("r", "R", f.resistance, WBEnd(WBLeft.vin, "Vin"), WBEnd(seat.plusCol, "PLUS"))
        wbResistor("ra", "Ra", f.resistance, WBEnd(WBLeft.vin, "Vin"), WBEnd(seat.sumCol, "SUM"))
        wbResistor("rb", "Rb", f.resistance, WBEnd(WBLeft.out, "Vout"), WBEnd(seat.sumCol, "SUM"))
        wbCapacitor("c", "C", f.capacitance, positive: WBEnd(seat.plusCol, "PLUS"), negative: WBEnd(seat.gndA, "GND"))
        return wbFinish(
            wbPartSentence(seat)
                + "All-pass: R and C on IN+ set the phase corner \(hz(f.cornerHz)). Ra and Rb are an equal pair around IN−, so the gain stays at 1 at every frequency and only the phase moves, from 0° toward −180°."
        )
    }

    /// Equal-component Sallen–Key. Vin → R1 → A → R2 → IN+. The feedback part runs from A to Vout across the
    /// gutter, the shunt part from IN+ to ground. Ra and Rb set the amplifier gain K.
    mutating func wbSallenKey(_ seat: WBSeat, _ f: WorkbenchFilterValues, lowpass: Bool) -> BreadboardLayout? {
        dualSupply()
        let k0 = f.sallenKeyK ?? 1
        wbSeatOpAmp(seat, sumNet: k0 > 1.0001 ? "SUM" : "Vout", plusNet: "PLUS", bottomOutput: true)
        let junction = WBLeft.junction
        wbCell("vin", label: "Vin", net: "Vin", plusCol: WBLeft.vin)
        wbRail("shunt-gnd", "GND", .black, col: seat.gndA, half: .top, rail: .topMinus)
        let k = f.sallenKeyK ?? 1
        let needsGain = k > 1.0001
        if needsGain {
            wbRail("ra-gnd", "GND", .black, col: seat.gndB, half: .top, rail: .topMinus)
        }
        // Vout also on the bottom half, so the feedback part can stand across the gutter at the junction column.
        wbWire("out-b", "Vout", .green, from: WBLeft.out, to: junction, half: .bottom, prefer: [.h, .g, .i, .j])
        if needsGain {
            wbResistor("rb", "Rb", (k - 1) * f.resistance, WBEnd(WBLeft.out, "Vout"), WBEnd(seat.sumCol, "SUM"))
            wbResistor("ra", "Ra", f.resistance, WBEnd(seat.sumCol, "SUM"), WBEnd(seat.gndB, "GND"))
        } else {
            wbWire("fb", "Vout", .green, from: WBLeft.out, to: seat.sumCol, half: .top)
        }
        if lowpass {
            wbResistor("r1", "R1", f.resistance, WBEnd(WBLeft.vin, "Vin"), WBEnd(junction, "NA"))
            wbResistor("r2", "R2", f.resistance, WBEnd(junction, "NA"), WBEnd(seat.plusCol, "PLUS"))
            wbVerticalCapacitor("c1", "C1", f.capacitance, col: junction, top: "NA", bottom: "Vout")
            wbCapacitor("c2", "C2", f.capacitance, positive: WBEnd(seat.plusCol, "PLUS"), negative: WBEnd(seat.gndA, "GND"))
        } else {
            wbCapacitor("c1", "C1", f.capacitance, positive: WBEnd(WBLeft.vin, "Vin"), negative: WBEnd(junction, "NA"))
            wbCapacitor("c2", "C2", f.capacitance, positive: WBEnd(junction, "NA"), negative: WBEnd(seat.plusCol, "PLUS"))
            wbVerticalResistor("r1", "R1", f.resistance, col: junction, top: "NA", bottom: "Vout")
            wbResistor("r2", "R2", f.resistance, WBEnd(seat.plusCol, "PLUS"), WBEnd(seat.gndA, "GND"))
        }
        let shape = lowpass ? "Low-pass" : "High-pass"
        let arms = lowpass
            ? "R1 and R2 run in series to IN+, C1 returns from the R1–R2 junction to Vout across the gutter, and C2 shunts IN+ to ground."
            : "C1 and C2 run in series to IN+, R1 returns from the C1–C2 junction to Vout across the gutter, and R2 shunts IN+ to ground."
        let gain = needsGain
            ? "Ra and Rb make the amplifier gain K = 1 + Rb/Ra = \(BreadboardFormat.trim(k)), which sets Q = \(BreadboardFormat.trim(f.quality))."
            : "Q ≤ 0.5 needs no gain, so the amplifier is a follower (K = 1)."
        return wbFinish(
            wbPartSentence(seat)
                + "Sallen–Key \(shape.lowercased()) at \(hz(f.cornerHz)): \(arms) \(gain)"
        )
    }
}
