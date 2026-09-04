import XCTest
@testable import BeckifyMath

/// Fixture strings → structured fields. These are not claimed Vision or VLM
/// outputs — they stand in for recognized text so the parser can be tested
/// on Linux without Apple Vision.
final class MotorNameplateOCRTests: XCTestCase {

    func testClassicDualVoltagePlate() {
        let text = """
        EXAMPLE MOTORS
        MODEL 10HP-215
        HP 10
        RPM 1750
        VOLTS 230/460
        AMPS 25.0/12.5
        HZ 60
        PH 3
        SF 1.15
        PF 82
        EFF 89.5
        FRAME 215T
        ENCL TEFC
        SER A12345
        """
        let extracted = NameplateFieldParser.extract(text: text)

        XCTAssertEqual(extracted.value(.manufacturer), "EXAMPLE MOTORS")
        XCTAssertEqual(extracted.value(.model), "10HP-215")
        XCTAssertEqual(extracted.value(.ratedHP), "10")
        XCTAssertEqual(extracted.value(.rpm), "1750")
        XCTAssertEqual(extracted.value(.voltage), "230/460")
        XCTAssertEqual(extracted.value(.fla), "12.5")
        XCTAssertEqual(extracted.value(.frequencyHz), "60")
        XCTAssertEqual(extracted.value(.phases), "3")
        XCTAssertEqual(extracted.value(.sf), "1.15")
        XCTAssertEqual(extracted.value(.pf), "0.82")
        XCTAssertEqual(extracted.value(.nomEff), "89.5")
        XCTAssertEqual(extracted.value(.frame), "215T")
        XCTAssertEqual(extracted.value(.enclosure), "TEFC")
        XCTAssertEqual(extracted.value(.serialNumber), "A12345")
        XCTAssertEqual(extracted.value(.poles), "4")
        XCTAssertEqual(extracted.value(.ratedKW), "7.46")
        XCTAssertTrue(extracted.value(.notes)?.contains("dual FLA") ?? false)
        XCTAssertEqual(extracted.agentID, "heuristic-v1")
        XCTAssertFalse(extracted.leavesDevice)
        XCTAssertGreaterThan(extracted.field(.ratedHP)?.confidence ?? 0, 0.8)
        XCTAssertFalse(extracted.field(.fla)?.reviewed ?? true)
    }

    func testStackedVisionStyleLines() {
        let text = """
        HP
        7.5
        R.P.M.
        1760
        VOLTS
        460
        AMPS
        10.0
        HZ
        60
        PHASE
        3
        """
        let extracted = NameplateFieldParser.extract(text: text)
        XCTAssertEqual(extracted.value(.ratedHP), "7.5")
        XCTAssertEqual(extracted.value(.rpm), "1760")
        XCTAssertEqual(extracted.value(.voltage), "460")
        XCTAssertEqual(extracted.value(.fla), "10.0")
        XCTAssertEqual(extracted.value(.frequencyHz), "60")
        XCTAssertEqual(extracted.value(.phases), "3")
    }

    func testValueThenUnitOnOneLine() {
        let text = "10 HP  1750 RPM  460 V  14 A  60 HZ  3 PH  TEFC  215T  SF 1.15"
        let extracted = NameplateFieldParser.extract(text: text)
        XCTAssertEqual(extracted.value(.ratedHP), "10")
        XCTAssertEqual(extracted.value(.rpm), "1750")
        XCTAssertEqual(extracted.value(.voltage), "460")
        XCTAssertEqual(extracted.value(.fla), "14")
        XCTAssertEqual(extracted.value(.frequencyHz), "60")
        XCTAssertEqual(extracted.value(.phases), "3")
        XCTAssertEqual(extracted.value(.enclosure), "TEFC")
        XCTAssertEqual(extracted.value(.frame), "215T")
        XCTAssertEqual(extracted.value(.sf), "1.15")
    }

    func testFractionalSinglePhasePlate() {
        let text = """
        HP 1/2
        RPM 1725
        VOLTS 115
        AMPS 9.8
        PH 1
        HZ 60
        ODP
        FRAME 56
        """
        let extracted = NameplateFieldParser.extract(text: text)
        XCTAssertEqual(extracted.value(.ratedHP), "1/2")
        XCTAssertEqual(extracted.value(.rpm), "1725")
        XCTAssertEqual(extracted.value(.voltage), "115")
        XCTAssertEqual(extracted.value(.fla), "9.8")
        XCTAssertEqual(extracted.value(.phases), "1")
        XCTAssertEqual(extracted.value(.enclosure), "ODP")
        XCTAssertEqual(extracted.value(.frame), "56")
    }

    func testGluedTokensAndPFAsFraction() {
        let text = """
        HP10
        RPM1750
        VOLTS230/460
        PF 0.85
        3PH
        """
        let extracted = NameplateFieldParser.extract(text: text)
        XCTAssertEqual(extracted.value(.ratedHP), "10")
        XCTAssertEqual(extracted.value(.rpm), "1750")
        XCTAssertEqual(extracted.value(.voltage), "230/460")
        XCTAssertEqual(extracted.value(.pf), "0.85")
        XCTAssertEqual(extracted.value(.phases), "3")
    }

    func testKwMapsToHorsepowerWhenHPMissing() {
        let text = """
        kW 7.46
        RPM 1750
        VOLTS 460
        """
        let extracted = NameplateFieldParser.extract(text: text)
        XCTAssertEqual(extracted.value(.ratedHP), "10")
        XCTAssertEqual(extracted.value(.ratedKW), "7.46")
        XCTAssertLessThan(extracted.field(.ratedHP)?.confidence ?? 1, 0.70)
        XCTAssertTrue(extracted.field(.ratedHP)?.isLowConfidence ?? false)
    }

    func testLabeledHPWinsOverKw() {
        let text = """
        HP 10
        kW 7.46
        """
        let extracted = NameplateFieldParser.extract(text: text)
        XCTAssertEqual(extracted.value(.ratedHP), "10")
        XCTAssertEqual(extracted.value(.ratedKW), "7.46")
        XCTAssertGreaterThan(extracted.field(.ratedHP)?.confidence ?? 0, 0.80)
    }

    func testGarbageIsNotANameplate() {
        let extracted = NameplateFieldParser.extract(text: """
        PANEL MDP-2
        400A MCB
        """)
        XCTAssertNil(extracted.value(.ratedHP))
        XCTAssertNil(extracted.value(.rpm))
        XCTAssertNil(extracted.value(.manufacturer))
        XCTAssertLessThan(extracted.populatedCount, 3)
    }

    func testEmptyInputYieldsNoFields() {
        let extracted = NameplateFieldParser.extract(text: "   \n  ")
        XCTAssertTrue(extracted.fields.isEmpty)
        XCTAssertTrue(extracted.rawLines.isEmpty)
    }

    func testVisionConfidenceScalesFieldConfidence() {
        let lines = [
            NameplateOCRLine(text: "HP 10", confidence: 0.4),
            NameplateOCRLine(text: "RPM 1750", confidence: 0.95),
        ]
        let extracted = NameplateFieldParser.extract(lines: lines)
        XCTAssertLessThan(extracted.field(.ratedHP)?.confidence ?? 1, 0.50)
        XCTAssertGreaterThan(extracted.field(.rpm)?.confidence ?? 0, 0.80)
        XCTAssertTrue(extracted.field(.ratedHP)?.isLowConfidence ?? false)
    }

    func testIEEfficiencyClassGoesToNotesNotNomEff() {
        let extracted = NameplateFieldParser.extract(text: "EFF IE3\nHP 15\nRPM 1460\nHZ 50")
        XCTAssertNil(extracted.value(.nomEff))
        XCTAssertTrue(extracted.value(.notes)?.contains("IE3") ?? false)
        XCTAssertEqual(extracted.value(.frequencyHz), "50")
        XCTAssertEqual(extracted.value(.poles), "4")
    }

    func testMOCPAndLRAAreNeverFLA() {
        let text = """
        HP 10
        VOLTS 460
        FLA 12.5
        LRA 72
        MOCP 40
        SFA 14.4
        HZ 60
        PH 3
        """
        let extracted = NameplateFieldParser.extract(text: text)
        XCTAssertEqual(extracted.value(.fla), "12.5")
        XCTAssertEqual(extracted.value(.lra), "72")
        XCTAssertEqual(extracted.value(.mocp), "40")
        XCTAssertEqual(extracted.value(.serviceFactorAmps), "14.4")
        XCTAssertNotEqual(extracted.value(.fla), extracted.value(.lra))
        XCTAssertNotEqual(extracted.value(.fla), extracted.value(.mocp))

        let mocpOnly = NameplateFieldParser.extract(text: "MOCP 40 A\nHP 10")
        XCTAssertEqual(mocpOnly.value(.mocp), "40")
        XCTAssertNil(mocpOnly.value(.fla))

        let lraAmps = NameplateFieldParser.extract(text: "LOCKED ROTOR 72 AMPS\nHP 5")
        XCTAssertEqual(lraAmps.value(.lra), "72")
        XCTAssertNil(lraAmps.value(.fla))
        XCTAssertTrue(NameplateFieldParser.isMOCPOrLRALine("MOCP 40 A"))
        XCTAssertTrue(NameplateFieldParser.isMOCPOrLRALine("LRA 72"))
        XCTAssertFalse(NameplateFieldParser.isMOCPOrLRALine("FLA 12.5"))
    }

    func testSameLineFLAAndLRA() {
        let extracted = NameplateFieldParser.extract(text: "FLA 12.5 LRA 72\nHP 10")
        XCTAssertEqual(extracted.value(.fla), "12.5")
        XCTAssertEqual(extracted.value(.lra), "72")
    }

    func testDesignCodeInsulationLetters() {
        let extracted = NameplateFieldParser.extract(text: """
        HP 10
        DESIGN B
        CODE G
        INSULATION CLASS F
        """)
        XCTAssertEqual(extracted.value(.designLetter), "B")
        XCTAssertEqual(extracted.value(.codeLetter), "G")
        XCTAssertEqual(extracted.value(.insulationClass), "F")
    }

    func testHandoffHelpersPreferHighVoltageOnThreePhase() {
        XCTAssertEqual(NameplateFieldParser.preferredVoltage(raw: "230/460", threePhase: true), "460")
        XCTAssertEqual(NameplateFieldParser.preferredVoltage(raw: "230/460", threePhase: false), "230")
        XCTAssertEqual(NameplateFieldParser.preferredAmps(raw: "25.0/12.5", threePhase: true), "12.5")
        XCTAssertEqual(NameplateFieldParser.preferredAmps(raw: "25.0/12.5", threePhase: false), "25.0")
    }

    func testInferredPolesFromNameplateRPM() {
        XCTAssertEqual(NameplateFieldParser.inferredPoles(rpm: 1750, frequencyHz: 60), 4)
        XCTAssertEqual(NameplateFieldParser.inferredPoles(rpm: 3500, frequencyHz: 60), 2)
        XCTAssertEqual(NameplateFieldParser.inferredPoles(rpm: 1160, frequencyHz: 60), 6)
        XCTAssertEqual(NameplateFieldParser.inferredPoles(rpm: 1460, frequencyHz: 50), 4)
        XCTAssertNil(NameplateFieldParser.inferredPoles(rpm: 0, frequencyHz: 60))
    }

    func testNearestListedHorsepower() {
        XCTAssertEqual(MotorFLA.nearestListedHorsepower(value: 10, threePhase: true), "10")
        XCTAssertEqual(MotorFLA.nearestListedHorsepower(value: 7.5, threePhase: true), "7-1/2")
        XCTAssertEqual(MotorFLA.nearestListedHorsepower(value: 0.5, threePhase: false), "1/2")
        XCTAssertEqual(MotorFLA.horsepowerValue("7-1/2"), 7.5)
        XCTAssertEqual(MotorFLA.horsepowerValue("1/2"), 0.5)
        XCTAssertEqual(MotorFLA.horsepowerValue("1-1/2"), 1.5)
        XCTAssertNil(MotorFLA.nearestListedHorsepower(value: 0, threePhase: true))
    }

    func testCloudAgentIsGatedOffAndDoesNotInventFields() async {
        XCTAssertFalse(NameplateAgentPolicy.cloudVLMEnabled)
        XCTAssertTrue(NameplateAgentPolicy.cloudVLMRequiresExplicitUserAction)
        XCTAssertFalse(NameplateAgentPolicy.activeAgent.leavesDevice)
        XCTAssertEqual(NameplateAgentPolicy.activeAgent.id, "heuristic-v1")

        do {
            _ = try await CloudNameplateAgent().extract(lines: [
                NameplateOCRLine(text: "HP 10"),
            ])
            XCTFail("Cloud stub must throw, not return invented VLM fields")
        } catch NameplateAgentError.cloudDisabled {
            // expected — no fake model output
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testHeuristicAgentUsesParserNotRawDump() async throws {
        let agent = HeuristicNameplateAgent()
        let result = try await agent.extract(lines: [
            NameplateOCRLine(text: "HP 10"),
            NameplateOCRLine(text: "RPM 1750"),
            NameplateOCRLine(text: "this line is not a field"),
        ])
        XCTAssertEqual(result.value(.ratedHP), "10")
        XCTAssertEqual(result.value(.rpm), "1750")
        XCTAssertFalse(result.fields.contains { $0.value.contains("this line is not a field") })
        XCTAssertFalse(result.leavesDevice)
    }

    func testExtractionPolicyToolIDIsExplicit() {
        XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: "motorNameplateOCR"), .explicit)
        XCTAssertTrue(ToolCalculationPolicy.knownToolIDs.contains("motorNameplateOCR"))
    }

    func testSharedSchemaKeysAndReviewedFlag() throws {
        let extracted = NameplateFieldParser.extract(text: """
        HP 10
        FLA 12.5
        LRA 72
        MOCP 40
        VOLTS 460
        HZ 60
        PH 3
        PF 82
        SER A12345
        """)
        XCTAssertFalse(extracted.fields.contains { $0.reviewed })

        let record = extracted.schemaRecord()
        XCTAssertEqual(record.ratedHP.value, 10)
        XCTAssertEqual(record.fla.value, 12.5)
        XCTAssertEqual(record.lra.value, 72)
        XCTAssertEqual(record.mocp.value, 40)
        XCTAssertEqual(record.voltage.value, "460")
        XCTAssertEqual(record.frequencyHz.value, 60)
        XCTAssertEqual(record.phases.value, 3)
        XCTAssertEqual(record.pf.value, 0.82)
        XCTAssertEqual(record.serialNumber.value, "A12345")
        XCTAssertFalse(record.fla.reviewed)
        XCTAssertNotEqual(record.fla.value, record.lra.value)
        XCTAssertNotEqual(record.fla.value, record.mocp.value)

        let confirmed = extracted.confirmingReview()
        XCTAssertTrue(confirmed.field(.fla)?.reviewed ?? false)
        XCTAssertTrue(confirmed.field(.lra)?.reviewed ?? false)
        XCTAssertFalse(extracted.field(.fla)?.reviewed ?? true)
        XCTAssertTrue(confirmed.schemaRecord().fla.reviewed)
        XCTAssertTrue(record.confirmed().fla.reviewed)

        let json = try XCTUnwrap(record.jsonString())
        XCTAssertTrue(json.contains("\"fla\""))
        XCTAssertTrue(json.contains("\"serialNumber\""))
        XCTAssertTrue(json.contains("\"frequencyHz\""))
        XCTAssertTrue(json.contains("\"ratedHP\""))
        XCTAssertTrue(json.contains("\"reviewed\""))
        XCTAssertTrue(json.contains("\"confidence\""))
        XCTAssertFalse(json.contains("\"horsepower\""))
        XCTAssertFalse(json.contains("\"amps\""))
        XCTAssertFalse(json.contains("\"frequency\""))
        XCTAssertFalse(json.contains("\"phase\""))

        let decoded = try JSONDecoder().decode(MotorNameplateRecord.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.fla.value, 12.5)
        XCTAssertEqual(decoded.lra.value, 72)
        XCTAssertEqual(decoded.mocp.value, 40)
        XCTAssertEqual(decoded.pf.value, 0.82)
        XCTAssertEqual(decoded.serialNumber.value, "A12345")
        XCTAssertFalse(decoded.fla.reviewed)
    }

    func testApplyingDraftDoesNotMarkReviewedUntilConfirm() {
        let extracted = NameplateFieldParser.extract(text: "HP 10\nFLA 12.5")
        let edited = extracted.applying(draft: [
            .ratedHP: "15",
            .fla: "12.5",
        ])
        XCTAssertEqual(edited.value(.ratedHP), "15")
        XCTAssertEqual(edited.field(.ratedHP)?.source, .user)
        XCTAssertEqual(edited.field(.ratedHP)?.confidence, 1)
        XCTAssertFalse(edited.field(.ratedHP)?.reviewed ?? true)
        XCTAssertEqual(edited.field(.fla)?.source, .heuristic)
        XCTAssertFalse(edited.field(.fla)?.reviewed ?? true)

        let confirmed = edited.confirmingReview()
        XCTAssertTrue(confirmed.field(.ratedHP)?.reviewed ?? false)
        XCTAssertTrue(confirmed.field(.fla)?.reviewed ?? false)
        XCTAssertTrue(confirmed.schemaRecord(forceReviewed: true).ratedHP.reviewed)
    }

    func testDualFrequencyRecordsSixty() {
        let extracted = NameplateFieldParser.extract(text: "HP 10\nHZ 50/60")
        XCTAssertEqual(extracted.value(.frequencyHz), "60")
        XCTAssertTrue(extracted.value(.notes)?.contains("50/60") ?? false)
    }
}
