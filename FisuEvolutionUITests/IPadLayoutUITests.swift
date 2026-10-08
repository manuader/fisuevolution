import XCTest

/// La app universal en el iPad (PLAN-v2 E3): a pantalla completa, sin barras,
/// con el tablero en su celda tope y los textos de la escena escalados.
///
/// Corre sólo en iPad: en el paso `ui` del oráculo (iPhone 16 Pro) se saltea, y
/// el paso `ipad-ui` la corre en un iPad Pro 13" propio.
final class IPadLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        let isPad = MainActor.assumeIsolated { UIDevice.current.userInterfaceIdiom == .pad }
        try XCTSkipUnless(isPad, "sólo en iPad (paso ipad-ui del oráculo)")
        continueAfterFailure = false
    }

    @MainActor
    func testElJuegoOcupaLaPantallaSinBarras() throws {
        let app = launch()
        let window = app.windows.element(boundBy: 0).frame
        let screen = XCUIScreen.main.screenshot().image.size
        XCTAssertEqual(window.width, screen.width, accuracy: 1,
                       "la ventana mide \(window.width) en una pantalla de \(screen.width): modo compatibilidad")
        XCTAssertEqual(window.height, screen.height, accuracy: 1)
        attach(app, named: "E3 iPad tablero")
    }

    @MainActor
    func testElTableroTopeaLaCeldaYEscalaLosTextos() throws {
        let app = launch()
        let marker = app.otherElements["board.layout"]
        XCTAssertTrue(marker.waitForExistence(timeout: 20))
        let value = try XCTUnwrap(marker.value as? String, "board.layout sin valor")
        // "5x2@112·1.25": columnas x filas @ celda · escala de texto.
        let cell = try XCTUnwrap(Double(value.split(separator: "@")[1].split(separator: "·")[0]), value)
        XCTAssertLessThanOrEqual(cell, 112, value)
        XCTAssertTrue(value.hasSuffix("·1.25"), "los textos de la escena escalan en iPad: \(value)")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 30), "la barra nunca apareció")
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
