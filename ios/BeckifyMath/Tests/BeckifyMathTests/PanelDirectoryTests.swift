import XCTest
@testable import BeckifyMath

/// Text recognition collapses runs of spaces, so a photographed schedule
/// arrives as one space-separated line rather than aligned columns, and a
/// directory sticker stops after the circuit name with no trip or pole column.
/// Both have to produce rows or a scan populates nothing.
final class PanelDirectoryTests: XCTestCase {
    func testDirectoryStickerWithNamesOnly() {
        let rows = PanelDirectory.parse("""
        1 LIGHTING OFFICE
        2 RECEPTACLES BREAK ROOM
        3 HVAC RTU-1
        4 SPARE
        """)

        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].circuit, "1")
        XCTAssertEqual(rows[0].name, "LIGHTING OFFICE")
        XCTAssertEqual(rows[0].trip, "")
        XCTAssertEqual(rows[0].poles, "")
        // A hyphenated equipment tag must not split the row.
        XCTAssertEqual(rows[2].name, "HVAC RTU-1")
        XCTAssertEqual(rows[3].name, "SPARE")
    }

    func testTwoUpOddEvenLines() {
        let rows = PanelDirectory.parse("""
        1 LIGHTING OFFICE 2 RECEPTACLES BREAK ROOM
        3 HVAC RTU-1 4 SPARE
        """)

        XCTAssertEqual(rows.map(\.circuit), ["1", "2", "3", "4"])
        XCTAssertEqual(rows[1].name, "RECEPTACLES BREAK ROOM")
        XCTAssertEqual(rows[2].name, "HVAC RTU-1")
    }

    func testTripWithoutPoleColumn() {
        let rows = PanelDirectory.parse("1 LIGHTING OFFICE 20A")

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].name, "LIGHTING OFFICE")
        XCTAssertEqual(rows[0].trip, "20A")
        XCTAssertEqual(rows[0].poles, "")
    }

    func testFullScheduleRowKeepsTripAndPoles() {
        let rows = PanelDirectory.parse("1 Lighting Office 20A 1P")

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].name, "Lighting Office")
        XCTAssertEqual(rows[0].trip, "20A")
        XCTAssertEqual(rows[0].poles, "1")
    }

    /// "20A" and "1P" must not read as the next circuit position.
    func testTwoUpFullScheduleIsNotChoppedByTripOrPoles() {
        let rows = PanelDirectory.parse("1 LIGHTING OFFICE 20A 1P 2 RECEPTACLES 20A 1P")

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].name, "LIGHTING OFFICE")
        XCTAssertEqual(rows[0].trip, "20A")
        XCTAssertEqual(rows[0].poles, "1")
        XCTAssertEqual(rows[1].circuit, "2")
        XCTAssertEqual(rows[1].name, "RECEPTACLES")
    }

    func testRatingsAndUnnamedNoiseAreNotCircuits() {
        XCTAssertTrue(PanelDirectory.parse("400A MCB").isEmpty)
        XCTAssertTrue(PanelDirectory.parse("1 20A").isEmpty)
        XCTAssertTrue(PanelDirectory.parse("").isEmpty)
    }

    func testPanelMetadataAndHeadersAreSkipped() {
        let rows = PanelDirectory.parse("""
        Panel: MDP-2
        Voltage: 480Y/277V
        Main Rating: 400A MCB
        CKT DESCRIPTION TRIP POLES
        1 LIGHTING OFFICE 20A 1P
        """)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].circuit, "1")
        XCTAssertEqual(rows[0].name, "LIGHTING OFFICE")
    }

    func testGangedAndSuffixedCircuitNumbers() {
        let rows = PanelDirectory.parse("""
        1-3 HVAC RTU-2 30A 3P
        5A PANEL LP-1 FEED
        """)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].circuit, "1-3")
        XCTAssertEqual(rows[0].poles, "3")
        XCTAssertEqual(rows[1].circuit, "5A")
    }

    func testDuplicateRowsCollapse() {
        let rows = PanelDirectory.parse("""
        1 LIGHTING OFFICE
        1 LIGHTING OFFICE
        """)

        XCTAssertEqual(rows.count, 1)
    }
}
