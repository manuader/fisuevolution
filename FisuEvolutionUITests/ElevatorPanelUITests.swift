import XCTest

/// La botonera del ascensor (PLAN-v2 E3): el display muestra el piso, tocarlo
/// despliega la persiana, un botón lleva al piso y la persiana se recoge sola.
final class ElevatorPanelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaBotoneraLlevaAlPisoYSeRecogeSola() throws {
        let app = XCUIApplication()
        // La torre abierta hasta el urbano; el piso visible arranca en el callejón.
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower"]
        app.launch()

        let display = app.buttons["hud.elevator.display"]
        XCTAssertTrue(display.waitForExistence(timeout: 20), "el display del ascensor no apareció")
        XCTAssertEqual(display.value as? String, "alley")
        XCTAssertTrue(app.buttons["hud.map"].exists, "el ícono del ascensor se conserva")
        XCTAssertFalse(app.buttons["hud.elevator.floor.urban"].exists, "en reposo sólo se ve el display")

        display.tap()
        let urban = app.buttons["hud.elevator.floor.urban"]
        XCTAssertTrue(urban.waitForExistence(timeout: 3), "la persiana no se desplegó")
        // Sin capturas entre medio: la persiana se recoge a los 2 s y una captura
        // con la máquina cargada se los come.
        urban.tap()
        attach(app, named: "E3 botonera desplegada")

        let floor = app.otherElements["board.floor"]
        let arrived = NSPredicate(format: "value == %@", "urban")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: arrived, evaluatedWith: floor)], timeout: 5), .completed,
                       "el botón no llevó al urbano")
        XCTAssertEqual(display.value as? String, "urban")
        XCTAssertTrue(urban.waitForNonExistence(timeout: 6), "la persiana no se recogió a los 2 s")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
