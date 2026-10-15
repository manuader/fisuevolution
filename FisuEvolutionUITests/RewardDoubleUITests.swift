import XCTest

/// Toda recompensa gratis en dos pasos (E14b B29, D17), con el Ministro de Economía: su pop-up cobra con
/// un solo botón y recién después sale «¿Lo duplicás?» con «×2 con video» y «No, gracias». El anuncio es
/// el del stub (`--uitest*` nunca usa AdMob): está siempre listo y paga a los 2 s.
@MainActor
final class RewardDoubleUITests: XCTestCase {
    private static let site = "double.visit.ministro_subsidio"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-visitor=ministro_subsidio"]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// El pop-up del Ministro: desde B21 no sale solo, se abre tocando su tarjeta.
    private func openMinister(_ app: XCUIApplication) -> XCUIElement {
        let accept = app.buttons["visit.option.accept"]
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 25), "el Ministro llegó")
        chip.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "tocar su tarjeta abre el popup (B21)")
        return accept
    }

    func testCobrarPrimeroYDespuesElDobleConVideo() {
        let app = launch()
        let accept = openMinister(app)
        XCTAssertFalse(app.buttons[Self.site].exists, "nunca se ofrece duplicar en el primer pop-up")
        XCTAssertFalse(app.buttons["visit.option.video"].exists)
        attach(app, "B29 paso 1 — el Ministro, un solo botón")
        accept.tap()

        let double = app.buttons[Self.site]
        XCTAssertTrue(double.waitForExistence(timeout: 8), "cobrado, enseguida sale el ×2 con video")
        XCTAssertTrue(app.buttons["reward.double.decline"].exists, "con su «No, gracias»")
        XCTAssertTrue(accept.waitForNonExistence(timeout: 3), "el primer pop-up ya se fue: no se enciman")
        attach(app, "B29 paso 2 — ¿Lo duplicás?")
        double.tap()
        XCTAssertTrue(app.descendants(matching: .any)["\(Self.site).watching"].waitForExistence(timeout: 3),
                      "el video del stub está en pantalla")
        XCTAssertTrue(double.waitForNonExistence(timeout: 12), "el video pagó y el paso 2 se fue")
        XCTAssertFalse(app.buttons["reward.double.decline"].exists)
    }

    func testNoGraciasCierraElPasoDosSinVideo() {
        let app = launch()
        openMinister(app).tap()
        let decline = app.buttons["reward.double.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 8))
        decline.tap()
        XCTAssertTrue(app.buttons[Self.site].waitForNonExistence(timeout: 4), "«No, gracias» lo cierra")
        XCTAssertFalse(app.descendants(matching: .any)["\(Self.site).watching"].exists, "y no hubo video")
    }
}
