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
    /// Leads E, B, C. 2N3904, flat face up.
    case npn(name: String)
    /// Leads S, G, D. 2N7000, flat face up.
    case nmos(name: String)
    /// Leads are pins 1…8. Pin 1 is the notch end on the top strip.
    case dip8(name: String, pins: [String])
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

public struct BreadboardLayout: Equatable, Sendable {
    public var circuit: ElectronicsCircuit
    public var components: [BBComponent]
    public var jumpers: [BBJumper]
    public var supplies: [BBSupply]
    public var railLabels: [BBRailLabel]
    public var caption: String
    public var columns: Int

    public init(
        circuit: ElectronicsCircuit,
        components: [BBComponent],
        jumpers: [BBJumper],
        supplies: [BBSupply],
        railLabels: [BBRailLabel],
        caption: String,
        columns: Int = BreadboardBoard.columns
    ) {
        self.circuit = circuit
        self.components = components
        self.jumpers = jumpers
        self.supplies = supplies
        self.railLabels = railLabels
        self.caption = caption
        self.columns = columns
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
        case .resistor, .ceramic, .electrolytic, .led, .source:
            guard leads.count == 2 else { return ["\(component.id) needs two leads"] }
            if leads[0].net == leads[1].net {
                return ["\(component.id) ties \(leads[0].net) to itself"]
            }
            if BreadboardBoard.group(leads[0].hole) == BreadboardBoard.group(leads[1].hole) {
                return ["\(component.id) is shorted by one breadboard node"]
            }
            return []
        case .npn, .nmos:
            guard leads.count == 3 else { return ["\(component.id) needs three leads"] }
            let nets = Set(leads.map(\.net))
            if nets.count < 3 { return ["\(component.id) leads are not three nodes"] }
            return []
        case .dip8:
            guard leads.count == 8 else { return ["\(component.id) is not an 8-pin DIP"] }
            return dipSpanFaults(component.id, leads, pins: 4)
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
        .seriesResistors, .parallelResistors, .voltageDivider, .kirchhoffLoop,
        .rcStep, .firstOrderFilter, .ledSeries,
        .bjtBias, .bjtSwitch, .mosSwitch,
        .invertingAmp, .nonInvertingAmp,
        .astable555, .monostable555, .ledFlasher, .sevenSegment,
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
        case .rcStep: return built.rcStep()
        case .firstOrderFilter: return built.filter()
        case .ledSeries: return built.led()
        case .bjtBias: return built.bjtBias()
        case .bjtSwitch: return built.bjtSwitch()
        case .mosSwitch: return built.mosSwitch()
        case .invertingAmp: return built.inverting()
        case .nonInvertingAmp: return built.nonInverting()
        case .astable555: return built.astable(withLED: false)
        case .monostable555: return built.monostable()
        case .ledFlasher: return built.astable(withLED: true)
        case .sevenSegment: return built.seven()
        default: return nil
        }
    }
}

// MARK: - Builder

private struct BreadboardBuilder {
    var solution: LabSolution
    var components: [BBComponent] = []
    var jumpers: [BBJumper] = []
    var supplies: [BBSupply] = []
    var railLabels: [BBRailLabel] = []

    init(_ solution: LabSolution) {
        self.solution = solution
    }

    func qty(_ id: String) -> Double? { solution.quantity(id) }

    func finish(_ caption: String) -> BreadboardLayout {
        BreadboardLayout(
            circuit: solution.circuit,
            components: components,
            jumpers: jumpers,
            supplies: supplies,
            railLabels: railLabels,
            caption: caption
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
        var leads: [BBLead] = []
        for index in 0..<4 {
            leads.append(hole(origin + index, .e, pins[index].1))
        }
        for index in 0..<4 {
            leads.append(hole(origin + 3 - index, .f, pins[4 + index].1))
        }
        components.append(BBComponent(
            id: id,
            part: .dip8(name: name, pins: pins.map(\.0)),
            leads: leads
        ))
        return leads
    }
}

private enum BreadboardFormat {
    static func ohms(_ value: Double) -> String { trim(value) + "Ω" }
    static func farads(_ value: Double) -> String { trim(value) + "F" }

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
        resistor("r1", "R1", r1, hole(8, .c, "Vs"), hole(14, .c, "V1"))
        resistor("r2", "R2", r2, hole(14, .a, "V1"), hole(20, .a, "GND"))
        jumper("vs", "Vs", 8, .e, 8, .topPlus, .red)
        jumper("gnd", "GND", 20, .e, 20, .topMinus, .black)
        return finish(caption("Series string on the top strip. Vs is the red rail, ground is the blue rail, and V1 is the node between R1 and R2."))
    }

    mutating func parallel() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r1", "R1", r1, hole(10, .e, "Vs"), hole(10, .f, "GND"))
        resistor("r2", "R2", r2, hole(16, .e, "Vs"), hole(16, .f, "GND"))
        jumper("vs1", "Vs", 10, .a, 10, .topPlus, .red)
        jumper("vs2", "Vs", 16, .b, 16, .topPlus, .red)
        jumper("g1", "GND", 10, .j, 10, .botMinus, .black)
        jumper("g2", "GND", 16, .i, 16, .botMinus, .black)
        return finish(caption("Both resistors sit across the gutter, so each one sees the full source."))
    }

    mutating func divider() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let vin = qty("vin") else { return nil }
        singleSupply(BreadboardFormat.trim(vin) + " V", "Vin", "GND")
        resistor("r1", "R1", r1, hole(8, .c, "Vin"), hole(14, .c, "Vout"))
        resistor("r2", "R2", r2, hole(14, .a, "Vout"), hole(20, .a, "GND"))
        jumper("vin", "Vin", 8, .e, 8, .topPlus, .red)
        jumper("gnd", "GND", 20, .e, 20, .topMinus, .black)
        jumper("out", "Vout", 14, .b, 24, .b, .yellow)
        return finish(caption("R1 is the top resistor and R2 returns to the blue rail. The yellow jumper is the unloaded tap."))
    }

    mutating func kirchhoff() -> BreadboardLayout? {
        guard let r1 = qty("r1"), let r2 = qty("r2"), let r3 = qty("r3"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r1", "R1", r1, hole(6, .c, "Vs"), hole(11, .c, "N1"))
        resistor("r2", "R2", r2, hole(11, .a, "N1"), hole(16, .a, "N2"))
        resistor("r3", "R3", r3, hole(16, .e, "N2"), hole(22, .e, "GND"))
        jumper("vs", "Vs", 6, .b, 6, .topPlus, .red)
        jumper("gnd", "GND", 22, .b, 22, .topMinus, .black)
        return finish(caption("One series loop. N1 is after R1 and N2 is after R2, both measured to the blue rail."))
    }

    mutating func rcStep() -> BreadboardLayout? {
        guard let r = qty("r"), let c = qty("c"), let vinf = qty("vinf") else { return nil }
        singleSupply(BreadboardFormat.trim(vinf) + " V", "Vinf", "GND")
        resistor("r", "R", r, hole(8, .c, "Vinf"), hole(14, .c, "Vc"))
        capacitor("c", "C", c, hole(14, .e, "Vc"), hole(14, .f, "GND"))
        jumper("src", "Vinf", 8, .a, 8, .topPlus, .red)
        jumper("gnd", "GND", 14, .j, 14, .botMinus, .black)
        return finish(caption("The capacitor’s positive lead is the Vc node. At 1 µF and above it is an electrolytic; smaller values are ceramic discs."))
    }

    mutating func filter() -> BreadboardLayout? {
        guard let r = qty("r"), let c = qty("c") else { return nil }
        let low = filterIsLowpass()
        singleSupply("Vin", "Vin", "GND")
        if low {
            resistor("r", "R", r, hole(8, .c, "Vin"), hole(15, .c, "Vout"))
            capacitor("c", "C", c, hole(15, .e, "Vout"), hole(15, .f, "GND"))
        } else {
            capacitor("c", "C", c, hole(8, .c, "Vin"), hole(15, .c, "Vout"))
            resistor("r", "R", r, hole(15, .e, "Vout"), hole(15, .f, "GND"))
        }
        jumper("vin", "Vin", 8, .a, 8, .topPlus, .red)
        jumper("gnd", "GND", 15, .j, 15, .botMinus, .black)
        let which = low ? "Low-pass: R is in series and C shunts the output." : "High-pass: C is in series and R shunts the output."
        return finish(caption(which + " The red rail is the source lead, not a second supply."))
    }

    func filterIsLowpass() -> Bool {
        guard let cap = solution.elements.first(where: { $0.id == "c" }) else { return true }
        return abs(cap.a.x - cap.b.x) + 0.01 < abs(cap.a.y - cap.b.y)
    }

    mutating func led() -> BreadboardLayout? {
        guard let r = qty("r"), let vs = qty("vs") else { return nil }
        singleSupply(BreadboardFormat.trim(vs) + " V", "Vs", "GND")
        resistor("r", "R", r, hole(8, .c, "Vs"), hole(14, .c, "Van"))
        components.append(BBComponent(id: "led", part: .led(label: "LED"), leads: [
            hole(14, .e, "Van"),
            hole(14, .f, "GND"),
        ]))
        jumper("vs", "Vs", 8, .a, 8, .topPlus, .red)
        jumper("gnd", "GND", 14, .j, 14, .botMinus, .black)
        return finish(caption("The flat side of the LED is the cathode, on the ground side of the gutter."))
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
        return finish(caption("2N3904, flat face toward the top of the board, leads E B C left to right. R1 and R2 set the base. Rc and Re are the collector and emitter resistors."))
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
        return finish(caption("2N7000, flat face toward the top of the board, leads S G D left to right. Rd is the load. Rds(on) is inside the MOSFET, not a second part."))
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
        return finish(caption("741 pinout across the gutter. Rin and Rf meet at pin 2. Pin 3 is the blue ground rail. Pin 7 is +V and pin 4 is −V. The ideal model does not solve supply current."))
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
        return finish(caption("NE555, notch at pin 1. Reset is held on the red rail. R1 feeds discharge, R2 feeds the timing node, and pins 2 and 6 share the capacitor. Pin 5 is open. " + extra))
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
