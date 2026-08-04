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
        XCTAssertFalse(up.isEnabled, "new game must not navigate into a locked floor")
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
