import XCTest
@testable import BeckifyMath

final class ReceptacleSelectorTests: XCTestCase {
    func test120VSinglePhase15AIndoorIs515RFamily() throws {
        let matches = try ReceptacleSelector.select(
            ReceptacleQuery(
                volts: 120,
                phase: .singlePhase2Wire,
                amps: 15,
                environment: .indoorDry,
                family: .any
            )
        )
        XCTAssertFalse(matches.isEmpty)
        XCTAssertEqual(matches[0].config.code, "5-15R")
        XCTAssertEqual(matches[0].config.family, .nemaStraight)
        XCTAssertEqual(matches[0].config.poles, 2)
        XCTAssertEqual(matches[0].config.wires, 3)
        XCTAssertTrue(matches[0].config.hasNeutral)
        XCTAssertTrue(matches[0].catalog.contains { $0.partNumber == "HBL5262" })
        XCTAssertTrue(matches[0].catalog.contains { $0.maker == "Leviton" && $0.partNumber == "5262" })
        XCTAssertTrue(matches[0].catalog.contains { $0.maker.contains("Pass") && $0.partNumber == "5262" })
        XCTAssertTrue(matches.contains { $0.config.code == "L5-15R" })
    }

    func test480VThreePhase30ALockingIsL16_30() throws {
        let matches = try ReceptacleSelector.select(
            ReceptacleQuery(
                volts: 480,
                phase: .threePhase,
                amps: 30,
                environment: .indoorDry,
                family: .locking,
                neutral: .none
            )
        )
        XCTAssertEqual(matches[0].config.code, "L16-30R")
        XCTAssertEqual(matches[0].config.family, .nemaLocking)
        XCTAssertFalse(matches[0].config.hasNeutral)
        XCTAssertEqual(matches[0].config.amps, 30)
        XCTAssertTrue(matches[0].catalog.contains { $0.partNumber == "HBL2730" })
        XCTAssertFalse(matches.contains { $0.config.family == .iec60309 })
    }

    func test480VThreePhase30AIECIs3PPlusE7h() throws {
        let matches = try ReceptacleSelector.select(
            ReceptacleQuery(
                volts: 480,
                phase: .threePhase,
                amps: 30,
                environment: .indoorDry,
                family: .iecPinSleeve,
                neutral: .none
            )
        )
        let top = matches[0]
        XCTAssertEqual(top.config.family, .iec60309)
        XCTAssertEqual(top.config.iecPolesLabel, "3P+E")
        XCTAssertEqual(top.config.iecEarthHour, 7)
        XCTAssertFalse(top.config.hasNeutral)
        XCTAssertTrue(top.catalog.contains { $0.partNumber == "HBL430R7W" })
        XCTAssertFalse(matches.contains { $0.config.iecEarthHour == 6 && $0.config.iecPolesLabel == "3P+E" })
    }

    func testIECClockPositions() {
        XCTAssertEqual(IEC60309.earthHour(volts: 120, poles: .twoPlusE, frequencyHz: 60), 4)
        XCTAssertEqual(IEC60309.earthHour(volts: 230, poles: .twoPlusE, frequencyHz: 50), 6)
        XCTAssertEqual(IEC60309.earthHour(volts: 277, poles: .twoPlusE, frequencyHz: 60), 5)
        XCTAssertNil(IEC60309.earthHour(volts: 277, poles: .twoPlusE, frequencyHz: 50))
        XCTAssertEqual(IEC60309.earthHour(volts: 208, poles: .threePlusE, frequencyHz: 60), 9)
        XCTAssertEqual(IEC60309.earthHour(volts: 400, poles: .threePlusE, frequencyHz: 50), 6)
        XCTAssertEqual(IEC60309.earthHour(volts: 480, poles: .threePlusE, frequencyHz: 60), 7)
        XCTAssertEqual(IEC60309.earthHour(volts: 208, poles: .threePlusNE, frequencyHz: 60), 9)
        XCTAssertEqual(IEC60309.earthHour(volts: 480, poles: .threePlusNE, frequencyHz: 60), 7)
    }

    func test20ALoadDoesNotSelect15ADevice() throws {
        let matches = try ReceptacleSelector.select(
            ReceptacleQuery(volts: 120, phase: .singlePhase2Wire, amps: 20, family: .straight)
        )
        XCTAssertEqual(matches[0].config.code, "5-20R")
        XCTAssertFalse(matches.contains { $0.config.code == "5-15R" })
    }

    func testIsolatedGroundUsesCitedIGPart() throws {
        let matches = try ReceptacleSelector.select(
            ReceptacleQuery(
                volts: 120,
                phase: .singlePhase2Wire,
                amps: 15,
                family: .straight,
                isolatedGround: true
            )
        )
        XCTAssertTrue(matches[0].catalog.contains { $0.partNumber == "IG5262" })
    }

    func testHazardousIsFlaggedNotClassifiedStamp() throws {
        let matches = try ReceptacleSelector.select(
            ReceptacleQuery(
                volts: 120,
                phase: .singlePhase2Wire,
                amps: 15,
                environment: .hazardous,
                family: .straight
            )
        )
        XCTAssertTrue(matches[0].caveats.contains { $0.localizedCaseInsensitiveContains("classified-area") })
        XCTAssertTrue(matches[0].caveats.contains { $0.localizedCaseInsensitiveContains("not a classified") })
    }

    func testMeltric480V30AHasPublicPN() throws {
        let matches = try ReceptacleSelector.select(
            ReceptacleQuery(
                volts: 480,
                phase: .threePhase,
                amps: 30,
                family: .switchedDisconnect,
                neutral: .none
            )
        )
        XCTAssertTrue(matches.contains { $0.config.code.contains("DS30 3P+G") })
        XCTAssertTrue(matches.contains { $0.catalog.contains { $0.partNumber == "33-34043" } })
        XCTAssertTrue(matches.contains { $0.catalog.contains { $0.partNumber == "63-34043" } })
    }

    func testNoInventedSKUWhenCatalogMissing() throws {
        let matches = try ReceptacleSelector.select(
            ReceptacleQuery(
                volts: 600,
                phase: .singlePhase2Wire,
                amps: 20,
                family: .locking
            )
        )
        XCTAssertEqual(matches[0].config.code, "L9-20R")
        XCTAssertTrue(matches[0].catalog.isEmpty)
        XCTAssertEqual(
            matches[0].catalogFallback,
            "Confirm current catalog — no public part number is cited for this configuration."
        )
    }

    func testRejectsZeroVoltage() {
        XCTAssertThrowsError(
            try ReceptacleSelector.select(
                ReceptacleQuery(volts: 0, phase: .singlePhase2Wire, amps: 15)
            )
        )
    }

    func testIECFacePutsEarthOnRequestedHour() {
        let face = ReceptacleFaces.iec(poles: .threePlusE, hour: 7)
        XCTAssertEqual(face.earthHour, 7)
        XCTAssertTrue(face.keywayAtSix)
        let earth = face.pins.first { $0.kind == .ground }
        XCTAssertEqual(earth?.clockAngle, 210)
    }
}
