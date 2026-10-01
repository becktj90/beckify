import XCTest
@testable import BeckifyMath

final class ProfessionalResultModelTests: XCTestCase {
    func testConductorDesignSeedRoundTrips() throws {
        let seed = ConductorDesignSeed(
            sourceToolID: "wireAmpacity",
            sourceSummary: "3 AWG Cu",
            loadAmps: 95,
            material: .copper,
            size: "3",
            system: .threePhase,
            supplyVolts: 480,
            oneWayFeet: 250,
            parallelRuns: 1,
            insulationCelsius: 90,
            terminationCelsius: 75
        )
        let data = try DesignHandoffStore.encode(seed)
        let decoded = try DesignHandoffStore.decode(data)
        XCTAssertEqual(decoded, seed)
    }
}

final class AmpacityDeratingTests: XCTestCase {
    func testAmbientAndCCCFactorsMatchPublishedTables() throws {
        XCTAssertEqual(NECAmpacityFactors.ambientCorrectionFactor(ambientC: 30, insulation: .c75), 1.0, accuracy: 1e-9)
        XCTAssertEqual(NECAmpacityFactors.ambientCorrectionFactor(ambientC: 40, insulation: .c75), 0.88, accuracy: 1e-9)
        XCTAssertEqual(NECAmpacityFactors.ambientCorrectionFactor(ambientC: 40, insulation: .c90), 0.91, accuracy: 1e-9)
        XCTAssertEqual(try NECAmpacityFactors.cccAdjustmentFactor(currentCarryingCount: 3), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try NECAmpacityFactors.cccAdjustmentFactor(currentCarryingCount: 6), 0.8, accuracy: 1e-9)
        XCTAssertEqual(try NECAmpacityFactors.cccAdjustmentFactor(currentCarryingCount: 9), 0.7, accuracy: 1e-9)
        XCTAssertEqual(NECAmpacityFactors.ambientCorrectionFactor(ambientC: 90, insulation: .c75), 0, accuracy: 1e-9)
    }

    func testNinetyInsulationCorrectedThenCappedAtSeventyFiveTermination() throws {
        // #3 Cu: 90 °C = 115 A, 75 °C = 100 A. 30 °C / 3 CCC → derated 115, usable min(115,100)=100.
        let r = try WireAmpacity.evaluate(AmpacityDeratingInput(
            size: "3",
            material: .copper,
            insulation: .c90,
            termination: .c75,
            ambientC: 30,
            currentCarryingCount: 3,
            loadAmps: 95
        ))
        XCTAssertEqual(r.baseAmpacity, 115, accuracy: 1e-9)
        XCTAssertEqual(r.correctedAmpacity, 115, accuracy: 1e-9)
        XCTAssertEqual(r.terminationCap, 100, accuracy: 1e-9)
        XCTAssertEqual(r.usablePerRun, 100, accuracy: 1e-9)
        XCTAssertTrue(r.limitedByTermination)
        XCTAssertEqual(r.passesLoad, true)
        XCTAssertEqual(r.trace.map(\.id), ["base", "ambient", "ccc", "termination", "usable"])
    }

    func testAmbientFortyCelsiusForcesUpsizeFromLegacySeventyFivePick() throws {
        // Legacy 95 A @ 75 °C / 30 °C picks #3 (100 A).
        // At 40 °C ambient with 75 °C insulation: #3 usable = 100 × 0.88 = 88 < 95 → need larger.
        let cool = try WireAmpacity.selectConductor(loadAmps: 95, material: .copper, insulation: .c75, termination: .c75, ambientC: 30)
        XCTAssertEqual(cool.selected.size, "3")

        let hot = try WireAmpacity.selectConductor(loadAmps: 95, material: .copper, insulation: .c75, termination: .c75, ambientC: 40)
        XCTAssertNotEqual(hot.selected.size, "3")
        XCTAssertGreaterThanOrEqual(hot.selected.usableTotal + 1e-9, 95)
        XCTAssertEqual(hot.selected.ambientFactor, 0.88, accuracy: 1e-9)
    }

    func testContinuousLoadAppliesOnePointTwentyFive() throws {
        // 100 A continuous → required 125 A. #1 Cu @ 75 °C = 130 A.
        let r = try WireAmpacity.selectConductor(
            loadAmps: 100,
            material: .copper,
            insulation: .c75,
            termination: .c75,
            ambientC: 30,
            continuousLoad: true
        )
        XCTAssertEqual(r.requiredAmpacity, 125, accuracy: 1e-9)
        XCTAssertEqual(r.selected.size, "1")
        XCTAssertEqual(r.selected.usablePerRun, 130, accuracy: 1e-9)
    }

    func testSixCCCAppliesPointEightAdjustment() throws {
        let r = try WireAmpacity.evaluate(AmpacityDeratingInput(
            size: "2",
            material: .copper,
            insulation: .c75,
            termination: .c75,
            ambientC: 30,
            currentCarryingCount: 6,
            loadAmps: 90
        ))
        XCTAssertEqual(r.baseAmpacity, 115, accuracy: 1e-9)
        XCTAssertEqual(r.cccFactor, 0.8, accuracy: 1e-9)
        XCTAssertEqual(r.correctedAmpacity, 92, accuracy: 1e-9)
        XCTAssertEqual(r.usablePerRun, 92, accuracy: 1e-9)
    }

    func testRejectsNonFiniteAmbientAndInvalidTermination() {
        XCTAssertThrowsError(try WireAmpacity.evaluate(AmpacityDeratingInput(
            size: "3", material: .copper, ambientC: .nan
        )))
        XCTAssertThrowsError(try WireAmpacity.evaluate(AmpacityDeratingInput(
            size: "3", material: .copper, insulation: .c75, termination: .c90
        )))
    }

    func testCompatibilitySmallestConductorStillNinetyFiveAmpCopper() throws {
        let sized = try WireAmpacity.smallestConductor(loadAmps: 95, material: .copper)
        XCTAssertEqual(sized.size, "3")
        XCTAssertEqual(sized.ampacity, 100)
    }

    func testSeedForVoltageDropUsesCommittedSize() throws {
        let r = try WireAmpacity.selectConductor(loadAmps: 95, material: .copper)
        let seed = r.selected.seedForVoltageDrop
        XCTAssertEqual(seed.size, "3")
        XCTAssertEqual(seed.material, .copper)
        XCTAssertEqual(seed.loadAmps, 95, accuracy: 1e-9)
        XCTAssertEqual(seed.sourceToolID, "wireAmpacity")
    }

    func testDeratingStackMatchesTraceAndRequiredCurrent() throws {
        let r = try WireAmpacity.evaluate(AmpacityDeratingInput(
            size: "3",
            material: .copper,
            insulation: .c90,
            termination: .c75,
            ambientC: 30,
            currentCarryingCount: 3,
            loadAmps: 95
        ))
        let stack = try XCTUnwrap(DeratingStackReadout(result: r))
        XCTAssertEqual(stack.stages.map(\.id), DeratingStackReadout.stageIDs)
        XCTAssertEqual(stack.designCurrent ?? -1, r.requiredAmpacity ?? -2, accuracy: 1e-9)
        XCTAssertEqual(stack.verdict, .meetsRequired)

        let trace = Dictionary(uniqueKeysWithValues: r.trace.map { ($0.id, $0.value) })
        XCTAssertEqual(stack.stages[0].perConductorAmps, trace["base"] ?? -1, accuracy: 1e-9)
        XCTAssertEqual(stack.stages[1].perConductorAmps, trace["ambient"] ?? -1, accuracy: 1e-9)
        XCTAssertEqual(stack.stages[2].perConductorAmps, trace["ccc"] ?? -1, accuracy: 1e-9)
        let capped = min(trace["ccc"] ?? 0, trace["termination"] ?? 0)
        XCTAssertEqual(stack.stages[3].perConductorAmps, capped, accuracy: 1e-9)
        XCTAssertEqual(stack.stages[3].ampacity, trace["usable"] ?? -1, accuracy: 1e-6)
        XCTAssertEqual(stack.terminationCapAmps, trace["termination"] ?? -1, accuracy: 1e-9)
        XCTAssertEqual(stack.stages.map(\.ampacity).count, 4)
        for (got, want) in zip(stack.stages.map(\.ampacity), [115.0, 115, 115, 100]) {
            XCTAssertEqual(got, want, accuracy: 1e-6)
        }
        XCTAssertLessThanOrEqual(stack.plottedFraction(stageID: "bundling") ?? 2, (stack.plottedFraction(stageID: "ambient") ?? 0) + 1e-9)
        XCTAssertLessThanOrEqual(stack.plottedFraction(stageID: "terminal") ?? 2, (stack.plottedFraction(stageID: "bundling") ?? 0) + 1e-9)
        XCTAssertEqual(
            stack.announcement,
            "100 A usable, 95 A required. 310.16 115 A. Ambient 115 A. Bundling 115 A. 110.14(C) 100 A. Meets required. Clamped at the 75 °C column, 100 A. \(DeratingStackReadout.methodLine)"
        )
        XCTAssertEqual(stack.announcement.first?.isNumber, true)
        XCTAssertTrue(stack.announcement.hasPrefix(stack.usableLabel))
        XCTAssertTrue(stack.announcement.contains(DeratingStackReadout.methodLine))
    }

    func testDeratingStackBundlingDoesNotGrowAndFailStaysBelowRequired() throws {
        let r = try WireAmpacity.evaluate(AmpacityDeratingInput(
            size: "2",
            material: .copper,
            insulation: .c75,
            termination: .c75,
            ambientC: 30,
            currentCarryingCount: 6,
            loadAmps: 100
        ))
        let stack = try XCTUnwrap(DeratingStackReadout(result: r))
        XCTAssertEqual(r.passesLoad, false)
        XCTAssertEqual(stack.verdict, .belowRequired)
        XCTAssertFalse(stack.limitedByTermination)
        XCTAssertLessThanOrEqual(stack.stages[2].ampacity, stack.stages[1].ampacity + 1e-6)
        XCTAssertEqual(stack.stages[3].ampacity, stack.stages[2].ampacity, accuracy: 1e-6)
        XCTAssertEqual(stack.usableLabel, "92 A")
        XCTAssertEqual(stack.designCurrentLabel, "100 A")
        XCTAssertTrue(stack.announcement.hasPrefix("92 A usable, 100 A required."))
        XCTAssertTrue(stack.announcement.contains("Below required."))
        XCTAssertTrue(stack.announcement.contains("75 °C column 115 A does not reduce ampacity."))
        XCTAssertFalse(stack.announcement.localizedCaseInsensitiveContains("warn"))
    }

    func testDeratingStackCoolAmbientCanLengthenBeforeTheCap() throws {
        let r = try WireAmpacity.evaluate(AmpacityDeratingInput(
            size: "3",
            material: .copper,
            insulation: .c90,
            termination: .c75,
            ambientC: 25,
            currentCarryingCount: 3,
            loadAmps: 95
        ))
        let stack = try XCTUnwrap(DeratingStackReadout(result: r))
        XCTAssertEqual(r.ambientFactor, 1.04, accuracy: 1e-9)
        XCTAssertGreaterThan(stack.stages[1].ampacity, stack.stages[0].ampacity)
        XCTAssertLessThanOrEqual(stack.stages[2].ampacity, stack.stages[1].ampacity + 1e-6)
        XCTAssertLessThanOrEqual(stack.stages[3].ampacity, stack.stages[2].ampacity + 1e-6)
        XCTAssertEqual(stack.stages[3].ampacity, 100, accuracy: 1e-6)
        XCTAssertEqual(stack.verdict, .meetsRequired)
    }

    func testDeratingStackParallelRunsStayOnTheRequiredTotal() throws {
        let r = try WireAmpacity.evaluate(AmpacityDeratingInput(
            size: "3",
            material: .copper,
            insulation: .c90,
            termination: .c75,
            ambientC: 30,
            currentCarryingCount: 3,
            parallelRuns: 2,
            loadAmps: 180
        ))
        let stack = try XCTUnwrap(DeratingStackReadout(result: r))
        XCTAssertEqual(stack.parallelRuns, 2)
        XCTAssertEqual(stack.stages[0].perConductorAmps, 115, accuracy: 1e-6)
        XCTAssertEqual(stack.stages[0].ampacity, 230, accuracy: 1e-6)
        XCTAssertEqual(stack.stages[3].ampacity, r.usableTotal, accuracy: 1e-6)
        XCTAssertEqual(stack.designCurrent ?? -1, 180, accuracy: 1e-9)
        XCTAssertEqual(stack.verdict, .meetsRequired)
        XCTAssertTrue(stack.announcement.contains("200 A usable, 180 A required."))
        XCTAssertTrue(stack.announcement.contains("2 parallel runs."))
        XCTAssertTrue(stack.caption.contains("Per conductor: 310.16 115 A"))
    }

    func testDeratingStackLabelMatchesResultRowRounding() {
        XCTAssertEqual(DeratingStackReadout.ampsLabel(115), "115 A")
        XCTAssertEqual(DeratingStackReadout.ampsLabel(92), "92 A")
        XCTAssertEqual(DeratingStackReadout.ampsLabel(88), "88 A")
        XCTAssertEqual(DeratingStackReadout.ampsLabel(1000), "1 kA")
        XCTAssertEqual(DeratingStackReadout.ampsLabel(1500), "1.5 kA")
        XCTAssertEqual(DeratingStackReadout.ampsLabel(12028), "12 kA")
    }
}

final class VoltageDropSizingTests: XCTestCase {
    func testLegacyThreePhaseExampleStillHolds() throws {
        let r = try VoltageDrop.calculate(
            system: .threePhase,
            current: 45,
            oneWayFeet: 250,
            supplyVolts: 480,
            size: "4",
            material: .copper
        )
        // VD = √3 × 12.9 × 45 × 250 / 41740 ≈ 6.02 V
        XCTAssertEqual(r.dropVolts, 6.021, accuracy: 0.02)
        XCTAssertEqual(r.dropPercent, r.dropVolts / 480 * 100, accuracy: 1e-9)
        XCTAssertEqual(r.ampacity75C, 85)
        XCTAssertEqual(r.ampacityOK, true)
    }

    func testParallelRunsHalveApproximateDrop() throws {
        let single = try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .threePhase, supplyVolts: 480, current: 45, oneWayFeet: 250, size: "4", material: .copper, parallelRuns: 1
        ))
        let dual = try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .threePhase, supplyVolts: 480, current: 45, oneWayFeet: 250, size: "4", material: .copper, parallelRuns: 2
        ))
        XCTAssertEqual(dual.dropVolts, single.dropVolts / 2, accuracy: 1e-9)
        XCTAssertEqual(dual.parallelRuns, 2)
    }

    func testRecommendationPrefersFirstSizeMeetingAmpacityAndTarget() throws {
        let r = try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .threePhase,
            supplyVolts: 480,
            current: 45,
            oneWayFeet: 800,
            size: "4",
            material: .copper,
            targetDropPercent: 3
        ))
        XCTAssertFalse(r.meetsTarget)
        XCTAssertNotNil(r.recommendedSize)
        XCTAssertNotEqual(r.recommendedSize, "4")
        let rec = r.candidates.first { $0.size == r.recommendedSize }
        XCTAssertEqual(rec?.meetsAllConstraints, true)
        XCTAssertTrue(r.warnings.contains { $0.provenance == .engineeringApproximation })
        XCTAssertTrue(r.warnings.contains { $0.provenance == .informationalNote })
    }

    func testLargeFeederPointsAtTable8RPlusTable9X() throws {
        let r = try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .threePhase,
            supplyVolts: 480,
            current: 80,
            oneWayFeet: 200,
            size: "2",
            material: .copper
        ))
        XCTAssertFalse(r.citations.contains { $0.articleOrTable.contains("Table 9") && $0.sourceDescription.contains("K-factor") })
        XCTAssertTrue(r.citations.contains { $0.sourceDescription.contains("Not Chapter 9 Table 9") })
        XCTAssertTrue(r.warnings.contains { $0.message.contains("Table 8 R") && $0.message.contains("Table 9 X") })
        XCTAssertEqual(r.method.displayName, "Field K approximation (~75 °C)")
    }

    func testSmallBranchDoesNotForceReactanceWarning() throws {
        let r = try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .singlePhase, supplyVolts: 120, current: 16, oneWayFeet: 80, size: "12", material: .copper
        ))
        XCTAssertFalse(r.warnings.contains { $0.message.contains("Table 8 R") })
    }

    func testRejectsBlankCurrent() {
        XCTAssertThrowsError(try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .singlePhase, supplyVolts: 120, current: .nan, oneWayFeet: 100, size: "12", material: .copper
        )))
    }

    func testRunReadoutTableAndChartPercentShareModelValue() throws {
        // Classic example: table ~6.02 V / 1.25%. Chart must not show volts as %.
        let r = try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .threePhase,
            supplyVolts: 480,
            current: 45,
            oneWayFeet: 250,
            size: "4",
            material: .copper,
            parallelRuns: 1,
            targetDropPercent: 3
        ))
        XCTAssertEqual(r.dropVolts, 6.02, accuracy: 0.02)
        XCTAssertEqual(r.dropPercent, r.dropVolts / 480 * 100, accuracy: 1e-9)
        XCTAssertEqual(r.dropPercent, 1.25, accuracy: 0.02)

        let run = try XCTUnwrap(VoltageDropRunReadout(result: r))
        XCTAssertEqual(run.chartDropPercent, r.dropPercent, accuracy: 1e-12)
        XCTAssertEqual(run.chartDropVolts, r.dropVolts, accuracy: 1e-12)
        XCTAssertEqual(run.dropPercentLabel, NECCircuitRunReadout.percentLabel(r.dropPercent))
        // Regression: volts-as-percent would be ~6.0, not ~1.25.
        XCTAssertLessThan(run.chartDropPercent, 2)
        XCTAssertGreaterThan(r.dropVolts, 5)
        XCTAssertGreaterThan(abs(run.chartDropPercent - r.dropVolts), 3)

        XCTAssertEqual(run.note3Label, "3% informational note (this run)")
        XCTAssertEqual(run.note5Label, "5% informational note (this run)")
        XCTAssertFalse(run.note5Label.localizedCaseInsensitiveContains("feeder"))
        XCTAssertFalse(run.note5Label.localizedCaseInsensitiveContains("combined"))
        XCTAssertFalse(run.note5Value.localizedCaseInsensitiveContains("PASS"))
        XCTAssertEqual(run.note3Value, "WITHIN NOTE")
        XCTAssertEqual(run.note5Value, "WITHIN NOTE")
        XCTAssertTrue(run.ampacityRowLabel.contains("≤3 CCC"))
        XCTAssertTrue(run.ampacityAssumptionCaption.contains("Continuous × 1.25"))
        XCTAssertTrue(run.ampacityAssumptionCaption.contains("not applied on this row"))
    }

    func testCandidateTableIncludesSelectedSize() throws {

        let r = try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .dc, supplyVolts: 48, current: 20, oneWayFeet: 50, size: "10", material: .copper
        ))
        XCTAssertTrue(r.candidates.contains { $0.size == "10" })
        XCTAssertGreaterThan(r.candidates.count, 5)
    }
}
