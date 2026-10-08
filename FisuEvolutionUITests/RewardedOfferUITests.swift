import XCTest

/// El botón de video responde al primer toque (PLAN-v2 E13 ítem 1): desde ahí
/// dice "Cargando video…", ignora los toques siguientes, y un doble toque es
/// UN video.
///
/// `--uitest-slow-ad-load` estira la "carga" del stub a 1,5 s: sin eso el
/// stub presenta en el acto y no hay ventana para el segundo toque.
/// ⚠️ `--uitest-skip-tutorial` por la trampa 9 del HANDOFF.
final class RewardedOfferUITests: XCTestCase {
    @MainActor
    func testDoubleTapOnAVideoIsOneVideoAndSaysLoadingFromTheFirstTouch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-slow-ad-load"]
        app.launch()

        XCTAssertTrue(app.buttons["hud.bonus"].waitForExistence(timeout: 15))
        app.buttons["hud.bonus"].tap()

        let watch = app.buttons["ads.watch.double_earnings"]
        XCTAssertTrue(watch.waitForExistence(timeout: 6), "la fila del video tiene que estar")
        for _ in 0..<6 where !watch.isHittable {
            app.swipeUp()
        }

        // Un solo gesto de dos toques: el segundo cae sobre lo que el primero
        // dejó en su lugar.
        watch.doubleTap()

        let loading = app.descendants(matching: .any)["ads.watch.double_earnings.watching"]
        XCTAssertTrue(loading.waitForExistence(timeout: 2),
                      "desde el primer toque el botón dice 'Cargando video…'")
        XCTAssertFalse(app.buttons["ads.watch.double_earnings"].exists,
                       "mientras carga no ofrece un segundo botón")

        XCTAssertTrue(app.staticTexts["ads.cooldown.double_earnings"].waitForExistence(timeout: 20)
                        || app.otherElements["ads.cooldown.double_earnings"].waitForExistence(timeout: 1),
                      "el video tiene que presentarse al llegar, terminar y dejar la fila en cooldown")
        app.buttons["sheet.close"].tap()

        let chips = app.otherElements.matching(identifier: "hud.bonus.chip")
        let one = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 1"), object: chips)
        XCTAssertEqual(XCTWaiter().wait(for: [one], timeout: 8), .completed,
                       "un doble toque es un video: un solo contador, hubo \(chips.count)")
    }
}
