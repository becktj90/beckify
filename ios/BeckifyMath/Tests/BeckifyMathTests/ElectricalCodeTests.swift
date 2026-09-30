import XCTest
@testable import BeckifyMath

final class ElectricalCodeTests: XCTestCase {
    func testDefaultCodeIsNECAndPlannedCodesAreNotSelectable() {
        XCTAssertEqual(ElectricalCode.nec.displayName, "NEC (US)")
        XCTAssertEqual(ElectricalCode.allCases, [.nec, .asnzs])
        XCTAssertEqual(PlannedElectricalCode.allCases.map(\.status), ["Not in this build", "Not in this build", "Not in this build"])
        XCTAssertEqual(ElectricalCode.asnzs.nominalSupply.singlePhaseVolts, 230)
        XCTAssertEqual(ElectricalCode.asnzs.nominalSupply.threePhaseLineVolts, 400)
        XCTAssertEqual(ElectricalCode.asnzs.nominalSupply.frequencyHz, 50)
        XCTAssertEqual(ElectricalCode.nec.nominalSupply.frequencyHz, 60)
    }

    func testLengthUnitFollowsCodeUnlessOverridden() {
        XCTAssertEqual(PreferredUnitSystem.followCode.lengthUnit(for: .nec), .feet)
        XCTAssertEqual(PreferredUnitSystem.followCode.lengthUnit(for: .asnzs), .metres)
        XCTAssertEqual(PreferredUnitSystem.metric.lengthUnit(for: .nec), .metres)
        XCTAssertEqual(PreferredUnitSystem.imperial.lengthUnit(for: .asnzs), .feet)
        XCTAssertEqual(FieldLengthUnit.feet.metres(from: 1), 0.3048, accuracy: 1e-12)
        XCTAssertEqual(FieldLengthUnit.metres.feet(from: 1), 1 / 0.3048, accuracy: 1e-9)
    }

    func testASNZSStubNeverClaimsNativeResults() {
        let ampacity = ElectricalCodeSupport.notice(toolID: "wireAmpacity", code: .asnzs)
        XCTAssertEqual(ampacity?.kind, .necLabeledFallback)
        XCTAssertTrue(ampacity?.title.contains("showing NEC") == true)
        XCTAssertTrue(ampacity?.message.contains("310.16") == true)
        XCTAssertFalse(ampacity?.message.localizedCaseInsensitiveContains("this result is AS/NZS") == true)

        let fill = ElectricalCodeSupport.notice(toolID: "conduitFill", code: .asnzs)
        XCTAssertTrue(fill?.message.contains("Count EGC") == true)
        XCTAssertEqual(fill?.kind, .necLabeledFallback)

        let ground = ElectricalCodeSupport.notice(toolID: "equipmentGround", code: .asnzs)
        XCTAssertEqual(ground?.kind, .necLabeledFallback)
        XCTAssertTrue(ground?.title.contains("showing NEC") == true)
        XCTAssertTrue(ground?.message.contains("250.122") == true)
        XCTAssertTrue(ground?.message.contains("Table 5.1") == true)
        XCTAssertFalse(ground?.message.localizedCaseInsensitiveContains("this result is AS/NZS") == true)
        XCTAssertEqual(ElectricalCodeSupport.notice(toolID: "equipmentGround", code: .nec)?.kind, .activeNative)

        let drop = ElectricalCodeSupport.notice(toolID: "voltageDrop", code: .asnzs)
        XCTAssertEqual(drop?.kind, .activeNative)
        XCTAssertFalse(drop?.title.contains("showing NEC") == true)
        XCTAssertTrue(drop?.message.contains("Table 5.1") == true)
        XCTAssertTrue(drop?.message.contains("3008") == true)

        XCTAssertNil(ElectricalCodeSupport.notice(toolID: "ohmsLaw", code: .asnzs))
        XCTAssertEqual(ElectricalCodeSupport.notice(toolID: "motorFLA", code: .nec)?.showsDetail, false)
    }

    func testTable5_1CopperEarth() {
        let six = ASNZSEarthing.recommend(activeMM2: 6, activeMaterial: .copper)
        XCTAssertEqual(six?.tableCopperMM2, 2.5)
        XCTAssertEqual(six?.separateCopperMM2, 2.5)
        XCTAssertEqual(six?.citation.articleOrTable, "Table 5.1")
        XCTAssertEqual(six?.citation.edition, .asnzs3000)

        XCTAssertEqual(ASNZSEarthing.recommend(activeMM2: 25, activeMaterial: .copper)?.tableCopperMM2, 6)
        XCTAssertEqual(ASNZSEarthing.recommend(activeMM2: 25, activeMaterial: .aluminum)?.tableCopperMM2, 6)
        XCTAssertEqual(ASNZSEarthing.recommend(activeMM2: 16, activeMaterial: .aluminum)?.tableCopperMM2, 4)
        XCTAssertEqual(ASNZSEarthing.recommend(activeMM2: 95, activeMaterial: .copper)?.tableCopperMM2, 25)
        XCTAssertEqual(ASNZSEarthing.recommend(activeMM2: 300, activeMaterial: .copper)?.tableCopperMM2, 120)

        let large = ASNZSEarthing.recommend(activeMM2: 630, activeMaterial: .copper)
        XCTAssertEqual(large?.tableCopperMM2, 120)
        XCTAssertTrue(large?.isTableMinimum == true)
        XCTAssertTrue(large?.notes.joined(separator: " ").contains("5.3.3.1.1") == true || large?.citation.sourceDescription.contains("5.3.3.1.1") == true)

        let small = ASNZSEarthing.recommend(activeMM2: 1, activeMaterial: .copper)
        XCTAssertEqual(small?.tableCopperMM2, 1)
        XCTAssertEqual(small?.separateCopperMM2, 2.5)
        XCTAssertTrue(small?.notes.joined(separator: " ").contains("5.3.3.4") == true)

        XCTAssertNil(ASNZSEarthing.recommend(activeMM2: 6, activeMaterial: .aluminum))
        XCTAssertNil(ASNZSEarthing.recommend(activeMM2: 800, activeMaterial: .copper))
    }

    func testASNZSVoltageDropResistanceMethod() throws {
        let result = try ASNZSVoltageDrop.calculate(ASNZSVoltageDropInput(
            system: .threePhase,
            supplyVolts: 400,
            current: 32,
            oneWayMetres: 40,
            sizeMM2: 6,
            material: .copper,
            parallelRuns: 1,
            targetDropPercent: 5,
            conductorTemperatureC: 75
        ))

        // 6 mm² Cu Class 2: 3.08 Ω/km at 20 °C, × (1 + 0.00393 × 55) at 75 °C.
        let r75 = 3.08 * (1 + 0.00393 * 55)
        let expected = Foundation.sqrt(3) * 32 * 40 * (r75 / 1000)
        XCTAssertEqual(result.resistanceOhmPerKm, r75, accuracy: 1e-9)
        XCTAssertEqual(result.dropVolts, expected, accuracy: 1e-6)
        XCTAssertEqual(result.dropPercent, expected / 400 * 100, accuracy: 1e-6)
        XCTAssertTrue(result.meetsInstallationLimit)
        XCTAssertEqual(result.earth?.separateCopperMM2, 2.5)
        XCTAssertTrue(result.citations.contains { $0.articleOrTable == "Clause 3.6.2" })
        XCTAssertTrue(result.warnings.contains { $0.message.contains("3008") })
        XCTAssertFalse(result.formula.contains("K ×"))
    }

    func testASNZSVoltageDropPicksSmallerSizeForTargetAndIgnoresNECAmpacity() throws {
        let result = try ASNZSVoltageDrop.calculate(ASNZSVoltageDropInput(
            system: .singlePhase,
            supplyVolts: 230,
            current: 20,
            oneWayMetres: 30,
            sizeMM2: 2.5,
            material: .copper,
            targetDropPercent: 3,
            conductorTemperatureC: 75
        ))
        XCTAssertFalse(result.meetsTarget)
        XCTAssertEqual(result.recommendedMM2, 4)
        XCTAssertEqual(result.recommendedEarth?.tableCopperMM2, 2.5)

        let hotter = try ASNZSVoltageDrop.calculate(ASNZSVoltageDropInput(
            system: .singlePhase,
            supplyVolts: 230,
            current: 20,
            oneWayMetres: 30,
            sizeMM2: 2.5,
            material: .copper,
            conductorTemperatureC: 90
        ))
        XCTAssertGreaterThan(hotter.dropVolts, result.dropVolts)
    }

    func testParallelRunsHalveTheDrop() throws {
        let one = try ASNZSVoltageDrop.calculate(ASNZSVoltageDropInput(
            system: .singlePhase, supplyVolts: 230, current: 20, oneWayMetres: 30, sizeMM2: 4, material: .copper
        ))
        let two = try ASNZSVoltageDrop.calculate(ASNZSVoltageDropInput(
            system: .singlePhase, supplyVolts: 230, current: 20, oneWayMetres: 30, sizeMM2: 4, material: .copper, parallelRuns: 2
        ))
        XCTAssertEqual(two.dropVolts * 2, one.dropVolts, accuracy: 1e-9)
    }

    func testReceptacleASNZSPrefersTypeIWithoutChangingNECRankReason() throws {
        let asnzs = try ReceptacleSelector.select(ReceptacleQuery(
            volts: 230,
            phase: .singlePhase2Wire,
            amps: 10,
            electricalCode: .asnzs
        ))
        XCTAssertTrue(asnzs[0].config.code.contains("3112"))
        XCTAssertTrue(asnzs[0].config.code.contains("10 A"))
        XCTAssertTrue(asnzs[0].reasons.contains { $0.contains("AS/NZS 3112") })

        let nec = try ReceptacleSelector.select(ReceptacleQuery(
            volts: 230,
            phase: .singlePhase2Wire,
            amps: 10
        ))
        XCTAssertFalse(nec[0].reasons.contains { $0.contains("AS/NZS 3112") })
    }
}
