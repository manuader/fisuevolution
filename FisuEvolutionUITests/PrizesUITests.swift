import XCTest

/// El paquete y el colchón se tocan desde sus chips (PLAN-v2 E5). El video del
/// colchón lo pone el stub de anuncios: 2 s y paga.
@MainActor
final class PrizesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAPackageBringsAWorker() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-packages=1"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let before = Int(units.value as? String ?? "") ?? 0
        let chip = app.buttons["prize.chip.package"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.value as? String, "1")
        chip.tap()

        expectation(for: NSPredicate(format: "value == %@", String(before + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(chip.waitForNonExistence(timeout: 3), "con el buzón vacío el chip se va")
    }

    func testTheMattressOpensWithAVideo() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-mattress"]
        app.launch()

        let chip = app.buttons["prize.chip.mattress"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()

        XCTAssertTrue(app.descendants(matching: .any)["mattress.odds.coins"].waitForExistence(timeout: 5),
                      "lo que puede tocar está a la vista antes del video")
        app.buttons["mattress.open"].tap()
        let result = app.descendants(matching: .any)["mattress.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(["coins", "package", "oro"].contains(result.value as? String ?? ""))

        let extra = app.buttons["mattress.extra"]
        XCTAssertTrue(extra.waitForExistence(timeout: 3))
        extra.tap()
        XCTAssertTrue(extra.waitForNonExistence(timeout: 8), "otro colchón es uno solo")
        app.buttons["mattress.collect"].tap()
        XCTAssertTrue(chip.waitForNonExistence(timeout: 5), "abierto, el colchón se va")
    }
}
