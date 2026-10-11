import XCTest

/// El candado de 5 s de verdad (PLAN-v2 E9). El resto de las suites lo baja con
/// `--uitest-tutorial-lock=0.3`; ésta no. La lección es `probe_explain`, sólo de
/// DEBUG: un paso de explicar y nada más, sin armar el momento de ninguna lección.
///
/// ⚠️ Mide tiempos reales y la máquina puede estar muy cargada: con el candado de
/// 5 s sólo se mira que nace cerrado y se abre solo. Que «Entendido» no avance con
/// el candado puesto se prueba con uno de 60 s, donde un toque lento no lo abre.
final class TutorialLockUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchProbe(lock: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-lesson=probe_explain"]
            + (lock.map { ["--uitest-tutorial-lock=\($0)"] } ?? [])
        app.launch()
        return app
    }

    @MainActor
    func testEntendidoEsperaCincoSegundos() throws {
        let app = launchProbe()
        let confirm = app.buttons["tutorial.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 20))
        XCTAssertEqual(confirm.value as? String, "locked", "nace cerrado")
        expectation(for: NSPredicate(format: "value == 'unlocked'"), evaluatedWith: confirm)
        waitForExpectations(timeout: 10)
        confirm.tap()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForNonExistence(timeout: 5), "abierto el candado, «Entendido» la cierra")
    }

    @MainActor
    func testConElCandadoPuestoEntendidoNoAvanza() throws {
        let app = launchProbe(lock: "60")
        let confirm = app.buttons["tutorial.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 20))
        confirm.tap()
        confirm.tap()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertEqual(step.value as? String, "probe_explain.one", "con el candado puesto no avanza")
        XCTAssertEqual(confirm.value as? String, "locked")
    }

    @MainActor
    func testElToqueAlTableroNoCierraLaLeccion() throws {
        let app = launchProbe()
        let tip = app.descendants(matching: .any)["tutorial.tip"]
        XCTAssertTrue(tip.waitForExistence(timeout: 20))
        XCTAssertEqual(tip.value as? String, "probe_explain")
        // El tablero de arriba, lejos de la tarjeta: sin recorte va centrada, y un toque
        // en el medio de la pantalla caería en «Entendido» apenas se abre el candado.
        let confirm = app.buttons["tutorial.confirm"]
        let board = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        XCTAssertFalse(confirm.frame.insetBy(dx: 0, dy: -120).contains(board.screenPoint),
                       "fixture: el toque tiene que caer en el tablero, no en la tarjeta")
        for _ in 0..<5 { board.tap() }
        XCTAssertTrue(tip.exists, "tocar el tablero ya no saltea")
        // Y la salida buena sigue andando: el toque no la rompió.
        expectation(for: NSPredicate(format: "value == 'unlocked'"), evaluatedWith: confirm)
        waitForExpectations(timeout: 10)
        confirm.tap()
        XCTAssertTrue(tip.waitForNonExistence(timeout: 5))
    }
}
