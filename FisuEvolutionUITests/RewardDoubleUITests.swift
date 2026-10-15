import XCTest

/// Toda recompensa gratis en dos pasos (E14b B29, D17), con el Ministro de Economía: su pop-up cobra con
/// un solo botón y recién después sale «¿Lo duplicás?» con «×2 con video» y «No, gracias». El anuncio es
/// el del stub (`--uitest*` nunca usa AdMob): está siempre listo y paga a los 2 s.
///
/// El embudo de ofertas (E15 T3) se mira acá también: el «×2 con video» es un `RewardedOfferButton`
/// con el `site` del paso 2 como id, y la sonda (`--uitest-ad-value-probe`) muestra sus contadores.
@MainActor
final class RewardDoubleUITests: XCTestCase {
    private static let site = "double.visit.ministro_subsidio"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-visitor=ministro_subsidio",
                               "--uitest-ad-value-probe"]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Un contador del embudo del paso 2, por la sonda.
    private func expectFunnel(_ app: XCUIApplication, stage: String, equals count: Int,
                              file: StaticString = #filePath, line: UInt = #line) {
        let probe = app.descendants(matching: .any)["ads.funnel.\(Self.site).\(stage)"]
        XCTAssertTrue(probe.waitForExistence(timeout: 6), "la sonda del embudo de \(stage)", file: file, line: line)
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '\(count)'"), object: probe)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 6), .completed,
                       "\(stage) = \(count), había '\(probe.value ?? "nada")'", file: file, line: line)
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

        expectFunnel(app, stage: "shown", equals: 1)
        expectFunnel(app, stage: "accepted", equals: 1)
        expectFunnel(app, stage: "completed", equals: 1)
        expectFunnel(app, stage: "dismissed", equals: 0)
    }

    func testNoGraciasCierraElPasoDosSinVideo() {
        let app = launch()
        openMinister(app).tap()
        let decline = app.buttons["reward.double.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 8))
        decline.tap()
        XCTAssertTrue(app.buttons[Self.site].waitForNonExistence(timeout: 4), "«No, gracias» lo cierra")
        XCTAssertFalse(app.descendants(matching: .any)["\(Self.site).watching"].exists, "y no hubo video")

        // E15 T3: «No, gracias» es el `dismissed` del lugar del paso 2.
        expectFunnel(app, stage: "shown", equals: 1)
        expectFunnel(app, stage: "dismissed", equals: 1)
        expectFunnel(app, stage: "accepted", equals: 0)
    }
}
