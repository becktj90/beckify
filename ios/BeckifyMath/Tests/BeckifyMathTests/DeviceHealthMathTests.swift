import XCTest
@testable import BeckifyMath

final class DeviceHealthMathTests: XCTestCase {

    func testBatteryUnknownWhenNegative() {
        XCTAssertEqual(DeviceHealthMath.batteryPercentText(level: -1), "—")
        XCTAssertEqual(DeviceHealthMath.batteryPercentText(level: .nan), "—")
        XCTAssertEqual(DeviceHealthMath.batteryTone(level: -1, charge: .unknown), .muted)
    }

    func testBatteryIntegerPercentAndLowUnpluggedTone() {
        XCTAssertEqual(DeviceHealthMath.batteryPercentText(level: 0.64), "64 %")
        XCTAssertEqual(DeviceHealthMath.batteryPercentText(level: 1), "100 %")
        XCTAssertEqual(DeviceHealthMath.batteryPercentText(level: 0), "0 %")
        XCTAssertEqual(DeviceHealthMath.batteryTone(level: 0.12, charge: .unplugged), .bad)
        XCTAssertEqual(DeviceHealthMath.batteryTone(level: 0.18, charge: .unplugged), .warn)
        XCTAssertEqual(DeviceHealthMath.batteryTone(level: 0.12, charge: .charging), .good)
    }

    func testChargeNuance() {
        XCTAssertEqual(DeviceHealthMath.chargeLabel(.charging), "Charging")
        XCTAssertEqual(DeviceHealthMath.chargeLabel(.full), "Full")
        XCTAssertEqual(DeviceHealthMath.chargeLabel(.unplugged), "Unplugged")
        XCTAssertTrue(DeviceHealthMath.chargeNote(.unplugged, level: 0.15).localizedCaseInsensitiveContains("20"))
        XCTAssertTrue(DeviceHealthMath.chargeNote(.unknown, level: -1).localizedCaseInsensitiveContains("Simulator"))
        XCTAssertFalse(DeviceHealthMath.chargeNote(.charging, level: 0.5).localizedCaseInsensitiveContains("health score"))
    }

    func testThermalMeaningIsFieldUsefulNotAThermometer() {
        XCTAssertEqual(DeviceHealthMath.thermalLabel(.nominal), "Nominal")
        XCTAssertEqual(DeviceHealthMath.thermalTone(.nominal), .good)
        XCTAssertEqual(DeviceHealthMath.thermalTone(.fair), .warn)
        XCTAssertEqual(DeviceHealthMath.thermalTone(.serious), .bad)
        XCTAssertEqual(DeviceHealthMath.thermalTone(.critical), .bad)
        XCTAssertTrue(DeviceHealthMath.thermalMeaning(.fair).localizedCaseInsensitiveContains("performance"))
        XCTAssertTrue(DeviceHealthMath.thermalMeaning(.serious).localizedCaseInsensitiveContains("throttling"))
        XCTAssertTrue(DeviceHealthMath.thermalMeaning(.critical).localizedCaseInsensitiveContains("cool"))
        XCTAssertFalse(DeviceHealthMath.thermalMeaning(.nominal).contains("°"))
    }

    func testLowPowerCopy() {
        XCTAssertEqual(DeviceHealthMath.lowPowerLabel(enabled: true), "On")
        XCTAssertEqual(DeviceHealthMath.lowPowerLabel(enabled: false), "Off")
        XCTAssertEqual(DeviceHealthMath.lowPowerTone(enabled: true), .warn)
        XCTAssertTrue(DeviceHealthMath.lowPowerNote(enabled: true).localizedCaseInsensitiveContains("background"))
    }

    func testUptimeBuckets() {
        XCTAssertEqual(DeviceHealthMath.formatUptime(seconds: 12), "under 1 min")
        XCTAssertEqual(DeviceHealthMath.formatUptime(seconds: 5 * 60), "5 min")
        XCTAssertEqual(DeviceHealthMath.formatUptime(seconds: 4 * 3600 + 12 * 60), "4h 12m")
        XCTAssertEqual(DeviceHealthMath.formatUptime(seconds: 2 * 86_400 + 3 * 3600), "2d 3h")
        XCTAssertEqual(DeviceHealthMath.formatUptime(seconds: -4), "—")
        XCTAssertEqual(DeviceHealthMath.formatUptime(seconds: .infinity), "—")
    }

    func testStorageAndMemoryFormatting() {
        XCTAssertEqual(DeviceHealthMath.formatStorageBytes(nil), "—")
        XCTAssertEqual(DeviceHealthMath.formatMemoryBytes(nil), "—")
        let disk = DeviceHealthMath.formatStorageBytes(5_000_000_000)
        XCTAssertTrue(disk.contains("GB") || disk.contains("5"), disk)
        let ram = DeviceHealthMath.formatMemoryBytes(8 * 1024 * 1024 * 1024)
        XCTAssertTrue(ram.contains("GB") || ram.contains("8"), ram)
    }

    func testBrightnessAndProcessors() {
        XCTAssertEqual(DeviceHealthMath.brightnessPercentText(0.72), "72 %")
        XCTAssertEqual(DeviceHealthMath.brightnessPercentText(-1), "—")
        XCTAssertEqual(DeviceHealthMath.processorText(active: 6, installed: 6), "6 active")
        XCTAssertEqual(DeviceHealthMath.processorText(active: 4, installed: 6), "4 active / 6")
        XCTAssertEqual(DeviceHealthMath.processorText(active: 0, installed: 0), "—")
    }

    func testModelLookupDoesNotInventUnknownIdentifiers() {
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone15,2"), "iPhone 14 Pro")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "arm64"), "Simulator")
        XCTAssertNil(DeviceHealthMath.marketingName(identifier: "iPhone99,1"))
        XCTAssertEqual(
            DeviceHealthMath.modelDisplay(identifier: "iPhone15,2", udiModel: "iPhone"),
            "iPhone 14 Pro (iPhone15,2)"
        )
        XCTAssertEqual(
            DeviceHealthMath.modelDisplay(identifier: "iPhone99,1", udiModel: "iPhone"),
            "iPhone (iPhone99,1)"
        )
        XCTAssertEqual(DeviceHealthMath.modelDisplay(identifier: "arm64", udiModel: "iPhone"), "Simulator")
    }

    func testSnapshotCopySaveAndStickyStayHonest() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let boot = now.addingTimeInterval(-2 * 86_400 - 3 * 3600)
        let snap = DeviceHealthMath.snapshot(
            batteryLevel: 0.64,
            charge: .unplugged,
            lowPower: true,
            thermal: .fair,
            freeImportantBytes: 32_000_000_000,
            freeOpportunisticBytes: 20_000_000_000,
            volumeTotalBytes: 128_000_000_000,
            identifier: "iPhone15,2",
            udiModel: "iPhone",
            systemName: "iOS",
            systemVersion: "18.6",
            uptimeSeconds: 2 * 86_400 + 3 * 3600,
            bootDate: boot,
            now: now,
            brightness: 0.5,
            physicalMemoryBytes: 6 * 1024 * 1024 * 1024,
            appHeadroomBytes: 800 * 1024 * 1024,
            activeProcessors: 6,
            installedProcessors: 6
        )

        XCTAssertEqual(snap.battery, "64 %")
        XCTAssertEqual(snap.charge, "Unplugged")
        XCTAssertEqual(snap.lowPower, "On")
        XCTAssertEqual(snap.thermal, "Fair")
        XCTAssertEqual(snap.system, "iOS 18.6")
        XCTAssertEqual(snap.uptime, "2d 3h")
        XCTAssertEqual(snap.uptimeLabel, "Since boot")
        XCTAssertTrue(snap.model.contains("iPhone 14 Pro"))
        XCTAssertTrue(snap.sticky.contains("64 %"))
        XCTAssertTrue(snap.sticky.contains("Fair"))
        XCTAssertTrue(snap.sticky.contains("LPM on"))
        XCTAssertTrue(snap.copyText.contains("Low Power On"))
        XCTAssertTrue(snap.copyText.contains("Thermal Fair"))
        XCTAssertFalse(snap.copyText.localizedCaseInsensitiveContains("health score"))
        XCTAssertEqual(snap.saveOutputs["battery"], "64 %")
        XCTAssertEqual(snap.saveOutputs["thermal"], "Fair")
        XCTAssertEqual(snap.saveOutputs["low power"], "On")
        XCTAssertEqual(snap.saveOutputs["identifier"], "iPhone15,2")
        XCTAssertNotNil(snap.saveOutputs["free important"])
        XCTAssertNotNil(snap.saveOutputs["app headroom"])
    }

    func testUnavailableSnapshotDoesNotInventBattery() {
        let snap = DeviceHealthMath.snapshot(
            batteryLevel: -1,
            charge: .unknown,
            lowPower: false,
            thermal: .nominal,
            freeImportantBytes: nil,
            freeOpportunisticBytes: nil,
            volumeTotalBytes: nil,
            identifier: "arm64",
            udiModel: "iPhone",
            systemName: "iOS",
            systemVersion: "18.6",
            uptimeSeconds: 12,
            bootDate: nil,
            brightness: -1,
            physicalMemoryBytes: nil,
            appHeadroomBytes: nil,
            activeProcessors: 0,
            installedProcessors: 0
        )
        XCTAssertEqual(snap.battery, "—")
        XCTAssertEqual(snap.booted, "—")
        XCTAssertEqual(snap.uptimeLabel, "Awake")
        XCTAssertEqual(snap.freeImportant, "—")
        XCTAssertEqual(snap.brightness, "—")
        XCTAssertEqual(snap.model, "Simulator")
        XCTAssertFalse(snap.sticky.contains("64"))
        XCTAssertTrue(snap.sticky.contains("Nominal"))
    }
}
