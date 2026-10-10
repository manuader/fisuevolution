import XCTest

/// La pausa publicitaria en pantalla (PLAN-v2 E7). Con `--uitest-ad-break` la
/// pausa sale en cada corte; el anuncio lo pone el stub (2 s, y paga).
@MainActor
final class AdBreakUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaPausaSeOfreceYSePuedeRechazar() {
        let app = launch()
        closeAScreen(app)
        let decline = app.buttons["adbreak.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 5), "la pantalla previa no apareció al cerrar el menú")
        XCTAssertTrue(app.buttons["adbreak.watch"].exists)
        // La cuenta ya pudo bajar un segundo mientras se esperaba el botón.
        let seconds = Int(app.otherElements["adbreak.intro"].value as? String ?? "")
        XCTAssertTrue((1...5).contains(seconds ?? 0), "la cuenta regresiva no está en 1...5: \(String(describing: seconds))")
        decline.tap()
        XCTAssertTrue(decline.waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons["tower.notice"].exists, "rechazarla no da ni quita nada")
    }

    func testSiNoSeRechazaElAnuncioPagaSuPremio() {
        let app = launch()
        closeAScreen(app)
        XCTAssertTrue(app.buttons["adbreak.decline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tower.notice"].waitForExistence(timeout: 12), "5 s de cuenta + 2 s de anuncio + el aviso")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-ad-break"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.upgrades"].waitForExistence(timeout: 30))
        return app
    }

    private func closeAScreen(_ app: XCUIApplication) {
        app.buttons["hud.upgrades"].tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
    }
}
