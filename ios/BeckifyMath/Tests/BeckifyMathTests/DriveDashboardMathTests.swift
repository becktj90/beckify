import XCTest
@testable import BeckifyMath

final class DriveSignalTableTests: XCTestCase {
    func testEveryReportedRowDecodesLikeOBDDecode() {
        let bytes: [UInt8] = [0x06, 0x72]
        let hex = bytes.map { String(format: "%02X", $0) }.joined()
        for row in DriveSignalTable.all where row.isReported {
            guard let request = row.request, let reading = row.reading, let decode = row.decode else {
                return XCTFail("\(row.id) claims reported without a request")
            }
            let reply: String
            if request.hasPrefix("01") {
                reply = "41" + request.dropFirst(2) + hex
            } else {
                reply = "62" + request.dropFirst(2) + hex
            }
            guard case .readings(let values) = OBDDecode.interpret(command: request, reply: reply) else {
                return XCTFail("\(row.id): OBDDecode ignored \(reply)")
            }
            guard let expected = values[reading], let actual = decode(bytes) else {
                return XCTFail("\(row.id): missing value")
            }
            XCTAssertEqual(actual, expected, accuracy: 0.000_1, row.id)
            XCTAssertTrue(row.accepts(actual), "\(row.id) fixture should be in range")
        }
    }

    func testEVFormulasMatchPublishedScales() {
        func value(_ id: String, _ bytes: [UInt8]) -> Double? {
            DriveSignalTable.definition(id: id)?.decode?(bytes)
        }
        XCTAssertEqual(value("soc", [0xCC]) ?? -1, 80, accuracy: 0.001)
        XCTAssertEqual(value("packTemp", [0x50]), 40)
        XCTAssertEqual(value("hvCurrent", [0x03, 0xE8]), 50)
        XCTAssertEqual(value("hvCurrent", [0xFF, 0x9C]), -5)
        XCTAssertEqual(value("capacity", [0x06, 0x72]), 165)
        XCTAssertEqual(value("lifeHD", [0xFF, 0xFF]) ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(value("motorTemp", [0x4A]), 34)
        XCTAssertEqual(value("moduleVolts", [0x36, 0xB0]), 14)
        XCTAssertNil(value("capacity", [0x06]), "short payload must not invent a number")
        XCTAssertNil(value("soc", []))
    }

    func testEVRowsUseThePublishedHeaders() {
        let headers = Dictionary(uniqueKeysWithValues: DriveSignalTable.ev.compactMap { row in
            row.header.map { (row.id, $0) }
        })
        XCTAssertEqual(headers["soc"], "7E4")
        XCTAssertEqual(headers["packTemp"], "7E4")
        XCTAssertEqual(headers["capacity"], "7E4")
        XCTAssertEqual(headers["lifeHD"], "7E4")
        XCTAssertEqual(headers["hvCurrent"], "7E1")
        XCTAssertEqual(headers["motorTemp"], "7E1")
    }

    func testPowerElectronicsPlaceholdersSendNothing() {
        for id in ["inverterTemp", "dcdcOutput", "charger"] {
            guard let row = DriveSignalTable.definition(id: id) else { return XCTFail(id) }
            XCTAssertFalse(row.isReported, id)
            XCTAssertNil(row.request, id)
            XCTAssertNil(row.decode, id)
            XCTAssertEqual(row.group, .powerElectronics)
        }
    }

    func testNoTractionPowerOrPackVoltageRow() {
        let names = DriveSignalTable.all.map { $0.name.lowercased() }
        XCTAssertFalse(names.contains { $0.contains("kw") || $0.contains("pack voltage") })
    }

    func testTableHooksLeaveTheBoltCycleUnchanged() {
        let cycle = OBDCommandPlan.liveCycle(profile: .boltEV, support: OBDSupportMap())
        XCTAssertEqual(cycle, [
            "ATSH 7DF",
            "010D", "010C", "0105", "0142", "0146", "0149", "015B",
            "ATSH 7E4",
            "228334", "22434F", "2241A3", "2243AF",
            "ATSH 7E1",
            "222414", "2228CB",
        ])
        XCTAssertEqual(DriveSignalTable.additionalBoltCommands(after: cycle), [])
        XCTAssertEqual(DriveSignalTable.decodeAdditionalMode22(did: 0x1234, data: [0x01]), [:])
        XCTAssertEqual(OBDDecode.interpret(command: "221234", reply: "62123401"), .ignored)
    }

    func testRowIDsAndReadingsAreUnique() {
        let ids = DriveSignalTable.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        let readings = DriveSignalTable.all.compactMap(\.reading)
        XCTAssertEqual(readings.count, Set(readings).count)
    }
}

final class DriveFreshnessTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testLiveStaleExpiredAndMissing() {
        func state(age: TimeInterval) -> DriveFreshness {
            DriveFreshness.evaluate(sample: OBDSample(value: 50, at: now.addingTimeInterval(-age)), now: now, validRange: 0...100)
        }
        XCTAssertEqual(state(age: 0), .live)
        XCTAssertEqual(state(age: 5), .live)
        XCTAssertEqual(state(age: 7.9), .stale(ageSeconds: 7))
        XCTAssertEqual(state(age: 20), .stale(ageSeconds: 20))
        XCTAssertEqual(state(age: 20.5), .notReported)
        XCTAssertEqual(state(age: -1), .notReported, "a future stamp is not trusted")
        XCTAssertEqual(DriveFreshness.evaluate(sample: nil, now: now, validRange: nil), .notReported)
    }

    func testOutOfRangeHidesTheNumber() {
        var book = OBDReadingBook()
        book.write(.packTempC, value: 180, at: now)
        let value = DriveValue.read(.packTempC, from: book, now: now)
        XCTAssertEqual(value.freshness, .outOfRange)
        XCTAssertNil(value.value)
    }

    func testDriveValueCarriesStaleNumbers() {
        var book = OBDReadingBook()
        book.write(.displayedSocPercent, value: 62, at: now.addingTimeInterval(-9))
        let value = DriveValue.read(.displayedSocPercent, from: book, now: now)
        XCTAssertEqual(value.value, 62)
        XCTAssertEqual(value.freshness, .stale(ageSeconds: 9))
        XCTAssertEqual(DriveValue.read(.motorTempC, from: book, now: now), .notReported)
    }

    func testBookSampleIgnoresExpiryButReadDoesNot() {
        var book = OBDReadingBook()
        book.write(.speedKph, value: 30, at: now.addingTimeInterval(-60))
        XCTAssertEqual(book.sample(.speedKph)?.value, 30)
        XCTAssertNil(book.read(.speedKph, now: now))
    }
}

final class DriveThresholdTests: XCTestCase {
    func testChargeAndTwelveVolt() {
        XCTAssertEqual(DriveThresholds.chargeLevel(percent: 14.9), .caution)
        XCTAssertEqual(DriveThresholds.chargeLevel(percent: 15), .normal)
        XCTAssertEqual(DriveThresholds.chargeLevel(percent: nil), .normal)
        XCTAssertEqual(DriveThresholds.moduleVoltsLevel(14.1), .normal)
        XCTAssertEqual(DriveThresholds.moduleVoltsLevel(12.1), .caution)
        XCTAssertEqual(DriveThresholds.moduleVoltsLevel(11.5), .critical)
    }

    func testPackBands() {
        XCTAssertEqual(DriveThresholds.packBand(celsius: -5), .cold)
        XCTAssertEqual(DriveThresholds.packBand(celsius: 0), .nominal)
        XCTAssertEqual(DriveThresholds.packBand(celsius: 44.9), .nominal)
        XCTAssertEqual(DriveThresholds.packBand(celsius: 45), .warm)
        XCTAssertEqual(DriveThresholds.packBand(celsius: 60), .hot)
        XCTAssertNil(DriveThresholds.packBand(celsius: nil))
        XCTAssertEqual(DriveTemperatureBand.hot.level, .critical)
        XCTAssertEqual(DriveTemperatureBand.cold.level, .caution)
    }

    func testFlowStateFollowsSignOnly() {
        XCTAssertEqual(HVFlowState.from(amps: 50), .drive)
        XCTAssertEqual(HVFlowState.from(amps: -5), .regen)
        XCTAssertEqual(HVFlowState.from(amps: 0), .idle)
        XCTAssertNil(HVFlowState.from(amps: nil))
        XCTAssertNil(HVFlowState.from(amps: .nan))
    }
}

final class SparklineBufferTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testWindowTrimsOldPoints() {
        var buffer = SparklineBuffer(window: 60, capacity: 1000)
        for second in 0..<90 {
            buffer.append(Double(second), at: start.addingTimeInterval(TimeInterval(second)))
        }
        let now = start.addingTimeInterval(89)
        let visible = buffer.points(now: now)
        XCTAssertEqual(visible.first?.value, 29)
        XCTAssertEqual(visible.last?.value, 89)
        XCTAssertEqual(buffer.range(now: now), 29...89)
    }

    func testCapacityOrderAndDuplicates() {
        var buffer = SparklineBuffer(window: 600, capacity: 3)
        for second in 0..<5 {
            buffer.append(Double(second), at: start.addingTimeInterval(TimeInterval(second)))
        }
        XCTAssertEqual(buffer.points.map(\.value), [2, 3, 4])
        buffer.append(99, at: start.addingTimeInterval(1))
        XCTAssertEqual(buffer.points.map(\.value), [2, 3, 4], "out-of-order sample is dropped")
        buffer.append(7, at: start.addingTimeInterval(4))
        XCTAssertEqual(buffer.points.map(\.value), [2, 3, 7], "same instant replaces")
        buffer.append(.infinity, at: start.addingTimeInterval(5))
        XCTAssertEqual(buffer.points.count, 3)
    }

    func testFlatLineGetsHeight() {
        var buffer = SparklineBuffer()
        buffer.append(12, at: start)
        buffer.append(12, at: start.addingTimeInterval(1))
        let range = buffer.range(now: start.addingTimeInterval(1))
        XCTAssertNotNil(range)
        XCTAssertLessThan(range!.lowerBound, 12)
        XCTAssertGreaterThan(range!.upperBound, 12)
        XCTAssertNil(SparklineBuffer().range(now: start))
    }
}

final class DriveTripStatsTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testSteadyDriveDistanceAverageAndMax() {
        var trip = DriveTripStats()
        for second in 0...3600 {
            trip.add(speedKph: second == 1800 ? 120 : 60, at: start.addingTimeInterval(TimeInterval(second)))
        }
        XCTAssertEqual(trip.distanceKilometers, 60 + 60.0 / 3600.0, accuracy: 0.001)
        XCTAssertEqual(trip.maxSpeedKph, 120)
        XCTAssertEqual(trip.averageMovingSpeedKph ?? 0, 60, accuracy: 0.05)
        XCTAssertEqual(trip.duration(now: start.addingTimeInterval(3600)), 3600)
    }

    func testGapsAndStopsAddNothing() {
        var trip = DriveTripStats()
        trip.add(speedKph: 50, at: start)
        trip.add(speedKph: 50, at: start.addingTimeInterval(30))
        XCTAssertEqual(trip.distanceKilometers, 0, "a 30 s gap must not invent distance")
        trip.add(speedKph: 0, at: start.addingTimeInterval(31))
        trip.add(speedKph: 0, at: start.addingTimeInterval(41))
        trip.add(speedKph: nil, at: start.addingTimeInterval(42))
        trip.add(speedKph: 0, at: start.addingTimeInterval(43))
        XCTAssertLessThan(trip.movingSeconds, 2)
        XCTAssertNil(trip.averageMovingSpeedKph)
    }

    func testEmptyTripHasNoDuration() {
        var trip = DriveTripStats()
        XCTAssertNil(trip.duration(now: start))
        trip.add(speedKph: -3, at: start)
        XCTAssertNil(trip.duration(now: start))
        trip.add(speedKph: 10, at: start)
        trip.reset()
        XCTAssertEqual(trip, DriveTripStats())
    }
}

final class DriveUnitTests: XCTestCase {
    func testSystemDefaults() {
        XCTAssertEqual(DriveUnitPreference.systemDefault(measurementSystem: "us"), DriveUnitPreference(speed: .mph, temperature: .fahrenheit))
        XCTAssertEqual(DriveUnitPreference.systemDefault(measurementSystem: "uk"), DriveUnitPreference(speed: .mph, temperature: .celsius))
        XCTAssertEqual(DriveUnitPreference.systemDefault(measurementSystem: "metric"), DriveUnitPreference(speed: .kmh, temperature: .celsius))
        XCTAssertEqual(DriveUnitPreference.systemDefault(measurementSystem: "anything"), DriveUnitPreference(speed: .kmh, temperature: .celsius))
    }

    func testConversions() {
        let us = DriveUnitPreference(speed: .mph, temperature: .fahrenheit)
        XCTAssertEqual(us.speed(fromKph: 100), 62.137, accuracy: 0.001)
        XCTAssertEqual(us.temperature(fromCelsius: 100), 212, accuracy: 0.001)
        XCTAssertEqual(us.distance(fromKilometers: 1.609344), 1, accuracy: 0.000_1)
        XCTAssertEqual(us.altitude(fromMeters: 0.3048), 1, accuracy: 0.000_1)
        XCTAssertEqual(us.distanceLabel, "mi")
        let metric = DriveUnitPreference(speed: .kmh, temperature: .celsius)
        XCTAssertEqual(metric.speed(fromKph: 100), 100)
        XCTAssertEqual(metric.temperature(fromCelsius: -40), -40)
        XCTAssertEqual(metric.altitudeLabel, "m")
    }
}

final class GForceMathTests: XCTestCase {
    func testIdentityAttitudePassesThrough() {
        let identity: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]
        let out = GForceMath.toReference(device: (0.1, -0.2, 0.3), matrix: identity)
        XCTAssertEqual(out?.x ?? 0, 0.1, accuracy: 1e-9)
        XCTAssertEqual(out?.y ?? 0, -0.2, accuracy: 1e-9)
        XCTAssertEqual(out?.z ?? 0, 0.3, accuracy: 1e-9)
        XCTAssertNil(GForceMath.toReference(device: (0, 0, 0), matrix: [1, 0]))
    }

    func testTransposeUndoesAQuarterTurn() {
        // Device yawed 90°: reference X shows up on device −Y.
        let yaw90: [Double] = [0, 1, 0, -1, 0, 0, 0, 0, 1]
        let out = GForceMath.toReference(device: (0, -1, 0), matrix: yaw90)
        XCTAssertEqual(out?.x ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(out?.y ?? 9, 0, accuracy: 1e-9)
    }

    func testVehicleFrameFromCourse() {
        let northbound = GForceMath.vehicleFrame(northG: 0.3, westG: 0, courseDegrees: 0)
        XCTAssertEqual(northbound?.longitudinal ?? 0, 0.3, accuracy: 1e-9)
        XCTAssertEqual(northbound?.lateral ?? 9, 0, accuracy: 1e-9)
        // Heading east, pushed south: that is toward the driver's right.
        let eastbound = GForceMath.vehicleFrame(northG: -0.2, westG: 0, courseDegrees: 90)
        XCTAssertEqual(eastbound?.longitudinal ?? 9, 0, accuracy: 1e-9)
        XCTAssertEqual(eastbound?.lateral ?? 0, 0.2, accuracy: 1e-9)
        // Heading north, pushed west: toward the left.
        let left = GForceMath.vehicleFrame(northG: 0, westG: 0.4, courseDegrees: 0)
        XCTAssertEqual(left?.lateral ?? 0, -0.4, accuracy: 1e-9)
        XCTAssertNil(GForceMath.vehicleFrame(northG: 0, westG: 0, courseDegrees: -1), "invalid GPS course")
    }

    func testTrackerSmoothsTrailsAndHoldsPeak() {
        var tracker = GForceTracker(smoothing: 0.5, trailCapacity: 3)
        tracker.add(GVector(longitudinal: 0, lateral: 0))
        tracker.add(GVector(longitudinal: 1, lateral: 0))
        XCTAssertEqual(tracker.current?.longitudinal ?? 0, 0.5, accuracy: 1e-9)
        tracker.add(GVector(longitudinal: 1, lateral: 0))
        tracker.add(GVector(longitudinal: 0, lateral: 0))
        XCTAssertEqual(tracker.trail.count, 3)
        XCTAssertEqual(tracker.peak, 0.75, accuracy: 1e-9)
        XCTAssertLessThan(tracker.current?.magnitude ?? 1, tracker.peak)
        tracker.add(GVector(longitudinal: .nan, lateral: 0))
        XCTAssertEqual(tracker.trail.count, 3)
        tracker.resetPeak()
        XCTAssertEqual(tracker.peak, tracker.current?.magnitude ?? -1, accuracy: 1e-9)
        tracker.clear()
        XCTAssertNil(tracker.current)
    }
}

final class DashboardLayoutTests: XCTestCase {
    func testSectionsPerLayout() {
        XCTAssertEqual(DashboardSection.sections(for: .ev), [.battery, .motor, .powerElectronics, .phone])
        XCTAssertEqual(DashboardSection.sections(for: .powertrain), [.vehicle, .phone])
        XCTAssertEqual(DashboardCardID.moduleVolts.section(for: .ev), .powerElectronics)
        XCTAssertEqual(DashboardCardID.moduleVolts.section(for: .powertrain), .vehicle)
        XCTAssertNil(DashboardCardID.fuel.section(for: .ev), "an EV never gets a fuel card")
        XCTAssertNil(DashboardCardID.hvCurrent.section(for: .powertrain))
        let layout = DashboardLayout.standard
        let power = layout.cards(in: .powerElectronics, for: .ev)
        XCTAssertEqual(power, [.moduleVolts, .inverterTemp, .dcdcOutput, .charger])
    }

    func testMoveWithinASectionKeepsOtherSectionsInPlace() {
        var layout = DashboardLayout.standard
        let phoneBefore = layout.cards(in: .phone, for: .ev)
        layout.move(in: .battery, for: .ev, from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(layout.cards(in: .battery, for: .ev), [.packTemp, .capacity, .hvCurrent, .remainingLifeHD, .planningRange])
        XCTAssertEqual(layout.cards(in: .phone, for: .ev), phoneBefore)
        layout.move(in: .battery, for: .ev, from: IndexSet(integer: 4), to: 0)
        XCTAssertEqual(layout.cards(in: .battery, for: .ev).first, .planningRange)
        layout.move(in: .battery, for: .ev, from: IndexSet(integer: 99), to: 0)
        XCTAssertEqual(layout.cards(in: .battery, for: .ev).first, .planningRange, "bad offsets are ignored")
    }

    func testHideAndRoundTrip() {
        var layout = DashboardLayout.standard
        layout.setHidden(.barometer, true)
        layout.move(in: .phone, for: .powertrain, from: IndexSet(integer: 6), to: 0)
        XCTAssertFalse(layout.cards(in: .phone, for: .ev).contains(.barometer))
        XCTAssertTrue(layout.cards(in: .phone, for: .ev, includeHidden: true).contains(.barometer))
        let restored = DashboardLayout.decoded(from: layout.encoded())
        XCTAssertEqual(restored, layout)
        XCTAssertEqual(restored.cards(in: .phone, for: .ev).first, .trip)
        layout.setHidden(.barometer, false)
        XCTAssertFalse(layout.isHidden(.barometer))
    }

    func testUnknownIDsDropAndNewCardsAppend() {
        let json = #"{"order":["trip","warpDrive","trip","gForce"],"hidden":["fluxCapacitor","compass"]}"#
        let layout = DashboardLayout.decoded(from: Data(json.utf8))
        XCTAssertEqual(Array(layout.order.prefix(2)), [.trip, .gForce])
        XCTAssertEqual(layout.order.count, DashboardCardID.allCases.count)
        XCTAssertEqual(layout.hidden, [.compass])
        XCTAssertEqual(DashboardLayout.decoded(from: Data("nope".utf8)), .standard)
        XCTAssertEqual(DashboardLayout.decoded(from: nil), .standard)
    }
}
