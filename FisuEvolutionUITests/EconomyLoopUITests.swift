import XCTest

/// F1 loop: tapping El Fisura earns coins; the spawn button enables and buys.
final class EconomyLoopUITests: XCTestCase {
    @MainActor
    func testTappingEarnsCoinsAndSpawnButtonExists() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        let coins = app.otherElements["hud.coins"]
        XCTAssertTrue(coins.waitForExistence(timeout: 15))
        let before = coins.value as? String

        // El Fisura arranca en la celda 0 (abajo-izquierda del board).
        let boardTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.13, dy: 0.77))
        for _ in 0..<20 {
            boardTap.tap()
        }

        // Al menos un tap tiene que haber pegado en el nodo y sumado monedas.
        let predicate = NSPredicate { _, _ in (coins.value as? String) != before }
        let changed = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 5), .completed, "coins never changed after tapping")

        let spawn = app.buttons["hud.spawn"]
        XCTAssertTrue(spawn.exists, "spawn button missing")
    }
}
