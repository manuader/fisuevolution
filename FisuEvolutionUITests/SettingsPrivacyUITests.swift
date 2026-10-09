import XCTest

/// "Opciones de privacidad" (PLAN-v2 E7, UMP): sólo donde hace falta. Bajo UI
/// tests el SDK no arranca y UMP no sabe nada, así que la fila se fuerza con
/// `--uitest-privacy-options`.
final class SettingsPrivacyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaFilaSaleCuandoUMPLaPide() {
        let app = openSettings(extra: ["--uitest-privacy-options"])
        XCTAssertTrue(app.buttons["settings.privacy.options"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSinUMPNoHayFila() {
        let app = openSettings(extra: [])
        XCTAssertTrue(app.buttons["settings.restore"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.privacy.options"].exists)
    }

    @MainActor
    private func openSettings(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extra
        app.launch()
        let tab = app.buttons["hud.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "la barra inferior nunca apareció")
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: tab)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed, "el tab del menú nunca quedó tocable")
        tab.tap()
        let settings = app.buttons["menu.card.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "el menú no abrió su grilla")
        settings.tap()
        return app
    }
}
