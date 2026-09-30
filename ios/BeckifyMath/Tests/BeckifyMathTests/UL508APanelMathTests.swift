import XCTest
@testable import BeckifyMath

final class UL508APanelMathTests: XCTestCase {

    func testFeederFormulaMultiLoad() throws {
        let result = try PanelFeederSizing.size(
            loads: [
                FeederLoadInput(name: "Conveyor", kind: .motor, fullLoadAmps: 28, branchDeviceAmps: 70),
                FeederLoadInput(name: "Pump", kind: .motor, fullLoadAmps: 14, branchDeviceAmps: 40),
                FeederLoadInput(name: "Heater", kind: .heater, fullLoadAmps: 10),
                FeederLoadInput(name: "Controls", kind: .other, fullLoadAmps: 5),
            ],
            conductorAmpacity: 85
        )
        XCTAssertEqual(result.largestMotorFLC, 28)
        XCTAssertEqual(result.remainingMotorFLC, 14)
        XCTAssertEqual(result.heaterFLC, 10)
        XCTAssertEqual(result.otherFLC, 5)
        XCTAssertEqual(result.minimumConductorAmps, 66.5, accuracy: 1e-9)
        XCTAssertEqual(result.largestBranchDeviceAmps, 70)
        XCTAssertFalse(result.branchDeviceIsPlanning)
        XCTAssertEqual(result.overcurrentBasisAmps, 101.5, accuracy: 1e-9)
        XCTAssertEqual(result.conductorAmpacityUsed, 85)
        XCTAssertEqual(result.maximumFeederOCPD, 101.5, accuracy: 1e-9)
        XCTAssertEqual(result.suggestedSize, "4")
    }

    func testFeederPlansBranchDeviceWhenMissing() throws {
        let result = try PanelFeederSizing.size(
            loads: [FeederLoadInput(name: "Fan", kind: .motor, fullLoadAmps: 10)],
            conductorAmpacity: nil
        )
        XCTAssertTrue(result.branchDeviceIsPlanning)
        XCTAssertEqual(result.minimumConductorAmps, 12.5, accuracy: 1e-9)
        XCTAssertEqual(result.largestBranchDeviceAmps, 25)
        XCTAssertEqual(result.overcurrentBasisAmps, 25, accuracy: 1e-9)
        XCTAssertEqual(result.maximumFeederOCPD, 25, accuracy: 1e-9)
    }

    func testTransformerIscMatchesShortCircuitAndUnmarkedZ() throws {
        let unmarked = try PanelTransformerFault.secondaryIsc(
            va: 45_000,
            secondaryVolts: 480,
            percentZ: nil,
            phases: 3
        )
        let viaShortCircuit = try ShortCircuit.transformerSecondary(
            kVA: 45,
            secondaryVolts: 480,
            impedancePercent: 2.1,
            system: .threePhase
        )
        XCTAssertEqual(unmarked.iscAmps, viaShortCircuit.availableFaultAmps, accuracy: 1e-6)
        XCTAssertEqual(unmarked.percentZUsed, 2.1, accuracy: 1e-9)
        XCTAssertTrue(unmarked.assumedUnmarkedZ)
        XCTAssertEqual(unmarked.iscKA, unmarked.iscAmps / 1000, accuracy: 1e-12)

        let lowZ = try PanelTransformerFault.secondaryIsc(
            va: 45_000,
            secondaryVolts: 480,
            percentZ: 1.5,
            phases: 3
        )
        XCTAssertTrue(lowZ.assumedUnmarkedZ)
        XCTAssertEqual(lowZ.percentZUsed, 2.1, accuracy: 1e-9)
        XCTAssertEqual(lowZ.iscAmps, unmarked.iscAmps, accuracy: 1e-6)

        let known = try PanelTransformerFault.secondaryIsc(
            va: 45_000,
            secondaryVolts: 480,
            percentZ: 5.75,
            phases: 3
        )
        XCTAssertFalse(known.assumedUnmarkedZ)
        XCTAssertEqual(known.percentZUsed, 5.75, accuracy: 1e-9)

        let single = try PanelTransformerFault.secondaryIsc(
            va: 5_000,
            secondaryVolts: 120,
            percentZ: 2.1,
            phases: 1
        )
        XCTAssertEqual(single.iscAmps, 5_000 / (120 * 0.021), accuracy: 1e-6)
        XCTAssertFalse(single.assumedUnmarkedZ)
    }

    func testSCCRMinAggregationWithoutCredit() throws {
        let result = try PanelSCCR.aggregate(
            components: [
                SCCRComponent(name: "Feeder breaker", role: .feederProtectiveDevice, kiloamps: 65, volts: 480, source: .marked),
                SCCRComponent(name: "Contactor", role: .loadSideComponent, kiloamps: 5, volts: 480, source: .assumedSB41),
                SCCRComponent(name: "Terminal block", role: .feederComponent, kiloamps: 10, volts: 480, source: .assumedSB41),
            ],
            limit: .none
        )
        XCTAssertEqual(result.panelKA, 5, accuracy: 1e-9)
        XCTAssertEqual(result.limitingNames, ["Contactor"])
        XCTAssertFalse(result.currentLimitApplied)
        XCTAssertEqual(try PanelSCCR.limitingKiloamps([65, 5, 10]), 5)
    }

    func testClassJLetThroughDoesNotRaiseAWeakContactor() throws {
        let looked = try PanelFuseLetThrough.peakKiloamps(fuseClass: .j, amps: 100, prospectiveKiloamps: 100)
        XCTAssertEqual(looked.caseAmps, 100)
        XCTAssertEqual(looked.peakKA, 14, accuracy: 1e-9)
        XCTAssertEqual(looked.columnKA, 100)

        let rounded = try PanelFuseLetThrough.peakKiloamps(fuseClass: .j, amps: 40, prospectiveKiloamps: 50)
        XCTAssertEqual(rounded.caseAmps, 60)
        XCTAssertEqual(rounded.peakKA, 8, accuracy: 1e-9)

        let result = try PanelSCCR.aggregate(
            components: [
                SCCRComponent(name: "Class J", role: .feederProtectiveDevice, kiloamps: 200, volts: 600, source: .marked),
                SCCRComponent(name: "Contactor", role: .loadSideComponent, kiloamps: 5, volts: 480, source: .assumedSB41),
                SCCRComponent(name: "Distribution block", role: .loadSideComponent, kiloamps: 10, volts: 480, source: .assumedSB41),
            ],
            limit: .fuse(fuseClass: .j, amps: 100, prospectiveKA: 100, interruptKA: 200)
        )
        XCTAssertEqual(try XCTUnwrap(result.letThroughKA), 14, accuracy: 1e-9)
        XCTAssertFalse(result.currentLimitApplied)
        XCTAssertEqual(result.panelKA, 5, accuracy: 1e-9)
    }

    func testCurrentLimitRaisesOnlyWhenEveryLoadSideClearsThePeak() throws {
        let result = try PanelSCCR.aggregate(
            components: [
                SCCRComponent(name: "Class J", role: .feederProtectiveDevice, kiloamps: 200, volts: 600, source: .marked),
                SCCRComponent(name: "Branch breaker", role: .branchProtectiveDevice, kiloamps: 65, volts: 480, source: .marked),
                SCCRComponent(name: "Contactor", role: .loadSideComponent, kiloamps: 18, volts: 480, source: .marked),
                SCCRComponent(name: "Overload", role: .loadSideComponent, kiloamps: 25, volts: 480, source: .marked),
            ],
            limit: .fuse(fuseClass: .j, amps: 100, prospectiveKA: 100, interruptKA: 200)
        )
        XCTAssertTrue(result.currentLimitApplied)
        XCTAssertEqual(result.panelKA, 65, accuracy: 1e-9)
        XCTAssertEqual(result.limitingNames, ["Branch breaker"])
        let contactor = try XCTUnwrap(result.paths.first { $0.name == "Contactor" })
        XCTAssertTrue(contactor.raised)
        XCTAssertEqual(contactor.effectiveKA, 100, accuracy: 1e-9)
    }

    func testTransformerRaisesSecondaryOnlyWhenComponentsCoverTheFault() throws {
        let isc = try PanelTransformerFault.secondaryIsc(va: 45_000, secondaryVolts: 480, percentZ: nil, phases: 3)
        XCTAssertLessThan(isc.iscKA, 5)

        let raised = try PanelSCCR.aggregate(
            components: [
                SCCRComponent(name: "Secondary starter", role: .transformerSecondaryComponent, kiloamps: 5, volts: 480, source: .assumedSB41),
            ],
            limit: .transformer(va: 45_000, secondaryVolts: 480, percentZ: nil, phases: 3, primaryInterruptKA: 65)
        )
        XCTAssertTrue(raised.currentLimitApplied)
        XCTAssertEqual(raised.panelKA, 65, accuracy: 1e-9)
        XCTAssertEqual(raised.transformer?.assumedUnmarkedZ, true)

        let stuck = try PanelSCCR.aggregate(
            components: [
                SCCRComponent(name: "Small block", role: .transformerSecondaryComponent, kiloamps: 2, volts: 480, source: .marked),
            ],
            limit: .transformer(va: 45_000, secondaryVolts: 480, percentZ: nil, phases: 3, primaryInterruptKA: 65)
        )
        XCTAssertFalse(stuck.currentLimitApplied)
        XCTAssertEqual(stuck.panelKA, 2, accuracy: 1e-9)
    }

    func testAssumedDefaultsAndGroupTap() throws {
        XCTAssertEqual(SCCRComponentKind.terminalOrPDB.assumedKiloamps, 10)
        XCTAssertEqual(SCCRComponentKind.supplementaryProtector.assumedKiloamps, 0.2)
        XCTAssertEqual(SCCRComponentKind.motorController0to50.assumedKiloamps, 5)
        XCTAssertTrue(SCCRComponentKind.busBar.assumptionNote.contains("SB4.1") || UL508APanelMath.assumedSCCRLabel.contains("SB4.1"))

        let group = try PanelBranchSizing.group(motorFLCs: [10, 8, 6], device: .inverseTimeBreaker)
        XCTAssertEqual(group.rawAmps, 39, accuracy: 1e-9)
        XCTAssertEqual(group.nextStandardAmps, 40)
        XCTAssertEqual(group.tapMinAmps, 4, accuracy: 1e-9)
        XCTAssertEqual(group.motors.map(\.loadSideMinAmps), [12.5, 10, 7.5])
    }

    func testSingleMotorReusesNameplatePercents() throws {
        let branch = try PanelBranchSizing.singleMotor(flc: 14, device: .inverseTimeBreaker)
        let percent = MotorNameplate.scpdPercent(motorType: .squirrelCageOther, device: .inverseTimeBreaker)
        XCTAssertEqual(branch.percent, percent)
        XCTAssertEqual(branch.rawAmps, 14 * percent / 100, accuracy: 1e-9)
        XCTAssertEqual(branch.conductorMinAmps, 17.5, accuracy: 1e-9)
        XCTAssertEqual(branch.overloadPercent, 115)
    }

    func testWashdownWireAndConduitAdvice() {
        let advice = PanelWiringAdvice.recommend(environment: .washdown, circuit: .powerFeeder)
        XCTAssertTrue(advice.preferredRaceways.contains(.lfmc))
        XCTAssertTrue(advice.preferredRaceways.contains(.rmc))
        XCTAssertFalse(advice.preferredRaceways.contains(.emt))
        XCTAssertTrue(advice.avoid.localizedCaseInsensitiveContains("EMT"))
        XCTAssertTrue(advice.wireTypes.joined(separator: " ").localizedCaseInsensitiveContains("THWN-2"))
        XCTAssertTrue(advice.verify.localizedCaseInsensitiveContains("AHJ"))
        XCTAssertEqual(PanelWiringAdvice.crossLinkToolIDs, ["wireAmpacity", "conduitFill", "equipmentGround", "motorFLA"])

        let hazardous = PanelWiringAdvice.recommend(environment: .hazardousPointer, circuit: .powerBranch)
        XCTAssertTrue(hazardous.why.localizedCaseInsensitiveContains("pointer"))
        XCTAssertFalse(hazardous.why.localizedCaseInsensitiveContains("Division 1 design"))
        XCTAssertTrue(hazardous.avoid.localizedCaseInsensitiveContains("not"))
    }

    func testEnclosureAnalogyIsNotAnEquivalence() {
        let type4X = PanelEnclosureGuide.guide(id: "4X")
        XCTAssertEqual(type4X?.environment, .corrosive)
        XCTAssertTrue(type4X?.ipAnalogy.contains("IP66") == true)
        XCTAssertEqual(type4X?.analogyOnly, true)
        XCTAssertTrue(type4X?.ipAnalogy.localizedCaseInsensitiveContains("analogy") == true)
        let hazard = PanelEnclosureGuide.guide(id: "haz")
        XCTAssertTrue(hazard?.notFor.localizedCaseInsensitiveContains("Class") == true)
        XCTAssertFalse(PanelEnclosureGuide.clearancePrompts.joined(separator: " ").contains("110.26(A)"))
    }

    func testConductorColorsAreConventions() {
        let power = PanelConductorColors.roles(in: .powerDistribution)
        XCTAssertTrue(power.contains { $0.id == "y208" && $0.swatches.map(\.name) == ["Black", "Red", "Blue"] })
        XCTAssertTrue(power.contains { $0.id == "y480" && $0.swatches.map(\.name) == ["Brown", "Orange", "Yellow"] })
        XCTAssertTrue(power.contains { $0.id == "highleg" && $0.swatches.contains { $0.name == "Orange" } })
        XCTAssertTrue(power.contains { $0.id == "grounding" && $0.swatches.contains { $0.name == "Green" } })
        XCTAssertTrue(power.contains { $0.id == "grounded" && $0.swatches.contains { $0.name == "White" } })
        XCTAssertTrue(power.contains { $0.id == "corner" })

        let control = PanelConductorColors.roles(in: .controlPanel)
        XCTAssertTrue(control.contains { $0.swatches.contains { $0.name == "Red" } && $0.role.localizedCaseInsensitiveContains("AC") })
        XCTAssertTrue(control.contains { $0.swatches.contains { $0.name == "Blue" } && $0.role.localizedCaseInsensitiveContains("DC") })
        XCTAssertTrue(control.contains { $0.swatches.contains { $0.name == "Yellow" } })
        XCTAssertTrue(control.contains { $0.role.localizedCaseInsensitiveContains("ground") && $0.swatches.contains { $0.name == "Green" } })

        let blob = PanelConductorColors.roles.map(\.authority).joined(separator: " ")
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("convention") || blob.localizedCaseInsensitiveContains("practice"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("mandatory law"))
        XCTAssertTrue(PanelConductorColors.emphasizeIEC(code: .asnzs))
        XCTAssertFalse(PanelConductorColors.emphasizeIEC(code: .nec))
        XCTAssertEqual(PanelConductorColors.roles(in: .iec).count, 3)
    }

    func testControlTransformerBandsAndWireColumn() throws {
        let small = try PanelControlTransformer.plan(va: 500, primaryVolts: 480, secondaryVolts: 120)
        XCTAssertEqual(small.primaryFLA, 500 / 480, accuracy: 1e-9)
        XCTAssertEqual(small.primaryPercent, 500)
        XCTAssertEqual(small.secondaryFLA, 500 / 120, accuracy: 1e-9)
        XCTAssertTrue(small.sccrNote.localizedCaseInsensitiveContains("primary"))
        XCTAssertTrue(small.limitedEnergyNote.localizedCaseInsensitiveContains("Class 2"))

        let mid = try PanelControlTransformer.plan(va: 2000, primaryVolts: 480, secondaryVolts: 120)
        XCTAssertEqual(mid.primaryPercent, 167)

        let large = try PanelControlTransformer.plan(va: 5000, primaryVolts: 480, secondaryVolts: 120)
        XCTAssertEqual(large.primaryPercent, 125)

        let wire = try PanelWireAmpacity.smallest(requiredAmps: 66.5, column: .c75, includeControlSizes: false)
        XCTAssertEqual(wire.size, "4")
        XCTAssertEqual(wire.ampacity, 85)
        XCTAssertFalse(wire.controlOnly)

        let control = try PanelWireAmpacity.smallest(requiredAmps: 6, column: .c60, includeControlSizes: true)
        XCTAssertEqual(control.size, "18")
        XCTAssertTrue(control.controlOnly)

        XCTAssertTrue(PanelNameplate.prompts.contains { $0.id == "sccr" })
        XCTAssertTrue(PanelNameplate.prompts.contains { $0.id == "enclosure" })
        XCTAssertTrue(PanelNameplate.prompts.contains { $0.id == "diagram" })
    }
}
