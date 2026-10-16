import XCTest
@testable import BeckifyMath

final class DriveEstimatesTests: XCTestCase {
    func testNominalPackAndWheelConstants() {
        XCTAssertEqual(96 * 3.65, DriveEstimates.boltNominalPackVolts, accuracy: 0.5)
        let diameter = 17 * 0.0254 + 2 * 0.215 * 0.50
        XCTAssertEqual(diameter / 2, DriveEstimates.boltWheelRadiusMeters, accuracy: 0.005)
    }

    func testPackPowerSignAndRegen() {
        XCTAssertEqual(DriveEstimates.packPowerKW(amps: 100), 35)
        XCTAssertEqual(DriveEstimates.packPowerKW(amps: -40), -14)
        XCTAssertNil(DriveEstimates.packPowerKW(amps: nil))
        XCTAssertNil(DriveEstimates.packPowerKW(amps: .nan))
        XCTAssertEqual(DriveEstimates.regenPowerKW(amps: -40), 14)
        XCTAssertNil(DriveEstimates.regenPowerKW(amps: 40), "drive is not regen")
        XCTAssertNil(DriveEstimates.regenPowerKW(amps: nil))
    }

    func testTorqueFromPowerAndSpeed() {
        // 35 kW at 72 km/h (20 m/s) on a 0.32 m wheel: 35000 × 0.32 / 20 = 560 N·m.
        XCTAssertEqual(DriveEstimates.wheelTorqueNm(powerKW: 35, speedKph: 72) ?? 0, 560, accuracy: 0.001)
        XCTAssertEqual(DriveEstimates.wheelTorqueNm(powerKW: -14, speedKph: 72) ?? 0, -224, accuracy: 0.001)
        XCTAssertNil(DriveEstimates.wheelTorqueNm(powerKW: 35, speedKph: 10.7), "under 3 m/s shows a dash")
        XCTAssertNotNil(DriveEstimates.wheelTorqueNm(powerKW: 35, speedKph: 10.8))
        XCTAssertNil(DriveEstimates.wheelTorqueNm(powerKW: nil, speedKph: 72))
        XCTAssertNil(DriveEstimates.wheelTorqueNm(powerKW: 35, speedKph: nil))
    }

    func testPowerAndTorqueUnits() {
        XCTAssertEqual(DrivePowerUnit.horsepower.convert(kilowatts: 150), 201.15, accuracy: 0.01)
        XCTAssertEqual(DrivePowerUnit.kilowatts.convert(kilowatts: 150), 150)
        XCTAssertEqual(DriveTorqueUnit.poundFeet.convert(newtonMeters: 360), 265.52, accuracy: 0.01)
        XCTAssertEqual(DriveTorqueUnit.newtonMeters.label, "Nm")
        let metric = DriveUnitPreference.systemDefault(measurementSystem: "metric")
        XCTAssertEqual(metric.power, .kilowatts)
        XCTAssertEqual(metric.torque, .newtonMeters)
    }

    func testCarPlayPowerCopyIsLabeledEstimate() {
        XCTAssertEqual(DrivePresentation.powerEstimateCopy(amps: 100), "35 kW est.")
        XCTAssertEqual(DrivePresentation.powerEstimateCopy(amps: -40), "Regen 14 kW est.")
        XCTAssertNil(DrivePresentation.powerEstimateCopy(amps: nil))
        var book = OBDReadingBook()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        book.write(.hvCurrentAmps, value: 100, at: now)
        let generic = DrivePresentationBuilder.make(
            profile: .generic, book: book, now: now,
            planning: PlanningInputs(usableKWh: nil, whPerMile: nil), trip: OBDTripTrack(), link: "Live"
        )
        XCTAssertEqual(generic.carPlay.power, "Not read", "no Bolt pack assumption on a generic car")
    }
}

final class EfficiencyTrackerTests: XCTestCase {
    func testWhPerMileNeedsARealDropAndDistance() {
        var tracker = EfficiencyTracker()
        tracker.update(socPercent: 80, gpsMiles: 10)
        tracker.update(socPercent: 79.6, gpsMiles: 12)
        XCTAssertNil(tracker.whPerMile(packKWh: 65), "0.4 % is one display step")
        tracker.update(socPercent: 76, gpsMiles: 25)
        // 4 % of 65 kWh = 2.6 kWh over 15 mi = 173 Wh/mi.
        XCTAssertEqual(tracker.whPerMile(packKWh: 65) ?? 0, 173.33, accuracy: 0.01)
        XCTAssertNil(tracker.whPerMile(packKWh: nil), "needs a typed pack size")
        tracker.update(socPercent: nil, gpsMiles: 30)
        XCTAssertEqual(tracker.miles, 15)
        tracker.reset()
        XCTAssertNil(tracker.socDropPercent)
    }

    func testRisingChargeGivesNoEfficiency() {
        var tracker = EfficiencyTracker()
        tracker.update(socPercent: 50, gpsMiles: 0)
        tracker.update(socPercent: 55, gpsMiles: 5)
        XCTAssertNil(tracker.whPerMile(packKWh: 65))
    }
}

final class RegenScoreTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testFullStopWithRegen() {
        var tracker = RegenScoreTracker(massKg: 1_000, packVolts: 350)
        // 72 → 0 km/h over 10 s: ½ × 1000 × 20² = 200 kJ shed.
        for second in 0...10 {
            let kph = 72 - 7.2 * Double(second)
            tracker.add(speedKph: kph, amps: -20, at: start.addingTimeInterval(Double(second)))
        }
        XCTAssertEqual(tracker.decelJoules, 200_000, accuracy: 1)
        // 350 V × 20 A × 10 s = 70 kJ back.
        XCTAssertEqual(tracker.regenJoules, 70_000, accuracy: 1)
        XCTAssertEqual(tracker.score ?? 0, 0.35, accuracy: 0.001)
    }

    func testNoScoreUntilEnoughBrakingAndCapped() {
        var tracker = RegenScoreTracker(massKg: 1_000, packVolts: 350)
        tracker.add(speedKph: 20, amps: -50, at: start)
        tracker.add(speedKph: 18, amps: -50, at: start.addingTimeInterval(1))
        XCTAssertNil(tracker.score)
        var hot = RegenScoreTracker(massKg: 200, packVolts: 350)
        hot.add(speedKph: 100, amps: -300, at: start)
        hot.add(speedKph: 50, amps: -300, at: start.addingTimeInterval(5))
        XCTAssertEqual(hot.score, 1, "the estimate can overshoot; capped")
    }

    func testGapsAndAccelerationAddNothing() {
        var tracker = RegenScoreTracker()
        tracker.add(speedKph: 100, amps: -50, at: start)
        tracker.add(speedKph: 0, amps: -50, at: start.addingTimeInterval(30))
        XCTAssertEqual(tracker.decelJoules, 0)
        tracker.add(speedKph: 50, amps: 100, at: start.addingTimeInterval(31))
        XCTAssertEqual(tracker.decelJoules, 0)
        tracker.add(speedKph: nil, amps: 100, at: start.addingTimeInterval(32))
        tracker.add(speedKph: 40, amps: -10, at: start.addingTimeInterval(33))
        XCTAssertEqual(tracker.decelJoules, 0, "unknown speed breaks the chain")
    }
}

final class TripEnergyLedgerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testBuckets() {
        var ledger = TripEnergyLedger(massKg: 1_000, packVolts: 400)
        ledger.add(amps: 0, speedKph: 50, altitudeMeters: 100, at: start)
        // 10 s driving at 100 A, climbing 10 m: 400 kJ out, 98 kJ climb.
        for second in 1...10 {
            ledger.add(amps: 100, speedKph: 50, altitudeMeters: 100 + Double(second), at: start.addingTimeInterval(Double(second)))
        }
        // 10 s stopped at 10 A: 40 kJ.
        for second in 11...20 {
            ledger.add(amps: 10, speedKph: 0, altitudeMeters: 110, at: start.addingTimeInterval(Double(second)))
        }
        // 5 s regen at −50 A: 100 kJ back.
        for second in 21...25 {
            ledger.add(amps: -50, speedKph: 30, altitudeMeters: 110, at: start.addingTimeInterval(Double(second)))
        }
        XCTAssertEqual(ledger.movingJoules, 400_000, accuracy: 1)
        XCTAssertEqual(ledger.climbJoules, 1_000 * DriveEstimates.gravity * 10, accuracy: 1)
        XCTAssertEqual(ledger.stoppedKWh, 40_000 / 3.6e6, accuracy: 1e-9)
        XCTAssertEqual(ledger.regenKWh, 100_000 / 3.6e6, accuracy: 1e-9)
        XCTAssertEqual(ledger.drivingKWh + ledger.climbKWh, 400_000 / 3.6e6, accuracy: 1e-9)
        XCTAssertEqual(ledger.netKWh, 340_000 / 3.6e6, accuracy: 1e-9)
        XCTAssertFalse(ledger.isEmpty)
    }

    func testClimbNeverExceedsMovingEnergyAndGapsDrop() {
        var ledger = TripEnergyLedger(massKg: 1_000, packVolts: 400)
        ledger.add(amps: 1, speedKph: 50, altitudeMeters: 0, at: start)
        ledger.add(amps: 1, speedKph: 50, altitudeMeters: 100, at: start.addingTimeInterval(1))
        XCTAssertEqual(ledger.climbKWh, ledger.movingJoules / 3.6e6, accuracy: 1e-12)
        XCTAssertEqual(ledger.drivingKWh, 0)
        let before = ledger.movingJoules
        ledger.add(amps: 100, speedKph: 50, altitudeMeters: 100, at: start.addingTimeInterval(60))
        XCTAssertEqual(ledger.movingJoules, before, "60 s gap adds nothing")
        ledger.reset()
        XCTAssertTrue(ledger.isEmpty)
    }
}

final class RangeWeatherModelTests: XCTestCase {
    func testTemperatureCurveFromAAA() {
        XCTAssertEqual(RangeWeatherModel.temperatureFraction(celsius: (75 - 32) * 5 / 9) ?? 9, 0, accuracy: 1e-9)
        XCTAssertEqual(RangeWeatherModel.temperatureFraction(celsius: (20 - 32) * 5 / 9) ?? 9, -0.41, accuracy: 1e-9)
        XCTAssertEqual(RangeWeatherModel.temperatureFraction(celsius: (95 - 32) * 5 / 9) ?? 9, -0.17, accuracy: 1e-9)
        XCTAssertEqual(RangeWeatherModel.temperatureFraction(celsius: -30) ?? 9, -0.41, accuracy: 1e-9, "held flat outside the test")
        let midway = RangeWeatherModel.temperatureFraction(celsius: (47.5 - 32) * 5 / 9) ?? 9
        XCTAssertEqual(midway, -0.205, accuracy: 1e-9)
        XCTAssertNil(RangeWeatherModel.temperatureFraction(celsius: nil))
    }

    func testHeadwindComponent() {
        XCTAssertEqual(RangeWeatherModel.headwindMps(windSpeedMps: 10, windFromDegrees: 0, courseDegrees: 0) ?? 0, 10, accuracy: 1e-9)
        XCTAssertEqual(RangeWeatherModel.headwindMps(windSpeedMps: 10, windFromDegrees: 180, courseDegrees: 0) ?? 0, -10, accuracy: 1e-9)
        XCTAssertEqual(RangeWeatherModel.headwindMps(windSpeedMps: 10, windFromDegrees: 90, courseDegrees: 0) ?? 9, 0, accuracy: 1e-9)
        XCTAssertNil(RangeWeatherModel.headwindMps(windSpeedMps: 10, windFromDegrees: 0, courseDegrees: -1))
    }

    func testHeadwindCutsRangeTailwindAddsIt() {
        let head = RangeWeatherModel.headwindFraction(speedKph: 105, headwindMps: 5) ?? 0
        let tail = RangeWeatherModel.headwindFraction(speedKph: 105, headwindMps: -5) ?? 0
        XCTAssertLessThan(head, -0.05)
        XCTAssertGreaterThan(head, -0.35)
        XCTAssertGreaterThan(tail, 0.05)
        XCTAssertEqual(RangeWeatherModel.headwindFraction(speedKph: 105, headwindMps: 0) ?? 9, 0, accuracy: 1e-12)
        XCTAssertNil(RangeWeatherModel.headwindFraction(speedKph: 15, headwindMps: 5), "too slow to matter")
    }

    func testAdjustmentCombines() {
        let adjustment = RangeWeatherModel.adjust(baseMiles: 200, celsius: 75.0.fahrenheitToCelsius, speedKph: 10, headwindMps: 5)
        XCTAssertEqual(adjustment?.adjustedMiles ?? 0, 200, accuracy: 1e-6)
        XCTAssertNil(adjustment?.headwindFraction)
        let cold = RangeWeatherModel.adjust(baseMiles: 200, celsius: -10, speedKph: 105, headwindMps: 0)
        XCTAssertEqual(cold?.adjustedMiles ?? 0, 118, accuracy: 1e-6)
        XCTAssertNil(RangeWeatherModel.adjust(baseMiles: nil, celsius: 10, speedKph: 100, headwindMps: 1))
        XCTAssertNil(RangeWeatherModel.adjust(baseMiles: 200, celsius: nil, speedKph: 10, headwindMps: nil))
    }
}

private extension Double {
    var fahrenheitToCelsius: Double { (self - 32) * 5 / 9 }
}

final class OpenMeteoTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testRequestRoundsCoordinates() {
        let url = OpenMeteoCurrent.requestURL(latitude: 42.336_123, longitude: -83.049_876)?.absoluteString ?? ""
        XCTAssertTrue(url.hasPrefix("https://api.open-meteo.com/v1/forecast?"))
        XCTAssertTrue(url.contains("latitude=42.34"))
        XCTAssertTrue(url.contains("longitude=-83.05"))
        XCTAssertFalse(url.contains("42.336"))
        XCTAssertTrue(url.contains("wind_speed_unit=ms"))
        XCTAssertNil(OpenMeteoCurrent.requestURL(latitude: 95, longitude: 0))
    }

    func testDecode() {
        let json = """
        {"latitude":42.34,"longitude":-83.05,"current_units":{"temperature_2m":"°C"},
         "current":{"time":"2026-10-12T14:00","interval":900,"temperature_2m":8.4,"wind_speed_10m":6.2,"wind_direction_10m":250}}
        """
        let current = OpenMeteoCurrent.decode(Data(json.utf8), fetchedAt: now)
        XCTAssertEqual(current?.temperatureC, 8.4)
        XCTAssertEqual(current?.windSpeedMps, 6.2)
        XCTAssertEqual(current?.windFromDegrees, 250)
        XCTAssertEqual(current?.fetchedAt, now)
        XCTAssertNil(OpenMeteoCurrent.decode(Data("{}".utf8), fetchedAt: now))
        XCTAssertNil(OpenMeteoCurrent.decode(Data(#"{"latitude":1,"longitude":1,"current":{"temperature_2m":1,"wind_speed_10m":-1,"wind_direction_10m":10}}"#.utf8), fetchedAt: now))
    }

    func testRefreshAndStaleness() {
        let current = OpenMeteoCurrent(temperatureC: 8, windSpeedMps: 3, windFromDegrees: 90, fetchedAt: now, latitude: 42.34, longitude: -83.05)
        XCTAssertFalse(current.needsRefresh(now: now.addingTimeInterval(60), latitude: 42.34, longitude: -83.05))
        XCTAssertTrue(current.needsRefresh(now: now.addingTimeInterval(16 * 60), latitude: 42.34, longitude: -83.05))
        XCTAssertTrue(current.needsRefresh(now: now, latitude: 42.45, longitude: -83.05), "about 12 km north")
        XCTAssertTrue(current.isUsable(now: now.addingTimeInterval(2 * 3600)))
        XCTAssertFalse(current.isUsable(now: now.addingTimeInterval(4 * 3600)))
        XCTAssertEqual(OpenMeteoCurrent.distanceKm(0, 0, 1, 0), 111.19, accuracy: 0.01)
    }
}

final class DriveInsightMathTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testSlope() {
        XCTAssertEqual(TrendMath.slope([(0, 1), (1, 3), (2, 5)]) ?? 0, 2, accuracy: 1e-9)
        XCTAssertNil(TrendMath.slope([(1, 1), (1, 2)]))
        XCTAssertNil(TrendMath.slope([(0, 1)]))
        var buffer = SparklineBuffer()
        for second in 0..<60 {
            buffer.append(10 + Double(second) / 30, at: start.addingTimeInterval(Double(second)))
        }
        XCTAssertEqual(TrendMath.slopePerMinute(buffer.points) ?? 0, 2, accuracy: 1e-9)
        XCTAssertNil(TrendMath.slopePerMinute(Array(buffer.points.prefix(10))), "under 30 s of data")
    }

    func testPreconditionAdvice() {
        XCTAssertEqual(PreconditionCoach.advice(packC: 20, trendPerMinute: nil), .inWindow)
        XCTAssertEqual(PreconditionCoach.advice(packC: nil, trendPerMinute: 1), .unknown)
        XCTAssertEqual(PreconditionCoach.advice(packC: 1, trendPerMinute: 0.4), .belowWindow(degrees: 4, minutes: 10))
        XCTAssertEqual(PreconditionCoach.advice(packC: 1, trendPerMinute: -0.2), .belowWindow(degrees: 4, minutes: nil), "cooling: no ETA")
        XCTAssertEqual(PreconditionCoach.advice(packC: 1, trendPerMinute: 0.01), .belowWindow(degrees: 4, minutes: nil), "too slow to read")
        XCTAssertEqual(PreconditionCoach.advice(packC: 48, trendPerMinute: -0.5), .aboveWindow(degrees: 3, minutes: 6))
        XCTAssertEqual(PreconditionCoach.advice(packC: 48, trendPerMinute: 0.5), .aboveWindow(degrees: 3, minutes: nil))
    }

    func testGradeFromAltitudeAndDistance() {
        var grade = GradeEstimator()
        for meter in stride(from: 0.0, through: 30, by: 5) {
            grade.add(distanceMeters: meter, altitudeMeters: meter * 0.05)
        }
        XCTAssertNil(grade.gradePercent, "under 40 m")
        for meter in stride(from: 35.0, through: 300, by: 5) {
            grade.add(distanceMeters: meter, altitudeMeters: meter * 0.05)
        }
        XCTAssertEqual(grade.gradePercent ?? 0, 5, accuracy: 1e-6)
        grade.add(distanceMeters: 300.5, altitudeMeters: 999)
        XCTAssertEqual(grade.gradePercent ?? 0, 5, accuracy: 1e-6, "under 1 m of travel is skipped")
        grade.add(distanceMeters: 305, altitudeMeters: nil)
        grade.reset()
        for meter in stride(from: 0.0, through: 100, by: 5) {
            grade.add(distanceMeters: meter, altitudeMeters: meter * 0.6)
        }
        XCTAssertNil(grade.gradePercent, "60 % is altimeter noise, not a road")
        grade.add(distanceMeters: 10, altitudeMeters: 0)
        XCTAssertNil(grade.gradePercent, "a distance reset clears the window")
    }

    func testCapacityLogOnePerDayAndTrend() {
        var log = CapacityLog()
        let day: TimeInterval = 86_400
        log.record(ampHours: 166, at: start)
        log.record(ampHours: 165.8, at: start.addingTimeInterval(3_600))
        XCTAssertEqual(log.entries.count, 1)
        XCTAssertEqual(log.entries.first?.ampHours, 165.8)
        log.record(ampHours: 400, at: start.addingTimeInterval(day))
        XCTAssertEqual(log.entries.count, 1, "implausible Ah ignored")
        XCTAssertNil(log.ampHoursPerYear)
        for month in 1...12 {
            log.record(ampHours: 165.8 - Double(month) * 0.25, at: start.addingTimeInterval(Double(month) * 30.4375 * day))
        }
        XCTAssertEqual(log.ampHoursPerYear ?? 0, -3, accuracy: 0.05)
        XCTAssertEqual(log.percentSinceFirst ?? 0, -3 / 165.8 * 100, accuracy: 0.01)
        let restored = CapacityLog.decoded(from: log.encoded())
        XCTAssertEqual(restored, log)
        XCTAssertEqual(CapacityLog.decoded(from: Data("x".utf8)), CapacityLog())
    }
}

final class DriveCarPlayExtrasTests: XCTestCase {
    func testCopy() {
        let regen = DriveCarPlayExtras.make(flow: .regen, powerKW: -14.2, whPerMile: 271.6, weatherRangeMiles: 182.4)
        XCTAssertEqual(regen, DriveCarPlayExtras(regen: "Regen 14 kW est.", efficiency: "272 Wh/mi est.", weatherRange: "182 mi est."))
        XCTAssertEqual(DriveCarPlayExtras.make(flow: .drive, powerKW: 30, whPerMile: nil, weatherRangeMiles: nil),
                       DriveCarPlayExtras(regen: "Drive", efficiency: "Not read", weatherRange: "Not read"))
        XCTAssertEqual(DriveCarPlayExtras.make(flow: nil, powerKW: nil, whPerMile: nil, weatherRangeMiles: nil), .unknown)
        XCTAssertEqual(DriveCarPlayExtras.make(flow: .idle, powerKW: 0, whPerMile: nil, weatherRangeMiles: nil).regen, "Idle")
    }
}

final class CarPlayUnitsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let metric = DriveUnitPreference.systemDefault(measurementSystem: "metric")
    private let us = DriveUnitPreference.systemDefault(measurementSystem: "us")

    private func book() -> OBDReadingBook {
        var book = OBDReadingBook()
        book.write(.displayedSocPercent, value: 80, at: now)
        book.write(.speedKph, value: 100, at: now)
        book.write(.packTempC, value: 22, at: now)
        book.write(.hvCurrentAmps, value: -40, at: now)
        return book
    }

    private func carPlay(_ units: DriveUnitPreference) -> DriveCarPlayCopy {
        DrivePresentationBuilder.make(
            profile: .boltEV, book: book(), now: now,
            planning: PlanningInputs(usableKWh: 65, whPerMile: 250),
            trip: OBDTripTrack(), link: "Live", units: units
        ).carPlay
    }

    func testMetricRegion() {
        let copy = carPlay(metric)
        XCTAssertEqual(copy.speed, "100 km/h")
        XCTAssertEqual(copy.range, "335 km planning")
        XCTAssertEqual(copy.temperature, "Pack 22°C")
        XCTAssertEqual(copy.power, "Regen 14 kW est.")
        let extras = DriveCarPlayExtras.make(flow: .regen, powerKW: -14, whPerMile: 250, weatherRangeMiles: 100, units: metric)
        XCTAssertEqual(extras, DriveCarPlayExtras(regen: "Regen 14 kW est.", efficiency: "155 Wh/km est.", weatherRange: "161 km est."))
    }

    func testUSRegion() {
        let copy = carPlay(us)
        XCTAssertEqual(copy.speed, "62 mph")
        XCTAssertEqual(copy.range, "208 mi planning")
        XCTAssertEqual(copy.temperature, "Pack 72°F")
        XCTAssertEqual(copy.power, "Regen 19 hp est.")
        let extras = DriveCarPlayExtras.make(flow: .regen, powerKW: -14, whPerMile: 250, weatherRangeMiles: 100, units: us)
        XCTAssertEqual(extras, DriveCarPlayExtras(regen: "Regen 19 hp est.", efficiency: "250 Wh/mi est.", weatherRange: "100 mi est."))
    }

    func testUKRegionIsMphAndCelsius() {
        let copy = carPlay(DriveUnitPreference.systemDefault(measurementSystem: "uk"))
        XCTAssertEqual(copy.speed, "62 mph")
        XCTAssertEqual(copy.temperature, "Pack 22°C")
    }
}

final class VehicleSpecAndGenericEVTests: XCTestCase {
    func testProfilesMapToLayoutsAndSpecs() {
        XCTAssertEqual(VehicleProfile.generic.dashboardLayout, .powertrain)
        XCTAssertEqual(VehicleProfile.genericEV.dashboardLayout, .evStandard)
        XCTAssertEqual(VehicleProfile.boltEV.dashboardLayout, .ev)
        XCTAssertEqual(VehicleProfile.boltEUV.dashboardLayout, .ev)
        XCTAssertNil(VehicleProfile.genericEV.spec, "no estimates without a vehicle spec")
        XCTAssertNil(VehicleProfile.generic.spec)
        XCTAssertEqual(VehicleProfile.boltEUV.spec, .bolt)
        XCTAssertFalse(VehicleProfile.genericEV.usesBoltPIDs)
        XCTAssertEqual(VehicleProfile.genericEV.nominalPackChoicesKWh, [])
    }

    func testGenericEVPollsStandardPIDsOnly() {
        let cycle = OBDCommandPlan.liveCycle(profile: .genericEV, support: OBDSupportMap())
        XCTAssertEqual(cycle, OBDCommandPlan.liveCycle(profile: .generic, support: OBDSupportMap()))
        XCTAssertFalse(cycle.contains { $0.hasPrefix("22") || $0.hasPrefix("ATSH") })
    }

    func testGenericEVCardsAreEVRelevant() {
        let layout = DashboardLayout.standard
        let vehicle = layout.cards(in: .vehicle, for: .evStandard)
        XCTAssertEqual(vehicle, [.ambient, .moduleVolts, .remainingLife])
        XCTAssertEqual(DashboardSection.sections(for: .evStandard), [.vehicle, .phone])
        for card in [DashboardCardID.fuel, .coolant, .engineLoad, .throttle, .hvCurrent, .efficiency, .packTemp] {
            XCTAssertNil(card.section(for: .evStandard), "\(card) needs fuel, an engine, or Bolt PIDs")
        }
        XCTAssertEqual(DashboardCardID.remainingLife.section(for: .powertrain), .vehicle, "hybrids answer 015B too")
        XCTAssertNil(DashboardCardID.remainingLife.section(for: .ev), "Bolt shows remaining life (HD) instead")
    }

    func testSpecLabelsAndWeatherUseSpec() {
        let bolt = VehicleSpec.bolt
        XCTAssertEqual(bolt.voltsLabel, "350 V")
        XCTAssertEqual(bolt.wheelLabel, "0.32 m")
        XCTAssertEqual(bolt.massLabel, "1,696 kg")
        var heavy = bolt
        heavy.massKg = 3_000
        heavy.dragCoefficient = 0.40
        heavy.frontalAreaM2 = 3.2
        let boltWind = RangeWeatherModel.adjust(baseMiles: 200, celsius: nil, speedKph: 100, headwindMps: 6, spec: bolt)?.headwindFraction ?? 0
        let heavyWind = RangeWeatherModel.adjust(baseMiles: 200, celsius: nil, speedKph: 100, headwindMps: 6, spec: heavy)?.headwindFraction ?? 0
        XCTAssertLessThan(boltWind, 0)
        XCTAssertNotEqual(boltWind, heavyWind, accuracy: 0.001)
        XCTAssertEqual(boltWind, RangeWeatherModel.headwindFraction(speedKph: 100, headwindMps: 6) ?? 9, accuracy: 1e-12, "Bolt default unchanged")
    }
}

final class SparklineScaleTests: XCTestCase {
    func testTinyRippleDoesNotFillTheCard() {
        let domain = SparklineScale.domain(values: [14.27, 14.33, 14.30])
        XCTAssertNotNil(domain)
        XCTAssertEqual(domain!.upperBound - domain!.lowerBound, 1, accuracy: 1e-9, "1 V floor beats 5 % of 14.3 V")
        XCTAssertTrue(domain!.contains(14.27) && domain!.contains(14.33))
        let warm = SparklineScale.domain(values: [180, 181])!
        XCTAssertEqual(warm.upperBound - warm.lowerBound, 9.025, accuracy: 1e-9, "5 % of 180.5")
    }

    func testRealSwingsAndBaselineKept() {
        XCTAssertEqual(SparklineScale.domain(values: [40, 140]), 40...140)
        XCTAssertEqual(SparklineScale.domain(values: [40, 140], baseline: 0), 0...140)
        XCTAssertEqual(SparklineScale.domain(values: [-62, -20], baseline: 0), -62...0)
        XCTAssertNil(SparklineScale.domain(values: []))
        XCTAssertNil(SparklineScale.domain(values: [.nan]))
    }
}

final class RamProfileTests: XCTestCase {
    func testRamIsICEPowertrainOnStandardPIDs() {
        let ram = VehicleProfile.ram1500_2026
        XCTAssertEqual(ram.title, "Ram 1500 2026")
        XCTAssertEqual(ram.dashboardLayout, .powertrain)
        XCTAssertFalse(ram.usesBoltPIDs)
        XCTAssertTrue(ram.nominalPackChoicesKWh.isEmpty)
        XCTAssertNil(ram.spec)
        XCTAssertNil(DrivePlanning.defaults(for: ram))
        XCTAssertTrue(VehicleProfile.allCases.contains(ram))
    }

    func testRamNeverGetsEVRange() {
        let typed = PlanningInputs(usableKWh: nil, whPerMile: nil)
        let effective = DrivePlanning.effective(typed: typed, profile: .ram1500_2026, measuredWhPerMile: nil)
        XCTAssertNil(effective.inputs.usableKWh)
        XCTAssertNil(effective.inputs.whPerMile)
        XCTAssertFalse(effective.usesDefaults)
    }

    func testRamLiveCycleHasNoMode22() {
        let cycle = OBDCommandPlan.liveCycle(profile: .ram1500_2026, support: OBDSupportMap())
        XCTAssertTrue(cycle.allSatisfy { !$0.hasPrefix("22") && !$0.hasPrefix("AT") })
        XCTAssertEqual(cycle.first, "010D")
    }

    func testRamFactsLeaveTrimSpecificValuesUnset() throws {
        let facts = try XCTUnwrap(VehicleProfile.ram1500_2026.facts)
        XCTAssertNil(facts.massKg)
        XCTAssertNil(facts.dragCoefficient)
        XCTAssertEqual(facts.curbWeightRangeLb, 4_820...6_440)
        XCTAssertTrue(facts.tireSizes.contains("275/65R18"))
        XCTAssertTrue(facts.sources.allSatisfy { $0.hasPrefix("https://") })
        XCTAssertNil(VehicleProfile.boltEV.facts)
    }

    func testProfileRawValueRoundTrips() {
        XCTAssertEqual(VehicleProfile(rawValue: "ram1500_2026"), .ram1500_2026)
    }
}

final class GaugeLayoutMathTests: XCTestCase {
    func testPortraitHeroFillsWidth() {
        // iPhone 15 Pro portrait viewport.
        XCTAssertEqual(GaugeLayoutMath.heroDiameter(width: 393, height: 760), 361, accuracy: 0.5)
    }

    func testPortraitHeroCappedByHeight() {
        // iPad portrait: height cap wins.
        XCTAssertEqual(GaugeLayoutMath.heroDiameter(width: 820, height: 1000), 550, accuracy: 0.5)
    }

    func testLandscapeHeroUsesHeight() {
        XCTAssertEqual(GaugeLayoutMath.heroDiameter(width: 852, height: 350), 318, accuracy: 0.5)
    }

    func testHeroBoundsOnSmallAndHugeScreens() {
        XCTAssertEqual(GaugeLayoutMath.heroDiameter(width: 320, height: 200), GaugeLayoutMath.minDiameter)
        XCTAssertEqual(GaugeLayoutMath.heroDiameter(width: 3000, height: 4000), GaugeLayoutMath.maxDiameter)
        XCTAssertEqual(GaugeLayoutMath.heroDiameter(width: .nan, height: 100), GaugeLayoutMath.minDiameter)
    }

    func testColumns() {
        XCTAssertEqual(GaugeLayoutMath.columnCount(width: 320, minCell: 170, spacing: 12), 1)
        XCTAssertEqual(GaugeLayoutMath.columnCount(width: 361, minCell: 170, spacing: 12), 2)
        XCTAssertEqual(GaugeLayoutMath.columnCount(width: 1000, minCell: 240, spacing: 12), 4)
        XCTAssertEqual(GaugeLayoutMath.columnCount(width: 0, minCell: 170, spacing: 12), 1)
    }

    func testMinCellWidth() {
        XCTAssertEqual(GaugeLayoutMath.minCellWidth(containerWidth: 361, accessibilitySize: false), 170)
        XCTAssertEqual(GaugeLayoutMath.minCellWidth(containerWidth: 900, accessibilitySize: false), 240)
        XCTAssertEqual(GaugeLayoutMath.minCellWidth(containerWidth: 361, accessibilitySize: true), 361)
    }

    func testRowSizesLeaveNoBlankCells() {
        XCTAssertEqual(GaugeLayoutMath.rowSizes(count: 5, columns: 2), [2, 2, 1])
        XCTAssertEqual(GaugeLayoutMath.rowSizes(count: 6, columns: 3), [3, 3])
        XCTAssertEqual(GaugeLayoutMath.rowSizes(count: 0, columns: 2), [])
        XCTAssertEqual(GaugeLayoutMath.rowSizes(count: 3, columns: 0), [1, 1, 1])
    }

    func testValueSizesClamp() {
        XCTAssertEqual(GaugeLayoutMath.cardValueSize(cardWidth: 100, scale: 1), 34)
        XCTAssertEqual(GaugeLayoutMath.cardValueSize(cardWidth: 500, scale: 1), 84)
        XCTAssertEqual(GaugeLayoutMath.cardValueSize(cardWidth: 170, scale: 3), 51 * 1.3, accuracy: 0.01)
        XCTAssertEqual(GaugeLayoutMath.heroSpeedSize(diameter: 300, scale: 1), 102, accuracy: 0.01)
    }

    func testEVDigitHeights() {
        XCTAssertEqual(GaugeLayoutMath.powerDigitHeight(cardWidth: 200, scale: 1), 58)
        XCTAssertEqual(GaugeLayoutMath.powerDigitHeight(cardWidth: 361, scale: 1), 93.86, accuracy: 0.01)
        XCTAssertEqual(GaugeLayoutMath.powerDigitHeight(cardWidth: 2000, scale: 1), 150)
        XCTAssertEqual(GaugeLayoutMath.torqueDigitHeight(cardWidth: 361, scale: 1), 57.76, accuracy: 0.01)
        XCTAssertEqual(GaugeLayoutMath.torqueDigitHeight(cardWidth: 100, scale: 2), 52, accuracy: 0.01)
    }
}
