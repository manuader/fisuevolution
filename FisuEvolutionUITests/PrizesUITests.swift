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

    /// Lo que falta para diagnosticar un rojo: la captura y el árbol de accesibilidad entero, por si
    /// otro pop-up modal tapa lo que se busca (E14b B24).
    private func diagnose(_ app: XCUIApplication, _ name: String) {
        snap(app, name)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "\(name): árbol"
        tree.lifetime = .keepAlways
        add(tree)
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

    /// Espera a que el colchón esté quieto en el tablero y lo toca en su centro (E14b B6). El
    /// marcador se publica recién cuando terminó de caer (B24): mientras espera que se cierre el
    /// pop-up del video y mientras cae, no se toca.
    private func tapTheBoardMattress(_ app: XCUIApplication) {
        let center = boardMattressCenter(app)
        app.coordinate(withNormalizedOffset: CGVector(dx: center.x, dy: center.y)).tap()
    }

    /// El centro del colchón quieto, normalizado a la pantalla (origen arriba a la izquierda).
    private func boardMattressCenter(_ app: XCUIApplication) -> CGPoint {
        let marker = app.otherElements["board.mattress"]
        XCTAssertTrue(marker.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value CONTAINS ','"), evaluatedWith: marker)
        waitForExpectations(timeout: 10)
        let parts = (marker.value as? String ?? "").split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 2, "el marcador trae x,y")
        return CGPoint(x: parts.first ?? 0, y: parts.last ?? 0)
    }

    /// El pop-up del premio, siempre con su imagen aprobada (E14b B24).
    private func assertThePrizeShowsItsArt(_ app: XCUIApplication) {
        let art = app.otherElements["mattress.result.art"]
        XCTAssertTrue(art.waitForExistence(timeout: 5), "el pop-up del premio trae la imagen")
        let key = art.value as? String ?? ""
        XCTAssertTrue(key.hasPrefix("rw_") || key.hasPrefix("ui_"), "imagen aprobada del premio, no el disco dibujado: \(key)")
    }

    /// E14b B24 (el bug del dueño): después del video el colchón cae a la vista en el piso que se
    /// mira, quieto se toca en su centro —el toque es del colchón, no de un empleado de adelante— y
    /// sale el pop-up del premio con su imagen.
    func testTheMattressAfterTheVideoLandsInSightAndOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-mattress"]
        app.launch()

        let chip = app.buttons["siderail.mattress"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        let open = app.buttons["mattress.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10), "el popup ofrece el video")
        open.tap()
        // Al tocar, el botón cambia de id («Cargando…», `mattress.open.watching`): esperar que se vaya
        // `open` no prueba nada. Se espera que termine el video y que el popup se haya ido.
        let watching = app.descendants(matching: .any)["mattress.open.watching"]
        _ = watching.waitForExistence(timeout: 2)
        XCTAssertTrue(watching.waitForNonExistence(timeout: 12), "el video (stub) terminó")
        XCTAssertTrue(app.descendants(matching: .any)["mattress.odds.coins"].waitForNonExistence(timeout: 5),
                      "al terminar el video el popup se cierra")

        let center = boardMattressCenter(app)
        snap(app, "B24 el colchón quieto en el piso")
        XCTAssertTrue((0.05...0.95).contains(center.x), "a la vista de costado: \(center.x)")
        XCTAssertTrue((0.3...0.92).contains(center.y), "en el piso, entre el HUD y la barra: \(center.y)")
        XCTAssertFalse(app.descendants(matching: .any)["mattress.result"].exists, "todavía cerrado")

        app.coordinate(withNormalizedOffset: CGVector(dx: center.x, dy: center.y)).tap()
        let result = app.descendants(matching: .any)["mattress.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), "el toque en su centro es del colchón y sale el pop-up del premio")
        assertThePrizeShowsItsArt(app)
        snap(app, "B24 el pop-up del premio")
        let collect = app.buttons["mattress.collect"]
        XCTAssertTrue(collect.waitForExistence(timeout: 5))
        collect.tap()
        XCTAssertTrue(collect.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["board.mattress"].value as? String ?? "", "", "abierto, se fue del tablero")
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
        assertThePrizeShowsItsArt(app)
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

        let collect = app.buttons["mattress.collect"]
        XCTAssertTrue(collect.waitForExistence(timeout: 5))
        collect.tap()
        XCTAssertTrue(collect.waitForNonExistence(timeout: 5), "Keep it! no cerró el colchón")
        XCTAssertEqual(app.otherElements["board.mattress"].value as? String ?? "", "", "abierto, se fue del tablero")
    }

    /// El de regalo (D4) ya está en el tablero: la columna no lo ofrece y un toque lo abre sin video.
    /// Cobrarlo ofrece su ×2 con video (el paso 2 de B29), que «No, gracias» cierra.
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
        if !result.waitForExistence(timeout: 10) { diagnose(app, "colchon de regalo: sin el premio") }
        XCTAssertTrue(result.exists, "el pop-up del premio sale siempre")
        XCTAssertFalse(app.buttons["mattress.open"].exists, "sin video")
        assertThePrizeShowsItsArt(app)
        snap(app, "colchon de regalo abierto")
        let collect = app.buttons["mattress.collect"]
        if !collect.waitForExistence(timeout: 5) { diagnose(app, "colchon de regalo: sin Cobrar") }
        XCTAssertTrue(collect.exists, "el pop-up del premio cobra")
        collect.tap()
        XCTAssertTrue(collect.waitForNonExistence(timeout: 5))
        let decline = app.buttons["reward.double.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 8), "cobrado el de regalo, sale su ×2 con video (B29)")
        XCTAssertTrue(app.buttons["double.mattress"].exists)
        decline.tap()
        XCTAssertTrue(decline.waitForNonExistence(timeout: 4))
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
        // Mientras el video se precarga el botón dice «Cargando…» con otro id: se lo espera de sobra.
        if !extra.waitForExistence(timeout: 12) { diagnose(app, "otro colchon: sin el video") }
        XCTAssertTrue(extra.exists, "el popup ofrece el video")
        XCTAssertFalse(app.buttons["mattress.open"].exists, "el colchón ya se abrió: nada de abrir gratis")
        XCTAssertFalse(app.descendants(matching: .any)["mattress.result"].exists)
        extra.tap()

        tapTheMattressOpen(app)
        let result = app.descendants(matching: .any)["mattress.result"]
        if !result.waitForExistence(timeout: 8) { diagnose(app, "otro colchon: sin el premio") }
        XCTAssertTrue(result.exists, "el video pagó")
        XCTAssertTrue(["coins", "package", "blue"].contains(result.value as? String ?? ""))
        XCTAssertTrue(extra.waitForNonExistence(timeout: 8), "otro colchón es uno solo")
        let collect = app.buttons["mattress.collect"]
        if !collect.waitForExistence(timeout: 5) { diagnose(app, "otro colchon: sin Cobrar") }
        XCTAssertTrue(collect.exists)
        collect.tap()
        XCTAssertTrue(collect.waitForNonExistence(timeout: 5))

        // E14 D8: los sellos no disponibles no aparecen. Pagado el colchón, el
        // sello se va de la columna; si todavía estuviera, no puede estar listo.
        XCTAssertTrue(
            chip.waitForNonExistence(timeout: 5) || chip.value as? String != "ready",
            "pagado, el sello se va de la columna (D8) o, si queda, deja de estar listo"
        )
    }
}
