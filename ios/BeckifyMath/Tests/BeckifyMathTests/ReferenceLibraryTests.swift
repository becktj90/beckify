import XCTest
@testable import BeckifyMath

final class ReferenceLibraryTests: XCTestCase {
    func testEveryTopicHasContentAndUniqueCodes() {
        XCTAssertFalse(ReferenceLibrary.topics.isEmpty)
        for topic in ReferenceLibrary.topics {
            XCTAssertFalse(topic.entries.isEmpty, topic.id)
            XCTAssertFalse(topic.purpose.isEmpty, topic.id)
            XCTAssertFalse(topic.source.isEmpty, topic.id)
            XCTAssertEqual(
                Set(topic.entries.map(\.code)).count,
                topic.entries.count,
                "\(topic.id) has a duplicate code"
            )
            for entry in topic.entries {
                XCTAssertFalse(entry.title.isEmpty, "\(topic.id)/\(entry.code)")
                XCTAssertFalse(entry.detail.isEmpty, "\(topic.id)/\(entry.code)")
            }
        }
    }

    func testTopicIDsAreUniqueAndLookupWorks() {
        let ids = ReferenceLibrary.topics.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ReferenceLibrary.topic(id: "ip-ratings")?.title, "IP Rating Chart")
        XCTAssertNil(ReferenceLibrary.topic(id: "not-a-topic"))
    }

    func testSearchNarrowsToMatchingEntries() throws {
        let results = ReferenceLibrary.matching("4X")
        let enclosures = try XCTUnwrap(results.first { $0.id == "nema-enclosures" })

        XCTAssertEqual(enclosures.entries.map(\.code), ["4X"])
    }

    func testSearchMatchesTopicTitleAndKeepsAllEntries() throws {
        let results = ReferenceLibrary.matching("enclosure")
        let topic = try XCTUnwrap(results.first { $0.id == "nema-enclosures" })

        XCTAssertEqual(topic.entries.count, ReferenceLibrary.nemaEnclosures.entries.count)
    }

    func testEmptySearchReturnsEverythingAndMissIsEmpty() {
        XCTAssertEqual(ReferenceLibrary.matching("   ").count, ReferenceLibrary.topics.count)
        XCTAssertTrue(ReferenceLibrary.matching("zzzznotathing").isEmpty)
    }

    /// The standard-size screen must read from the same tables the calculators
    /// use, so a code update cannot leave the reference page stale.
    func testStandardSizesTrackNECTables() throws {
        let topic = ReferenceLibrary.standardSizes
        let ocpd = try XCTUnwrap(topic.entries.first { $0.code == "OCPD" })

        XCTAssertTrue(ocpd.detail.contains("\(NECTables.standardOCPD[0])"))
        XCTAssertTrue(ocpd.detail.contains("\(NECTables.standardOCPD.last!)"))
    }

    func testBoltTorqueCoversCommonSizes() {
        let torque = ReferenceLibrary.boltTorque
        XCTAssertTrue(torque.entries.contains { $0.code == "3/8-16" })
        XCTAssertTrue(torque.entries.contains { $0.code == "M8" })
    }
}
