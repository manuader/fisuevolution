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

    func testTheMattressOpensWithAVideo() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-mattress"]
        app.launch()

        let chip = app.buttons["siderail.mattress"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        XCTAssertEqual(chip.value as? String, "ready")
        chip.tap()

        XCTAssertTrue(app.descendants(matching: .any)["mattress.odds.coins"].waitForExistence(timeout: 5),
                      "lo que puede tocar está a la vista antes del video")
        snap(app, "colchon 1 antes")
        app.buttons["mattress.open"].tap()
        tapTheMattressOpen(app)
        let result = app.descendants(matching: .any)["mattress.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        snap(app, "colchon 3 despues")
        XCTAssertTrue(["coins", "package", "oro"].contains(result.value as? String ?? ""))

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
        XCTAssertTrue(["coins", "package", "oro"].contains(result.value as? String ?? ""))
        XCTAssertTrue(extra.waitForNonExistence(timeout: 8), "otro colchón es uno solo")
        app.buttons["mattress.collect"].tap()
        XCTAssertTrue(app.buttons["mattress.collect"].waitForNonExistence(timeout: 5))

        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertNotEqual(chip.value as? String, "ready", "pagado, el sello deja de estar listo")
    }
}
