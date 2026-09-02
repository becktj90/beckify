import XCTest
@testable import BeckifyMath

final class OhmsLawTests: XCTestCase {
    func testSolveForVoltage() throws {
        let r = try OhmsLaw.solve(voltage: nil, current: 2, resistance: 6)
        XCTAssertEqual(r.voltage, 12, accuracy: 1e-9)
        XCTAssertEqual(r.power, 24, accuracy: 1e-9)
    }

    func testSolveForCurrent() throws {
        let r = try OhmsLaw.solve(voltage: 120, current: nil, resistance: 10)
        XCTAssertEqual(r.current, 12, accuracy: 1e-9)
    }

    func testSolveForResistance() throws {
        let r = try OhmsLaw.solve(voltage: 24, current: 2, resistance: nil)
        XCTAssertEqual(r.resistance, 12, accuracy: 1e-9)
    }

    func testNeedsTwoValues() {
        XCTAssertThrowsError(try OhmsLaw.solve(voltage: 12, current: nil, resistance: nil))
    }

    func testRejectsInconsistentThreeValues() {
        XCTAssertThrowsError(try OhmsLaw.solve(voltage: 120, current: 10, resistance: 20)) { error in
            XCTAssertEqual(error as? CalcError, .needTwoOfThree)
        }
    }
}

final class PowerWizardTests: XCTestCase {
    /// Spot-check from product spec: 480 V 3Ø 50 kW PF 0.90 → 66.8 A.
    func testThreePhase50kW480V() throws {
        let r = try PowerWizard.solve(
            system: .threePhase,
            known: .kilowatts(50),
            voltage: 480,
            powerFactor: 0.90,
            efficiency: 1
        )
        XCTAssertEqual(r.amps, 66.8, accuracy: 0.05)
        XCTAssertEqual(r.kW, 50, accuracy: 1e-9)
        XCTAssertEqual(r.kVA, 50 / 0.90, accuracy: 1e-9)
    }

    func testDCFromAmps() throws {
        let r = try PowerWizard.solve(
            system: .dc,
            known: .amps(10),
            voltage: 48,
            powerFactor: 0.5,
            efficiency: 1
        )
        XCTAssertEqual(r.amps, 10, accuracy: 1e-9)
        XCTAssertEqual(r.kW, 0.48, accuracy: 1e-9)
        XCTAssertEqual(r.powerFactor, 1, accuracy: 1e-9)
        XCTAssertEqual(r.kVAR, 0, accuracy: 1e-9)
    }

    func testSinglePhaseFromKVA() throws {
        let r = try PowerWizard.solve(
            system: .singlePhase,
            known: .kilovoltAmps(12),
            voltage: 240,
            powerFactor: 0.8,
            efficiency: 1
        )
        XCTAssertEqual(r.amps, 50, accuracy: 1e-9)
        XCTAssertEqual(r.kW, 9.6, accuracy: 1e-9)
    }

    func testInvalidEfficiencyOnKilowattsThrows() {
        XCTAssertThrowsError(
            try PowerWizard.solve(
                system: .threePhase,
                known: .kilowatts(50),
                voltage: 480,
                powerFactor: 0.9,
                efficiency: 0
            )
        ) { error in
            XCTAssertEqual(
                error as? CalcError,
                .outOfRange("Efficiency must be between 0 and 1 (exclusive of 0).")
            )
        }
    }

    func testInvalidEfficiencyOnAmpsThrows() {
        XCTAssertThrowsError(
            try PowerWizard.solve(
                system: .dc,
                known: .amps(10),
                voltage: 48,
                powerFactor: 1,
                efficiency: .nan
            )
        ) { error in
            XCTAssertEqual(
                error as? CalcError,
                .outOfRange("Efficiency must be between 0 and 1 (exclusive of 0).")
            )
        }
    }
}

final class ACPowerTests: XCTestCase {
    func testThreePhaseApparent() throws {
        let r = try ACPower.solve(system: .threePhase, voltage: 480, current: 66.823, powerFactor: 0.9)
        XCTAssertEqual(r.kW, 50, accuracy: 0.05)
    }

    func testDCPowerVIR() throws {
        let r = try DCPower.fromIR(current: 10, resistance: 4)
        XCTAssertEqual(r.power, 400, accuracy: 1e-9)
        XCTAssertEqual(r.voltage, 40, accuracy: 1e-9)
    }

    func testRejectsDCSystem() {
        XCTAssertThrowsError(try ACPower.solve(system: .dc, voltage: 48, current: 10, powerFactor: 0.9)) { error in
            XCTAssertEqual(
                error as? CalcError,
                .outOfRange("AC power is for 1Ø or 3Ø. Use DC power or Power Wizard for DC.")
            )
        }
    }

    func testFromVIRejectsZeroCurrent() {
        XCTAssertThrowsError(try DCPower.fromVI(voltage: 120, current: 0)) { error in
            XCTAssertEqual(
                error as? CalcError,
                .outOfRange("Current must not be zero when deriving resistance.")
            )
        }
    }
}

final class VoltageDropTests: XCTestCase {
    func testThreePhaseCopperExample() throws {
        // Website example: 480 V, 45 A, 250 ft, Cu 4 AWG, 3Ø
        let r = try VoltageDrop.calculate(
            system: .threePhase,
            current: 45,
            oneWayFeet: 250,
            supplyVolts: 480,
            size: "4",
            material: .copper
        )
        let expected = Foundation.sqrt(3.0) * 12.9 * 45 * 250 / 41740
        XCTAssertEqual(r.dropVolts, expected, accuracy: 1e-6)
        XCTAssertEqual(r.ampacity75C, 85)
        XCTAssertEqual(r.ampacityOK, true)
        XCTAssertTrue(r.meets3Percent)
        XCTAssertTrue(r.meets5Percent)
    }
}

final class ConduitFillTests: XCTestCase {
    func testThreeConductorsUse40Percent() throws {
        let r = try ConduitFill.calculate(quantity: 3, size: "12", tradeSize: "1/2")
        XCTAssertEqual(r.maxFillPercent, 40)
        XCTAssertEqual(r.totalWireArea, 3 * 0.0133, accuracy: 1e-9)
        XCTAssertTrue(r.passes)
    }

    func testSingleConductorUses53Percent() throws {
        let r = try ConduitFill.calculate(quantity: 1, size: "4/0", tradeSize: "1/2")
        XCTAssertEqual(r.maxFillPercent, 53)
        XCTAssertFalse(r.passes)
        XCTAssertNotNil(r.suggestedTradeSize)
    }

    func testTwoConductorsUse31Percent() throws {
        let r = try ConduitFill.calculate(quantity: 2, size: "12", tradeSize: "1/2")
        XCTAssertEqual(r.maxFillPercent, 31)
    }

    func testFractionalConductorCountIsRejected() throws {
        XCTAssertThrowsError(try WholeCount.parse(2.9, name: "Conductor quantity")) { error in
            XCTAssertEqual(error as? CalcError, .outOfRange("Conductor quantity must be a whole number."))
        }
        XCTAssertEqual(try WholeCount.parse(3, name: "Conductor quantity"), 3)
        XCTAssertThrowsError(try WholeCount.parse(1e20, name: "Conductor quantity")) { error in
            XCTAssertEqual(error as? CalcError, .outOfRange("Conductor quantity is out of range."))
        }
        // Truncating 2.9 → 2 would silently use the 2-wire 31% Table 1 row.
        let twoWire = try ConduitFill.calculate(quantity: 2, size: "12", tradeSize: "1/2")
        XCTAssertEqual(twoWire.maxFillPercent, 31)
    }
}

final class TransformerSizingTests: XCTestCase {
    func testContinuousThreePhaseNote1() throws {
        // Website example: 38 kW, PF 90%, 480→208, 3Ø, continuous
        let r = try TransformerSizing.size(
            system: .threePhase,
            load: .kW(38, powerFactor: 0.90),
            primaryVolts: 480,
            secondaryVolts: 208,
            continuous: true
        )
        XCTAssertEqual(r.loadKVA, 38 / 0.90, accuracy: 1e-9)
        XCTAssertEqual(r.designKVA, (38 / 0.90) * 1.25, accuracy: 1e-9)
        XCTAssertEqual(r.selectedKVA, 75)
        XCTAssertEqual(r.primaryOnly.percent, 125)
        XCTAssertTrue(r.primaryOnly.roundsUp)
        XCTAssertEqual(r.primaryWithSecondary.percent, 250)
        XCTAssertEqual(r.secondaryProtection.percent, 125)
    }

    func testSmallPrimaryNoRoundUp() throws {
        let r = try TransformerSizing.size(
            system: .singlePhase,
            load: .kVA(1),
            primaryVolts: 480,
            secondaryVolts: 120,
            continuous: false
        )
        // 1 kVA / 480 V ≈ 2.08 A → 167 % row, no Note 1 round-up
        XCTAssertEqual(r.primaryOnly.percent, 167)
        XCTAssertFalse(r.primaryOnly.roundsUp)
    }

    func testRejectsOver1000V() {
        XCTAssertThrowsError(
            try TransformerSizing.size(
                system: .threePhase,
                load: .kVA(500),
                primaryVolts: 13800,
                secondaryVolts: 480,
                continuous: false
            )
        ) { error in
            XCTAssertEqual(
                error as? CalcError,
                .outOfRange("This calculator implements NEC Table 450.3(B) for transformers rated 1000 V or less.")
            )
        }
    }
}

final class NumericParseTests: XCTestCase {
    func testUSParsesWholeString() {
        let us = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(NumericParse.parse("12.5", locale: us), 12.5)
        XCTAssertEqual(NumericParse.parse("  66.8  ", locale: us), 66.8)
        XCTAssertEqual(NumericParse.parse("-3.25", locale: us), -3.25)
    }

    func testRejectsTrailingJunk() {
        let us = Locale(identifier: "en_US_POSIX")
        XCTAssertNil(NumericParse.parse("12.5abc", locale: us))
        XCTAssertNil(NumericParse.parse("1.9 extra", locale: us))
        XCTAssertNil(NumericParse.parse("2.9 conductors", locale: us))
        XCTAssertNil(NumericParse.parse("", locale: us))
        XCTAssertNil(NumericParse.parse("   ", locale: us))
        XCTAssertNil(NumericParse.parse("12.5.6", locale: us))
        XCTAssertNil(NumericParse.parse("1e2e3", locale: us))
        XCTAssertNil(NumericParse.parse("1,,2", locale: us))
    }

    func testLocaleDecimalSeparator() {
        let fr = Locale(identifier: "fr_FR")
        XCTAssertEqual(NumericParse.parse("12,5", locale: fr), 12.5)
        XCTAssertNil(NumericParse.parse("12,5abc", locale: fr))
    }

    func testPersianMinusSignRoundTrip() {
        let fa = Locale(identifier: "fa_IR")
        let formatter = NumberFormatter()
        formatter.locale = fa
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        guard let formatted = formatter.string(from: NSNumber(value: -3.25)) else {
            XCTFail("fa_IR formatter could not format -3.25")
            return
        }
        XCTAssertEqual(NumericParse.parse(formatted, locale: fa) ?? .nan, -3.25, accuracy: 1e-9)
        if (formatter.minusSign ?? "").unicodeScalars.contains("\u{2212}") {
            XCTAssertTrue(formatted.unicodeScalars.contains("\u{2212}"))
        }
    }
}

final class Timer555Tests: XCTestCase {
    func testAstableDocExample() throws {
        // 10 kΩ, 47 kΩ, 0.1 µF, no diode
        let r = try Timer555.astable(r1: 10e3, r2: 47e3, capacitance: 0.1e-6, diodeSteering: false)
        let tHigh = Foundation.log(2.0) * (10e3 + 47e3) * 0.1e-6
        let tLow = Foundation.log(2.0) * 47e3 * 0.1e-6
        XCTAssertEqual(r.timeHigh, tHigh, accuracy: 1e-12)
        XCTAssertEqual(r.timeLow, tLow, accuracy: 1e-12)
        XCTAssertGreaterThan(r.dutyPercent, 50)
        XCTAssertEqual(r.frequency, 1 / (tHigh + tLow), accuracy: 1e-6)
    }

    func testMonostableLn3() throws {
        let r = try Timer555.monostable(resistance: 10e3, capacitance: 1e-6)
        XCTAssertEqual(r.pulseWidth, Foundation.log(3.0) * 10e3 * 1e-6, accuracy: 1e-12)
    }
}

final class MotorFLATests: XCTestCase {
    func testTable430_248() {
        XCTAssertEqual(MotorFLA.lookup(horsepower: "1", voltageColumn: "115", threePhase: false), 16)
        XCTAssertEqual(MotorFLA.lookup(horsepower: "5", voltageColumn: "230", threePhase: false), 28)
    }

    func testTable430_250And480MapsTo460() {
        XCTAssertEqual(MotorFLA.tableVoltage(forSystemVolts: 480, threePhase: true), "460")
        XCTAssertEqual(MotorFLA.lookup(horsepower: "50", voltageColumn: "460", threePhase: true), 65)
        XCTAssertEqual(MotorFLA.conductorAmps(fla: 65), 81.25, accuracy: 1e-9)
    }
}

final class WireAmpacityTests: XCTestCase {
    func testCopper75CLookup() throws {
        XCTAssertEqual(NECTables.ampacity75C(size: "12", material: .copper), 25)
        XCTAssertEqual(NECTables.ampacity75C(size: "4/0", material: .copper), 230)
        let sized = try WireAmpacity.smallestConductor(loadAmps: 95, material: .copper)
        XCTAssertEqual(sized.size, "3")
        XCTAssertEqual(sized.ampacity, 100)
    }

    func testAluminumSkips14AWG() {
        XCTAssertNil(NECTables.ampacity75C(size: "14", material: .aluminum))
        XCTAssertEqual(NECTables.ampacity75C(size: "12", material: .aluminum), 20)
    }

    func testNextStandardOCPDIncludes10A() {
        XCTAssertEqual(NECTables.nextStandardOCPD(9.5), 10)
        XCTAssertEqual(NECTables.nextStandardOCPD(10), 10)
        XCTAssertEqual(NECTables.nextStandardOCPD(10.1), 15)
    }
}

final class SensorMathTests: XCTestCase {
    func testFaceUpLevelIsZeroWhenGravityIsMinusZ() {
        let t = LevelMath.faceUpTiltDegrees(gravityX: 0, gravityY: 0, gravityZ: -1)
        XCTAssertEqual(t.x, 0, accuracy: 1e-9)
        XCTAssertEqual(t.y, 0, accuracy: 1e-9)
    }

    func testFaceUpRollFortyFive() {
        let t = LevelMath.faceUpTiltDegrees(gravityX: 0.70710678118, gravityY: 0, gravityZ: -0.70710678118)
        XCTAssertEqual(t.x, 45, accuracy: 0.01)
        XCTAssertEqual(t.y, 0, accuracy: 0.01)
    }

    func testFaceUpDiagonalTiltUsesFullProjection() {
        let t = LevelMath.faceUpTiltDegrees(gravityX: 0.5, gravityY: 0.5, gravityZ: -0.70710678118)
        XCTAssertEqual(t.x, 30, accuracy: 0.05)
        XCTAssertEqual(t.y, 30, accuracy: 0.05)
    }

    func testPortraitPlumb() {
        XCTAssertEqual(LevelMath.portraitPlumbDeviationDegrees(gravityX: 0, gravityY: -1, gravityZ: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(LevelMath.portraitPlumbDeviationDegrees(gravityX: 0, gravityY: -0.70710678118, gravityZ: -0.70710678118), 45, accuracy: 0.05)
    }

    func testMagneticMagnitudeAndHeading() {
        XCTAssertEqual(MagneticMath.magnitudeMicrotesla(x: 3, y: 4, z: 12), 13, accuracy: 1e-9)
        XCTAssertEqual(MagneticMath.headingDegrees(x: 0, y: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(MagneticMath.headingDegrees(x: 1, y: 0), 90, accuracy: 1e-9)
        XCTAssertEqual(MagneticMath.gauss(fromMicrotesla: 50), 0.5, accuracy: 1e-9)
    }

    func testSoundDBFS() {
        XCTAssertEqual(SoundLevel.dbfs(rms: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(SoundLevel.dbfs(rms: 0.1), -20, accuracy: 1e-9)
        XCTAssertEqual(SoundLevel.dbfs(rms: 0), SoundLevel.silenceFloorDBFS, accuracy: 1e-9)
        XCTAssertEqual(SoundLevel.dbfs(rms: -1), SoundLevel.silenceFloorDBFS, accuracy: 1e-9)
    }

    func testAccelerationGToMS2() {
        XCTAssertEqual(MotionMath.magnitudeG(x: 0, y: 0, z: -1), 1, accuracy: 1e-9)
        XCTAssertEqual(MotionMath.metersPerSecondSquared(fromG: 1), 9.80665, accuracy: 1e-9)
    }

    func testHaversineOneDegreeLatitude() {
        let meters = GeoMath.haversineMeters(lat1: 0, lon1: 0, lat2: 1, lon2: 0)
        XCTAssertEqual(meters, GeoMath.earthRadiusMeters * .pi / 180, accuracy: 1e-6)
        XCTAssertEqual(GeoMath.initialBearingDegrees(lat1: 0, lon1: 0, lat2: 1, lon2: 0), 0, accuracy: 1e-6)
        XCTAssertEqual(GeoMath.initialBearingDegrees(lat1: 0, lon1: 0, lat2: 0, lon2: 1), 90, accuracy: 1e-6)
    }

    func testEastNorthMetersAtEquator() {
        let en = GeoMath.eastNorthMeters(originLat: 0, originLon: 0, lat: 0, lon: 1)
        XCTAssertEqual(en.north, 0, accuracy: 1e-6)
        XCTAssertEqual(en.east, GeoMath.earthRadiusMeters * .pi / 180, accuracy: 1e-3)
        let n = GeoMath.eastNorthMeters(originLat: 0, originLon: 0, lat: 1, lon: 0)
        XCTAssertEqual(n.east, 0, accuracy: 1e-6)
        XCTAssertEqual(n.north, GeoMath.earthRadiusMeters * .pi / 180, accuracy: 1e-3)
    }

    func testWiFiCoverageIDWAndBars() throws {
        XCTAssertEqual(WiFiCoverageMath.percent(0.73), 73, accuracy: 1e-9)
        XCTAssertEqual(WiFiCoverageMath.clampStrength(.nan), 0, accuracy: 1e-9)
        XCTAssertEqual(WiFiCoverageMath.clampStrength(.infinity), 0, accuracy: 1e-9)
        XCTAssertEqual(WiFiCoverageMath.clampStrength(-0.2), 0, accuracy: 1e-9)
        XCTAssertEqual(WiFiCoverageMath.clampStrength(1.4), 1, accuracy: 1e-9)
        XCTAssertEqual(WiFiCoverageMath.bars(.nan), 0)
        XCTAssertEqual(WiFiCoverageMath.bars(0), 0)
        XCTAssertEqual(WiFiCoverageMath.bars(0.1), 1)
        XCTAssertEqual(WiFiCoverageMath.bars(0.4), 2)
        XCTAssertEqual(WiFiCoverageMath.bars(0.6), 3)
        XCTAssertEqual(WiFiCoverageMath.bars(0.9), 4)
        let a = WiFiAmplitudeSample(east: 0, north: 0, strength: 1)
        let b = WiFiAmplitudeSample(east: 10, north: 0, strength: 0)
        XCTAssertEqual(WiFiCoverageMath.idw(east: 0, north: 0, samples: [a, b]), 1, accuracy: 1e-9)
        XCTAssertEqual(WiFiCoverageMath.idw(east: 5, north: 0, samples: [a, b]), 0.5, accuracy: 1e-9)
        XCTAssertTrue(WiFiCoverageMath.idw(east: 5, north: 0, samples: [a, b], power: .infinity).isNaN)
        XCTAssertTrue(WiFiCoverageMath.idw(east: 5, north: 0, samples: [a, b], power: .nan).isNaN)
        XCTAssertNil(WiFiCoverageMath.bounds([]))
        let box = try XCTUnwrap(WiFiCoverageMath.bounds([a, b], padding: 0))
        XCTAssertEqual(box.minE, 0, accuracy: 1e-9)
        XCTAssertEqual(box.maxE, 10, accuracy: 1e-9)
    }
}

final class HomeworkMathTests: XCTestCase {
    func testVoltageDividerVoutAndSolveR() throws {
        let r = try VoltageDivider.fromResistors(vin: 12, r1: 10_000, r2: 10_000)
        XCTAssertEqual(r.vout, 6, accuracy: 1e-9)
        XCTAssertEqual(r.current, 12 / 20_000, accuracy: 1e-12)
        let r2 = try VoltageDivider.solveR2(vin: 12, vout: 6, r1: 10_000)
        XCTAssertEqual(r2.r2, 10_000, accuracy: 1e-6)
        let r1 = try VoltageDivider.solveR1(vin: 12, vout: 6, r2: 10_000)
        XCTAssertEqual(r1.r1, 10_000, accuracy: 1e-6)
        XCTAssertThrowsError(try VoltageDivider.solveR2(vin: 5, vout: 5, r1: 1000))
    }

    func testSeriesParallelRAndC() throws {
        XCTAssertEqual(try SeriesParallel.resistors([10, 20], kind: .series), 30, accuracy: 1e-9)
        XCTAssertEqual(try SeriesParallel.resistors([100, 100], kind: .parallel), 50, accuracy: 1e-9)
        XCTAssertEqual(try SeriesParallel.capacitors([10e-6, 10e-6], kind: .parallel), 20e-6, accuracy: 1e-15)
        XCTAssertEqual(try SeriesParallel.capacitors([10e-6, 10e-6], kind: .series), 5e-6, accuracy: 1e-15)
        XCTAssertThrowsError(try SeriesParallel.resistors([10], kind: .series))
    }

    func testResistorColorDecodeEncode() throws {
        let four = try ResistorColorCode.decode4(d1: .yellow, d2: .violet, multiplier: .red, tolerance: .gold)
        XCTAssertEqual(four.ohms, 4700, accuracy: 1e-9)
        XCTAssertEqual(four.tolerancePercent, 5, accuracy: 1e-9)
        let encoded = try ResistorColorCode.encode(ohms: 4700, bands: 4, tolerance: .gold)
        XCTAssertEqual(encoded.bands, [.yellow, .violet, .red, .gold])
        let five = try ResistorColorCode.decode5(d1: .brown, d2: .black, d3: .black, multiplier: .brown, tolerance: .brown)
        XCTAssertEqual(five.ohms, 1_000, accuracy: 1e-9)
        XCTAssertEqual(try ResistorColorCode.encode(ohms: 10_000, bands: 4).bands.prefix(3).map(\.rawValue), ["brown", "black", "orange"])
        XCTAssertThrowsError(try ResistorColorCode.encode(ohms: 0.001, bands: 4))
        let rounded = try ResistorColorCode.encode(ohms: 99.6, bands: 4, tolerance: .gold)
        XCTAssertEqual(rounded.bands.prefix(3).map(\.rawValue), ["brown", "black", "brown"])
        XCTAssertEqual(rounded.ohms, 100, accuracy: 1e-9)
        XCTAssertThrowsError(try ResistorColorCode.decode4(d1: .gold, d2: .violet, multiplier: .red, tolerance: .gold))
    }

    func testUnitConvert() throws {
        XCTAssertEqual(try UnitConvert.si(value: 4.7, from: .kilo, to: .none), 4700, accuracy: 1e-9)
        XCTAssertEqual(try UnitConvert.voltageDB(ratio: 2), 20 * log10(2.0), accuracy: 1e-9)
        XCTAssertEqual(try UnitConvert.voltageRatio(fromDB: 6), pow(10, 6.0 / 20.0), accuracy: 1e-9)
        XCTAssertEqual(try UnitConvert.powerDB(ratio: 2), 10 * log10(2.0), accuracy: 1e-9)
        XCTAssertEqual(try UnitConvert.fahrenheit(fromCelsius: 0), 32, accuracy: 1e-9)
        XCTAssertEqual(try UnitConvert.celsius(fromFahrenheit: 32), 0, accuracy: 1e-9)
        XCTAssertEqual(try UnitConvert.meters(fromFeet: 1), 0.3048, accuracy: 1e-12)
        XCTAssertEqual(try UnitConvert.mm(fromMils: 1000), 25.4, accuracy: 1e-12)
        XCTAssertEqual(try UnitConvert.feet(fromMeters: 0.3048), 1, accuracy: 1e-12)
        XCTAssertEqual(try UnitConvert.mils(fromMM: 25.4), 1000, accuracy: 1e-12)
        XCTAssertEqual(try UnitConvert.powerRatio(fromDB: 3), pow(10, 0.3), accuracy: 1e-9)
    }

    func testFrequencyPeriodWavelengthAndLC() throws {
        let w = try Wave.fromFrequency(1e6)
        XCTAssertEqual(w.period, 1e-6, accuracy: 1e-18)
        XCTAssertEqual(w.wavelength, Wave.speedOfLight / 1e6, accuracy: 1e-6)
        let back = try Wave.fromPeriod(1e-6)
        XCTAssertEqual(back.frequency, 1e6, accuracy: 1e-3)
        let lc = try Wave.lcResonance(inductance: 100e-6, capacitance: 100e-12)
        let expected = 1 / (2 * Double.pi * sqrt(100e-6 * 100e-12))
        XCTAssertEqual(lc.frequency, expected, accuracy: 1e-3)
    }

    func testLEDAndRC() throws {
        let led = try LEDResistor.size(supply: 5, forward: 2, current: 0.01)
        XCTAssertEqual(led.resistance, 300, accuracy: 1e-9)
        XCTAssertEqual(led.power, 0.03, accuracy: 1e-9)
        XCTAssertEqual(LEDResistor.nearestE24(300), 300, accuracy: 1e-9)
        XCTAssertEqual(LEDResistor.nearestE24(310), 300, accuracy: 1e-9)
        XCTAssertEqual(LEDResistor.nearestE24(960), 1000, accuracy: 1e-9)
        let rc = try RCTime.tau(resistance: 10_000, capacitance: 100e-6)
        XCTAssertEqual(rc.tau, 1, accuracy: 1e-9)
        XCTAssertEqual(rc.fiveTau, 5, accuracy: 1e-9)
        XCTAssertThrowsError(try LEDResistor.size(supply: 2, forward: 2, current: 0.01))
    }
}

final class CalcErrorCopyTests: XCTestCase {
    func testMissingSaysHowToFix() {
        XCTAssertEqual(
            CalcError.missing("Vin").message,
            "Need Vin. Type a number — this tool will not guess a blank."
        )
    }

    func testNonPositiveSaysHowToFix() {
        XCTAssertEqual(
            CalcError.nonPositive("Current").message,
            "Current must be greater than zero. Zero, negatives, and empty are not usable here."
        )
    }

    func testNeedTwoOfThreeTellsYouToLeaveTheUnknownBlank() {
        XCTAssertEqual(
            CalcError.needTwoOfThree.message,
            "Enter any two of voltage, current, or resistance. Leave the one you want solved blank."
        )
    }

    func testOutOfRangeKeepsTheStoredDetail() {
        XCTAssertEqual(
            CalcError.outOfRange("Conductor quantity must be a whole number.").message,
            "Conductor quantity must be a whole number."
        )
    }
}
