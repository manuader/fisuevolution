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

    /// Llega y espera con su tarjeta; el popup se abre al tocarla (E14b B21, D15).
    @MainActor
    private func openPopup(_ app: XCUIApplication, waitingFor option: XCUIElement) {
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 25), "el visitante no llegó")
        chip.tap()
        XCTAssertTrue(option.waitForExistence(timeout: 6), "tocar su tarjeta no abrió el popup")
    }

    @MainActor
    func testAceptarElRetoCambiaElChipPorElDelReto() throws {
        let app = launch("coach_reto")
        let chip = app.buttons["stage.chip.visitor"]
        let accept = app.buttons["visit.option.challenge"]
        openPopup(app, waitingFor: accept)
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
        openPopup(app, waitingFor: app.buttons["visit.option.card.mate"])
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

    @MainActor
    func testElVendedorSeOfendeYSeVaPisandoFuerte() throws {
        let app = launch("vendedor_ofertas")
        let decline = app.buttons["visit.option.decline"]
        openPopup(app, waitingFor: decline)
        decline.tap()
        let bye = app.buttons["visit.offended.bye"]
        XCTAssertTrue(bye.waitForExistence(timeout: 6), "el berretín: su frase ofendida y un «Chau»")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "vendedor: el berretín"
        shot.lifetime = .keepAlways
        add(shot)
        bye.tap()
        XCTAssertTrue(bye.waitForNonExistence(timeout: 6))
        XCTAssertTrue(app.buttons["stage.chip.visitor"].waitForNonExistence(timeout: 20), "se va y no deja tarjeta")
    }
}
