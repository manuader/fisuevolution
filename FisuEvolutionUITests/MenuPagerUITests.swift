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
        // La barra es Tienda · Mejoras · Pintas · Contratar · Regalos · Menú (E14b B26): Mejoras es la 2.ª de 6.
        XCTAssertEqual(dots(app), "2/6")
        XCTAssertEqual(app.buttons.matching(identifier: "sheet.close").count, 1,
                       "las páginas ocultas no exponen su X")
        XCTAssertTrue(app.buttons["menu.pager.previous"].isEnabled, "a la izquierda de Mejoras está la Tienda")

        app.windows.firstMatch.swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["skins.row.base"].waitForExistence(timeout: 5), "deslizar no llevó a Vestimenta")
        XCTAssertEqual(dots(app), "3/6")

        app.buttons["menu.pager.next"].tap()
        XCTAssertTrue(app.buttons["jobs.hire.homeless"].waitForExistence(timeout: 5), "la flecha no llevó a Contratar")
        XCTAssertEqual(dots(app), "4/6")
        attach(app, named: "E3 paginador en Contratar")

        app.buttons["menu.pager.previous"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["skins.row.base"].waitForExistence(timeout: 5))

        let close = app.buttons["sheet.close"]
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10), "la X cierra la sesión entera")
    }

    /// La Tienda ocupa el extremo izquierdo (E14b B26): primera página, sin vuelta atrás.
    @MainActor
    func testLaTiendaEsLaPrimeraPaginaYNoTieneVueltaAtras() throws {
        let app = launch()
        tapTab("hud.store", in: app)
        XCTAssertEqual(dots(app), "1/6")
        XCTAssertFalse(app.buttons["menu.pager.previous"].isEnabled, "en el extremo no hay vuelta")
        app.buttons["menu.pager.next"].tap()
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 5), "la flecha no llevó a Mejoras")
        XCTAssertEqual(dots(app), "2/6")
    }

    @MainActor
    func testConAjustesAbiertoElMenuNoSeDesliza() throws {
        let app = launch()
        tapTab("hud.settings", in: app)
        XCTAssertEqual(dots(app), "6/6")
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
        XCTAssertEqual(dots(app), "6/6")
    }

    /// Arrastrar hacia una pestaña nueva y soltar para volver no la muestra quieta:
    /// conserva su «¡Nuevo!».
    @MainActor
    func testArrastrarYVolverNoLeSacaElNuevoAlaPestanaDeAlLado() throws {
        let app = launch(extra: ["--uitest-progressive-tabs"])
        let gifts = app.buttons["hud.bonus"]
        XCTAssertTrue(gifts.waitForExistence(timeout: 10))
        XCTAssertTrue(isNew(gifts), "Bonus arranca con su ¡Nuevo!")
        tapTab("hud.hire", in: app)
        let jobs = dots(app)

        let window = app.windows.firstMatch
        let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let partway = window.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: partway, withVelocity: .slow, thenHoldForDuration: 0.6)
        XCTAssertEqual(dots(app), jobs, "soltar sin llegar no cambia de página")
        app.buttons["sheet.close"].tap()
        XCTAssertTrue(app.buttons["sheet.close"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(isNew(app.buttons["hud.bonus"]), "la pestaña de al lado no se vio quieta: conserva su ¡Nuevo!")
    }

    /// La contracara: deslizar del todo la deja quieta y sí se lo saca.
    @MainActor
    func testDeslizarDelTodoLeSacaElNuevoALaPestanaDeAlLado() throws {
        let app = launch(extra: ["--uitest-progressive-tabs"])
        XCTAssertTrue(isNew(app.buttons["hud.bonus"]))
        tapTab("hud.hire", in: app)
        let jobs = dots(app)
        app.windows.firstMatch.swipeLeft()
        XCTAssertNotEqual(dots(app), jobs, "deslizar del todo cambia de página")
        app.buttons["sheet.close"].tap()
        XCTAssertTrue(app.buttons["sheet.close"].waitForNonExistence(timeout: 10))
        XCTAssertFalse(isNew(app.buttons["hud.bonus"]), "la página quieta sí cuenta como vista")
    }

    /// La cabecera de Mejoras (E14b B10): las flechas quedan sobre las pestañas (a la
    /// altura del cartel) y el selector usa casi todo el ancho de la columna, con
    /// botones altos.
    @MainActor
    func testLasFlechasSubenAlCartelYLasPestanasUsanTodoElAncho() throws {
        let app = launch()
        tapTab("hud.upgrades", in: app)
        let characters = app.buttons["upgrades.tab.characters"]
        let boosts = app.buttons["upgrades.tab.boosts"]
        XCTAssertTrue(characters.waitForExistence(timeout: 10))
        let next = app.buttons["menu.pager.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame

        XCTAssertLessThan(next.frame.maxY, characters.frame.minY, "las flechas van a la altura del cartel, sobre las pestañas")
        let span = boosts.frame.maxX - characters.frame.minX
        XCTAssertGreaterThan(span, window.width * 0.7, "el selector de pestañas ocupa casi todo el ancho")
        XCTAssertGreaterThanOrEqual(characters.frame.height, 48, "botones grandes")
        XCTAssertFalse(next.frame.intersects(characters.frame), "nada se superpone")
        attach(app, named: "B10 cabecera de Mejoras")
    }

    /// Recorrer todas las páginas con las flechas no deja ninguna a medio armar: cada
    /// una muestra su cuerpo apenas queda quieta (las vecinas ya estaban armadas).
    @MainActor
    func testElPasoEntrePaginasMuestraLaVecinaYaArmada() throws {
        let app = launch()
        tapTab("hud.upgrades", in: app)
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 10))
        for expected in ["3/6", "4/6"] {
            app.buttons["menu.pager.next"].tap()
            let settled = NSPredicate(format: "value == %@", expected)
            let dots = app.otherElements["menu.pager.dots"]
            expectation(for: settled, evaluatedWith: dots)
            waitForExpectations(timeout: 5)
        }
        XCTAssertEqual(app.buttons.matching(identifier: "sheet.close").count, 1,
                       "con las vecinas armadas sigue habiendo una sola X")
    }

    // MARK: - Utilidades

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"] + extra
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
    private func isNew(_ tab: XCUIElement) -> Bool {
        (tab.value as? String)?.contains("new") == true
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
