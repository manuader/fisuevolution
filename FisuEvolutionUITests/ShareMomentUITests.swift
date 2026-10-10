import XCTest

/// Compartir (PLAN-v2 E3): el momento viral se ofrece como botón, abre la
/// tarjeta vertical y se descarta sin interrumpir. La hoja del sistema para
/// compartir no se puede completar desde el runner: eso lo cubre `ShareMomentTests`.
final class ShareMomentUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElMomentoViralSeOfreceComoBotonYAbreLaTarjeta() throws {
        let app = launch()
        offer(in: app)
        let button = app.buttons["share.offer"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "el momento no se ofreció")
        button.tap()
        XCTAssertTrue(app.buttons["share.button"].waitForExistence(timeout: 5), "no abrió la tarjeta")
        let skip = app.buttons["share.skip"]
        skip.tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 8))
        XCTAssertFalse(app.buttons["share.offer"].exists, "abrirla consume la oferta")
    }

    @MainActor
    func testLaOfertaSeDescartaConLaX() throws {
        let app = launch()
        offer(in: app)
        let dismiss = app.buttons["share.offer.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        dismiss.tap()
        XCTAssertTrue(app.buttons["share.offer"].waitForNonExistence(timeout: 3))
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-share"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func offer(in app: XCUIApplication) {
        let debugKey = app.buttons["hud.debug"]
        XCTAssertTrue(debugKey.waitForExistence(timeout: 6))
        debugKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        // La lista del panel es perezosa: la fila puede estar bajo el pliegue.
        let button = app.buttons["debug.share.offer"]
        var swipes = 0
        while !button.waitForExistence(timeout: 2), swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(button.exists, "el panel de debug no ofrece compartir")
        button.tap()
    }
}
