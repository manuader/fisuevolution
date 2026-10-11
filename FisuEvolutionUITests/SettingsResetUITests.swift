import XCTest

final class SettingsResetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testResetearPideCasillaPalabraYMantenerTresSegundos() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()
        let tab = app.buttons["hud.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "la barra inferior nunca apareció")
        tab.tap()
        app.buttons["menu.card.settings"].tap()
        let reset = app.buttons["settings.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        if !reset.isHittable { app.swipeUp() }
        reset.tap()

        XCTAssertTrue(app.descendants(matching: .any)["reset.summary"].waitForExistence(timeout: 5))
        let next = app.buttons["reset.next"]
        next.tap()
        XCTAssertTrue(app.descendants(matching: .any)["reset.summary"].exists, "sin la casilla no se avanza")
        XCTAssertFalse(app.textFields["reset.word"].exists)
        let understand = app.switches["reset.understand"]
        XCTAssertEqual(understand.value as? String, "off")
        understand.tap()
        XCTAssertEqual(understand.value as? String, "on")
        next.tap()

        let word = app.textFields["reset.word"]
        XCTAssertTrue(word.waitForExistence(timeout: 5), "con la casilla sí avanza")
        word.tap()
        word.typeText("RESE")
        app.buttons["reset.next"].tap()
        XCTAssertTrue(word.exists, "con la palabra mal no se avanza")
        XCTAssertFalse(app.buttons["reset.hold"].exists)
        word.typeText("T")
        app.buttons["reset.next"].tap()

        let hold = app.buttons["reset.hold"]
        XCTAssertTrue(hold.waitForExistence(timeout: 5), "con la palabra bien sí avanza")
        hold.press(forDuration: 1.0)
        XCTAssertTrue(hold.exists, "soltar antes de los 3 s no resetea")
        hold.press(forDuration: 3.5)

        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 10), "la partida nueva arranca con el núcleo")
        XCTAssertEqual(step.value as? String, "core.tap")
    }
}
