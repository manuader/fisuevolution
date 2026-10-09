import XCTest

/// La pestaña Ranking del menú deslizable (E12): vive en la barra con el núcleo del tutorial hecho, se
/// alcanza deslizando, muestra la fila propia fija abajo y se apaga con el interruptor del servidor.
final class RankingTabUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaPestanaSeAbreYLaFilaPropiaQuedaFijaAbajo() throws {
        let app = launch(scenario: "outside-top")
        openRanking(in: app)
        let pinned = app.descendants(matching: .any)["ranking.row.pinned"]
        XCTAssertTrue(pinned.waitForExistence(timeout: 10), "la fila propia no está fija abajo")
        XCTAssertTrue((pinned.label).contains("103"), "la fila propia no dice su puesto: \(pinned.label)")
        attach(app, named: "E12 pestaña Ranking")
    }

    @MainActor
    func testSeDeslizaHastaElRankingDesdeMejoras() throws {
        let app = launch(scenario: "outside-top")
        let tab = app.buttons["hud.upgrades"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 10))
        app.windows.firstMatch.swipeRight()
        XCTAssertTrue(app.descendants(matching: .any)["ranking.row.pinned"].waitForExistence(timeout: 10),
                      "deslizar a la izquierda de Mejoras no llevó al Ranking")
    }

    @MainActor
    func testReportarUnaFilaAjenaPideConfirmacionYSeCierra() throws {
        let app = launch(scenario: "outside-top")
        openRanking(in: app)
        let row = app.descendants(matching: .any)["ranking.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.0)
        let report = app.buttons["Report"]
        XCTAssertTrue(report.waitForExistence(timeout: 5), "el menú contextual no ofrece Reportar")
        report.tap()
        let yes = app.buttons["ranking.report.confirm.yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5), "no apareció la confirmación")
        yes.tap()
        XCTAssertTrue(yes.waitForNonExistence(timeout: 5), "la confirmación no se cerró")
    }

    @MainActor
    func testMisPartidasSeEmpujaYVuelve() throws {
        let app = launch(scenario: "happy")
        openRanking(in: app)
        let open = app.buttons["ranking.mine.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ranking.mine.empty"].waitForExistence(timeout: 10),
                      "Mis partidas no se empujó")
        app.windows.firstMatch.swipeRight()
        XCTAssertTrue(open.waitForExistence(timeout: 10), "volver no regresó al ranking")
    }

    @MainActor
    func testConElServidorApagadoLaPestanaNoEstaMas() throws {
        let app = launch(scenario: "disabled")
        openRanking(in: app)
        // El primer pedido al tablero recibe 503 y el store se apaga: al cerrar, la barra ya no la tiene.
        let close = app.buttons["sheet.close"]
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["hud.ranking"].waitForNonExistence(timeout: 10),
                      "con el interruptor apagado la pestaña sigue en la barra")
    }

    @MainActor
    func testSinRedElRankingSeVeConLoUltimoQueSeBajo() throws {
        let online = launch(scenario: "happy")
        openRanking(in: online)
        XCTAssertTrue(online.descendants(matching: .any)["ranking.row.me"].waitForExistence(timeout: 10))
        online.terminate()

        let offline = launch(scenario: "offline")
        openRanking(in: offline)
        XCTAssertTrue(offline.descendants(matching: .any)["ranking.stale"].waitForExistence(timeout: 10),
                      "sin red no avisa que muestra lo último que bajó")
    }

    // MARK: - Utilidades

    @MainActor
    private func launch(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins", "--uitest-ranking-\(scenario)"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
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
