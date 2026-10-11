import XCTest
@testable import BeckifyMath

final class HazardousLocationsTests: XCTestCase {
    func testClassDivisionZoneMapping() throws {
        let g1 = try HazClassifier.classify(material: .gasVapor, presence: .continuous, group: .d)
        XCTAssertEqual(g1.divisionLabel, "Class I, Division 1, Group D")
        XCTAssertEqual(g1.zoneLabel, "Zone 0, Group IIA")
        XCTAssertEqual(try HazClassifier.classify(material: .gasVapor, presence: .normal).zone, 1)
        let g2 = try HazClassifier.classify(material: .gasVapor, presence: .abnormal, group: .b)
        XCTAssertEqual(g2.division, 2)
        XCTAssertEqual(g2.zone, 2)
        XCTAssertEqual(g2.group?.zoneGroup, "IIC")

        let d = try HazClassifier.classify(material: .dust, presence: .normal, group: .g)
        XCTAssertEqual(d.divisionLabel, "Class II, Division 1, Group G")
        XCTAssertEqual(d.zone, 21)
        XCTAssertEqual(try HazClassifier.classify(material: .dust, presence: .abnormal, group: .g).zone, 22)
        // Metal dust stays Division 1.
        XCTAssertEqual(try HazClassifier.classify(material: .dust, presence: .abnormal, group: .e).division, 1)

        let f = try HazClassifier.classify(material: .fibers, presence: .abnormal)
        XCTAssertEqual(f.divisionLabel, "Class III, Division 2")
        XCTAssertEqual(f.zoneLabel, "Zone 22, Group IIIA")

        XCTAssertThrowsError(try HazClassifier.classify(material: .gasVapor, presence: .normal, group: .g))
        XCTAssertEqual(HazGroup.groups(for: .gasVapor), [.a, .b, .c, .d])
        XCTAssertEqual(HazArea.from(g1, zoneSystem: false), .c1d1)
        XCTAssertEqual(HazArea.from(g1, zoneSystem: true), .z0)
        XCTAssertEqual(HazArea.from(f, zoneSystem: false), .c3d2)
    }

    func testTCodeLookup() {
        // Gasoline AIT ≈ 280 °C → T2A is the hottest acceptable.
        XCTAssertEqual(TemperatureCodes.minimumCode(forAutoignitionC: 280)?.code, "T2A")
        XCTAssertEqual(TemperatureCodes.minimumCode(forAutoignitionC: 280, zoneOnly: true)?.code, "T3")
        // Hydrogen ≈ 500 °C → T1.
        XCTAssertEqual(TemperatureCodes.minimumCode(forAutoignitionC: 500)?.code, "T1")
        // Carbon disulfide ≈ 90 °C → T6.
        XCTAssertEqual(TemperatureCodes.minimumCode(forAutoignitionC: 90)?.code, "T6")
        XCTAssertNil(TemperatureCodes.minimumCode(forAutoignitionC: 80))
        let t4 = TemperatureCodes.code(named: "t4")!
        XCTAssertTrue(TemperatureCodes.permits(t4, autoignitionC: 135))
        XCTAssertFalse(TemperatureCodes.permits(t4, autoignitionC: 134))
        XCTAssertEqual(TemperatureCodes.table.count, 14)
    }

    func testProtectionTechniques() {
        let names = { (a: HazArea) in Set(ProtectionTechniques.allowed(in: a).map(\.marking)) }
        XCTAssertTrue(names(.c1d1).contains("XP"))
        XCTAssertFalse(names(.c1d1).contains("NI"))
        XCTAssertTrue(names(.c1d2).contains("NI"))
        XCTAssertTrue(names(.z0).contains("IS / ia"))
        XCTAssertFalse(names(.z0).contains("ib"))
        XCTAssertFalse(names(.z0).contains("e"))
        XCTAssertTrue(names(.z1).contains("e"))
        XCTAssertTrue(names(.z2).contains("nA / nC / nR"))
        XCTAssertTrue(names(.c2d1).contains("DIP"))
        XCTAssertFalse(names(.c2d1).contains("XP"))
        for area in HazArea.allCases { XCTAssertFalse(ProtectionTechniques.allowed(in: area).isEmpty, area.rawValue) }
    }

    func testReferenceCards() {
        XCTAssertTrue(HazLocReference.wiringAndSeals.contains { $0.citation == "501.15" && $0.points.joined().contains("18 in") })
        XCTAssertTrue(HazLocReference.article490.first?.points.joined().contains("NOT a hazardous-locations") == true)
    }
}
