import XCTest

/// El menú deslizable (PLAN-v2 E3): una hoja, las pestañas como páginas, flechas
/// y puntos, sin vuelta en los extremos, y el Menú con un destino empujado no se
/// desliza.
final class MenuPagerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDeslizarYLasFlechasCambianDePestanaEnLaMismaHoja() throws {
        let app = launch()
        tapTab("hud.upgrades", in: app)
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 10))
        XCTAssertEqual(dots(app), "1/5")
        XCTAssertEqual(app.buttons.matching(identifier: "sheet.close").count, 1,
                       "las páginas ocultas no exponen su X")
        XCTAssertFalse(app.buttons["menu.pager.previous"].isEnabled, "en el extremo no hay vuelta")

        app.windows.firstMatch.swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["skins.row.base"].waitForExistence(timeout: 5), "deslizar no llevó a Vestimenta")
        XCTAssertEqual(dots(app), "2/5")

        app.buttons["menu.pager.next"].tap()
        XCTAssertTrue(app.buttons["jobs.hire.homeless"].waitForExistence(timeout: 5), "la flecha no llevó a Contratar")
        XCTAssertEqual(dots(app), "3/5")
        attach(app, named: "E3 paginador en Contratar")

        app.buttons["menu.pager.previous"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["skins.row.base"].waitForExistence(timeout: 5))

        let close = app.buttons["sheet.close"]
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10), "la X cierra la sesión entera")
    }

    @MainActor
    func testConAjustesAbiertoElMenuNoSeDesliza() throws {
        let app = launch()
        tapTab("hud.settings", in: app)
        XCTAssertEqual(dots(app), "5/5")
        let settingsCard = app.buttons["menu.card.settings"]
        XCTAssertTrue(settingsCard.waitForExistence(timeout: 10))
        settingsCard.tap()
        let version = app.descendants(matching: .any)["settings.about.version"]
        XCTAssertTrue(version.waitForExistence(timeout: 10), "Ajustes no se empujó")

        app.windows.firstMatch.swipeLeft()
        XCTAssertTrue(version.exists, "con un destino empujado, deslizar no cambia de pestaña")

        // Deslizar hacia la derecha es el gesto de volver del NavigationStack: vuelve
        // al Menú, no pasa a la pestaña de al lado.
        app.windows.firstMatch.swipeRight()
        XCTAssertTrue(settingsCard.waitForExistence(timeout: 10), "volver no llegó a la grilla del Menú")
        XCTAssertEqual(dots(app), "5/5")
    }

    // MARK: - Utilidades

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func tapTab(_ identifier: String, in app: XCUIApplication) {
        let tab = app.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.buttons["sheet.close"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func dots(_ app: XCUIApplication) -> String? {
        let dots = app.otherElements["menu.pager.dots"]
        _ = dots.waitForExistence(timeout: 5)
        return dots.value as? String
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
