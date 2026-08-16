import XCTest

/// El loop de F1 con la barra inferior puesta: tocar al Fisura gana monedas y
/// contratar ya no es un botón sino una PANTALLA — se abre FisuJobs desde el
/// tab `hud.hire`, se toca la fila del tipo y el tablero suma una unidad.
///
/// ⚠️ `--uitest-skip-tutorial` arregla la trampa 9 del HANDOFF: sin él, en un
/// simulador limpio el scrim del tutorial se come los toques al tablero y el
/// test falla con "coins never changed after tapping" — que es exactamente lo
/// que pasaba en `main` antes de rehacer el tutorial, medido.
///
/// ⚠️ Los dos tests lanzan la app aparte a propósito. El de contratar necesita
/// `--uitest-coins`, y el del tap NO puede tenerlo: el fixture acredita 1M, que
/// `CoinFormatter` abrevia a "1M", y un tap de +1 no mueve ese texto ni un
/// carácter. El assert pasaría a ser sobre un valor que no puede cambiar.
final class EconomyLoopUITests: XCTestCase {
    @MainActor
    func testTappingEarnsCoins() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let coins = app.otherElements["hud.coins"]
        XCTAssertTrue(coins.waitForExistence(timeout: 15))
        let before = coins.value as? String

        // El Fisura arranca en la celda 0 (abajo-izquierda del board).
        let boardTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.13, dy: 0.77))
        for _ in 0..<20 {
            boardTap.tap()
        }

        // Al menos un tap tiene que haber pegado en el nodo y sumado monedas.
        let predicate = NSPredicate { _, _ in (coins.value as? String) != before }
        let changed = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 5), .completed, "coins never changed after tapping")
    }

    /// La cadena que reemplaza al botón de spawn: tab → pantalla → contratar →
    /// cerrar, con el tablero como testigo. `board.units` es la única prueba de
    /// que la compra llegó a la escena y no se quedó en el modelo.
    @MainActor
    func testHiringFromFisuJobsAddsAUnitToTheBoard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        XCTAssertEqual(units.value as? String, "1", "una partida nueva arranca con el Fisura solo")

        let jobs = app.buttons["hud.hire"]
        XCTAssertTrue(jobs.waitForExistence(timeout: 10), "el tab de FisuJobs no está en la barra")
        jobs.tap()

        let hire = app.buttons["jobs.hire.homeless"]
        XCTAssertTrue(hire.waitForExistence(timeout: 10), "FisuJobs no ofrece contratar al Fisura")

        // La captura va ANTES de los asserts (trampa 9a-bis): un assert que
        // corta se lleva puesta la evidencia, y lo que hace falta ver cuando
        // esto falla es si la pantalla está y el árbol de AX es el roto.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "FisuJobs con la fila del Fisura"
        shot.lifetime = .keepAlways
        add(shot)

        hire.tap()
        app.buttons["sheet.close"].tap()

        let grew = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "2"), object: units
        )
        XCTAssertEqual(XCTWaiter().wait(for: [grew], timeout: 8), .completed,
                       "contratar en FisuJobs tiene que poner la unidad en el tablero, quedó en \(units.value ?? "?")")
    }
}
