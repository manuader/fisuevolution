import XCTest

final class CorralitoUITests: XCTestCase {
    @MainActor
    func testElCorralitoTiemblaConSuMotivoYOfreceLaSalidaPorVideo() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins", "--uitest-corralito"]
        app.launch()
        let chip = app.buttons["hud.event.chip.corralito"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        XCTAssertTrue(app.buttons["event.escape"].waitForExistence(timeout: 6), "la salida por video vive en el popup")
        app.buttons["sheet.close"].tap()
        XCTAssertTrue(app.buttons["event.escape"].waitForNonExistence(timeout: 6))
        app.buttons["hud.quickhire"].tap()
        XCTAssertTrue(app.buttons["tower.notice"].waitForExistence(timeout: 5))
        app.buttons["hud.hire"].tap()
        XCTAssertTrue(app.otherElements["jobs.spending_frozen"].waitForExistence(timeout: 5))
    }
}
