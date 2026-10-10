import XCTest
@testable import BeckifyMath

final class AppVersionCheckTests: XCTestCase {
    func testSemanticOrderingNotLexical() {
        XCTAssertEqual(AppVersionCheck.compare("1.0.10", "1.0.9"), .orderedDescending)
        XCTAssertEqual(AppVersionCheck.compare("1.0.6", "1.0.7"), .orderedAscending)
        XCTAssertEqual(AppVersionCheck.compare("2.0", "1.9.9"), .orderedDescending)
    }

    func testMissingComponentsPadWithZero() {
        XCTAssertEqual(AppVersionCheck.compare("1.0", "1.0.0"), .orderedSame)
        XCTAssertEqual(AppVersionCheck.compare("1.1", "1.0.9"), .orderedDescending)
    }

    func testIsStoreNewer() {
        XCTAssertTrue(AppVersionCheck.isStoreNewer(store: "1.0.7", installed: "1.0.6"))
        XCTAssertFalse(AppVersionCheck.isStoreNewer(store: "1.0.6", installed: "1.0.6"))
        // Installed build ahead of the store (TestFlight / review) never prompts.
        XCTAssertFalse(AppVersionCheck.isStoreNewer(store: "1.0.5", installed: "1.0.6"))
        XCTAssertFalse(AppVersionCheck.isStoreNewer(store: "", installed: "1.0.6"))
    }

    func testThrottleOncePerDay() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(AppVersionCheck.shouldCheck(lastCheck: nil, now: now))
        XCTAssertFalse(AppVersionCheck.shouldCheck(lastCheck: now.addingTimeInterval(-3600), now: now))
        XCTAssertTrue(AppVersionCheck.shouldCheck(lastCheck: now.addingTimeInterval(-86_400), now: now))
        XCTAssertTrue(AppVersionCheck.shouldCheck(lastCheck: now.addingTimeInterval(3600), now: now))
    }

    func testParsesLookupResponse() {
        let json = #"{"resultCount":1,"results":[{"version":"1.0.7","trackId":6807908745}]}"#
        XCTAssertEqual(AppVersionCheck.storeVersion(fromLookup: Data(json.utf8)), "1.0.7")
        XCTAssertNil(AppVersionCheck.storeVersion(fromLookup: Data(#"{"resultCount":0,"results":[]}"#.utf8)))
        XCTAssertNil(AppVersionCheck.storeVersion(fromLookup: Data("nope".utf8)))
    }
}
