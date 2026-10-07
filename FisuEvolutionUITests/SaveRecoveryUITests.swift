import XCTest

/// La pantalla de recuperación: se llega con un save ilegible plantado por el fixture.
final class SaveRecoveryUITests: XCTestCase {
    @MainActor
    func testUnSaveIlegibleMuestraLaRecuperacionYEmpezarDeNuevoJuega() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-unreadable-save", "--uitest-skip-tutorial"]
        app.launch()
        XCTAssertTrue(app.otherElements["recovery.screen"].waitForExistence(timeout: 15))
        app.buttons["recovery.retry"].tap()
        XCTAssertTrue(app.otherElements["recovery.screen"].waitForExistence(timeout: 5), "el save sigue roto: no se sale")
        app.buttons["recovery.start_over"].tap()
        app.buttons["recovery.confirm.yes"].tap()
        XCTAssertTrue(app.otherElements["board.units"].waitForExistence(timeout: 15))
    }
}
