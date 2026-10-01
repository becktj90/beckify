import XCTest
@testable import BeckifyMath

final class ConductorCostTests: XCTestCase {
    func testRanksByModeledFirstCost() throws {
        let result = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 150,
            loadUnit: .amps,
            powerFactor: 0.9,
            material: .copper,
            insulation: .c90,
            termination: .c75,
            ambientC: 30,
            currentCarryingCount: 3,
            continuousLoad: true,
            oneWayFeet: 250,
            targetDropPercent: 3,
            maxParallelRuns: 4
        ))

        XCTAssertGreaterThan(result.options.count, 1)
        XCTAssertEqual(result.loadAmps, 150, accuracy: 1e-9)
        XCTAssertEqual(result.designCurrent, 187.5, accuracy: 1e-9)

        let costs = result.options.map(\.firstCost)
        XCTAssertEqual(costs, costs.sorted())
        XCTAssertEqual(result.recommended.firstCost, result.options[0].firstCost, accuracy: 1e-9)
        XCTAssertTrue(result.options.allSatisfy(\.ampacityOK))
        XCTAssertTrue(result.options.allSatisfy(\.meetsVoltageDrop))
        XCTAssertFalse(result.modeledEnergy)
        XCTAssertTrue(result.priceSource.contains("planning"))
    }

    func testUserKftOverrideChangesRankingAgainstBook() throws {
        let book = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 200,
            loadUnit: .amps,
            material: .copper,
            insulation: .c90,
            termination: .c75,
            continuousLoad: true,
            oneWayFeet: 400,
            targetDropPercent: 3,
            maxParallelRuns: 4
        ))

        // A very high uniform $/kft still ranks by conductor-feet × cores × runs,
        // so the cheapest first-cost option must still be first.
        let override = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 200,
            loadUnit: .amps,
            material: .copper,
            insulation: .c90,
            termination: .c75,
            continuousLoad: true,
            oneWayFeet: 400,
            targetDropPercent: 3,
            maxParallelRuns: 4,
            dollarsPerKft: 12_000
        ))

        XCTAssertTrue(override.recommended.usedUserPrice)
        XCTAssertEqual(override.recommended.dollarsPerKftUsed, 12_000, accuracy: 1e-9)
        XCTAssertFalse(book.recommended.usedUserPrice)
        XCTAssertEqual(override.options.map(\.firstCost), override.options.map(\.firstCost).sorted())
        XCTAssertEqual(
            override.recommended.firstCost,
            12.0 * 400 * Double(override.recommended.insulatedCores) * Double(override.recommended.parallelRuns),
            accuracy: 1e-6
        )
    }

    func testParallelsOnlyForOneAughtAndLarger() throws {
        let result = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 400,
            loadUnit: .amps,
            material: .copper,
            insulation: .c90,
            termination: .c75,
            continuousLoad: true,
            oneWayFeet: 200,
            targetDropPercent: 5,
            maxParallelRuns: 3
        ))

        let minCM = NECTables.circularMils["1/0"] ?? 105_600
        for option in result.options where option.parallelRuns > 1 {
            let cm = NECTables.circularMils[option.size] ?? 0
            XCTAssertGreaterThanOrEqual(cm, minCM, "\(option.label) should not parallel below 1/0")
        }
        XCTAssertTrue(result.options.contains { $0.parallelRuns > 1 })
    }

    func testOptionalI2RLifecycleIsAttachedAndUsesOperatingCurrent() throws {
        let result = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 150,
            loadUnit: .amps,
            material: .copper,
            insulation: .c90,
            termination: .c75,
            continuousLoad: true,
            oneWayFeet: 250,
            targetDropPercent: 3,
            maxParallelRuns: 2,
            dollarsPerKwh: 0.12,
            hoursPerYear: 4000
        ))

        XCTAssertTrue(result.modeledEnergy)
        let pick = result.recommended
        XCTAssertNotNil(pick.i2rWatts)
        XCTAssertNotNil(pick.annualEnergyCost)
        XCTAssertNotNil(pick.lifecycleCost)
        let expectedI2R = ConductorCost.i2rWatts(
            current: 150,
            size: pick.size,
            material: .copper,
            oneWayFeet: 250,
            runs: pick.parallelRuns,
            system: .threePhase
        )
        XCTAssertEqual(pick.i2rWatts ?? -1, expectedI2R ?? -2, accuracy: 1e-6)
        // Continuous 125% must not inflate I²R — operating current is 150 A.
        let designBased = ConductorCost.i2rWatts(
            current: 187.5,
            size: pick.size,
            material: .copper,
            oneWayFeet: 250,
            runs: pick.parallelRuns,
            system: .threePhase
        )
        XCTAssertLessThan(pick.i2rWatts ?? .infinity, designBased ?? 0)
        XCTAssertEqual(pick.annualEnergyCost ?? 0, (pick.i2rWatts ?? 0) / 1000 * 0.12 * 4000, accuracy: 1e-6)
        XCTAssertEqual(pick.lifecycleCost ?? 0, pick.firstCost + (pick.annualEnergyCost ?? 0), accuracy: 1e-6)
    }

    func testKVALoadAndHandoffSeed() throws {
        let result = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 100,
            loadUnit: .kva,
            material: .copper,
            oneWayFeet: 150,
            targetDropPercent: 3,
            maxParallelRuns: 2
        ))
        let expectedI = 100_000 / (Foundation.sqrt(3.0) * 480)
        XCTAssertEqual(result.loadAmps, expectedI, accuracy: 1e-9)
        XCTAssertEqual(result.currentBasis, "I = kVA×1000 / (√3 × V)")

        let seed = result.seed
        XCTAssertEqual(seed.sourceToolID, "conductorCost")
        XCTAssertEqual(seed.size, result.recommended.size)
        XCTAssertEqual(seed.parallelRuns, result.recommended.parallelRuns)
        XCTAssertEqual(seed.loadAmps, result.loadAmps, accuracy: 1e-9)
        XCTAssertEqual(seed.material, .copper)
        XCTAssertNotNil(result.recommended.suggestedEMT)
    }

    func testImpossibleVDLimitThrows() {
        XCTAssertThrowsError(try ConductorCost.optimize(ConductorCostInput(
            system: .singlePhase,
            supplyVolts: 120,
            loadValue: 200,
            loadUnit: .amps,
            material: .copper,
            oneWayFeet: 2000,
            targetDropPercent: 0.1,
            maxParallelRuns: 1
        ))) { error in
            guard let calc = error as? CalcError else {
                return XCTFail("expected CalcError, got \(error)")
            }
            guard case .notListed(let message) = calc else {
                return XCTFail("expected notListed, got \(calc)")
            }
            XCTAssertTrue(message.contains("voltage-drop"))
        }
    }

    func testDefaultBookMatchesWebsitePlanningAllowance() {
        XCTAssertEqual(ConductorCost.planningPricePerFoot(size: "4/0", material: .copper), 5.75)
        XCTAssertEqual(ConductorCost.planningDollarsPerKft(size: "4/0", material: .copper), 5750)
        XCTAssertEqual(ConductorCost.planningPricePerFoot(size: "1/0", material: .aluminum), 0.88)
        XCTAssertNil(ConductorCost.planningPricePerFoot(size: "14", material: .aluminum))
    }


    func testIncludeEGCAddsTable250_122CostAndFill() throws {
        let without = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 150,
            loadUnit: .amps,
            material: .copper,
            continuousLoad: true,
            oneWayFeet: 250,
            targetDropPercent: 3,
            maxParallelRuns: 2,
            includeEGC: false
        ))
        let with = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 150,
            loadUnit: .amps,
            material: .copper,
            continuousLoad: true,
            oneWayFeet: 250,
            targetDropPercent: 3,
            maxParallelRuns: 2,
            includeEGC: true,
            egcMaterial: .copper
        ))

        XCTAssertFalse(without.includeEGC)
        XCTAssertNil(without.equipmentGrounding)
        XCTAssertTrue(with.includeEGC)
        XCTAssertNotNil(with.equipmentGrounding)
        XCTAssertTrue(with.recommended.includedEGC)
        XCTAssertGreaterThan(with.recommended.egcCost, 0)
        XCTAssertEqual(
            with.recommended.firstCost,
            with.recommended.phaseCost + with.recommended.egcCost,
            accuracy: 1e-6
        )
        XCTAssertEqual(with.recommended.conductorsPerRun, with.recommended.insulatedCores + 1)
        XCTAssertTrue(with.recommended.typeString.contains("EGC"))
        XCTAssertTrue(with.citations.contains(where: { $0.articleOrTable == "Table 250.122" }))
    }

    func testPerSizePriceOverrideBeatsBookAndUniform() throws {
        let book = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 150,
            loadUnit: .amps,
            material: .copper,
            continuousLoad: true,
            oneWayFeet: 250,
            targetDropPercent: 3,
            maxParallelRuns: 1
        ))
        let pickSize = book.recommended.size
        let override = try ConductorCost.optimize(ConductorCostInput(
            system: .threePhase,
            supplyVolts: 480,
            loadValue: 150,
            loadUnit: .amps,
            material: .copper,
            continuousLoad: true,
            oneWayFeet: 250,
            targetDropPercent: 3,
            maxParallelRuns: 1,
            dollarsPerKft: 9_999,
            priceOverridesBySize: [pickSize: 1_000]
        ))
        let match = override.options.first { $0.size == pickSize && $0.parallelRuns == book.recommended.parallelRuns }
        let matched = try XCTUnwrap(match)
        XCTAssertEqual(matched.dollarsPerKftUsed, 1_000, accuracy: 1e-9)
        XCTAssertEqual(matched.priceSourceLabel, "Line override")
        XCTAssertTrue(matched.usedUserPrice)

        let resolved = try XCTUnwrap(ConductorCost.resolvedDollarsPerKft(
            size: "4/0",
            material: .copper,
            uniformDollarsPerKft: 8000,
            overridesBySize: ["4/0": 1234]
        ))
        XCTAssertEqual(resolved.dollarsPerKft, 1234, accuracy: 1e-9)
        XCTAssertEqual(resolved.source, .lineOverride)

        let uniform = try XCTUnwrap(ConductorCost.resolvedDollarsPerKft(
            size: "4/0",
            material: .copper,
            uniformDollarsPerKft: 8000,
            overridesBySize: [:]
        ))
        XCTAssertEqual(uniform.dollarsPerKft, 8000, accuracy: 1e-9)
        XCTAssertEqual(uniform.source, .uniform)

        let defaultBook = try XCTUnwrap(ConductorCost.resolvedDollarsPerKft(
            size: "4/0",
            material: .copper,
            uniformDollarsPerKft: nil,
            overridesBySize: [:]
        ))
        XCTAssertEqual(defaultBook.dollarsPerKft, 5750, accuracy: 1e-9)
        XCTAssertEqual(defaultBook.source, .book)
    }

    func testIncludeEGCIgnoredForDC() throws {
        let result = try ConductorCost.optimize(ConductorCostInput(
            system: .dc,
            supplyVolts: 48,
            loadValue: 40,
            loadUnit: .amps,
            material: .copper,
            continuousLoad: false,
            oneWayFeet: 50,
            targetDropPercent: 5,
            maxParallelRuns: 1,
            construction: .twoPlusE,
            includeEGC: true
        ))
        XCTAssertFalse(result.includeEGC)
        XCTAssertNil(result.equipmentGrounding)
        XCTAssertFalse(result.recommended.includedEGC)
        XCTAssertEqual(result.recommended.egcCost, 0, accuracy: 1e-9)
    }
}
