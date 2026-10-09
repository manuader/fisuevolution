import XCTest

final class ElevatorRideUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testElegirUnPisoEnElMapaViajaEnCabinaYSeSaltea() throws {
        let app = launchedApp()
        let skip = pickUrbanInTheMap(app)
        XCTAssertTrue(skip.waitForExistence(timeout: 3), "elegir en el mapa no abrió la cabina")
        // La cabina dura ~2 s: resolver el botón de nuevo para tocarlo llega tarde, se toca la pantalla.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 2), "saltear no cerró la cabina")
        XCTAssertEqual(app.otherElements["board.floor"].value as? String, "urban",
                       "al saltear, el destino queda a la vista")
    }

    @MainActor
    func testElViajeTerminaSoloEnElDestino() throws {
        let app = launchedApp()
        let skip = pickUrbanInTheMap(app)
        XCTAssertTrue(skip.waitForExistence(timeout: 3), "elegir en el mapa no abrió la cabina")
        XCTAssertTrue(skip.waitForNonExistence(timeout: 6), "el viaje no terminó solo")
        XCTAssertEqual(app.otherElements["board.floor"].value as? String, "urban")
    }

    @MainActor
    func testScrollearEntrePisosNuncaViaja() throws {
        let app = launchedApp()
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 20))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertFalse(app.buttons["elevator.ride.skip"].exists, "scrollear abrió la cabina")
        let board = app.otherElements["board.floor"]
        let arrived = NSPredicate(format: "value == %@", "urban")
        wait(for: [expectation(for: arrived, evaluatedWith: board)], timeout: 5)
        XCTAssertFalse(app.buttons["elevator.ride.skip"].exists, "scrollear abrió la cabina")
    }

    @MainActor
    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower",
                               "--uitest-elevator-ride"]
        app.launch()
        return app
    }

    @MainActor
    private func pickUrbanInTheMap(_ app: XCUIApplication) -> XCUIElement {
        let map = app.buttons["hud.map"]
        XCTAssertTrue(map.waitForExistence(timeout: 20))
        map.tap()
        let urban = app.buttons["map.floor.urban"]
        XCTAssertTrue(urban.waitForExistence(timeout: 5))
        urban.tap()
        return app.buttons["elevator.ride.skip"]
    }
}
