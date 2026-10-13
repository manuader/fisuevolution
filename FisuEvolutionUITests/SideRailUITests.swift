import XCTest

/// Los sellos de premios (PLAN-v2 E14 C9): una columna siempre a la vista bajo
/// el HUD, pegada al borde izquierdo, con la cinta de estado de cada uno. Los
/// que no están disponibles no se dibujan. El anuncio lo pone el stub (2 s, y
/// paga).
final class SideRailUITests: XCTestCase {
    private let seals = ["siderail.wheel", "siderail.mattress", "siderail.packages", "siderail.boost"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLosSellosEstanSiempreALaVistaBajoElHUDYPegadosALaIzquierda() {
        let app = launch(extra: ["--uitest-packages=1", "--uitest-mattress"])
        let packages = app.buttons["siderail.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["siderail.toggle"].exists, "ya no hay botón «Premios» que despliegue nada")
        let top = app.otherElements["hud.coins"].frame.maxY
        var previousBottom = top
        for id in seals where app.buttons[id].exists {
            let seal = app.buttons[id]
            XCTAssertGreaterThanOrEqual(seal.frame.minY, top, "\(id) pisa el HUD")
            XCTAssertGreaterThanOrEqual(seal.frame.minY, previousBottom - 1, "\(id) pisa al sello de arriba")
            XCTAssertLessThanOrEqual(seal.frame.maxX, 80, "\(id) se sale de su esquina")
            XCTAssertGreaterThanOrEqual(seal.frame.width, 60, "\(id): objetivo de toque chico")
            XCTAssertGreaterThanOrEqual(seal.frame.height, 60, "\(id): objetivo de toque chico")
            previousBottom = seal.frame.maxY
        }
        XCTAssertLessThanOrEqual(previousBottom, app.buttons["hud.hire"].frame.minY, "los sellos pisan la barra de abajo")
        XCTAssertEqual(app.buttons["siderail.mattress"].value as? String, "ready")
        attach(app, named: "E14 T13 sellos de premios")
    }

    @MainActor
    func testTocarUnSelloAbreLoSuyo() {
        let app = launch(extra: ["--uitest-packages=1"])
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let before = Int(units.value as? String ?? "") ?? 0
        let packages = app.buttons["siderail.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 3))
        XCTAssertEqual(packages.value as? String, "ready:1")
        packages.tap()
        expectation(for: NSPredicate(format: "value == %@", String(before + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 10)
    }

    @MainActor
    func testLosPaquetesSinNadaOfrecenLaLluvia() {
        let app = launch()
        let packages = app.buttons["siderail.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 15))
        packages.tap()
        let video = app.buttons["siderail.offer.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 5), "sin paquetes, Paquetes ofrece la lluvia por video")
        XCTAssertGreaterThan(video.frame.minX, packages.frame.maxX - 1, "la tarjeta sale al lado de los sellos, sin taparlos")
        attach(app, named: "E7b tarjeta de la lluvia")
        app.buttons["siderail.offer.close"].tap()
        XCTAssertTrue(video.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testTocarElTableroCierraLaTarjeta() {
        let app = launch()
        XCTAssertTrue(app.buttons["siderail.packages"].waitForExistence(timeout: 15))
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
        XCTAssertTrue(boost.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "waiting"), evaluatedWith: boost)
        waitForExpectations(timeout: 5)
    }

    /// D14, en el peor caso: sellos a la izquierda y, a la derecha, el especial,
    /// la oferta, un evento y un boost a la vez. Ningún elemento pisa a otro y
    /// todos viven entre el HUD y la barra de abajo.
    @MainActor
    func testLasDosEsquinasNoSePisanEnElPeorCaso() throws {
        let app = launch(extra: ["--uitest-packages=1", "--uitest-mattress", "--uitest-visitor=turista_propina",
                                 "--uitest-offer=renacer", "--uitest-event=devaluacion"])
        let special = app.buttons["stage.chip.visitor"]
        let offer = app.buttons["hud.offer.chip"]
        let event = app.buttons["hud.event.chip.devaluacion"]
        XCTAssertTrue(app.buttons["siderail.packages"].waitForExistence(timeout: 15))
        // Las hojas y el anuncio del evento van llegando: se cierran hasta ver las tres cosas.
        for _ in 0..<12 where !(special.exists && offer.exists && event.exists) {
            let close = app.buttons["sheet.close"].firstMatch
            if close.waitForExistence(timeout: 3) { close.tap() }
        }
        XCTAssertTrue(special.waitForExistence(timeout: 40), "falta la tarjeta del especial")
        XCTAssertTrue(offer.waitForExistence(timeout: 5), "falta el sello de la oferta")
        XCTAssertTrue(event.waitForExistence(timeout: 5), "falta el reloj del evento")
        attach(app, named: "E14 T13 las dos esquinas")

        let screen = app.windows.firstMatch.frame
        let top = app.otherElements["hud.coins"].frame.maxY
        let bottom = app.buttons["hud.hire"].frame.minY
        let right = [special, offer, event]
        let left = seals.map { app.buttons[$0] }.filter(\.exists)
        XCTAssertFalse(left.isEmpty)
        for element in left + right {
            XCTAssertGreaterThanOrEqual(element.frame.minY, top, "\(element.identifier) pisa el HUD")
            XCTAssertLessThanOrEqual(element.frame.maxY, bottom, "\(element.identifier) pisa la barra")
            XCTAssertTrue(screen.contains(element.frame), "\(element.identifier) se sale de la pantalla")
        }
        let all = left + right
        for (index, one) in all.enumerated() {
            for other in all[(index + 1)...] {
                XCTAssertFalse(one.frame.intersects(other.frame), "\(one.identifier) pisa a \(other.identifier)")
            }
        }
        XCTAssertLessThan(special.frame.minY, offer.frame.minY, "el especial va primero")
        XCTAssertLessThan(offer.frame.minY, event.frame.minY, "la oferta va antes que los eventos")
        XCTAssertGreaterThanOrEqual(special.frame.minX, screen.midX, "el especial va a la derecha")
    }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extra
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
