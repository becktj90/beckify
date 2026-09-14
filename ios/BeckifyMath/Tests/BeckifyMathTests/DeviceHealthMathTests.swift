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
        XCTAssertEqual(DeviceHealthMath.formatStorageBytes(256_000_000_000), "256 GB")
        XCTAssertEqual(DeviceHealthMath.formatStorageBytes(55_980_000_000), "55.98 GB")
        XCTAssertEqual(DeviceHealthMath.formatStorageBytes(5_000_000_000), "5.00 GB")
        let ram = DeviceHealthMath.formatMemoryBytes(8 * 1024 * 1024 * 1024)
        XCTAssertTrue(ram.contains("GB") || ram.contains("8"), ram)
        XCTAssertEqual(
            DeviceHealthMath.storageUsedBytes(total: 256_000_000_000, freeImportant: 55_980_000_000),
            200_020_000_000
        )
        XCTAssertNil(DeviceHealthMath.storageUsedBytes(total: nil, freeImportant: 1))
        let fraction = DeviceHealthMath.storageUsedFraction(total: 256_000_000_000, freeImportant: 55_980_000_000)
        XCTAssertNotNil(fraction)
        XCTAssertEqual(fraction!, 200_020_000_000.0 / 256_000_000_000.0, accuracy: 1e-9)
        XCTAssertTrue(DeviceHealthMath.storageCaption.localizedCaseInsensitiveContains("About"))
        XCTAssertTrue(DeviceHealthMath.storageCaption.localizedCaseInsensitiveContains("ImportantUsage")
            || DeviceHealthMath.storageCaption.localizedCaseInsensitiveContains("user files"))
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
            "iPhone 14 Pro"
        )
        XCTAssertEqual(
            DeviceHealthMath.modelDisplay(identifier: "iPhone99,1", udiModel: "iPhone"),
            "iPhone"
        )
        XCTAssertEqual(DeviceHealthMath.modelDisplay(identifier: "arm64", udiModel: "iPhone"), "Simulator")
        XCTAssertEqual(
            DeviceHealthMath.identifierCaption(identifier: "iPhone15,2"),
            "Identifier `iPhone15,2` is not the product name."
        )
        XCTAssertEqual(DeviceHealthMath.identifierCaption(identifier: "arm64"), "")
    }

    func testIPhone17LineupMapsFromIPhone18Identifiers() {
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone18,1"), "iPhone 17 Pro")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone18,2"), "iPhone 17 Pro Max")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone18,3"), "iPhone 17")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone18,4"), "iPhone Air")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone18,5"), "iPhone 17e")
        XCTAssertEqual(
            DeviceHealthMath.modelDisplay(identifier: "iPhone18,1", udiModel: "iPhone"),
            "iPhone 17 Pro"
        )
        XCTAssertFalse(
            DeviceHealthMath.modelDisplay(identifier: "iPhone18,1", udiModel: "iPhone")
                .localizedCaseInsensitiveContains("iPhone 18")
        )
        XCTAssertEqual(
            DeviceHealthMath.identifierCaption(identifier: "iPhone18,1"),
            "Identifier `iPhone18,1` is not the product name."
        )
    }

    func testExistingIPhone14Through16Mappings() {
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone15,2"), "iPhone 14 Pro")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone15,3"), "iPhone 14 Pro Max")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone15,4"), "iPhone 15")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone15,5"), "iPhone 15 Plus")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone16,1"), "iPhone 15 Pro")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone16,2"), "iPhone 15 Pro Max")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone17,1"), "iPhone 16 Pro")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone17,2"), "iPhone 16 Pro Max")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone17,3"), "iPhone 16")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone17,4"), "iPhone 16 Plus")
        XCTAssertEqual(DeviceHealthMath.marketingName(identifier: "iPhone17,5"), "iPhone 16e")
        XCTAssertEqual(
            DeviceHealthMath.modelDisplay(identifier: "iPhone17,1", udiModel: "iPhone"),
            "iPhone 16 Pro"
        )
        XCTAssertNotEqual(DeviceHealthMath.marketingName(identifier: "iPhone17,1"), "iPhone 17")
        XCTAssertNotEqual(DeviceHealthMath.marketingName(identifier: "iPhone18,1"), "iPhone 18")
    }

    func testUnknownIPhone18FamilyDoesNotBecomeIPhone18() {
        XCTAssertNil(DeviceHealthMath.marketingName(identifier: "iPhone18,9"))
        XCTAssertNil(DeviceHealthMath.marketingName(identifier: "iPhone19,1"))
        let unknown = DeviceHealthMath.modelDisplay(identifier: "iPhone18,9", udiModel: "iPhone")
        XCTAssertEqual(unknown, "iPhone")
        XCTAssertFalse(unknown.contains("iPhone 18"))
        XCTAssertFalse(unknown.contains("iPhone18"))
        let caption = DeviceHealthMath.identifierCaption(identifier: "iPhone18,9")
        XCTAssertTrue(caption.contains("`iPhone18,9`"))
        XCTAssertTrue(caption.localizedCaseInsensitiveContains("not the product name"))
        XCTAssertTrue(caption.localizedCaseInsensitiveContains("No public marketing name"))
        XCTAssertFalse(caption.contains("iPhone 18"))
        let rawOnly = DeviceHealthMath.modelDisplay(identifier: "iPhone18,9", udiModel: "")
        XCTAssertEqual(rawOnly, "iPhone18,9")
        XCTAssertNotEqual(rawOnly, "iPhone 18")
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
        XCTAssertEqual(snap.model, "iPhone 14 Pro")
        XCTAssertEqual(snap.identifier, "iPhone15,2")
        XCTAssertEqual(snap.identifierCaption, "Identifier `iPhone15,2` is not the product name.")
        XCTAssertEqual(snap.volumeTotal, "128 GB")
        XCTAssertEqual(snap.freeImportant, "32.00 GB")
        XCTAssertEqual(snap.usedStorage, "96.00 GB")
        XCTAssertEqual(snap.batteryFraction, 0.64)
        XCTAssertNotNil(snap.storageUsedFraction)
        XCTAssertTrue(snap.sticky.contains("64 %"))
        XCTAssertTrue(snap.sticky.contains("Fair"))
        XCTAssertTrue(snap.sticky.contains("LPM on"))
        XCTAssertTrue(snap.copyText.contains("Low Power On"))
        XCTAssertTrue(snap.copyText.contains("Thermal Fair"))
        XCTAssertTrue(snap.copyText.contains("Identifier iPhone15,2 is not the product name"))
        XCTAssertTrue(snap.copyText.contains("Maximum Capacity / SoH"))
        XCTAssertTrue(snap.copyText.localizedCaseInsensitiveContains("Battery Health"))
        XCTAssertFalse(snap.copyText.localizedCaseInsensitiveContains("health score"))
        XCTAssertFalse(snap.copyText.contains("iPhone 18"))
        XCTAssertEqual(snap.saveOutputs["battery"], "64 %")
        XCTAssertEqual(snap.saveOutputs["thermal"], "Fair")
        XCTAssertEqual(snap.saveOutputs["low power"], "On")
        XCTAssertEqual(snap.saveOutputs["identifier"], "iPhone15,2")
        XCTAssertEqual(snap.saveOutputs["model"], "iPhone 14 Pro")
        XCTAssertEqual(snap.saveOutputs["battery health"], DeviceHealthMath.batteryHealthUnavailableValue)
        XCTAssertNotNil(snap.saveOutputs["free important"])
        XCTAssertNotNil(snap.saveOutputs["app headroom"])
        XCTAssertNotNil(snap.saveOutputs["used"])
    }

    func testIPhone17ProSnapshotUsesMarketingNameNotIPhone18() {
        let snap = DeviceHealthMath.snapshot(
            batteryLevel: 0.42,
            charge: .unplugged,
            lowPower: false,
            thermal: .nominal,
            freeImportantBytes: 55_980_000_000,
            freeOpportunisticBytes: 40_000_000_000,
            volumeTotalBytes: 256_000_000_000,
            identifier: "iPhone18,1",
            udiModel: "iPhone",
            systemName: "iOS",
            systemVersion: "26.7",
            uptimeSeconds: 3600,
            bootDate: nil,
            brightness: 0.5,
            physicalMemoryBytes: 8 * 1024 * 1024 * 1024,
            appHeadroomBytes: 800 * 1024 * 1024,
            activeProcessors: 6,
            installedProcessors: 6
        )
        XCTAssertEqual(snap.model, "iPhone 17 Pro")
        XCTAssertEqual(snap.identifier, "iPhone18,1")
        XCTAssertEqual(snap.system, "iOS 26.7")
        XCTAssertEqual(snap.battery, "42 %")
        XCTAssertEqual(snap.volumeTotal, "256 GB")
        XCTAssertEqual(snap.freeImportant, "55.98 GB")
        XCTAssertFalse(snap.model.contains("iPhone 18"))
        XCTAssertFalse(snap.copyText.contains("iPhone 18"))
        XCTAssertTrue(snap.copyText.contains("iPhone 17 Pro"))
        XCTAssertTrue(snap.identifierCaption.contains("`iPhone18,1`"))
        XCTAssertTrue(snap.copyText.contains(DeviceHealthMath.batteryHealthUnavailableNote))
        XCTAssertFalse(snap.copyText.contains("% SoH") || snap.copyText.contains("Maximum Capacity 8"))
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
