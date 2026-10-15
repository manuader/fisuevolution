import XCTest

/// E14b B18: cada caja pertenece a un piso y trae a alguien de ese piso. Cae una caja del urbano:
/// en el callejón no se ve; se sube con el ascensor y está; se abre y llega el personaje del urbano.
/// Dónde está la caja del piso que se mira lo dice el marcador `board.package` ("x,y", o vacío).
@MainActor
final class PackageFloorsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func ride(_ app: XCUIApplication, to floorId: String) {
        app.buttons["hud.map"].press(forDuration: 0.9)
        let button = app.buttons["hud.elevator.keypad.floor.\(floorId)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3), "no se desplegó la placa")
        snap(app, "B18: la placa con la marca de la caja en \(floorId)")
        button.tap()
        let arrived = NSPredicate(format: "value == %@", floorId)
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: arrived, object: app.otherElements["board.floor"])],
                                        timeout: 6), .completed, "no llegó a \(floorId)")
    }

    func testUnaCajaDeOtroPisoSeVeYSeAbreEnSuPiso() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower",
                               "--uitest-package-floor=urban"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let floor = app.otherElements["board.floor"]
        XCTAssertTrue(floor.waitForExistence(timeout: 5))
        XCTAssertEqual(floor.value as? String, "alley")

        // En el callejón no hay ninguna caja: la del urbano se queda en su piso.
        let marker = app.otherElements["board.package"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        XCTAssertFalse((marker.value as? String ?? "").contains(","), "la caja del urbano no se ve en el callejón")
        snap(app, "B18: callejón sin la caja del urbano")

        // Se sube con el ascensor: ahí está.
        ride(app, to: "urban")
        expectation(for: NSPredicate(format: "value CONTAINS ','"), evaluatedWith: marker)
        waitForExpectations(timeout: 8)
        snap(app, "B18: la caja en el urbano")
        let before = Int(units.value as? String ?? "") ?? 0

        // Se abre: la primera vez con la pantalla, que ya dice a quién trae y a qué piso llega.
        let parts = (marker.value as? String ?? "").split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 2, "el marcador trae x,y")
        app.coordinate(withNormalizedOffset: CGVector(dx: parts[0], dy: parts[1])).tap()
        let inside = app.descendants(matching: .any)["package.inside"]
        XCTAssertTrue(inside.waitForExistence(timeout: 5), "la pantalla muestra a quién trae la caja")
        XCTAssertEqual(inside.value as? String, "urban", "trae a alguien del urbano")
        snap(app, "B18: adentro viene alguien del urbano")
        app.buttons["package.open"].tap()
        let box = app.buttons["package.tap"]
        XCTAssertTrue(box.waitForExistence(timeout: 8))
        for _ in 0..<3 where box.exists { box.tap() }
        let collect = app.buttons["package.collect"]
        XCTAssertTrue(collect.waitForExistence(timeout: 8))
        collect.tap()
        XCTAssertTrue(collect.waitForNonExistence(timeout: 5))

        expectation(for: NSPredicate(format: "value == %@", String(before + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(floor.value as? String, "urban", "el que llegó es del urbano y llega ahí")
        snap(app, "B18: llegó el del urbano")
    }

    /// Las cajas quietas del piso que se mira, del marcador `board.packages` ("x,y;x,y;…").
    private func spots(_ marker: XCUIElement) -> [CGPoint] {
        (marker.value as? String ?? "").split(separator: ";").compactMap { pair in
            let parts = pair.split(separator: ",").compactMap { Double($0) }
            return parts.count == 2 ? CGPoint(x: parts[0], y: parts[1]) : nil
        }
    }

    private func waitForThreeBoxes(_ marker: XCUIElement) {
        expectation(for: NSPredicate(format: "value MATCHES %@", "^[^;]+;[^;]+;[^;]+$"), evaluatedWith: marker)
        waitForExpectations(timeout: 10)
    }

    /// E14b B22: caen tres cajas en el callejón y quedan separadas; se va al urbano, se vuelve, y
    /// están en el mismo lugar.
    func testTresCajasCaenSeparadasYSeQuedanEnSuLugar() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower",
                               "--uitest-package-floor=alley:3"]
        app.launch()

        XCTAssertTrue(app.otherElements["board.units"].waitForExistence(timeout: 15))
        let floor = app.otherElements["board.floor"]
        XCTAssertTrue(floor.waitForExistence(timeout: 5))
        XCTAssertEqual(floor.value as? String, "alley")
        let marker = app.otherElements["board.packages"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        waitForThreeBoxes(marker)
        let before = spots(marker)
        XCTAssertEqual(before.count, 3)
        snap(app, "B22: tres cajas en el callejón, separadas")

        // Separadas: entre dos centros hay por lo menos media caja (la separación de fondo).
        let screen = app.windows.firstMatch.frame.size
        for (index, a) in before.enumerated() {
            for b in before.dropFirst(index + 1) {
                let distance = hypot((a.x - b.x) * screen.width, (a.y - b.y) * screen.height)
                XCTAssertGreaterThan(distance, 30, "dos cajas encimadas: \(a) y \(b)")
            }
        }

        ride(app, to: "urban")
        expectation(for: NSPredicate(format: "NOT (value CONTAINS ',')"), evaluatedWith: marker)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(spots(marker).isEmpty, "las del callejón no viajan al urbano")
        ride(app, to: "alley")
        waitForThreeBoxes(marker)
        let after = spots(marker)
        snap(app, "B22: de vuelta en el callejón, las tres en el mismo lugar")
        XCTAssertEqual(after.count, before.count)
        for (old, new) in zip(before, after) {
            XCTAssertEqual(old.x, new.x, accuracy: 0.002, "la caja se movió")
            XCTAssertEqual(old.y, new.y, accuracy: 0.002, "la caja se movió")
        }
    }
}
