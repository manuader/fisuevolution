import XCTest

/// El doble toque fusiona un par cercano **fuera del tutorial**, que es el caso
/// difícil: acá nadie está congelado y los dos personajes deambulan a 44 pt/s.
/// El paso del tutorial los tiene quietos bajo su recorte, así que aquel test
/// no prueba esto.
///
/// ⚠️ `--uitest-skip-tutorial` por la trampa 9 del HANDOFF: sin él, en un
/// simulador limpio el scrim se come los toques al tablero.
final class BoardGestureUITests: XCTestCase {
    @MainActor
    func testDoubleTapMergesANearbyPair() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        // Sembrar el par pasa por FisuJobs desde que el botón de spawn murió:
        // tab → fila del Fisura → cerrar. El fixture `--uitest-coins` paga.
        app.buttons["hud.hire"].tap()
        let hire = app.buttons["jobs.hire.homeless"]
        XCTAssertTrue(hire.waitForExistence(timeout: 10), "FisuJobs no ofrece contratar al Fisura")
        hire.tap()
        app.buttons["sheet.close"].tap()
        XCTAssertTrue(waitFor(units, value: "2", timeout: 8),
                      "contratar tiene que dejar el par que se va a fusionar")

        // Se barre en X porque los dos deambulan y no hay recorte publicado que
        // diga dónde quedaron. Un doble toque que cae en el vacío no hace NADA
        // —no hay nodo ahí—, así que reintentar no puede hacer pasar el test por
        // la razón equivocada: la única forma de que `board.units` baje a 1 es
        // que una fusión haya ocurrido, y con dos toques no se arrastra nada.
        for x in [0.13, 0.20, 0.27, 0.34, 0.10, 0.24] {
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.77)).doubleTap()
            if waitFor(units, value: "1", timeout: 2) { return }
        }
        XCTFail("el doble toque no fusionó el par; board.units quedó en \(units.value ?? "?")")
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, value: String, timeout: TimeInterval) -> Bool {
        let reached = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value), object: element
        )
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
    }
}
