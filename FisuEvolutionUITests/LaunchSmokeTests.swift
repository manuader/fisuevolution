import XCTest

/// Smoke test: the app launches, loads its content and shows the HUD.
final class LaunchSmokeTests: XCTestCase {
    @MainActor
    func testLaunchShowsCoinHUD() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        let coins = app.otherElements["hud.coins"]
        XCTAssertTrue(coins.waitForExistence(timeout: 15), "HUD coin counter never appeared")
    }

    @MainActor
    func testLaunchShowsBoundedTowerNavigator() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15), "tower pill never appeared")
        let down = app.buttons["tower.arrow.down"]
        let up = app.buttons["tower.arrow.up"]
        XCTAssertTrue(down.exists, "down arrow missing")
        XCTAssertTrue(up.exists, "up arrow missing")
        XCTAssertFalse(down.isEnabled, "new game must not navigate below the alley")
        XCTAssertTrue(up.isEnabled, "new game should preview its next locked floor")
    }

    @MainActor
    func testLockedFloorPreviewStopsAtOneFloorAhead() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        let initialLabel = pill.label
        let up = app.buttons["tower.arrow.up"]
        up.tap()
        let reachedPreview = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initialLabel), object: pill
        )
        XCTAssertEqual(XCTWaiter().wait(for: [reachedPreview], timeout: 3), .completed)
        XCTAssertFalse(up.isEnabled, "preview must not allow skipping another locked floor")
        XCTAssertTrue(app.buttons["tower.arrow.down"].isEnabled)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "F7.3 locked-floor-preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testTowerArrowsAndEmptyBoardSwipeNavigateOneFloor() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-unlock-tower"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        let up = app.buttons["tower.arrow.up"]
        XCTAssertTrue(up.isEnabled, "fixture should unlock the urban floor")
        let initialLabel = pill.label

        up.tap()
        let movedByArrow = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initialLabel), object: pill
        )
        XCTAssertEqual(XCTWaiter().wait(for: [movedByArrow], timeout: 3), .completed)
        XCTAssertTrue(app.buttons["tower.arrow.down"].isEnabled)

        // Centro del campo vacío: el swipe no debe iniciar tap/drag de unidad.
        let swipeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        let swipeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        swipeStart.press(forDuration: 0.05, thenDragTo: swipeEnd)
        let returnedBySwipe = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", initialLabel), object: pill
        )
        XCTAssertEqual(XCTWaiter().wait(for: [returnedBySwipe], timeout: 3), .completed)
    }
}
