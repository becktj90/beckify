import XCTest
@testable import BeckifyMath

/// Fixture strings → structured rows. These are not claimed Vision or VLM
/// outputs — they stand in for recognized text so the parser can be tested
/// on Linux without Apple Vision.
final class PanelScheduleOCRTests: XCTestCase {

    func testTwoUpScheduleExtractsRowsAndClassifies() {
        let text = """
        Panel: LP-1
        Voltage: 208Y/120V
        Main Rating: 225A MCB
        1 LIGHTING OFFICE 20A 1P 2 RECEPTACLES 20A 1P
        3 AHU-1 40A 2P 4 SPARE 20A 1P
        """
        let extracted = PanelScheduleParser.extract(text: text)

        XCTAssertEqual(extracted.circuits.map(\.circuit), ["1", "2", "3", "4"])
        XCTAssertEqual(extracted.circuits[0].name, "LIGHTING OFFICE")
        XCTAssertEqual(extracted.circuits[0].trip, "20A")
        XCTAssertEqual(extracted.circuits[0].loadClass, .lighting)
        XCTAssertEqual(extracted.circuits[1].loadClass, .receptacle)
        XCTAssertEqual(extracted.circuits[2].loadClass, .motor)
        XCTAssertTrue(extracted.circuits[3].isSpareOrSpace)
        XCTAssertEqual(extracted.panelName.value, "LP-1")
        XCTAssertEqual(extracted.voltage.value, "208Y/120V")
        XCTAssertEqual(extracted.mainRating.value, "225A")
        XCTAssertEqual(extracted.phases.value, "3")
        XCTAssertEqual(extracted.agentID, "heuristic-v1")
        XCTAssertFalse(extracted.leavesDevice)
        XCTAssertFalse(extracted.circuits[0].reviewed)
    }

    func testGuessesHardToReadLightingAndTrip() {
        let extracted = PanelScheduleParser.extract(text: "1 UGHTING OFFICE 2OA 1P")
        XCTAssertEqual(extracted.circuits.count, 1)
        XCTAssertEqual(extracted.circuits[0].name, "LIGHTING OFFICE")
        XCTAssertEqual(extracted.circuits[0].trip, "20A")
        XCTAssertTrue(extracted.circuits[0].guessed)
        XCTAssertLessThan(extracted.circuits[0].confidence, 0.80)
        XCTAssertTrue(extracted.circuits[0].isLowConfidence)
    }

    func testGuessesSpareFromSpapeAndPolesFromIP() {
        let guessed = PanelScheduleParser.guessHardToRead("4 SPAPE 20A IP")
        XCTAssertTrue(guessed.changed)
        XCTAssertTrue(guessed.text.contains("SPARE"))
        XCTAssertTrue(guessed.text.contains("1P") || guessed.text.contains("IP") == false)

        let extracted = PanelScheduleParser.extract(text: "4 SPAPE 20A IP")
        XCTAssertEqual(extracted.circuits.count, 1)
        XCTAssertEqual(extracted.circuits[0].name, "SPARE")
        XCTAssertTrue(extracted.circuits[0].isSpareOrSpace)
    }

    func testVisionConfidenceScalesRowConfidence() {
        let lines = [
            PanelOCRLine(text: "1 LIGHTING OFFICE 20A 1P", confidence: 0.4),
            PanelOCRLine(text: "2 RECEPTACLES 20A 1P", confidence: 0.95),
        ]
        let extracted = PanelScheduleParser.extract(lines: lines)
        XCTAssertEqual(extracted.circuits.count, 2)
        XCTAssertLessThan(extracted.circuits[0].confidence, 0.50)
        XCTAssertGreaterThan(extracted.circuits[1].confidence, 0.80)
        XCTAssertTrue(extracted.circuits[0].isLowConfidence)
        XCTAssertFalse(extracted.circuits[1].isLowConfidence)
    }

    func testConfirmMarksReviewedAndApplyingDraftMarksUser() {
        let extracted = PanelScheduleParser.extract(text: "1 LIGHTING OFFICE 20A 1P")
        XCTAssertFalse(extracted.circuits[0].reviewed)

        let confirmed = extracted.confirmingReview()
        XCTAssertTrue(confirmed.circuits[0].reviewed)
        XCTAssertFalse(confirmed.circuits[0].isLowConfidence)

        var draft = extracted.circuits
        draft[0].name = "LIGHTING LOBBY"
        let applied = extracted.applying(draft: draft)
        XCTAssertEqual(applied.circuits[0].name, "LIGHTING LOBBY")
        XCTAssertEqual(applied.circuits[0].source, .user)
        XCTAssertEqual(applied.circuits[0].confidence, 1)
        XCTAssertFalse(applied.circuits[0].reviewed)
    }

    func testHeuristicAgentIsNotARawDump() async throws {
        let agent = HeuristicPanelAgent()
        XCTAssertEqual(agent.id, "heuristic-v1")
        XCTAssertFalse(agent.leavesDevice)
        let extracted = try await agent.extract(lines: [
            PanelOCRLine(text: "Panel: MDP-2"),
            PanelOCRLine(text: "1 LIGHTING OFFICE 20A 1P"),
        ])
        XCTAssertEqual(extracted.circuits.count, 1)
        XCTAssertEqual(extracted.panelName.value, "MDP-2")
        XCTAssertNotEqual(extracted.rawLines.joined(separator: " "), extracted.circuits[0].name)
    }

    func testCloudAgentStaysDisabled() async {
        XCTAssertFalse(PanelAgentPolicy.cloudVLMEnabled)
        XCTAssertTrue(PanelAgentPolicy.cloudVLMRequiresExplicitUserAction)
        XCTAssertEqual(PanelAgentPolicy.activeAgent.id, "heuristic-v1")
        do {
            _ = try await CloudPanelAgent().extract(lines: [PanelOCRLine(text: "1 LIGHTING")])
            XCTFail("cloud agent must throw")
        } catch let error as PanelAgentError {
            XCTAssertEqual(error, .cloudDisabled)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testVoltageAndMainParsing() {
        let y = PanelScheduleParser.parseVoltage("480Y/277V")
        XCTAssertEqual(y?.lineToLine, 480)
        XCTAssertEqual(y?.lineToNeutral, 277)
        XCTAssertEqual(y?.phases, 3)

        let split = PanelScheduleParser.parseVoltage("240/120")
        XCTAssertEqual(split?.lineToLine, 240)
        XCTAssertEqual(split?.lineToNeutral, 120)
        XCTAssertEqual(split?.phases, 1)

        XCTAssertEqual(PanelScheduleParser.parseMainAmps("400A MCB"), 400)
        XCTAssertEqual(PanelScheduleParser.parseTripAmps("20A"), 20)
    }

    func testConnectedVAOnePoleThreePhaseUsesLineToNeutral() {
        let va = PanelScheduleParser.connectedVA(tripAmps: 20, poles: 1, voltage: 208, phases: 3)
        XCTAssertEqual(va, 20 * 208 / sqrt(3), accuracy: 0.01)
        let three = PanelScheduleParser.connectedVA(tripAmps: 40, poles: 3, voltage: 208, phases: 3)
        XCTAssertEqual(three, 40 * 208 * sqrt(3), accuracy: 0.01)
        let split1 = PanelScheduleParser.connectedVA(tripAmps: 20, poles: 1, voltage: 240, phases: 1)
        XCTAssertEqual(split1, 20 * 120, accuracy: 0.01)
    }

    func testDemandAndCapacityToAddUsesWorksheetMath() throws {
        let circuits = [
            PanelCircuitDraft.from(PanelCircuit(circuit: "1", name: "LIGHTING OFFICE", trip: "20A", poles: "1"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "2", name: "RECEPTACLES", trip: "20A", poles: "1"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "3", name: "AHU-1", trip: "40A", poles: "3"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "4", name: "SPARE", trip: "20A", poles: "1"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "5", name: "FUTURE ROOM"), confidence: 0.6),
        ]
        let result = try PanelScheduleDemand.estimate(
            circuits: circuits,
            voltage: 208,
            phases: 3,
            mainAmps: 225,
            occupancy: .other
        )

        XCTAssertEqual(result.circuitsInDemand, 3)
        XCTAssertEqual(result.unusedPositions, 2)
        XCTAssertEqual(result.circuitsMissingTrip, 0)
        XCTAssertGreaterThan(result.totalDemandVA, 0)
        XCTAssertEqual(result.demandAmps, result.worksheet.amps, accuracy: 1e-9)
        XCTAssertEqual(result.mainAmps, 225)
        XCTAssertEqual(result.capacityToAddAmps ?? 0, 225 - result.demandAmps, accuracy: 1e-9)
        XCTAssertLessThan(result.utilization ?? 1, 1)
        XCTAssertTrue(result.caveats.contains(where: { $0.localizedCaseInsensitiveContains("not measured load") }))
        XCTAssertTrue(result.caveats.contains(where: { $0.localizedCaseInsensitiveContains("design aid") }))
        XCTAssertTrue(result.copyLine.contains("capacity to add"))

        let lightingVA = PanelScheduleParser.connectedVA(tripAmps: 20, poles: 1, voltage: 208, phases: 3)
        let receptVA = PanelScheduleParser.connectedVA(tripAmps: 20, poles: 1, voltage: 208, phases: 3)
        let motorVA = PanelScheduleParser.connectedVA(tripAmps: 40, poles: 3, voltage: 208, phases: 3)
        let expectedRows = [
            LoadWorksheetRow(description: "LIGHTING OFFICE", type: .lighting, vaEach: lightingVA),
            LoadWorksheetRow(description: "RECEPTACLES", type: .receptacle, vaEach: receptVA),
            LoadWorksheetRow(description: "AHU-1", type: .motor, vaEach: motorVA),
        ]
        let worksheet = try LoadWorksheet.calculate(
            rows: expectedRows,
            occupancy: .other,
            voltage: 208,
            phases: 3
        )
        XCTAssertEqual(result.totalDemandVA, worksheet.totalDemandVA, accuracy: 0.01)
        XCTAssertEqual(result.lightingDemandVA, worksheet.lightingDemandVA, accuracy: 0.01)
    }

    func testDwellingLightingDemandUses220_42() throws {
        let circuits = [
            PanelCircuitDraft.from(PanelCircuit(circuit: "1", name: "LIGHTING", trip: "20A", poles: "1"), confidence: 0.9),
        ]
        // 20A × 120 V = 2400 VA lighting on a 240/1Ø panel — first 3 kVA at 100%.
        let result = try PanelScheduleDemand.estimate(
            circuits: circuits,
            voltage: 240,
            phases: 1,
            mainAmps: 100,
            occupancy: .dwelling
        )
        XCTAssertEqual(result.lightingConnectedVA, 2400, accuracy: 0.01)
        XCTAssertEqual(result.lightingDemandVA, 2400, accuracy: 0.01)
        XCTAssertEqual(result.occupancy, .dwelling)
    }

    func testMissingTripDoesNotInventVA() throws {
        let circuits = [
            PanelCircuitDraft.from(PanelCircuit(circuit: "1", name: "LIGHTING OFFICE"), confidence: 0.7),
        ]
        let result = try PanelScheduleDemand.estimate(
            circuits: circuits,
            voltage: 208,
            phases: 3,
            mainAmps: 100,
            occupancy: .other
        )
        XCTAssertEqual(result.circuitsInDemand, 0)
        XCTAssertEqual(result.circuitsMissingTrip, 1)
        XCTAssertEqual(result.totalDemandVA, 0, accuracy: 1e-9)
        XCTAssertEqual(result.capacityToAddAmps ?? 0, 100, accuracy: 1e-9)
    }

    func testCategoryTotalsSkipSpare() {
        let circuits = [
            PanelCircuitDraft.from(PanelCircuit(circuit: "1", name: "LIGHTING", trip: "20A", poles: "1"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "2", name: "SPARE", trip: "20A", poles: "1"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "3", name: "AHU-1", trip: "40A", poles: "3"), confidence: 0.9),
        ]
        let totals = PanelScheduleDemand.categoryTotals(from: circuits, voltage: 208, phases: 3)
        XCTAssertGreaterThan(totals[.lighting] ?? 0, 0)
        XCTAssertGreaterThan(totals[.motor] ?? 0, 0)
        XCTAssertNil(totals[.other])
    }

    func testExistingDirectoryParserStillReadsNameOnlyStickers() {
        let rows = PanelDirectory.parse("""
        1 LIGHTING OFFICE
        2 RECEPTACLES BREAK ROOM
        """)
        XCTAssertEqual(rows.count, 2)
        let extracted = PanelScheduleParser.extract(text: """
        1 LIGHTING OFFICE
        2 RECEPTACLES BREAK ROOM
        """)
        XCTAssertEqual(extracted.circuits.count, 2)
        XCTAssertEqual(extracted.circuits[0].trip, "")
        XCTAssertTrue(extracted.circuits[0].isLowConfidence)
    }

    func testGenericPanelScheduleHeaderIsNotAPanelName() {
        let extracted = PanelScheduleParser.extract(text: """
        PANEL SCHEDULE
        1 LIGHTING OFFICE 20A 1P
        """)
        XCTAssertEqual(extracted.circuits.count, 1)
        XCTAssertFalse(extracted.panelName.isPresent)
    }

    func testEmptyInputYieldsNoCircuits() {
        let extracted = PanelScheduleParser.extract(text: "   \n  ")
        XCTAssertTrue(extracted.circuits.isEmpty)
        XCTAssertTrue(extracted.rawLines.isEmpty)
    }

    func testTSVIncludesLoadClass() {
        let extracted = PanelScheduleParser.extract(text: "1 LIGHTING OFFICE 20A 1P")
        XCTAssertTrue(extracted.tsv().contains("lighting"))
        XCTAssertTrue(extracted.tsv().hasPrefix("Circuit\tName\tTrip\tPoles\tClass"))
    }
}
