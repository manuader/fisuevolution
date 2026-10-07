import XCTest

/// La sección "Avisos" de Ajustes (PLAN-v2 E11): el maestro, uno por motivo y la
/// salida a Ajustes de iOS cuando el sistema las bloqueó.
///
/// ⚠️ Todo por identifier y por valor sin traducir (`on`/`off`): el runner corre
/// la app en inglés (trampa 6). Bajo `--uitest*` el juego no le habla a iOS: los
/// toggles guardan la preferencia y nada más, que es justo lo que se prueba.
/// El estado bloqueado lo arma `--uitest-notifications-denied` (centro en memoria).
final class NotificationsSettingsUITests: XCTestCase {
    private static let kinds = ["vault_full", "daily_ready", "comeback"]

    @MainActor
    func testElMaestroArrancaPrendidoYGobiernaLosMotivos() throws {
        let app = launch()
        openSettings(app)
        let master = app.switches["settings.notifications"]
        XCTAssertTrue(master.waitForExistence(timeout: 10), "Ajustes no trae el maestro de notificaciones")
        scrollTo(master, in: app)
        attach(app, named: "E11 ajustes: avisos")

        XCTAssertEqual(master.value as? String, "on", "en la 2.0 las notificaciones arrancan prendidas")
        for kind in Self.kinds {
            XCTAssertEqual(app.switches["settings.notifications.\(kind)"].value as? String, "on",
                           "el motivo \(kind) arranca prendido")
        }

        let vault = app.switches["settings.notifications.vault_full"]
        scrollTo(vault, in: app)
        vault.tap()
        waitFor(vault, value: "off")

        scrollTo(master, in: app)
        master.tap()
        waitFor(master, value: "off")
        XCTAssertFalse(app.switches["settings.notifications.vault_full"].exists,
                       "con el maestro apagado no se ofrecen los motivos")
        attach(app, named: "E11 ajustes: maestro apagado")

        master.tap()
        waitFor(master, value: "on")
        XCTAssertEqual(app.switches["settings.notifications.vault_full"].value as? String, "off",
                       "prender el maestro no pisa lo elegido por motivo")

        // Es preferencia del dispositivo: sobrevive al cierre de la app.
        app.terminate()
        app.launchArguments = ["--uitest-skip-tutorial"]
        app.launch()
        openSettings(app)
        let reopened = app.switches["settings.notifications.vault_full"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        XCTAssertEqual(reopened.value as? String, "off", "lo elegido por motivo no persistió")
    }

    @MainActor
    func testConIOSBloqueadoLaFilaLoDiceYOfreceAbrirAjustes() throws {
        let app = launch(extraArguments: ["--uitest-notifications-denied"])
        openSettings(app)
        let open = app.buttons["settings.notifications.open_settings"]
        XCTAssertTrue(open.waitForExistence(timeout: 10), "con iOS bloqueado falta «Abrir Ajustes»")
        scrollTo(open, in: app)
        attach(app, named: "E11 ajustes: bloqueadas por iOS")
        // No se toca: saldría de la app. Lo que importa es que esté y que la
        // preferencia del jugador no se haya apagado sola.
        XCTAssertEqual(app.switches["settings.notifications"].value as? String, "on",
                       "el bloqueo de iOS no le apaga la preferencia al jugador")
    }

    // MARK: Andamio

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extraArguments
        app.launch()
        return app
    }

    /// El menú y la tarjeta de Ajustes (el camino de `MenuUITests`).
    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        let tab = app.buttons["hud.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "la barra inferior nunca apareció")
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: tab)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed, "el tab del menú nunca quedó tocable")
        tab.tap()
        let card = app.buttons["menu.card.settings"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "el menú no abrió su grilla")
        card.tap()
    }

    /// La sección de avisos vive debajo de idioma, audio y "En el juego".
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(element.identifier) no quedó a la vista")
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, value: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed,
                       "\(element.identifier) no pasó a \(value)")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
