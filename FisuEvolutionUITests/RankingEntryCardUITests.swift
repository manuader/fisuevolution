import XCTest

/// La tarjeta del nombre al llegar a Dios (E12): sale en el primer momento calmo, filtra lo que se
/// tipea, muestra el rechazo sin cerrarse y se cierra con "Ahora no" o con el nombre en camino.
final class RankingEntryCardUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaTarjetaMuestraElTiempoYFiltraElNombre() throws {
        let app = launchAtGod(scenario: "happy")
        let name = app.textFields["ranking.entry.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "la tarjeta no salió al llegar a Dios")
        XCTAssertTrue(app.descendants(matching: .any)["ranking.entry.card"].exists, "la tarjeta no dice el tiempo")
        attach(app, named: "E12 tarjeta de Dios")

        name.tap()
        name.typeText("Juan😀<b>")
        XCTAssertEqual(name.value as? String, "Juanb")
        XCTAssertEqual(app.staticTexts["ranking.entry.counter"].value as? String, "5/15")

        name.typeText(String(repeating: "x", count: 16))
        XCTAssertEqual((name.value as? String)?.count, 15)
        XCTAssertEqual(app.staticTexts["ranking.entry.counter"].value as? String, "15/15")
    }

    @MainActor
    func testUnNombreRechazadoDejaLaTarjetaAbiertaYOtroLaCierra() throws {
        let app = launchAtGod(scenario: "reject-first-name")
        let name = app.textFields["ranking.entry.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Primero")
        app.buttons["ranking.entry.submit"].tap()

        XCTAssertTrue(app.staticTexts["ranking.entry.error"].waitForExistence(timeout: 10),
                      "el rechazo no se explicó")
        XCTAssertTrue(name.exists, "la tarjeta se cerró con el nombre rechazado")

        name.tap()
        name.typeText("Segundo")
        app.buttons["ranking.entry.submit"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 10), "el nombre aceptado no cerró la tarjeta")
    }

    @MainActor
    func testSinRedElNombreQuedaEnCaminoYLaTarjetaSeCierra() throws {
        let app = launchAtGod(scenario: "offline")
        let name = app.textFields["ranking.entry.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Juan")
        app.buttons["ranking.entry.submit"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 10), "sin red la tarjeta no se cerró")

        openRanking(in: app)
        XCTAssertFalse(app.buttons["ranking.pending.name"].exists, "el nombre ya elegido no se vuelve a pedir")
    }

    @MainActor
    func testAhoraNoLaCierraYLaPestanaOfreceElNombre() throws {
        let app = launchAtGod(scenario: "happy")
        let later = app.buttons["ranking.entry.later"]
        XCTAssertTrue(later.waitForExistence(timeout: 15))
        later.tap()
        XCTAssertTrue(later.waitForNonExistence(timeout: 10))

        openRanking(in: app)
        XCTAssertTrue(app.buttons["ranking.pending.name"].waitForExistence(timeout: 10),
                      "la pestaña no ofrece poner el nombre")
    }

    @MainActor
    func testConElRankingApagadoLaTarjetaNoSale() throws {
        let app = launchAtGod(scenario: "disabled")
        sleep(6)
        XCTAssertFalse(app.textFields["ranking.entry.name"].exists, "con el ranking apagado salió la tarjeta")
    }

    // MARK: - Utilidades

    @MainActor
    private func launchAtGod(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins",
            "--uitest-ranking-god", "--uitest-ranking-\(scenario)",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        let debugKey = app.buttons["hud.debug"]
        XCTAssertTrue(debugKey.waitForExistence(timeout: 6))
        debugKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let reach = app.buttons["debug.ranking.reachGod"]
        for _ in 0..<10 where !reach.isHittable { app.swipeUp() }
        XCTAssertTrue(reach.waitForExistence(timeout: 6), "el panel de debug no ofrece llegar a Dios")
        reach.tap()
        XCTAssertTrue(reach.waitForNonExistence(timeout: 6))
        return app
    }

    @MainActor
    private func openRanking(in app: XCUIApplication) {
        let tab = app.buttons["hud.ranking"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "la barra no tiene el Ranking")
        tab.tap()
        XCTAssertTrue(app.buttons["sheet.close"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
