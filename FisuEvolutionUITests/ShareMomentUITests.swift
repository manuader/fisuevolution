import XCTest

/// Compartir (PLAN-v2 E3): el momento viral se ofrece como botón, abre la
/// tarjeta vertical y se descarta sin interrumpir. La hoja del sistema para
/// compartir no se puede completar desde el runner: eso lo cubre `ShareMomentTests`.
final class ShareMomentUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElMomentoViralSeOfreceComoBotonYAbreLaTarjeta() throws {
        let app = launch()
        offer(in: app)
        let button = app.buttons["share.offer"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "el momento no se ofreció")
        button.tap()
        XCTAssertTrue(app.buttons["share.button"].waitForExistence(timeout: 5), "no abrió la tarjeta")
        let skip = app.buttons["share.skip"]
        skip.tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 8))
        XCTAssertFalse(app.buttons["share.offer"].exists, "abrirla consume la oferta")
    }

    @MainActor
    func testLaOfertaSeDescartaConLaX() throws {
        let app = launch()
        offer(in: app)
        let dismiss = app.buttons["share.offer.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        dismiss.tap()
        XCTAssertTrue(app.buttons["share.offer"].waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testUnPersonajeNuevoAbreSuCardYSeguirCierraSinTocarElTablero() throws {
        let app = launch()
        openDebugRow("debug.share.character", in: app)
        let share = app.buttons["share.offer"]
        XCTAssertTrue(share.waitForExistence(timeout: 8), "el personaje nuevo no abrió su card")
        let keepGoing = app.buttons["share.card.continue"]
        XCTAssertTrue(keepGoing.exists, "falta «Seguir»")
        XCTAssertTrue(app.staticTexts["share.card.bonus"].exists || app.otherElements["share.card.bonus"].exists,
                      "el bonus tiene que estar a la vista")
        // Es lo único que bloquea: el tablero de atrás no recibe el toque.
        XCTAssertFalse(app.buttons["share.offer.dismiss"].exists, "la oferta chica no se suma a la card")
        keepGoing.tap()
        XCTAssertTrue(keepGoing.waitForNonExistence(timeout: 8))
        XCTAssertFalse(app.buttons["share.offer"].exists, "seguir cierra la card y no deja la oferta chica")
    }

    /// El caso de la captura del dueño (B11): la lección de compartir toma el turno y el chip que
    /// señala tiene que seguir a la vista, o la tarjeta queda colgada sin nada que tocar.
    @MainActor
    func testElTipDeCompartirSeNalaElChipYSeCierraConSuBoton() throws {
        let app = launch(extra: ["--uitest-lesson=share", "--uitest-tutorial-lock=0.3"])
        let tip = app.otherElements["tutorial.tip"]
        XCTAssertTrue(tip.waitForExistence(timeout: 20), "la lección de compartir no salió")
        offer(in: app)
        XCTAssertTrue(app.buttons["share.offer"].waitForExistence(timeout: 8),
                      "el tip señala un chip que no está a la vista: queda colgado")
        let lit = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "NOT (value BEGINSWITH 'missing') AND value != 'none'"),
            object: app.otherElements["tutorial.spotlight"])
        XCTAssertEqual(XCTWaiter().wait(for: [lit], timeout: 5), .completed, "el recorte no encuentra el chip")
        let close = app.buttons["tutorial.tip.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 3), "el tip no tiene botón de cerrar")
        close.tap()
        XCTAssertTrue(tip.waitForNonExistence(timeout: 5), "el botón no cerró el tip")
    }

    /// Aunque el chip no esté (la oferta se fue), el tip de una lección se cierra con su botón.
    @MainActor
    func testUnTipSinNadaQueSenalarSeCierraConSuBoton() throws {
        let app = launch(extra: ["--uitest-lesson=share", "--uitest-tutorial-lock=0.3"])
        let tip = app.otherElements["tutorial.tip"]
        XCTAssertTrue(tip.waitForExistence(timeout: 15), "la lección forzada no salió")
        let close = app.buttons["tutorial.tip.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 3), "el tip no tiene botón de cerrar")
        close.tap()
        XCTAssertTrue(tip.waitForNonExistence(timeout: 5), "el botón no cerró el tip")
    }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-share"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func offer(in app: XCUIApplication) {
        openDebugRow("debug.share.offer", in: app)
    }

    @MainActor
    private func openDebugRow(_ identifier: String, in app: XCUIApplication) {
        let debugKey = app.buttons["hud.debug"]
        XCTAssertTrue(debugKey.waitForExistence(timeout: 6))
        debugKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        // La lista del panel es perezosa: la fila puede estar bajo el pliegue.
        let button = app.buttons[identifier]
        var swipes = 0
        while !button.waitForExistence(timeout: 2), swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(button.exists, "el panel de debug no ofrece compartir")
        button.tap()
    }
}
