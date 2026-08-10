import XCTest

/// Activar un boost dejaba de tener rastro apenas se cerraba el panel: ni el
/// efecto ni cuánto le faltaba. El contador tiene que quedar en pantalla, con
/// el juego corriendo detrás.
///
/// ⚠️ `--uitest-skip-tutorial` por la trampa 9 del HANDOFF: sin él, en un
/// simulador limpio el scrim se come los toques.
final class BonusHUDUITests: XCTestCase {
    @MainActor
    func testActivatingABoostShowsItsCounterOnTheHUD() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let chip = app.otherElements["hud.bonus.chip"]
        XCTAssertTrue(app.buttons["hud.bonus"].waitForExistence(timeout: 15))
        XCTAssertFalse(chip.exists, "sin ningún bonus corriendo no puede haber contador")

        app.buttons["hud.bonus"].tap()
        // El mate arranca desbloqueado (se abre en el callejón) y sin cooldown.
        let activate = app.buttons["bonus.activate.mate"]
        XCTAssertTrue(activate.waitForExistence(timeout: 6), "el mate tiene que estar disponible en una partida nueva")
        activate.tap()
        app.buttons["sheet.close"].tap()

        // La captura va ANTES de los asserts: si el chip no está, lo que hace
        // falta es ver la pantalla, y un assert que corta se lleva puesta la
        // evidencia. Así se encontró que el chip se dibujaba perfecto y el que
        // fallaba era el árbol de accesibilidad.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "contador de boost activo"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertTrue(chip.waitForExistence(timeout: 6),
                      "el boost activado tiene que dejar su contador en el HUD")
        // El mate descuenta el costo de contratar: su magnitud 0,7 se lee −30%,
        // y el valor lleva además el tiempo que le queda.
        let value = try XCTUnwrap(chip.value as? String)
        XCTAssertTrue(value.contains("30%"), "el chip tiene que decir qué hace, dijo '\(value)'")
        XCTAssertTrue(value.contains("s") || value.contains(":"),
                      "y cuánto le queda, dijo '\(value)'")
    }

    /// Dos bonus corriendo son dos contadores, y de dos orígenes distintos: el
    /// mate es un boost y el ×2 viene de un video. Además fija el orden — primero
    /// el que vence, que es el que urge.
    @MainActor
    func testTwoBonusesShowAtTheSameTime() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        XCTAssertTrue(app.buttons["hud.bonus"].waitForExistence(timeout: 15))
        app.buttons["hud.bonus"].tap()

        let activateMate = app.buttons["bonus.activate.mate"]
        XCTAssertTrue(activateMate.waitForExistence(timeout: 6))
        activateMate.tap()

        // El video del stub tarda 2 s y siempre paga: ×2 a los ingresos por 120 s.
        // ⚠️ Su fila vive abajo de los seis boosts y `List` es perezosa: hasta que
        // no se scrollea no existe en el árbol de accesibilidad, y buscarla sin
        // bajar falla con "no matches" aunque la vista esté perfecta.
        let watch = app.buttons["ads.watch.double_earnings"]
        for _ in 0..<4 where !watch.exists {
            app.swipeUp()
        }
        XCTAssertTrue(watch.waitForExistence(timeout: 6), "la fila del video tiene que estar")
        watch.tap()
        XCTAssertTrue(app.staticTexts["ads.cooldown.double_earnings"].waitForExistence(timeout: 15)
                        || app.otherElements["ads.cooldown.double_earnings"].waitForExistence(timeout: 1),
                      "el video tiene que terminar y dejar la fila en cooldown")
        app.buttons["sheet.close"].tap()

        let chips = app.otherElements.matching(identifier: "hud.bonus.chip")
        let two = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 2"), object: chips
        )
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "dos contadores a la vez"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertEqual(XCTWaiter().wait(for: [two], timeout: 8), .completed,
                       "dos bonus corriendo son dos contadores, hubo \(chips.count)")

        // El mate dura 60 s y el video 120: primero el mate.
        let first = try XCTUnwrap(chips.element(boundBy: 0).value as? String)
        XCTAssertTrue(first.contains("30%"), "arriba va el que vence primero, había '\(first)'")
    }
}
