import XCTest

/// La columna plegable (PLAN-v2 §2; opción C del dueño): en reposo un solo botón
/// "Premios" abajo a la izquierda; al tocarlo despliega los cuatro, que se
/// recogen solos a los 3 s o al tocar uno. El anuncio lo pone el stub (2 s, y
/// paga).
final class SideRailUITests: XCTestCase {
    private let buttons = ["siderail.wheel", "siderail.mattress", "siderail.packages", "siderail.boost"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEnReposoUnSoloBotonQueDespliegaLosCuatro() {
        // La persiana se queda abierta mientras se miden los cuatro: consultar
        // cada marco cuesta más que los 3 s con que se recoge sola.
        let app = launch()
        let toggle = app.buttons["siderail.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        for id in buttons {
            XCTAssertFalse(app.buttons[id].exists, "\(id) a la vista con la columna plegada")
        }
        XCTAssertLessThanOrEqual(toggle.frame.maxY, app.buttons["hud.quickhire"].frame.minY, "«Premios» pisa el atajo")
        XCTAssertLessThanOrEqual(toggle.frame.maxX, 60, "«Premios» se sale de su esquina")
        attach(app, named: "E7b columna plegada")

        toggle.tap()
        let top = app.otherElements["hud.coins"].frame.maxY
        for id in buttons {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 3), "\(id) no se desplegó")
            XCTAssertGreaterThanOrEqual(button.frame.minY, top, "\(id) pisa el HUD")
            XCTAssertLessThanOrEqual(button.frame.maxY, toggle.frame.minY, "\(id) pisa «Premios»")
            XCTAssertLessThanOrEqual(button.frame.maxX, 110, "\(id) se sale de la persiana")
        }
        attach(app, named: "E7b columna desplegada")
        toggle.tap()
        XCTAssertTrue(app.buttons["siderail.wheel"].waitForNonExistence(timeout: 3), "tocar «Premios» abierto no la recogió")
    }

    @MainActor
    func testLaPersianaSeRecogeSolaALos3Segundos() {
        let app = launch(hold: false)
        let toggle = app.buttons["siderail.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        XCTAssertTrue(app.buttons["siderail.wheel"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["siderail.wheel"].waitForNonExistence(timeout: 6), "la persiana no se recogió a los 3 s")
    }

    @MainActor
    func testTocarUnoAbreLoSuyoYRecogeLaPersiana() {
        let app = launch(extra: ["--uitest-packages=1"])
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let before = Int(units.value as? String ?? "") ?? 0
        let toggle = app.buttons["siderail.toggle"]
        XCTAssertGreaterThanOrEqual(Int(toggle.value as? String ?? "") ?? 0, 1, "el «!» suma el paquete")
        toggle.tap()
        let packages = app.buttons["siderail.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 3))
        XCTAssertEqual(packages.value as? String, "ready:1")
        packages.tap()
        XCTAssertTrue(packages.waitForNonExistence(timeout: 2), "tocar uno recoge la persiana")
        expectation(for: NSPredicate(format: "value == %@", String(before + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 10)
    }

    @MainActor
    func testLosPaquetesSinNadaOfrecenLaLluvia() {
        let app = launch()
        let toggle = app.buttons["siderail.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        let packages = app.buttons["siderail.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 3))
        packages.tap()
        let video = app.buttons["siderail.offer.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 5), "sin paquetes, Paquetes ofrece la lluvia por video")
        XCTAssertFalse(packages.exists, "la tarjeta sale al lado de «Premios», con la persiana recogida")
        attach(app, named: "E7b tarjeta de la lluvia")
        app.buttons["siderail.offer.close"].tap()
        XCTAssertTrue(video.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testTocarElTableroCierraLaTarjeta() {
        let app = launch()
        let toggle = app.buttons["siderail.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        app.buttons["siderail.packages"].tap()
        let video = app.buttons["siderail.offer.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)).tap()
        XCTAssertTrue(video.waitForNonExistence(timeout: 3), "tocar el tablero no cerró la tarjeta")
    }

    @MainActor
    func testFusionarTodoPorVideo() {
        let app = launch(extra: ["--uitest-coins"])
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let start = Int(units.value as? String ?? "") ?? 0
        let quickHire = app.buttons["hud.quickhire"]
        quickHire.tap()
        quickHire.tap()
        expectation(for: NSPredicate(format: "value == %@", String(start + 2)), evaluatedWith: units)
        waitForExpectations(timeout: 10)

        app.buttons["siderail.toggle"].tap()
        let boost = app.buttons["siderail.boost"]
        XCTAssertTrue(boost.waitForExistence(timeout: 3))
        XCTAssertEqual(boost.value as? String, "ready")
        boost.tap()
        let video = app.buttons["siderail.offer.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        attach(app, named: "E7b tarjeta de Fusionar todo")
        video.tap()

        expectation(for: NSPredicate(format: "value == %@", String(start + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 20)
        // El aviso de la cadena puede apagar la UI un instante y plegar la persiana: se reintenta.
        for _ in 0..<4 where !boost.exists {
            app.buttons["siderail.toggle"].tap()
            _ = boost.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(boost.exists)
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "waiting"), evaluatedWith: boost)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func launch(extra: [String] = [], hold: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        // Con `hold` la persiana no se recoge sola: consultar cada botón lleva más que 3 s.
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + (hold ? ["--uitest-rail-hold"] : []) + extra
        app.launch()
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
