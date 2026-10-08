import XCTest

/// La barra progresiva (PLAN-v2 E3). Sólo corre con `--uitest-progressive-tabs`:
/// sin el flag, toda corrida de UI ve las seis pestañas (los tests viejos las
/// necesitan).
final class ProgressiveTabsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testUnJugadorNuevoVeSoloContratarYMejoras() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-progressive-tabs"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["hud.upgrades"].exists)
        for hidden in ["hud.skins", "hud.bonus", "hud.store", "hud.settings"] {
            XCTAssertFalse(app.buttons[hidden].exists, "\(hidden) no tendría que estar todavía")
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "barra-arranque-nuevo"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testAlTerminarElNucleoAparecenBonusYMenuConNuevo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-progressive-tabs"]
        app.launch()
        let gifts = app.buttons["hud.bonus"]
        XCTAssertTrue(gifts.waitForExistence(timeout: 20), "Bonus tendría que estar con el núcleo hecho")
        XCTAssertTrue(app.buttons["hud.settings"].exists)
        XCTAssertFalse(app.buttons["hud.skins"].exists, "Vestimenta espera la primera pinta")
        // La Tienda no se afirma acá: `--uitest-skip-tutorial` arranca con la
        // fase hecha, así que el bootstrap ya cuenta esa corrida como la
        // sesión que sigue al núcleo (la regla está en `TabUnlockRulesTests`).
        // El runner corre en inglés (trampa 6): "new" es el valor de AX del badge.
        XCTAssertTrue((gifts.value as? String)?.contains("new") == true, "Bonus tendría que decir ¡Nuevo!")

        gifts.tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10))
        XCTAssertFalse((app.buttons["hud.bonus"].value as? String)?.contains("new") == true,
                       "abrirla le saca el ¡Nuevo!")
    }
}
