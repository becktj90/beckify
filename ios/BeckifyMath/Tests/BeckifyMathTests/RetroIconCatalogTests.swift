import Foundation
import XCTest
@testable import BeckifyMath

/// Linux check that the iOS asset catalog still carries Trevor’s approved
/// retro CRT pack, one imageset per ToolID. `IconWell` looks these up as
/// `Retro/<ToolID>` and falls back to the canvas glyph when the imageset
/// is absent. This does not render SwiftUI.
final class RetroIconCatalogTests: XCTestCase {
    /// Hidden Power Wizard was excluded from the pack and stays off the grid.
    /// Every live toolbox tool, including statistics and Spanish, has a tile.
    private let canvasFallbackToolIDs: Set<String> = [
        "powerWizard",
        "switchgearLogicLab",
    ]

    /// Off the toolbox list, but related tools and deep links still draw a well.
    private let hiddenWithTile: Set<String> = ["phasorDiagram"]

    /// Shipped imagesets kept for asset continuity after the tool left the catalog.
    private let retiredImagesets: Set<String> = ["breathFlute", "lookCheck"]

    func testEveryLiveToolHasAnOriginalColorTile() throws {
        let root = retroRoot()
        let entries = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        let imagesets = entries
            .filter { $0.pathExtension == "imageset" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(imagesets.count, 90, "live tiles plus retired breathFlute and lookCheck")

        var shipped = Set<String>()
        for imageset in imagesets {
            let id = imageset.deletingPathExtension().lastPathComponent
            XCTAssertTrue(shipped.insert(id).inserted, "duplicate imageset \(id)")
            try assertImageset(imageset, id: id)
        }

        let known = Set(ToolCalculationPolicy.knownToolIDs)
        let unknown = shipped.subtracting(known).subtracting(retiredImagesets).sorted()
        XCTAssertTrue(unknown.isEmpty, "imagesets that are not ToolIDs: \(unknown.joined(separator: ", "))")
        for id in retiredImagesets {
            XCTAssertTrue(shipped.contains(id), "retired imageset missing: \(id)")
            XCTAssertFalse(known.contains(id), "retired tool still in knownToolIDs: \(id)")
        }
        XCTAssertEqual(
            known.subtracting(shipped),
            canvasFallbackToolIDs,
            "ToolIDs missing a retro tile changed — ship an imageset or update the canvas fallback"
        )
        for id in hiddenWithTile {
            XCTAssertTrue(shipped.contains(id), "\(id) is off the grid but IconWell still needs its tile")
        }

        let liveGrid = known.subtracting(["powerWizard", "phasorDiagram", "switchgearLogicLab"])
        let missingLive = liveGrid.subtracting(shipped).sorted()
        XCTAssertTrue(missingLive.isEmpty, "live tools still missing a tile: \(missingLive.joined(separator: ", "))")
        XCTAssertEqual(liveGrid.intersection(shipped).count, liveGrid.count)
        XCTAssertTrue(shipped.contains("statistics"))
        XCTAssertTrue(shipped.contains("spanishTranslator"))

        let folder = try Data(contentsOf: root.appendingPathComponent("Contents.json"))
        let folderJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: folder) as? [String: Any])
        let folderProps = try XCTUnwrap(folderJSON["properties"] as? [String: Any])
        XCTAssertEqual(
            folderProps["provides-namespace"] as? Bool,
            true,
            "IconWell looks up Retro/<ToolID>; the folder must provide that namespace"
        )
    }

    private func retroRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // BeckifyMathTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // BeckifyMath
            .deletingLastPathComponent() // ios
            .appendingPathComponent("Beckify")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("Retro", isDirectory: true)
    }

    private func assertImageset(_ imageset: URL, id: String) throws {
        let data = try Data(contentsOf: imageset.appendingPathComponent("Contents.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], id)
        let props = try XCTUnwrap(json["properties"] as? [String: Any], id)
        XCTAssertEqual(props["template-rendering-intent"] as? String, "original", id)
        let images = try XCTUnwrap(json["images"] as? [[String: Any]], id)
        var scales: [String: String] = [:]
        for image in images {
            let scale = try XCTUnwrap(image["scale"] as? String, id)
            let filename = try XCTUnwrap(image["filename"] as? String, id)
            XCTAssertNil(scales[scale], "duplicate scale \(scale) for \(id)")
            scales[scale] = filename
        }
        XCTAssertEqual(Set(scales.keys), ["1x", "2x", "3x"], id)
        try assertPNG(imageset.appendingPathComponent(scales["1x"]!), size: 64, id: id)
        try assertPNG(imageset.appendingPathComponent(scales["2x"]!), size: 128, id: id)
        try assertPNG(imageset.appendingPathComponent(scales["3x"]!), size: 192, id: id)
    }

    private func assertPNG(_ url: URL, size: Int, id: String) throws {
        let data = try Data(contentsOf: url)
        let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertEqual(data.prefix(8), signature, "\(id) \(url.lastPathComponent) is not a PNG")
        guard data.count >= 24 else {
            XCTFail("\(id) \(url.lastPathComponent) is shorter than a PNG header")
            return
        }
        XCTAssertEqual(pngDimension(data, offset: 16), size, "\(id) \(url.lastPathComponent) width")
        XCTAssertEqual(pngDimension(data, offset: 20), size, "\(id) \(url.lastPathComponent) height")
    }

    private func pngDimension(_ data: Data, offset: Int) -> Int {
        let bytes = [UInt8](data[offset..<(offset + 4)])
        let value = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        return Int(value)
    }
}
