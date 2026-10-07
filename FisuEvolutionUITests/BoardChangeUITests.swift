import XCTest

/// Un cambio del tablero que no hizo el jugador se ve: el par se funde a la
/// vista y el personaje nuevo se revela.
final class BoardChangeUITests: XCTestCase {
    @MainActor
    func testUnCambioDelTableroSeReproduceYRevela() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-board-change"]
        app.launch()
        let revealed = app.otherElements["board.revealed"]
        let units = app.otherElements["board.units"]
        XCTAssertTrue(revealed.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "value == %@", "2"), evaluatedWith: revealed)
        expectation(for: NSPredicate(format: "value == %@", "2"), evaluatedWith: units)
        waitForExpectations(timeout: 25)
    }
}
