import XCTest

/// La ruleta se gira desde Regalos (PLAN-v2 E5): un giro regalado, el premio
/// a la vista, "repetir" una vez y la tabla siempre visible. El candado anti
/// doble toque vive en la vista y se prueba acá: el simulador corre con
/// Reduce Motion (`Tools/v2/oraculo.sh` lo deja prendido para esta clase).
@MainActor
final class WheelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(spins: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-wheel-spins=\(spins)"]
        app.launch()
        return app
    }

    private func openWheel(_ app: XCUIApplication) {
        let gifts = app.buttons["hud.bonus"]
        XCTAssertTrue(gifts.waitForExistence(timeout: 15))
        gifts.tap()
        let open = app.buttons["gifts.wheel.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
    }

    func testTheWheelSpinsFromGifts() {
        let app = launch(spins: 1)
        openWheel(app)

        XCTAssertTrue(app.descendants(matching: .any)["wheel.odds.coins_30"].waitForExistence(timeout: 5),
                      "la tabla está a la vista antes de girar")
        let free = app.buttons["wheel.spin.bonus"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        free.tap()

        let result = app.descendants(matching: .any)["wheel.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertFalse((result.value as? String ?? "").isEmpty)
        let again = app.buttons["wheel.repeat"]
        XCTAssertTrue(again.waitForExistence(timeout: 3))
        again.tap()
        XCTAssertTrue(again.waitForNonExistence(timeout: 6), "repetir es una vez por giro")
        XCTAssertTrue(app.buttons["wheel.spin.video"].exists, "después del regalado quedan los de video")
    }

    /// Un toque al giro regalado gasta UNO: con dos regalados, queda uno. El doble
    /// cobro se prueba con un unitario del cerrojo (`WheelSpinLatchTests`).
    func testASpinSpendsOneSpin() {
        let app = launch(spins: 2)
        openWheel(app)

        let free = app.buttons["wheel.spin.bonus"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        free.tap()

        XCTAssertTrue(app.descendants(matching: .any)["wheel.result"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["wheel.spin.bonus"].waitForExistence(timeout: 5),
                      "gastó un giro regalado y quedó el otro")
        XCTAssertFalse(app.buttons["wheel.spin.video"].exists, "con un regalado en pie no se ofrece el de video")
    }

    /// El giro por video gira cuando el video se premia (el stub paga a los 2 s) y
    /// la cuenta de videos de hoy baja.
    func testTheVideoSpinSpinsAndCountsDown() {
        let app = launch(spins: 0)
        openWheel(app)

        let video = app.buttons["wheel.spin.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        let before = video.label
        video.tap()

        XCTAssertTrue(app.descendants(matching: .any)["wheel.result"].waitForExistence(timeout: 12),
                      "el video se miró y la rueda tiene que girar")
        let after = app.buttons["wheel.spin.video"]
        XCTAssertTrue(after.waitForExistence(timeout: 8))
        XCTAssertNotEqual(after.label, before, "la cuenta de videos bajó")
    }

    /// Mientras carga el video de "repetir" no se puede girar.
    func testCannotSpinWhileTheRepeatVideoLoads() {
        let app = launch(spins: 2)
        openWheel(app)

        let free = app.buttons["wheel.spin.bonus"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        free.tap()
        let again = app.buttons["wheel.repeat"]
        XCTAssertTrue(again.waitForExistence(timeout: 8))
        again.tap()

        XCTAssertTrue(app.descendants(matching: .any)["wheel.repeat.watching"].waitForExistence(timeout: 3))
        app.buttons["wheel.spin.bonus"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["wheel.spinning"].exists, "con el video en curso no se gira")
        XCTAssertTrue(app.descendants(matching: .any)["wheel.repeat.watching"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["wheel.spin.bonus"].waitForExistence(timeout: 3),
                      "el toque durante el video no gastó el giro regalado")
    }
}
