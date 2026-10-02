import XCTest
@testable import BeckifyMath

final class PanelDirectoryTrustTests: XCTestCase {

    func testConflictMergeQueuesDisagreementInsteadOfSilentFirstWins() {
        let left = PanelScheduleParser.extract(text: "1 LIGHTING OFFICE 20A 1P")
        let right = PanelCloudAnalyze.normalize([
            "circuits": [[
                "circuit": ["value": "1"],
                "description": ["value": "LIGHTING LOBBY"],
                "trip": ["value": 20],
                "poles": ["value": 1],
            ]],
        ] as [String: Any]).extraction
        let merge = PanelConflictMerge.merge(left, right)
        XCTAssertEqual(merge.extraction.circuits.count, 1)
        XCTAssertEqual(merge.extraction.circuits[0].name, "LIGHTING OFFICE")
        XCTAssertFalse(merge.conflicts.isEmpty)
        XCTAssertTrue(merge.conflicts.contains { $0.field == "name" && $0.incomingValue == "LIGHTING LOBBY" })
        XCTAssertEqual(merge.extraction.circuits[0].reviewState, .conflict)
    }

    func testUserRowsStillWinWithoutConflict() {
        let left = PanelScheduleParser.extract(text: "1 LIGHTING OFFICE 20A 1P")
        var edited = left.circuits
        edited[0].name = "LIGHTING LOBBY"
        let user = left.applying(draft: edited)
        let right = PanelCloudAnalyze.normalize([
            "circuits": [[
                "circuit": ["value": "1"],
                "description": ["value": "LIGHTING OFFICE"],
                "trip": ["value": 20],
            ], [
                "circuit": ["value": "2"],
                "description": ["value": "RECEPTACLES"],
                "trip": ["value": 20],
            ]],
        ] as [String: Any]).extraction
        let merge = PanelCloudAnalyze.mergeWithConflicts(existing: user, incoming: right)
        XCTAssertEqual(merge.extraction.circuits[0].name, "LIGHTING LOBBY")
        XCTAssertEqual(merge.extraction.circuits[0].source, .user)
        XCTAssertEqual(merge.extraction.circuits[1].name, "RECEPTACLES")
        XCTAssertTrue(merge.conflicts.filter { $0.circuitKey == "1" && $0.isOpen }.isEmpty)
    }

    func testTripScenarioWithholdsCapacityToAdd() throws {
        let circuits = [
            PanelCircuitDraft.from(PanelCircuit(circuit: "1", name: "LIGHTING", trip: "20A", poles: "1"), confidence: 0.9),
        ]
        let result = try PanelScheduleDemand.estimate(
            circuits: circuits,
            voltage: 208,
            phases: 3,
            mainAmps: 100,
            occupancy: .other
        )
        let coverage = PanelCoverage(expectedSlots: 42, photographedSlots: 1, readableSlots: 1, notes: ["partial"])
        let presented = PanelDemandAnalysis.present(result: result, coverage: coverage)
        XCTAssertEqual(presented.scenario, .tripAsConservativeConnected)
        XCTAssertFalse(presented.showsCapacityToAdd)
        XCTAssertTrue(presented.copyLine.contains("No capacity-to-add") || (presented.capacityWithheldReason?.contains("trips") ?? false))
        XCTAssertFalse(result.copyLine.localizedCaseInsensitiveContains("capacity to add \(1)"))
        XCTAssertTrue(result.copyLine.localizedCaseInsensitiveContains("No capacity-to-add from trips alone"))
        XCTAssertTrue(result.caveats.contains(where: { $0.localizedCaseInsensitiveContains("not measured load") }))
    }

    func testCoverageIncompleteWhenExpectedMissing() {
        let circuits = [
            PanelCircuitDraft.from(PanelCircuit(circuit: "1", name: "LIGHTING", trip: "20A"), confidence: 0.9),
            PanelCircuitDraft(
                circuit: "2",
                name: "",
                confidence: 0.2,
                slotKind: .notPhotographed,
                reviewState: .needsReview
            ),
        ]
        let coverage = PanelCoverage.from(circuits: circuits, expectedSlots: 42, inferredSlots: 0)
        XCTAssertFalse(coverage.isComplete)
        XCTAssertTrue(coverage.summaryLine.contains("incomplete") || coverage.notes.contains(where: { $0.contains("not in these photos") }))
    }

    func testSpareSpaceUnreadableKinds() {
        XCTAssertEqual(PanelSlotKind.infer(fromName: "SPARE"), .spare)
        XCTAssertEqual(PanelSlotKind.infer(fromName: "SPACE"), .space)
        XCTAssertEqual(PanelSlotKind.infer(fromName: "UNREADABLE"), .unreadable)
        XCTAssertEqual(PanelSlotKind.infer(fromName: "NOT PHOTOGRAPHED"), .notPhotographed)
        XCTAssertEqual(PanelSlotKind.infer(fromName: "LIGHTING", poles: "2"), .circuit)
    }

    func testTandemKeysStayDistinctAndMultiPoleGroups() {
        XCTAssertEqual(PanelCloudAnalyze.normalizeCircuitKey("01A"), "1A")
        XCTAssertEqual(PanelCloudAnalyze.normalizeCircuitKey("1B"), "1B")
        let circuits = [
            PanelCircuitDraft.from(PanelCircuit(circuit: "3", name: "AHU-1", trip: "40A", poles: "3"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "4", name: "AHU-1", trip: "40A", poles: "3"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "5", name: "AHU-1", trip: "40A", poles: "3"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "1A", name: "SPARE", trip: "20A", poles: "1"), confidence: 0.9),
            PanelCircuitDraft.from(PanelCircuit(circuit: "1B", name: "SPARE", trip: "20A", poles: "1"), confidence: 0.9),
        ]
        let groups = PanelPoleGrouping.groups(from: circuits)
        XCTAssertTrue(groups.contains { $0.circuitKeys == ["3", "4", "5"] && $0.poles == 3 })
        XCTAssertTrue(groups.contains { $0.circuitKeys == ["1A"] })
        XCTAssertTrue(groups.contains { $0.circuitKeys == ["1B"] })
    }

    func testWorksheetHandoffPreviewMergeReplaceProvenance() {
        let circuits = [
            PanelCircuitDraft.from(PanelCircuit(circuit: "1", name: "LIGHTING", trip: "20A", poles: "1"), confidence: 0.9),
        ]
        let replace = PanelWorksheetHandoff.preview(
            circuits: circuits,
            voltage: 208,
            phases: 3,
            occupancy: .other,
            mode: .replace,
            existing: [.lighting: 1000],
            coverage: PanelCoverage(readableSlots: 1),
            confirmed: true,
            agentID: "heuristic-v1"
        )
        XCTAssertEqual(PanelWorksheetHandoff.values(for: replace)[.lighting] ?? 0, replace.totals[.lighting] ?? -1, accuracy: 0.01)
        XCTAssertTrue(replace.provenance.contains(where: { $0.contains("Replace") || $0.contains("replace") }))
        XCTAssertTrue(replace.provenance.contains(where: { $0.localizedCaseInsensitiveContains("not measured") }))

        let merge = PanelWorksheetHandoff.preview(
            circuits: circuits,
            voltage: 208,
            phases: 3,
            occupancy: .other,
            mode: .merge,
            existing: [.lighting: 1000],
            coverage: PanelCoverage(readableSlots: 1),
            confirmed: false,
            agentID: "cloud-vlm"
        )
        let mergedLighting = PanelWorksheetHandoff.values(for: merge)[.lighting] ?? 0
        XCTAssertEqual(mergedLighting, 1000 + (merge.totals[.lighting] ?? 0), accuracy: 0.01)
        XCTAssertTrue(merge.provenance.contains(where: { $0.contains("NOT confirmed") }))
    }

    func testPartialFrameDoesNotRenumberFromOneWithoutAnchor() {
        let lines = [
            PanelOCRLine(text: "LIGHTING OFFICE 20A 1P", box: PanelOCRBox(x: 0.1, y: 0.8, width: 0.3, height: 0.05)),
            PanelOCRLine(text: "RECEPTACLES 20A 1P", box: PanelOCRBox(x: 0.6, y: 0.8, width: 0.3, height: 0.05)),
        ]
        let assigned = FuzzyPanelGrid.assign(lines)
        XCTAssertEqual(assigned.inferredSlots, 0)
        XCTAssertFalse(assigned.lines[0].text.hasPrefix("1 "))
        XCTAssertFalse(assigned.lines[1].text.hasPrefix("2 "))
    }

    func testPrintedAnchorAllowsOddEvenInfer() {
        let lines = [
            PanelOCRLine(text: "21 LIGHTING 20A 1P", box: PanelOCRBox(x: 0.1, y: 0.8, width: 0.3, height: 0.05)),
            PanelOCRLine(text: "RECEPTACLES 20A 1P", box: PanelOCRBox(x: 0.6, y: 0.8, width: 0.3, height: 0.05)),
            PanelOCRLine(text: "AHU-2 40A 2P", box: PanelOCRBox(x: 0.1, y: 0.7, width: 0.3, height: 0.05)),
        ]
        let assigned = FuzzyPanelGrid.assign(lines)
        XCTAssertGreaterThanOrEqual(assigned.inferredSlots, 1)
        XCTAssertTrue(assigned.lines.contains { $0.inferredCircuit && ($0.text.contains("22") || $0.text.hasPrefix("22 ")) })
    }

    func testPhotoRoleGuidanceAndReviewFilter() {
        XCTAssertFalse(PanelPhotoRole.directory.guidance.isEmpty)
        XCTAssertFalse(PanelPhotoRole.nameplate.guidance.isEmpty)
        XCTAssertFalse(PanelPhotoRole.deadfront.guidance.isEmpty)
        let row = PanelCircuitDraft(
            circuit: "1",
            name: "LIGHTING",
            confidence: 0.4,
            circuitNumberInferred: true,
            reviewState: .needsReview
        )
        XCTAssertTrue(PanelReviewFilter.needsReview.includes(row))
        XCTAssertFalse(PanelReviewFilter.verified.includes(row))
        XCTAssertTrue(PanelReviewFilter.all.includes(row))
    }

    func testHowItWorksMentionsNoCapacityFromTrips() {
        let copy = ToolHowItWorksCatalog.copy(forToolID: "panelDirectory")
        XCTAssertTrue(copy?.summary.localizedCaseInsensitiveContains("Local OCR") == true
            || copy?.summary.localizedCaseInsensitiveContains("Analyze") == true)
        XCTAssertTrue(copy?.bullets.contains(where: {
            $0.localizedCaseInsensitiveContains("capacity") || $0.localizedCaseInsensitiveContains("Conflict")
        }) == true)
    }
}
