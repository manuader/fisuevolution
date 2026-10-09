import XCTest

final class ElevatorRideUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testElegirUnPisoEnElMapaViajaEnCabinaYSeSaltea() throws {
        // x5: el viaje dura ~10 s, así que si la cabina se va en un par de segundos fue por saltear.
        let app = launchedApp(slow: true)
        let skip = pickUrbanInTheMap(app)
        XCTAssertTrue(skip.waitForExistence(timeout: 3), "elegir en el mapa no abrió la cabina")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 3), "saltear no cerró la cabina")
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
    private func launchedApp(slow: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower",
                               "--uitest-elevator-ride"] + (slow ? ["--uitest-elevator-ride-slow"] : [])
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
