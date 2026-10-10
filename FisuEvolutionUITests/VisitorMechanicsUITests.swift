import XCTest

/// Las dos mecánicas con pantalla propia: el reto (su chip reemplaza al del
/// visitante) y el Vendedor (tres cartas, una por visita). Los toques del reto
/// no se automatizan: son toques al tablero por coordenada (HANDOFF §7); los
/// cuenta `VisitorRuntimeTests`.
final class VisitorMechanicsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ script: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-visitor=\(script)"]
        app.launch()
        return app
    }

    @MainActor
    func testAceptarElRetoCambiaElChipPorElDelReto() throws {
        let app = launch("coach_reto")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        let accept = app.buttons["visit.option.challenge"]
        XCTAssertTrue(accept.waitForExistence(timeout: 6))
        accept.tap()
        let challenge = app.otherElements["stage.chip.challenge"]
        XCTAssertTrue(challenge.waitForExistence(timeout: 6), "el reto se juega en el tablero, con su contador")
        XCTAssertFalse(chip.exists, "mientras dura el reto no hay popup que abrir")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "reto: el chip con el contador"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testElVendedorMuestraTresCartasYSeLlevaUna() throws {
        let app = launch("vendedor_ofertas")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        for card in ["mate", "cafe", "turbo"] {
            XCTAssertTrue(app.buttons["visit.option.card.\(card)"].waitForExistence(timeout: 6), "falta la carta \(card)")
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "vendedor: las tres cartas"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["visit.option.card.mate"].tap()
        // El anuncio del stub dura 2 s; el boost queda corriendo y el Vendedor se va.
        XCTAssertTrue(app.otherElements["hud.bonus.chip"].waitForExistence(timeout: 10)
            || app.staticTexts["hud.bonus.chip"].waitForExistence(timeout: 1))
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6))
    }
}
