import XCTest

/// La tarjeta del momento (2.1 E15 F3 T6): con un segmento que ve ofertas y el momento forzado aparece
/// centrada; «No, gracias» la cierra y cuenta `dismissed`; el video (stub) paga y cuenta `completed`; con
/// `base` no aparece nunca. La sonda `ads.funnel.<site>.<etapa>` muestra cada contador.
///
/// ⚠️ `--uitest-skip-tutorial` por la trampa 9 del HANDOFF.
final class MomentOfferUITests: XCTestCase {
    private static let site = "moment.pw_small"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(segment: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-ad-value-probe",
            "--uitest-segment", segment, "--uitest-moment", "price_wall", "--uitest-moment-arm", "pw_small",
        ]
        app.launch()
        return app
    }

    @MainActor
    func testNoGraciasLaCierraYCuentaDescartada() throws {
        let app = launch(segment: "high")
        XCTAssertTrue(app.staticTexts["moment.offer.amount"].waitForExistence(timeout: 30), "la tarjeta no salió")
        app.buttons["moment.offer.decline"].tap()
        XCTAssertTrue(app.staticTexts["moment.offer.amount"].waitForNonExistence(timeout: 5))
        expectFunnel(app, stage: "dismissed", equals: 1)
        expectFunnel(app, stage: "completed", equals: 0)
    }

    @MainActor
    func testElVideoPagaYCuentaCompletada() throws {
        let app = launch(segment: "high")
        let watch = app.buttons[Self.site]
        XCTAssertTrue(watch.waitForExistence(timeout: 30), "el botón del video no salió")
        watch.tap()
        XCTAssertTrue(app.staticTexts["moment.offer.amount"].waitForNonExistence(timeout: 15), "el premio no cerró la tarjeta")
        expectFunnel(app, stage: "accepted", equals: 1)
        expectFunnel(app, stage: "completed", equals: 1)
    }

    @MainActor
    func testConBaseNoAparece() throws {
        let app = launch(segment: "base")
        XCTAssertTrue(app.buttons["hud.bonus"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["moment.offer.amount"].waitForExistence(timeout: 12), "base no ve ofertas")
        XCTAssertFalse(app.buttons[Self.site].exists)
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
