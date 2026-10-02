import XCTest
@testable import BeckifyMath

final class PanelDataExtractorTests: XCTestCase {

    func testExtractsScheduleFLAAndKAIC() {
        let text = """
        Panel: LP-1
        Voltage: 208Y/120V
        Main Rating: 225A MCB
        FLA 42.5
        65 kAIC
        1 LIGHTING OFFICE 20A 1P 2 RECEPTACLES 20A 1P
        3 AHU-1 40A 3P 4 SPARE 20A 1P
        """
        let scan = PanelDataExtractor.extract(text: text)
        XCTAssertEqual(scan.extraction.circuits.map(\.circuit), ["1", "2", "3", "4"])
        XCTAssertEqual(scan.extraction.panelName.value, "LP-1")
        XCTAssertEqual(scan.extraction.voltage.value, "208Y/120V")
        XCTAssertEqual(scan.extraction.fla.value, "42.5")
        XCTAssertEqual(scan.extraction.kaic.value, "65 kAIC")
        XCTAssertFalse(scan.extraction.fla.reviewed)
        XCTAssertFalse(scan.extraction.leavesDevice)
        XCTAssertGreaterThan(scan.quality, PanelScanResult.retakeThreshold)
        XCTAssertFalse(scan.promptsRetake)
        XCTAssertEqual(scan.extraction.scanQuality ?? 0, scan.quality, accuracy: 0.0001)
    }

    func testFuzzyLineBecomesAGuessedCircuit() {
        let scan = PanelDataExtractor.extract(text: "1 UGHTING OFFICE ZO A IP")
        XCTAssertEqual(scan.extraction.circuits.count, 1)
        XCTAssertEqual(scan.extraction.circuits[0].name, "LIGHTING OFFICE")
        XCTAssertEqual(scan.extraction.circuits[0].trip, "20A")
        XCTAssertEqual(scan.extraction.circuits[0].poles, "1")
        XCTAssertTrue(scan.extraction.circuits[0].guessed)
        XCTAssertTrue(scan.lines[0].text.contains("LIGHTING"))
        XCTAssertFalse(scan.lines[0].text.contains("BKR"))
    }

    func testTradeCodeSurvivesExtract() {
        let scan = PanelDataExtractor.extract(text: "5 TRANSFORMER BKR-3A 30A 3P")
        XCTAssertEqual(scan.extraction.circuits.count, 1)
        XCTAssertTrue(scan.lines[0].text.contains("BKR-3A"))
        XCTAssertTrue(scan.extraction.circuits[0].name.contains("TRANSFORMER") || scan.lines[0].text.contains("TRANSFORMER"))
    }

    func testMissingNumbersOnATwoColumnGridAreInferred() {
        // Printed anchor (21) unlocks odd/even fill for the opposite column (22).
        let lines = [
            PanelOCRLine(
                text: "21 LIGHTING OFFICE 20A 1P",
                confidence: 0.9,
                box: PanelOCRBox(x: 0.05, y: 0.70, width: 0.34, height: 0.04)
            ),
            PanelOCRLine(
                text: "RECEPTACLES 20A 1P",
                confidence: 0.9,
                box: PanelOCRBox(x: 0.56, y: 0.70, width: 0.34, height: 0.04)
            ),
        ]
        let scan = PanelDataExtractor.extract(lines: lines)
        XCTAssertEqual(scan.extraction.circuits.map(\.circuit), ["21", "22"])
        XCTAssertEqual(scan.extraction.inferredSlots, 1)
        XCTAssertTrue(scan.extraction.circuits.contains(where: { $0.circuit == "22" && $0.guessed }))
    }

    func testLowConfidenceEmptyReadPromptsRetake() {
        let scan = PanelDataExtractor.extract(lines: [
            PanelOCRLine(text: "???", confidence: 0.2),
        ])
        XCTAssertTrue(scan.extraction.circuits.isEmpty)
        XCTAssertLessThan(scan.quality, PanelScanResult.retakeThreshold)
        XCTAssertTrue(scan.promptsRetake)
        XCTAssertTrue(scan.extraction.scanNotes.contains { $0.contains("Retake") })
    }

    func testEmptyInputScoresZero() {
        let scan = PanelDataExtractor.extract(text: "   \n")
        XCTAssertEqual(scan.quality, 0)
        XCTAssertTrue(scan.promptsRetake)
        XCTAssertTrue(scan.lines.isEmpty)
    }

    func testRatingLineIsNotACircuit() {
        XCTAssertTrue(PanelDirectory.isRatingOnlyLine("65 KAIC"))
        XCTAssertTrue(PanelDirectory.isRatingOnlyLine("FLA 42.5"))
        XCTAssertFalse(PanelDirectory.isRatingOnlyLine("12 TRANSFORMER 65 KAIC 30A 3P"))
        let scan = PanelDataExtractor.extract(text: "65 kAIC\n1 LIGHTING OFFICE 20A 1P")
        XCTAssertEqual(scan.extraction.circuits.map(\.circuit), ["1"])
        XCTAssertEqual(scan.extraction.kaic.value, "65 kAIC")
    }

    func testKAICLabelBeforeTheNumber() {
        let field = PanelDataExtractor.readKAIC(in: [PanelOCRLine(text: "kAIC: 22", confidence: 0.8)])
        XCTAssertEqual(field.value, "22 kAIC")
        XCTAssertGreaterThan(field.confidence, 0.5)
    }

    func testDualFLASlashForm() {
        let field = PanelDataExtractor.readFLA(in: [PanelOCRLine(text: "FLA 25.0/12.5")])
        XCTAssertEqual(field.value, "25.0/12.5")
    }
}
