import XCTest
@testable import BeckifyMath

final class OhmsLawTests: XCTestCase {
    func testSolveForVoltage() throws {
        let r = try OhmsLaw.solve(voltage: nil, current: 2, resistance: 6)
        XCTAssertEqual(r.voltage, 12, accuracy: 1e-9)
        XCTAssertEqual(r.power, 24, accuracy: 1e-9)
    }

    func testSolveForCurrent() throws {
        let r = try OhmsLaw.solve(voltage: 120, current: nil, resistance: 10)
        XCTAssertEqual(r.current, 12, accuracy: 1e-9)
    }

    func testSolveForResistance() throws {
        let r = try OhmsLaw.solve(voltage: 24, current: 2, resistance: nil)
        XCTAssertEqual(r.resistance, 12, accuracy: 1e-9)
    }

    func testNeedsTwoValues() {
        XCTAssertThrowsError(try OhmsLaw.solve(voltage: 12, current: nil, resistance: nil))
    }
}

final class PowerWizardTests: XCTestCase {
    /// Spot-check from product spec: 480 V 3Ø 50 kW PF 0.90 → 66.8 A.
    func testThreePhase50kW480V() throws {
        let r = try PowerWizard.solve(
            system: .threePhase,
            known: .kilowatts(50),
            voltage: 480,
            powerFactor: 0.90,
            efficiency: 1
        )
        XCTAssertEqual(r.amps, 66.8, accuracy: 0.05)
        XCTAssertEqual(r.kW, 50, accuracy: 1e-9)
        XCTAssertEqual(r.kVA, 50 / 0.90, accuracy: 1e-9)
    }

    func testDCFromAmps() throws {
        let r = try PowerWizard.solve(
            system: .dc,
            known: .amps(10),
            voltage: 48,
            powerFactor: 0.5,
            efficiency: 1
        )
        XCTAssertEqual(r.amps, 10, accuracy: 1e-9)
        XCTAssertEqual(r.kW, 0.48, accuracy: 1e-9)
        XCTAssertEqual(r.powerFactor, 1, accuracy: 1e-9)
        XCTAssertEqual(r.kVAR, 0, accuracy: 1e-9)
    }

    func testSinglePhaseFromKVA() throws {
        let r = try PowerWizard.solve(
            system: .singlePhase,
            known: .kilovoltAmps(12),
            voltage: 240,
            powerFactor: 0.8,
            efficiency: 1
        )
        XCTAssertEqual(r.amps, 50, accuracy: 1e-9)
        XCTAssertEqual(r.kW, 9.6, accuracy: 1e-9)
    }
}

final class ACPowerTests: XCTestCase {
    func testThreePhaseApparent() throws {
        let r = try ACPower.solve(system: .threePhase, voltage: 480, current: 66.823, powerFactor: 0.9)
        XCTAssertEqual(r.kW, 50, accuracy: 0.05)
    }

    func testDCPowerVIR() throws {
        let r = try DCPower.fromIR(current: 10, resistance: 4)
        XCTAssertEqual(r.power, 400, accuracy: 1e-9)
        XCTAssertEqual(r.voltage, 40, accuracy: 1e-9)
    }
}

final class VoltageDropTests: XCTestCase {
    func testThreePhaseCopperExample() throws {
        // Website example: 480 V, 45 A, 250 ft, Cu 4 AWG, 3Ø
        let r = try VoltageDrop.calculate(
            system: .threePhase,
            current: 45,
            oneWayFeet: 250,
            supplyVolts: 480,
            size: "4",
            material: .copper
        )
        let expected = Foundation.sqrt(3.0) * 12.9 * 45 * 250 / 41740
        XCTAssertEqual(r.dropVolts, expected, accuracy: 1e-6)
        XCTAssertEqual(r.ampacity75C, 85)
        XCTAssertEqual(r.ampacityOK, true)
        XCTAssertTrue(r.meets3Percent)
        XCTAssertTrue(r.meets5Percent)
    }
}

final class ConduitFillTests: XCTestCase {
    func testThreeConductorsUse40Percent() throws {
        let r = try ConduitFill.calculate(quantity: 3, size: "12", tradeSize: "1/2")
        XCTAssertEqual(r.maxFillPercent, 40)
        XCTAssertEqual(r.totalWireArea, 3 * 0.0133, accuracy: 1e-9)
        XCTAssertTrue(r.passes)
    }

    func testSingleConductorUses53Percent() throws {
        let r = try ConduitFill.calculate(quantity: 1, size: "4/0", tradeSize: "1/2")
        XCTAssertEqual(r.maxFillPercent, 53)
        XCTAssertFalse(r.passes)
        XCTAssertNotNil(r.suggestedTradeSize)
    }

    func testTwoConductorsUse31Percent() throws {
        let r = try ConduitFill.calculate(quantity: 2, size: "12", tradeSize: "1/2")
        XCTAssertEqual(r.maxFillPercent, 31)
    }
}

final class TransformerSizingTests: XCTestCase {
    func testContinuousThreePhaseNote1() throws {
        // Website example: 38 kW, PF 90%, 480→208, 3Ø, continuous
        let r = try TransformerSizing.size(
            system: .threePhase,
            load: .kW(38, powerFactor: 0.90),
            primaryVolts: 480,
            secondaryVolts: 208,
            continuous: true
        )
        XCTAssertEqual(r.loadKVA, 38 / 0.90, accuracy: 1e-9)
        XCTAssertEqual(r.designKVA, (38 / 0.90) * 1.25, accuracy: 1e-9)
        XCTAssertEqual(r.selectedKVA, 75)
        XCTAssertEqual(r.primaryOnly.percent, 125)
        XCTAssertTrue(r.primaryOnly.roundsUp)
        XCTAssertEqual(r.primaryWithSecondary.percent, 250)
        XCTAssertEqual(r.secondaryProtection.percent, 125)
    }

    func testSmallPrimaryNoRoundUp() throws {
        let r = try TransformerSizing.size(
            system: .singlePhase,
            load: .kVA(1),
            primaryVolts: 480,
            secondaryVolts: 120,
            continuous: false
        )
        // 1 kVA / 480 V ≈ 2.08 A → 167 % row, no Note 1 round-up
        XCTAssertEqual(r.primaryOnly.percent, 167)
        XCTAssertFalse(r.primaryOnly.roundsUp)
    }
}

final class Timer555Tests: XCTestCase {
    func testAstableDocExample() throws {
        // 10 kΩ, 47 kΩ, 0.1 µF, no diode
        let r = try Timer555.astable(r1: 10e3, r2: 47e3, capacitance: 0.1e-6, diodeSteering: false)
        let tHigh = Foundation.log(2.0) * (10e3 + 47e3) * 0.1e-6
        let tLow = Foundation.log(2.0) * 47e3 * 0.1e-6
        XCTAssertEqual(r.timeHigh, tHigh, accuracy: 1e-12)
        XCTAssertEqual(r.timeLow, tLow, accuracy: 1e-12)
        XCTAssertGreaterThan(r.dutyPercent, 50)
        XCTAssertEqual(r.frequency, 1 / (tHigh + tLow), accuracy: 1e-6)
    }

    func testMonostableLn3() throws {
        let r = try Timer555.monostable(resistance: 10e3, capacitance: 1e-6)
        XCTAssertEqual(r.pulseWidth, Foundation.log(3.0) * 10e3 * 1e-6, accuracy: 1e-12)
    }
}

final class MotorFLATests: XCTestCase {
    func testTable430_248() {
        XCTAssertEqual(MotorFLA.lookup(horsepower: "1", voltageColumn: "115", threePhase: false), 16)
        XCTAssertEqual(MotorFLA.lookup(horsepower: "5", voltageColumn: "230", threePhase: false), 28)
    }

    func testTable430_250And480MapsTo460() {
        XCTAssertEqual(MotorFLA.tableVoltage(forSystemVolts: 480, threePhase: true), "460")
        XCTAssertEqual(MotorFLA.lookup(horsepower: "50", voltageColumn: "460", threePhase: true), 65)
        XCTAssertEqual(MotorFLA.conductorAmps(fla: 65), 81.25, accuracy: 1e-9)
    }
}

final class WireAmpacityTests: XCTestCase {
    func testCopper75CLookup() throws {
        XCTAssertEqual(NECTables.ampacity75C(size: "12", material: .copper), 25)
        XCTAssertEqual(NECTables.ampacity75C(size: "4/0", material: .copper), 230)
        let sized = try WireAmpacity.smallestConductor(loadAmps: 95, material: .copper)
        XCTAssertEqual(sized.size, "3")
        XCTAssertEqual(sized.ampacity, 100)
    }

    func testAluminumSkips14AWG() {
        XCTAssertNil(NECTables.ampacity75C(size: "14", material: .aluminum))
        XCTAssertEqual(NECTables.ampacity75C(size: "12", material: .aluminum), 20)
    }
}
