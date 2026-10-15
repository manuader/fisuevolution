import XCTest

/// Un visitante de punta a punta: entra, camina al medio del piso y espera caminando; su popup se
/// abre sólo al tocarlo (E14b B21, D15: ya no sale solo como desde E14 C2), se cierra el trato y se
/// va. La entrada sale de `--uitest-visitor=<guion>` (los visitantes vienen cada 4–6 min de juego:
/// sin la puerta el test mediría la paciencia); el fixture lo presenta en el primer momento calmo.
final class VisitorUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ script: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-visitor=\(script)"] + extra
        app.launch()
        return app
    }

    /// Llega y espera con su tarjeta, sin abrir nada solo; tocar la tarjeta abre el popup.
    @MainActor
    private func openByTapping(_ app: XCUIApplication, waitingFor option: XCUIElement) {
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 25), "el visitante no llegó")
        XCTAssertFalse(option.waitForExistence(timeout: 3), "el popup no sale solo al llegar (B21)")
        chip.tap()
        XCTAssertTrue(option.waitForExistence(timeout: 6), "tocar su tarjeta abre el popup")
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, value: String, timeout: TimeInterval) -> Bool {
        let reached = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testElVisitanteLlegaYAlTocarloAbreSuPopupYCierraElTrato() throws {
        let app = launch("turista_propina")
        let chip = app.buttons["stage.chip.visitor"]
        let accept = app.buttons["visit.option.accept"]
        openByTapping(app, waitingFor: accept)
        XCTAssertTrue(app.buttons["visit.option.video"].exists, "y el ×2 con video")
        XCTAssertTrue(app.buttons["visit.option.decline"].exists, "«No, gracias» siempre a la vista")
        attach(app, "visitante: el popup abierto al tocarlo")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 6), "elegir cierra el popup")
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6), "y sin trato no queda chip")
    }

    @MainActor
    func testElVideoDelVisitanteCierraElTratoAlTerminar() throws {
        let app = launch("ministro_subsidio")
        let chip = app.buttons["stage.chip.visitor"]
        let video = app.buttons["visit.option.video"]
        openByTapping(app, waitingFor: video)
        video.tap()
        // El anuncio del stub dura 2 s; el trato se cierra cuando termina.
        XCTAssertTrue(video.waitForNonExistence(timeout: 10))
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6))
    }

    @MainActor
    func testCerrarElPopupSinElegirLoDejaEsperandoYNoSeReabreSolo() throws {
        let app = launch("turista_propina")
        let chip = app.buttons["stage.chip.visitor"]
        let close = app.buttons["sheet.close"]
        openByTapping(app, waitingFor: close)
        close.tap()
        let accept = app.buttons["visit.option.accept"]
        XCTAssertTrue(accept.waitForNonExistence(timeout: 6))
        XCTAssertTrue(chip.waitForExistence(timeout: 6), "cerrar no lo echa: sigue esperando, con su tarjeta")
        XCTAssertFalse(accept.waitForExistence(timeout: 4), "el popup no vuelve solo")
        attach(app, "visitante: esperando en el medio del piso")
        chip.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "la tarjeta lo reabre")
    }

    /// B21 (D15): un merge en medio de la entrada no la corta. Los ocho Fisuras de `--uitest-merge-all`
    /// deambulan por el piso mientras el turista entra; el doble toque fusiona un par sin saltear la
    /// caminata. Se barre en X como en `BoardGestureUITests`: sólo un merge baja `board.units`.
    /// `--uitest-slow-entrance` estira la entrada a ~11 s, y la tarjeta (que sale al llegar) tiene que
    /// faltar antes y después del merge: si el merge cayó con el visitante ya llegado, el test falla.
    @MainActor
    func testUnMergeEnMedioDeLaEntradaNoLaCortaYTocarloAbreElPopup() throws {
        let app = launch("turista_propina", extra: ["--uitest-merge-all", "--uitest-slow-entrance"])
        let units = app.otherElements["board.units"]
        let chip = app.buttons["stage.chip.visitor"]
        let accept = app.buttons["visit.option.accept"]
        XCTAssertTrue(waitFor(units, value: "8", timeout: 15), "el fixture no sembró los ocho")
        var merged = false
        for x in [0.30, 0.42, 0.55, 0.68, 0.20, 0.80, 0.36, 0.62] where !merged {
            XCTAssertFalse(chip.exists, "el visitante llegó antes del merge: el test no probó la entrada")
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.74)).doubleTap()
            merged = waitFor(units, value: "7", timeout: 0.6)
        }
        XCTAssertTrue(merged, "el doble toque no fusionó ningún par")
        XCTAssertFalse(chip.exists, "el merge tiene que caer con el visitante todavía entrando")
        attach(app, "B21: el merge, con el visitante entrando")
        XCTAssertTrue(chip.waitForExistence(timeout: 25), "la entrada terminó entera: llegó y espera con su tarjeta")
        XCTAssertFalse(accept.waitForExistence(timeout: 3), "llegó sin abrir el popup solo")
        attach(app, "B21: esperando en el medio del piso, sin popup")
        chip.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "al tocarlo se abre el popup")
    }
}
