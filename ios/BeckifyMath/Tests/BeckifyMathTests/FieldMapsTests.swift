import XCTest
@testable import BeckifyMath

final class FieldMapsTests: XCTestCase {
    private let mu0 = 4 * Double.pi * 1e-7

    func testEllipticIntegralsKnownValues() {
        let zero = EllipticIntegrals.kAndE(m: 0)
        XCTAssertEqual(zero.k, Double.pi / 2, accuracy: 1e-12)
        XCTAssertEqual(zero.e, Double.pi / 2, accuracy: 1e-12)
        // K(0.5) = 1.8540746773, E(0.5) = 1.3506438810
        let half = EllipticIntegrals.kAndE(m: 0.5)
        XCTAssertEqual(half.k, 1.8540746773013719, accuracy: 1e-10)
        XCTAssertEqual(half.e, 1.3506438810476755, accuracy: 1e-10)
    }

    func testLoopMatchesOnAxisFormula() {
        let a = 0.05, z = 0.03
        let expected = mu0 * a * a / (2 * pow(a * a + z * z, 1.5))
        // Just off axis the general expression must meet the axis limit.
        let near = SolenoidFieldMap.loop(radius: a, rho: 1e-4, z: z)
        XCTAssertEqual(near.bZ, expected, accuracy: expected * 1e-4)
        let axis = SolenoidFieldMap.loop(radius: a, rho: 0, z: z)
        XCTAssertEqual(axis.bZ, expected, accuracy: expected * 1e-12)
    }

    func testLoopCentreField() {
        let a = 0.1
        let centre = SolenoidFieldMap.loop(radius: a, rho: 0, z: 0)
        XCTAssertEqual(centre.bZ, mu0 / (2 * a), accuracy: 1e-12)
    }

    func testLongSolenoidFieldMatchesMuNI() throws {
        // 1 m long, 2 cm radius, 1000 turns, 2 A: B ≈ μ0 n I = 2.513 mT inside.
        let map = try XCTUnwrap(SolenoidFieldMap.compute(
            lengthM: 1, innerRadiusM: 0.02, buildM: 0.002, turns: 1000, currentAmps: 2, columns: 40, rows: 60
        ))
        let centre = map.sample(rho: 0.005, z: 0)
        XCTAssertEqual(centre.bZ, mu0 * 1000 * 2, accuracy: mu0 * 1000 * 2 * 0.01)
        XCTAssertEqual(centre.bRho, 0, accuracy: 1e-6)
    }

    func testSolenoidMatchesTheDesignerAxialField() throws {
        let map = try XCTUnwrap(SolenoidFieldMap.compute(
            lengthM: 0.1, innerRadiusM: 0.02, buildM: 0.0001, turns: 500, currentAmps: 1, columns: 30, rows: 40
        ))
        let onAxis = map.sample(rho: 0, z: 0.03).bZ
        let designer = SolenoidDesign.axialFieldTesla(zFromCenterM: 0.03, lengthM: 0.1, meanRadiusM: 0.02, turns: 500, currentAmps: 1)
        XCTAssertEqual(onAxis, designer, accuracy: designer * 0.03)
    }

    func testFluxFunctionGivesTheFluxThroughAnAxisDisc() throws {
        // ψ(ρ, 0) = flux through a disc of radius ρ. Inside a long solenoid that is B·πρ².
        let map = try XCTUnwrap(SolenoidFieldMap.compute(
            lengthM: 1, innerRadiusM: 0.02, buildM: 0.002, turns: 1000, currentAmps: 2, columns: 40, rows: 60
        ))
        let rho = 0.01
        let s = map.sample(rho: rho, z: 0)
        let psi = 2 * Double.pi * rho * s.aPhiPerAmp * map.currentAmps
        let expected = mu0 * 1000 * 2 * Double.pi * rho * rho
        XCTAssertEqual(psi, expected, accuracy: expected * 0.02)
    }

    func testInducedEFollowsCurrentRamp() throws {
        let map = try XCTUnwrap(SolenoidFieldMap.compute(
            lengthM: 0.1, innerRadiusM: 0.02, buildM: 0.003, turns: 300, currentAmps: 2, columns: 20, rows: 30
        ))
        let c = 10, r = 15
        let e = map.inducedE(column: c, row: r, didt: 100)
        XCTAssertEqual(map.inducedE(column: c, row: r, didt: 200), 2 * e, accuracy: abs(e) * 1e-12)
        XCTAssertEqual(map.inducedE(column: c, row: r, didt: -100), -e, accuracy: abs(e) * 1e-12)
        XCTAssertLessThan(e, 0, "a rising current induces E opposite the winding current")
    }

    func testContoursOfACircleCloseOnTheRadius() {
        let n = 41
        var values: [Double] = []
        for y in 0..<n { for x in 0..<n { values.append(hypot(Double(x) - 20, Double(y) - 20)) } }
        let segments = FieldContours.segments(values: values, columns: n, rows: n, level: 10)
        XCTAssertGreaterThan(segments.count, 40)
        for s in segments {
            XCTAssertEqual(hypot(s.x0 - 20, s.y0 - 20), 10, accuracy: 0.5)
            XCTAssertEqual(hypot(s.x1 - 20, s.y1 - 20), 10, accuracy: 0.5)
        }
    }

    func testGappedCoreFieldNearSeriesCircuitPrediction() throws {
        // 1 cm legs, 40 cm path, 1 mm gap, µr 2000, 200 A·turns.
        let t = 0.01, l = 0.40, g = 0.001, mur = 2000.0, ni = 200.0
        let map = try XCTUnwrap(CoreFieldMap.compute(ampTurns: ni, legThicknessM: t, pathLengthM: l, gapM: g, relativePermeability: mur))
        XCTAssertLessThan(map.residual, 1e-5, "solver converged")
        let series = mu0 * ni / (g + l / mur) // gap-dominated series estimate
        XCTAssertGreaterThan(map.gapB, series * 0.45)
        XCTAssertLessThan(map.gapB, series * 1.2)
        // Same flux, similar area. The coil leg also carries leakage that never reaches the gap.
        XCTAssertGreaterThan(map.steelB, map.gapB * 0.4)
        XCTAssertLessThan(map.steelB, map.gapB * 2.0, "the coil leg also carries leakage flux")
    }

    func testBiggerGapWeakensTheField() throws {
        func gapB(_ g: Double) throws -> Double {
            try XCTUnwrap(CoreFieldMap.compute(ampTurns: 200, legThicknessM: 0.01, pathLengthM: 0.4, gapM: g, relativePermeability: 2000)).gapB
        }
        let small = try gapB(0.0005), big = try gapB(0.004)
        XCTAssertGreaterThan(small, big * 2)
    }

    func testNoGapCoreHasHigherSteelFieldThanGapped() throws {
        let closed = try XCTUnwrap(CoreFieldMap.compute(ampTurns: 50, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0, relativePermeability: 2000))
        let gapped = try XCTUnwrap(CoreFieldMap.compute(ampTurns: 50, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0.002, relativePermeability: 2000))
        XCTAssertGreaterThan(closed.steelB, gapped.steelB * 3)
    }

    func testSubCellGapKeepsItsRealReluctance() throws {
        // 0.1 mm in a 10 mm leg is far below one grid cell. It must still cut the field about as the series circuit says.
        let thin = try XCTUnwrap(CoreFieldMap.compute(ampTurns: 200, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0.0001, relativePermeability: 2000))
        let closed = try XCTUnwrap(CoreFieldMap.compute(ampTurns: 200, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0, relativePermeability: 2000))
        let series = mu0 * 200 / (0.0001 + 0.4 / 2000)
        XCTAssertGreaterThan(thin.steelB, series * 0.4)
        XCTAssertLessThan(thin.steelB, series * 1.3)
        XCTAssertLessThan(thin.steelB, closed.steelB * 0.8, "a 0.1 mm gap still matters in a µr 2000 core")
        // And doubling it lowers the field more.
        let wider = try XCTUnwrap(CoreFieldMap.compute(ampTurns: 200, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0.0002, relativePermeability: 2000))
        XCTAssertLessThan(wider.steelB, thin.steelB)
    }

    func testInducedEAtZeroCurrentIsStillDefined() throws {
        let zero = try XCTUnwrap(FieldRaster.core(ampTurns: 0, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0.001, relativePermeability: 2000, currentAmps: 0))
        XCTAssertEqual(zero.maxB, 0, accuracy: 1e-12)
        XCTAssertGreaterThan(zero.maxEPerRamp, 0, "A per ampere-turn does not vanish with the current")
        let live = try XCTUnwrap(FieldRaster.core(ampTurns: 200, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0.001, relativePermeability: 2000, currentAmps: 200))
        XCTAssertEqual(zero.maxEPerRamp, live.maxEPerRamp, accuracy: live.maxEPerRamp * 0.02)
    }

    func testInvalidInputsReturnNil() {
        XCTAssertNil(SolenoidFieldMap.compute(lengthM: 0, innerRadiusM: 0.02, buildM: 0.001, turns: 100, currentAmps: 1))
        XCTAssertNil(CoreFieldMap.compute(ampTurns: .nan, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0, relativePermeability: 100))
        XCTAssertNil(CoreFieldMap.compute(ampTurns: 10, legThicknessM: 0.01, pathLengthM: 0.4, gapM: -1, relativePermeability: 100))
    }
}

final class FieldRasterTests: XCTestCase {
    func testSolenoidRasterIsMirroredAboutTheAxis() throws {
        let raster = try XCTUnwrap(FieldRaster.solenoid(lengthM: 0.08, innerRadiusM: 0.012, buildM: 0.004, turns: 1200, currentAmps: 0.8))
        let mid = raster.columns / 2
        for row in [10, 40, 70] {
            let left = raster.index(column: mid - 7, row: row)
            let right = raster.index(column: mid + 7, row: row)
            XCTAssertEqual(raster.bMag[left], raster.bMag[right], accuracy: raster.bMag[right] * 1e-9)
            XCTAssertEqual(raster.by[left], raster.by[right], accuracy: abs(raster.by[right]) * 1e-9 + 1e-15)
            XCTAssertEqual(raster.bx[left], -raster.bx[right], accuracy: abs(raster.bx[right]) * 1e-9 + 1e-15)
            XCTAssertEqual(raster.ePerRamp[left], -raster.ePerRamp[right], accuracy: abs(raster.ePerRamp[right]) * 1e-9 + 1e-15)
        }
    }

    func testProbeAtTheCentreMatchesTheDesignerFormula() throws {
        let raster = try XCTUnwrap(FieldRaster.solenoid(lengthM: 0.08, innerRadiusM: 0.012, buildM: 0.0001, turns: 1200, currentAmps: 0.8))
        let reading = try XCTUnwrap(raster.probe(xM: raster.widthM / 2, yM: raster.heightM / 2, didt: 0))
        let designer = SolenoidDesign.axialFieldTesla(zFromCenterM: 0, lengthM: 0.08, meanRadiusM: 0.0121, turns: 1200, currentAmps: 0.8)
        XCTAssertEqual(reading.bMagnitude, designer, accuracy: designer * 0.05)
        XCTAssertNil(raster.probe(xM: -1, yM: 0, didt: 0))
        XCTAssertNil(raster.probe(xM: 0, yM: raster.heightM * 2, didt: 0))
    }

    func testCoreRasterTagsSteelCoilAndGap() throws {
        let raster = try XCTUnwrap(FieldRaster.core(ampTurns: 200, legThicknessM: 0.01, pathLengthM: 0.4, gapM: 0.002, relativePermeability: 2000, currentAmps: 1))
        XCTAssertTrue(raster.tag.contains(FieldRaster.steel))
        XCTAssertTrue(raster.tag.contains(FieldRaster.coil))
        XCTAssertTrue(raster.tag.contains(FieldRaster.gap))
        // In steel H is B / (µ0 µr), far smaller than the same B in air.
        let steelIndex = try XCTUnwrap(raster.tag.firstIndex(of: FieldRaster.steel))
        let c = steelIndex % raster.columns, r = steelIndex / raster.columns
        let p = raster.position(column: c, row: r)
        let reading = try XCTUnwrap(raster.probe(xM: p.x, yM: p.y, didt: 0))
        XCTAssertEqual(reading.material, "Steel")
    }

    func testInducedEScalesWithRamp() throws {
        let raster = try XCTUnwrap(FieldRaster.solenoid(lengthM: 0.08, innerRadiusM: 0.012, buildM: 0.004, turns: 1200, currentAmps: 0.8))
        let p = (x: raster.widthM * 0.55, y: raster.heightM * 0.5)
        let a = try XCTUnwrap(raster.probe(xM: p.x, yM: p.y, didt: 10)).inducedE
        let b = try XCTUnwrap(raster.probe(xM: p.x, yM: p.y, didt: 20)).inducedE
        XCTAssertEqual(b, 2 * a, accuracy: abs(a) * 1e-9)
    }
}
