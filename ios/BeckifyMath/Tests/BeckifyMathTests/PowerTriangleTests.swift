import XCTest
@testable import BeckifyMath

final class PowerTriangleTests: XCTestCase {
    func testRealLegStaysPutWhenReactiveShrinks() throws {
        let result = try PowerFactorCorrection.solve(
            realPowerKW: 100,
            existingPowerFactor: 0.75,
            targetPowerFactor: 0.95,
            voltage: 480
        )
        let picture = try XCTUnwrap(PowerTriangleComparison.correction(from: result))

        XCTAssertEqual(picture.realPowerKW, 100, accuracy: 0.02)
        let existingS = hypot(picture.realPowerKW, picture.existingKVAR)
        let targetS = hypot(picture.realPowerKW, picture.targetKVAR)
        XCTAssertGreaterThan(existingS, targetS)
        XCTAssertEqual(picture.scaleKVA, existingS, accuracy: 1e-9)

        let perUnit = picture.realLeg / picture.realPowerKW
        XCTAssertEqual(picture.existingReactiveLeg / picture.existingKVAR, perUnit, accuracy: 1e-12)
        XCTAssertEqual(picture.targetReactiveLeg / picture.targetKVAR, perUnit, accuracy: 1e-12)

        // Scaling each triangle by its own hypotenuse would lengthen kW after correction.
        let separateTargetRealLeg = picture.realPowerKW / targetS
        XCTAssertNotEqual(picture.realLeg, separateTargetRealLeg, accuracy: 0.02)

        let shorterTarget = try XCTUnwrap(PowerTriangleComparison.correction(
            realPowerKW: picture.realPowerKW,
            existingKVAR: picture.existingKVAR,
            targetKVAR: picture.targetKVAR / 2,
            bankMicrofarads: picture.bankMicrofarads
        ))
        XCTAssertEqual(shorterTarget.realLeg, picture.realLeg, accuracy: 1e-12)
        XCTAssertEqual(shorterTarget.existingReactiveLeg, picture.existingReactiveLeg, accuracy: 1e-12)
        XCTAssertLessThan(shorterTarget.targetReactiveLeg, picture.targetReactiveLeg)
    }

    func testAnnouncementLeadsWithBothReactiveValues() throws {
        let result = try PowerFactorCorrection.solve(
            realPowerKW: 100,
            existingPowerFactor: 0.75,
            targetPowerFactor: 0.95,
            voltage: 480
        )
        let picture = try XCTUnwrap(PowerTriangleComparison.correction(from: result))

        XCTAssertTrue(picture.announcement.hasPrefix("88.19 kVAR existing, 32.87 kVAR after correction, 100 kW"))
        XCTAssertTrue(picture.announcement.contains("µF bank"))
        XCTAssertEqual(picture.announcement.first?.isNumber, true)
        XCTAssertNotNil(picture.bankCaption)
        XCTAssertFalse(picture.announcement.localizedCaseInsensitiveContains("bill"))
        XCTAssertFalse(picture.announcement.localizedCaseInsensitiveContains("utility"))
        XCTAssertFalse(picture.bankCaption?.localizedCaseInsensitiveContains("bill") ?? false)
    }

    func testUnityTargetKeepsTheExistingHypotenuseAsScale() throws {
        let picture = try XCTUnwrap(PowerTriangleComparison.correction(
            realPowerKW: 50,
            existingKVAR: 20,
            targetKVAR: 0,
            bankMicrofarads: nil
        ))
        XCTAssertEqual(picture.targetReactiveLeg, 0, accuracy: 1e-12)
        XCTAssertEqual(picture.realLeg, 50 / hypot(50, 20), accuracy: 1e-12)
        XCTAssertNil(picture.bankLabel)
        XCTAssertFalse(picture.announcement.contains("µF"))
        XCTAssertEqual(picture.announcement, "20 kVAR existing, 0 kVAR after correction, 50 kW.")
    }

    func testUnusableInputsDrawNothing() throws {
        XCTAssertNil(PowerTriangleComparison.correction(
            realPowerKW: .nan, existingKVAR: 1, targetKVAR: 0, bankMicrofarads: 10
        ))
        XCTAssertNil(PowerTriangleComparison.correction(
            realPowerKW: 0, existingKVAR: 1, targetKVAR: 0, bankMicrofarads: 10
        ))
        XCTAssertNil(PowerTriangleComparison.correction(
            realPowerKW: -5, existingKVAR: 1, targetKVAR: 0, bankMicrofarads: 10
        ))
        XCTAssertNil(PowerTriangleComparison.correction(
            realPowerKW: 10, existingKVAR: .infinity, targetKVAR: 1, bankMicrofarads: 10
        ))
        XCTAssertNil(PowerTriangleComparison.correction(from: PowerFactorResult(
            existingKVAR: .nan,
            targetKVAR: 1,
            correctionKVAR: 1,
            capacitance: 1e-6,
            newKVA: 10,
            formula: ""
        )))

        let noBank = try XCTUnwrap(PowerTriangleComparison.correction(
            realPowerKW: 10, existingKVAR: 5, targetKVAR: 1, bankMicrofarads: .nan
        ))
        XCTAssertNil(noBank.bankLabel)
        XCTAssertFalse(noBank.announcement.contains("µF"))
    }
}
