import XCTest

/// El juego en castellano en la pantalla más chica que soportamos (PLAN-v2 E3,
/// i18n). El castellano es más largo que el inglés y el SE es la pantalla más
/// angosta: si algo se encima, es acá.
///
/// No hay forma de ver un texto truncado desde XCUITest; sí de ver dos
/// controles encimados o uno afuera de la pantalla, que es lo que rompe.
/// Corre en todo dispositivo; el paso `se-ui` del oráculo la corre en un SE 3.
final class LocalizationLayoutUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testLaPantallaPrincipalNoSeEnciman() throws {
        let app = launch()
        let screen = app.windows.element(boundBy: 0).frame
        // El display del ascensor se fue del tablero (ElevatorPanelUITests): no está en la lista.
        let controls = ["hud.coins.plus", "hud.map", "hud.quickhire",
                        "hud.upgrades", "hud.skins", "hud.hire", "hud.bonus", "hud.store", "hud.settings"]
            .map { app.buttons[$0] }
        for control in controls {
            XCTAssertTrue(control.waitForExistence(timeout: 10), "falta \(control.identifier)")
            XCTAssertTrue(screen.contains(control.frame.insetBy(dx: 1, dy: 1)),
                          "\(control.identifier) se sale de la pantalla: \(control.frame)")
        }
        for (index, lhs) in controls.enumerated() {
            for rhs in controls.dropFirst(index + 1) {
                XCTAssertFalse(lhs.frame.insetBy(dx: 1, dy: 1).intersects(rhs.frame.insetBy(dx: 1, dy: 1)),
                               "\(lhs.identifier) y \(rhs.identifier) se enciman")
            }
        }
        attach(app, named: "E3 SE en castellano")
    }

    @MainActor
    func testCadaHojaSeAbreYSeCierraEnCastellano() throws {
        let app = launch()
        for tab in ["hud.upgrades", "hud.skins", "hud.hire", "hud.bonus", "hud.store", "hud.settings"] {
            let button = app.buttons[tab]
            XCTAssertTrue(waitUntilHittable(button), "\(tab) nunca quedó tocable")
            button.tap()
            let close = app.buttons["sheet.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10), "\(tab) no abrió una hoja cerrable")
            XCTAssertTrue(close.isHittable, "la X de \(tab) quedó tapada")
            attach(app, named: "E3 SE castellano \(tab)")
            close.tap()
            XCTAssertTrue(close.waitForNonExistence(timeout: 10))
        }
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(es)", "-AppleLocale", "es_AR",
                               "--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 30))
        return app
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable { return true }
            usleep(200_000)
        }
        return false
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
