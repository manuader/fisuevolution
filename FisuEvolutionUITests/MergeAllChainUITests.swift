import XCTest

/// "Fusionar todo" se ve entero: siete pares en cadena, tres tiers nuevos, y la
/// cola no se traba (PLAN-v2, verificación: "Fusionar todo con un tier nuevo en
/// el medio, que se celebra").
final class MergeAllChainUITests: XCTestCase {
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-merge-all"]
        app.launch()
        return app
    }

    @MainActor
    private func waitForTheEnd(_ app: XCUIApplication, timeout: TimeInterval) {
        let units = app.otherElements["board.units"]
        let revealed = app.otherElements["board.revealed"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: units)
        expectation(for: NSPredicate(format: "value == %@", "4"), evaluatedWith: revealed)
        waitForExpectations(timeout: timeout)
    }

    @MainActor
    func testLaCadenaTerminaYRevelaLosTresTiers() {
        let app = launch()
        // 7 eslabones (~2,7 s) + 3 reveals (~2 s c/u) + el arranque; en un simulador cargado midió 19,9 s: 30 s de techo.
        waitForTheEnd(app, timeout: 30)
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 5), "el HUD volvió")
    }

    @MainActor
    func testTocandoSinPararLaCadenaTerminaIgual() {
        let app = launch()
        XCTAssertTrue(app.otherElements["board.floor"].waitForExistence(timeout: 15))
        let board = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        for _ in 0..<20 { board.tap() }
        waitForTheEnd(app, timeout: 30)
    }
}
