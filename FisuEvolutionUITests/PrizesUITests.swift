import XCTest

/// El paquete y el colchón se tocan desde los sellos de la esquina de arriba a
/// la izquierda (PLAN-v2 E5 y E14 C9): el sello de cada uno abre lo suyo. El
/// video del colchón lo pone el stub de anuncios: 2 s y paga.
@MainActor
final class PrizesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// La captura de un momento de la pantalla de premio (E14 T17), adjunta al resultado.
    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testAPackageBringsAWorker() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-packages=1"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let before = Int(units.value as? String ?? "") ?? 0
        let chip = app.buttons["siderail.packages"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.value as? String, "ready:1")
        chip.tap()

        // Antes: a quién trae y a qué piso llega (E14b B18: se decidió cuando cayó).
        XCTAssertTrue(app.descendants(matching: .any)["package.inside"].waitForExistence(timeout: 5),
                      "la cara de quien trae está a la vista antes de abrir")
        snap(app, "paquete 1 antes")
        app.buttons["package.open"].tap()

        // Durante: tres toques a la caja (uno con Reduce Motion).
        let box = app.buttons["package.tap"]
        XCTAssertTrue(box.waitForExistence(timeout: 8), "la caja se abre tocándola")
        snap(app, "paquete 2 durante")
        for _ in 0..<3 where box.exists { box.tap() }

        // Después: quién salió y a qué piso llega.
        XCTAssertTrue(app.descendants(matching: .any)["package.result"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["package.result.floor"].exists, "dice a qué piso llega")
        snap(app, "paquete 3 despues")
        app.buttons["package.collect"].tap()

        expectation(for: NSPredicate(format: "value == %@", String(before + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertNotEqual(chip.value as? String, "ready:1", "con el buzón vacío el sello se queda y cambia de estado")
    }

    /// El colchón pagado se toca para abrirlo (E14 C4 «durante»): tres toques, o uno con Reduce Motion.
    private func tapTheMattressOpen(_ app: XCUIApplication) {
        let mattress = app.buttons["mattress.tap"]
        XCTAssertTrue(mattress.waitForExistence(timeout: 8), "el colchón pagado se abre tocándolo")
        snap(app, "colchon 2 durante")
        for _ in 0..<3 where mattress.exists { mattress.tap() }
    }

    /// Espera a que el colchón esté quieto en el tablero y lo toca donde está (E14b B6).
    private func tapTheBoardMattress(_ app: XCUIApplication) {
        let marker = app.otherElements["board.mattress"]
        XCTAssertTrue(marker.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value CONTAINS ','"), evaluatedWith: marker)
        waitForExpectations(timeout: 10)
        let parts = (marker.value as? String ?? "").split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 2, "el marcador trae x,y")
        app.coordinate(withNormalizedOffset: CGVector(dx: parts[0], dy: parts[1])).tap()
    }

    /// El recorrido entero (E14b B6, D3): la columna pide el video, el colchón cae al tablero, ahí se
    /// toca y se abre, y sale el pop-up del premio; después, «otro colchón».
    func testTheMattressOpensWithAVideo() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-mattress"]
        app.launch()

        let chip = app.buttons["siderail.mattress"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        XCTAssertEqual(chip.value as? String, "ready")
        XCTAssertEqual(app.otherElements["board.mattress"].value as? String ?? "", "",
                       "en la columna, sólo en la columna: el tablero no lo muestra")
        chip.tap()

        let odds = app.descendants(matching: .any)["mattress.odds.coins"]
        XCTAssertTrue(odds.waitForExistence(timeout: 5), "lo que puede tocar está a la vista antes del video")
        snap(app, "colchon 1 antes")
        app.buttons["mattress.open"].tap()
        XCTAssertTrue(odds.waitForNonExistence(timeout: 10), "al terminar el video el popup se cierra")
        XCTAssertFalse(app.descendants(matching: .any)["mattress.result"].exists, "pagar no abre: cae al tablero")

        tapTheBoardMattress(app)
        snap(app, "colchon 2 abriendose en el tablero")
        let result = app.descendants(matching: .any)["mattress.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), "abierto en el tablero, sale el pop-up del premio")
        XCTAssertFalse(app.buttons["mattress.tap"].exists, "la animación ya se vio en el tablero")
        snap(app, "colchon 3 despues")
        XCTAssertTrue(["coins", "package", "blue"].contains(result.value as? String ?? ""))

        let extra = app.buttons["mattress.extra"]
        XCTAssertTrue(extra.waitForExistence(timeout: 3))
        extra.tap()
        XCTAssertTrue(extra.waitForNonExistence(timeout: 8), "otro colchón es uno solo")
        XCTAssertTrue(app.descendants(matching: .any)["mattress.extra.watching"].waitForNonExistence(timeout: 10),
                      "el video del segundo colchón no terminó")
        tapTheMattressOpen(app)
        XCTAssertTrue(app.descendants(matching: .any)["mattress.result"].waitForExistence(timeout: 8))

        app.buttons["mattress.collect"].tap()
        XCTAssertTrue(app.buttons["mattress.collect"].waitForNonExistence(timeout: 5), "Keep it! no cerró el colchón")
        XCTAssertEqual(app.otherElements["board.mattress"].value as? String ?? "", "", "abierto, se fue del tablero")
    }

    /// El de regalo (D4) ya está en el tablero: la columna no lo ofrece y un toque lo abre sin video.
    func testTheGiftedMattressOpensOnTheBoard() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-mattress-board"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let chip = app.buttons["siderail.mattress"]
        XCTAssertFalse(chip.exists && chip.value as? String == "ready", "de regalo no pasa por la columna")

        tapTheBoardMattress(app)
        let result = app.descendants(matching: .any)["mattress.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), "el pop-up del premio sale siempre")
        XCTAssertFalse(app.buttons["mattress.open"].exists, "sin video")
        snap(app, "colchon de regalo abierto")
        app.buttons["mattress.collect"].tap()
        XCTAssertTrue(app.buttons["mattress.collect"].waitForNonExistence(timeout: 5))
    }

    func testTheSavedExtraMattressPaysWithOnlyTheVideo() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-mattress-extra"]
        app.launch()

        let chip = app.buttons["siderail.mattress"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        XCTAssertEqual(chip.value as? String, "ready", "el otro colchón guardado espera en la columna")
        chip.tap()

        let extra = app.buttons["mattress.extra"]
        XCTAssertTrue(extra.waitForExistence(timeout: 5), "el popup ofrece el video")
        XCTAssertFalse(app.buttons["mattress.open"].exists, "el colchón ya se abrió: nada de abrir gratis")
        XCTAssertFalse(app.descendants(matching: .any)["mattress.result"].exists)
        extra.tap()

        tapTheMattressOpen(app)
        let result = app.descendants(matching: .any)["mattress.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 8), "el video pagó")
        XCTAssertTrue(["coins", "package", "blue"].contains(result.value as? String ?? ""))
        XCTAssertTrue(extra.waitForNonExistence(timeout: 8), "otro colchón es uno solo")
        app.buttons["mattress.collect"].tap()
        XCTAssertTrue(app.buttons["mattress.collect"].waitForNonExistence(timeout: 5))

        // E14 D8: los sellos no disponibles no aparecen. Pagado el colchón, el
        // sello se va de la columna; si todavía estuviera, no puede estar listo.
        XCTAssertTrue(
            chip.waitForNonExistence(timeout: 5) || chip.value as? String != "ready",
            "pagado, el sello se va de la columna (D8) o, si queda, deja de estar listo"
        )
    }
}
