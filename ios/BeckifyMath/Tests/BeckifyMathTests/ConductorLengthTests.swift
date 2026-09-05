import XCTest
@testable import BeckifyMath

/// Fixtures ported from `artifacts/beckify/tests/toolbox-conductor-length.test.cjs`.
final class ConductorLengthTests: XCTestCase {

    func testSinglePathTotalLengthMatchesWebsite() throws {
        let result = try ConductorLength.calculate(ConductorLengthInput(
            resistance: 250,
            resistanceUnit: .milliohm,
            circularMils: 105_600,
            method: .single,
            temperature: 20,
            temperatureUnit: .celsius,
            referenceTempC: 20,
            alpha: 0.00393,
            rho: 10.371
        ))

        XCTAssertEqual(result.totalLengthFt, 2545.56, accuracy: 0.5)
        XCTAssertEqual(result.oneWayLengthFt, 2545.56, accuracy: 0.5)
        XCTAssertEqual(result.oneWayLengthFt, result.totalLengthFt, accuracy: 1e-12)
        XCTAssertEqual(result.pathFactor, 1, accuracy: 1e-12)
        XCTAssertEqual(result.resistanceOhms, 0.25, accuracy: 1e-12)
        XCTAssertEqual(result.totalLengthM, result.totalLengthFt * 0.3048, accuracy: 1e-12)
        XCTAssertEqual(result.oneWayLengthM, result.oneWayLengthFt * 0.3048, accuracy: 1e-12)
        XCTAssertEqual(result.metalMass.label, "Copper weight")
        XCTAssertEqual(result.metalMass.densityGPerCm3, 8.89, accuracy: 1e-12)
        XCTAssertEqual(result.metalMass.lbPerKft, 319.5, accuracy: 1e-12)
        XCTAssertEqual(result.metalMass.oneWayLb, result.metalMass.totalPathLb, accuracy: 1e-12)
        // Standard Wire 1/0 Cu is 319.5 lb/kft; 2545.56 ft ≈ 813.3 lb.
        XCTAssertEqual(result.metalMass.oneWayLb, 813.3, accuracy: 1.0)
        XCTAssertEqual(result.metalMass.oneWayKg, result.metalMass.oneWayLb * 453.59237 / 1000, accuracy: 1e-9)
    }

    func testHotMeasurementCompensatesDownToReferenceTemp() throws {
        let result = try ConductorLength.calculate(ConductorLengthInput(
            resistance: 250,
            resistanceUnit: .milliohm,
            circularMils: 105_600,
            method: .single,
            temperature: 75,
            temperatureUnit: .celsius,
            referenceTempC: 20,
            alpha: 0.00393,
            rho: 10.371
        ))

        XCTAssertEqual(result.resistanceAtRefTemp, 0.2056, accuracy: 0.001)
        XCTAssertLessThan(result.resistanceAtRefTemp, result.resistanceOhms)
        XCTAssertLessThan(result.totalLengthFt, 2545.56)
    }

    func testLoopTwoHalvesOneWayDistance() throws {
        let result = try ConductorLength.calculate(ConductorLengthInput(
            resistance: 0.5,
            resistanceUnit: .ohm,
            circularMils: 66_360,
            method: .loop2,
            temperature: 68,
            temperatureUnit: .fahrenheit,
            referenceTempC: 75,
            alpha: 0.00403,
            rho: 21.2,
            material: .aluminum
        ))

        XCTAssertEqual(result.measuredTempC, 20, accuracy: 1e-9)
        XCTAssertEqual(result.totalLengthFt, 2010.78, accuracy: 0.5)
        XCTAssertEqual(result.oneWayLengthFt, 1005.39, accuracy: 0.5)
        XCTAssertEqual(result.oneWayLengthFt, result.totalLengthFt / 2, accuracy: 1e-12)
        XCTAssertEqual(result.pathFactor, 2, accuracy: 1e-12)
        XCTAssertEqual(result.metalMass.label, "Aluminum weight")
        XCTAssertEqual(result.metalMass.densityGPerCm3, 2.70, accuracy: 1e-12)
        XCTAssertEqual(result.metalMass.oneWayLb, result.metalMass.totalPathLb / 2, accuracy: 1e-12)
        // Displayed weight stays one-way (distance to short), not total-path.
        XCTAssertEqual(
            result.metalMass.oneWayLb,
            result.metalMass.lbPerKft * result.oneWayLengthFt / 1000,
            accuracy: 1e-12
        )
    }

    /// Trevor screenshot: 14 AWG / 4110 CM, 49.54 ft one-way, copper ~0.62 lb.
    /// Source: Standard Wire & Cable Co. solid bare copper — 14 AWG = 12.43 lb/kft.
    func testFourteenAWGOneWayMatchesStandardWireBook() throws {
        let oneWayFt = 49.54
        let mass = try ConductorLength.metalMass(
            lengthFt: oneWayFt,
            circularMils: 4110,
            material: .copperAnnealed
        )
        let bookLbPerKft = ConductorLength.copperBookLbPerKft["14"]!
        XCTAssertEqual(bookLbPerKft, 12.43, accuracy: 1e-12)
        XCTAssertEqual(ConductorLength.bookLbPerKft(circularMils: 4110, material: .copperAnnealed), 12.43, accuracy: 1e-12)
        XCTAssertEqual(mass.lb, 12.43 * oneWayFt / 1000, accuracy: 1e-12)
        XCTAssertEqual(mass.lb, 0.6158, accuracy: 0.005)

        let loop = try ConductorLength.calculate(ConductorLengthInput(
            resistance: 250,
            resistanceUnit: .milliohm,
            circularMils: 4110,
            method: .loop2,
            temperature: 20,
            temperatureUnit: .celsius,
            referenceTempC: 20,
            alpha: 0.00393,
            rho: 10.371,
            material: .copperAnnealed
        ))
        XCTAssertEqual(loop.oneWayLengthFt, 49.51, accuracy: 0.05)
        XCTAssertEqual(loop.metalMass.lbPerKft, 12.43, accuracy: 1e-12)
        XCTAssertEqual(loop.metalMass.oneWayLb, 12.43 * loop.oneWayLengthFt / 1000, accuracy: 1e-12)
        XCTAssertEqual(loop.metalMass.oneWayLb, 0.62, accuracy: 0.01)
        XCTAssertEqual(loop.metalMass.oneWayLb, loop.metalMass.totalPathLb / 2, accuracy: 1e-12)
    }

    func testThreePhaseLoopUsesDivideByTwo() throws {
        let result = try ConductorLength.calculate(ConductorLengthInput(
            resistance: 0.3,
            resistanceUnit: .ohm,
            circularMils: 167_800,
            method: .loop3,
            temperature: 20,
            temperatureUnit: .celsius,
            referenceTempC: 20,
            alpha: 0.00393,
            rho: 10.371
        ))

        XCTAssertEqual(result.oneWayLengthFt, result.totalLengthFt / 2, accuracy: 1e-9)
        XCTAssertEqual(result.pathFactor, 2, accuracy: 1e-12)
    }

    func testMethodDisplayNamesUseFieldLanguage() {
        XCTAssertEqual(ConductorLengthMethod.single.rawValue, "single")
        XCTAssertEqual(ConductorLengthMethod.loop2.rawValue, "loop2")
        XCTAssertEqual(ConductorLengthMethod.loop3.rawValue, "loop3")
        XCTAssertEqual(ConductorLengthMethod.single.displayName, "End-to-end")
        XCTAssertEqual(ConductorLengthMethod.loop2.displayName, "Short to parallel")
        XCTAssertEqual(ConductorLengthMethod.loop3.displayName, "3-phase far-end short")
        XCTAssertEqual(ConductorLengthMethod.single.pathFactor, 1, accuracy: 1e-12)
        XCTAssertEqual(ConductorLengthMethod.loop2.pathFactor, 2, accuracy: 1e-12)
        XCTAssertEqual(ConductorLengthMethod.loop3.pathFactor, 2, accuracy: 1e-12)
        XCTAssertEqual(ConductorLengthMethod.single.primaryLengthLabel, "End-to-end length")
        XCTAssertEqual(ConductorLengthMethod.loop2.primaryLengthLabel, "Distance to short")
        XCTAssertEqual(ConductorLengthMethod.loop3.primaryLengthLabel, "Distance to short")
        XCTAssertTrue(ConductorLengthMethod.single.detail.contains("end-to-end"))
        XCTAssertTrue(ConductorLengthMethod.loop2.detail.contains("path ÷ 2"))
        XCTAssertTrue(ConductorLengthMethod.loop3.detail.contains("path ÷ 2"))
    }

    func testCatalogCircularMilsMatchWebsiteSizeBook() {
        XCTAssertEqual(ConductorLength.circularMils(forSize: "1/0"), 105_600)
        XCTAssertEqual(ConductorLength.circularMils(forSize: "2"), 66_360)
        XCTAssertEqual(ConductorLength.circularMils(forSize: "3/0"), 167_800)
        XCTAssertEqual(ConductorLength.circularMils(forSize: "14"), 4110)
        XCTAssertEqual(ConductorLength.circularMils(forSize: "4/0"), 211_600)
        XCTAssertEqual(ConductorLength.preset(.copperAnnealed).rho20, 10.371, accuracy: 1e-12)
        XCTAssertEqual(ConductorLength.preset(.copperAnnealed).rho75, 12.9, accuracy: 1e-12)
        XCTAssertEqual(ConductorLength.preset(.aluminum).rho20, 17.02, accuracy: 1e-12)
        XCTAssertEqual(ConductorLength.preset(.aluminum).alpha, 0.00403, accuracy: 1e-12)
        XCTAssertEqual(
            ConductorLength.preset(.copperHardDrawn).rho20,
            ConductorLength.preset(.copperAnnealed).rho20,
            accuracy: 1e-12
        )
    }

    func testZeroResistanceThrowsWebsiteCopy() {
        XCTAssertThrowsError(try ConductorLength.calculate(ConductorLengthInput(
            resistance: 0,
            resistanceUnit: .ohm,
            circularMils: 105_600,
            method: .single,
            temperature: 20,
            temperatureUnit: .celsius,
            referenceTempC: 20,
            alpha: 0.00393,
            rho: 10.371
        ))) { error in
            guard let calc = error as? CalcError, case .outOfRange(let message) = calc else {
                return XCTFail("expected outOfRange, got \(error)")
            }
            XCTAssertTrue(message.contains("Resistance, conductor area, and ρ"))
        }
    }

    func testNegativeAlphaThrows() {
        XCTAssertThrowsError(try ConductorLength.calculate(ConductorLengthInput(
            resistance: 0.25,
            circularMils: 105_600,
            temperature: 20,
            referenceTempC: 20,
            alpha: -0.001,
            rho: 10.371
        ))) { error in
            guard let calc = error as? CalcError, case .outOfRange(let message) = calc else {
                return XCTFail("expected outOfRange, got \(error)")
            }
            XCTAssertTrue(message.contains("temperatures and α"))
        }
    }

    func testInvalidCompensationDenominatorThrows() {
        // 1 + α × (T − T_ref) ≤ 0 when T is far below the reference.
        XCTAssertThrowsError(try ConductorLength.calculate(ConductorLengthInput(
            resistance: 0.25,
            circularMils: 105_600,
            temperature: -250,
            temperatureUnit: .celsius,
            referenceTempC: 20,
            alpha: 0.00393,
            rho: 10.371
        ))) { error in
            guard let calc = error as? CalcError, case .outOfRange(let message) = calc else {
                return XCTFail("expected outOfRange, got \(error)")
            }
            XCTAssertTrue(message.contains("invalid resistance factor"))
        }
    }

    func testCopperWeightFromLengthAndCircularMils() throws {
        let mass = try ConductorLength.metalMass(
            lengthFt: 1000,
            circularMils: 105_600,
            material: .copperAnnealed
        )
        // Standard Wire 1/0 Cu is 319.5 lb/kft; density×CM at 8.89 g/cm³ is ~319.7.
        XCTAssertEqual(mass.lb, 319.5, accuracy: 0.4)
        XCTAssertEqual(mass.kg, mass.lb * ConductorLength.gramsPerPound / 1000, accuracy: 1e-9)
        XCTAssertEqual(ConductorLengthMaterial.copperHardDrawn.weightLabel, "Copper weight")
        XCTAssertEqual(ConductorLengthMaterial.copperHardDrawn.densityGPerCm3, 8.89, accuracy: 1e-12)
    }

    func testAluminumWeightUsesAluminumDensityNotCopper() throws {
        let copper = try ConductorLength.metalMass(
            lengthFt: 1000,
            circularMils: 105_600,
            material: .copperAnnealed
        )
        let aluminum = try ConductorLength.metalMass(
            lengthFt: 1000,
            circularMils: 105_600,
            material: .aluminum
        )
        XCTAssertEqual(
            aluminum.lb,
            copper.lb * ConductorLength.aluminumDensityGPerCm3 / ConductorLength.copperDensityGPerCm3,
            accuracy: 1e-12
        )
        XCTAssertEqual(ConductorLengthMaterial.aluminum.weightLabel, "Aluminum weight")
        XCTAssertLessThan(aluminum.lb, copper.lb)
    }

    func testBookLbPerKftAgreesWithDensityVolumeWithinOnePercent() throws {
        for (size, cm) in NECTables.circularMils where ConductorLength.copperBookLbPerKft[size] != nil {
            let book = ConductorLength.bookLbPerKft(circularMils: cm, material: .copperAnnealed)
            let volume = try ConductorLength.metalMass(
                lengthFt: 1000,
                circularMils: cm,
                densityGPerCm3: ConductorLength.copperDensityGPerCm3
            )
            XCTAssertEqual(book, volume.lb, accuracy: max(0.4, volume.lb * 0.01), "\(size) AWG book vs density×CM")
        }
    }

    func testMetalMassRejectsNonPositiveInputs() {
        XCTAssertThrowsError(try ConductorLength.metalMass(
            lengthFt: 0,
            circularMils: 105_600,
            densityGPerCm3: 8.89
        ))
    }
}
