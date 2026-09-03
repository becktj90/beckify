import XCTest
@testable import BeckifyMath

final class ConduitFillPlanningTests: XCTestCase {
    func testLegacyFour12THHNInThreeQuarterEMT() throws {
        let r = try ConduitFill.calculate(quantity: 4, size: "12", tradeSize: "3/4")
        XCTAssertEqual(r.totalWireArea, 4 * 0.0133, accuracy: 1e-12)
        XCTAssertEqual(r.conduitArea, 0.533, accuracy: 1e-12)
        XCTAssertEqual(r.maxFillPercent, 40)
        XCTAssertEqual(r.actualFillPercent, (4 * 0.0133) / 0.533 * 100, accuracy: 1e-12)
        XCTAssertTrue(r.passes)
        XCTAssertNil(r.suggestedTradeSize)
    }

    func testMixedSizesSumIndividualAreas() throws {
        let input = ConduitFillInput(
            groups: [
                ConductorGroup(quantity: 3, size: "3/0", insulation: .thhnTHWN2, purpose: .phase, countsAsCurrentCarrying: true),
                ConductorGroup(quantity: 1, size: "3/0", insulation: .thhnTHWN2, purpose: .neutral),
                ConductorGroup(quantity: 1, size: "4", insulation: .thhnTHWN2, purpose: .equipmentGround, countsAsCurrentCarrying: false),
                ConductorGroup(quantity: 4, size: "12", insulation: .thhnTHWN2, purpose: .control, countsAsCurrentCarrying: true),
            ],
            raceway: RacewaySelection(type: .emt, tradeSize: "2")
        )
        let r = try ConduitFillPlanning.design(input)
        let expected = 3 * 0.2679 + 0.2679 + 0.0824 + 4 * 0.0133
        XCTAssertEqual(r.totalConductorArea, expected, accuracy: 1e-12)
        XCTAssertEqual(r.physicalConductorCount, 9)
        XCTAssertEqual(r.actualFillPercent, expected / 3.356 * 100, accuracy: 1e-12)
        XCTAssertEqual(r.codeMaximumPercent, 40)
        XCTAssertTrue(r.passesCodeFill)
        XCTAssertEqual(r.currentCarrying.automaticCurrentCarryingCount, 7)
        XCTAssertEqual(r.currentCarrying.unconfirmedNeutralCount, 1)
        XCTAssertTrue(r.currentCarrying.adjustmentReviewMayBeRequired)
        XCTAssertFalse(r.currentCarrying.notes.contains(where: { $0.contains("derating applied") }))
        XCTAssertEqual(r.minimumCompliantRaceway?.tradeSize, "2")
        XCTAssertEqual(r.preferredRaceway?.tradeSize, "2-1/2")
    }

    func testMixedInsulationUsesCorrectTable5Column() throws {
        let r = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [
                    ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2),
                    ConductorGroup(quantity: 1, size: "12", insulation: .xhhw2),
                    ConductorGroup(quantity: 1, size: "12", insulation: .rhhRhw2),
                ],
                raceway: RacewaySelection(type: .imc, tradeSize: "1")
            )
        )
        XCTAssertEqual(r.totalConductorArea, 0.0133 + 0.0181 + 0.0353, accuracy: 1e-12)
        XCTAssertEqual(r.conductorBreakdown[0].unitArea, 0.0133, accuracy: 1e-12)
        XCTAssertEqual(r.conductorBreakdown[1].unitArea, 0.0181, accuracy: 1e-12)
        XCTAssertEqual(r.conductorBreakdown[2].unitArea, 0.0353, accuracy: 1e-12)
        XCTAssertEqual(r.racewayArea, 0.959, accuracy: 1e-12)
    }

    func testCopperAndAluminumShareTable5Area() throws {
        let cu = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 1, size: "4/0", insulation: .thhnTHWN2, material: .copper)],
                raceway: RacewaySelection(type: .rmc, tradeSize: "1")
            )
        )
        let al = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 1, size: "4/0", insulation: .thhnTHWN2, material: .aluminum)],
                raceway: RacewaySelection(type: .rmc, tradeSize: "1")
            )
        )
        XCTAssertEqual(cu.totalConductorArea, 0.3237, accuracy: 1e-12)
        XCTAssertEqual(al.totalConductorArea, 0.3237, accuracy: 1e-12)
        XCTAssertEqual(cu.conductorBreakdown[0].source.table, al.conductorBreakdown[0].source.table)
    }

    func testEGCCountsTowardPhysicalFillNotCCC() throws {
        let r = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [
                    ConductorGroup(quantity: 2, size: "12", insulation: .thhnTHWN2, purpose: .phase, countsAsCurrentCarrying: true),
                    ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2, purpose: .equipmentGround, countsAsCurrentCarrying: false),
                ],
                raceway: RacewaySelection(type: .emt, tradeSize: "1/2")
            )
        )
        XCTAssertEqual(r.physicalConductorCount, 3)
        XCTAssertEqual(r.totalConductorArea, 3 * 0.0133, accuracy: 1e-12)
        XCTAssertEqual(r.currentCarrying.automaticCurrentCarryingCount, 2)
        XCTAssertEqual(r.codeMaximumPercent, 40)
        XCTAssertTrue(r.recommendations.contains(where: { $0.kind == .egcCountsTowardFill }))
    }

    func testOneTwoAndThreePlusLimits() throws {
        let one = try ConduitFillPlanning.design(singleTHHN(qty: 1, size: "12", trade: "1/2"))
        let two = try ConduitFillPlanning.design(singleTHHN(qty: 2, size: "12", trade: "1/2"))
        let three = try ConduitFillPlanning.design(singleTHHN(qty: 3, size: "12", trade: "1/2"))
        XCTAssertEqual(one.codeMaximumPercent, 53)
        XCTAssertEqual(two.codeMaximumPercent, 31)
        XCTAssertEqual(three.codeMaximumPercent, 40)
    }

    func testQualifyingNippleUses60Percent() throws {
        let r = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 6, size: "12", insulation: .thhnTHWN2)],
                raceway: RacewaySelection(type: .emt, tradeSize: "1/2", nippleLengthInches: 24),
                installation: InstallationConditions(runKind: .nipple)
            )
        )
        XCTAssertTrue(r.qualifyingNipple)
        XCTAssertEqual(r.codeMaximumPercent, 60)
        XCTAssertEqual(r.codeMaximumArea, 0.304 * 0.60, accuracy: 1e-12)
    }

    func testNonqualifyingNippleKeepsTable1() throws {
        let missing = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 6, size: "12", insulation: .thhnTHWN2)],
                raceway: RacewaySelection(type: .emt, tradeSize: "1/2"),
                installation: InstallationConditions(runKind: .nipple)
            )
        )
        XCTAssertFalse(missing.qualifyingNipple)
        XCTAssertEqual(missing.codeMaximumPercent, 40)

        let long = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 6, size: "12", insulation: .thhnTHWN2)],
                raceway: RacewaySelection(type: .emt, tradeSize: "1/2", nippleLengthInches: 24.1),
                installation: InstallationConditions(runKind: .nipple)
            )
        )
        XCTAssertFalse(long.qualifyingNipple)
        XCTAssertEqual(long.codeMaximumPercent, 40)
    }

    func testExactPassFailBoundary() throws {
        let limit = 0.304 * 0.53
        let pass = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 1, size: "12", insulation: .custom, customAreaSquareInches: limit)],
                raceway: RacewaySelection(type: .emt, tradeSize: "1/2")
            )
        )
        XCTAssertTrue(pass.passesCodeFill)
        XCTAssertEqual(pass.actualFillPercent, 53, accuracy: 1e-9)

        let fail = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 1, size: "12", insulation: .custom, customAreaSquareInches: limit + 0.001)],
                raceway: RacewaySelection(type: .emt, tradeSize: "1/2")
            )
        )
        XCTAssertFalse(fail.passesCodeFill)
        XCTAssertNotNil(fail.minimumCompliantRaceway)
    }

    func testMinimumAndPreferredRecommendations() throws {
        let r = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 1, size: "4/0", insulation: .thhnTHWN2)],
                raceway: RacewaySelection(type: .emt, tradeSize: "1/2")
            )
        )
        XCTAssertFalse(r.passesCodeFill)
        XCTAssertEqual(r.minimumCompliantRaceway?.tradeSize, "1")
        XCTAssertEqual(0.533 * 0.53, 0.28249, accuracy: 1e-12)
        XCTAssertTrue(0.3237 > 0.533 * 0.53)
        XCTAssertTrue(0.3237 <= 0.864 * 0.53)
        XCTAssertEqual(r.recommendations.first?.kind, .increaseForCode)
        XCTAssertTrue(r.recommendations[0].text.contains("1\""))
    }

    func testPreferredIsNotLabeledAsCode() throws {
        let r = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [
                    ConductorGroup(quantity: 3, size: "3/0", insulation: .thhnTHWN2, purpose: .phase, countsAsCurrentCarrying: true),
                    ConductorGroup(quantity: 1, size: "3/0", insulation: .thhnTHWN2, purpose: .neutral),
                    ConductorGroup(quantity: 1, size: "4", insulation: .thhnTHWN2, purpose: .equipmentGround, countsAsCurrentCarrying: false),
                    ConductorGroup(quantity: 4, size: "12", insulation: .thhnTHWN2, purpose: .control, countsAsCurrentCarrying: true),
                ],
                raceway: RacewaySelection(type: .emt, tradeSize: "2")
            )
        )
        XCTAssertTrue(r.passesCodeFill)
        XCTAssertEqual(r.preferredRaceway?.tradeSize, "2-1/2")
        XCTAssertTrue(r.recommendations.contains(where: {
            $0.kind == .increaseForPreferred && $0.text.contains("not an NEC requirement")
        }))
    }

    func testNoRacewayLargeEnough() throws {
        let r = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 40, size: "1000", insulation: .rhhRhw2)],
                raceway: RacewaySelection(type: .ent, tradeSize: "2")
            )
        )
        XCTAssertFalse(r.passesCodeFill)
        XCTAssertNil(r.minimumCompliantRaceway)
        XCTAssertEqual(r.recommendations.first?.kind, .noRacewayLargeEnough)
    }

    func testInvalidQuantity() {
        XCTAssertThrowsError(
            try ConduitFillPlanning.design(singleTHHN(qty: 0, size: "12", trade: "3/4"))
        ) { error in
            XCTAssertEqual(error as? CalcError, .nonPositive("Conductor quantity in row 1"))
        }
        XCTAssertThrowsError(try ConduitFill.calculate(quantity: 0, size: "12", tradeSize: "3/4"))
    }

    func testMissingDimensionalDataDoesNotSubstituteTHHN() {
        XCTAssertThrowsError(
            try ConduitFillPlanning.design(
                ConduitFillInput(
                    groups: [ConductorGroup(quantity: 1, size: "4/0", insulation: .compactAluminum)],
                    raceway: RacewaySelection(type: .emt, tradeSize: "2")
                )
            )
        ) { error in
            guard case .notListed(let message) = error as? CalcError else {
                return XCTFail("expected notListed")
            }
            XCTAssertTrue(message.contains("THHN area is not substituted"))
            XCTAssertFalse(message.contains("0.3237"))
        }
        XCTAssertThrowsError(
            try ConduitFillPlanning.design(
                ConduitFillInput(
                    groups: [ConductorGroup(quantity: 1, size: "4", insulation: .bare)],
                    raceway: RacewaySelection(type: .emt, tradeSize: "1")
                )
            )
        )
    }

    func testCustomAreaAndOD() throws {
        let area = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 2, size: "2", insulation: .custom, customAreaSquareInches: 0.20)],
                raceway: RacewaySelection(type: .pvc40, tradeSize: "1")
            )
        )
        XCTAssertEqual(area.totalConductorArea, 0.40, accuracy: 1e-12)
        XCTAssertTrue(area.conductorBreakdown[0].usedCustomDimension)

        let od = 0.5
        let fromOD = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 1, size: "2", insulation: .custom, customOutsideDiameterInches: od)],
                raceway: RacewaySelection(type: .pvc40, tradeSize: "1")
            )
        )
        XCTAssertEqual(fromOD.totalConductorArea, Double.pi * 0.25 * 0.25, accuracy: 1e-12)
    }

    func testOverflowAndNonFiniteInputs() {
        XCTAssertThrowsError(
            try ConduitFillPlanning.design(
                ConduitFillInput(
                    groups: [ConductorGroup(quantity: 1, size: "12", insulation: .custom, customAreaSquareInches: .infinity)],
                    raceway: RacewaySelection(type: .emt, tradeSize: "1")
                )
            )
        )
        XCTAssertThrowsError(
            try ConduitFillPlanning.design(
                ConduitFillInput(
                    groups: [ConductorGroup(quantity: 1, size: "12", insulation: .custom, customAreaSquareInches: .nan)],
                    raceway: RacewaySelection(type: .emt, tradeSize: "1")
                )
            )
        )
        XCTAssertThrowsError(
            try ConduitFillPlanning.design(
                ConduitFillInput(
                    groups: [ConductorGroup(quantity: 2, size: "12", insulation: .custom, customAreaSquareInches: .greatestFiniteMagnitude)],
                    raceway: RacewaySelection(type: .rmc, tradeSize: "6")
                )
            )
        )
    }

    func testUnknownTradeSizeForType() {
        XCTAssertThrowsError(
            try ConduitFillPlanning.design(
                ConduitFillInput(
                    groups: [ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2)],
                    raceway: RacewaySelection(type: .ent, tradeSize: "6")
                )
            )
        ) { error in
            guard case .notListed(let message) = error as? CalcError else {
                return XCTFail("expected notListed")
            }
            XCTAssertTrue(message.contains("ENT"))
        }
    }

    func testPullPlanningLongRunAndBends() throws {
        let r = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [ConductorGroup(quantity: 4, size: "4/0", insulation: .thhnTHWN2)],
                raceway: RacewaySelection(type: .emt, tradeSize: "2"),
                route: PullRoute(lengthFeet: 220, totalBendDegrees: 400, bendCount: 5, verticalRiseFeet: 20, pullPointCount: 0)
            )
        )
        XCTAssertEqual(r.pullPlanning.status, .engineeringReview)
        XCTAssertTrue(r.pullPlanning.factors.contains(where: { $0.detail.contains("220") }))
        XCTAssertTrue(r.pullPlanning.factors.contains(where: { $0.detail.contains("400") }))
        XCTAssertFalse(r.pullPlanning.tensionCalculated)
        XCTAssertTrue(r.recommendations.contains(where: { $0.kind == .addPullPoint }))
        XCTAssertTrue(r.recommendations.contains(where: { $0.kind == .confirmBendLimit }))
        XCTAssertTrue(r.recommendations.contains(where: { $0.kind == .verifyTension }))
        let kinds = r.recommendations.map(\.kind.sortOrder)
        XCTAssertEqual(kinds, kinds.sorted())
    }

    func testSavedJobBackwardCompatibility() throws {
        let legacy = try ConduitFillJobSnapshot.decode(from: ["n": "4", "size": "12", "emt": "3/4"])
        XCTAssertEqual(legacy.version, 1)
        XCTAssertEqual(legacy.input.groups.count, 1)
        XCTAssertEqual(legacy.input.groups[0].quantity, 4)
        XCTAssertEqual(legacy.input.groups[0].size, "12")
        XCTAssertEqual(legacy.input.groups[0].insulation, .thhnTHWN2)
        XCTAssertEqual(legacy.input.raceway.type, .emt)
        XCTAssertEqual(legacy.input.raceway.tradeSize, "3/4")

        let designed = try ConduitFillPlanning.design(legacy.input)
        let wrapper = try ConduitFill.calculate(quantity: 4, size: "12", tradeSize: "3/4")
        XCTAssertEqual(designed.actualFillPercent, wrapper.actualFillPercent, accuracy: 1e-12)

        let encoded = ConduitFillJobSnapshot(input: legacy.input).encodeInputs()
        let roundTrip = try ConduitFillJobSnapshot.decode(from: encoded)
        XCTAssertEqual(roundTrip.version, 2)
        XCTAssertEqual(roundTrip.input.groups[0].quantity, 4)
    }

    func testCCCOverrideDoesNotChangeFill() throws {
        let base = ConduitFillInput(
            groups: [
                ConductorGroup(quantity: 3, size: "12", insulation: .thhnTHWN2, purpose: .phase, countsAsCurrentCarrying: true),
                ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2, purpose: .neutral, countsAsCurrentCarrying: true),
            ],
            raceway: RacewaySelection(type: .fmc, tradeSize: "3/4"),
            preferences: ConduitFillPreferences(currentCarryingOverride: 3)
        )
        let r = try ConduitFillPlanning.design(base)
        XCTAssertEqual(r.physicalConductorCount, 4)
        XCTAssertEqual(r.currentCarrying.automaticCurrentCarryingCount, 4)
        XCTAssertEqual(r.currentCarrying.reportedCount, 3)
        XCTAssertEqual(r.totalConductorArea, 4 * 0.0133, accuracy: 1e-12)
        XCTAssertFalse(r.currentCarrying.adjustmentReviewMayBeRequired)
    }

    func testJammingUnavailableForMixedSizes() throws {
        let r = try ConduitFillPlanning.design(
            ConduitFillInput(
                groups: [
                    ConductorGroup(quantity: 2, size: "4/0", insulation: .thhnTHWN2),
                    ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2),
                ],
                raceway: RacewaySelection(type: .emt, tradeSize: "2")
            )
        )
        if case .unavailable(let reason) = r.pullPlanning.jamming {
            XCTAssertTrue(reason.contains("Mixed"))
        } else {
            XCTFail("expected unavailable jamming screen")
        }
    }

    func testThreeSameConductorsProduceJamRatio() throws {
        let r = try ConduitFillPlanning.design(singleTHHN(qty: 3, size: "4/0", trade: "2"))
        if case .screened(let ratio, _, let id, let od) = r.pullPlanning.jamming {
            let expectedOD = 2 * (0.3237 / Double.pi).squareRoot()
            let expectedID = 2 * (3.356 / Double.pi).squareRoot()
            XCTAssertEqual(od, expectedOD, accuracy: 1e-9)
            XCTAssertEqual(id, expectedID, accuracy: 1e-9)
            XCTAssertEqual(ratio, expectedID / expectedOD, accuracy: 1e-9)
        } else {
            XCTFail("expected screened jam ratio")
        }
    }

    func testPVC80HasSmallerAreaThanPVC40() {
        XCTAssertLessThan(RacewayType.pvc80.area(for: "2") ?? 0, RacewayType.pvc40.area(for: "2") ?? 0)
        XCTAssertEqual(RacewayType.emt.metricDesignator(for: "1-1/4"), "35")
    }

    private func singleTHHN(qty: Int, size: String, trade: String) -> ConduitFillInput {
        ConduitFillInput(
            groups: [ConductorGroup(quantity: qty, size: size, insulation: .thhnTHWN2)],
            raceway: RacewaySelection(type: .emt, tradeSize: trade)
        )
    }
}
