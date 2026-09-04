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
        XCTAssertEqual(r.conductorRequiredAmps, 27 * 1.25, accuracy: 1e-9)
        XCTAssertEqual(r.scpd.percent, 250, accuracy: 1e-9)
        XCTAssertNotNil(r.lockedRotor)
        XCTAssertEqual(r.lockedRotor?.letter, "G")
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
