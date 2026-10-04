import XCTest

final class NavigationTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testSwipeBackFromToolReturnsToShelfBeforeHome() {
        let shelf = element("shelfCard.jobsite")
        reveal(shelf)
        shelf.tap()
        XCTAssertTrue(app.navigationBars["Jobsite"].waitForExistence(timeout: 5))

        let tool = element("toolTile.voltageDrop")
        XCTAssertTrue(tool.waitForExistence(timeout: 5))
        tool.tap()
        XCTAssertFalse(app.navigationBars["Jobsite"].exists)

        swipeBack()
        XCTAssertTrue(app.navigationBars["Jobsite"].waitForExistence(timeout: 5))
        XCTAssertTrue(tool.isHittable)
        XCTAssertFalse(element("homeAreaPicker").isHittable)

        swipeBack()
        XCTAssertTrue(element("homeAreaPicker").waitForExistence(timeout: 5))
        XCTAssertTrue(element("homeAreaPicker").isHittable)
    }

    func testSwipeBackFromRelatedToolReturnsToPreviousToolThenShelf() {
        let shelf = element("shelfCard.jobsite")
        reveal(shelf)
        shelf.tap()
        let tool = element("toolTile.voltageDrop")
        XCTAssertTrue(tool.waitForExistence(timeout: 5))
        tool.tap()
        let related = app.buttons["Open related tool Wire Size & Ampacity"]
        reveal(related)
        related.tap()
        XCTAssertTrue(app.staticTexts["Wire Size & Ampacity"].waitForExistence(timeout: 5))

        swipeBack()
        XCTAssertTrue(app.staticTexts["Voltage Drop"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Jobsite"].exists)
        swipeBack()
        XCTAssertTrue(app.navigationBars["Jobsite"].waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func reveal(_ target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if target.exists && target.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Could not reach \(target)", file: file, line: line)
    }

    private func swipeBack() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}
