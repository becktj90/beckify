import XCTest
@testable import BeckifyMath

final class FuzzyPanelGridTests: XCTestCase {

    func testCleanupRewritesGlareTokensAndProtectsTradeCodes() {
        let cleaned = FuzzyPanelGrid.cleanup("1 UGHTING OFFICE ZO A IP BKR-3A A|C")
        XCTAssertTrue(cleaned.changed)
        XCTAssertTrue(cleaned.text.contains("LIGHTING"))
        XCTAssertTrue(cleaned.text.contains("20A"))
        XCTAssertTrue(cleaned.text.contains("1P"))
        XCTAssertTrue(cleaned.text.contains("BKR-3A"))
        XCTAssertTrue(cleaned.text.contains("A/C"))
        XCTAssertFalse(cleaned.text.contains("ZO"))
        XCTAssertFalse(cleaned.text.contains("UGHTING"))
        XCTAssertFalse(cleaned.text.contains("A|C"))
    }

    func testCleanupLeavesAClearScheduleUntouched() {
        let cleaned = FuzzyPanelGrid.cleanup("1 LIGHTING OFFICE 20A 1P")
        XCTAssertFalse(cleaned.changed)
        XCTAssertEqual(cleaned.text, "1 LIGHTING OFFICE 20A 1P")
    }

    func testConfusedDigitsNeedADigitOrZ() {
        XCTAssertEqual(FuzzyPanelGrid.confusedDigits("ZO"), "20")
        XCTAssertEqual(FuzzyPanelGrid.confusedDigits("2O"), "20")
        XCTAssertNil(FuzzyPanelGrid.confusedDigits("ON"))
        XCTAssertNil(FuzzyPanelGrid.confusedDigits("OFFICE"))
        XCTAssertTrue(FuzzyPanelGrid.isProtectedTradeCode("BKR-3A"))
        XCTAssertTrue(FuzzyPanelGrid.isProtectedTradeCode("AHU-1"))
        XCTAssertFalse(FuzzyPanelGrid.isProtectedTradeCode("LIGHTING"))
    }

    func testLevenshtein() {
        XCTAssertEqual(FuzzyPanelGrid.levenshtein("UGHTING", "LIGHTING"), 2)
        XCTAssertEqual(FuzzyPanelGrid.levenshtein("SPARE", "SPARE"), 0)
        XCTAssertEqual(FuzzyPanelGrid.levenshtein("SPARF", "SPARE"), 1)
    }

    func testOddLeftEvenRightWhenNumbersAreMissing() {
        let lines = [
            line("LIGHTING OFFICE 20A 1P", x: 0.06, y: 0.72),
            line("RECEPTACLES 20A 1P", x: 0.56, y: 0.71),
            line("3 AHU-1 40A 3P", x: 0.06, y: 0.55),
            line("SPARE 20A 1P", x: 0.58, y: 0.54),
        ]
        let assigned = FuzzyPanelGrid.assign(lines)
        XCTAssertEqual(assigned.inferredSlots, 3)
        XCTAssertEqual(assigned.lines.map(\.text), [
            "1 LIGHTING OFFICE 20A 1P",
            "2 RECEPTACLES 20A 1P",
            "3 AHU-1 40A 3P",
            "4 SPARE 20A 1P",
        ])
        XCTAssertTrue(assigned.lines[0].inferredCircuit)
        XCTAssertTrue(assigned.lines[1].inferredCircuit)
        XCTAssertFalse(assigned.lines[2].inferredCircuit)
        XCTAssertTrue(assigned.lines[3].inferredCircuit)
    }

    func testSingleColumnDoesNotInventOddEvenNumbers() {
        let lines = [
            line("LIGHTING OFFICE 20A 1P", x: 0.10, y: 0.70),
            line("RECEPTACLES 20A 1P", x: 0.12, y: 0.55),
        ]
        let assigned = FuzzyPanelGrid.assign(lines)
        XCTAssertEqual(assigned.inferredSlots, 0)
        XCTAssertEqual(assigned.lines.map(\.text), [
            "LIGHTING OFFICE 20A 1P",
            "RECEPTACLES 20A 1P",
        ])
    }

    func testPrintedNumbersAreKeptAndReadingOrderIsTopToBottom() {
        let lines = [
            line("4 SPARE 20A 1P", x: 0.60, y: 0.40),
            line("1 LIGHTING OFFICE 20A 1P", x: 0.08, y: 0.80),
            line("2 RECEPTACLES 20A 1P", x: 0.60, y: 0.79),
            line("3 AHU-1 40A 3P", x: 0.08, y: 0.41),
        ]
        let assigned = FuzzyPanelGrid.assign(lines)
        XCTAssertEqual(assigned.inferredSlots, 0)
        XCTAssertEqual(assigned.lines.map(\.text), [
            "1 LIGHTING OFFICE 20A 1P",
            "2 RECEPTACLES 20A 1P",
            "3 AHU-1 40A 3P",
            "4 SPARE 20A 1P",
        ])
    }

    func testPrepareIsIdempotentForInferredSlots() {
        // Cleanup stays idempotent; circuit numbers are not invented without a printed anchor.
        let once = FuzzyPanelGrid.prepare([
            line("LIGHTING OFFICE ZO A IP", x: 0.08, y: 0.70),
            line("REC 20A 1P", x: 0.60, y: 0.69),
        ])
        XCTAssertEqual(once.inferredSlots, 0)
        XCTAssertTrue(once.lines[0].text.contains("20A"))
        XCTAssertTrue(once.lines[0].text.contains("1P"))
        XCTAssertFalse(once.lines[0].text.hasPrefix("1 "))
        XCTAssertFalse(once.lines[1].text.hasPrefix("2 "))
        let twice = FuzzyPanelGrid.prepare(once.lines)
        XCTAssertEqual(twice.inferredSlots, 0)
        XCTAssertEqual(twice.lines.map(\.text), once.lines.map(\.text))
    }

    private func line(_ text: String, x: Double, y: Double) -> PanelOCRLine {
        PanelOCRLine(
            text: text,
            confidence: 0.8,
            box: PanelOCRBox(x: x, y: y, width: 0.32, height: 0.04)
        )
    }
}
