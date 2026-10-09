import XCTest

/// El atajo de contratar (PLAN-v2 E3): dice su estado y mantenerlo presionado no
/// compra. El selector que abre lo prueba `QuickHireUITests`.
final class QuickHireButtonUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElAtajoDiceSiCompraONoYPorQue() throws {
        let broke = launch(["--uitest-reset", "--uitest-skip-tutorial"])
        let quickHire = broke.buttons["hud.quickhire"]
        XCTAssertTrue(quickHire.waitForExistence(timeout: 20))
        XCTAssertEqual(quickHire.value as? String, "cantAfford:homeless", "sin plata: meta de ahorro")
        broke.terminate()

        let rich = launch(["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"])
        let ready = rich.buttons["hud.quickhire"]
        XCTAssertTrue(ready.waitForExistence(timeout: 20))
        XCTAssertEqual(ready.value as? String, "ready:homeless")
    }

    @MainActor
    func testMantenerPresionadoNoCompra() throws {
        let app = launch(["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"])
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(quickHire.waitForExistence(timeout: 20))
        let units = app.otherElements["board.units"]
        let before = units.value as? String

        quickHire.press(forDuration: 0.9)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(units.value as? String, before, "el toque de soltar después de mantener no compra")

        quickHire.tap()
        let bought = NSPredicate(format: "value != %@", before ?? "")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: bought, evaluatedWith: units)], timeout: 5),
                       .completed, "un toque común sí compra")
    }

    @MainActor
    func testUnToqueDespuesDeMantenerPresionadoSiCompra() throws {
        let app = launch(["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"])
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(quickHire.waitForExistence(timeout: 20))
        let units = app.otherElements["board.units"]
        let before = units.value as? String

        quickHire.press(forDuration: 1.0)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertEqual(units.value as? String, before, "mantener no compra")

        quickHire.tap()
        let bought = NSPredicate(format: "value != %@", before ?? "")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: bought, evaluatedWith: units)], timeout: 5),
                       .completed, "el toque que sigue a un mantener compra")
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }
}
