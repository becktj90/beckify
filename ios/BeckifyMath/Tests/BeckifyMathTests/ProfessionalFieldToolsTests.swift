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

    func testRejectsBlankCurrent() {
        XCTAssertThrowsError(try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .singlePhase, supplyVolts: 120, current: .nan, oneWayFeet: 100, size: "12", material: .copper
        )))
    }

    func testCandidateTableIncludesSelectedSize() throws {
        let r = try VoltageDropSizing.calculate(VoltageDropSizingInput(
            system: .dc, supplyVolts: 48, current: 20, oneWayFeet: 50, size: "10", material: .copper
        ))
        XCTAssertTrue(r.candidates.contains { $0.size == "10" })
        XCTAssertGreaterThan(r.candidates.count, 5)
    }
}
