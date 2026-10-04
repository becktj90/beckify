import XCTest

final class NavigationTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchEnvironment["BECKIFY_NAV_DIAGNOSTICS"] = "1"
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
        XCTAssertTrue(toolToolbar("voltageDrop").waitForExistence(timeout: 5))
        XCTAssertTrue(toolToolbar("voltageDrop").isHittable)
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
        XCTAssertTrue(toolToolbar("wireAmpacity").waitForExistence(timeout: 5))
        XCTAssertTrue(toolToolbar("wireAmpacity").isHittable)

        swipeBack()
        XCTAssertTrue(toolToolbar("voltageDrop").waitForExistence(timeout: 5))
        XCTAssertTrue(toolToolbar("voltageDrop").isHittable)
        XCTAssertFalse(app.navigationBars["Jobsite"].exists)
        swipeBack()
        XCTAssertTrue(app.navigationBars["Jobsite"].waitForExistence(timeout: 5))
    }

    func testCancelledSwipeAndPinChangeKeepOnePageHistory() {
        let shelf = element("shelfCard.jobsite")
        reveal(shelf)
        shelf.tap()
        let tool = element("toolTile.voltageDrop")
        XCTAssertTrue(tool.waitForExistence(timeout: 5))
        tool.tap()
        XCTAssertTrue(toolToolbar("voltageDrop").waitForExistence(timeout: 5))

        let pin = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@",
            "Unpin Voltage Drop from home", "Pin Voltage Drop to home"
        )).firstMatch
        pin.tap()
        pin.tap()

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5))
        start.press(forDuration: 0, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1)
        XCTAssertTrue(toolToolbar("voltageDrop").isHittable)
        XCTAssertFalse(app.navigationBars["Jobsite"].exists)

        swipeBack()
        XCTAssertTrue(app.navigationBars["Jobsite"].waitForExistence(timeout: 5))
        XCTAssertTrue(tool.isHittable)
        app.navigationBars["Jobsite"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("homeAreaPicker").waitForExistence(timeout: 5))
        XCTAssertTrue(element("homeAreaPicker").isHittable)
    }

    private func toolToolbar(_ toolID: String) -> XCUIElement {
        app.buttons.matching(identifier: "howItWorksToolbar." + toolID).firstMatch
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
        let diagnostic = element("legacyBackSwipeDiagnostic")
        if diagnostic.exists { print("BECKIFY_NAV: " + diagnostic.label) }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        // Start inside the screen-edge region so the first touch reaches the window.
        start.press(forDuration: 0.05, thenDragTo: end)
        if diagnostic.exists { print("BECKIFY_NAV_AFTER: " + diagnostic.label) }
    }
}
