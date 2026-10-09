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

    /// El chrome vive en una columna de 592 pt centrada (`PlayColumn`): ningún
    /// control se estira hacia los bordes del iPad.
    @MainActor
    func testElChromeVaEnUnaColumnaCentrada() throws {
        let app = launch()
        let window = app.windows.element(boundBy: 0).frame
        let left = window.midX - 296 - 1
        let right = window.midX + 296 + 1
        for identifier in ["hud.coins.plus", "hud.map", "hud.upgrades", "hud.hire", "hud.settings", "hud.quickhire"] {
            let element = app.buttons[identifier]
            XCTAssertTrue(element.waitForExistence(timeout: 10), "falta \(identifier)")
            XCTAssertGreaterThanOrEqual(element.frame.minX, left, "\(identifier) se sale de la columna por la izquierda")
            XCTAssertLessThanOrEqual(element.frame.maxX, right, "\(identifier) se sale de la columna por la derecha")
        }
    }

    /// Una hoja de la barra se abre como página, se cierra con su X, y el cofre
    /// es un telón a pantalla completa con el video a su tamaño.
    @MainActor
    func testUnaHojaYElCofreEnIPad() throws {
        let app = launch()
        app.buttons["hud.upgrades"].tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 10))
        attach(app, named: "E3 iPad hoja de Mejoras")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10))

        let chest = XCUIApplication()
        chest.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-chest", "--uitest-chest-manual"]
        chest.launch()
        XCTAssertTrue(chest.buttons["chest.tap"].waitForExistence(timeout: 30))
        attach(chest, named: "E3 iPad cofre")
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
