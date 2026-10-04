import Foundation

/// Solderless breadboard hookup for Electronics Lab circuits that map onto
/// DIP packages and discrete parts. Rows a–e in one column are one node, f–j
/// are the other, and each power rail is one node along the board.
///
/// This is an illustrative layout of the teaching netlist. It is not a SPICE
/// board file, a router, or a fabrication drawing.
public enum BBRow: String, CaseIterable, Sendable, Equatable {
    case topPlus, topMinus
    case a, b, c, d, e
    case f, g, h, i, j
    case botMinus, botPlus

    public var isRail: Bool {
        switch self {
        case .topPlus, .topMinus, .botMinus, .botPlus: return true
        default: return false
        }
    }

    /// Vertical order on the board, in hole pitches. The gutter sits between e and f.
    public var unitY: Double {
        switch self {
        case .topPlus: return 0
        case .topMinus: return 1
        case .a: return 2.55
        case .b: return 3.55
        case .c: return 4.55
        case .d: return 5.55
        case .e: return 6.55
        case .f: return 8.85
        case .g: return 9.85
        case .h: return 10.85
        case .i: return 11.85
        case .j: return 12.85
        case .botMinus: return 14.4
        case .botPlus: return 15.4
        }
    }
}

public struct BBHole: Hashable, Sendable, Equatable {
    public var column: Int
    public var row: BBRow

    public init(column: Int, row: BBRow) {
        self.column = column
        self.row = row
    }
}

public struct BBLead: Equatable, Sendable {
    public var hole: BBHole
    public var net: String

    public init(hole: BBHole, net: String) {
        self.hole = hole
        self.net = net
    }
}

public enum BBWireColor: String, Sendable, Equatable {
    case red, black, blue, yellow, green, orange, violet, white
}

public enum BBPart: Equatable, Sendable {
    /// Axial resistor. `bands` are 4-band names (digit, digit, multiplier, tolerance) or empty when the value will not encode.
    case resistor(ohms: Double, label: String, bands: [String])
    case ceramic(farads: Double, label: String)
    /// Lead 0 is the positive lead.
    case electrolytic(farads: Double, label: String)
    /// Lead 0 is the anode.
    case led(label: String)
    /// Signal diode. Lead 0 is the anode, lead 1 the cathode (banded end).
    case diode(label: String)
    /// Axial inductor.
    case inductor(henries: Double, label: String)
    /// Leads E, B, C. 2N3904, flat face up.
    case npn(name: String)
    /// Leads S, G, D. 2N7000, flat face up.
    case nmos(name: String)
    /// Leads S, G, D. P-channel TO-92 stand-in, flat face up.
    case pmos(name: String)
    /// Leads are pins 1…8. Pin 1 is the notch end on the top strip.
    case dip8(name: String, pins: [String])
    /// Leads are pins 1…14, pin 1 at the notch end, counting along row e and back along row f.
    case dip14(name: String, pins: [String])
    /// Leads are pins 1…10 of a common-cathode 5161AS-style digit. `mask` bits are a…g.
    case display(name: String, digit: Int, mask: Int, pins: [String])
    /// Lead 0 positive, lead 1 negative.
    case source(label: String)
}

public struct BBComponent: Equatable, Sendable, Identifiable {
    public var id: String
    public var part: BBPart
    public var leads: [BBLead]

    public init(id: String, part: BBPart, leads: [BBLead]) {
        self.id = id
        self.part = part
        self.leads = leads
    }
}

public struct BBJumper: Equatable, Sendable, Identifiable {
    public var id: String
    public var net: String
    public var a: BBHole
    public var b: BBHole
    public var color: BBWireColor

    public init(id: String, net: String, a: BBHole, b: BBHole, color: BBWireColor) {
        self.id = id
        self.net = net
        self.a = a
        self.b = b
        self.color = color
    }
}

public struct BBSupply: Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var leads: [BBLead]

    public init(id: String, label: String, leads: [BBLead]) {
        self.id = id
        self.label = label
        self.leads = leads
    }
}

public struct BBRailLabel: Equatable, Sendable {
    public var row: BBRow
    public var text: String

    public init(row: BBRow, text: String) {
        self.row = row
        self.text = text
    }
}


/// On-board voltage or current chip. Anchored to a hole so the canvas can place it.
public struct BBMeter: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable, Equatable {
        case voltage
        case current
    }

    public var id: String
    public var kind: Kind
    public var title: String
    public var reading: String
    public var hole: BBHole

    public init(id: String, kind: Kind, title: String, reading: String, hole: BBHole) {
        self.id = id
        self.kind = kind
        self.title = title
        self.reading = reading
        self.hole = hole
    }
}

public struct BreadboardLayout: Equatable, Sendable {
    public var circuit: ElectronicsCircuit
    public var components: [BBComponent]
    public var jumpers: [BBJumper]
    public var supplies: [BBSupply]
    public var railLabels: [BBRailLabel]
    public var caption: String
    public var columns: Int
    /// Compact on-board I/V chips derived from the solved schematic.
    public var meters: [BBMeter]

    public init(
        circuit: ElectronicsCircuit,
        components: [BBComponent],
        jumpers: [BBJumper],
        supplies: [BBSupply],
        railLabels: [BBRailLabel],
        caption: String,
        columns: Int = BreadboardBoard.columns,
        meters: [BBMeter] = []
    ) {
        self.circuit = circuit
        self.components = components
        self.jumpers = jumpers
        self.supplies = supplies
        self.railLabels = railLabels
        self.caption = caption
        self.columns = columns
        self.meters = meters
    }

    public func component(_ id: String) -> BBComponent? {
        components.first { $0.id == id }
    }
}

public enum BreadboardBoard {
    public static let columns = 30
    public static let gutterAfterE: Double = 8.85

    /// Electrical node of a hole before jumpers are applied.
    public static func group(_ hole: BBHole) -> String {
        switch hole.row {
        case .topPlus: return "rail:top+"
        case .topMinus: return "rail:top-"
        case .botPlus: return "rail:bot+"
        case .botMinus: return "rail:bot-"
        case .a, .b, .c, .d, .e: return "top:\(hole.column)"
        case .f, .g, .h, .i, .j: return "bot:\(hole.column)"
        }
    }

    public static func onBoard(_ hole: BBHole, columns: Int = columns) -> Bool {
        hole.column >= 1 && hole.column <= columns
    }
}

public struct BBPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum BreadboardRoute {
    /// Manhattan polyline in board units. Endpoints sit on the holes. Segments are axis-aligned.
    public static func manhattan(from: BBHole, to: BBHole) -> [BBPoint] {
        let start = BBPoint(x: Double(from.column), y: from.row.unitY)
        let end = BBPoint(x: Double(to.column), y: to.row.unitY)
        if from.column == to.column || from.row == to.row {
            return [start, end]
        }
        return [start, BBPoint(x: end.x, y: start.y), end]
    }
}

public struct BreadboardAudit: Equatable, Sendable {
    public var ok: Bool
    public var shorts: [String]
    public var opens: [String]
    public var clashes: [String]
    public var faults: [String]

    public init(ok: Bool, shorts: [String], opens: [String], clashes: [String], faults: [String]) {
        self.ok = ok
        self.shorts = shorts
        self.opens = opens
        self.clashes = clashes
        self.faults = faults
    }
}

public enum BreadboardNetlist {
    public static func audit(_ layout: BreadboardLayout) -> BreadboardAudit {
        var shorts: [String] = []
        var opens: [String] = []
        var clashes: [String] = []
        var faults: [String] = []
        var used: [BBHole: String] = [:]

        func claim(_ hole: BBHole, _ who: String) {
            if !BreadboardBoard.onBoard(hole, columns: layout.columns) {
                faults.append("\(who) is off the board")
            }
            if let prior = used[hole] {
                clashes.append("\(who) shares \(hole.column)\(hole.row.rawValue) with \(prior)")
            } else {
                used[hole] = who
            }
        }

        var touches: [(group: String, net: String)] = []
        for component in layout.components {
            for (index, lead) in component.leads.enumerated() {
                claim(lead.hole, "\(component.id)#\(index)")
                guard !lead.net.isEmpty else {
                    faults.append("\(component.id) lead \(index) has no net")
                    continue
                }
                touches.append((BreadboardBoard.group(lead.hole), lead.net))
            }
            faults.append(contentsOf: partFaults(component))
        }
        for supply in layout.supplies {
            for (index, lead) in supply.leads.enumerated() {
                claim(lead.hole, "\(supply.id)#\(index)")
                guard lead.hole.row.isRail else {
                    faults.append("\(supply.id) lead \(index) is not on a rail")
                    continue
                }
                touches.append((BreadboardBoard.group(lead.hole), lead.net))
            }
        }

        var parent: [String: String] = [:]
        func find(_ group: String) -> String {
            if parent[group] == nil { parent[group] = group }
            if parent[group] != group { parent[group] = find(parent[group]!) }
            return parent[group]!
        }
        func unite(_ a: String, _ b: String) {
            let ra = find(a)
            let rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for jumper in layout.jumpers {
            if jumper.a == jumper.b { faults.append("\(jumper.id) starts and ends in one hole") }
            claim(jumper.a, jumper.id)
            claim(jumper.b, jumper.id)
            guard !jumper.net.isEmpty else {
                faults.append("\(jumper.id) has no net")
                continue
            }
            let ga = BreadboardBoard.group(jumper.a)
            let gb = BreadboardBoard.group(jumper.b)
            unite(ga, gb)
            touches.append((ga, jumper.net))
            touches.append((gb, jumper.net))
            let bend = BreadboardRoute.manhattan(from: jumper.a, to: jumper.b)
            for index in 1..<bend.count {
                let prev = bend[index - 1]
                let next = bend[index]
                if prev.x != next.x && prev.y != next.y {
                    faults.append("\(jumper.id) is not Manhattan")
                }
            }
        }

        var netsByRoot: [String: Set<String>] = [:]
        var rootsByNet: [String: Set<String>] = [:]
        for touch in touches {
            let root = find(touch.group)
            netsByRoot[root, default: []].insert(touch.net)
            rootsByNet[touch.net, default: []].insert(root)
        }
        for (root, nets) in netsByRoot where nets.count > 1 {
            shorts.append("\(nets.sorted().joined(separator: " + ")) share \(root)")
        }
        for (net, roots) in rootsByNet where roots.count > 1 {
            opens.append("\(net) is split across \(roots.count) nodes")
        }

        let ok = shorts.isEmpty && opens.isEmpty && clashes.isEmpty && faults.isEmpty
        return BreadboardAudit(
            ok: ok,
            shorts: shorts.sorted(),
            opens: opens.sorted(),
            clashes: clashes.sorted(),
            faults: faults.sorted()
        )
    }

    private static func partFaults(_ component: BBComponent) -> [String] {
        let leads = component.leads
        switch component.part {
        case .resistor, .ceramic, .electrolytic, .led, .diode, .inductor, .source:
            guard leads.count == 2 else { return ["\(component.id) needs two leads"] }
            if leads[0].net == leads[1].net {
                return ["\(component.id) ties \(leads[0].net) to itself"]
            }
            if BreadboardBoard.group(leads[0].hole) == BreadboardBoard.group(leads[1].hole) {
                return ["\(component.id) is shorted by one breadboard node"]
            }
            return []
        case .npn, .nmos, .pmos:
            guard leads.count == 3 else { return ["\(component.id) needs three leads"] }
            let nets = Set(leads.map(\.net))
            if nets.count < 3 { return ["\(component.id) leads are not three nodes"] }
            return []
        case .dip8:
            guard leads.count == 8 else { return ["\(component.id) is not an 8-pin DIP"] }
            return dipSpanFaults(component.id, leads, pins: 4)
        case .dip14:
            guard leads.count == 14 else { return ["\(component.id) is not a 14-pin DIP"] }
            return dipSpanFaults(component.id, leads, pins: 7)
        case .display:
            guard leads.count == 10 else { return ["\(component.id) is not a 10-pin display"] }
            return dipSpanFaults(component.id, leads, pins: 5)
        }
    }

    /// Pin 1…n on row e, pin n+1…2n continuing back on row f.
    private static func dipSpanFaults(_ id: String, _ leads: [BBLead], pins: Int) -> [String] {
        let origin = leads[0].hole.column
        var faults: [String] = []
        for index in 0..<pins {
            let top = leads[index].hole
            let bottom = leads[2 * pins - 1 - index].hole
            if top.row != .e || bottom.row != .f || top.column != origin + index || bottom.column != origin + index {
                faults.append("\(id) pin \(index + 1) is not across the gutter")
            }
        }
        return faults
    }
}

public enum BreadboardBands {
    /// Nearest 4-band, 5% code. Empty when the value will not encode.
    public static func fourBand(ohms: Double) -> [String] {
        guard let coded = try? ResistorColorCode.encode(ohms: ohms, bands: 4, tolerance: .gold) else {
            return []
        }
        return coded.bands.map(\.rawValue)
    }
}

public enum BreadboardLayouts {
    public static let disclosure = "Breadboard is an illustrative solderless hookup of this circuit’s nodes. It is not a SPICE board file or a fabrication drawing."

    public static let supported: [ElectronicsCircuit] = [
        .seriesResistors, .parallelResistors, .voltageDivider, .kirchhoffLoop, .theveninNorton,
        .rcStep, .rlStep, .firstOrderFilter, .seriesRLC, .ledSeries,
        .halfWave, .fullBridge, .shuntClipper, .clamper,
        .bjtBias, .ceAmp, .bjtSwitch, .csAmp, .mosSwitch, .cmosInverter,
        .invertingAmp, .nonInvertingAmp, .summingAmp, .diffAmp, .integrator, .differentiator, .comparator,
        .astable555, .monostable555, .ledFlasher, .sevenSegment,
        .linearDrop,
        .discretePower, .opAmpPower,
    ]

    public static func supports(_ circuit: ElectronicsCircuit) -> Bool {
        supported.contains(circuit)
    }

    public static func make(_ solution: LabSolution) -> BreadboardLayout? {
        guard supports(solution.circuit) else { return nil }
        var built = BreadboardBuilder(solution)
        switch solution.circuit {
        case .seriesResistors: return built.series()
        case .parallelResistors: return built.parallel()
        case .voltageDivider: return built.divider()
        case .kirchhoffLoop: return built.kirchhoff()
        case .theveninNorton: return built.thevenin()
        case .rcStep: return built.rcStep()
        case .rlStep: return built.rlStep()
        case .firstOrderFilter: return built.filter()
        case .seriesRLC: return built.seriesRLC()
        case .ledSeries: return built.led()
        case .halfWave: return built.halfWave()
        case .fullBridge: return built.fullBridge()
        case .shuntClipper: return built.clipper()
        case .clamper: return built.clamper()
        case .bjtBias: return built.bjtBias()
        case .ceAmp: return built.ceAmp()
        case .bjtSwitch: return built.bjtSwitch()
        case .csAmp: return built.csAmp()
        case .mosSwitch: return built.mosSwitch()
        case .cmosInverter: return built.cmosInverter()
        case .invertingAmp: return built.inverting()
        case .nonInvertingAmp: return built.nonInverting()
        case .summingAmp: return built.summing()
        case .diffAmp: return built.difference()
        case .integrator: return built.integrator()
        case .differentiator: return built.differentiator()
        case .comparator: return built.comparator()
        case .astable555: return built.astable(withLED: false)
        case .monostable555: return built.monostable()
        case .ledFlasher: return built.astable(withLED: true)
        case .sevenSegment: return built.seven()
        case .linearDrop: return built.linearDrop()
        case .discretePower: return built.discretePowerStage()
        case .opAmpPower: return built.opAmpLoadStage()
        default: return nil
        }
    }
}

// MARK: - Builder

struct BreadboardBuilder {
    var solution: LabSolution
    var components: [BBComponent] = []
    var jumpers: [BBJumper] = []
    var supplies: [BBSupply] = []
    var railLabels: [BBRailLabel] = []
    /// Holes under a placed part or wire body, so a later part does not lie across them.
    var bodyHoles = Set<BBHole>()
    /// Set when a placement ran out of room. The board is then dropped instead of drawn wrong.
    var failed = false
    var failure = ""

    init(_ solution: LabSolution) {
        self.solution = solution
    }

    func qty(_ id: String) -> Double? { solution.quantity(id) }

    func finish(_ caption: String) -> BreadboardLayout {
        let bare = BreadboardLayout(
            circuit: solution.circuit,
            components: components,
            jumpers: jumpers,
            supplies: supplies,
            railLabels: railLabels,
            caption: caption
        )
        return BreadboardLayout(
            circuit: bare.circuit,
            components: bare.components,
            jumpers: bare.jumpers,
            supplies: bare.supplies,
            railLabels: bare.railLabels,
            caption: bare.caption,
            columns: bare.columns,
            meters: BreadboardMeters.make(solution: solution, layout: bare)
        )
    }

    func hole(_ column: Int, _ row: BBRow, _ net: String) -> BBLead {
        BBLead(hole: BBHole(column: column, row: row), net: net)
    }

    mutating func jumper(_ id: String, _ net: String, _ column: Int, _ row: BBRow, _ column2: Int, _ row2: BBRow, _ color: BBWireColor) {
        jumpers.append(BBJumper(
            id: id, net: net,
            a: BBHole(column: column, row: row),
            b: BBHole(column: column2, row: row2),
            color: color
        ))
    }

    mutating func resistor(_ id: String, _ name: String, _ ohms: Double, _ a: BBLead, _ b: BBLead) {
        let label = "\(name) \(BreadboardFormat.ohms(ohms))"
        components.append(BBComponent(
            id: id,
            part: .resistor(ohms: ohms, label: label, bands: BreadboardBands.fourBand(ohms: ohms)),
            leads: [a, b]
        ))
    }

    mutating func capacitor(_ id: String, _ name: String, _ farads: Double, _ positive: BBLead, _ negative: BBLead) {
        let label = "\(name) \(BreadboardFormat.farads(farads))"
        let part: BBPart = farads >= 1e-6
            ? .electrolytic(farads: farads, label: label)
            : .ceramic(farads: farads, label: label)
        components.append(BBComponent(id: id, part: part, leads: [positive, negative]))
    }

    mutating func diode(_ id: String, _ label: String, _ anode: BBLead, _ cathode: BBLead) {
        components.append(BBComponent(id: id, part: .diode(label: label), leads: [anode, cathode]))
    }

    mutating func inductor(_ id: String, _ name: String, _ henries: Double, _ a: BBLead, _ b: BBLead) {
        let label = "\(name) \(BreadboardFormat.henries(henries))"
        components.append(BBComponent(id: id, part: .inductor(henries: henries, label: label), leads: [a, b]))
    }

    mutating func singleSupply(_ label: String, _ positive: String, _ negative: String) {
        supplies.append(BBSupply(id: "ps", label: label, leads: [
            hole(2, .topPlus, positive),
            hole(2, .topMinus, negative),
        ]))
        jumper("tie+", positive, 30, .topPlus, 30, .botPlus, .red)
        jumper("tie-", negative, 29, .topMinus, 29, .botMinus, .black)
        railLabels = [
            BBRailLabel(row: .topPlus, text: positive),
            BBRailLabel(row: .botPlus, text: positive),
            BBRailLabel(row: .topMinus, text: negative),
            BBRailLabel(row: .botMinus, text: negative),
        ]
    }

    mutating func dualSupply() {
        supplies.append(BBSupply(id: "ps", label: "±V", leads: [
            hole(2, .topPlus, "+V"),
            hole(2, .topMinus, "GND"),
            hole(3, .botMinus, "−V"),
        ]))
        jumper("tie+", "+V", 30, .topPlus, 30, .botPlus, .red)
        railLabels = [
            BBRailLabel(row: .topPlus, text: "+V"),
            BBRailLabel(row: .botPlus, text: "+V"),
            BBRailLabel(row: .topMinus, text: "GND"),
            BBRailLabel(row: .botMinus, text: "−V"),
        ]
    }

    func caption(_ specific: String) -> String {
        specific + " " + BreadboardLayouts.disclosure + " Color bands are the nearest 5% code. The part label is the solved value."
    }

    mutating func dip8(_ id: String, _ name: String, origin: Int, pins: [(String, String)]) -> [BBLead] {
        dip(id, name, origin: origin, pins: pins)
    }

    /// 8 or 14 pins. Pins 1…n/2 run along row e from `origin`, the rest come back along row f.
    mutating func dip(_ id: String, _ name: String, origin: Int, pins: [(String, String)]) -> [BBLead] {
        let half = pins.count / 2
        var leads: [BBLead] = []
        for index in 0..<half {
            leads.append(hole(origin + index, .e, pins[index].1))
        }
        for index in 0..<half {
            leads.append(hole(origin + half - 1 - index, .f, pins[half + index].1))
        }
        let labels = pins.map(\.0)
        components.append(BBComponent(
            id: id,
            part: pins.count == 14 ? .dip14(name: name, pins: labels) : .dip8(name: name, pins: labels),
            leads: leads
        ))
        return leads
    }
}

enum BreadboardFormat {
    static func ohms(_ value: Double) -> String { trim(value) + "Ω" }
    static func farads(_ value: Double) -> String { trim(value) + "F" }
    static func henries(_ value: Double) -> String { trim(value) + "H" }

    static func trim(_ value: Double) -> String {
        let raw = LabKit.eng(value)
        guard let dot = raw.firstIndex(of: ".") else { return raw }
        var index = raw.index(after: dot)
        while index < raw.endIndex, raw[index].isNumber { index = raw.index(after: index) }
        var number = String(raw[..<index])
        let suffix = String(raw[index...])
        while number.last == "0" { number.removeLast() }
        if number.last == "." { number.removeLast() }
        return number + suffix
    }
}

// MARK: - Passive, RC, LED

extension BreadboardBuilder {
    mutating func series() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r1", "R1", r1, hole(6, .c, "Vs"), hole(14, .c, "V1"))
        resistor("r2", "R2", r2, hole(14, .a, "V1"), hole(24, .a, "GND"))
        jumper("vs", "Vs", 6, .e, 6, .topPlus, .red)
        jumper("mid", "V1", 14, .b, 14, .e, .yellow)
        jumper("probe", "V1", 14, .d, 22, .d, .yellow)
        jumper("gnd", "GND", 24, .e, 24, .topMinus, .black)
        jumper("gndb", "GND", 24, .b, 24, .botMinus, .black)
        return finish(caption("Series string along rows a–e. Vs is the red rail, ground is the blue rail, and the yellow jumpers mark V1 between R1 and R2."))
    }

    mutating func parallel() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r1", "R1", r1, hole(8, .e, "Vs"), hole(8, .f, "GND"))
        resistor("r2", "R2", r2, hole(16, .e, "Vs"), hole(16, .f, "GND"))
        jumper("vs1", "Vs", 8, .a, 8, .topPlus, .red)
        jumper("vs2", "Vs", 16, .b, 16, .topPlus, .red)
        jumper("vbus", "Vs", 8, .c, 24, .c, .red)
        jumper("vs3", "Vs", 24, .a, 24, .topPlus, .red)
        jumper("g1", "GND", 8, .j, 8, .botMinus, .black)
        jumper("g2", "GND", 16, .i, 16, .botMinus, .black)
        jumper("gbus", "GND", 8, .h, 24, .h, .black)
        jumper("g3", "GND", 24, .j, 24, .botMinus, .black)
        return finish(caption("Both resistors sit across the gutter, so each one sees the full source. Red and black buses tie the rails across the board."))
    }

    mutating func divider() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let vin = qty("vin") else { return nil }
        singleSupply(BreadboardFormat.trim(vin) + " V", "Vin", "GND")
        resistor("r1", "R1", r1, hole(6, .c, "Vin"), hole(14, .c, "Vout"))
        resistor("r2", "R2", r2, hole(14, .a, "Vout"), hole(24, .a, "GND"))
        jumper("vin", "Vin", 6, .e, 6, .topPlus, .red)
        jumper("gnd", "GND", 24, .e, 24, .topMinus, .black)
        jumper("gndb", "GND", 24, .b, 24, .botMinus, .black)
        jumper("out", "Vout", 14, .b, 22, .b, .yellow)
        jumper("tap", "Vout", 22, .e, 22, .f, .yellow)
        return finish(caption("R1 feeds the tap and R2 returns to the blue rail. The yellow jumpers are the unloaded tap brought across the gutter."))
    }

    mutating func kirchhoff() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let r3 = qty("r3"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r1", "R1", r1, hole(5, .c, "Vs"), hole(11, .c, "N1"))
        resistor("r2", "R2", r2, hole(11, .a, "N1"), hole(18, .a, "N2"))
        resistor("r3", "R3", r3, hole(18, .e, "N2"), hole(26, .e, "GND"))
        jumper("vs", "Vs", 5, .b, 5, .topPlus, .red)
        jumper("n1", "N1", 11, .b, 11, .e, .orange)
        jumper("n2", "N2", 18, .b, 18, .d, .yellow)
        jumper("gnd", "GND", 26, .b, 26, .topMinus, .black)
        jumper("gndb", "GND", 26, .a, 26, .botMinus, .black)
        return finish(caption("One series loop. Orange marks N1 after R1 and yellow marks N2 after R2, both measured to the blue rail."))
    }

    mutating func rcStep() -> BreadboardLayout? {
        guard let r = qty("r"), let c = qty("c"), let vinf = qty("vinf") else { return nil }
        singleSupply(BreadboardFormat.trim(vinf) + " V", "Vinf", "GND")
        resistor("r", "R", r, hole(6, .c, "Vinf"), hole(16, .c, "Vc"))
        capacitor("c", "C", c, hole(16, .e, "Vc"), hole(16, .f, "GND"))
        jumper("src", "Vinf", 6, .a, 6, .topPlus, .red)
        jumper("probe", "Vc", 16, .b, 24, .b, .yellow)
        jumper("gnd", "GND", 16, .j, 16, .botMinus, .black)
        jumper("gndb", "GND", 24, .j, 24, .botMinus, .black)
        return finish(caption("The capacitor’s positive lead is the Vc node; the yellow jumper is a probe point. At 1 µF and above it is an electrolytic; smaller values are ceramic discs."))
    }

    mutating func filter() -> BreadboardLayout? {
        guard let r = qty("r"), let c = qty("c") else { return nil }
        let low = filterIsLowpass()
        let chip: String
        if (qty("ac") ?? 1) >= 0.5, let vp = qty("vp") {
            chip = BreadboardFormat.trim(vp) + " Vpk"
        } else if let vdc = qty("vdc") {
            chip = BreadboardFormat.trim(vdc) + " Vdc"
        } else {
            chip = "Vin"
        }
        singleSupply(chip, "Vin", "GND")
        if low {
            resistor("r", "R", r, hole(6, .c, "Vin"), hole(16, .c, "Vout"))
            capacitor("c", "C", c, hole(16, .e, "Vout"), hole(16, .f, "GND"))
        } else {
            capacitor("c", "C", c, hole(6, .c, "Vin"), hole(16, .c, "Vout"))
            resistor("r", "R", r, hole(16, .e, "Vout"), hole(16, .f, "GND"))
        }
        jumper("vin", "Vin", 6, .a, 6, .topPlus, .red)
        jumper("out", "Vout", 16, .b, 24, .b, .yellow)
        jumper("gnd", "GND", 16, .j, 16, .botMinus, .black)
        jumper("gndb", "GND", 24, .j, 24, .botMinus, .black)
        let which = low ? "Low-pass: R is in series and C shunts the output." : "High-pass: C is in series and R shunts the output."
        return finish(caption(which + " Yellow is the Vout probe. The red rail is the source lead, not a second supply."))
    }

    func filterIsLowpass() -> Bool {
        guard let cap = solution.elements.first(where: { $0.id == "c" }) else { return true }
        return abs(cap.a.x - cap.b.x) + 0.01 < abs(cap.a.y - cap.b.y)
    }

    mutating func led() -> BreadboardLayout? {
        guard let r = qty("r"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r", "R", r, hole(6, .c, "Vs"), hole(16, .c, "Van"))
        components.append(BBComponent(id: "led", part: .led(label: "LED"), leads: [
            hole(16, .e, "Van"),
            hole(16, .f, "GND"),
        ]))
        jumper("vs", "Vs", 6, .a, 6, .topPlus, .red)
        jumper("anode", "Van", 16, .b, 22, .b, .orange)
        jumper("gnd", "GND", 16, .j, 16, .botMinus, .black)
        jumper("gndb", "GND", 22, .j, 22, .botMinus, .black)
        return finish(caption("The flat side of the LED is the cathode, on the ground side of the gutter. Orange marks the anode node after the series resistor."))
    }
}

// MARK: - Discrete

extension BreadboardBuilder {
    mutating func bjtBias() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let rc = qty("rc"), let re = qty("re"), let vcc = qty("vcc") else {
            return nil
        }
        singleSupply(BreadboardFormat.trim(vcc) + " V", "Vcc", "GND")
        transistor(npn: true)
        resistor("r1", "R1", r1, hole(11, .i, "Vcc"), hole(17, .i, "Vb"))
        resistor("r2", "R2", r2, hole(17, .j, "Vb"), hole(22, .j, "GND"))
        resistor("rc", "Rc", rc, hole(18, .g, "Vc"), hole(24, .g, "Vcc"))
        resistor("re", "Re", re, hole(16, .j, "Ve"), hole(12, .j, "GND"))
        jumper("v1", "Vcc", 11, .g, 11, .botPlus, .red)
        jumper("v2", "Vcc", 24, .j, 24, .botPlus, .red)
        jumper("g1", "GND", 22, .g, 22, .botMinus, .black)
        jumper("g2", "GND", 12, .h, 12, .botMinus, .black)
        return finish(caption("2N3904 with its flat face toward you, leads E B C left to right. R1 and R2 set the base. Rc and Re are the collector and emitter resistors."))
    }

    mutating func bjtSwitch() -> BreadboardLayout? {
        guard let rb = qty("rb"), let rc = qty("rc"), let vcc = qty("vcc"), let vin = qty("vin") else { return nil }
        singleSupply(BreadboardFormat.trim(vcc) + " V", "Vcc", "GND")
        transistor(npn: true, emitterNet: "GND")
        components.append(BBComponent(id: "vin", part: .source(label: "Vin " + BreadboardFormat.trim(vin) + " V"), leads: [
            hole(6, .e, "Vin"),
            hole(6, .f, "GND"),
        ]))
        resistor("rb", "Rb", rb, hole(6, .b, "Vin"), hole(14, .b, "Vb"))
        resistor("rc", "Rc", rc, hole(18, .i, "Vc"), hole(24, .i, "Vcc"))
        jumper("base", "Vb", 14, .d, 17, .i, .yellow)
        jumper("emit", "GND", 16, .j, 16, .botMinus, .black)
        jumper("srcg", "GND", 6, .j, 6, .botMinus, .black)
        jumper("vcc", "Vcc", 24, .g, 24, .botPlus, .red)
        return finish(caption("Low-side 2N3904 switch, E B C left to right. Vin is its own source referenced to the blue rail. The emitter jumper is the ground lead."))
    }

    mutating func mosSwitch() -> BreadboardLayout? {
        guard let rd = qty("rd"), let vdd = qty("vdd"), let vgs = qty("vgs") else { return nil }
        singleSupply(BreadboardFormat.trim(vdd) + " V", "Vdd", "GND")
        transistor(npn: false)
        components.append(BBComponent(id: "vgs", part: .source(label: "Vgs " + BreadboardFormat.trim(vgs) + " V"), leads: [
            hole(6, .e, "Vgs"),
            hole(6, .f, "GND"),
        ]))
        resistor("rd", "Rd", rd, hole(18, .i, "Vd"), hole(24, .i, "Vdd"))
        jumper("gate", "Vgs", 6, .c, 17, .i, .yellow)
        jumper("src", "GND", 16, .j, 16, .botMinus, .black)
        jumper("srcg", "GND", 6, .j, 6, .botMinus, .black)
        jumper("vdd", "Vdd", 24, .g, 24, .botPlus, .red)
        return finish(caption("2N7000 with its flat face toward you, leads S G D left to right. Rd is the load. Rds(on) is inside the MOSFET, not a second part."))
    }

    mutating func transistor(npn: Bool, emitterNet: String? = nil) {
        let leads = [
            hole(16, .f, emitterNet ?? (npn ? "Ve" : "GND")),
            hole(17, .f, npn ? "Vb" : "Vgs"),
            hole(18, .f, npn ? "Vc" : "Vd"),
        ]
        if npn {
            components.append(BBComponent(id: "q", part: .npn(name: "2N3904"), leads: leads))
        } else {
            components.append(BBComponent(id: "m", part: .nmos(name: "2N7000"), leads: leads))
        }
    }
}

// MARK: - Op-amp and 555

extension BreadboardBuilder {
    mutating func inverting() -> BreadboardLayout? {
        guard let rin = qty("rin"), let rf = qty("rf") else { return nil }
        placeOpAmp(sumNet: "SUM", plusNet: "GND")
        dualSupply()
        components.append(BBComponent(id: "vin", part: .source(label: "Vin"), leads: [
            hole(7, .d, "Vin"),
            hole(4, .d, "GND"),
        ]))
        resistor("rin", "Rin", rin, hole(7, .b, "Vin"), hole(13, .b, "SUM"))
        resistor("rf", "Rf", rf, hole(13, .a, "SUM"), hole(9, .a, "Vout"))
        jumper("gndsrc", "GND", 4, .b, 4, .topMinus, .black)
        jumper("plus", "GND", 14, .c, 14, .topMinus, .black)
        jumper("cross", "Vout", 9, .e, 9, .f, .green)
        jumper("fb", "Vout", 9, .j, 14, .i, .green)
        return finish(caption("741 in the DIP-8 straddling the gutter, notch to the left, pin 1 at the lower left. Rin and Rf meet at pin 2. Pin 3 is the blue ground rail. Pin 7 is +V and pin 4 is −V. The ideal model does not solve supply current."))
    }

    mutating func nonInverting() -> BreadboardLayout? {
        guard let rg = qty("rg"), let rf = qty("rf") else { return nil }
        placeOpAmp(sumNet: "SUM", plusNet: "Vin")
        dualSupply()
        components.append(BBComponent(id: "vin", part: .source(label: "Vin"), leads: [
            hole(7, .d, "Vin"),
            hole(4, .d, "GND"),
        ]))
        resistor("rg", "Rg", rg, hole(13, .c, "SUM"), hole(9, .c, "GND"))
        resistor("rf", "Rf", rf, hole(13, .a, "SUM"), hole(18, .a, "Vout"))
        jumper("gndsrc", "GND", 4, .b, 4, .topMinus, .black)
        jumper("in", "Vin", 7, .b, 14, .b, .yellow)
        jumper("rgg", "GND", 9, .a, 9, .topMinus, .black)
        jumper("cross", "Vout", 18, .e, 18, .f, .green)
        jumper("fb", "Vout", 18, .j, 14, .i, .green)
        return finish(caption("741 pinout. Vin drives pin 3. Rg returns pin 2 to the blue rail and Rf feeds back from pin 6. Pin 7 is +V and pin 4 is −V. Supply current is not in the ideal model."))
    }

    mutating func placeOpAmp(sumNet: String, plusNet: String) {
        _ = dip8("u", "741", origin: 12, pins: [
            ("OA1", "NC1"), ("−", sumNet), ("+", plusNet), ("V−", "−V"),
            ("OA5", "NC5"), ("OUT", "Vout"), ("V+", "+V"), ("NC", "NC8"),
        ])
        jumper("vplus", "+V", 13, .j, 13, .botPlus, .red)
        jumper("vminusA", "−V", 15, .b, 20, .b, .blue)
        jumper("vminusB", "−V", 20, .e, 20, .f, .blue)
        jumper("vminusC", "−V", 20, .j, 20, .botMinus, .blue)
    }

    mutating func astable(withLED: Bool) -> BreadboardLayout? {
        let r1 = qty("r1")
        let r2 = qty("r2")
        let c = qty("c")
        let vcc = qty("vcc")
        guard let r1, let r2, let c, let vcc else { return nil }
        singleSupply(BreadboardFormat.trim(vcc) + " V", "Vcc", "GND")
        _ = dip8("u", "555", origin: 11, pins: [
            ("GND", "GND"), ("TRIG", "TIME"), ("OUT", "OUT"), ("RST", "Vcc"),
            ("CTRL", "CTRL"), ("THR", "TIME"), ("DIS", "DIS"), ("VCC", "Vcc"),
        ])
        jumper("gnd", "GND", 11, .a, 11, .topMinus, .black)
        jumper("vcc", "Vcc", 11, .j, 11, .botPlus, .red)
        jumper("rst", "Vcc", 14, .b, 14, .topPlus, .red)
        resistor("r1", "R1", r1, hole(12, .j, "DIS"), hole(18, .j, "Vcc"))
        jumper("r1v", "Vcc", 18, .h, 18, .botPlus, .red)
        resistor("r2", "R2", r2, hole(12, .h, "DIS"), hole(20, .h, "TIME"))
        jumper("thr", "TIME", 13, .i, 20, .i, .yellow)
        jumper("bridge", "TIME", 20, .e, 20, .f, .yellow)
        jumper("trig", "TIME", 12, .b, 20, .b, .yellow)
        jumper("capj", "TIME", 20, .c, 22, .c, .yellow)
        capacitor("c", "C", c, hole(22, .e, "TIME"), hole(22, .f, "GND"))
        jumper("cg", "GND", 22, .j, 22, .botMinus, .black)
        if withLED {
            guard let rled = qty("rled") else { return nil }
            resistor("rled", "Rled", rled, hole(13, .c, "OUT"), hole(8, .c, "LED"))
            components.append(BBComponent(id: "led", part: .led(label: "LED"), leads: [
                hole(8, .e, "LED"),
                hole(8, .f, "GND"),
            ]))
            jumper("ledk", "GND", 8, .j, 8, .botMinus, .black)
        } else {
            jumper("out", "OUT", 13, .c, 8, .c, .green)
        }
        let extra = withLED
            ? "The LED and Rled hang on pin 3 and return to the blue rail, so the LED is on while the output is high."
            : "Pin 3 is brought out on the green jumper. No load is added."
        return finish(caption("NE555, notch to the left and pin 1 at the lower left, counting counter-clockwise like the real package. Reset is held on the red rail. R1 feeds discharge, R2 feeds the timing node, and pins 2 and 6 share the capacitor. Pin 5 is open. " + extra))
    }

    mutating func monostable() -> BreadboardLayout? {
        guard let r = qty("r"), let c = qty("c"), let vcc = qty("vcc") else { return nil }
        singleSupply(BreadboardFormat.trim(vcc) + " V", "Vcc", "GND")
        _ = dip8("u", "555", origin: 11, pins: [
            ("GND", "GND"), ("TRIG", "TRIG"), ("OUT", "OUT"), ("RST", "Vcc"),
            ("CTRL", "CTRL"), ("THR", "RC"), ("DIS", "RC"), ("VCC", "Vcc"),
        ])
        jumper("gnd", "GND", 11, .a, 11, .topMinus, .black)
        jumper("vcc", "Vcc", 11, .j, 11, .botPlus, .red)
        jumper("rst", "Vcc", 14, .b, 14, .topPlus, .red)
        resistor("r", "R", r, hole(12, .j, "RC"), hole(18, .j, "Vcc"))
        jumper("rv", "Vcc", 18, .h, 18, .botPlus, .red)
        jumper("tie67", "RC", 13, .i, 12, .i, .orange)
        jumper("torow", "RC", 12, .g, 16, .g, .orange)
        jumper("bridge", "RC", 16, .e, 16, .f, .orange)
        jumper("tocap", "RC", 16, .c, 20, .c, .orange)
        capacitor("c", "C", c, hole(20, .e, "RC"), hole(20, .f, "GND"))
        jumper("cg", "GND", 20, .j, 20, .botMinus, .black)
        jumper("trig", "TRIG", 12, .b, 8, .b, .violet)
        jumper("out", "OUT", 13, .c, 9, .c, .green)
        return finish(caption("NE555 one-shot. R and C set the width, with threshold and discharge tied. The violet jumper is the trigger input. A brief low there starts the pulse. No extra trigger network is drawn. Pin 5 is open."))
    }

    mutating func seven() -> BreadboardLayout? {
        guard let r = qty("r"), let digitValue = qty("digit"), let vcc = qty("vcc") else { return nil }
        let digit = Int(digitValue.rounded())
        let mask = LabKit.segmentMask(digit: digit)
        singleSupply(BreadboardFormat.trim(vcc) + " V", "Vcc", "GND")
        let pins = ["e", "d", "CC", "c", "DP", "b", "a", "CC", "f", "g"]
        let nets = ["Se", "Sd", "GND", "Sc", "DP", "Sb", "Sa", "GND", "Sf", "Sg"]
        var leads: [BBLead] = []
        let origin = 20
        for index in 0..<5 {
            leads.append(hole(origin + index, .e, nets[index]))
        }
        for index in 0..<5 {
            leads.append(hole(origin + 4 - index, .f, nets[5 + index]))
        }
        components.append(BBComponent(
            id: "seg",
            part: .display(name: "5161AS", digit: digit, mask: mask, pins: pins),
            leads: leads
        ))
        jumper("cc1", "GND", 22, .b, 22, .topMinus, .black)
        jumper("cc2", "GND", 22, .j, 22, .botMinus, .black)
        // a b c d e f g at bits 0…6. Only lit segments get a resistor.
        let places: [(bit: Int, net: String, from: Int, to: Int, row: BBRow, top: Bool)] = [
            (0, "Sa", 14, 23, .i, false),
            (1, "Sb", 15, 24, .g, false),
            (2, "Sc", 12, 23, .c, true),
            (3, "Sd", 9, 21, .b, true),
            (4, "Se", 8, 20, .d, true),
            (5, "Sf", 11, 21, .h, false),
            (6, "Sg", 10, 20, .j, false),
        ]
        for place in places where mask & (1 << place.bit) != 0 {
            resistor(
                "r\(place.net)",
                "R\(place.net.dropFirst())",
                r,
                hole(place.from, place.row, "Vcc"),
                hole(place.to, place.row, place.net)
            )
            if place.top {
                jumper("v\(place.net)", "Vcc", place.from, .a, place.from, .topPlus, .red)
            } else {
                jumper("v\(place.net)", "Vcc", place.from, place.row == .j ? .g : .j, place.from, .botPlus, .red)
            }
        }
        return finish(caption("Common-cathode 5161AS. Pins 3 and 8 are the cathode, on the blue rail. Each lit segment has its own resistor from the red rail. Dark segments are open. DP is unused."))
    }
}


// MARK: - Extra passives, diodes, op-amps

extension BreadboardBuilder {
    mutating func thevenin() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r1", "R1", r1, hole(6, .c, "Vs"), hole(14, .c, "Vth"))
        resistor("r2", "R2", r2, hole(14, .e, "Vth"), hole(14, .f, "GND"))
        jumper("vs", "Vs", 6, .a, 6, .topPlus, .red)
        jumper("gnd", "GND", 14, .j, 14, .botMinus, .black)
        jumper("tap", "Vth", 14, .b, 22, .b, .yellow)
        if let rl = qty("rl"), rl > 0 {
            resistor("rl", "RL", rl, hole(22, .e, "Vth"), hole(22, .f, "GND"))
            jumper("lg", "GND", 22, .j, 22, .botMinus, .black)
            return finish(caption("Divider feeding RL. Yellow is the Thevenin node; R1 series, R2 shunt, RL across the gutter."))
        }
        jumper("open", "Vth", 22, .e, 26, .e, .yellow)
        return finish(caption("Divider Thevenin port left open. Yellow marks the Vth node; Rth is R1 || R2 behind that tap."))
    }

    mutating func rlStep() -> BreadboardLayout? {
        guard let r = qty("r"), let l = qty("l"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r", "R", r, hole(6, .c, "Vs"), hole(14, .c, "VL"))
        inductor("l", "L", l, hole(14, .a, "VL"), hole(24, .a, "GND"))
        jumper("vs", "Vs", 6, .e, 6, .topPlus, .red)
        jumper("mid", "VL", 14, .b, 14, .e, .yellow)
        jumper("gnd", "GND", 24, .e, 24, .topMinus, .black)
        jumper("gndb", "GND", 24, .b, 24, .botMinus, .black)
        return finish(caption("Series RL along rows a–e. Yellow marks the inductor node. Ideal L — no core model."))
    }

    mutating func halfWave() -> BreadboardLayout? {
        guard let c = qty("c"), let rload = qty("rload") else { return nil }
        let ac = (qty("ac") ?? 1) >= 0.5
        let label: String
        let net: String
        if ac {
            guard let vrms = qty("vrms") else { return nil }
            label = BreadboardFormat.trim(vrms) + " Vrms"
            net = "Vac"
        } else {
            guard let vdc = qty("vdc") else { return nil }
            label = BreadboardFormat.trim(vdc) + " Vdc"
            net = "Vdc"
        }
        singleSupply(label, net, "GND")
        diode("d", "D", hole(8, .c, net), hole(16, .c, "Vpk"))
        resistor("rl", "RL", rload, hole(16, .e, "Vpk"), hole(16, .f, "GND"))
        capacitor("c", "C", c, hole(22, .e, "Vpk"), hole(22, .f, "GND"))
        jumper("ac", net, 8, .a, 8, .topPlus, .red)
        jumper("out", "Vpk", 16, .b, 22, .b, .yellow)
        jumper("g1", "GND", 16, .j, 16, .botMinus, .black)
        jumper("g2", "GND", 22, .j, 22, .botMinus, .black)
        let captionText = ac
            ? "Half-wave: diode anode on the red rail (AC source stand-in), cathode to the filter node. RL and C share Vpeak across the gutter. Banded end is the cathode."
            : "Half-wave on a DC source: diode anode on the red rail, cathode to the filter node. RL and C share that node. Banded end is the cathode."
        return finish(caption(captionText))
    }

    mutating func clipper() -> BreadboardLayout? {
        guard let r = qty("r") else { return nil }
        let ac = (qty("ac") ?? 1) >= 0.5
        let label: String
        let net: String
        if ac {
            guard let vp = qty("vp") else { return nil }
            label = BreadboardFormat.trim(vp) + " Vpk"
            net = "Vp"
        } else {
            guard let vdc = qty("vdc") else { return nil }
            label = BreadboardFormat.trim(vdc) + " Vdc"
            net = "Vdc"
        }
        let vbias = qty("vbias") ?? 0
        singleSupply(label, net, "GND")
        resistor("r", "R", r, hole(6, .c, net), hole(16, .c, "Vout"))
        if abs(vbias) < 1e-12 {
            // Zero bias: cathode is ground — do not invent a second Vb net on the blue rail.
            diode("d", "D", hole(16, .e, "Vout"), hole(16, .f, "GND"))
            jumper("dk", "GND", 16, .j, 16, .botMinus, .black)
        } else {
            diode("d", "D", hole(16, .e, "Vout"), hole(16, .f, "Vb"))
            components.append(BBComponent(
                id: "vb",
                part: .source(label: "Vb " + BreadboardFormat.trim(vbias) + " V"),
                leads: [hole(22, .e, "Vb"), hole(22, .f, "GND")]
            ))
            jumper("bias", "Vb", 16, .i, 22, .i, .blue)
            jumper("bg", "GND", 22, .j, 22, .botMinus, .black)
        }
        jumper("src", net, 6, .a, 6, .topPlus, .red)
        jumper("tap", "Vout", 16, .b, 24, .b, .yellow)
        jumper("gnd", "GND", 24, .j, 24, .botMinus, .black)
        return finish(caption("Series R into a shunt diode. The banded cathode sits toward the bias/ground side. Yellow is the clipped output node."))
    }

    mutating func clamper() -> BreadboardLayout? {
        guard let vp = qty("vp") else { return nil }
        // Cap value is illustrative — solve does not expose C.
        let c = 1e-6
        singleSupply(BreadboardFormat.trim(vp) + " Vpk", "Vp", "GND")
        capacitor("c", "C", c, hole(8, .c, "Vp"), hole(16, .c, "Vout"))
        diode("d", "D", hole(16, .f, "GND"), hole(16, .e, "Vout"))
        jumper("src", "Vp", 8, .a, 8, .topPlus, .red)
        jumper("out", "Vout", 16, .b, 24, .b, .yellow)
        jumper("gnd", "GND", 16, .j, 16, .botMinus, .black)
        jumper("gndb", "GND", 24, .j, 24, .botMinus, .black)
        return finish(caption("Series C with a diode to the blue rail. Banded cathode is on the output node (positive clamp). C is illustrative — the solve only shifts the peaks."))
    }

    mutating func summing() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let rf = qty("rf") else { return nil }
        placeOpAmp(sumNet: "SUM", plusNet: "GND")
        dualSupply()
        components.append(BBComponent(id: "v1", part: .source(label: "V1"), leads: [
            hole(5, .d, "V1"), hole(3, .d, "GND"),
        ]))
        components.append(BBComponent(id: "v2", part: .source(label: "V2"), leads: [
            hole(7, .d, "V2"), hole(3, .e, "GND"),
        ]))
        resistor("r1", "R1", r1, hole(5, .b, "V1"), hole(13, .b, "SUM"))
        resistor("r2", "R2", r2, hole(7, .a, "V2"), hole(13, .a, "SUM"))
        resistor("rf", "Rf", rf, hole(13, .c, "SUM"), hole(9, .c, "Vout"))
        jumper("gndsrc", "GND", 3, .b, 3, .topMinus, .black)
        jumper("plus", "GND", 14, .c, 14, .topMinus, .black)
        jumper("cross", "Vout", 9, .e, 9, .f, .green)
        jumper("fb", "Vout", 9, .j, 14, .i, .green)
        return finish(caption("741 summing amp. R1 and R2 meet Rin at pin 2 (virtual ground). Rf feeds back from pin 6. Pin 3 is on the blue rail."))
    }

    mutating func difference() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let rf = qty("rf") else { return nil }
        placeOpAmp(sumNet: "SUM", plusNet: "PLUS")
        dualSupply()
        components.append(BBComponent(id: "v1", part: .source(label: "V1"), leads: [
            hole(5, .d, "V1"), hole(3, .d, "GND"),
        ]))
        components.append(BBComponent(id: "v2", part: .source(label: "V2"), leads: [
            hole(7, .d, "V2"), hole(3, .e, "GND"),
        ]))
        resistor("r1a", "R1", r1, hole(5, .b, "V1"), hole(13, .b, "SUM"))
        resistor("rf", "Rf", rf, hole(13, .a, "SUM"), hole(9, .a, "Vout"))
        resistor("r1b", "R1", r1, hole(7, .c, "V2"), hole(14, .c, "PLUS"))
        resistor("rg", "Rf", rf, hole(14, .b, "PLUS"), hole(18, .b, "GND"))
        jumper("gndsrc", "GND", 3, .b, 3, .topMinus, .black)
        jumper("rgnd", "GND", 18, .a, 18, .topMinus, .black)
        jumper("cross", "Vout", 9, .e, 9, .f, .green)
        jumper("fb", "Vout", 9, .j, 14, .i, .green)
        return finish(caption("Matched difference amp on a 741. Rin/Rf pairs on both inputs. Ideal matched resistors — mismatch CMRR is not modeled."))
    }

    mutating func integrator() -> BreadboardLayout? {
        guard let r = qty("r"), let c = qty("c") else { return nil }
        placeOpAmp(sumNet: "SUM", plusNet: "GND")
        dualSupply()
        components.append(BBComponent(id: "vin", part: .source(label: "Vin"), leads: [
            hole(6, .d, "Vin"), hole(4, .d, "GND"),
        ]))
        resistor("r", "R", r, hole(6, .b, "Vin"), hole(13, .b, "SUM"))
        capacitor("c", "C", c, hole(13, .a, "SUM"), hole(9, .a, "Vout"))
        jumper("gndsrc", "GND", 4, .b, 4, .topMinus, .black)
        jumper("plus", "GND", 14, .c, 14, .topMinus, .black)
        jumper("cross", "Vout", 9, .e, 9, .f, .green)
        jumper("fb", "Vout", 9, .j, 14, .i, .green)
        return finish(caption("Ideal integrator: R into pin 2, C in the feedback. No reset resistor is drawn — DC error integrates forever in the model."))
    }

    mutating func differentiator() -> BreadboardLayout? {
        guard let r = qty("r"), let c = qty("c") else { return nil }
        placeOpAmp(sumNet: "SUM", plusNet: "GND")
        dualSupply()
        components.append(BBComponent(id: "vin", part: .source(label: "Vin"), leads: [
            hole(6, .d, "Vin"), hole(4, .d, "GND"),
        ]))
        capacitor("c", "C", c, hole(6, .b, "Vin"), hole(13, .b, "SUM"))
        resistor("r", "R", r, hole(13, .a, "SUM"), hole(9, .a, "Vout"))
        jumper("gndsrc", "GND", 4, .b, 4, .topMinus, .black)
        jumper("plus", "GND", 14, .c, 14, .topMinus, .black)
        jumper("cross", "Vout", 9, .e, 9, .f, .green)
        jumper("fb", "Vout", 9, .j, 14, .i, .green)
        return finish(caption("Ideal differentiator: C into pin 2, R in the feedback. No high-frequency roll-off is modeled."))
    }

    mutating func comparator() -> BreadboardLayout? {
        placeOpAmp(sumNet: "Vin", plusNet: "Vref")
        dualSupply()
        components.append(BBComponent(id: "vin", part: .source(label: "Vin"), leads: [
            hole(6, .d, "Vin"), hole(4, .d, "GND"),
        ]))
        components.append(BBComponent(id: "vref", part: .source(label: "Vref"), leads: [
            hole(8, .d, "Vref"), hole(4, .e, "GND"),
        ]))
        jumper("gndsrc", "GND", 4, .b, 4, .topMinus, .black)
        jumper("in", "Vin", 6, .b, 13, .b, .yellow)
        jumper("ref", "Vref", 8, .c, 14, .c, .orange)
        jumper("out", "Vout", 14, .i, 24, .i, .green)
        jumper("cross", "Vout", 24, .e, 24, .f, .green)
        return finish(caption("Open-loop 741 as a comparator. Yellow is Vin on pin 2, orange is Vref on pin 3. Output sits on a rail — no feedback."))
    }

    mutating func linearDrop() -> BreadboardLayout? {
        guard let vin = qty("vin"), let vout = qty("vout"), let iload = qty("iload") else { return nil }
        // Represent pass element as a series resistor whose drop matches Vin−Vout at Iload.
        let drop = max(vin - vout, 1e-9)
        let rpass = drop / max(iload, 1e-9)
        let rload = vout / max(iload, 1e-9)
        singleSupply(BreadboardFormat.trim(vin) + " V", "Vin", "GND")
        resistor("pass", "Pass", rpass, hole(6, .c, "Vin"), hole(16, .c, "Vout"))
        resistor("rl", "Load", rload, hole(16, .e, "Vout"), hole(16, .f, "GND"))
        jumper("vin", "Vin", 6, .a, 6, .topPlus, .red)
        jumper("out", "Vout", 16, .b, 24, .b, .yellow)
        jumper("gnd", "GND", 16, .j, 16, .botMinus, .black)
        jumper("gndb", "GND", 24, .j, 24, .botMinus, .black)
        return finish(caption("Linear drop sketched as a series pass resistance and the load. Heat is (Vin − Vout)·Iload. Not a real regulator pinout."))
    }
}



// MARK: - Priority breadboard circuits (bridge, RLC, CE/CS, CMOS)

extension BreadboardBuilder {
    mutating func seriesRLC() -> BreadboardLayout? {
        guard let r = qty("r"), let l = qty("l"), let c = qty("c") else { return nil }
        let ac = (qty("ac") ?? 1) >= 0.5
        let label: String
        let net: String
        if ac {
            guard let vp = qty("vp") else { return nil }
            label = BreadboardFormat.trim(vp) + " Vpk"
            net = "Vp"
        } else {
            guard let vdc = qty("vdc") else { return nil }
            label = BreadboardFormat.trim(vdc) + " Vdc"
            net = "Vdc"
        }
        singleSupply(label, net, "GND")
        resistor("r", "R", r, hole(6, .c, net), hole(12, .c, "N1"))
        inductor("l", "L", l, hole(12, .a, "N1"), hole(18, .a, "N2"))
        capacitor("c", "C", c, hole(18, .e, "N2"), hole(24, .e, "GND"))
        jumper("src", net, 6, .e, 6, .topPlus, .red)
        jumper("n1", "N1", 12, .b, 12, .e, .orange)
        jumper("n2", "N2", 18, .b, 18, .d, .yellow)
        jumper("gnd", "GND", 24, .b, 24, .topMinus, .black)
        jumper("gndb", "GND", 24, .a, 24, .botMinus, .black)
        let drive = ac
            ? "AC peak on the red rail drives series R–L–C. At DC the capacitor is open — steady current is zero."
            : "DC on the red rail into series R–L–C. Series C is an open at DC, so steady current is zero."
        return finish(caption(drive + " Orange is after R; yellow is after L."))
    }

    mutating func fullBridge() -> BreadboardLayout? {
        guard let c = qty("c"), let rload = qty("rload") else { return nil }
        let ac = (qty("ac") ?? 1) >= 0.5
        if ac {
            guard let vrms = qty("vrms") else { return nil }
            singleSupply("Vpk", "Vpk", "GND")
            components.append(BBComponent(
                id: "ac",
                part: .source(label: BreadboardFormat.trim(vrms) + " Vrms"),
                leads: [hole(5, .e, "VacA"), hole(5, .f, "VacB")]
            ))
            diode("d1", "D1", hole(8, .c, "VacA"), hole(14, .c, "Vpk"))
            diode("d2", "D2", hole(10, .j, "VacB"), hole(14, .j, "Vpk"))
            diode("d3", "D3", hole(7, .f, "GND"), hole(8, .i, "VacA"))
            diode("d4", "D4", hole(9, .f, "GND"), hole(10, .h, "VacB"))
            jumper("aBus", "VacA", 5, .c, 8, .a, .yellow)
            jumper("aCross", "VacA", 8, .e, 8, .f, .yellow)
            jumper("bBus", "VacB", 5, .j, 10, .g, .violet)
            jumper("vpkCross", "Vpk", 14, .e, 14, .f, .red)
            jumper("plus", "Vpk", 14, .a, 14, .topPlus, .red)
            jumper("plusb", "Vpk", 14, .d, 20, .d, .red)
            jumper("g3", "GND", 7, .j, 7, .botMinus, .black)
            jumper("g4", "GND", 9, .j, 9, .botMinus, .black)
            resistor("rl", "RL", rload, hole(20, .e, "Vpk"), hole(20, .f, "GND"))
            capacitor("c", "C", c, hole(24, .e, "Vpk"), hole(24, .f, "GND"))
            jumper("out", "Vpk", 20, .b, 24, .b, .red)
            jumper("lg", "GND", 20, .j, 20, .botMinus, .black)
            jumper("cg", "GND", 24, .j, 24, .botMinus, .black)
            return finish(caption("Full-wave bridge: AC secondary between VacA and VacB (not the DC rails). D1/D2 cathodes feed Vpk on the red rail; D3/D4 anodes sit on the blue rail. RL and C share Vpeak. Banded ends are cathodes. Illustrative — not a transformer pinout."))
        } else {
            guard let vdc = qty("vdc") else { return nil }
            singleSupply(BreadboardFormat.trim(vdc) + " Vdc", "Vdc", "GND")
            diode("d1", "D1", hole(6, .c, "Vdc"), hole(12, .c, "Mid"))
            diode("d2", "D2", hole(12, .a, "Mid"), hole(18, .a, "Vpk"))
            resistor("rl", "RL", rload, hole(18, .e, "Vpk"), hole(18, .f, "GND"))
            capacitor("c", "C", c, hole(24, .e, "Vpk"), hole(24, .f, "GND"))
            jumper("src", "Vdc", 6, .a, 6, .topPlus, .red)
            jumper("mid", "Mid", 12, .b, 12, .e, .orange)
            jumper("out", "Vpk", 18, .b, 24, .b, .yellow)
            jumper("g1", "GND", 18, .j, 18, .botMinus, .black)
            jumper("g2", "GND", 24, .j, 24, .botMinus, .black)
            return finish(caption("Bridge on a DC source is two forward drops in series (D1 then D2) into RL || C. Ripple is zero on DC — switch to AC sine to size C from a ripple target."))
        }
    }

    mutating func ceAmp() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let rc = qty("rc"), let re = qty("re"),
              let vcc = qty("vcc"), let rl = qty("rl") else { return nil }
        singleSupply(BreadboardFormat.trim(vcc) + " V", "Vcc", "GND")
        transistor(npn: true)
        resistor("r1", "R1", r1, hole(11, .i, "Vcc"), hole(17, .i, "Vb"))
        resistor("r2", "R2", r2, hole(17, .j, "Vb"), hole(22, .j, "GND"))
        resistor("rc", "Rc", rc, hole(18, .g, "Vc"), hole(24, .g, "Vcc"))
        resistor("re", "Re", re, hole(16, .j, "Ve"), hole(12, .j, "GND"))
        capacitor("cc", "Cc", 1e-6, hole(20, .c, "Vc"), hole(26, .c, "Vout"))
        resistor("rl", "RL", rl, hole(26, .e, "Vout"), hole(26, .f, "GND"))
        jumper("v1", "Vcc", 11, .g, 11, .botPlus, .red)
        jumper("v2", "Vcc", 24, .j, 24, .botPlus, .red)
        jumper("g1", "GND", 22, .g, 22, .botMinus, .black)
        jumper("g2", "GND", 12, .h, 12, .botMinus, .black)
        jumper("col", "Vc", 18, .i, 20, .e, .orange)
        jumper("loadg", "GND", 26, .j, 26, .botMinus, .black)
        let unbypassed = solution.steps.contains { $0.contains("/ (1 + gm·Re)") }
        if !unbypassed {
            capacitor("ce", "Ce", 10e-6, hole(16, .h, "Ve"), hole(14, .h, "GND"))
            jumper("ceg", "GND", 14, .j, 14, .botMinus, .black)
        }
        return finish(caption("CE stage on a 2N3904 (E B C). Bias matches the BJT bias board; Cc couples the collector into RL. Ce is illustrative when the emitter is bypassed for midband gain. Coupling/bypass are AC shorts in the solve — not a SPICE transient."))
    }

    mutating func csAmp() -> BreadboardLayout? {
        guard let rd = qty("rd"), let vdd = qty("vdd"), let vg = qty("vg") else { return nil }
        let rs = qty("rs") ?? 0
        singleSupply(BreadboardFormat.trim(vdd) + " V", "Vdd", "GND")
        let sourceNet = rs > 1e-12 ? "Vs" : "GND"
        components.append(BBComponent(id: "m", part: .nmos(name: "2N7000"), leads: [
            hole(16, .f, sourceNet),
            hole(17, .f, "Vg"),
            hole(18, .f, "Vd"),
        ]))
        components.append(BBComponent(id: "vg", part: .source(label: "Vg " + BreadboardFormat.trim(vg) + " V"), leads: [
            hole(6, .e, "Vg"),
            hole(6, .f, "GND"),
        ]))
        resistor("rd", "Rd", rd, hole(18, .i, "Vd"), hole(24, .i, "Vdd"))
        if rs > 1e-12 {
            resistor("rs", "Rs", rs, hole(16, .j, "Vs"), hole(12, .j, "GND"))
            jumper("rsg", "GND", 12, .h, 12, .botMinus, .black)
        } else {
            jumper("src", "GND", 16, .j, 16, .botMinus, .black)
        }
        jumper("gate", "Vg", 6, .c, 17, .i, .yellow)
        jumper("srcg", "GND", 6, .j, 6, .botMinus, .black)
        jumper("vdd", "Vdd", 24, .g, 24, .botPlus, .red)
        return finish(caption("CS stage on a 2N7000 (S G D). Rd is the drain load. Rs is present only when degeneration is non-zero; Rs = 0 ties the source to the blue rail. Square-law bias — not a SPICE model card."))
    }

    mutating func cmosInverter() -> BreadboardLayout? {
        guard let vdd = qty("vdd") else { return nil }
        let vin = qty("vin") ?? (qty("vm") ?? (vdd / 2))
        singleSupply(BreadboardFormat.trim(vdd) + " V", "Vdd", "GND")
        components.append(BBComponent(id: "p", part: .pmos(name: "PMOS"), leads: [
            hole(18, .c, "Vdd"),
            hole(17, .c, "Vin"),
            hole(16, .c, "Vout"),
        ]))
        components.append(BBComponent(id: "n", part: .nmos(name: "NMOS"), leads: [
            hole(14, .f, "GND"),
            hole(15, .f, "Vin"),
            hole(16, .f, "Vout"),
        ]))
        components.append(BBComponent(id: "vin", part: .source(label: "Vin " + BreadboardFormat.trim(vin) + " V"), leads: [
            hole(6, .e, "Vin"),
            hole(6, .f, "GND"),
        ]))
        jumper("out", "Vout", 16, .e, 16, .g, .green)
        jumper("gatep", "Vin", 6, .c, 17, .a, .yellow)
        jumper("gaten", "Vin", 15, .i, 17, .e, .yellow)
        jumper("ps", "Vdd", 18, .a, 18, .topPlus, .red)
        jumper("ns", "GND", 14, .j, 14, .botMinus, .black)
        jumper("srcg", "GND", 6, .j, 6, .botMinus, .black)
        jumper("probe", "Vout", 16, .b, 24, .b, .green)
        jumper("pgnd", "GND", 24, .j, 24, .botMinus, .black)
        return finish(caption("CMOS inverter sketch: discrete PMOS (rows a–e) and NMOS (rows f–j) sharing Vin and Vout across the gutter. Ideal rail-to-rail logic — static current is zero in the solve. Not a matched IC process or a SPICE deck."))
    }
}

// MARK: - On-board meters

public enum BreadboardMeters {
    /// Build a small set of voltage and current chips from the solved schematic.
    public static func make(solution: LabSolution, layout: BreadboardLayout) -> [BBMeter] {
        var holesByNet: [String: [BBHole]] = [:]
        func claim(_ net: String, _ hole: BBHole) {
            guard !net.isEmpty else { return }
            holesByNet[net, default: []].append(hole)
        }
        for component in layout.components {
            for lead in component.leads { claim(lead.net, lead.hole) }
        }
        for jumper in layout.jumpers {
            claim(jumper.net, jumper.a)
            claim(jumper.net, jumper.b)
        }
        for supply in layout.supplies {
            for lead in supply.leads { claim(lead.net, lead.hole) }
        }

        var meters: [BBMeter] = []
        var usedHoles = Set<BBHole>()

        func pickHole(forNet net: String) -> BBHole? {
            let candidates = holesByNet[net] ?? []
            // Prefer interior strip holes over rails for readable chips.
            let prefer = candidates.first { !$0.row.isRail } ?? candidates.first
            return prefer
        }

        func netAliases(for node: LabNode) -> [String] {
            var names = [node.name, node.id]
            let compact = node.name.replacingOccurrences(of: " ", with: "")
            if compact != node.name { names.append(compact) }
            // Common lab aliases
            if node.name == "Vth node" { names.append("Vth") }
            if node.name == "Vpeak" { names.append(contentsOf: ["Vpk", "Vpeak"]) }
            if node.name == "Vrms" { names.append(contentsOf: ["Vac", "Vrms"]) }
            if node.name == "Open" { names.append("Vth") }
            if node.name == "VL" { names.append("Vth") }
            return names
        }

        for node in solution.nodes {
            guard node.unit == "V" || node.unit.isEmpty else { continue }
            var hole: BBHole?
            for alias in netAliases(for: node) {
                if let found = pickHole(forNet: alias) {
                    hole = found
                    break
                }
            }
            guard let hole, !usedHoles.contains(hole) else { continue }
            usedHoles.insert(hole)
            let title = node.name
            let reading = LabKit.si(node.value, unit: node.unit.isEmpty ? "V" : node.unit)
            meters.append(BBMeter(
                id: "v-\(node.id)",
                kind: .voltage,
                title: title,
                reading: reading,
                hole: hole
            ))
            if meters.filter({ $0.kind == .voltage }).count >= 5 { break }
        }

        // Currents: prefer emphasized / named branches; cap at 3.
        let branches = solution.branches.filter { $0.unit == "A" }
        for branch in branches.prefix(3) {
            // Anchor near a mid-board component lead if possible, else column 12 row a.
            let anchor: BBHole
            if let mid = layout.components.first(where: { $0.leads.count >= 2 })?.leads.first?.hole {
                anchor = BBHole(column: min(layout.columns, mid.column + 2), row: .a)
            } else {
                anchor = BBHole(column: 12, row: .a)
            }
            // Offset each current chip so they don't stack.
            let column = min(layout.columns, max(1, anchor.column + meters.filter { $0.kind == .current }.count * 3))
            let hole = BBHole(column: column, row: .topPlus)
            meters.append(BBMeter(
                id: "i-\(branch.id)",
                kind: .current,
                title: branch.name,
                reading: LabKit.si(branch.value, unit: "A"),
                hole: hole
            ))
        }

        return meters
    }

    /// One-line summary for captions / accessibility.
    public static func summaryLine(_ meters: [BBMeter]) -> String {
        guard !meters.isEmpty else { return "" }
        return meters.map { "\($0.title) \($0.reading)" }.joined(separator: "  ·  ")
    }
}

// MARK: - Power-stage boards (discrete CE stage, op-amp driving a load)

extension BreadboardBuilder {
    /// The class-A teaching stage uses the same divider-biased 2N3904 as the BJT bias board.
    mutating func discretePowerStage() -> BreadboardLayout? {
        guard var board = bjtBias() else { return nil }
        board.caption = caption("Class-A common-emitter stage on a 2N3904 with its flat face toward you, leads E B C left to right. R1 and R2 set the base, Rc is the collector load, and Re sets the emitter. Quiescent power in the transistor is Ic × Vce. Add a heatsink and check the bias before you rely on it for real power.")
        return board
    }

    /// A non-inverting op-amp stage with its load resistor, so load power can be measured on the board.
    mutating func opAmpLoadStage() -> BreadboardLayout? {
        guard let rf = qty("rf"), let av = qty("av"), av > 1 else { return nil }
        let rg = rf / (av - 1)
        let vout = qty("vout") ?? 0
        let iout = qty("iout") ?? 0
        let rl = (abs(vout) > 1e-12 && abs(iout) > 1e-12) ? abs(vout / iout) : 1000
        placeOpAmp(sumNet: "SUM", plusNet: "Vin")
        dualSupply()
        components.append(BBComponent(id: "vin", part: .source(label: "Vin"), leads: [
            hole(7, .d, "Vin"),
            hole(4, .d, "GND"),
        ]))
        resistor("rg", "Rg", rg, hole(13, .c, "SUM"), hole(9, .c, "GND"))
        resistor("rf", "Rf", rf, hole(13, .a, "SUM"), hole(18, .a, "Vout"))
        resistor("rl", "RL", rl, hole(18, .c, "Vout"), hole(22, .c, "GND"))
        jumper("gndsrc", "GND", 4, .b, 4, .topMinus, .black)
        jumper("in", "Vin", 7, .b, 14, .b, .yellow)
        jumper("rgg", "GND", 9, .a, 9, .topMinus, .black)
        jumper("rlg", "GND", 22, .a, 22, .topMinus, .black)
        jumper("cross", "Vout", 18, .e, 18, .f, .green)
        jumper("fb", "Vout", 18, .j, 14, .i, .green)
        return finish(caption("741 pinout. Vin drives pin 3, Rg and Rf set the gain, and RL is the load from Vout to the ground rail. Pin 7 is +V and pin 4 is −V. A 741 cannot source much current, so keep RL large on the real part. The ideal model does not limit output current."))
    }
}
