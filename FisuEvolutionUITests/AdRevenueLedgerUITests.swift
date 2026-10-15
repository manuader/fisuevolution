import XCTest

/// El circuito entero de E15 T2, de punta a punta con el stub: un video visto deja UNA impresión
/// anotada en el save. La sonda `ads.ledger.count` (`--uitest-ad-value-probe`) muestra el total.
///
/// ⚠️ `--uitest-skip-tutorial` por la trampa 9 del HANDOFF: sin él, en un simulador limpio el
/// scrim se come los toques.
final class AdRevenueLedgerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAWatchedVideoLeavesOneImpressionInTheLedger() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-ad-value-probe"]
        app.launch()

        let probe = app.descendants(matching: .any)["ads.ledger.count"]
        XCTAssertTrue(probe.waitForExistence(timeout: 15), "la sonda tiene que estar con el argumento")
        XCTAssertEqual(probe.value as? String, "0", "una partida nueva no vio ningún anuncio")

        XCTAssertTrue(app.buttons["hud.bonus"].waitForExistence(timeout: 15))
        app.buttons["hud.bonus"].tap()

        // El video del stub tarda 2 s y siempre paga. Su fila vive abajo: se desliza hasta que
        // se pueda tocar (ver `BonusHUDUITests`).
        let watch = app.buttons["ads.watch.double_earnings"]
        XCTAssertTrue(watch.waitForExistence(timeout: 6), "la fila del video tiene que estar")
        for _ in 0..<6 where !watch.isHittable {
            app.swipeUp()
        }
        watch.tap()
        XCTAssertTrue(app.staticTexts["ads.cooldown.double_earnings"].waitForExistence(timeout: 15)
                        || app.otherElements["ads.cooldown.double_earnings"].waitForExistence(timeout: 1),
                      "el video tiene que terminar y dejar la fila en cooldown")
        app.buttons["sheet.close"].tap()

        let one = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: probe)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "después del video"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertEqual(XCTWaiter().wait(for: [one], timeout: 6), .completed,
                       "un video visto deja una impresión en el ledger, había '\(probe.value ?? "nada")'")
    }
}
