import XCTest
@testable import BeckifyMath

final class PanelCloudAnalyzeTests: XCTestCase {

    func testNormalizeWrappedPanelDraft() throws {
        let json = """
        {
          "provider": "openai",
          "analysis": {
            "panel": {
              "name": { "value": "LP-1", "confidence": 0.9 },
              "voltage": { "value": "208Y/120V", "confidence": 0.88 },
              "mainAmps": { "value": 225, "confidence": 0.86 },
              "phases": { "value": 3, "confidence": 0.8 }
            },
            "circuits": [
              {
                "circuit": { "value": "01", "confidence": 0.92 },
                "description": { "value": "LIGHTING OFFICE", "confidence": 0.9 },
                "trip": { "value": 20, "confidence": 0.87 },
                "poles": { "value": 1, "confidence": 0.8 },
                "loadAmps": { "value": 20, "confidence": 0.4 }
              },
              {
                "circuit": { "value": "2", "confidence": 0.9 },
                "description": { "value": "RECEPTACLES", "confidence": 0.88 },
                "trip": { "value": 20, "confidence": 0.86 },
                "poles": { "value": 1, "confidence": 0.8 }
              }
            ],
            "raw_ocr": "1 LIGHTING OFFICE 20A",
            "warnings": ["Bottom of the card is cropped."]
          }
        }
        """
        let draft = try PanelCloudAnalyze.normalize(jsonText: json)
        XCTAssertEqual(draft.extraction.agentID, "cloud-vlm")
        XCTAssertTrue(draft.extraction.leavesDevice)
        XCTAssertEqual(draft.extraction.panelName.value, "LP-1")
        XCTAssertEqual(draft.extraction.voltage.value, "208Y/120V")
        XCTAssertEqual(draft.extraction.mainRating.value, "225A")
        XCTAssertEqual(draft.extraction.phases.value, "3")
        XCTAssertEqual(draft.extraction.circuits.map(\.circuit), ["1", "2"])
        XCTAssertEqual(draft.extraction.circuits[0].name, "LIGHTING OFFICE")
        XCTAssertEqual(draft.extraction.circuits[0].trip, "20A")
        XCTAssertEqual(draft.extraction.circuits[0].poles, "1")
        XCTAssertEqual(draft.extraction.circuits[0].loadClass, .lighting)
        XCTAssertEqual(draft.extraction.circuits[0].source, .vlm)
        XCTAssertFalse(draft.extraction.circuits[0].reviewed)
        XCTAssertEqual(draft.warnings, ["Bottom of the card is cropped."])
    }

    func testIgnoresLoadAmpsAndNormalizesCircuitKeys() {
        let draft = PanelCloudAnalyze.normalize([
            "circuits": [
                [
                    "circuit": ["value": "01A"],
                    "description": ["value": "SPARE"],
                    "trip": ["value": 20],
                    "loadAmps": ["value": 20],
                ],
            ],
        ] as [String: Any])
        XCTAssertEqual(draft.extraction.circuits.count, 1)
        XCTAssertEqual(draft.extraction.circuits[0].circuit, "1A")
        XCTAssertTrue(draft.extraction.circuits[0].isSpareOrSpace)
    }

    func testMergeFillsEmptySlotsAndKeepsUserRows() {
        let left = PanelScheduleParser.extract(text: "1 LIGHTING OFFICE 20A 1P")
        var edited = left.circuits
        edited[0].name = "LIGHTING LOBBY"
        let user = left.applying(draft: edited)
        let right = PanelCloudAnalyze.normalize([
            "circuits": [
                [
                    "circuit": ["value": "1"],
                    "description": ["value": "LIGHTING OFFICE"],
                    "trip": ["value": 20],
                    "poles": ["value": 1],
                ],
                [
                    "circuit": ["value": "2"],
                    "description": ["value": "RECEPTACLES"],
                    "trip": ["value": 20],
                    "poles": ["value": 1],
                ],
            ],
            "panel": ["name": ["value": "LP-1"]],
        ] as [String: Any]).extraction
        let merged = PanelCloudAnalyze.merge(existing: user, incoming: right)
        XCTAssertEqual(merged.circuits.count, 2)
        XCTAssertEqual(merged.circuits[0].name, "LIGHTING LOBBY")
        XCTAssertEqual(merged.circuits[0].source, .user)
        XCTAssertEqual(merged.circuits[1].name, "RECEPTACLES")
        XCTAssertEqual(merged.panelName.value, "LP-1")
        XCTAssertTrue(merged.leavesDevice)
    }

    func testHowItWorksMentionsOptionalAnalyze() {
        let copy = ToolHowItWorksCatalog.copy(forToolID: "panelDirectory")
        XCTAssertTrue(copy?.summary.localizedCaseInsensitiveContains("Analyze") == true)
        XCTAssertTrue(copy?.bullets.contains(where: { $0.contains("/api/analyze-panel") }) == true)
        XCTAssertTrue(copy?.context.localizedCaseInsensitiveContains("uploads only if you tap") == true)
    }
}
