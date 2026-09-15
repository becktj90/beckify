import XCTest
@testable import BeckifyMath

final class BLEAdvertisementMathTests: XCTestCase {

    func testManufacturerDataNeedsTwoBytes() {
        XCTAssertNil(BLEAdvertisementMath.parseManufacturerData([] as [UInt8]))
        XCTAssertNil(BLEAdvertisementMath.parseManufacturerData([0x4C]))
    }

    func testManufacturerCompanyIDIsLittleEndian() throws {
        let apple = try XCTUnwrap(BLEAdvertisementMath.parseManufacturerData([0x4C, 0x00, 0x10, 0x06]))
        XCTAssertEqual(apple.companyID, 0x004C)
        XCTAssertEqual(apple.companyName, "Apple")
        XCTAssertEqual(apple.payloadByteCount, 2)
        XCTAssertFalse(apple.looksLikeIBeacon)

        let samsung = try XCTUnwrap(BLEAdvertisementMath.parseManufacturerData([0x75, 0x00]))
        XCTAssertEqual(samsung.companyID, 0x0075)
        XCTAssertEqual(samsung.companyName, "Samsung")
        XCTAssertEqual(samsung.payloadByteCount, 0)

        let beAppleWouldBeWrong = try XCTUnwrap(BLEAdvertisementMath.parseManufacturerData([0x00, 0x4C]))
        XCTAssertEqual(beAppleWouldBeWrong.companyID, 0x4C00)
        XCTAssertEqual(beAppleWouldBeWrong.companyName, "Company 0x4C00")
    }

    func testKnownCompanyLookupsCiteSIGTable() {
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x004C), "Apple")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x0075), "Samsung")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x00E0), "Google")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x0006), "Microsoft")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x067C), "Tile")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x0059), "Nordic")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x02E5), "Espressif")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x0087), "Garmin")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x012D), "Sony")
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0x009E), "Bose")
        XCTAssertTrue(BLEAdvertisementMath.isKnownCompany(id: 0x004C))
        XCTAssertFalse(BLEAdvertisementMath.isKnownCompany(id: 0xFFFF))
        XCTAssertEqual(BLEAdvertisementMath.companyName(id: 0xFFFF), "Company 0xFFFF")
        XCTAssertEqual(BLEAdvertisementMath.formatCompanyID(0x004C), "0x004C")
    }

    func testIBeaconPrefixIsDetectedWithoutDecodingUUID() throws {
        var bytes: [UInt8] = [0x4C, 0x00, 0x02, 0x15]
        bytes.append(contentsOf: Array(repeating: 0xAB, count: 21))
        let parsed = try XCTUnwrap(BLEAdvertisementMath.parseManufacturerData(bytes))
        XCTAssertTrue(parsed.looksLikeIBeacon)
        XCTAssertEqual(parsed.payloadByteCount, 23)
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(
                name: "Unnamed",
                companyID: parsed.companyID,
                serviceIDs: [],
                looksLikeIBeacon: parsed.looksLikeIBeacon
            ),
            .beacon
        )
    }

    func testKindHeuristicsFromCompanyAndServices() {
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(name: "SigMesh", companyID: nil, serviceIDs: []),
            .mesh
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(name: "Node", companyID: nil, serviceIDs: ["1828"]),
            .mesh
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(
                name: "Unnamed",
                companyID: nil,
                serviceIDs: [],
                serviceDataUUIDs: ["FEAA"]
            ),
            .beacon
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(name: "QC35", companyID: 0x009E, serviceIDs: []),
            .audio
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(
                name: "Watch",
                companyID: nil,
                serviceIDs: ["0000180D-0000-1000-8000-00805F9B34FB"]
            ),
            .fitness
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(name: "Fenix", companyID: 0x0087, serviceIDs: []),
            .fitness
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(name: "Tile", companyID: 0x067C, serviceIDs: []),
            .wearable
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(name: "Unnamed", companyID: 0x004C, serviceIDs: []),
            .phoneEcosystem
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(
                name: "Pixel",
                companyID: nil,
                serviceIDs: ["FE2C"]
            ),
            .phoneEcosystem
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(name: "Unnamed", companyID: nil, serviceIDs: []),
            .unnamedNoise
        )
        XCTAssertEqual(
            BLEAdvertisementMath.kindHint(name: "ClearSky Smart Fleet", companyID: 0x02E5, serviceIDs: []),
            .unknown
        )
    }

    func testRowChipPrefersKindThenKnownManufacturer() {
        XCTAssertEqual(
            BLEAdvertisementMath.rowChip(kind: .phoneEcosystem, companyID: 0x004C),
            "Phone-ecosystem"
        )
        XCTAssertEqual(
            BLEAdvertisementMath.rowChip(kind: .unknown, companyID: 0x02E5),
            "Espressif"
        )
        XCTAssertNil(BLEAdvertisementMath.rowChip(kind: .unnamedNoise, companyID: nil))
        XCTAssertNil(BLEAdvertisementMath.rowChip(kind: .unknown, companyID: 0xABCD))
    }

    func testServiceDataSkipsHugeHex() {
        let small = BLEAdvertisementMath.summarizeServiceData(uuid: "feaa", bytes: [0x10, 0xEE])
        XCTAssertEqual(small.uuid, "FEAA")
        XCTAssertEqual(small.previewHex, "10 EE")
        let huge = BLEAdvertisementMath.summarizeServiceData(
            uuid: "FEAA",
            bytes: Array(repeating: 0x01, count: 40)
        )
        XCTAssertEqual(huge.byteCount, 40)
        XCTAssertNil(huge.previewHex)
        XCTAssertEqual(
            BLEAdvertisementMath.serviceDataCaption([small, huge]),
            "FEAA (2 B), FEAA (40 B)"
        )
    }

    func testSummaryCountsNamedBandsAndManufacturers() {
        let rows = [
            BLEScanTallyRow(name: "AirPods", rssi: -40, companyID: 0x004C),
            BLEScanTallyRow(name: "Unnamed", rssi: -44, companyID: 0x004C),
            BLEScanTallyRow(name: "Unnamed", rssi: -70, companyID: 0x0075),
            BLEScanTallyRow(name: "Esp node", rssi: -90, companyID: 0x02E5),
            BLEScanTallyRow(name: "Unnamed", rssi: 127, companyID: nil),
        ]
        let summary = BLEAdvertisementMath.summarize(rows, topManufacturers: 3)
        XCTAssertEqual(summary.total, 5)
        XCTAssertEqual(summary.named, 2)
        XCTAssertEqual(summary.unnamed, 3)
        XCTAssertEqual(summary.near, 2)
        XCTAssertEqual(summary.mid, 1)
        XCTAssertEqual(summary.far, 1)
        XCTAssertEqual(summary.unknownBand, 1)
        XCTAssertEqual(summary.topManufacturers.map(\.name), ["Apple", "Samsung", "Espressif"])
        XCTAssertEqual(summary.topManufacturers.first?.count, 2)
        XCTAssertTrue(summary.stickyLine.contains("≠ people"))
        XCTAssertTrue(summary.copyLine.contains("Device count ≠ people"))
        XCTAssertTrue(summary.copyLine.localizedCaseInsensitiveContains("not occupancy"))
        XCTAssertFalse(summary.copyLine.localizedCaseInsensitiveContains("how many people"))
        XCTAssertEqual(BLEAdvertisementMath.displayName("  "), "Unnamed")
        XCTAssertFalse(BLEAdvertisementMath.isNamed("Unnamed"))
    }

    func testShortServiceKeyCollapsesBluetoothBaseUUID() {
        XCTAssertEqual(
            BLEAdvertisementMath.shortServiceKey("0000180D-0000-1000-8000-00805F9B34FB"),
            "180D"
        )
        XCTAssertEqual(BLEAdvertisementMath.shortServiceKey("180d"), "180D")
        XCTAssertEqual(
            BLEAdvertisementMath.shortServiceKey("A1B2C3D4-E5F6-7890-ABCD-EF1234567890"),
            "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        )
    }
}
