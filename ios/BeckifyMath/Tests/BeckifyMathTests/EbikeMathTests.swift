import XCTest
@testable import BeckifyMath

final class EbikeMathTests: XCTestCase {

    // MARK: - Helpers

    func testKilowattsAndHorsepowerToWattsMatchWebsite() {
        XCTAssertEqual(EbikeMath.powerToWatts(2, unit: .kilowatts), 2000, accuracy: 1e-12)
        XCTAssertEqual(EbikeMath.powerToWatts(1, unit: .horsepower), 746, accuracy: 1e-12)
        XCTAssertEqual(EbikeMath.powerToWatts(500, unit: .watts), 500, accuracy: 1e-12)
    }

    func testWheelSpeedDefault26InchAt800RPM() {
        let mph = EbikeMath.wheelSpeedMilesPerHour(outputRPM: 800, wheelDiameterInches: 26)
        XCTAssertNotNil(mph)
        XCTAssertEqual(mph!, 800 * Double.pi * (26 / 12) * 60 / 5280, accuracy: 1e-12)
        XCTAssertEqual(mph!, 61.880, accuracy: 0.01)
    }

    func testWheelSpeedOmitsNonPositiveDiameter() {
        XCTAssertNil(EbikeMath.wheelSpeedMilesPerHour(outputRPM: 800, wheelDiameterInches: 0))
        XCTAssertNil(EbikeMath.wheelSpeedMilesPerHour(outputRPM: 0, wheelDiameterInches: 26))
    }

    // MARK: - Torque / RPM

    func testTorqueFrom2kWAt3200RPM() throws {
        let result = try EbikeTorqueRPM.solve(
            power: 2, unit: .kilowatts, solveFor: .torque, rpm: 3200
        )
        XCTAssertEqual(result.powerWatts, 2000, accuracy: 1e-12)
        XCTAssertEqual(result.torqueNewtonMetres, 2000 * 60 / (2 * Double.pi * 3200), accuracy: 1e-12)
        XCTAssertEqual(result.torqueNewtonMetres, 5.968, accuracy: 0.001)
        XCTAssertEqual(result.torquePoundFeet, result.torqueNewtonMetres * 0.737562, accuracy: 1e-12)
        XCTAssertEqual(result.solved, .torque)
    }

    func testRPMFrom2kWAt6Nm() throws {
        let result = try EbikeTorqueRPM.solve(
            power: 2, unit: .kilowatts, solveFor: .rpm, torqueNewtonMetres: 6
        )
        XCTAssertEqual(result.rpm, 2000 * 60 / (2 * Double.pi * 6), accuracy: 1e-12)
        XCTAssertEqual(result.rpm, 3183.1, accuracy: 0.05)
        XCTAssertEqual(result.solved, .rpm)
    }

    func testTorqueFrom1HorsepowerAt3200RPM() throws {
        let result = try EbikeTorqueRPM.solve(
            power: 1, unit: .horsepower, solveFor: .torque, rpm: 3200
        )
        XCTAssertEqual(result.powerWatts, 746, accuracy: 1e-12)
        XCTAssertEqual(result.torqueNewtonMetres, 2.226, accuracy: 0.001)
    }

    func testTorqueRPMRejectsNonPositiveInputs() {
        XCTAssertThrowsError(try EbikeTorqueRPM.solve(
            power: 0, unit: .kilowatts, solveFor: .torque, rpm: 3200
        ))
        XCTAssertThrowsError(try EbikeTorqueRPM.solve(
            power: 2, unit: .kilowatts, solveFor: .torque, rpm: 0
        ))
        XCTAssertThrowsError(try EbikeTorqueRPM.solve(
            power: 2, unit: .kilowatts, solveFor: .rpm, torqueNewtonMetres: 0
        ))
    }

    // MARK: - Sprocket ratio

    func testDefaultSprocketRatio14To56() throws {
        let result = try EbikeSprocket.ratio(
            motorRPM: 3200,
            motorTorqueNewtonMetres: 6,
            driveTeeth: 14,
            drivenTeeth: 56,
            efficiencyPercent: 92,
            wheelDiameterInches: 26
        )
        XCTAssertEqual(result.ratio, 4, accuracy: 1e-12)
        XCTAssertEqual(result.outputRPM, 800, accuracy: 1e-12)
        XCTAssertEqual(result.outputTorqueNewtonMetres, 22.08, accuracy: 1e-12)
        XCTAssertEqual(result.outputTorquePoundFeet, 22.08 * 0.737562, accuracy: 1e-12)
        XCTAssertEqual(result.inputMechanicalWatts, 6 * 3200 * 2 * Double.pi / 60, accuracy: 1e-12)
        XCTAssertEqual(result.inputMechanicalWatts, 2010.6, accuracy: 0.1)
        XCTAssertEqual(result.wheelSpeedMilesPerHour ?? 0, 61.88, accuracy: 0.01)
    }

    func testSprocketRatioWithoutWheelOmitsSpeed() throws {
        let result = try EbikeSprocket.ratio(
            motorRPM: 3000,
            motorTorqueNewtonMetres: 4,
            driveTeeth: 11,
            drivenTeeth: 44,
            efficiencyPercent: 90
        )
        XCTAssertEqual(result.ratio, 4, accuracy: 1e-12)
        XCTAssertEqual(result.outputRPM, 750, accuracy: 1e-12)
        XCTAssertEqual(result.outputTorqueNewtonMetres, 14.4, accuracy: 1e-12)
        XCTAssertNil(result.wheelSpeedMilesPerHour)
    }

    /// 11T/44T at 3000 rpm → 750 rpm out. Website `ebWheelSpeedMph(750, 27)`.
    func testSprocket27InchWheelSpeed() throws {
        let result = try EbikeSprocket.ratio(
            motorRPM: 3000,
            motorTorqueNewtonMetres: 4,
            driveTeeth: 11,
            drivenTeeth: 44,
            efficiencyPercent: 90,
            wheelDiameterInches: 27
        )
        let expected = 750 * Double.pi * (27.0 / 12.0) * 60 / 5280
        XCTAssertEqual(result.outputRPM, 750, accuracy: 1e-12)
        XCTAssertEqual(result.wheelSpeedMilesPerHour ?? 0, expected, accuracy: 1e-12)
        XCTAssertEqual(result.wheelSpeedMilesPerHour ?? 0, 60.24, accuracy: 0.01)
    }

    func testSprocketRejectsZeroEfficiency() {
        XCTAssertThrowsError(try EbikeSprocket.ratio(
            motorRPM: 3200, motorTorqueNewtonMetres: 6,
            driveTeeth: 14, drivenTeeth: 56, efficiencyPercent: 0
        ))
    }

    // MARK: - Target sprocket

    func testDefaultTargetSprocketRPMAndTorque() throws {
        let result = try EbikeSprocket.target(
            motorRPM: 3200,
            motorTorqueNewtonMetres: 6,
            driveTeeth: 14,
            efficiencyPercent: 92,
            targetOutputRPM: 800,
            targetOutputTorqueNewtonMetres: 20
        )
        XCTAssertEqual(result.rpmRatio ?? 0, 4, accuracy: 1e-12)
        XCTAssertEqual(result.rpmDrivenTeeth ?? 0, 56, accuracy: 1e-12)
        XCTAssertEqual(result.rpmDrivenTeethRounded, 56)
        XCTAssertEqual(result.torqueRatio ?? 0, 20 / (6 * 0.92), accuracy: 1e-12)
        XCTAssertEqual(result.torqueRatio ?? 0, 3.623, accuracy: 0.001)
        XCTAssertEqual(result.torqueDrivenTeethRounded, 51)
    }

    func testTargetSprocketRPMOnly() throws {
        let result = try EbikeSprocket.target(
            motorRPM: 4000,
            motorTorqueNewtonMetres: 5,
            driveTeeth: 12,
            efficiencyPercent: 95,
            targetOutputRPM: 1000
        )
        XCTAssertEqual(result.rpmRatio ?? 0, 4, accuracy: 1e-12)
        XCTAssertEqual(result.rpmDrivenTeethRounded, 48)
        XCTAssertNil(result.torqueRatio)
    }

    func testTargetSprocketTorqueOnly() throws {
        let result = try EbikeSprocket.target(
            motorRPM: 3000,
            motorTorqueNewtonMetres: 8,
            driveTeeth: 15,
            efficiencyPercent: 90,
            targetOutputTorqueNewtonMetres: 30
        )
        XCTAssertEqual(result.torqueRatio ?? 0, 30 / (8 * 0.9), accuracy: 1e-12)
        XCTAssertEqual(result.torqueDrivenTeethRounded, 63)
        XCTAssertNil(result.rpmRatio)
    }

    func testTargetSprocketRequiresAtLeastOneTarget() {
        XCTAssertThrowsError(try EbikeSprocket.target(
            motorRPM: 3200, motorTorqueNewtonMetres: 6,
            driveTeeth: 14, efficiencyPercent: 92
        ))
    }

    // MARK: - Range

    func testDefaultRange52V20Ah() throws {
        let result = try EbikeRange.estimate(
            batteryVolts: 52,
            batteryAmpHours: 20,
            wattHoursPerMile: 28,
            averagePowerWatts: 700
        )
        XCTAssertEqual(result.batteryWattHours, 1040, accuracy: 1e-12)
        XCTAssertEqual(result.miles, 1040 / 28, accuracy: 1e-12)
        XCTAssertEqual(result.miles, 37.14, accuracy: 0.01)
        XCTAssertEqual(result.kilometers, result.miles * 1.609344, accuracy: 1e-12)
        XCTAssertEqual(result.runtimeHours, 1040 / 700, accuracy: 1e-12)
        XCTAssertEqual(result.impliedMilesPerHour, 25, accuracy: 1e-12)
    }

    func testRange48V17p5Ah() throws {
        let result = try EbikeRange.estimate(
            batteryVolts: 48,
            batteryAmpHours: 17.5,
            wattHoursPerMile: 25,
            averagePowerWatts: 500
        )
        XCTAssertEqual(result.batteryWattHours, 840, accuracy: 1e-12)
        XCTAssertEqual(result.miles, 33.6, accuracy: 1e-12)
        XCTAssertEqual(result.runtimeHours, 1.68, accuracy: 1e-12)
        XCTAssertEqual(result.impliedMilesPerHour, 20, accuracy: 1e-12)
    }

    func testRange72V15Ah() throws {
        let result = try EbikeRange.estimate(
            batteryVolts: 72,
            batteryAmpHours: 15,
            wattHoursPerMile: 35,
            averagePowerWatts: 900
        )
        XCTAssertEqual(result.batteryWattHours, 1080, accuracy: 1e-12)
        XCTAssertEqual(result.miles, 30.86, accuracy: 0.01)
        XCTAssertEqual(result.runtimeHours, 1.2, accuracy: 1e-12)
        XCTAssertEqual(result.impliedMilesPerHour, 25.71, accuracy: 0.01)
    }

    func testRangeRejectsZeroConsumption() {
        XCTAssertThrowsError(try EbikeRange.estimate(
            batteryVolts: 52, batteryAmpHours: 20,
            wattHoursPerMile: 0, averagePowerWatts: 700
        ))
    }

    // MARK: - Pack analyze (visual designer balanced S×P)

    func testAnalyze14S10P18650MatchesWebsiteDesigner() throws {
        let result = try EbikePack.analyze(
            seriesCount: 14,
            parallelCount: 10,
            cellVolts: 3.6,
            cellAmpHours: 2.5,
            cellContinuousAmps: 20,
            loadAmps: 40
        )
        XCTAssertEqual(result.architecture, "14S10P")
        XCTAssertEqual(result.cellCount, 140)
        XCTAssertEqual(result.nominalVolts, 50.4, accuracy: 1e-12)
        XCTAssertEqual(result.maxVolts, 58.8, accuracy: 1e-12)
        XCTAssertEqual(result.capacityAmpHours, 25, accuracy: 1e-12)
        XCTAssertEqual(result.energyWattHours, 1260, accuracy: 1e-12)
        XCTAssertEqual(result.packContinuousAmps, 200, accuracy: 1e-12)
        XCTAssertEqual(result.perCellLoadAmps ?? 0, 4, accuracy: 1e-12)
        XCTAssertEqual(result.cRate ?? 0, 1.6, accuracy: 1e-12)
        XCTAssertTrue(result.loadOk)
    }

    func testAnalyze13S8P21700() throws {
        let result = try EbikePack.analyze(
            seriesCount: 13,
            parallelCount: 8,
            cellVolts: 3.6,
            cellAmpHours: 4,
            cellContinuousAmps: 15
        )
        XCTAssertEqual(result.nominalVolts, 46.8, accuracy: 1e-12)
        XCTAssertEqual(result.capacityAmpHours, 32, accuracy: 1e-12)
        XCTAssertEqual(result.energyWattHours, 1497.6, accuracy: 1e-12)
        XCTAssertEqual(result.packContinuousAmps, 120, accuracy: 1e-12)
        XCTAssertNil(result.perCellLoadAmps)
        XCTAssertTrue(result.loadOk)
    }

    func testAnalyzeLoadOverCellRatingIsNotOk() throws {
        let result = try EbikePack.analyze(
            seriesCount: 10,
            parallelCount: 2,
            cellVolts: 3.6,
            cellAmpHours: 3,
            cellContinuousAmps: 10,
            loadAmps: 30
        )
        XCTAssertEqual(result.perCellLoadAmps ?? 0, 15, accuracy: 1e-12)
        XCTAssertFalse(result.loadOk)
    }

    func testAnalyzeRejectsFractionalSeries() {
        XCTAssertThrowsError(try EbikePack.analyze(
            seriesCount: 14.5, parallelCount: 10,
            cellVolts: 3.6, cellAmpHours: 2.5, cellContinuousAmps: 20
        ))
    }

    // MARK: - Pack plan (18650 planner)

    func testPlan36V20AWithoutEnclosure() throws {
        let result = try EbikePack.plan(
            targetVolts: 36,
            continuousAmps: 20,
            cellVolts: 3.6,
            cellAmpHours: 3,
            cellContinuousAmps: 10
        )
        XCTAssertEqual(result.series, 10)
        XCTAssertEqual(result.parallel, 2)
        XCTAssertEqual(result.cellCount, 20)
        XCTAssertEqual(result.nominalVolts, 36, accuracy: 1e-12)
        XCTAssertEqual(result.maxVolts, 42, accuracy: 1e-12)
        XCTAssertEqual(result.requiredAmps, 20, accuracy: 1e-12)
        XCTAssertEqual(result.capacityAmpHours, 6, accuracy: 1e-12)
        XCTAssertEqual(result.energyWattHours, 216, accuracy: 1e-12)
        XCTAssertEqual(result.perCellAmps, 10, accuracy: 1e-12)
        XCTAssertEqual(result.cRate, 10 / 3, accuracy: 1e-12)
        XCTAssertTrue(result.loadOk)
        XCTAssertFalse(result.spaceLimited)
    }

    func testPlan48VFromPowerRoundsTo13S() throws {
        let result = try EbikePack.plan(
            targetVolts: 48,
            continuousWatts: 750,
            cellVolts: 3.6,
            cellAmpHours: 3,
            cellContinuousAmps: 10
        )
        XCTAssertEqual(result.series, 13)
        XCTAssertEqual(result.nominalVolts, 46.8, accuracy: 1e-12)
        XCTAssertEqual(result.requiredAmps, 750 / 46.8, accuracy: 1e-12)
        XCTAssertEqual(result.parallel, 2)
        XCTAssertEqual(result.cellCount, 26)
        XCTAssertEqual(result.capacityAmpHours, 6, accuracy: 1e-12)
        XCTAssertEqual(result.energyWattHours, 280.8, accuracy: 1e-9)
    }

    func testPlanTakesMaxOfCurrentAndPower() throws {
        let result = try EbikePack.plan(
            targetVolts: 36,
            continuousAmps: 5,
            continuousWatts: 720,
            cellVolts: 3.6,
            cellAmpHours: 3,
            cellContinuousAmps: 10
        )
        XCTAssertEqual(result.requiredAmps, 20, accuracy: 1e-12)
        XCTAssertEqual(result.parallel, 2)
    }

    func testPlanEnclosureHoneycomb36V20A() throws {
        let result = try EbikePack.plan(
            targetVolts: 36,
            continuousAmps: 20,
            cellVolts: 3.6,
            cellAmpHours: 3,
            cellContinuousAmps: 10,
            cellDiameterMM: 18.5,
            cellLengthMM: 65.2,
            enclosureWidthMM: 400,
            enclosureHeightMM: 150,
            pattern: .honeycomb
        )
        XCTAssertEqual(result.series, 10)
        XCTAssertEqual(result.parallel, 2)
        XCTAssertFalse(result.spaceLimited)
        XCTAssertFalse(result.geometryImpossible)
        XCTAssertEqual(result.enclosureHeadroomCells, 4)
        XCTAssertEqual(result.columnPitchMM, 21.5, accuracy: 1e-12)
        XCTAssertEqual(result.rowPitchMM, 21.5 * 0.8660254, accuracy: 1e-12)
    }

    func testPlanRequiresCurrentOrPower() {
        XCTAssertThrowsError(try EbikePack.plan(
            targetVolts: 36,
            cellVolts: 3.6,
            cellAmpHours: 3,
            cellContinuousAmps: 10
        ))
    }

    func testPlanMassAndEnergyDensity() throws {
        let result = try EbikePack.plan(
            targetVolts: 36,
            continuousAmps: 20,
            cellVolts: 3.6,
            cellAmpHours: 3,
            cellContinuousAmps: 10,
            cellMassGrams: 48
        )
        XCTAssertEqual(result.packMassKilograms ?? 0, 0.96, accuracy: 1e-12)
        XCTAssertEqual(result.energyDensityWhPerKg ?? 0, 216 / 0.96, accuracy: 1e-12)
    }

    // MARK: - Nickel strip

    func testDefaultNickelStrip8x0p15() throws {
        let result = try NickelStrip.size(
            widthMM: 8, thicknessMM: 0.15,
            continuousDensity: 5, pulseDensity: 10
        )
        XCTAssertEqual(result.crossSectionMM2, 1.2, accuracy: 1e-12)
        XCTAssertEqual(result.continuousAmps, 6, accuracy: 1e-12)
        XCTAssertEqual(result.pulseAmps, 12, accuracy: 1e-12)
    }

    func testNickelStrip10x0p2() throws {
        let result = try NickelStrip.size(
            widthMM: 10, thicknessMM: 0.2,
            continuousDensity: 5, pulseDensity: 10
        )
        XCTAssertEqual(result.crossSectionMM2, 2.0, accuracy: 1e-12)
        XCTAssertEqual(result.continuousAmps, 10, accuracy: 1e-12)
        XCTAssertEqual(result.pulseAmps, 20, accuracy: 1e-12)
    }

    func testCommonStripTableIncludes6x0p1() throws {
        let size = NickelStrip.commonSizes.first { $0.widthMM == 6 && $0.thicknessMM == 0.1 }
        XCTAssertNotNil(size)
        let result = try NickelStrip.size(
            widthMM: 6, thicknessMM: 0.1,
            continuousDensity: 5, pulseDensity: 10
        )
        XCTAssertEqual(result.crossSectionMM2, 0.6, accuracy: 1e-12)
        XCTAssertEqual(result.continuousAmps, 3, accuracy: 1e-12)
        XCTAssertEqual(result.pulseAmps, 6, accuracy: 1e-12)
    }

    func testNickelStripRejectsZeroWidth() {
        XCTAssertThrowsError(try NickelStrip.size(
            widthMM: 0, thicknessMM: 0.15,
            continuousDensity: 5, pulseDensity: 10
        ))
    }
}
