import XCTest

/// La Marcha del Puntero (E14b B25, D16) con la ventana corta de DEBUG (`--uitest-marcha-corta`,
/// 20 s): el popup con sus botones, el chip «Marcha 0/420» con su reloj, el estado al tocarlo y la
/// derrota al vencer. El festejo sale de una Marcha ya ganada (`--uitest-marcha-ganada`). Los 420
/// toques no se automatizan (son toques al tablero por coordenada, HANDOFF §7): los cuentan
/// `MarchTests` y `MarchRuntimeTests`.
final class MarchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testLaMarchaCortaArrancaMuestraSuChipYVenceSinPremio() throws {
        let app = launch(["--uitest-visitor=puntero_marcha", "--uitest-marcha-corta"])
        let visitorChip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(visitorChip.waitForExistence(timeout: 25), "el Puntero no llegó")
        visitorChip.tap()
        let accept = app.buttons["visit.option.challenge"]
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "tocar su tarjeta no abrió el popup")
        XCTAssertTrue(app.buttons["visit.option.decline"].exists, "«Hoy no marcho»")
        capture(app, "marcha: el pedido del Puntero")
        accept.tap()

        let chip = app.buttons["stage.chip.marcha"]
        XCTAssertTrue(chip.waitForExistence(timeout: 6), "la Marcha se juega con su chip en la esquina")
        capture(app, "marcha: el chip con el contador y el reloj")
        chip.tap()
        let close = app.buttons["marcha.status.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 6), "tocar el chip abre el estado")
        XCTAssertTrue(app.otherElements["marcha.status"].exists || app.staticTexts["marcha.status"].exists)
        capture(app, "marcha: el popup del estado")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 6))

        // La ventana corta vence sola: sale la línea de la derrota, sin premio.
        let ok = app.buttons["marcha.result.ok"]
        XCTAssertTrue(ok.waitForExistence(timeout: 40), "al vencer, el Puntero dice su línea")
        XCTAssertFalse(app.buttons["marcha.result.claim"].exists, "perdida no cobra")
        capture(app, "marcha: se desconcentró")
        ok.tap()
        XCTAssertTrue(ok.waitForNonExistence(timeout: 6))
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6), "cerrada, el chip se va")
    }

    @MainActor
    func testLaMarchaGanadaFestejaYCobraUnaVez() throws {
        let app = launch(["--uitest-marcha-ganada"])
        let claim = app.buttons["marcha.result.claim"]
        XCTAssertTrue(claim.waitForExistence(timeout: 25), "ganada, el Puntero sale a festejar")
        capture(app, "marcha: plaza llena")
        claim.tap()
        XCTAssertTrue(claim.waitForNonExistence(timeout: 6))
        XCTAssertTrue(app.buttons["stage.chip.marcha"].waitForNonExistence(timeout: 6), "cobrada, no queda nada")
    }
}
