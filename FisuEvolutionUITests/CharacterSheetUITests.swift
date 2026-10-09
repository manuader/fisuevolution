import XCTest

/// La ficha de personaje (PLAN-v2 E3): la pinta en grande, la X de la casa, y
/// despedir con la confirmación propia del juego — nunca una alerta del sistema.
final class CharacterSheetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaPintaVaEnGrandeYLaFichaSeCierraConLaX() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-open-sheet"]
        app.launch()

        let portrait = app.otherElements["character.portrait"]
        XCTAssertTrue(portrait.waitForExistence(timeout: 15), "la ficha no mostró su retrato")
        XCTAssertGreaterThanOrEqual(portrait.frame.height, 200, "la pinta tiene que verse en grande")
        XCTAssertGreaterThanOrEqual(portrait.frame.width, 200)
        attach(app, named: "E3 ficha grande")

        let base = portrait.value as? String
        app.buttons["character.skin.next"].tap()
        let changed = NSPredicate(format: "value != %@", base ?? "")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: changed, evaluatedWith: portrait)], timeout: 3),
                       .completed, "la flecha no cambió de pinta")

        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.exists, "la ficha se cierra con la X de la casa")
        close.tap()
        XCTAssertTrue(portrait.waitForNonExistence(timeout: 8))
    }

    @MainActor
    func testDespedirPideLaTarjetaDeLaCasaYNoUnaAlerta() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 20))

        // La puerta de debug contrata un segundo Fisura y abre la ficha del
        // primero: con uno solo, despedir no existe.
        let debugKey = app.buttons["hud.debug"]
        XCTAssertTrue(debugKey.waitForExistence(timeout: 6))
        debugKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let open = app.buttons["debug.sheet.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 6))
        open.tap()

        let dismissButton = app.buttons["character.dismiss"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 10), "la ficha no ofreció despedir")
        XCTAssertEqual(units.value as? String, "2")

        dismissButton.tap()
        let accept = app.buttons["confirm.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 3), "despedir tiene que pedir confirmación")
        // La tarjeta es `.isModal` y XCUITest la expone como cuatro `Alert` de
        // 10×10 en sus esquinas: no son una alerta, la de sistema trae botones.
        XCTAssertEqual(app.alerts.buttons.count, 0, "nunca la alerta del sistema")
        attach(app, named: "E3 confirmación de la casa")

        app.buttons["confirm.cancel"].tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 3))
        XCTAssertTrue(dismissButton.exists, "cancelar deja la ficha como estaba")

        dismissButton.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 3))
        accept.tap()
        XCTAssertTrue(dismissButton.waitForNonExistence(timeout: 8), "despedir cierra la ficha")
        let one = NSPredicate(format: "value == %@", "1")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: one, evaluatedWith: units)], timeout: 5), .completed)
    }

    @MainActor
    func testLaFichaSeAbreDesdePersonajes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()
        XCTAssertTrue(app.otherElements["board.units"].waitForExistence(timeout: 20))

        let upgrades = app.buttons["hud.upgrades"]
        XCTAssertTrue(upgrades.waitForExistence(timeout: 6))
        upgrades.tap()
        let sheetButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'upgrades.character.' AND identifier ENDSWITH '.sheet'")).firstMatch
        XCTAssertTrue(sheetButton.waitForExistence(timeout: 8), "Personajes no ofreció la ficha")
        sheetButton.tap()

        let portrait = app.otherElements["character.portrait"]
        XCTAssertTrue(portrait.waitForExistence(timeout: 10), "la ficha no mostró su retrato")
        attach(app, named: "E13 ficha desde Personajes")
        // Debajo de la ficha sigue la X de Mejoras: la de la ficha es la de arriba.
        let closes = app.buttons.matching(identifier: "sheet.close")
        XCTAssertEqual(closes.count, 2)
        closes.element(boundBy: 1).tap()
        XCTAssertTrue(portrait.waitForNonExistence(timeout: 8))
        XCTAssertTrue(sheetButton.exists, "cerrar la ficha deja a Personajes abierta")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
