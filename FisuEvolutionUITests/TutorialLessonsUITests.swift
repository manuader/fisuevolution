import XCTest

/// Las lecciones del tablero y la torre (E9b T1), de punta a punta. Todo por identifier y por
/// valores sin traducir (trampa 6): el runner corre la app en inglés.
final class TutorialLessonsUITests: XCTestCase {
    @MainActor
    private func launch(lesson: String, coins: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + (coins ? ["--uitest-coins"] : [])
            + ["--uitest-lesson=\(lesson)", "--uitest-tutorial-lock=0.3"]
        app.launch()
        return app
    }

    @MainActor
    private func waitForStep(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10) -> Bool {
        let marker = app.otherElements["tutorial.step"]
        let reached = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", id), object: marker)
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
    }

    @MainActor
    private func spotlight(_ app: XCUIApplication) -> String? {
        app.otherElements["tutorial.spotlight"].value as? String
    }

    @MainActor
    private func firstPickerFace(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quickhire.picker.option.'")).firstMatch
    }

    /// El atajo: tocar → mantener → fijar → soltar → el botón gris. El paso de fijar señala una
    /// cara del selector, que vive en la raíz: si su ancla no llegara, el recorte diría
    /// `missing:pickerFace` y el paso no tendría salida.
    @MainActor
    func testElAtajoEnseniaAMantenerFijarYSoltar() throws {
        let app = launch(lesson: "quickHire")
        XCTAssertTrue(waitForStep(app, "quick_hire.tap"))
        app.buttons["hud.quickhire"].tap()

        XCTAssertTrue(waitForStep(app, "quick_hire.hold"))
        app.buttons["hud.quickhire"].press(forDuration: 1.0)

        XCTAssertTrue(waitForStep(app, "quick_hire.pin"))
        let face = firstPickerFace(app)
        XCTAssertTrue(face.waitForExistence(timeout: 6))
        let hole = try XCTUnwrap(spotlight(app))
        XCTAssertFalse(hole.hasPrefix("missing"), "la cara del selector no le llega al recorte: \(hole)")
        XCTAssertNotEqual(hole, "none")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "atajo: fijar una cara"
        shot.lifetime = .keepAlways
        add(shot)
        face.tap()

        XCTAssertTrue(waitForStep(app, "quick_hire.unpin"))
        app.buttons["hud.quickhire"].press(forDuration: 1.0)
        let pinned = firstPickerFace(app)
        XCTAssertTrue(pinned.waitForExistence(timeout: 6))
        pinned.tap()

        XCTAssertTrue(waitForStep(app, "quick_hire.blocked"))
        let confirm = app.buttons["tutorial.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 6))
        let unlocked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'unlocked'"), object: confirm)
        XCTAssertEqual(XCTWaiter().wait(for: [unlocked], timeout: 8), .completed)
        confirm.tap()
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == 0"), object: app.otherElements["tutorial.step"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 6), .completed, "la lección termina")
    }

    /// La ficha señala a un empleado del tablero: el recorte lo publica la escena.
    @MainActor
    func testLaFichaSenalaAUnEmpleadoDelTablero() throws {
        let app = launch(lesson: "characterSheet", coins: false)
        XCTAssertTrue(waitForStep(app, "character_sheet.hold"))
        let hole = try XCTUnwrap(spotlight(app))
        XCTAssertFalse(hole.hasPrefix("missing"), "las lecciones tienen que pedir el recorte del tablero: \(hole)")
        XCTAssertNotEqual(hole, "none")
    }

    /// El pasivo: abrir Mejoras → desbloquearlo → el cierre. El cierre vive en el tablero: quien
    /// compró y cierra el menú no oye otra vez «abrí Mejoras».
    @MainActor
    func testElPasivoSeDesbloqueaYCierraEnElTablero() throws {
        let app = launch(lesson: "passive")
        XCTAssertTrue(waitForStep(app, "passive.open"))
        app.buttons["hud.upgrades"].tap()

        let coach = app.otherElements["tutorial.coach"]
        XCTAssertTrue(coach.waitForExistence(timeout: 10))
        let atUnlock = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'passive.unlock'"), object: coach)
        XCTAssertEqual(XCTWaiter().wait(for: [atUnlock], timeout: 6), .completed)
        let passive = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH '.passive'")).firstMatch
        XCTAssertTrue(passive.waitForExistence(timeout: 6))
        passive.tap()

        // Cerrar el menú justo después de comprar no reinicia la lección.
        let close = app.buttons["sheet.close"]
        if close.waitForExistence(timeout: 4) { close.tap() }
        XCTAssertTrue(waitForStep(app, "passive.done", timeout: 12), "el cierre vive en el tablero")
    }

    @MainActor
    private func waitForCoach(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10) -> Bool {
        let coach = app.otherElements["tutorial.coach"]
        let reached = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", id), object: coach)
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
    }

    /// Deslizar el menú: abrir Mejoras → deslizar a la pestaña de al lado. El segundo paso señala los
    /// puntos del paginador, que viven en el marco de cada página.
    @MainActor
    func testDeslizarElMenuSeCumpleDeslizando() throws {
        let app = launch(lesson: "menuSwipe", coins: false)
        XCTAssertTrue(waitForStep(app, "menu_swipe.open"))
        app.buttons["hud.upgrades"].tap()

        XCTAssertTrue(waitForCoach(app, "menu_swipe.swipe"))
        let pager = app.otherElements["menu.pager.dots"]
        XCTAssertTrue(pager.waitForExistence(timeout: 6), "los puntos del paginador son el destino del paso")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "menú: deslizá"
        shot.lifetime = .keepAlways
        add(shot)

        app.windows.firstMatch.swipeLeft()
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == 0"), object: app.otherElements["tutorial.coach"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed, "deslizar cierra la lección")
    }

    /// La tienda de ORO: abrir Mejoras → elegir la pestaña Boosts → el cierre de los topes. El segundo
    /// paso se cumple con la pestaña elegida, no con abrir la hoja.
    @MainActor
    func testLaTiendaDeOroPasaPorLaPestanaBoosts() throws {
        let app = launch(lesson: "oroShop", coins: false)
        XCTAssertTrue(waitForStep(app, "oro_shop.open"))
        app.buttons["hud.upgrades"].tap()

        XCTAssertTrue(waitForCoach(app, "oro_shop.spend"))
        XCTAssertEqual(app.otherElements["tutorial.coach"].value as? String, "oro_shop.spend", "abrir Mejoras no basta")
        app.buttons["upgrades.tab.boosts"].tap()
        XCTAssertTrue(waitForCoach(app, "oro_shop.caps"))
    }
}
