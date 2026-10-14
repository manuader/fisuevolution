import XCTest

/// Un visitante de punta a punta: entra, camina al horizonte, abre su popup solo
/// (E14 C2), se cierra el trato y se va. La entrada sale de `--uitest-visitor=<guion>` (los visitantes vienen
/// cada 4–6 min de juego: sin la puerta el test mediría la paciencia); el
/// fixture lo presenta en el primer momento calmo.
final class VisitorUITests: XCTestCase {
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
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testElVisitanteLlegaAbreSuPopupSoloYCierraElTrato() throws {
        let app = launch("turista_propina")
        let chip = app.buttons["stage.chip.visitor"]
        let accept = app.buttons["visit.option.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 25), "el turista llega y el popup sale solo, sin tocar nada")
        XCTAssertTrue(app.buttons["visit.option.video"].exists, "y el ×2 con video")
        XCTAssertTrue(app.buttons["visit.option.decline"].exists, "«No, gracias» siempre a la vista")
        attach(app, "visitante: el popup salió solo")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 6), "elegir cierra el popup")
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6), "y sin trato no queda chip")
    }

    @MainActor
    func testElVideoDelVisitanteCierraElTratoAlTerminar() throws {
        let app = launch("ministro_subsidio")
        let chip = app.buttons["stage.chip.visitor"]
        let video = app.buttons["visit.option.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 25))
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
        XCTAssertTrue(close.waitForExistence(timeout: 25))
        close.tap()
        let accept = app.buttons["visit.option.accept"]
        XCTAssertTrue(accept.waitForNonExistence(timeout: 6))
        XCTAssertTrue(chip.waitForExistence(timeout: 6), "cerrar no lo echa: sigue esperando, con su tarjeta")
        XCTAssertFalse(accept.waitForExistence(timeout: 4), "el popup no vuelve solo")
        attach(app, "visitante: esperando en el horizonte")
        chip.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "la tarjeta lo reabre")
    }
}
