import XCTest

/// Un visitante de punta a punta: entra, se toca su chip, se cierra el trato y
/// se va. La entrada sale de `--uitest-visitor=<guion>` (los visitantes vienen
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
    func testElVisitanteEntraSeLoTocaYCierraElTrato() throws {
        let app = launch("turista_propina")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "el turista tiene que llegar y dejar su chip")
        attach(app, "visitante: en escena con su chip")
        chip.tap()
        let accept = app.buttons["visit.option.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "el popup ofrece aceptar")
        XCTAssertTrue(app.buttons["visit.option.video"].exists, "y el ×2 con video")
        attach(app, "visitante: el popup")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 6), "elegir cierra el popup")
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6), "y sin trato no queda chip")
    }

    @MainActor
    func testElVideoDelVisitanteCierraElTratoAlTerminar() throws {
        let app = launch("ministro_subsidio")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        let video = app.buttons["visit.option.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 6))
        video.tap()
        // El anuncio del stub dura 2 s; el trato se cierra cuando termina.
        XCTAssertTrue(video.waitForNonExistence(timeout: 10))
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6))
    }

    @MainActor
    func testCerrarElPopupSinElegirLoDejaEsperando() throws {
        let app = launch("turista_propina")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 6))
        close.tap()
        XCTAssertTrue(app.buttons["visit.option.accept"].waitForNonExistence(timeout: 6))
        XCTAssertTrue(chip.exists, "cerrar no lo echa: sigue esperando")
    }
}
