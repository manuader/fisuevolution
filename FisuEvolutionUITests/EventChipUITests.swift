import XCTest

/// Un evento de punta a punta: entra su presentador, lo anuncia, queda su chip
/// con la cara, y el popup ofrece la salida.
final class EventChipUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElPresentadorAnunciaYElChipAbreLaSalida() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-event=devaluacion"]
        app.launch()
        let chip = app.buttons["hud.event.chip.devaluacion"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "el presentador llega y el evento deja su chip")
        let anuncio = XCTAttachment(screenshot: app.screenshot())
        anuncio.name = "evento: el presentador y el chip"
        anuncio.lifetime = .keepAlways
        add(anuncio)
        chip.tap()
        let escape = app.buttons["event.escape"]
        XCTAssertTrue(escape.waitForExistence(timeout: 6))
        escape.tap()
        // El anuncio del stub dura 2 s; al terminar, el evento se va y su chip también.
        XCTAssertTrue(chip.waitForNonExistence(timeout: 12))
    }
}
