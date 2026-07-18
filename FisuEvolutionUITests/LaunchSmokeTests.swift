import XCTest

/// Smoke test: the app launches, loads its content and shows the HUD.
final class LaunchSmokeTests: XCTestCase {
    @MainActor
    func testLaunchShowsCoinHUD() throws {
        let app = XCUIApplication()
        app.launch()

        let coins = app.staticTexts["hud.coins"]
        XCTAssertTrue(coins.waitForExistence(timeout: 15), "HUD coin counter never appeared")
    }
}
