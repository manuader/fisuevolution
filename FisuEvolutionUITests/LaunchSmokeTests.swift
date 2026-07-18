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
}
