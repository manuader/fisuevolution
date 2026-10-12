import XCTest

/// El repaso y el Tour pedidos desde Ajustes (PLAN-v2 E9b T5): la hoja se cierra, el tablero
/// vuelve a la vista y la demostración corre sin tocar la partida.
@MainActor
final class TutorialReplayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testElRepasoSePideDesdeAjustesYSeTermina() throws {
        let app = launchAndOpenSettings()
        let replay = app.buttons["settings.tutorial.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        replay.tap()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 15), "el repaso nunca arrancó")
        XCTAssertEqual(step.value as? String, "replay.core.tap")
        XCTAssertEqual(app.descendants(matching: .any)["tutorial.tip"].value as? String, "replay")
        XCTAssertTrue(app.buttons["tutorial.replay.end"].exists)
        app.buttons["tutorial.replay.end"].tap()
        XCTAssertTrue(step.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hud.settings"].isHittable, "el tablero vuelve a ser del jugador")
    }

    func testElTourSePideDesdeAjustesYNoTieneSalidaAnticipada() throws {
        let app = launchAndOpenSettings()
        let tour = app.buttons["settings.tutorial.tour"]
        XCTAssertTrue(tour.waitForExistence(timeout: 5))
        tour.tap()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 15), "el Tour nunca arrancó")
        XCTAssertEqual(step.value as? String, "tour.intro")
        XCTAssertEqual(app.descendants(matching: .any)["tutorial.tip"].value as? String, "tour")
        XCTAssertFalse(app.buttons["tutorial.replay.end"].exists, "el Tour no se termina antes")
    }

    private func launchAndOpenSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-tutorial-lock=0.3"]
        app.launch()
        let tab = app.buttons["hud.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "la barra inferior nunca apareció")
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: tab)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 40), .completed, "el tab del menú nunca quedó tocable")
        tab.tap()
        let settings = app.buttons["menu.card.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "el menú no abrió su grilla")
        settings.tap()
        return app
    }
}
