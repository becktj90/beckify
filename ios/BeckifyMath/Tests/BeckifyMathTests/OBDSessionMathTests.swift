import XCTest
@testable import BeckifyMath

final class OBDSessionMathTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testReassemblerSplitsOnPromptAndKeepsPartial() {
        var buffer = ""
        XCTAssertEqual(ELMReassembler.replies(in: &buffer, appending: "ELM327 v1.5"), [])
        XCTAssertEqual(ELMReassembler.replies(in: &buffer, appending: "\r>"), ["ELM327 v1.5\r"])
        let pair = ELMReassembler.replies(in: &buffer, appending: "410D3C>NO DA")
        XCTAssertEqual(pair, ["410D3C"])
        XCTAssertEqual(buffer, "NO DA")
    }

    func testSpeedRPMCoolantAndModuleVoltage() {
        let speed = OBDDecode.interpret(command: "010D", reply: "41 0D 3C")
        XCTAssertEqual(speed, .readings([.speedKph: 60]))
        let rpm = OBDDecode.interpret(command: "010C", reply: "410C0C80")
        XCTAssertEqual(rpm, .readings([.rpm: 800]))
        let coolant = OBDDecode.interpret(command: "0105", reply: "7E8 03 41 05 50")
        XCTAssertEqual(coolant, .readings([.coolantC: 40]))
        let volts = OBDDecode.interpret(command: "0142", reply: "414236B0")
        XCTAssertEqual(volts, .readings([.moduleVolts: 14.0]))
    }

    func testFuelLevelIsNotStateOfCharge() {
        let fuel = OBDDecode.interpret(command: "012F", reply: "412F80")
        guard case .readings(let values) = fuel else {
            return XCTFail("expected fuel reading")
        }
        XCTAssertNil(values[.displayedSocPercent])
        XCTAssertEqual(values[.fuelLevelPercent] ?? -1, 128.0 * 100.0 / 255.0, accuracy: 0.001)
    }

    func testHybridRemainingLifeIsNotDisplayedSoC() {
        let life = OBDDecode.interpret(command: "015B", reply: "415BCC")
        guard case .readings(let values) = life else {
            return XCTFail("expected remaining life")
        }
        XCTAssertNil(values[.displayedSocPercent])
        XCTAssertEqual(values[.hybridRemainingLifePercent] ?? -1, 80, accuracy: 0.001)
    }

    func testBoltDisplayedSoCPackTempCurrentAndCapacity() {
        let soc = OBDDecode.interpret(command: "228334", reply: "7EC 04 62 83 34 CC")
        XCTAssertEqual(soc, .readings([.displayedSocPercent: 80]))
        let temp = OBDDecode.interpret(command: "22434F", reply: "62434F50")
        XCTAssertEqual(temp, .readings([.packTempC: 40]))
        let amps = OBDDecode.interpret(command: "222414", reply: "62241403E8")
        XCTAssertEqual(amps, .readings([.hvCurrentAmps: 50]))
        let regen = OBDDecode.interpret(command: "222414", reply: "622414FF9C")
        XCTAssertEqual(regen, .readings([.hvCurrentAmps: -5]))
        let ah = OBDDecode.interpret(command: "2241A3", reply: "6241A30672")
        XCTAssertEqual(ah, .readings([.capacityAh: 165]))
        let motor = OBDDecode.interpret(command: "2228CB", reply: "6228CB4A")
        XCTAssertEqual(motor, .readings([.motorTempC: 34]))
    }

    func testShortOrFaultyPayloadDoesNotInventANumber() {
        XCTAssertEqual(OBDDecode.interpret(command: "2241A3", reply: "6241A314"), .ignored)
        XCTAssertEqual(OBDDecode.interpret(command: "010D", reply: "NO DATA"), .fault)
        XCTAssertEqual(OBDDecode.interpret(command: "228334", reply: "UNABLE TO CONNECT"), .fault)
        XCTAssertEqual(OBDDecode.interpret(command: "010D", reply: "?"), .fault)
        XCTAssertEqual(OBDDecode.interpret(command: "010D", reply: "SEARCHING..."), .ignored)
        XCTAssertEqual(OBDDecode.interpret(command: "ATZ", reply: "ELM327 v1.5"), .adapter)
    }

    func testRemainingLifeHDUsesPublishedScale() {
        let full = OBDDecode.interpret(command: "2243AF", reply: "6243AFFFFF")
        XCTAssertEqual(full, .readings([.hybridRemainingLifeHDPercent: 100]))
        let half = OBDDecode.interpret(command: "2243AF", reply: "6243AF8000")
        guard case .readings(let values) = half else { return XCTFail("expected HD life") }
        XCTAssertEqual(values[.hybridRemainingLifeHDPercent] ?? -1, Double(0x8000) * 100.0 / 65535.0, accuracy: 0.001)
        XCTAssertNil(values[.displayedSocPercent])
    }

    func testSupportMaskAndGenericCycleSkipsBoltPIDs() {
        var map = OBDSupportMap()
        map.record(block: 0x00, data: [0x00, 0x18, 0x00, 0x00])
        XCTAssertTrue(map.allows(0x0C))
        XCTAssertTrue(map.allows(0x0D))
        XCTAssertFalse(map.allows(0x05))
        let cycle = OBDCommandPlan.liveCycle(profile: .generic, support: map)
        XCTAssertEqual(cycle, ["010D", "010C"])
        XCTAssertFalse(cycle.contains("228334"))
        XCTAssertFalse(cycle.contains("012F"))
    }

    func testBoltCycleUsesPublishedHeadersAndSkipsUntrustedScales() {
        let cycle = OBDCommandPlan.liveCycle(profile: .boltEUV, support: OBDSupportMap())
        XCTAssertEqual(cycle, OBDCommandPlan.liveCycle(profile: .boltEV, support: OBDSupportMap()))
        XCTAssertTrue(cycle.contains("ATSH 7E4"))
        XCTAssertTrue(cycle.contains("228334"))
        XCTAssertTrue(cycle.contains("22434F"))
        XCTAssertTrue(cycle.contains("ATSH 7E1"))
        XCTAssertTrue(cycle.contains("222414"))
        XCTAssertFalse(cycle.contains("22436B"))
        XCTAssertFalse(cycle.contains("22436C"))
        XCTAssertFalse(cycle.contains("22437D"))
        XCTAssertFalse(cycle.contains("2241B6"))
        XCTAssertFalse(cycle.contains("012F"))
        XCTAssertFalse(OBDCommandPlan.initialization.contains("228334"))
    }

    func testStaleReadingExpiresAndDoesNotResurrect() {
        var book = OBDReadingBook()
        book.write(.displayedSocPercent, value: 80, at: now)
        XCTAssertEqual(book.read(.displayedSocPercent, now: now.addingTimeInterval(20)), 80)
        XCTAssertNil(book.read(.displayedSocPercent, now: now.addingTimeInterval(21)))
    }

    func testPlanningRangeRequiresMeasuredSoCAndTypedRates() {
        XCTAssertNil(DrivePlanning.rangeMiles(socPercent: 80, usableKWh: 65, whPerMile: nil))
        XCTAssertNil(DrivePlanning.rangeMiles(socPercent: nil, usableKWh: 65, whPerMile: 250))
        XCTAssertEqual(DrivePlanning.rangeMiles(socPercent: 80, usableKWh: 65, whPerMile: 250) ?? -1, 208, accuracy: 0.001)
        XCTAssertNil(DrivePlanning.efficiencyWhPerMile(distanceMiles: 10, energyKWh: nil))
    }

    func testTripDistanceDropsLongGaps() {
        var trip = OBDTripTrack()
        trip.add(speedKph: 36, at: now)
        trip.add(speedKph: 36, at: now.addingTimeInterval(2))
        XCTAssertEqual(trip.distanceKilometers, 0.02, accuracy: 0.0001)
        trip.add(speedKph: 36, at: now.addingTimeInterval(30))
        XCTAssertEqual(trip.distanceKilometers, 0.02, accuracy: 0.0001)
    }

    func testCarPlayPublishIntervalIsTenSeconds() {
        XCTAssertTrue(CarPlayPublishPolicy.shouldPublish(since: nil, now: now))
        XCTAssertFalse(CarPlayPublishPolicy.shouldPublish(since: now, now: now.addingTimeInterval(9.9)))
        XCTAssertTrue(CarPlayPublishPolicy.shouldPublish(since: now, now: now.addingTimeInterval(10)))
        XCTAssertEqual(CarPlayPublishPolicy.minimumInterval, 10)
    }

    func testGlanceDoesNotPromoteRemainingLifeOrFuelIntoCharge() {
        var book = OBDReadingBook()
        book.write(.hybridRemainingLifePercent, value: 92, at: now)
        book.write(.fuelLevelPercent, value: 40, at: now)
        let bolt = DrivePresentationBuilder.make(
            profile: .boltEV,
            book: book,
            now: now,
            planning: PlanningInputs(usableKWh: 65, whPerMile: 250),
            trip: OBDTripTrack(),
            link: "Live · Bolt EV"
        )
        XCTAssertNil(bolt.heroPercent)
        XCTAssertEqual(bolt.heroValue, "—")
        XCTAssertEqual(bolt.carPlay.charge, "Not read")
        XCTAssertEqual(bolt.carPlay.power, "Not read")
        XCTAssertEqual(bolt.carPlay.range, "Not read")
        XCTAssertEqual(bolt.tiles.first { $0.id == "power" }?.value, "—")

        let generic = DrivePresentationBuilder.make(
            profile: .generic,
            book: book,
            now: now,
            planning: PlanningInputs(usableKWh: nil, whPerMile: nil),
            trip: OBDTripTrack(),
            link: "Live · Generic OBD"
        )
        XCTAssertEqual(generic.layout, .powertrain)
        XCTAssertNil(generic.heroPercent)
        XCTAssertEqual(generic.carPlay.charge, "Not read")
        XCTAssertEqual(generic.tiles.first { $0.id == "fuel" }?.value.contains("%"), true)
        XCTAssertFalse(generic.rows.contains { $0.label == "Displayed state of charge" })
    }

    func testBoltGlanceUsesDisplayedSoCAndLabelsPlanningRange() {
        var book = OBDReadingBook()
        book.write(.displayedSocPercent, value: 80, at: now)
        book.write(.speedKph, value: 60, at: now)
        book.write(.packTempC, value: 22, at: now)
        book.write(.hvCurrentAmps, value: -5, at: now)
        let glance = DrivePresentationBuilder.make(
            profile: .boltEUV,
            book: book,
            now: now,
            planning: PlanningInputs(usableKWh: 65, whPerMile: 250),
            trip: OBDTripTrack(),
            link: "Live · Bolt EUV"
        )
        XCTAssertEqual(glance.layout, .ev)
        XCTAssertEqual(glance.heroPercent ?? -1, 80, accuracy: 0.001)
        XCTAssertEqual(glance.carPlay.charge, "80.0%")
        XCTAssertEqual(glance.carPlay.speed, "37 mph")
        XCTAssertEqual(glance.carPlay.range, "208 mi planning")
        XCTAssertEqual(glance.carPlay.temperature, "Pack 72°F")
        XCTAssertEqual(glance.carPlay.power, "Not read")
        XCTAssertEqual(glance.tiles.first { $0.id == "amps" }?.value, "-5.0 A")
        XCTAssertTrue(glance.tiles.first { $0.id == "range" }?.caption.contains("not the vehicle estimate") == true)
        XCTAssertTrue(glance.designAid.contains("Not a certified diagnostic"))
    }

    func testAdapterNameHintDoesNotMatchHeadphones() {
        XCTAssertTrue(OBDAdapterHint.looksLikeOBD(name: "VEEPEAK", serviceUUIDs: []))
        XCTAssertTrue(OBDAdapterHint.looksLikeOBD(name: "IOS-VLINK", serviceUUIDs: []))
        XCTAssertTrue(OBDAdapterHint.looksLikeOBD(name: nil, serviceUUIDs: ["FFF0"]))
        XCTAssertFalse(OBDAdapterHint.looksLikeOBD(name: "AirPods", serviceUUIDs: ["180F"]))
    }
}
