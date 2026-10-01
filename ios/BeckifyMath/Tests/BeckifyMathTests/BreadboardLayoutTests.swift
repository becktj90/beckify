import XCTest
@testable import BeckifyMath

final class BreadboardLayoutTests: XCTestCase {
    func testSupportedDefaultsAreHonestHookups() throws {
        for circuit in BreadboardLayouts.supported {
            let layout = try layout(circuit)
            let audit = BreadboardNetlist.audit(layout)
            XCTAssertTrue(audit.ok, "\(circuit.rawValue) \(audit)")
            XCTAssertFalse(layout.components.isEmpty)
            XCTAssertFalse(layout.jumpers.isEmpty)
            XCTAssertFalse(layout.caption.isEmpty)
            for jumper in layout.jumpers {
                let bend = BreadboardRoute.manhattan(from: jumper.a, to: jumper.b)
                XCTAssertGreaterThanOrEqual(bend.count, 2)
                for index in 1..<bend.count {
                    let prev = bend[index - 1]
                    let next = bend[index]
                    XCTAssertTrue(prev.x == next.x || prev.y == next.y, "\(circuit.rawValue) \(jumper.id) diagonal")
                }
            }
        }
    }

    func testHiddenCircuitsStayOffTheBoard() throws {
        let hidden: [ElectronicsCircuit] = [
            .seriesRLC, .fullBridge, .cmosInverter, .ceAmp, .csAmp,
            .idealBuck, .quarterWave, .stubCancel, .lMatch, .classOverview,
            .discretePower, .opAmpPower, .complexConvert, .impedanceCombo,
        ]
        for circuit in hidden {
            XCTAssertFalse(BreadboardLayouts.supports(circuit))
            let info = ElectronicsLab.info(circuit)
            let solved = try ElectronicsLab.solve(circuit, unknown: info.defaultUnknown, inputs: info.defaults)
            XCTAssertNil(BreadboardLayouts.make(solved))
        }
    }

    func testColumnGroupsAndRails() {
        XCTAssertEqual(BreadboardBoard.group(BBHole(column: 4, row: .a)), BreadboardBoard.group(BBHole(column: 4, row: .e)))
        XCTAssertNotEqual(BreadboardBoard.group(BBHole(column: 4, row: .e)), BreadboardBoard.group(BBHole(column: 4, row: .f)))
        XCTAssertNotEqual(BreadboardBoard.group(BBHole(column: 4, row: .a)), BreadboardBoard.group(BBHole(column: 5, row: .a)))
        XCTAssertEqual(BreadboardBoard.group(BBHole(column: 1, row: .topPlus)), BreadboardBoard.group(BBHole(column: 30, row: .topPlus)))
        XCTAssertNotEqual(BreadboardBoard.group(BBHole(column: 1, row: .topPlus)), BreadboardBoard.group(BBHole(column: 1, row: .topMinus)))
        XCTAssertNotEqual(BreadboardBoard.group(BBHole(column: 1, row: .topMinus)), BreadboardBoard.group(BBHole(column: 1, row: .botMinus)))
        let bend = BreadboardRoute.manhattan(from: BBHole(column: 2, row: .c), to: BBHole(column: 8, row: .j))
        XCTAssertEqual(bend.count, 3)
        XCTAssertEqual(bend[1].x, 8)
        XCTAssertEqual(bend[1].y, BBRow.c.unitY)
    }

    func testColorBandsFollowTheValue() {
        XCTAssertEqual(BreadboardBands.fourBand(ohms: 1_000), ["brown", "black", "red", "gold"])
        XCTAssertEqual(BreadboardBands.fourBand(ohms: 2_000), ["red", "black", "red", "gold"])
        XCTAssertEqual(BreadboardBands.fourBand(ohms: 330), ["orange", "orange", "brown", "gold"])
        XCTAssertEqual(BreadboardBands.fourBand(ohms: 47_000), ["yellow", "violet", "orange", "gold"])
        XCTAssertEqual(BreadboardBands.fourBand(ohms: 100_000), ["brown", "black", "yellow", "gold"])
    }

    func testSeriesMidNodeIsNotShorted() throws {
        let layout = try layout(.seriesResistors)
        let r1 = try XCTUnwrap(layout.component("r1"))
        let r2 = try XCTUnwrap(layout.component("r2"))
        XCTAssertEqual(r1.leads.map(\.net), ["Vs", "V1"])
        XCTAssertEqual(r2.leads.map(\.net), ["V1", "GND"])
        if case .resistor(let ohms, _, let bands) = r1.part {
            XCTAssertEqual(ohms, 1_000, accuracy: 1e-6)
            XCTAssertEqual(bands, ["brown", "black", "red", "gold"])
        } else {
            XCTFail("R1")
        }
        XCTAssertEqual(BreadboardBoard.group(r1.leads[1].hole), BreadboardBoard.group(r2.leads[0].hole))
        XCTAssertNotEqual(BreadboardBoard.group(r1.leads[0].hole), BreadboardBoard.group(r2.leads[1].hole))
    }

    func testDividerTapAndParallelBranches() throws {
        let divider = try layout(.voltageDivider)
        XCTAssertEqual(divider.component("r1")?.leads.map(\.net), ["Vin", "Vout"])
        XCTAssertEqual(divider.component("r2")?.leads.map(\.net), ["Vout", "GND"])
        XCTAssertTrue(divider.jumpers.contains { $0.net == "Vout" })

        let parallel = try layout(.parallelResistors)
        for id in ["r1", "r2"] {
            let part = try XCTUnwrap(parallel.component(id))
            XCTAssertEqual(part.leads.map(\.net), ["Vs", "GND"])
            XCTAssertEqual(part.leads[0].hole.column, part.leads[1].hole.column)
            XCTAssertNotEqual(BreadboardBoard.group(part.leads[0].hole), BreadboardBoard.group(part.leads[1].hole))
        }
    }

    func testRCPolarityAndFilterTopology() throws {
        let rc = try layout(.rcStep)
        guard case .electrolytic = rc.component("c")?.part else {
            return XCTFail("1 µF is an electrolytic")
        }
        XCTAssertEqual(rc.component("c")?.leads.map(\.net), ["Vc", "GND"])
        XCTAssertEqual(rc.component("r")?.leads.map(\.net), ["Vinf", "Vc"])

        let low = try layout(.firstOrderFilter)
        XCTAssertEqual(low.component("r")?.leads.map(\.net), ["Vin", "Vout"])
        XCTAssertEqual(low.component("c")?.leads.map(\.net), ["Vout", "GND"])
        guard case .ceramic = low.component("c")?.part else {
            return XCTFail("10 nF is ceramic")
        }

        var inputs = ElectronicsLab.info(.firstOrderFilter).defaults
        inputs["kind"] = "highpass"
        let solved = try ElectronicsLab.solve(.firstOrderFilter, unknown: "cutoff", inputs: inputs)
        let high = try XCTUnwrap(BreadboardLayouts.make(solved))
        XCTAssertTrue(BreadboardNetlist.audit(high).ok)
        XCTAssertEqual(high.component("c")?.leads.map(\.net), ["Vin", "Vout"])
        XCTAssertEqual(high.component("r")?.leads.map(\.net), ["Vout", "GND"])
    }

    func testLEDCathodeIsGround() throws {
        let layout = try layout(.ledSeries)
        let led = try XCTUnwrap(layout.component("led"))
        XCTAssertEqual(led.leads.map(\.net), ["Van", "GND"])
        XCTAssertEqual(layout.component("r")?.leads.map(\.net), ["Vs", "Van"])
    }

    func testBJTAndMOSPinOrder() throws {
        let bias = try layout(.bjtBias)
        let npn = try XCTUnwrap(bias.component("q"))
        XCTAssertEqual(npn.leads.map(\.net), ["Ve", "Vb", "Vc"])
        XCTAssertEqual(bias.component("r1")?.leads.map(\.net), ["Vcc", "Vb"])
        XCTAssertEqual(bias.component("r2")?.leads.map(\.net), ["Vb", "GND"])
        XCTAssertEqual(bias.component("rc")?.leads.map(\.net), ["Vc", "Vcc"])
        XCTAssertEqual(bias.component("re")?.leads.map(\.net), ["Ve", "GND"])
        if case .resistor(let ohms, _, let bands) = bias.component("r1")?.part {
            XCTAssertEqual(ohms, 47_000, accuracy: 1)
            XCTAssertEqual(bands.first, "yellow")
        } else {
            XCTFail("R1")
        }

        let switched = try layout(.bjtSwitch)
        XCTAssertEqual(switched.component("q")?.leads.map(\.net), ["GND", "Vb", "Vc"])
        XCTAssertEqual(switched.component("rb")?.leads.map(\.net), ["Vin", "Vb"])
        XCTAssertNotEqual(switched.component("vin")?.leads[0].net, "Vcc")

        let mos = try layout(.mosSwitch)
        XCTAssertEqual(mos.component("m")?.leads.map(\.net), ["GND", "Vgs", "Vd"])
        XCTAssertEqual(mos.component("rd")?.leads.map(\.net), ["Vd", "Vdd"])
        XCTAssertNil(mos.components.first { $0.id == "rdson" })
    }

    func testOpAmp741Pinout() throws {
        let inv = try layout(.invertingAmp)
        let chip = try XCTUnwrap(inv.component("u"))
        XCTAssertEqual(chip.leads.map(\.net), ["NC1", "SUM", "GND", "−V", "NC5", "Vout", "+V", "NC8"])
        XCTAssertEqual(chip.leads[1].net, "SUM")
        XCTAssertEqual(chip.leads[2].net, "GND")
        XCTAssertEqual(chip.leads[3].net, "−V")
        XCTAssertEqual(chip.leads[5].net, "Vout")
        XCTAssertEqual(chip.leads[6].net, "+V")
        XCTAssertEqual(chip.leads[0].hole.row, .e)
        XCTAssertEqual(chip.leads[7].hole.row, .f)
        XCTAssertEqual(chip.leads[0].hole.column, chip.leads[7].hole.column)
        XCTAssertEqual(inv.component("rin")?.leads.map(\.net), ["Vin", "SUM"])
        XCTAssertEqual(inv.component("rf")?.leads.map(\.net), ["SUM", "Vout"])
        XCTAssertFalse(inv.jumpers.contains { $0.net == "−V" && $0.a.row == .topMinus })

        let non = try layout(.nonInvertingAmp)
        XCTAssertEqual(non.component("u")?.leads[2].net, "Vin")
        XCTAssertEqual(non.component("rg")?.leads.map(\.net), ["SUM", "GND"])
        XCTAssertEqual(non.component("rf")?.leads.map(\.net), ["SUM", "Vout"])
        XCTAssertTrue(BreadboardNetlist.audit(non).ok)
    }

    func test555AstableMonostableAndFlasher() throws {
        let astable = try layout(.astable555)
        let chip = try XCTUnwrap(astable.component("u"))
        XCTAssertEqual(chip.leads[0].net, "GND")
        XCTAssertEqual(chip.leads[1].net, "TIME")
        XCTAssertEqual(chip.leads[2].net, "OUT")
        XCTAssertEqual(chip.leads[3].net, "Vcc")
        XCTAssertEqual(chip.leads[4].net, "CTRL")
        XCTAssertEqual(chip.leads[5].net, "TIME")
        XCTAssertEqual(chip.leads[6].net, "DIS")
        XCTAssertEqual(chip.leads[7].net, "Vcc")
        XCTAssertEqual(astable.component("r1")?.leads.map(\.net), ["DIS", "Vcc"])
        XCTAssertEqual(astable.component("r2")?.leads.map(\.net), ["DIS", "TIME"])
        XCTAssertEqual(astable.component("c")?.leads.map(\.net), ["TIME", "GND"])
        guard case .electrolytic = astable.component("c")?.part else {
            return XCTFail("timing cap")
        }
        XCTAssertEqual(astable.jumpers.filter { $0.net == "CTRL" }.count, 0)
        XCTAssertNil(astable.component("led"))

        let mono = try layout(.monostable555)
        XCTAssertEqual(mono.component("u")?.leads[1].net, "TRIG")
        XCTAssertEqual(mono.component("u")?.leads[5].net, "RC")
        XCTAssertEqual(mono.component("u")?.leads[6].net, "RC")
        XCTAssertNotEqual(mono.component("u")?.leads[1].net, mono.component("u")?.leads[5].net)
        XCTAssertTrue(mono.jumpers.contains { $0.net == "TRIG" })

        let flash = try layout(.ledFlasher)
        XCTAssertEqual(flash.component("led")?.leads.map(\.net), ["LED", "GND"])
        XCTAssertEqual(flash.component("rled")?.leads.map(\.net), ["OUT", "LED"])
        XCTAssertEqual(flash.component("u")?.leads[1].net, flash.component("u")?.leads[5].net)
    }

    func testSevenSegmentFollowsTheMask() throws {
        let eight = try layout(.sevenSegment)
        guard case .display(_, let digit, let mask, let pins) = eight.component("seg")?.part else {
            return XCTFail("display")
        }
        XCTAssertEqual(digit, 8)
        XCTAssertEqual(mask, 0b1111111)
        XCTAssertEqual(pins, ["e", "d", "CC", "c", "DP", "b", "a", "CC", "f", "g"])
        let resistors = eight.components.filter {
            if case .resistor = $0.part { return true }
            return false
        }
        XCTAssertEqual(resistors.count, 7)
        let anodes = Set(resistors.map { $0.leads[1].net })
        XCTAssertEqual(anodes.count, 7)
        XCTAssertFalse(anodes.contains("GND"))
        XCTAssertEqual(eight.component("seg")?.leads[2].net, "GND")
        XCTAssertEqual(eight.component("seg")?.leads[7].net, "GND")

        var inputs = ElectronicsLab.info(.sevenSegment).defaults
        inputs["digit"] = "1"
        let solved = try ElectronicsLab.solve(.sevenSegment, unknown: "map", inputs: inputs)
        let one = try XCTUnwrap(BreadboardLayouts.make(solved))
        XCTAssertTrue(BreadboardNetlist.audit(one).ok, "\(BreadboardNetlist.audit(one))")
        let lit = one.components.filter {
            if case .resistor = $0.part { return true }
            return false
        }
        XCTAssertEqual(Set(lit.map { $0.leads[1].net }), ["Sb", "Sc"])
    }

    func testAuditCatchesAShortAnOpenAndAClash() {
        let shorted = BreadboardLayout(
            circuit: .seriesResistors,
            components: [
                BBComponent(id: "r", part: .resistor(ohms: 1000, label: "R", bands: []), leads: [
                    BBLead(hole: BBHole(column: 4, row: .c), net: "A"),
                    BBLead(hole: BBHole(column: 8, row: .c), net: "B"),
                ]),
            ],
            jumpers: [
                BBJumper(id: "bad", net: "A", a: BBHole(column: 4, row: .a), b: BBHole(column: 8, row: .a), color: .red),
            ],
            supplies: [],
            railLabels: [],
            caption: "bad"
        )
        let shortAudit = BreadboardNetlist.audit(shorted)
        XCTAssertFalse(shortAudit.ok)
        XCTAssertFalse(shortAudit.shorts.isEmpty)

        let open = BreadboardLayout(
            circuit: .seriesResistors,
            components: [
                BBComponent(id: "r1", part: .resistor(ohms: 1000, label: "R1", bands: []), leads: [
                    BBLead(hole: BBHole(column: 4, row: .c), net: "MID"),
                    BBLead(hole: BBHole(column: 8, row: .c), net: "GND"),
                ]),
                BBComponent(id: "r2", part: .resistor(ohms: 2000, label: "R2", bands: []), leads: [
                    BBLead(hole: BBHole(column: 12, row: .c), net: "MID"),
                    BBLead(hole: BBHole(column: 16, row: .c), net: "Vs"),
                ]),
            ],
            jumpers: [],
            supplies: [],
            railLabels: [],
            caption: "open"
        )
        XCTAssertFalse(BreadboardNetlist.audit(open).opens.isEmpty)

        let clash = BreadboardLayout(
            circuit: .ledSeries,
            components: [
                BBComponent(id: "r", part: .resistor(ohms: 330, label: "R", bands: []), leads: [
                    BBLead(hole: BBHole(column: 4, row: .c), net: "Vs"),
                    BBLead(hole: BBHole(column: 8, row: .c), net: "N"),
                ]),
                BBComponent(id: "led", part: .led(label: "LED"), leads: [
                    BBLead(hole: BBHole(column: 8, row: .c), net: "N"),
                    BBLead(hole: BBHole(column: 8, row: .f), net: "GND"),
                ]),
            ],
            jumpers: [],
            supplies: [],
            railLabels: [],
            caption: "clash"
        )
        XCTAssertFalse(BreadboardNetlist.audit(clash).clashes.isEmpty)
    }

    func testNewDiodeAndOpAmpBoardsAudit() throws {
        let extras: [ElectronicsCircuit] = [
            .theveninNorton, .rlStep, .halfWave, .shuntClipper, .clamper,
            .summingAmp, .diffAmp, .integrator, .differentiator, .comparator, .linearDrop,
        ]
        for circuit in extras {
            XCTAssertTrue(BreadboardLayouts.supports(circuit), circuit.rawValue)
            let board = try layout(circuit)
            let audit = BreadboardNetlist.audit(board)
            XCTAssertTrue(audit.ok, "\(circuit.rawValue) \(audit)")
            XCTAssertFalse(board.meters.isEmpty, circuit.rawValue)
        }
    }

    func testMetersUseSensibleCurrentUnits() throws {
        let board = try layout(.voltageDivider)
        XCTAssertFalse(board.meters.isEmpty)
        let currents = board.meters.filter { $0.kind == .current }
        XCTAssertFalse(currents.isEmpty)
        // Default divider is 12 V / 20 kΩ = 0.6 mA.
        XCTAssertTrue(currents.contains { $0.reading.contains("mA") || $0.reading.contains("µA") || $0.reading.contains("A") })
        let volts = board.meters.filter { $0.kind == .voltage }
        XCTAssertTrue(volts.contains { $0.reading.contains("V") })
    }

    func testLabKitSICurrentPrefixes() {
        XCTAssertEqual(LabKit.si(0.6, unit: "A"), "600 mA")
        XCTAssertEqual(LabKit.si(0.0006, unit: "A"), "600 µA")
        XCTAssertEqual(LabKit.si(1.5, unit: "A"), "1.50 A")
        XCTAssertEqual(LabKit.si(12, unit: "V"), "12.0 V")
        XCTAssertEqual(LabKit.si(0.012, unit: "V"), "12.0 mV")
    }

    private func layout(_ circuit: ElectronicsCircuit) throws -> BreadboardLayout {
        let info = ElectronicsLab.info(circuit)
        let solved = try ElectronicsLab.solve(circuit, unknown: info.defaultUnknown, inputs: info.defaults)
        return try XCTUnwrap(BreadboardLayouts.make(solved), circuit.rawValue)
    }
}
