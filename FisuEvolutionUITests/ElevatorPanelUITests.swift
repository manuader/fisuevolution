import XCTest

/// La placa colgante del ascensor (PLAN-v2 E13, ítem 13): mantener apretado el ícono la
/// despliega con un botón por piso abierto; un botón viaja; tocar afuera la recoge; el toque
/// corto sigue siendo el mapa.
final class ElevatorPanelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // La torre abierta hasta el urbano; el piso visible arranca en el callejón.
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 20), "el ícono del ascensor no apareció")
        return app
    }

    @MainActor
    func testMantenerApretadoDespliegaUnBotonPorPisoYLlevaAlPiso() throws {
        let app = launch()
        XCTAssertFalse(app.otherElements["hud.elevator.keypad"].exists, "en reposo no hay placa")
        XCTAssertFalse(app.buttons["hud.elevator.display"].exists, "el display LED se fue del tablero")
        app.buttons["hud.map"].press(forDuration: 0.9)
        let keypad = app.otherElements["hud.elevator.keypad"]
        XCTAssertTrue(keypad.waitForExistence(timeout: 3), "mantener apretado no desplegó la placa")
        XCTAssertEqual(keypad.value as? String, "2", "un botón por piso abierto")
        XCTAssertFalse(app.buttons["map.floor.urban"].exists, "soltar no abrió el mapa")
        attach(app, named: "E13b placa desplegada")
        app.buttons["hud.elevator.keypad.floor.urban"].tap()
        XCTAssertTrue(keypad.waitForNonExistence(timeout: 2), "elegir no recogió la placa")
        let arrived = NSPredicate(format: "value == %@", "urban")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: arrived, evaluatedWith: app.otherElements["board.floor"])],
                                        timeout: 5), .completed, "el botón no llevó al urbano")
    }

    @MainActor
    func testTocarAfueraLaRecogeYElToqueCortoSigueSiendoElMapa() throws {
        let app = launch()
        let unitsBefore = app.otherElements["board.units"].value as? String
        app.buttons["hud.map"].press(forDuration: 0.9)
        let keypad = app.otherElements["hud.elevator.keypad"]
        XCTAssertTrue(keypad.waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        XCTAssertTrue(keypad.waitForNonExistence(timeout: 2), "tocar afuera no la recogió")
        XCTAssertEqual(app.otherElements["board.units"].value as? String, unitsBefore, "el toque de afuera llegó al tablero")
        app.buttons["hud.map"].tap()
        XCTAssertTrue(app.buttons["map.floor.urban"].waitForExistence(timeout: 5), "el toque corto es el mapa")
    }

    @MainActor
    func testElBotonDeLaPlacaViajaEnCabina() throws {
        let app = launch(["--uitest-elevator-ride"])
        app.buttons["hud.map"].press(forDuration: 0.9)
        app.buttons["hud.elevator.keypad.floor.urban"].tap()
        XCTAssertTrue(app.buttons["elevator.ride.skip"].waitForExistence(timeout: 3), "no arrancó el viaje")
        XCTAssertTrue(app.buttons["elevator.ride.skip"].waitForNonExistence(timeout: 5), "el viaje no terminó")
        XCTAssertEqual(app.otherElements["board.floor"].value as? String, "urban")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
