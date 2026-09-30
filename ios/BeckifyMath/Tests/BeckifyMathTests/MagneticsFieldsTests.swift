import XCTest
@testable import BeckifyMath

final class MagneticsLabTests: XCTestCase {
    private let mu0 = 4 * Double.pi * 1e-7

    func testMu0() {
        XCTAssertEqual(MagneticsLab.mu0, mu0, accuracy: 1e-18)
    }

    func testUngappedCoreMatchesOhmAnalogy() throws {
        let result = try MagneticsLab.series(
            turns: 100,
            current: 2,
            steelLength: 0.2,
            steelArea: 1e-4,
            relativePermeability: 1000
        )
        let reluctance = 0.2 / (mu0 * 1000 * 1e-4)
        XCTAssertEqual(result.mmf, 200, accuracy: 1e-9)
        XCTAssertEqual(result.equivalentReluctance, reluctance, accuracy: 1)
        XCTAssertEqual(result.coilFlux, 200 / reluctance, accuracy: 1e-12)
        XCTAssertEqual(result.inductance, 100 * 100 / reluctance, accuracy: 1e-12)
        XCTAssertEqual(result.energy, 0.5 * result.inductance * 4, accuracy: 1e-12)
        let steel = try XCTUnwrap(result.drop(named: "Steel"))
        XCTAssertEqual(steel.intensity, 200 / 0.2, accuracy: 1e-6)
        XCTAssertEqual(steel.fluxDensity, result.coilFlux / 1e-4, accuracy: 1e-9)
        XCTAssertNil(result.drop(named: "Air gap"))
        XCTAssertEqual(result.gapMMFFraction, 0, accuracy: 1e-12)
    }

    func testIntensityIgnoresPermeabilityOnAUniformCore() throws {
        let low = try MagneticsLab.series(
            turns: 50, current: 4, steelLength: 0.25, steelArea: 2e-4, relativePermeability: 200
        )
        let high = try MagneticsLab.series(
            turns: 50, current: 4, steelLength: 0.25, steelArea: 2e-4, relativePermeability: 5000
        )
        XCTAssertEqual(low.drop(named: "Steel")!.intensity, high.drop(named: "Steel")!.intensity, accuracy: 1e-6)
        XCTAssertEqual(low.drop(named: "Steel")!.intensity, 200 / 0.25, accuracy: 1e-6)
        XCTAssertGreaterThan(high.coilFlux, low.coilFlux * 10)
    }

    func testAirGapTakesMostOfTheMMF() throws {
        let result = try MagneticsLab.series(
            turns: 500,
            current: 0.6,
            steelLength: 0.2,
            steelArea: 1e-4,
            relativePermeability: 4000,
            gapLength: 0.001,
            stackingFactor: 1,
            fringing: 1
        )
        let gap = try XCTUnwrap(result.drop(named: "Air gap"))
        let steel = try XCTUnwrap(result.drop(named: "Steel"))
        XCTAssertGreaterThan(gap.reluctance, steel.reluctance)
        XCTAssertGreaterThan(result.gapMMFFraction, 0.8)
        XCTAssertEqual(gap.flux, steel.flux, accuracy: 1e-15)
        XCTAssertEqual(gap.mmf + steel.mmf, result.mmf, accuracy: 1e-6)
        XCTAssertTrue(result.warnings.contains { $0.contains("air gap") })
    }

    func testFringingLowersGapReluctanceAndStackingRaisesSteel() throws {
        let plain = try MagneticsLab.series(
            turns: 100, current: 1, steelLength: 0.2, steelArea: 1e-4,
            relativePermeability: 2000, gapLength: 0.001, stackingFactor: 1, fringing: 1
        )
        let fringe = try MagneticsLab.series(
            turns: 100, current: 1, steelLength: 0.2, steelArea: 1e-4,
            relativePermeability: 2000, gapLength: 0.001, stackingFactor: 1, fringing: 1.15
        )
        let stacked = try MagneticsLab.series(
            turns: 100, current: 1, steelLength: 0.2, steelArea: 1e-4,
            relativePermeability: 2000, gapLength: 0.001, stackingFactor: 0.96, fringing: 1
        )
        XCTAssertLessThan(fringe.drop(named: "Air gap")!.reluctance, plain.drop(named: "Air gap")!.reluctance)
        XCTAssertEqual(
            fringe.drop(named: "Air gap")!.effectiveArea,
            plain.drop(named: "Air gap")!.effectiveArea * 1.15,
            accuracy: 1e-12
        )
        XCTAssertGreaterThan(stacked.drop(named: "Steel")!.reluctance, plain.drop(named: "Steel")!.reluctance)
        XCTAssertEqual(stacked.drop(named: "Steel")!.effectiveArea, 1e-4 * 0.96, accuracy: 1e-12)
    }

    func testThreeLegSplitsFluxAndClosesTheNode() throws {
        let side = MagneticsLab.CoreLeg(
            steelLength: 0.2,
            steelArea: 1e-4,
            gapLength: 0.001,
            relativePermeability: 8000,
            stackingFactor: 1,
            fringing: 1
        )
        let result = try MagneticsLab.threeLeg(
            turns: 400,
            current: 1,
            center: MagneticsLab.CoreLeg(
                steelLength: 0.06, steelArea: 2e-4, gapLength: 0,
                relativePermeability: 8000
            ),
            left: side,
            right: side
        )
        let left = try XCTUnwrap(result.leftFlux)
        let right = try XCTUnwrap(result.rightFlux)
        XCTAssertEqual(left, right, accuracy: 1e-12)
        XCTAssertEqual(left + right, result.coilFlux, accuracy: 1e-12)
        let center = try XCTUnwrap(result.drop(named: "Center steel"))
        let leftSteel = try XCTUnwrap(result.drop(named: "Left steel"))
        let leftGap = try XCTUnwrap(result.drop(named: "Left gap"))
        XCTAssertEqual(center.mmf + leftSteel.mmf + leftGap.mmf, result.mmf, accuracy: 1e-6)
        XCTAssertNil(result.drop(named: "Center gap"))
    }

    func testWiderLegTakesMoreFlux() throws {
        let result = try MagneticsLab.threeLeg(
            turns: 100,
            current: 1,
            center: .init(steelLength: 0.05, steelArea: 2e-4, relativePermeability: 1000),
            left: .init(steelLength: 0.2, steelArea: 2e-4, relativePermeability: 1000),
            right: .init(steelLength: 0.2, steelArea: 1e-4, relativePermeability: 1000)
        )
        XCTAssertGreaterThan(result.leftFlux!, result.rightFlux! * 1.5)
        XCTAssertEqual(result.leftFlux! + result.rightFlux!, result.coilFlux, accuracy: 1e-9)
    }

    func testSaturationWarningAndRejectedGeometry() throws {
        let hot = try MagneticsLab.series(
            turns: 100, current: 3, steelLength: 0.2, steelArea: 1e-4, relativePermeability: 1000
        )
        XCTAssertGreaterThan(abs(hot.drop(named: "Steel")!.fluxDensity), 1.5)
        XCTAssertTrue(hot.warnings.contains { $0.contains("1.5") })

        XCTAssertThrowsError(try MagneticsLab.series(
            turns: 10, current: 1, steelLength: 0.2, steelArea: 1e-4,
            relativePermeability: 1000, gapLength: -0.001
        ))
        XCTAssertThrowsError(try MagneticsLab.series(
            turns: 10, current: 1, steelLength: 0.2, steelArea: 1e-4,
            relativePermeability: 1000, stackingFactor: 1.2
        ))
    }

    func testMachineChecksStayHonest() throws {
        let link = try MagneticsLab.transformerLink(
            sharedFlux: 1e-4, primaryTurns: 200, secondaryTurns: 50
        )
        XCTAssertEqual(link.turnsRatio, 0.25, accuracy: 1e-12)
        XCTAssertNil(link.acPeakFlux)
        XCTAssertTrue(link.note.contains("change"))

        let ac = try MagneticsLab.transformerLink(
            sharedFlux: 1e-4, primaryTurns: 200, secondaryTurns: 100,
            primaryRMS: 120, frequencyHz: 60
        )
        let expectedPeak = 120 / (4.44 * 60 * 200)
        XCTAssertEqual(ac.acPeakFlux!, expectedPeak, accuracy: 1e-12)

        let force = try MagneticsLab.conductorForce(current: 10, length: 0.05, fluxDensity: 0.8)
        XCTAssertEqual(force.newtons, 10 * 0.05 * 0.8, accuracy: 1e-12)
        let none = try MagneticsLab.conductorForce(current: 10, length: 0.05, fluxDensity: 0.8, angleDegrees: 0)
        XCTAssertEqual(none.newtons, 0, accuracy: 1e-12)

        let emf = try MagneticsLab.motionalEMF(fluxDensity: 0.4, length: 0.1, speed: 5)
        XCTAssertEqual(emf.volts, 0.4 * 0.1 * 5, accuracy: 1e-12)
    }
}

final class EMFieldsTests: XCTestCase {
    func testFaradaySignAndAverageRate() throws {
        let steady = try EMFields.faradayDensityRate(turns: 10, area: 0.01, densityRate: 2)
        XCTAssertEqual(steady.emf, -0.2, accuracy: 1e-12)
        XCTAssertEqual(steady.circulation, "clockwise")

        let falling = try EMFields.faradayLinearDensity(
            turns: 1, area: 0.02, startDensity: 0.4, endDensity: 0.1, seconds: 0.5
        )
        XCTAssertEqual(falling.fluxRate, 0.02 * (0.1 - 0.4) / 0.5, accuracy: 1e-12)
        XCTAssertGreaterThan(falling.emf, 0)
        XCTAssertEqual(falling.circulation, "counterclockwise")

        let held = try EMFields.faradayFluxRate(turns: 5, fluxRate: 0)
        XCTAssertEqual(held.emf, 0, accuracy: 1e-15)
        XCTAssertEqual(held.circulation, "none")
    }

    func testPointChargeSuperpositionAndEquilibrium() throws {
        let k = EMFields.coulombConstant
        let alone = try EMFields.pointChargeField(
            charges: [.init(x: 0, y: 0, z: 0, coulombs: 1e-9)],
            at: .init(x: 1, y: 0, z: 0),
            testCharge: 2e-9
        )
        XCTAssertEqual(alone.electricField.x, k * 1e-9, accuracy: 1e-4)
        XCTAssertEqual(alone.force!.x, 2e-9 * alone.electricField.x, accuracy: 1e-9)
        XCTAssertFalse(alone.nearEquilibrium)

        let pair = try EMFields.pointChargeField(
            charges: [
                .init(x: -1, y: 0, z: 0, coulombs: 1e-9),
                .init(x: 1, y: 0, z: 0, coulombs: 1e-9),
            ],
            at: .init(x: 0, y: 0, z: 0)
        )
        XCTAssertEqual(pair.magnitude, 0, accuracy: 1e-6)
        XCTAssertTrue(pair.nearEquilibrium)

        XCTAssertThrowsError(try EMFields.pointChargeField(
            charges: [.init(x: 0, y: 0, z: 0, coulombs: 1)],
            at: .init(x: 0, y: 0, z: 0)
        ))
    }

    func testLorentzCrossAndPathKind() throws {
        let curved = try EMFields.lorentz(
            charge: 1,
            electric: .init(x: 0, y: 0, z: 0),
            velocity: .init(x: 1, y: 0, z: 0),
            magnetic: .init(x: 0, y: 0, z: 1),
            mass: 2
        )
        XCTAssertEqual(curved.force.y, -1, accuracy: 1e-12)
        XCTAssertTrue(curved.magneticDominant)
        XCTAssertEqual(curved.path, "curves")
        XCTAssertEqual(curved.radius!, 2, accuracy: 1e-12)

        let straight = try EMFields.lorentz(
            charge: 1,
            electric: .init(x: 10, y: 0, z: 0),
            velocity: .init(x: 1, y: 0, z: 0),
            magnetic: .init(x: 0, y: 0, z: 0.1)
        )
        XCTAssertTrue(straight.electricDominant)
        XCTAssertEqual(straight.path, "straight")
        XCTAssertNil(straight.radius)
    }

    func testCoordinateRoundTripAndProducts() throws {
        let fromCyl = try EMFields.cartesian(fromCylindrical: 2, phiDegrees: 90, z: 3)
        XCTAssertEqual(fromCyl.x, 0, accuracy: 1e-12)
        XCTAssertEqual(fromCyl.y, 2, accuracy: 1e-12)
        XCTAssertEqual(fromCyl.z, 3, accuracy: 1e-12)
        let cyl = try EMFields.cylindrical(from: fromCyl)
        XCTAssertEqual(cyl.rho, 2, accuracy: 1e-12)
        XCTAssertEqual(cyl.phiDegrees, 90, accuracy: 1e-9)

        let fromSph = try EMFields.cartesian(fromSpherical: 2, thetaDegrees: 90, phiDegrees: 0)
        XCTAssertEqual(fromSph.x, 2, accuracy: 1e-12)
        XCTAssertEqual(fromSph.y, 0, accuracy: 1e-12)
        XCTAssertEqual(fromSph.z, 0, accuracy: 1e-12)
        let sph = try EMFields.spherical(from: .init(x: 0, y: 0, z: 4))
        XCTAssertEqual(sph.r, 4, accuracy: 1e-12)
        XCTAssertEqual(sph.thetaDegrees, 0, accuracy: 1e-9)

        let products = try EMFields.products(
            a: .init(x: 2, y: 2, z: 0),
            b: .init(x: 1, y: 0, z: 0)
        )
        XCTAssertEqual(products.dot, 2, accuracy: 1e-12)
        XCTAssertEqual(products.projection.x, 2, accuracy: 1e-12)
        XCTAssertEqual(products.projection.y, 0, accuracy: 1e-12)
        let cross = FieldVector.cross(.init(x: 1, y: 0, z: 0), .init(x: 0, y: 1, z: 0))
        XCTAssertEqual(cross.z, 1, accuracy: 1e-12)
        XCTAssertEqual(products.unitB!.x, 1, accuracy: 1e-12)
    }

    func testCannedFieldsMatchDivAndCurl() throws {
        let swirl = try EMFields.probe(field: .swirl, at: .init(x: 1, y: 0, z: 0))
        XCTAssertEqual(swirl.value.y, 1, accuracy: 1e-12)
        XCTAssertEqual(swirl.divergence, 0, accuracy: 1e-12)
        XCTAssertEqual(swirl.curl.z, 2, accuracy: 1e-12)

        let spread = try EMFields.probe(field: .spreading, at: .init(x: 1, y: 2, z: 3))
        XCTAssertEqual(spread.divergence, 3, accuracy: 1e-12)
        XCTAssertEqual(spread.curl.magnitude, 0, accuracy: 1e-12)
        XCTAssertEqual(spread.value.y, 2, accuracy: 1e-12)

        let saddle = EMFields.SampleField.saddle
        XCTAssertEqual(saddle.divergence, 0, accuracy: 1e-12)
        XCTAssertEqual(saddle.curl.magnitude, 0, accuracy: 1e-12)
        XCTAssertEqual(saddle.value(at: .init(x: 2, y: 3, z: 0)).y, -3, accuracy: 1e-12)
    }

    func testListingCopyAvoidsCourseLabels() throws {
        let magnetics = try XCTUnwrap(ToolHowItWorksCatalog.copy(forToolID: "magneticsLab"))
        let fields = try XCTUnwrap(ToolHowItWorksCatalog.copy(forToolID: "emFields"))
        let blobs = ([magnetics.summary, magnetics.context] + magnetics.bullets + [fields.summary, fields.context] + fields.bullets)
            .joined(separator: "\n")
            .lowercased()
        for banned in ["textbook", "course", "homework", "ee255", "chapman", "lecture"] {
            XCTAssertFalse(blobs.contains(banned), banned)
        }
    }
}
