import XCTest
@testable import BeckifyMath

final class NameplateCloudAnalyzeTests: XCTestCase {

    func testNormalizeWrappedNameplateDraft() throws {
        let json = """
        {
          "provider": "openai",
          "analysis": {
            "fields": {
              "manufacturer": { "value": "EXAMPLE MOTORS", "confidence": 0.91 },
              "ratedHP": { "value": 10, "confidence": 0.94 },
              "voltage": { "value": "230/460", "confidence": 0.9 },
              "fla": { "value": null, "confidence": 0 },
              "rpm": { "value": 1750, "confidence": 0.88 },
              "phases": { "value": 3, "confidence": 0.8 },
              "pf": { "value": 0.82, "confidence": 0.7 }
            },
            "dualFla": "25.0/12.5",
            "insulation": "F",
            "raw_ocr": "HP 10\\nVOLTS 230/460",
            "warnings": ["Glare on the amp line."]
          }
        }
        """
        let draft = try NameplateCloudAnalyze.normalize(jsonText: json)
        XCTAssertEqual(draft.extraction.agentID, "cloud-vlm")
        XCTAssertTrue(draft.extraction.leavesDevice)
        XCTAssertEqual(draft.extraction.value(.ratedHP), "10")
        XCTAssertEqual(draft.extraction.value(.voltage), "230/460")
        XCTAssertEqual(draft.extraction.value(.fla), "25.0/12.5")
        XCTAssertEqual(draft.extraction.field(.fla)?.source, .vlm)
        XCTAssertEqual(draft.extraction.value(.insulationClass), "F")
        XCTAssertEqual(draft.extraction.value(.pf), "0.82")
        XCTAssertEqual(draft.dualFla, "25.0/12.5")
        XCTAssertTrue(draft.extraction.value(.notes)?.contains("Dual FLA") == true)
        XCTAssertEqual(draft.warnings, ["Glare on the amp line."])
        XCTAssertFalse(draft.extraction.field(.ratedHP)?.reviewed ?? true)
    }

    func testDropsFLAWhenItMatchesMOCP() throws {
        let draft = try NameplateCloudAnalyze.normalize(jsonText: """
        {
          "fields": {
            "fla": { "value": 40, "confidence": 0.8 },
            "mocp": { "value": 40, "confidence": 0.9 }
          }
        }
        """)
        XCTAssertNil(draft.extraction.value(.fla))
        XCTAssertEqual(draft.extraction.value(.mocp), "40")
        XCTAssertTrue(draft.warnings.contains(where: { $0.contains("MOCP") }))
    }

    func testIgnoresInventedPhase() {
        let draft = NameplateCloudAnalyze.normalize([
            "phases": ["value": 2, "confidence": 0.9],
            "ratedHP": ["value": 5, "confidence": 0.9],
        ] as [String: Any])
        XCTAssertNil(draft.extraction.value(.phases))
        XCTAssertEqual(draft.extraction.value(.ratedHP), "5")
    }

    func testPowerFactorPercentBecomesFraction() {
        let draft = NameplateCloudAnalyze.normalize(["pf": 82] as [String: Any])
        XCTAssertEqual(draft.extraction.value(.pf), "0.82")
    }

    func testMergeKeepsUserEditsAndFillsBlanks() {
        let local = NameplateFieldParser.extract(text: "HP 10\nRPM 1750")
        let edited = local.applying(draft: [
            .ratedHP: "7.5",
            .rpm: "1750",
        ], confidence: [:])
        let cloud = NameplateCloudAnalyze.normalize([
            "ratedHP": ["value": 10, "confidence": 0.9],
            "voltage": ["value": "460", "confidence": 0.85],
        ] as [String: Any]).extraction
        let merged = NameplateCloudAnalyze.merge(existing: edited, incoming: cloud)
        XCTAssertEqual(merged.value(.ratedHP), "7.5")
        XCTAssertEqual(merged.field(.ratedHP)?.source, .user)
        XCTAssertEqual(merged.value(.voltage), "460")
        XCTAssertEqual(merged.field(.voltage)?.source, .vlm)
        XCTAssertEqual(merged.value(.rpm), "1750")
        XCTAssertTrue(merged.leavesDevice)
    }

    func testHowItWorksMentionsOptionalAnalyze() {
        let copy = ToolHowItWorksCatalog.copy(forToolID: "motorNameplateOCR")
        XCTAssertTrue(copy?.summary.localizedCaseInsensitiveContains("Analyze") == true)
        XCTAssertTrue(copy?.bullets.contains(where: { $0.contains("/api/analyze-nameplate") }) == true)
        XCTAssertTrue(copy?.context.localizedCaseInsensitiveContains("uploads only if you tap") == true)
    }
}
