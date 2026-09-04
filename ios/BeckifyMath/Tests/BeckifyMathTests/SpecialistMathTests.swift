import XCTest
@testable import BeckifyMath

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
