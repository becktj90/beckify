import XCTest
@testable import BeckifyMath

final class SolarDesignTests: XCTestCase {
    func testOrientationAdviceNorthern() throws {
        let a = try SolarDesign.orientationAdvice(latitudeDegrees: 40)
        XCTAssertEqual(a.yearRoundTiltDegrees, 40, accuracy: 1e-9)
        XCTAssertEqual(a.summerTiltDegrees, 25, accuracy: 1e-9)
        XCTAssertEqual(a.winterTiltDegrees, 55, accuracy: 1e-9)
        XCTAssertEqual(a.optimalAzimuthDegrees, 180, accuracy: 1e-9)
        XCTAssertEqual(a.hemisphere, "northern")
    }

    func testOrientationAdviceSouthern() throws {
        let a = try SolarDesign.orientationAdvice(latitudeDegrees: -33.9)
        XCTAssertEqual(a.yearRoundTiltDegrees, 33.9, accuracy: 1e-9)
        XCTAssertEqual(a.optimalAzimuthDegrees, 0, accuracy: 1e-9)
        XCTAssertEqual(a.hemisphere, "southern")
    }

    func testAzimuthErrorWrap() {
        XCTAssertEqual(SolarDesign.azimuthErrorDegrees(measured: 10, target: 350), 20, accuracy: 1e-9)
        XCTAssertEqual(SolarDesign.azimuthErrorDegrees(measured: 180, target: 180), 0, accuracy: 1e-9)
    }

    func testOptimalOrientationFactorIsOne() throws {
        let a = try SolarDesign.orientationAdvice(latitudeDegrees: 35)
        let o = try SolarDesign.orientationFactor(tiltDegrees: 35, azimuthDegrees: 180, advice: a)
        XCTAssertEqual(o.factor, 1.0, accuracy: 1e-9)
        XCTAssertEqual(o.tiltError, 0, accuracy: 1e-9)
        XCTAssertEqual(o.azimuthError, 0, accuracy: 1e-9)
    }

    func testOffAzimuthReducesFactor() throws {
        let a = try SolarDesign.orientationAdvice(latitudeDegrees: 35)
        let o = try SolarDesign.orientationFactor(tiltDegrees: 35, azimuthDegrees: 90, advice: a)
        XCTAssertLessThan(o.factor, 0.95)
        XCTAssertEqual(o.azimuthError, 90, accuracy: 1e-9)
    }

    func testPanelTiltFromGravityFlat() {
        let tilt = SolarDesign.panelTiltFromGravityDegrees(gravityX: 0, gravityY: 0, gravityZ: -1)
        XCTAssertEqual(tilt, 0, accuracy: 1e-6)
    }

    func testPanelTiltFromGravity45() {
        let g = 0.70710678118
        let tilt = SolarDesign.panelTiltFromGravityDegrees(gravityX: 0, gravityY: g, gravityZ: -g)
        XCTAssertEqual(tilt, 45, accuracy: 0.05)
    }

    func testResidentialArraySizing() throws {
        let r = try SolarDesign.size(
            scale: .residential,
            latitudeDegrees: 40,
            dailyLoadKwh: 30,
            peakSunHours: 4.5,
            panelWatts: 400,
            tiltDegrees: 40,
            azimuthDegrees: 180
        )
        XCTAssertGreaterThan(r.arrayKwDc, 5)
        XCTAssertGreaterThan(r.panelCount, 10)
        XCTAssertEqual(r.orientationFactor, 1.0, accuracy: 1e-6)
        XCTAssertGreaterThan(r.dailyProductionKwh, 25)
        XCTAssertNil(r.storage)
        XCTAssertGreaterThan(r.inverterKwAc, 4)
        XCTAssertEqual(r.dcAcRatio, 1.20, accuracy: 1e-9)
    }

    func testUtilityScaleLargerEfficiency() throws {
        let res = try SolarDesign.size(
            scale: .residential,
            latitudeDegrees: 33,
            dailyLoadKwh: 1000,
            peakSunHours: 5.5,
            panelWatts: 550,
            tiltDegrees: 33,
            azimuthDegrees: 180
        )
        let util = try SolarDesign.size(
            scale: .utility,
            latitudeDegrees: 33,
            dailyLoadKwh: 1000,
            peakSunHours: 5.5,
            panelWatts: 550,
            tiltDegrees: 33,
            azimuthDegrees: 180
        )
        // Higher η → fewer panels for the same load.
        XCTAssertLessThanOrEqual(util.panelCount, res.panelCount)
        XCTAssertEqual(util.dcAcRatio, 1.30, accuracy: 1e-9)
    }

    func testStorageAutonomy() throws {
        let r = try SolarDesign.size(
            scale: .commercial,
            latitudeDegrees: 35,
            dailyLoadKwh: 200,
            peakSunHours: 5,
            panelWatts: 500,
            tiltDegrees: 35,
            azimuthDegrees: 180,
            includeStorage: true,
            storageMode: .autonomy,
            autonomyDays: 2,
            storageDodPercent: 90,
            storageRoundTripEfficiencyPercent: 90
        )
        let s = try XCTUnwrap(r.storage)
        // Usable = 200 × 2 = 400; nameplate = 400 / (0.9 × 0.9) ≈ 493.8
        XCTAssertEqual(s.usableKwh, 400, accuracy: 1e-6)
        XCTAssertEqual(s.nameplateKwh, 400 / 0.81, accuracy: 0.1)
        XCTAssertGreaterThan(s.recommendedPowerKw, 0)
    }

    func testStoragePeakShave() throws {
        let s = try SolarDesign.sizeStorage(
            mode: .peakShave,
            dailyLoadKwh: 100,
            dailyProductionKwh: 120,
            autonomyDays: 1,
            peakLoadKw: 50,
            peakDurationHours: 4,
            selfConsumptionFractionPercent: 40,
            dodPercent: 90,
            roundTripEfficiencyPercent: 90,
            arrayKwDc: 40
        )
        XCTAssertEqual(s.usableKwh, 200, accuracy: 1e-9)
        XCTAssertEqual(s.recommendedPowerKw, 50, accuracy: 1e-9)
    }

    func testPanelCountOverride() throws {
        let r = try SolarDesign.size(
            scale: .residential,
            latitudeDegrees: 40,
            dailyLoadKwh: 30,
            peakSunHours: 4.5,
            panelWatts: 400,
            tiltDegrees: 40,
            azimuthDegrees: 180,
            panelCountOverride: 20
        )
        XCTAssertEqual(r.panelCount, 20)
        XCTAssertEqual(r.arrayKwDc, 8.0, accuracy: 1e-9)
    }

    func testRejectsZeroSystemEfficiency() {
        XCTAssertThrowsError(
            try SolarDesign.size(
                scale: .residential,
                latitudeDegrees: 40,
                dailyLoadKwh: 30,
                peakSunHours: 4.5,
                panelWatts: 400,
                tiltDegrees: 40,
                azimuthDegrees: 180,
                systemEfficiencyPercent: 0
            )
        ) { error in
            guard let calc = error as? CalcError else {
                return XCTFail("Expected CalcError")
            }
            XCTAssertEqual(calc.message, "System efficiency must be greater than 0 and at most 100 %.")
        }
    }

    func testRejectsBadLatitude() {
        XCTAssertThrowsError(try SolarDesign.orientationAdvice(latitudeDegrees: 95))
    }
}
