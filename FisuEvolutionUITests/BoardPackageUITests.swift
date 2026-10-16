import XCTest

/// La caja del tablero (E14b B5, D2): la primera vez abre la pantalla del paquete; desde la segunda,
/// un toque la abre ahí mismo y el empleado llega sin pop-up. Dónde tocar la caja lo dice el marcador
/// `board.package` ("x,y" normalizado a la pantalla): su centro o, si un empleado de adelante la tapa
/// (cae en cualquier lugar del piso, B22, y el toque es de lo de adelante, B19), una parte que se ve.
@MainActor
final class BoardPackageUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Espera a que haya una caja a la vista y la toca donde se ve.
    private func tapTheBoardBox(_ app: XCUIApplication) {
        let marker = app.otherElements["board.package"]
        XCTAssertTrue(marker.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value CONTAINS ','"), evaluatedWith: marker)
        waitForExpectations(timeout: 10)
        let parts = (marker.value as? String ?? "").split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 2, "el marcador trae x,y")
        app.coordinate(withNormalizedOffset: CGVector(dx: parts[0], dy: parts[1])).tap()
    }

    func testTheSecondPackageOpensOnTheBoardWithoutPopup() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-packages=2"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let before = Int(units.value as? String ?? "") ?? 0

        // La primera: la pantalla de C28, como siempre.
        tapTheBoardBox(app)
        XCTAssertTrue(app.descendants(matching: .any)["package.inside"].waitForExistence(timeout: 5),
                      "la primera vez la caja del tablero abre la pantalla del paquete, con quién trae (B18)")
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

        // La segunda: un toque, se abre en el tablero y el empleado llega, sin pop-up.
        tapTheBoardBox(app)
        snap(app, "paquete en el tablero abriéndose")
        XCTAssertFalse(app.descendants(matching: .any)["package.inside"].waitForExistence(timeout: 2),
                       "desde la segunda no hay pop-up")
        expectation(for: NSPredicate(format: "value == %@", String(before + 2)), evaluatedWith: units)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.descendants(matching: .any)["package.result"].exists, "tampoco el de recompensa")
        snap(app, "paquete en el tablero abierto")
    }
}
