import XCTest
@testable import BeckifyMath

final class TransientCircuitTests: XCTestCase {
    /// 12 V through 1 kΩ / 100 µF (τ = 0.1 s), read at t = 0.05 s.
    func testRCChargingAtHalfTimeConstant() throws {
        let tau = try TransientCircuit.rcTimeConstant(resistance: 1000, capacitance: 100e-6)
        let result = try TransientCircuit.step(amplitude: 12, timeConstant: tau, time: 0.05, charging: true)

        XCTAssertEqual(tau, 0.1, accuracy: 1e-9)
        XCTAssertEqual(result.valueAtTime, 4.7216, accuracy: 0.001)
        XCTAssertEqual(result.percentComplete, 39.347, accuracy: 0.001)
    }

    /// Discharging from the same 12 V starting point mirrors the charging curve.
    func testRCDischargingComplementsCharging() throws {
        let charge = try TransientCircuit.step(amplitude: 12, timeConstant: 0.1, time: 0.05, charging: true)
        let discharge = try TransientCircuit.step(amplitude: 12, timeConstant: 0.1, time: 0.05, charging: false)

        XCTAssertEqual(discharge.valueAtTime, 12 - charge.valueAtTime, accuracy: 1e-9)
        XCTAssertEqual(discharge.percentComplete, charge.percentComplete, accuracy: 1e-9)
    }

    func testRLTimeConstant() throws {
        let tau = try TransientCircuit.rlTimeConstant(inductance: 0.5, resistance: 10)
        XCTAssertEqual(tau, 0.05, accuracy: 1e-9)
    }

    /// At t = 0 nothing has happened yet: 0 % charged, full starting value discharged.
    func testZeroTimeIsTheStartingPoint() throws {
        let charge = try TransientCircuit.step(amplitude: 5, timeConstant: 1, time: 0, charging: true)
        let discharge = try TransientCircuit.step(amplitude: 5, timeConstant: 1, time: 0, charging: false)

        XCTAssertEqual(charge.valueAtTime, 0, accuracy: 1e-9)
        XCTAssertEqual(discharge.valueAtTime, 5, accuracy: 1e-9)
    }

    /// After about 5 time constants the response is effectively settled (>99 %).
    func testFiveTimeConstantsIsEffectivelySettled() throws {
        let result = try TransientCircuit.step(amplitude: 10, timeConstant: 1, time: 5, charging: true)
        XCTAssertGreaterThan(result.percentComplete, 99)
    }

    func testCurveStartsAtZeroAndSpansAtLeastTheRequestedTime() throws {
        let result = try TransientCircuit.step(amplitude: 10, timeConstant: 1, time: 2, charging: true, samples: 10)

        XCTAssertEqual(result.curve.count, 10)
        XCTAssertEqual(try XCTUnwrap(result.curve.first?.time), 0, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(result.curve.last?.time), 2)
    }

    func testNonPositiveInputsThrow() {
        XCTAssertThrowsError(try TransientCircuit.step(amplitude: 0, timeConstant: 1, time: 1, charging: true))
        XCTAssertThrowsError(try TransientCircuit.step(amplitude: 10, timeConstant: 0, time: 1, charging: true))
        XCTAssertThrowsError(try TransientCircuit.step(amplitude: 10, timeConstant: 1, time: -1, charging: true))
        XCTAssertThrowsError(try TransientCircuit.rcTimeConstant(resistance: 0, capacitance: 1e-6))
        XCTAssertThrowsError(try TransientCircuit.rlTimeConstant(inductance: 0.5, resistance: 0))
    }
}

final class RackCurrentBudgetTests: XCTestCase {
    func testTotalsAndHeadroom() throws {
        let result = try RackCurrentBudget.solve(deviceCurrents: [0.5, 1.2, 0.3], busCapacity: 4)

        XCTAssertEqual(result.totalCurrent, 2.0, accuracy: 1e-9)
        XCTAssertEqual(result.headroom, 2.0, accuracy: 1e-9)
        XCTAssertEqual(result.utilizationPercent, 50, accuracy: 1e-9)
    }

    /// Overloading the bus is a valid (if alarming) answer, not an error —
    /// negative headroom is exactly the warning sign the tool exists to show.
    func testOverloadIsNegativeHeadroomNotAnError() throws {
        let result = try RackCurrentBudget.solve(deviceCurrents: [3, 3], busCapacity: 4)
        XCTAssertEqual(result.headroom, -2, accuracy: 1e-9)
        XCTAssertEqual(result.utilizationPercent, 150, accuracy: 1e-9)
    }

    func testEmptyDeviceListThrows() {
        XCTAssertThrowsError(try RackCurrentBudget.solve(deviceCurrents: [], busCapacity: 4))
    }

    func testNegativeDeviceCurrentThrows() {
        XCTAssertThrowsError(try RackCurrentBudget.solve(deviceCurrents: [1, -1], busCapacity: 4))
    }

    func testZeroCapacityThrows() {
        XCTAssertThrowsError(try RackCurrentBudget.solve(deviceCurrents: [1], busCapacity: 0))
    }
}

final class DiodeIVTests: XCTestCase {
    /// Room temperature (300 K) thermal voltage is the textbook ~25.85 mV.
    func testThermalVoltageAtRoomTemperature() throws {
        let vt = try DiodeIV.thermalVoltage(temperatureKelvin: 300)
        XCTAssertEqual(vt, 0.025852, accuracy: 0.000001)
    }

    /// A small-signal silicon diode, n = 1.5, at two forward voltages 50 mV apart.
    func testForwardCurrentAtTwoVoltages() throws {
        let low = try DiodeIV.solve(saturationCurrent: 2.5e-9, idealityFactor: 1.5, temperatureKelvin: 300, forwardVoltage: 0.6)
        let high = try DiodeIV.solve(saturationCurrent: 2.5e-9, idealityFactor: 1.5, temperatureKelvin: 300, forwardVoltage: 0.65)

        XCTAssertEqual(low.current, 0.013111, accuracy: 0.00001)
        XCTAssertEqual(high.current, 0.047601, accuracy: 0.00001)
        XCTAssertGreaterThan(high.current, low.current)
    }

    /// At V = 0 the diode carries no current — that's the whole point of the "−1".
    func testZeroVoltageIsZeroCurrent() throws {
        let result = try DiodeIV.solve(saturationCurrent: 1e-9, idealityFactor: 1, temperatureKelvin: 300, forwardVoltage: 0)
        XCTAssertEqual(result.current, 0, accuracy: 1e-15)
    }

    func testCurveStartsAtZeroAndIsMonotonicallyIncreasing() throws {
        let result = try DiodeIV.solve(saturationCurrent: 1e-9, idealityFactor: 1.5, temperatureKelvin: 300, forwardVoltage: 0.6, samples: 12)

        XCTAssertEqual(result.curve.count, 12)
        XCTAssertEqual(try XCTUnwrap(result.curve.first?.voltage), 0, accuracy: 1e-9)
        for (a, b) in zip(result.curve, result.curve.dropFirst()) {
            XCTAssertLessThan(a.current, b.current)
        }
    }

    func testNonPositiveInputsThrow() {
        XCTAssertThrowsError(try DiodeIV.solve(saturationCurrent: 0, idealityFactor: 1, temperatureKelvin: 300, forwardVoltage: 0.6))
        XCTAssertThrowsError(try DiodeIV.solve(saturationCurrent: 1e-9, idealityFactor: 0, temperatureKelvin: 300, forwardVoltage: 0.6))
        XCTAssertThrowsError(try DiodeIV.thermalVoltage(temperatureKelvin: 0))
    }
}

final class ISLoopVerifierTests: XCTestCase {
    private let safeBarrier = (voc: 24.0, isc: 0.1, ca: 0.5e-6, la: 5e-3)
    private let safeDevice = (vmax: 30.0, imax: 0.15, ci: 20e-9, li: 1e-3)

    func testFullyCompliantLoopIsSafe() throws {
        let result = try ISLoopVerifier.verify(
            barrierVoc: safeBarrier.voc, barrierIsc: safeBarrier.isc, barrierCa: safeBarrier.ca, barrierLa: safeBarrier.la,
            deviceVmax: safeDevice.vmax, deviceImax: safeDevice.imax, deviceCi: safeDevice.ci, deviceLi: safeDevice.li,
            cableCapacitance: 50e-9, cableInductance: 1e-3
        )

        XCTAssertTrue(result.isSafe)
        XCTAssertTrue(result.voltageOK && result.currentOK && result.capacitanceOK && result.inductanceOK)
        XCTAssertEqual(result.totalCapacitance, safeDevice.ci + 50e-9, accuracy: 1e-15)
        XCTAssertEqual(result.totalInductance, safeDevice.li + 1e-3, accuracy: 1e-15)
    }

    /// A barrier Voc above the device's Vmax fails on voltage alone, even
    /// though every other parameter is fine — one bad row fails the loop.
    func testVoltageExceedanceFailsIndependently() throws {
        let result = try ISLoopVerifier.verify(
            barrierVoc: 35, barrierIsc: safeBarrier.isc, barrierCa: safeBarrier.ca, barrierLa: safeBarrier.la,
            deviceVmax: safeDevice.vmax, deviceImax: safeDevice.imax, deviceCi: safeDevice.ci, deviceLi: safeDevice.li,
            cableCapacitance: 50e-9, cableInductance: 1e-3
        )

        XCTAssertFalse(result.isSafe)
        XCTAssertFalse(result.voltageOK)
        XCTAssertTrue(result.currentOK && result.capacitanceOK && result.inductanceOK)
    }

    /// Too much cable capacitance for the barrier's Ca fails on capacitance,
    /// independent of every other row — this is the "cable run too long" case.
    func testExcessCableCapacitanceFailsIndependently() throws {
        let result = try ISLoopVerifier.verify(
            barrierVoc: safeBarrier.voc, barrierIsc: safeBarrier.isc, barrierCa: safeBarrier.ca, barrierLa: safeBarrier.la,
            deviceVmax: safeDevice.vmax, deviceImax: safeDevice.imax, deviceCi: safeDevice.ci, deviceLi: safeDevice.li,
            cableCapacitance: 1e-6, cableInductance: 1e-3
        )

        XCTAssertFalse(result.isSafe)
        XCTAssertFalse(result.capacitanceOK)
        XCTAssertTrue(result.voltageOK && result.currentOK && result.inductanceOK)
    }

    /// Exactly-equal values are compliant — the standard's inequalities are ≤ / ≥, not strict.
    func testExactEqualityIsCompliant() throws {
        let result = try ISLoopVerifier.verify(
            barrierVoc: 24, barrierIsc: 0.1, barrierCa: 100e-9, barrierLa: 1e-3,
            deviceVmax: 24, deviceImax: 0.1, deviceCi: 100e-9, deviceLi: 1e-3,
            cableCapacitance: 0, cableInductance: 0
        )
        XCTAssertTrue(result.isSafe)
    }

    func testNegativeParameterThrows() {
        XCTAssertThrowsError(try ISLoopVerifier.verify(
            barrierVoc: -1, barrierIsc: 0.1, barrierCa: 1e-6, barrierLa: 1e-3,
            deviceVmax: 24, deviceImax: 0.1, deviceCi: 20e-9, deviceLi: 1e-3,
            cableCapacitance: 0, cableInductance: 0
        ))
    }
}

final class MagneticCircuitTests: XCTestCase {
    /// 500 At around a 20 cm path, 1 cm² core, µr 1000 — a small relay-sized core.
    func testTypicalCoreSizing() throws {
        let result = try MagneticCircuit.solve(
            magnetomotiveForce: 500,
            pathLength: 0.2,
            crossSectionalArea: 0.0001,
            relativePermeability: 1000
        )

        XCTAssertEqual(result.reluctance, 1_591_549.43, accuracy: 0.1)
        XCTAssertEqual(result.flux, 0.000314159, accuracy: 1e-8)
        XCTAssertEqual(result.fluxDensity, 3.14159, accuracy: 0.0001)
    }

    /// Flux = mmf / reluctance always, regardless of the specific numbers.
    func testOhmsLawAnalogyHolds() throws {
        let result = try MagneticCircuit.solve(
            magnetomotiveForce: 1000,
            pathLength: 0.5,
            crossSectionalArea: 0.0002,
            relativePermeability: 500
        )
        XCTAssertEqual(result.flux, 1000 / result.reluctance, accuracy: 1e-12)
        XCTAssertEqual(result.fluxDensity, result.flux / 0.0002, accuracy: 1e-12)
    }

    func testNonPositiveInputsThrow() {
        XCTAssertThrowsError(try MagneticCircuit.solve(magnetomotiveForce: 0, pathLength: 0.2, crossSectionalArea: 0.0001, relativePermeability: 1000))
        XCTAssertThrowsError(try MagneticCircuit.solve(magnetomotiveForce: 500, pathLength: 0, crossSectionalArea: 0.0001, relativePermeability: 1000))
        XCTAssertThrowsError(try MagneticCircuit.solve(magnetomotiveForce: 500, pathLength: 0.2, crossSectionalArea: 0, relativePermeability: 1000))
        XCTAssertThrowsError(try MagneticCircuit.solve(magnetomotiveForce: 500, pathLength: 0.2, crossSectionalArea: 0.0001, relativePermeability: 0))
    }
}

final class FiberLinkTests: XCTestCase {
    /// A common 1.48/1.46 step-index multimode fiber.
    func testNumericalApertureAndAcceptanceAngle() throws {
        let result = try FiberLink.solve(coreIndex: 1.48, claddingIndex: 1.46)

        XCTAssertEqual(result.numericalAperture, 0.24249, accuracy: 0.0001)
        XCTAssertEqual(result.acceptanceAngleDegrees, 14.033, accuracy: 0.001)
        XCTAssertNil(result.vNumber)
        XCTAssertNil(result.isSingleMode)
    }

    /// 4.5 µm core radius at 1310 nm gives V ≈ 5.23 — multimode, not single-mode.
    func testVNumberAndModeCondition() throws {
        let result = try FiberLink.solve(
            coreIndex: 1.48, claddingIndex: 1.46,
            coreRadiusMicrons: 4.5, wavelengthNanometers: 1310
        )

        XCTAssertEqual(try XCTUnwrap(result.vNumber), 5.2337, accuracy: 0.001)
        XCTAssertEqual(result.isSingleMode, false)
    }

    /// A tiny single-mode core (~2 µm) at 1550 nm should land under the 2.405 cutoff.
    func testSingleModeCutoff() throws {
        let result = try FiberLink.solve(
            coreIndex: 1.4682, claddingIndex: 1.4629,
            coreRadiusMicrons: 2.0, wavelengthNanometers: 1550
        )
        XCTAssertEqual(result.isSingleMode, true)
    }

    func testCoreNotGreaterThanCladdingThrows() {
        XCTAssertThrowsError(try FiberLink.solve(coreIndex: 1.46, claddingIndex: 1.48))
        XCTAssertThrowsError(try FiberLink.solve(coreIndex: 1.46, claddingIndex: 1.46))
    }

    func testNonPositiveIndexThrows() {
        XCTAssertThrowsError(try FiberLink.solve(coreIndex: 0, claddingIndex: 1.46))
    }
}

final class GaussianBeamTests: XCTestCase {
    /// A 0.5 mm waist at 633 nm (HeNe) — a common bench laser setup.
    func testRayleighRangeAndDivergence() throws {
        let result = try GaussianBeam.solve(waistRadius: 0.5, wavelengthNanometers: 633)

        XCTAssertEqual(result.rayleighRange, 1240.76, accuracy: 0.01)
        XCTAssertEqual(result.divergenceHalfAngleRadians, 0.00040298, accuracy: 1e-7)
        XCTAssertEqual(result.divergenceHalfAngleMilliradians, 0.40298, accuracy: 0.0001)
        XCTAssertNil(result.radiusAtDistance)
    }

    /// At one Rayleigh range, the beam radius has grown by exactly √2.
    func testRadiusAtRayleighRangeIsSqrtTwoTimesWaist() throws {
        let base = try GaussianBeam.solve(waistRadius: 0.5, wavelengthNanometers: 633)
        let atZR = try GaussianBeam.solve(waistRadius: 0.5, wavelengthNanometers: 633, propagationDistance: base.rayleighRange)

        XCTAssertEqual(try XCTUnwrap(atZR.radiusAtDistance), 0.5 * 2.0.squareRoot(), accuracy: 1e-6)
    }

    func testZeroDistanceGivesWaistBack() throws {
        let result = try GaussianBeam.solve(waistRadius: 0.3, wavelengthNanometers: 1064, propagationDistance: 0)
        XCTAssertEqual(try XCTUnwrap(result.radiusAtDistance), 0.3, accuracy: 1e-9)
    }

    func testNonPositiveInputsThrow() {
        XCTAssertThrowsError(try GaussianBeam.solve(waistRadius: 0, wavelengthNanometers: 633))
        XCTAssertThrowsError(try GaussianBeam.solve(waistRadius: 0.5, wavelengthNanometers: 0))
    }
}
