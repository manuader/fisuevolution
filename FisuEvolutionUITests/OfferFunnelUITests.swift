import XCTest

/// El embudo de ofertas por lugar (E15 T3), de punta a punta con el stub: el botón de video de
/// Regalos cuenta mostrado, aceptado y completado en el save. La sonda `ads.funnel.<site>.<etapa>`
/// (`--uitest-ad-value-probe`) muestra cada contador. El paso 2 de B29 se prueba con el Ministro, en
/// `RewardDoubleUITests`.
///
/// ⚠️ `--uitest-skip-tutorial` por la trampa 9 del HANDOFF: sin él, en un simulador limpio el
/// scrim se come los toques.
final class OfferFunnelUITests: XCTestCase {
    private static let site = "ads.watch.double_earnings"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRegalosCuentaMostradaAceptadaYCompletada() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-ad-value-probe"]
        app.launch()

        XCTAssertTrue(app.buttons["hud.bonus"].waitForExistence(timeout: 15))
        app.buttons["hud.bonus"].tap()

        // El video del stub tarda 2 s y siempre paga. Su fila vive abajo: se desliza hasta que
        // se pueda tocar (ver `BonusHUDUITests`).
        let watch = app.buttons[Self.site]
        XCTAssertTrue(watch.waitForExistence(timeout: 6), "la fila del video tiene que estar")
        for _ in 0..<6 where !watch.isHittable {
            app.swipeUp()
        }
        watch.tap()
        XCTAssertTrue(app.staticTexts["ads.cooldown.double_earnings"].waitForExistence(timeout: 15)
                        || app.otherElements["ads.cooldown.double_earnings"].waitForExistence(timeout: 1),
                      "el video tiene que terminar y dejar la fila en cooldown")
        app.buttons["sheet.close"].tap()

        expectFunnel(app, stage: "shown", equals: 1)
        expectFunnel(app, stage: "accepted", equals: 1)
        expectFunnel(app, stage: "completed", equals: 1)
        expectFunnel(app, stage: "dismissed", equals: 0)
        expectFunnel(app, stage: "unfilled", equals: 0)
    }

    @MainActor
    private func expectFunnel(_ app: XCUIApplication, stage: String, equals count: Int,
                              file: StaticString = #filePath, line: UInt = #line) {
        let probe = app.descendants(matching: .any)["ads.funnel.\(Self.site).\(stage)"]
        XCTAssertTrue(probe.waitForExistence(timeout: 6), "la sonda del embudo de \(stage)", file: file, line: line)
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '\(count)'"), object: probe)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 6), .completed,
                       "\(stage) = \(count), había '\(probe.value ?? "nada")'", file: file, line: line)
    }
}
