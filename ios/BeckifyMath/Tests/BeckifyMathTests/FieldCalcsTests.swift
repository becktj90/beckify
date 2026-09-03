import XCTest
@testable import BeckifyMath

final class ReactanceTests: XCTestCase {
    func testSeriesReactanceAtSixtyHertz() throws {
        // 100 mH at 60 Hz is 37.699 Ω; 100 µF is 26.526 Ω.
        let result = try Reactance.series(
            frequency: 60,
            resistance: 10,
            inductance: 0.1,
            capacitance: 100e-6
        )

        XCTAssertEqual(result.inductiveReactance, 37.699, accuracy: 0.001)
        XCTAssertEqual(result.capacitiveReactance, 26.526, accuracy: 0.001)
        XCTAssertEqual(result.netReactance, 11.173, accuracy: 0.001)
        XCTAssertEqual(result.impedance, 14.995, accuracy: 0.001)
        // Net reactance is inductive, so current lags and the angle is positive.
        XCTAssertEqual(result.phaseAngleDegrees, 48.172, accuracy: 0.01)
    }

    func testOpenCapacitorDoesNotDivideByZero() throws {
        let result = try Reactance.series(frequency: 60, resistance: 10, inductance: 0.1, capacitance: 0)
        XCTAssertTrue(result.capacitiveReactance.isInfinite)
        XCTAssertEqual(result.phaseAngleDegrees, -90, accuracy: 0.001)
    }

    func testResonanceAndQ() throws {
        let result = try Reactance.resonance(inductance: 0.1, capacitance: 100e-6, resistance: 10)
        XCTAssertEqual(result.frequency, 50.329, accuracy: 0.001)
        // Q = (1/R)·√(L/C) = 0.1·√1000
        XCTAssertEqual(result.qualityFactor, 3.162, accuracy: 0.001)
        XCTAssertEqual(result.bandwidth, result.frequency / result.qualityFactor, accuracy: 0.001)
    }

    func testMissingReactiveElementsThrow() {
        XCTAssertThrowsError(try Reactance.series(frequency: 60, resistance: 10, inductance: 0, capacitance: 0))
        XCTAssertThrowsError(try Reactance.resonance(inductance: 0, capacitance: 1e-6, resistance: 1))
    }

    func testSeriesRejectsNegativeAndNonFiniteComponents() {
        XCTAssertThrowsError(try Reactance.series(
            frequency: 60, resistance: -1, inductance: 0.1, capacitance: 100e-6
        ))
        XCTAssertThrowsError(try Reactance.series(
            frequency: 60, resistance: .nan, inductance: 0.1, capacitance: 100e-6
        ))
        XCTAssertThrowsError(try Reactance.series(
            frequency: 60, resistance: 10, inductance: -0.1, capacitance: 100e-6
        ))
        XCTAssertThrowsError(try Reactance.series(
            frequency: 60, resistance: 10, inductance: .infinity, capacitance: 100e-6
        ))
        XCTAssertThrowsError(try Reactance.series(
            frequency: 60, resistance: 10, inductance: 0.1, capacitance: -100e-6
        ))
        XCTAssertThrowsError(try Reactance.series(
            frequency: 60, resistance: 10, inductance: 0.1, capacitance: .nan
        ))
    }
}

final class PowerFactorCorrectionTests: XCTestCase {
    func testCorrectionKVAR() throws {
        // 100 kW at 0.75 PF needs 88.19 kVAR to reach 0.95.
        let result = try PowerFactorCorrection.solve(
            realPowerKW: 100,
            existingPowerFactor: 0.75,
            targetPowerFactor: 0.95,
            voltage: 480
        )

        XCTAssertEqual(result.existingKVAR, 88.192, accuracy: 0.01)
        XCTAssertEqual(result.targetKVAR, 32.868, accuracy: 0.01)
        XCTAssertEqual(result.correctionKVAR, 55.323, accuracy: 0.01)
        XCTAssertEqual(result.newKVA, 105.263, accuracy: 0.01)
        XCTAssertTrue(result.capacitance > 0)
    }

    func testTargetMustImproveOnExisting() {
        XCTAssertThrowsError(try PowerFactorCorrection.solve(
            realPowerKW: 100,
            existingPowerFactor: 0.95,
            targetPowerFactor: 0.85,
            voltage: 480
        ))
    }

    func testPowerFactorRangeIsChecked() {
        XCTAssertThrowsError(try PowerFactorCorrection.solve(
            realPowerKW: 100,
            existingPowerFactor: 1.4,
            targetPowerFactor: 0.95,
            voltage: 480
        ))
    }

    func testVoltageAndFrequencyMustBeFiniteAndPositive() {
        XCTAssertThrowsError(try PowerFactorCorrection.solve(
            realPowerKW: 100, existingPowerFactor: 0.75, targetPowerFactor: 0.95,
            voltage: 0, frequency: 60
        ))
        XCTAssertThrowsError(try PowerFactorCorrection.solve(
            realPowerKW: 100, existingPowerFactor: 0.75, targetPowerFactor: 0.95,
            voltage: 480, frequency: .infinity
        ))
    }

    func testPowerFactorCorrectionRejectsDC() {
        XCTAssertThrowsError(try PowerFactorCorrection.solve(
            realPowerKW: 100, existingPowerFactor: 0.75, targetPowerFactor: 0.95,
            voltage: 480, frequency: 60, system: .dc
        ))
    }
}

final class ShortCircuitTests: XCTestCase {
    func testInfiniteBusSecondaryFault() throws {
        // 500 kVA, 480 V, 5% Z: FLA 601.4 A, ISC about 12 kA.
        let result = try ShortCircuit.transformerSecondary(
            kVA: 500,
            secondaryVolts: 480,
            impedancePercent: 5
        )

        XCTAssertEqual(result.fullLoadAmps, 601.407, accuracy: 0.01)
        XCTAssertEqual(result.multiplier, 20, accuracy: 0.001)
        XCTAssertEqual(result.availableFaultAmps, 12028.13, accuracy: 0.1)
    }

    func testSinglePhaseDropsTheRootThree() throws {
        let result = try ShortCircuit.transformerSecondary(
            kVA: 25,
            secondaryVolts: 240,
            impedancePercent: 2,
            system: .singlePhase
        )
        XCTAssertEqual(result.fullLoadAmps, 104.167, accuracy: 0.01)
    }

    func testZeroImpedanceThrows() {
        XCTAssertThrowsError(try ShortCircuit.transformerSecondary(
            kVA: 500,
            secondaryVolts: 480,
            impedancePercent: 0
        ))
    }

    func testTransformerSecondaryRejectsDC() {
        XCTAssertThrowsError(try ShortCircuit.transformerSecondary(
            kVA: 500, secondaryVolts: 480, impedancePercent: 5, system: .dc
        ))
    }
}

final class CircularMilsTests: XCTestCase {
    func testDiameterRoundTrip() throws {
        // 250 mils across is 62,500 CM.
        XCTAssertEqual(try CircularMils.fromDiameterMils(250), 62500, accuracy: 0.001)
        XCTAssertEqual(try CircularMils.diameterMils(fromCircularMils: 62500), 250, accuracy: 0.001)
        XCTAssertEqual(try CircularMils.fromDiameterInches(0.25), 62500, accuracy: 0.001)
    }

    func testSquareInches() throws {
        // A 1000 CM conductor is 0.000785 in².
        XCTAssertEqual(try CircularMils.squareInches(fromCircularMils: 1000), 0.000785, accuracy: 1e-6)
    }

    func testNonPositiveThrows() {
        XCTAssertThrowsError(try CircularMils.fromDiameterMils(0))
        XCTAssertThrowsError(try CircularMils.diameterMils(fromCircularMils: -1))
    }
}

final class LoadFactorsTests: XCTestCase {
    func testFactorsFromMeteredData() throws {
        let result = try LoadFactors.solve(
            connectedLoad: 400,
            maximumDemand: 250,
            averageLoad: 150,
            sumOfIndividualDemands: 320,
            systemCapacity: 500
        )

        XCTAssertEqual(result.demandFactor, 0.625, accuracy: 0.0001)
        XCTAssertEqual(result.loadFactor, 0.6, accuracy: 0.0001)
        XCTAssertEqual(result.diversityFactor, 1.28, accuracy: 0.0001)
        XCTAssertEqual(result.capacityUtilization, 0.5, accuracy: 0.0001)
    }

    /// Optional inputs drop their ratio instead of dividing by zero.
    func testOptionalInputsYieldNaNNotCrash() throws {
        let result = try LoadFactors.solve(
            connectedLoad: 400,
            maximumDemand: 250,
            averageLoad: 0,
            sumOfIndividualDemands: 0,
            systemCapacity: 0
        )

        XCTAssertEqual(result.demandFactor, 0.625, accuracy: 0.0001)
        XCTAssertTrue(result.loadFactor.isNaN)
        XCTAssertTrue(result.diversityFactor.isNaN)
        XCTAssertTrue(result.capacityUtilization.isNaN)
    }
}
