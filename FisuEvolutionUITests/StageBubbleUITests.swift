import XCTest

/// E14b B19 (D13): el globo de texto del visitante va arriba de todo —ni el HUD, ni las esquinas, ni
/// la pastilla del prestigio lo tapan— y entra entero en la pantalla. La escena de
/// `capturas-e14b/20.jpg`: un piso alto, el presentador de «Lluvia de paquetes» con su frase larga,
/// el evento activo en la columna y la pastilla del prestigio.
final class StageBubbleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-event=lluvia_paquetes"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func bubble(in app: XCUIApplication) -> XCUIElement {
        let bubble = app.descendants(matching: .any).matching(identifier: "stage.bubble").firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 25), "el presentador llega y habla")
        return bubble
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testEnUnPisoAltoElGloboLargoQuedaArribaDeTodoYEntero() throws {
        let app = launch(["--uitest-unlock-tower-all", "--uitest-prestige", "--uitest-floor=galaxy"])
        let floor = app.otherElements["board.floor"]
        XCTAssertTrue(floor.waitForExistence(timeout: 15))
        XCTAssertEqual(floor.value as? String, "galaxy", "arranca en un piso alto")
        let bubble = bubble(in: app)
        // Lo que dura la entrada del globo.
        Thread.sleep(forTimeInterval: 0.5)
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(bubble.frame), "el globo entra entero: \(bubble.frame) en \(window)")
        XCTAssertTrue(bubble.isHittable, "nada lo tapa: ni el HUD ni la pastilla del prestigio")
        XCTAssertTrue((bubble.label as String).contains("bolsones") || (bubble.label as String).contains("bags"),
                      "es la frase entera del presentador")
        attach(app, "B19: el globo largo en un piso alto, arriba de todo")
    }

    @MainActor
    func testEnElCallejonElGloboNoTapaElHUD() throws {
        let app = launch([])
        let bubble = bubble(in: app)
        Thread.sleep(forTimeInterval: 0.5)
        let map = app.buttons["hud.map"]
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(bubble.frame.minY, map.frame.maxY,
                                    "con lugar sobre la cabeza, el globo queda debajo del HUD: \(bubble.frame) / \(map.frame)")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(bubble.frame))
        attach(app, "B19: el globo en el callejón, debajo del HUD")
    }
}
