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
            rho: 21.2
        ))

        XCTAssertEqual(result.measuredTempC, 20, accuracy: 1e-9)
        XCTAssertEqual(result.totalLengthFt, 2010.78, accuracy: 0.5)
        XCTAssertEqual(result.oneWayLengthFt, 1005.39, accuracy: 0.5)
        XCTAssertEqual(result.oneWayLengthFt, result.totalLengthFt / 2, accuracy: 1e-12)
        XCTAssertEqual(result.pathFactor, 2, accuracy: 1e-12)
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
}
