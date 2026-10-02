import XCTest
@testable import BeckifyMath

final class EquipmentGroundingTests: XCTestCase {

    func testTableRowsAreIncreasingAndCitedAsNEC2023() {
        let ratings = EquipmentGrounding.table250_122.map(\.maxOCPD)
        XCTAssertEqual(ratings, ratings.sorted())
        XCTAssertEqual(Set(ratings).count, ratings.count)
        XCTAssertEqual(ratings.first, 15)
        XCTAssertEqual(ratings.last, 6000)
        XCTAssertEqual(EquipmentGrounding.citation.edition, .nec2023)
        XCTAssertEqual(EquipmentGrounding.citation.articleOrTable, "Table 250.122")
        XCTAssertTrue(EquipmentGrounding.citation.sourceDescription.localizedCaseInsensitiveContains("AHJ"))
        XCTAssertTrue(EquipmentGrounding.citation.sourceDescription.contains("250.66"))
        XCTAssertTrue(EquipmentGrounding.citation.sourceDescription.localizedCaseInsensitiveContains("Not a PE stamp"))
    }

    func testCopperBreakpointsMatchTable250_122() {
        let cases: [(Double, String)] = [
            (10, "14"),
            (15, "14"),
            (20, "12"),
            (21, "10"),
            (60, "10"),
            (61, "8"),
            (100, "8"),
            (200, "6"),
            (300, "4"),
            (400, "3"),
            (500, "2"),
            (800, "1/0"),
            (1000, "2/0"),
            (1200, "3/0"),
            (2000, "250"),
            (6000, "800"),
        ]
        for (amps, size) in cases {
            let rec = EquipmentGrounding.recommend(
                amps: amps,
                material: .copper,
                context: .threePhase,
                ampsAreOCPDRating: true
            )
            XCTAssertEqual(rec?.size, size, "\(amps) A")
            XCTAssertEqual(rec?.citation.articleOrTable, "Table 250.122", "\(amps) A")
            XCTAssertFalse(rec?.cappedToUngroundedConductor ?? true, "\(amps) A")
        }
    }

    func testAluminumColumnAnd1200kcmilLabel() {
        let at100 = EquipmentGrounding.recommend(
            amps: 100, material: .aluminum, context: .singlePhase, ampsAreOCPDRating: true
        )
        XCTAssertEqual(at100?.size, "6")
        XCTAssertEqual(at100?.label, "6 AWG")

        let at6000 = EquipmentGrounding.recommend(
            amps: 6000, material: .aluminum, context: .threePhase, ampsAreOCPDRating: true
        )
        XCTAssertEqual(at6000?.size, "1200")
        XCTAssertEqual(at6000?.label, "1200 kcmil")
    }

    func testInferredOCPDUsesNextStandardDevice() {
        let rec = EquipmentGrounding.recommend(
            amps: 45,
            material: .copper,
            context: .multiwire,
            ampsAreOCPDRating: false
        )
        XCTAssertEqual(rec?.basisAmps, 45)
        XCTAssertEqual(rec?.size, "10")
        XCTAssertTrue(rec?.basisLabel.contains("240.6") == true)
        XCTAssertEqual(rec?.isProvisionalOCPDBasis, true)
        XCTAssertTrue(rec?.notes.contains(where: { $0.contains("Provisional EGC") }) == true)

        let justOver = EquipmentGrounding.recommend(
            amps: 21,
            material: .copper,
            context: .threePhase,
            ampsAreOCPDRating: false
        )
        XCTAssertEqual(justOver?.basisAmps, 25)
        XCTAssertEqual(justOver?.size, "10")
    }

    func testNoGroundWithoutAContextOrAboveTheTable() {
        XCTAssertNil(EquipmentGrounding.recommend(
            amps: 100, material: .copper, context: .none, ampsAreOCPDRating: true
        ))
        XCTAssertNil(EquipmentGrounding.recommend(
            amps: 100, material: .copper, context: EquipmentGroundingContext.from(system: .dc), ampsAreOCPDRating: true
        ))
        XCTAssertNil(EquipmentGrounding.recommend(
            amps: 0, material: .copper, context: .threePhase, ampsAreOCPDRating: true
        ))
        XCTAssertNil(EquipmentGrounding.recommend(
            amps: .nan, material: .copper, context: .threePhase, ampsAreOCPDRating: false
        ))
        XCTAssertNil(EquipmentGrounding.recommend(
            amps: 6001, material: .copper, context: .threePhase, ampsAreOCPDRating: true
        ))
    }

    func testCapsToSmallerUngroundedConductor() {
        let rec = EquipmentGrounding.recommend(
            amps: 20,
            material: .copper,
            context: .singlePhase,
            ampsAreOCPDRating: true,
            ungroundedSize: "14"
        )
        XCTAssertEqual(rec?.size, "14")
        XCTAssertEqual(rec?.cappedToUngroundedConductor, true)
        XCTAssertTrue(rec?.notes.contains(where: { $0.contains("250.122(A)") }) == true)
    }

    func testLargerPhaseNotesVoltageDropUpsizeWithoutChangingMinimum() {
        let rec = EquipmentGrounding.recommend(
            amps: 20,
            material: .copper,
            context: .threePhase,
            ampsAreOCPDRating: true,
            ungroundedSize: "8",
            extraNote: "Motor branch note."
        )
        XCTAssertEqual(rec?.size, "12")
        XCTAssertEqual(rec?.cappedToUngroundedConductor, false)
        XCTAssertEqual(rec?.notes.first, "Motor branch note.")
        XCTAssertTrue(rec?.notes.contains(where: { $0.contains("250.122(B)") }) == true)
    }

    func testReceptacleAndPhaseMapping() {
        XCTAssertEqual(EquipmentGroundingContext.from(receptacle: .singlePhase3Wire), .multiwire)
        XCTAssertEqual(EquipmentGroundingContext.from(receptacle: .threePhase), .threePhase)
        XCTAssertEqual(EquipmentGroundingContext.from(phases: 3), .threePhase)
        XCTAssertTrue(EquipmentGroundingContext.threePhase.countsInRacewayByDefault)
        XCTAssertTrue(EquipmentGroundingContext.multiwire.countsInRacewayByDefault)
        XCTAssertFalse(EquipmentGroundingContext.singlePhase.countsInRacewayByDefault)
    }
}
