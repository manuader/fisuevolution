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

    /// `video` le saca al pool el póster forzado: la Ruleta se ve con el marco del clip.
    private func launch(spins: Int, video: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-wheel-spins=\(spins)"]
            + (video ? ["--uitest-video"] : [])
        app.launch()
        return app
    }

    /// La captura de un momento de la pantalla de premio (E14 T17), adjunta al resultado.
    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
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
        let app = launch(spins: 1, video: true)
        openWheel(app)

        XCTAssertTrue(app.descendants(matching: .any)["wheel.odds.coins_30"].waitForExistence(timeout: 5),
                      "la tabla está a la vista antes de girar")
        let free = app.buttons["wheel.spin.bonus"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        snap(app, "ruleta 1 antes")
        free.tap()
        snap(app, "ruleta 2 durante")

        let result = app.descendants(matching: .any)["wheel.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        snap(app, "ruleta 3 despues")
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

    /// El video de "repetir" no gira la rueda ni gasta el giro regalado que queda.
    /// Que un toque DURANTE el video no gire lo prueba el unitario del cerrojo
    /// (`WheelSpinLatchTests`): el video del stub dura 2 s y, con la máquina
    /// cargada, el segundo toque de XCUITest llegaba después y giraba con derecho.
    func testTheRepeatVideoDoesNotSpendTheFreeSpin() {
        let app = launch(spins: 2)
        openWheel(app)

        let free = app.buttons["wheel.spin.bonus"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        free.tap()
        let again = app.buttons["wheel.repeat"]
        XCTAssertTrue(again.waitForExistence(timeout: 8))
        again.tap()

        let watching = app.descendants(matching: .any)["wheel.repeat.watching"]
        XCTAssertTrue(watching.waitForExistence(timeout: 3))
        XCTAssertTrue(watching.waitForNonExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["wheel.spinning"].exists, "repetir no gira la rueda")
        XCTAssertTrue(app.buttons["wheel.spin.bonus"].waitForExistence(timeout: 3),
                      "repetir no gastó el giro regalado")
    }
}
