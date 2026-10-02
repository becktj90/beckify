import XCTest
@testable import BeckifyMath

final class TapChangerTests: XCTestCase {
    func testNominalTapWhenSecondaryIsAlready480() throws {
        let r = try TapChanger.solve(measuredSecondaryVolts: 480, currentTapPercent: 0)
        XCTAssertEqual(r.nominalRatio, 23000 / 480, accuracy: 1e-9)
        XCTAssertEqual(r.impliedPrimaryVolts, 23000, accuracy: 1e-6)
        XCTAssertEqual(r.recommendedTapPercent, 0, accuracy: 1e-9)
        XCTAssertEqual(r.positions.count, 5)
        XCTAssertEqual(r.positions.filter(\.isRecommended).count, 1)
    }

    func testLowSecondaryRecommendsRaiseTapTowardNominal() throws {
        // Measured 456 V on the 0% tap ⇒ implied primary low; a −5% tap
        // (more primary turns) raises secondary toward 480.
        let r = try TapChanger.solve(measuredSecondaryVolts: 456, currentTapPercent: 0)
        XCTAssertEqual(r.recommendedTapPercent, -5, accuracy: 1e-9)
        let rec = r.positions.first { $0.isRecommended }
        XCTAssertEqual(rec?.expectedSecondaryVolts ?? 0, 480, accuracy: 0.5)
    }

    func testRejectsNonPositiveMeasuredVoltage() {
        XCTAssertThrowsError(try TapChanger.solve(measuredSecondaryVolts: 0, currentTapPercent: 0))
        XCTAssertThrowsError(try TapChanger.solve(measuredSecondaryVolts: .nan, currentTapPercent: 0))
    }
}

final class HarmonicsTHDTests: XCTestCase {
    func testKnownSquareishOddHarmonics() throws {
        // I1=100, I3=33.3, I5=20 → THD = √(33.3²+20²)/100 × 100 ≈ 38.85%
        let r = try HarmonicsTHD.calculate(
            fundamentalAmps: 100,
            harmonics: [
                HarmonicComponent(order: 3, amps: 33.3),
                HarmonicComponent(order: 5, amps: 20),
            ]
        )
        XCTAssertEqual(r.thdPercent, 38.849, accuracy: 0.02)
        XCTAssertEqual(r.dominantOrder, 3)
        XCTAssertTrue(r.status.contains("HIGH"))
        XCTAssertTrue(r.mitigationHint.lowercased().contains("zero-sequence") || r.mitigationHint.lowercased().contains("active"))
    }

    func testAcceptableTHDBand() throws {
        let r = try HarmonicsTHD.calculate(
            fundamentalAmps: 100,
            harmonics: [HarmonicComponent(order: 5, amps: 3)]
        )
        XCTAssertEqual(r.thdPercent, 3, accuracy: 1e-9)
        XCTAssertTrue(r.status.contains("ACCEPTABLE"))
    }

    func testRejectsNonPositiveFundamentalAndNegativeHarmonic() {
        XCTAssertThrowsError(try HarmonicsTHD.calculate(fundamentalAmps: 0, harmonics: []))
        XCTAssertThrowsError(try HarmonicsTHD.calculate(
            fundamentalAmps: 10,
            harmonics: [HarmonicComponent(order: 5, amps: -1)]
        ))
    }
}

final class UPSSizingTests: XCTestCase {
    func testWebsiteStyleExample() throws {
        // 10 kW, PF 0.9, 15 min, 92% eff, 48 V DC
        let r = try UPSSizing.size(
            loadKW: 10,
            powerFactor: 0.9,
            runtimeMinutes: 15,
            efficiency: 0.92,
            dcBusVolts: 48
        )
        XCTAssertEqual(r.loadKVA, 10 / 0.9, accuracy: 1e-9)
        XCTAssertEqual(r.designKVA, (10 / 0.9) * 1.25, accuracy: 1e-9)
        XCTAssertEqual(r.batteryWattHours, (10 * 1000 / 0.92) * 0.25, accuracy: 1e-6)
        XCTAssertEqual(r.batteryAmpHours, r.batteryWattHours / 48, accuracy: 1e-9)
        XCTAssertEqual(r.recommendedKVA, 15, accuracy: 1e-9)
    }

    func testRejectsPFAboveOne() {
        XCTAssertThrowsError(try UPSSizing.size(
            loadKW: 5, powerFactor: 1.2, runtimeMinutes: 10, efficiency: 0.9, dcBusVolts: 48
        ))
    }
}

final class MotorNameplateTests: XCTestCase {
    func testSF115Uses125PercentOverload() throws {
        let r = try MotorNameplate.analyze(
            fla: 27,
            phases: 3,
            horsepower: 10,
            volts: 460,
            serviceFactor: 1.15,
            motorType: .squirrelCageOther,
            device: .inverseTimeBreaker,
            codeLetter: "G"
        )
        XCTAssertEqual(r.overload.percent, 125, accuracy: 1e-9)
        XCTAssertEqual(r.overload.amps, 27 * 1.25, accuracy: 1e-9)
        XCTAssertEqual(r.conductorRequiredAmps, 14 * 1.25, accuracy: 1e-9)
        XCTAssertEqual(r.tableFullLoadAmps, 14, accuracy: 1e-9)
        XCTAssertEqual(r.scpd.rawAmps, 14 * 2.5, accuracy: 1e-9)
        XCTAssertEqual(r.scpd.percent, 250, accuracy: 1e-9)
        XCTAssertNotNil(r.lockedRotor)
        XCTAssertEqual(r.lockedRotor?.letter, "G")
    }

    func testNameplateAndTableCurrentHaveSeparatePurposes() throws {
        let r = try MotorNameplate.analyze(fla: 22, phases: 3, horsepower: 20, volts: 480, serviceFactor: 1.15)
        XCTAssertEqual(r.overload.amps, 27.5, accuracy: 1e-9)
        XCTAssertEqual(r.tableFullLoadAmps, 27, accuracy: 1e-9)
        XCTAssertEqual(r.conductorRequiredAmps, 33.75, accuracy: 1e-9)
        XCTAssertEqual(r.scpd.rawAmps, 67.5, accuracy: 1e-9)
    }

    func testUnsupportedRatingsRequireReviewedTableCurrent() throws {
        XCTAssertThrowsError(try MotorNameplate.analyze(fla: 22, phases: 3))
        XCTAssertThrowsError(try MotorNameplate.analyze(fla: 22, phases: 3, horsepower: 19, volts: 460))
        XCTAssertThrowsError(try MotorNameplate.analyze(fla: 22, phases: 3, horsepower: 20, volts: 1_000))
        XCTAssertThrowsError(try MotorNameplate.analyze(fla: 22, phases: 3, horsepower: 20, volts: 460, motorType: .synchronous))
        let r = try MotorNameplate.analyze(fla: 22, phases: 3, tableFullLoadAmps: 30)
        XCTAssertEqual(r.conductorRequiredAmps, 37.5, accuracy: 1e-9)
        XCTAssertThrowsError(try MotorNameplate.analyze(fla: 22, phases: 3, tableFullLoadAmps: .nan))
    }

    func testRejectsNonPositiveFLA() {
        XCTAssertThrowsError(try MotorNameplate.analyze(fla: 0, phases: 3))
    }
}

final class HeaterDesignTests: XCTestCase {
    func testThreePhaseWyeLineCurrent() throws {
        let r = try HeaterDesign.electrical(totalWatts: 9000, lineVolts: 480, phase: .three, connection: .wye)
        XCTAssertEqual(r.lineAmps, 9000 / (sqrt(3) * 480), accuracy: 1e-9)
        XCTAssertEqual(r.legResistanceOhms, (480 * 480) / 9000, accuracy: 1e-9)
        XCTAssertEqual(r.designAmps, r.lineAmps * 1.25, accuracy: 1e-9)
    }

    func testElementLengthPositive() throws {
        let e = try HeaterDesign.element(targetResistanceOhms: 25.6, targetWatts: 3000, resistivityOhmMm2PerM: 1.09, awg: 18)
        XCTAssertGreaterThan(e.lengthMeters, 0)
        XCTAssertGreaterThan(e.currentAmps, 0)
    }
}

final class EMPEMCTests: XCTestCase {
    func testCopperSkinDepthAt1MHz() throws {
        let r = try EMPEMC.shieldEstimate(material: .copper, thicknessM: 0.001, frequencyHz: 1e6)
        XCTAssertGreaterThan(r.skinDepthM, 0)
        XCTAssertLessThan(r.skinDepthM, 1e-4)
        XCTAssertGreaterThan(r.sheetSEDB, 0)
    }

    func testFaradayLoop() throws {
        let r = try EMPEMC.faradayLoop(turns: 1, areaM2: 0.01, dBdtTeslaPerS: 100)
        XCTAssertEqual(r.inducedVolts, 1.0, accuracy: 1e-9)
    }
}

final class NECCircuitTests: XCTestCase {
    func testFromKWPicksConductor() throws {
        let r = try NECCircuitCalc.solve(
            loadKW: 15,
            voltage: 480,
            phases: 3,
            powerFactor: 0.9,
            loadType: .continuous,
            oneWayFeet: 150
        )
        XCTAssertGreaterThan(r.fla, 0)
        XCTAssertFalse(r.conductorSize.isEmpty)
        XCTAssertNotNil(r.ocpdAmps)
        XCTAssertEqual(r.supplyVolts, 480, accuracy: 1e-9)
        XCTAssertEqual(r.oneWayFeet, 150, accuracy: 1e-9)
    }

    func testRunReadoutMatchesDropAndAmpacityVerdict() throws {
        let r = try NECCircuitCalc.solve(
            loadKW: 15,
            voltage: 480,
            phases: 3,
            powerFactor: 0.9,
            loadType: .continuous,
            oneWayFeet: 150
        )
        let fla = 15_000 / (sqrt(3) * 480 * 0.9)
        XCTAssertEqual(r.fla, fla, accuracy: 1e-6)
        XCTAssertEqual(r.designAmps, fla * 1.25, accuracy: 1e-6)
        XCTAssertEqual(r.vdPercent, r.vdVolts / 480 * 100, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(r.deratedAmpacity + 1e-9, r.designAmps)

        let run = try XCTUnwrap(NECCircuitRunReadout(result: r))
        XCTAssertEqual(run.verdict, .meets)
        XCTAssertEqual(run.parallelRuns, 1)
        XCTAssertEqual(run.dropVolts, r.vdVolts, accuracy: 1e-12)
        XCTAssertEqual(run.dropPercent, r.vdPercent, accuracy: 1e-12)
        XCTAssertEqual(run.designAmps, r.designAmps, accuracy: 1e-12)
        XCTAssertEqual(run.usableAmps, r.deratedAmpacity, accuracy: 1e-12)
        XCTAssertEqual(run.receivingVolts, r.supplyVolts - r.vdVolts, accuracy: 1e-9)
        XCTAssertEqual(run.designLabel, DeratingStackReadout.ampsLabel(r.designAmps))
        XCTAssertEqual(run.usableLabel, DeratingStackReadout.ampsLabel(r.deratedAmpacity))
        XCTAssertEqual(run.dropVoltsLabel, DeratingStackReadout.siLabel(r.vdVolts, unit: "V"))
        XCTAssertEqual(run.supplyLabel, DeratingStackReadout.siLabel(r.supplyVolts, unit: "V"))
        XCTAssertEqual(run.receivingLabel, DeratingStackReadout.siLabel(run.receivingVolts, unit: "V"))
        XCTAssertEqual(run.dropPercentLabel, NECCircuitRunReadout.percentLabel(r.vdPercent))
        XCTAssertEqual(run.oneWayLabel, "150 ft")
        XCTAssertEqual(run.chipLine, "\(run.usableLabel) usable · MEETS \(run.designLabel)")
        XCTAssertEqual(run.announcement.hasPrefix("\(run.designLabel) design."), true)
        XCTAssertEqual(run.announcement.first?.isNumber, true)
        XCTAssertTrue(run.announcement.contains("\(run.dropVoltsLabel) drop, \(run.dropPercentLabel)."))
        XCTAssertTrue(run.announcement.contains("\(run.usableLabel) usable, meets \(run.designLabel) required."))
        XCTAssertTrue(run.announcement.contains("3% and 5% marks are informational."))
        XCTAssertFalse(run.announcement.localizedCaseInsensitiveContains("short"))
        XCTAssertFalse(run.chipLine.localizedCaseInsensitiveContains("short"))
    }

    func testRunReadoutShortWhenUsableIsBelowDesign() throws {
        let r = NECCircuitResult(
            fla: 100,
            designAmps: 125,
            ambientFactor: 1,
            cccFactor: 1,
            totalDerating: 1,
            conductorSize: "8",
            baseAmpacity: 55,
            deratedAmpacity: 50,
            vdVolts: 4.2,
            vdPercent: 3.5,
            ocpdAmps: 150,
            formula: "test",
            supplyVolts: 120,
            oneWayFeet: 80
        )
        let run = try XCTUnwrap(NECCircuitRunReadout(result: r))
        XCTAssertEqual(run.verdict, .short)
        XCTAssertEqual(run.receivingVolts, 115.8, accuracy: 1e-9)
        XCTAssertEqual(run.chipLine, "50 A usable · SHORT 125 A")
        XCTAssertEqual(
            run.announcement,
            "125 A design. 4.2 V drop, 3.5 %. 50 A usable, short of 125 A required. 120 V supply. 116 V load. 80 ft one-way. 1 parallel run. 3% and 5% marks are informational."
        )
        XCTAssertEqual(run.announcement.first?.isNumber, true)
        XCTAssertFalse(run.announcement.localizedCaseInsensitiveContains("meets"))
    }

    func testRunReadoutRejectsUnusableNumbers() {
        var r = NECCircuitResult(
            fla: 100,
            designAmps: 125,
            ambientFactor: 1,
            cccFactor: 1,
            totalDerating: 1,
            conductorSize: "8",
            baseAmpacity: 55,
            deratedAmpacity: 50,
            vdVolts: 4.2,
            vdPercent: 3.5,
            ocpdAmps: 150,
            formula: "test",
            supplyVolts: 120,
            oneWayFeet: 80
        )
        r.supplyVolts = 0
        XCTAssertNil(NECCircuitRunReadout(result: r))
        r.supplyVolts = 120
        r.designAmps = 0
        XCTAssertNil(NECCircuitRunReadout(result: r))
    }
}

final class LoadWorksheetTests: XCTestCase {
    func testOtherOccupancyIsUnityLightingDF() throws {
        let r = try LoadWorksheet.calculate(
            rows: [
                LoadWorksheetRow(description: "L", type: .lighting, vaEach: 10_000),
                LoadWorksheetRow(description: "M", type: .motor, vaEach: 4_000),
            ],
            occupancy: .other,
            voltage: 208,
            phases: 3,
            sparePercent: 0
        )
        XCTAssertEqual(r.lightingDemandVA, 10_000, accuracy: 1e-9)
        XCTAssertEqual(r.otherDemandVA, 4_000 * 1.25, accuracy: 1e-9)
        XCTAssertEqual(r.totalDemandVA, 10_000 + 5_000, accuracy: 1e-9)
    }
}

final class CableScheduleTests: XCTestCase {
    func testSequentialIDsAndCSV() throws {
        let r = try CableSchedule.generate(
            lines: [
                CableScheduleLineInput(typeId: "PWR-3C-10", quantity: 2, from: "A", to: "B"),
                CableScheduleLineInput(typeId: "CTL-8C-14", quantity: 1, from: "C", to: "D"),
            ],
            prefix: "C",
            startNumber: 1
        )
        XCTAssertEqual(r.rows.count, 3)
        XCTAssertEqual(r.rows[0].cableID, "C-001")
        XCTAssertEqual(r.rows[2].cableID, "C-003")
        XCTAssertTrue(r.csv.contains("Cable ID"))
        XCTAssertTrue(r.csv.contains("PWR-3C-10"))
    }
}

final class SolenoidDesignTests: XCTestCase {
    func testLongSolenoidCenterFieldNearMu0NIOverL() throws {
        // ℓ = 200 mm, R = 10 mm, N = 1000, I = 1 A, air → nearly infinite-length B.
        let r = try SolenoidDesign.design(
            lengthM: 0.2,
            meanRadiusM: 0.01,
            turns: 1000,
            currentAmps: 1,
            wireAWG: 24,
            relativePermeability: 1,
            airGapM: 0.002
        )
        let infinite = SolenoidDesign.mu0 * (1000 / 0.2) * 1
        XCTAssertEqual(r.bCenterTesla, infinite, accuracy: infinite * 0.02)
        XCTAssertGreaterThan(r.inductanceHenry, 0)
        XCTAssertEqual(r.forceVsGap.count, 24)
        XCTAssertFalse(r.axialField.isEmpty)
        XCTAssertNotNil(r.forceNewton)
    }

    func testCurrentForTargetBRoundTrip() throws {
        let i = try SolenoidDesign.currentForTargetB(
            targetTesla: 0.01,
            lengthM: 0.15,
            meanRadiusM: 0.012,
            turns: 800
        )
        let r = try SolenoidDesign.design(
            lengthM: 0.15,
            meanRadiusM: 0.012,
            turns: 800,
            currentAmps: i,
            wireAWG: 22
        )
        XCTAssertEqual(r.bCenterTesla, 0.01, accuracy: 1e-6)
    }

    func testRejectsNonPositiveGeometry() {
        XCTAssertThrowsError(try SolenoidDesign.design(
            lengthM: 0, meanRadiusM: 0.01, turns: 100, currentAmps: 1, wireAWG: 22
        ))
    }
}
