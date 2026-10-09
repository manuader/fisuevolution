import XCTest

/// La cinemática a pantalla completa: tapa el juego, se come los toques y se cierra con su "Saltar"
/// o sola. `--uitest-video` le saca al pool el póster forzado de los UI tests.
final class CinematicUITests: XCTestCase {
    private static func launchArguments(_ id: String) -> [String] {
        ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-video", "--uitest-cinematic=\(id)"]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaCinematicaTapaLaPantallaYSeSaltea() {
        let app = XCUIApplication()
        app.launchArguments = Self.launchArguments("dios")
        app.launch()
        let video = app.descendants(matching: .any)["cinematic.player"]
        XCTAssertTrue(video.waitForExistence(timeout: 8))
        let skip = app.buttons["cinematic.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertTrue(video.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["hud.debug"].waitForExistence(timeout: 3), "el HUD vuelve")
    }

    @MainActor
    func testUnTapAlTableroNoLaSaltea() {
        let app = XCUIApplication()
        app.launchArguments = Self.launchArguments("dios")
        app.launch()
        let video = app.descendants(matching: .any)["cinematic.player"]
        XCTAssertTrue(video.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["cinematic.skip"].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(video.exists, "el tap al tablero de abajo no la corta")
        XCTAssertTrue(app.buttons["cinematic.skip"].exists)
    }

    @MainActor
    func testSinTocarNadaTerminaSola() {
        let app = XCUIApplication()
        app.launchArguments = Self.launchArguments("arresto")
        app.launch()
        let video = app.descendants(matching: .any)["cinematic.player"]
        XCTAssertTrue(video.waitForExistence(timeout: 8))
        XCTAssertTrue(video.waitForNonExistence(timeout: 12))
    }
}
