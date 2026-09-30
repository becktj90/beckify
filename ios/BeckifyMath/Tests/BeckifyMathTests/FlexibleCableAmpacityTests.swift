import XCTest
@testable import BeckifyMath

final class FlexibleCableAmpacityTests: XCTestCase {

    private func evaluate(
        family: FlexibleCableFamily,
        size: String = "12",
        circularMils: Double? = nil,
        conductors: Int = 3,
        material: ConductorMaterial = .copper,
        insulation: ConductorTempColumn = .c90,
        ambient: Double = 30,
        ccc: Int = 2,
        continuous: Bool = false,
        load: Double? = nil
    ) throws -> FlexibleCableAmpacityResult {
        try FlexibleCableAmpacity.evaluate(FlexibleCableAmpacityInput(
            family: family,
            size: size,
            circularMils: circularMils,
            conductorCount: conductors,
            material: material,
            insulation: insulation,
            ambientC: ambient,
            currentCarryingCount: ccc,
            continuousLoad: continuous,
            loadAmps: load
        ))
    }

    func testPortableCordColumnAAndB() throws {
        let two = try evaluate(family: .so, size: "12", ccc: 2)
        XCTAssertEqual(two.baseAmpacity, 25)
        XCTAssertEqual(two.allowableAmpacity, 25)
        XCTAssertTrue(two.columnLabel.contains("Column B"))
        XCTAssertEqual(two.tableName, "NEC Table 400.5(A)(1)")
        XCTAssertTrue(two.source.contains("400.5(A)(1)"))

        let three = try evaluate(family: .so, size: "12", conductors: 4, ccc: 3)
        XCTAssertEqual(three.baseAmpacity, 20)
        XCTAssertTrue(three.columnLabel.contains("Column A"))

        let eighteen = try evaluate(family: .sjo, size: "18", conductors: 2, ccc: 2)
        XCTAssertEqual(eighteen.baseAmpacity, 10)
        let eighteenA = try evaluate(family: .sto, size: "18", conductors: 3, ccc: 3)
        XCTAssertEqual(eighteenA.baseAmpacity, 7)

        let heavy = try evaluate(family: .so, size: "2", conductors: 4, ccc: 3)
        XCTAssertEqual(heavy.baseAmpacity, 80)
        let heavyB = try evaluate(family: .so, size: "2", conductors: 2, ccc: 2)
        XCTAssertEqual(heavyB.baseAmpacity, 95)
    }

    func testCordFamiliesShareOneColumn() throws {
        let so = try evaluate(family: .so, size: "10", conductors: 3, ccc: 3)
        let sjo = try evaluate(family: .sjo, size: "10", conductors: 3, ccc: 3)
        let sto = try evaluate(family: .sto, size: "10", conductors: 3, ccc: 3)
        XCTAssertEqual(so.baseAmpacity, 25)
        XCTAssertEqual(so.baseAmpacity, sjo.baseAmpacity)
        XCTAssertEqual(so.baseAmpacity, sto.baseAmpacity)
        XCTAssertEqual(so.source, sjo.source)
    }

    func testMoreThanThreeConductorsUses4005A3() throws {
        let four = try evaluate(family: .so, size: "12", conductors: 5, ccc: 4)
        XCTAssertEqual(four.baseAmpacity, 20)
        XCTAssertEqual(four.bundleFactor, 0.80)
        XCTAssertEqual(four.allowableAmpacity, 16, accuracy: 0.001)
        XCTAssertTrue(four.source.contains("400.5(A)(1)"))
        XCTAssertTrue(four.warnings.contains { $0.contains("400.5(A)(3)") })

        let seven = try evaluate(family: .sjo, size: "14", conductors: 8, ccc: 7)
        XCTAssertEqual(seven.baseAmpacity, 15)
        XCTAssertEqual(seven.bundleFactor, 0.70)
        XCTAssertEqual(seven.allowableAmpacity, 10.5, accuracy: 0.001)
    }

    func testGroundIsNotCurrentCarrying() throws {
        let cord = try evaluate(family: .soowFamilyProxy, size: "12", conductors: 3, ccc: 2)
        XCTAssertEqual(cord.baseAmpacity, 25)

        let typeW = try evaluate(family: .typeW, size: "2", conductors: 4, ccc: 3)
        XCTAssertEqual(typeW.baseAmpacity, 152)
        XCTAssertEqual(typeW.tableName, "NEC Table 400.5(A)(2)")
    }

    func testTypeWPublishedCells() throws {
        let eight = try evaluate(family: .typeW, size: "8", conductors: 3, ccc: 3)
        XCTAssertEqual(eight.baseAmpacity, 65)
        XCTAssertTrue(eight.source.contains("400.5(A)(2)"))

        let twoCCC = try evaluate(family: .typeW, size: "8", conductors: 2, ccc: 2)
        XCTAssertEqual(twoCCC.baseAmpacity, 74)

        let single = try evaluate(family: .typeW, size: "4/0", conductors: 1, ccc: 1)
        XCTAssertEqual(single.baseAmpacity, 405)

        let threeFifty = try evaluate(family: .typeW, size: "350", conductors: 3, ccc: 3)
        XCTAssertEqual(threeFifty.baseAmpacity, 433)

        let fiveHundred = try evaluate(family: .typeW, size: "500", conductors: 3, ccc: 3)
        XCTAssertEqual(fiveHundred.baseAmpacity, 536)

        let adjusted = try evaluate(family: .typeW, size: "2", conductors: 5, ccc: 4)
        XCTAssertEqual(adjusted.baseAmpacity, 152)
        XCTAssertEqual(adjusted.allowableAmpacity, 121.6, accuracy: 0.001)
    }

    func testMissingTypeWCellIsNotInvented() {
        XCTAssertThrowsError(try evaluate(family: .typeW, size: "250", conductors: 2, ccc: 2)) { error in
            guard case CalcError.notListed(let message) = error else {
                return XCTFail("expected notListed, got \(error)")
            }
            XCTAssertTrue(message.contains("not listed") || message.contains("not in the"))
            XCTAssertFalse(message.contains("interpolate a value of"))
        }
        XCTAssertFalse(FlexibleCableAmpacity.sizes(for: .typeW, currentCarryingCount: 1).contains("3/0"))
        XCTAssertFalse(FlexibleCableAmpacity.sizes(for: .typeW, currentCarryingCount: 1).contains("250"))
    }

    func testSelectsSmallestSizeAtOrUnder400A() throws {
        let cord = try evaluate(family: .so, size: "8", conductors: 3, ccc: 2, load: 20)
        XCTAssertEqual(cord.recommendation?.size, "12")
        XCTAssertEqual(cord.recommendation?.tableAmps, 25)
        XCTAssertTrue(cord.recommendation?.source.contains("400.5(A)(1)") == true)

        let typeW = try evaluate(family: .typeW, size: "4/0", conductors: 3, ccc: 3, load: 400)
        XCTAssertEqual(typeW.requiredAmpacity, 400)
        XCTAssertEqual(typeW.recommendation?.size, "350")
        XCTAssertEqual(typeW.recommendation?.tableAmps, 433)
        XCTAssertEqual(typeW.passesLoad, false)

        let single = try evaluate(family: .typeW, size: "4/0", conductors: 1, ccc: 1, load: 320)
        XCTAssertEqual(single.recommendation?.size, "4/0")
        XCTAssertEqual(single.recommendation?.allowableAmpacity, 405)

        let continuous = try evaluate(family: .typeW, size: "350", conductors: 3, ccc: 3, continuous: true, load: 320)
        XCTAssertEqual(continuous.requiredAmpacity, 400)
        XCTAssertEqual(continuous.recommendation?.size, "350")
        XCTAssertTrue(continuous.warnings.contains { $0.contains("125%") })
    }

    func testSelectionStopsAt400A() {
        XCTAssertThrowsError(
            try evaluate(family: .typeW, size: "500", conductors: 3, ccc: 3, continuous: true, load: 321)
        ) { error in
            guard case CalcError.outOfRange(let message) = error else {
                return XCTFail("expected outOfRange, got \(error)")
            }
            XCTAssertTrue(message.contains("400"))
        }
    }

    func testTwoConductorTypeWCannotReach400A() {
        XCTAssertThrowsError(
            try evaluate(family: .typeW, size: "4/0", conductors: 2, ccc: 2, load: 400)
        ) { error in
            guard case CalcError.notListed(let message) = error else {
                return XCTFail("expected notListed, got \(error)")
            }
            XCTAssertTrue(message.contains("4/0"))
            XCTAssertTrue(message.contains("361"))
        }
    }

    func testAmbientCorrectionUsesInsulationColumn() throws {
        let hot = try evaluate(family: .so, size: "12", conductors: 2, insulation: .c90, ambient: 40, ccc: 2)
        XCTAssertEqual(hot.baseAmpacity, 25)
        XCTAssertEqual(hot.ambientFactor, 0.91, accuracy: 0.001)
        XCTAssertEqual(hot.allowableAmpacity, 22.75, accuracy: 0.001)
        XCTAssertTrue(hot.warnings.contains { $0.contains("ambient correction only") })

        let sameBase = try evaluate(family: .so, size: "12", conductors: 2, insulation: .c60, ambient: 30, ccc: 2)
        XCTAssertEqual(sameBase.baseAmpacity, 25)
        XCTAssertEqual(sameBase.allowableAmpacity, 25)
    }

    func testTypeWRejectsUntranscribedTemperatureColumn() {
        XCTAssertThrowsError(
            try evaluate(family: .typeW, size: "8", conductors: 3, insulation: .c75, ccc: 3)
        ) { error in
            guard case CalcError.notListed(let message) = error else {
                return XCTFail("expected notListed, got \(error)")
            }
            XCTAssertTrue(message.contains("90"))
            XCTAssertTrue(message.contains("75"))
        }
    }

    func testAluminumIsNotListed() {
        XCTAssertThrowsError(
            try evaluate(family: .typeW, size: "2", conductors: 3, material: .aluminum, ccc: 3)
        ) { error in
            guard case CalcError.notListed(let message) = error else {
                return XCTFail("expected notListed, got \(error)")
            }
            XCTAssertTrue(message.localizedCaseInsensitiveContains("aluminum"))
            XCTAssertTrue(message.localizedCaseInsensitiveContains("copper"))
        }
    }

    func testCircularMilsMatchExactTable8Size() throws {
        let twelve = try evaluate(family: .so, size: "4", circularMils: 6530, conductors: 3, ccc: 2)
        XCTAssertEqual(twelve.size, "12")
        XCTAssertEqual(twelve.baseAmpacity, 25)

        let eighteen = try evaluate(family: .sjo, size: "12", circularMils: 1620, conductors: 2, ccc: 2)
        XCTAssertEqual(eighteen.size, "18")
        XCTAssertEqual(eighteen.baseAmpacity, 10)

        XCTAssertThrowsError(try evaluate(family: .so, circularMils: 7000, ccc: 2)) { error in
            guard case CalcError.notListed = error else {
                return XCTFail("expected notListed, got \(error)")
            }
        }
    }

    func testChartCitesSourcePerRowAndHighlightsSelection() throws {
        let result = try evaluate(family: .typeW, size: "2", conductors: 4, ccc: 3, load: 100)
        XCTAssertTrue(result.chart.contains { $0.isSelected && $0.size == "2" })
        XCTAssertTrue(result.chart.contains { $0.isRecommended && $0.size == "4" })
        XCTAssertTrue(result.chart.allSatisfy { $0.source.contains("400.5(A)(2)") })
        XCTAssertEqual(result.chart.first { $0.size == "8" }?.tableAmps, 65)
        XCTAssertNotEqual(result.chart.map(\.source), result.chart.map { _ in FlexibleCableAmpacity.cordSource })
    }

    func testCordChartUsesTheActiveColumn() throws {
        let result = try evaluate(family: .so, size: "10", conductors: 4, ccc: 3)
        XCTAssertEqual(result.chart.first { $0.size == "12" }?.tableAmps, 20)
        XCTAssertTrue(result.chart.allSatisfy { $0.source.contains("400.5(A)(1)") })
        XCTAssertTrue(result.chart.first { $0.size == "10" }?.isSelected == true)
    }

    func testInstallNotesStayShortAndNameThePath() {
        for family in FlexibleCableFamily.allCases {
            let notes = FlexibleCableAmpacity.installNotes(for: family)
            XCTAssertLessThanOrEqual(notes.count, 4, family.rawValue)
            XCTAssertGreaterThanOrEqual(notes.count, 3, family.rawValue)
            let blob = notes.map { $0.title + " " + $0.body }.joined(separator: " ")
            XCTAssertTrue(blob.localizedCaseInsensitiveContains("THHN"), family.rawValue)
            XCTAssertTrue(blob.contains("NEMA") || blob.contains("IP"), family.rawValue)
            XCTAssertTrue(blob.contains("LFMC") || blob.localizedCaseInsensitiveContains("conduit"), family.rawValue)
            XCTAssertTrue(blob.contains("does not cross"), family.rawValue)
            for note in notes {
                XCTAssertLessThanOrEqual(note.body.count, 320, "\(family.rawValue) \(note.id)")
                XCTAssertFalse(note.body.contains("IP67"), "do not invent an enclosure mapping")
                XCTAssertFalse(note.body.contains("NEMA 4"), "do not invent an enclosure mapping")
            }
        }
        let typeW = FlexibleCableAmpacity.installNotes(for: .typeW).map(\.body).joined(separator: " ")
        XCTAssertTrue(typeW.contains("400.5(A)(2)"))
        XCTAssertTrue(typeW.contains("310.16"))
        let so = FlexibleCableAmpacity.installNotes(for: .so).map(\.body).joined(separator: " ")
        XCTAssertTrue(so.contains("400.5(A)(1)"))
        XCTAssertTrue(so.contains("Type W"))
    }

    func testCurrentCarryingCannotExceedConductorCount() {
        XCTAssertThrowsError(try evaluate(family: .so, conductors: 3, ccc: 4)) { error in
            guard case CalcError.outOfRange = error else {
                return XCTFail("expected outOfRange, got \(error)")
            }
        }
    }

    func testSingleConductorPortableCordRefusesTable4005A1() {
        XCTAssertThrowsError(try evaluate(family: .so, size: "12", conductors: 1, ccc: 1)) { error in
            guard case CalcError.notListed(let message) = error else {
                return XCTFail("expected notListed, got \(error)")
            }
            XCTAssertTrue(message.contains("400.5(A)(2)"))
        }
        XCTAssertTrue(FlexibleCableAmpacity.sizes(for: .so, currentCarryingCount: 1).isEmpty)
    }
}

private extension FlexibleCableFamily {
    /// Keeps the ground-count test readable. SO is the 600 V family.
    static var soowFamilyProxy: FlexibleCableFamily { .so }
}
