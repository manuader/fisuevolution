import XCTest

/// E14b B7 (D6): el visitante se queda congelado en su piso. Se sube un piso, pasa más que su
/// paciencia (30 s) y, al volver, sigue esperando; desde el aviso de la columna se lo despacha.
final class VisitorFloorsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// La torre abierta hasta el urbano, el visible en el callejón y el turista llegando ahí.
    @MainActor
    private func launchWithAWaitingVisitor() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower",
                               "--uitest-visitor=turista_propina"]
        app.launch()
        // Desde B21 (D15) el popup no sale solo: llega y espera con su tarjeta.
        XCTAssertTrue(app.buttons["stage.chip.visitor"].waitForExistence(timeout: 25), "el turista no llegó")
        XCTAssertFalse(app.buttons["visit.option.accept"].exists, "el popup no sale solo")
        return app
    }

    @MainActor
    private func ride(_ app: XCUIApplication, to floorId: String) {
        app.buttons["hud.map"].press(forDuration: 0.9)
        let button = app.buttons["hud.elevator.keypad.floor.\(floorId)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3), "no se desplegó la placa")
        button.tap()
        let arrived = NSPredicate(format: "value == %@", floorId)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: arrived, evaluatedWith: app.otherElements["board.floor"])],
                                        timeout: 6), .completed, "no llegó a \(floorId)")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testSubirUnPisoYVolverDejaAlVisitanteEsperando() throws {
        let app = launchWithAWaitingVisitor()
        ride(app, to: "urban")
        let waiting = app.buttons["stage.chip.waiting"]
        XCTAssertTrue(waiting.waitForExistence(timeout: 4), "el aviso de arriba no avisa que espera en otro piso")
        XCTAssertEqual(waiting.value as? String, "1")
        XCTAssertFalse(app.buttons["stage.chip.visitor"].exists, "en el urbano no hay nadie en escena")
        attach(app, "B7: esperando en el callejón, aviso en el urbano")
        XCTAssertFalse(waiting.waitForNonExistence(timeout: 35), "congelado: pasó su paciencia y sigue esperando")

        ride(app, to: "alley")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 6), "al volver, el visitante sigue ahí")
        XCTAssertTrue(waiting.waitForNonExistence(timeout: 4), "y el aviso de otro piso se fue")
        XCTAssertFalse(app.buttons["visit.option.accept"].waitForExistence(timeout: 3), "el popup no sale solo al volver")
        chip.tap()
        XCTAssertTrue(app.buttons["visit.option.accept"].waitForExistence(timeout: 6), "la tarjeta lo reabre")
    }

    @MainActor
    func testDesdeElAvisoSeDespachaAlVisitanteDeOtroPiso() throws {
        let app = launchWithAWaitingVisitor()
        ride(app, to: "urban")
        let waiting = app.buttons["stage.chip.waiting"]
        XCTAssertTrue(waiting.waitForExistence(timeout: 4))
        waiting.tap()
        let accept = app.buttons["visit.option.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "el aviso no abrió su popup")
        XCTAssertEqual(app.otherElements["board.floor"].value as? String, "alley", "no llevó a su piso")
        attach(app, "B7: despachado desde el aviso")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 6))
    }
}
