import XCTest
@testable import BeckifyMath

final class WorkbenchBoardsTests: XCTestCase {
    private let stageValues = WorkbenchStageValues(
        vin: 1, v1: 1, v2: 2, rin: 10_000, rf: 47_000, rg: 10_000, r1: 10_000, r2: 22_000,
        capacitance: 100e-9, outputVolts: -4.7
    )

    private func filterValues(q: Double = 0.707, k: Double? = 1.586) -> WorkbenchFilterValues {
        WorkbenchFilterValues(resistance: 10_000, capacitance: 15.9e-9, cornerHz: 1000, quality: q, sallenKeyK: k)
    }

    func testEveryPartAndTopologyAuditsClean() {
        for part in WorkbenchBoards.opAmpParts {
            for topology in OpAmpTopology.allCases {
                guard let layout = WorkbenchBoards.stage(topology, values: stageValues, part: part) else {
                    XCTFail("\(part.name) \(topology) did not fit the board: \(WorkbenchBoards.lastFailure)")
                    continue
                }
                let audit = BreadboardNetlist.audit(layout)
                XCTAssertTrue(audit.ok, "\(part.name) \(topology): \(audit)")
            }
        }
    }

    func testEveryPartAndFilterAuditsClean() {
        for part in WorkbenchBoards.opAmpParts {
            for family in AnalogFilterFamily.allCases {
                for q in [0.5, 0.707, 2.0] {
                    // A passive twin-T is Q 0.25, so the board only exists for that.
                    let values = filterValues(q: family == .twinTNotch ? 0.25 : q, k: 3 - 1 / q)
                    guard let layout = WorkbenchBoards.filter(family, values: values, part: part) else {
                        XCTFail("\(part.name) \(family) q=\(q) did not fit the board: \(WorkbenchBoards.lastFailure)")
                        continue
                    }
                    let audit = BreadboardNetlist.audit(layout)
                    XCTAssertTrue(audit.ok, "\(part.name) \(family) q=\(q): \(audit)")
                }
            }
        }
    }

    func testSeatedPackageHasRealPinNumbers() throws {
        let part = try XCTUnwrap(WorkbenchBoards.opAmpPart(id: "lm358"))
        let layout = try XCTUnwrap(WorkbenchBoards.stage(.inverting, values: stageValues, part: part))
        let chip = try XCTUnwrap(layout.component("u"))
        guard case .dip8(let name, let pins) = chip.part else { return XCTFail("expected a DIP-8") }
        XCTAssertEqual(name, "LM358")
        XCTAssertEqual(pins[0], "OUT A")
        XCTAssertEqual(pins[7], "V+")
        // Pin 2 (IN− A) carries the summing node and pin 1 (OUT A) carries Vout.
        XCTAssertEqual(chip.leads[1].net, "SUM")
        XCTAssertEqual(chip.leads[0].net, "Vout")
        XCTAssertEqual(chip.leads[7].net, "+V")
        XCTAssertEqual(chip.leads[3].net, "−V")
    }

    func testQuadSeatsFourteenPinsAndTiesOffSpares() throws {
        let part = try XCTUnwrap(WorkbenchBoards.opAmpPart(id: "lm324"))
        let layout = try XCTUnwrap(WorkbenchBoards.stage(.noninverting, values: stageValues, part: part))
        let chip = try XCTUnwrap(layout.component("u"))
        XCTAssertEqual(chip.leads.count, 14)
        XCTAssertEqual(chip.leads[3].net, "+V")   // pin 4
        XCTAssertEqual(chip.leads[10].net, "−V")  // pin 11
        for letter in ["B", "C", "D"] {
            XCTAssertTrue(layout.jumpers.contains { $0.id == "tie\(letter)" }, "spare amp \(letter) is tied off")
        }
    }

    func testPartTablesMatchPinoutCatalog() throws {
        for part in WorkbenchBoards.opAmpParts {
            let catalog = try XCTUnwrap(PartPinouts.part(id: part.id), part.id)
            XCTAssertEqual(catalog.package, .dip(part.pinCount), part.id)
            func role(_ number: Int) -> PinRole? { catalog.pins.first { $0.number == number }?.role }
            XCTAssertEqual(role(part.vPlus), .supplyPlus, part.id)
            XCTAssertEqual(role(part.vMinus), .supplyMinus, part.id)
            for amp in part.amps {
                XCTAssertEqual(role(amp.inMinus), .inputMinus, "\(part.id) \(amp.letter)")
                XCTAssertEqual(role(amp.inPlus), .inputPlus, "\(part.id) \(amp.letter)")
                XCTAssertEqual(role(amp.out), .output, "\(part.id) \(amp.letter)")
            }
        }
    }

    func testBoardsAreNotDrawnForCircuitsThatCannotRealizeTheRequest() throws {
        let part = try XCTUnwrap(WorkbenchBoards.opAmpPart(id: "lm741"))
        // Q = 0.4 would need K = 0.5. A non-inverting stage cannot do that.
        let low = filterValues(q: 0.4, k: 0.5)
        XCTAssertNotNil(WorkbenchBoards.filterLimitation(.sallenKeyLowpass, values: low))
        XCTAssertNil(WorkbenchBoards.filter(.sallenKeyLowpass, values: low, part: part))
        // A passive twin-T cannot be sharper than about Q 0.25.
        XCTAssertNotNil(WorkbenchBoards.filterLimitation(.twinTNotch, values: filterValues(q: 2, k: nil)))
        XCTAssertNil(WorkbenchBoards.filterLimitation(.twinTNotch, values: filterValues(q: 0.25, k: nil)))
    }

    func testGainNoteAppearsOnlyWhenTheCircuitGainDiffers() {
        let sk = filterValues(q: 0.707, k: 1.586)
        XCTAssertEqual(WorkbenchBoards.realizedGain(.sallenKeyLowpass, values: sk), 1.586, accuracy: 1e-9)
        XCTAssertNil(WorkbenchBoards.filterGainNote(.sallenKeyLowpass, values: sk, requestedGain: 1.586))
        XCTAssertNotNil(WorkbenchBoards.filterGainNote(.sallenKeyLowpass, values: sk, requestedGain: 1))
        XCTAssertNotNil(WorkbenchBoards.filterGainNote(.firstOrderAllpass, values: sk, requestedGain: 2))
        XCTAssertNil(WorkbenchBoards.filterGainNote(.rcLowpass, values: sk, requestedGain: 1))
    }

    func testFilterCapacitorsAreNeverPolarized() throws {
        let part = try XCTUnwrap(WorkbenchBoards.opAmpPart(id: "lm741"))
        // 10 Hz at 10 kΩ puts 1.59 µF in the signal path.
        let big = WorkbenchFilterValues(resistance: 10_000, capacitance: 1.59e-6, cornerHz: 10, quality: 0.707, sallenKeyK: 1.586)
        for family in [AnalogFilterFamily.sallenKeyLowpass, .sallenKeyHighpass, .firstOrderAllpass, .rcLowpass, .rcHighpass] {
            let layout = try XCTUnwrap(WorkbenchBoards.filter(family, values: big, part: part), "\(family)")
            for component in layout.components {
                if case .electrolytic = component.part { XCTFail("\(family) drew an electrolytic: \(component.id)") }
            }
        }
    }

    func testMissingValueDropsTheBoardInsteadOfDrawingItWrong() throws {
        let part = try XCTUnwrap(WorkbenchBoards.opAmpPart(id: "lm741"))
        XCTAssertNil(WorkbenchBoards.stage(.inverting, values: WorkbenchStageValues(vin: 1, rin: nil, rf: 1000), part: part))
    }

    func testFilterValuesPickTheRightCapacitor() throws {
        let result = try AnalogFilter.solve(family: .sallenKeyLowpass, designFrequency: 1000, resistance: 10_000, capacitance: 47e-9, passbandGain: 1, quality: 0.707)
        let second = WorkbenchBoards.filterValues(family: .sallenKeyLowpass, result: result, resistance: 10_000, referenceCapacitance: 47e-9)
        XCTAssertEqual(second.capacitance, result.suggestedCapacitance, accuracy: 1e-15)
        let first = WorkbenchBoards.filterValues(family: .rcLowpass, result: result, resistance: 10_000, referenceCapacitance: 47e-9)
        XCTAssertEqual(first.capacitance, 47e-9, accuracy: 1e-15)
    }
}
