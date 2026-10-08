import XCTest

final class CorralitoUITests: XCTestCase {
    @MainActor
    func testElCorralitoTiemblaConSuMotivoYOfreceLaSalidaPorVideo() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins", "--uitest-corralito"]
        app.launch()
        XCTAssertTrue(app.buttons["event.escape"].waitForExistence(timeout: 15))
        app.buttons["hud.quickhire"].tap()
        XCTAssertTrue(app.buttons["tower.notice"].waitForExistence(timeout: 5))
        app.buttons["hud.hire"].tap()
        XCTAssertTrue(app.otherElements["jobs.spending_frozen"].waitForExistence(timeout: 5))
    }
}
