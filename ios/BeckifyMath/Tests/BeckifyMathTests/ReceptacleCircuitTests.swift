import XCTest
@testable import BeckifyMath

final class ReceptacleCircuitTests: XCTestCase {

    func testTwentyAmpNonDwellingCounts() throws {
        let full = try ReceptacleCircuit.solve(ReceptacleCircuitInput(breakerAmps: 20, continuous: false))
        XCTAssertEqual(full.circuitVA, 2400, accuracy: 1e-9)
        XCTAssertEqual(full.nonDwellingCountFull, 13)
        XCTAssertEqual(full.nonDwellingCountContinuous, 10)
        XCTAssertEqual(full.nonDwellingCount, 13)

        let cont = try ReceptacleCircuit.solve(ReceptacleCircuitInput(breakerAmps: 20, continuous: true))
        XCTAssertEqual(cont.usableVA, 1920, accuracy: 1e-9)
        XCTAssertEqual(cont.nonDwellingCount, 10)
        XCTAssertTrue(cont.nema520Permitted)
    }

    func testFifteenAmpCountsAndNema520Flag() throws {
        let r = try ReceptacleCircuit.solve(ReceptacleCircuitInput(breakerAmps: 15, continuous: true, size: "14"))
        XCTAssertEqual(r.nonDwellingCountFull, 10)
        XCTAssertEqual(r.nonDwellingCountContinuous, 8, "1440 / 180 is exactly 8")
        XCTAssertFalse(r.nema520Permitted)
        XCTAssertTrue(r.notes.contains { $0.contains("210.21(B)(3)") })
        XCTAssertTrue(r.conductorOK)
    }

    func testYokeCountEdgeCases() {
        XCTAssertEqual(ReceptacleCircuit.yokeCount(circuitVA: 0, continuous: false), 0)
        XCTAssertEqual(ReceptacleCircuit.yokeCount(circuitVA: -100, continuous: true), 0)
        XCTAssertEqual(ReceptacleCircuit.yokeCount(circuitVA: .nan, continuous: true), 0)
        XCTAssertEqual(ReceptacleCircuit.yokeCount(circuitVA: 179, continuous: false), 0)
        XCTAssertEqual(ReceptacleCircuit.yokeCount(circuitVA: 180, continuous: false), 1)
        XCTAssertEqual(ReceptacleCircuit.yokeCount(circuitVA: 225, continuous: true), 1)
    }

    func testDwellingGuidanceIsNotACodeLimit() throws {
        let r = try ReceptacleCircuit.solve(ReceptacleCircuitInput(occupancy: .dwelling))
        XCTAssertEqual(r.dwellingGuidance, 8...10)
        XCTAssertEqual(r.headlineCount, 10)
        XCTAssertTrue(r.notes.contains { $0.contains("220.14(J)") })
        XCTAssertTrue(r.notes.contains { $0.contains("210.11(C)") })
        XCTAssertEqual(ReceptacleCircuit.dwellingGuidance(breakerAmps: 15, volts: 120), 6...8)
    }

    func testConductorMinimumPer2404D() {
        XCTAssertFalse(ReceptacleCircuit.conductorMeetsMinimum(size: "14", breakerAmps: 20, material: .copper))
        XCTAssertTrue(ReceptacleCircuit.conductorMeetsMinimum(size: "12", breakerAmps: 20, material: .copper))
        XCTAssertTrue(ReceptacleCircuit.conductorMeetsMinimum(size: "10", breakerAmps: 20, material: .copper))
        XCTAssertFalse(ReceptacleCircuit.conductorMeetsMinimum(size: "12", breakerAmps: 20, material: .aluminum))
        XCTAssertTrue(ReceptacleCircuit.conductorMeetsMinimum(size: "10", breakerAmps: 20, material: .aluminum))
        XCTAssertTrue(ReceptacleCircuit.conductorMeetsMinimum(size: "14", breakerAmps: 15, material: .copper))
        XCTAssertTrue(ReceptacleCircuit.conductorMeetsMinimum(size: "250", breakerAmps: 20, material: .copper))
    }

    func testUndersizedConductorAddsNote() throws {
        let r = try ReceptacleCircuit.solve(ReceptacleCircuitInput(size: "14"))
        XCTAssertFalse(r.conductorOK)
        XCTAssertTrue(r.notes.contains { $0.contains("240.4(D)") })
    }

    func testVoltageDropReusesVoltageDropMath() throws {
        let r = try ReceptacleCircuit.solve(ReceptacleCircuitInput(oneWayFeet: 100, plannedLoadVA: 1440))
        let expected = try VoltageDrop.calculate(
            system: .singlePhase, current: 12, oneWayFeet: 100, supplyVolts: 120, size: "12", material: .copper
        )
        XCTAssertEqual(r.vdAmps, 12, accuracy: 1e-9)
        XCTAssertTrue(r.vdUsesPlannedLoad)
        XCTAssertEqual(r.voltageDrop, expected)
        XCTAssertEqual(r.plannedPercentOfCircuit ?? 0, 60, accuracy: 1e-9)
        XCTAssertEqual(r.plannedFitsUsable, true)
    }

    func testNoPlannedLoadUsesUsableCapacityForDrop() throws {
        let r = try ReceptacleCircuit.solve(ReceptacleCircuitInput(continuous: true, plannedLoadVA: nil))
        XCTAssertFalse(r.vdUsesPlannedLoad)
        XCTAssertEqual(r.vdAmps, 16, accuracy: 1e-9)
        XCTAssertNil(r.plannedFitsUsable)
        let zero = try ReceptacleCircuit.solve(ReceptacleCircuitInput(plannedLoadVA: 0))
        XCTAssertFalse(zero.vdUsesPlannedLoad)
    }

    func testPlannedLoadOverEightyPercent() throws {
        let r = try ReceptacleCircuit.solve(ReceptacleCircuitInput(continuous: true, plannedLoadVA: 2000))
        XCTAssertEqual(r.plannedFitsUsable, false)
        let ok = try ReceptacleCircuit.solve(ReceptacleCircuitInput(continuous: false, plannedLoadVA: 2000))
        XCTAssertEqual(ok.plannedFitsUsable, true)
    }

    func testRejectsBadInputs() {
        XCTAssertThrowsError(try ReceptacleCircuit.solve(ReceptacleCircuitInput(breakerAmps: 30)))
        XCTAssertThrowsError(try ReceptacleCircuit.solve(ReceptacleCircuitInput(oneWayFeet: 0)))
        XCTAssertThrowsError(try ReceptacleCircuit.solve(ReceptacleCircuitInput(volts: .nan)))
        XCTAssertThrowsError(try ReceptacleCircuit.solve(ReceptacleCircuitInput(plannedLoadVA: -5)))
        XCTAssertThrowsError(try ReceptacleCircuit.solve(ReceptacleCircuitInput(size: "99")))
    }

    func testLongRunFailsThreePercent() throws {
        let r = try ReceptacleCircuit.solve(ReceptacleCircuitInput(oneWayFeet: 200, plannedLoadVA: 1920))
        XCTAssertFalse(r.voltageDrop.meets3Percent)
    }

    func testToolIsRegistered() {
        XCTAssertTrue(ToolCalculationPolicy.knownToolIDs.contains("receptacleCircuit"))
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "receptacleCircuit"), .jobsite)
        XCTAssertNotNil(ToolHowItWorksCatalog.copy(forToolID: "receptacleCircuit"))
    }
}
