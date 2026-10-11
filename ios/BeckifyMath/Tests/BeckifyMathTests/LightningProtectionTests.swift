import XCTest
@testable import BeckifyMath

final class LightningProtectionTests: XCTestCase {
    func testRollingSphereGroundRadius() {
        // 50 ft mast, 150 ft sphere: sqrt(2*150*50 - 50^2) = sqrt(12500) ≈ 111.8 ft
        XCTAssertEqual(RollingSphere.protectedRadiusAtGround(mastHeight: 50, sphereRadius: 150), 111.803, accuracy: 0.01)
        // Mast at or above the sphere radius reaches one radius.
        XCTAssertEqual(RollingSphere.protectedRadiusAtGround(mastHeight: 150, sphereRadius: 150), 150, accuracy: 1e-9)
        XCTAssertEqual(RollingSphere.protectedRadiusAtGround(mastHeight: 400, sphereRadius: 150), 150, accuracy: 1e-9)
        // Smaller hazardous sphere shrinks the zone.
        XCTAssertEqual(RollingSphere.protectedRadiusAtGround(mastHeight: 50, sphereRadius: 100), 86.603, accuracy: 0.01)
    }

    func testRollingSphereBoundaryHeight() {
        XCTAssertEqual(RollingSphere.protectedHeight(atDistance: 0, mastHeight: 50, sphereRadius: 150), 50, accuracy: 1e-9)
        let d = RollingSphere.protectedRadiusAtGround(mastHeight: 50, sphereRadius: 150)
        XCTAssertEqual(RollingSphere.protectedHeight(atDistance: d, mastHeight: 50, sphereRadius: 150), 0, accuracy: 1e-9)
        // 30 ft out: 150 - sqrt(150^2 - (111.803-30)^2) ≈ 24.27 ft
        XCTAssertEqual(RollingSphere.protectedHeight(atDistance: 30, mastHeight: 50, sphereRadius: 150), 24.27, accuracy: 0.05)
        XCTAssertTrue(RollingSphere.isProtected(objectHeight: 20, atDistance: 30, mastHeight: 50, sphereRadius: 150))
        XCTAssertFalse(RollingSphere.isProtected(objectHeight: 30, atDistance: 30, mastHeight: 50, sphereRadius: 150))
        // Boundary falls monotonically.
        let p = RollingSphere.profile(mastHeight: 50, sphereRadius: 150)
        for i in 1..<p.count { XCTAssertLessThanOrEqual(p[i].y, p[i - 1].y + 1e-9) }
    }

    func testConeForLowStructures() {
        XCTAssertEqual(ProtectionCone.radiusAtGround(height: 20), 40)
        XCTAssertEqual(ProtectionCone.radiusAtGround(height: 40), 40)
        XCTAssertNil(ProtectionCone.radiusAtGround(height: 60))
    }

    func testDownConductorCount() {
        XCTAssertEqual(LPSLayout.downConductorCount(perimeterFeet: 120), 2)
        XCTAssertEqual(LPSLayout.downConductorCount(perimeterFeet: 200), 2)
        XCTAssertEqual(LPSLayout.downConductorCount(perimeterFeet: 201), 3)
        XCTAssertEqual(LPSLayout.downConductorCount(perimeterFeet: 600), 6)
        XCTAssertEqual(LPSLayout.downConductorCount(perimeterFeet: 0), 0)
    }

    func testTerminalSpacingAndCounts() {
        XCTAssertEqual(LPSLayout.terminalSpacingFeet(terminalHeightInches: 12), 20)
        XCTAssertEqual(LPSLayout.terminalSpacingFeet(terminalHeightInches: 24), 25)
        XCTAssertEqual(LPSLayout.terminalsAlongRun(lengthFeet: 64, spacingFeet: 20), 4)
        XCTAssertEqual(LPSLayout.terminalsAroundPerimeter(perimeterFeet: 400, spacingFeet: 20), 20)
        XCTAssertEqual(LPSLayout.interiorFieldTerminals(lengthFeet: 200, widthFeet: 100), 3)
        XCTAssertEqual(LPSLayout.interiorFieldTerminals(lengthFeet: 200, widthFeet: 40), 0)
    }

    func testMaterialClassAndRoof() {
        XCTAssertEqual(LPSMaterialClass.forHeight(feet: 75), .classI)
        XCTAssertEqual(LPSMaterialClass.forHeight(feet: 75.5), .classII)
        XCTAssertEqual(LPSRoofStyle.classify(risePer12: 0, spanFeet: 30), .flat)
        XCTAssertEqual(LPSRoofStyle.classify(risePer12: 3, spanFeet: 30), .gentlySloping)
        XCTAssertEqual(LPSRoofStyle.classify(risePer12: 4, spanFeet: 30), .steep)
        XCTAssertEqual(LPSRoofStyle.classify(risePer12: 6, spanFeet: 60), .gentlySloping)
        XCTAssertEqual(LPSRoofStyle.classify(risePer12: 7, spanFeet: 60), .steep)
    }

    func testSeparationDistance() {
        XCTAssertEqual(LPSLayout.separationDistanceFeet(heightFeet: 60, downConductors: 1, solidMaterial: false), 10, accuracy: 1e-9)
        XCTAssertEqual(LPSLayout.separationDistanceFeet(heightFeet: 60, downConductors: 2, solidMaterial: false), 60 / 9, accuracy: 1e-9)
        XCTAssertEqual(LPSLayout.separationDistanceFeet(heightFeet: 60, downConductors: 4, solidMaterial: true), 60 / 13.5 * 0.5, accuracy: 1e-9)
    }

    func testWizard() throws {
        let r = try LPSWizard.solve(LPSStructureInput(lengthFeet: 200, widthFeet: 100, heightFeet: 30, risePer12: 0, terminalHeightInches: 12))
        XCTAssertEqual(r.roof, .flat)
        XCTAssertEqual(r.perimeterFeet, 600)
        XCTAssertEqual(r.downConductors, 6)
        XCTAssertEqual(r.perimeterTerminals, 30)
        XCTAssertEqual(r.interiorTerminals, 3)
        XCTAssertEqual(r.totalTerminals, 33)
        XCTAssertEqual(r.materialClass, .classI)
        XCTAssertEqual(r.sphereRadiusFeet, 150)
        XCTAssertEqual(r.coneRadiusFeet, 30)
        let h = try LPSWizard.solve(LPSStructureInput(lengthFeet: 50, widthFeet: 50, heightFeet: 90, risePer12: 0, terminalHeightInches: 24, hazardous: true))
        XCTAssertEqual(h.sphereRadiusFeet, 100)
        XCTAssertEqual(h.materialClass, .classII)
        XCTAssertNil(h.coneRadiusFeet)
        XCTAssertThrowsError(try LPSWizard.solve(LPSStructureInput(lengthFeet: 50, widthFeet: 50, heightFeet: 20, risePer12: 0, terminalHeightInches: 6)))
        XCTAssertThrowsError(try LPSWizard.solve(LPSStructureInput(lengthFeet: .nan, widthFeet: 50, heightFeet: 20, risePer12: 0, terminalHeightInches: 12)))
    }

    func testReferenceCitesSectionsOnly() {
        XCTAssertEqual(NFPA780Reference.chapterTitles[7]?.contains("Flammable"), true)
        XCTAssertEqual(NFPA780Reference.chapterTitles[8]?.contains("Explosive"), true)
        for card in NFPA780Reference.chapter4 + NFPA780Reference.chapter7 + NFPA780Reference.chapter8 {
            XCTAssertTrue(card.citation.hasPrefix("NFPA 780 "), card.title)
            XCTAssertFalse(card.points.isEmpty, card.title)
        }
    }
}
