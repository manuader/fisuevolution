import XCTest

/// Rediseño §3: el HUD superior es **una** barra contigua — moneda+ · plata y
/// `X/s` · ascensor — con la fila de torre y el chip de reencarnación debajo.
///
/// Mira la PANTALLA, no el modelo: la trampa 2 del HANDOFF avisa que un test de
/// UI puede pasar sin probar nada, así que cada assert exige un elemento real y
/// tocable del árbol de accesibilidad.
///
/// ⚠️ Todo se asserta por accessibility identifier: el runner corre la app en
/// INGLÉS aunque el idioma de desarrollo sea `es` (trampa 6), así que un assert
/// sobre "Comprar monedas" pasaría por no encontrar nunca nada.
final class HUDRedesignUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()
        return app
    }

    /// La captura va SIEMPRE antes de los asserts: un assert que corta se lleva
    /// puesta la evidencia, y el bug de la trampa 9a-bis (identifiers pisados
    /// por un contenedor) sólo se vio mirando el attachment.
    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// El atajo de la izquierda de la barra abre la tienda: mismo destino que el
    /// carrito, pero puesto donde el jugador mira cuando le falta plata.
    @MainActor
    func testElAtajoDeMonedasAbreLaTienda() throws {
        let app = launch()

        let plus = app.buttons["hud.coins.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 20), "el atajo moneda+ nunca apareció en la barra")
        attach(app, named: "T6 barra superior contigua")

        plus.tap()

        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "tocar la moneda+ no abrió ninguna hoja")
        attach(app, named: "T6 la tienda abierta desde la moneda+")

        close.tap()
        XCTAssertTrue(plus.waitForExistence(timeout: 10), "la hoja no se cerró: el HUD no volvió a la vista")
    }

    /// El `X/s` se mudó de la píldora de la torre a la barra. Es un elemento de
    /// ESTADO —no un control—, así que se lee por `.value`; y la píldora tiene
    /// que seguir existiendo, con las flechas, en su propia fila.
    @MainActor
    func testLaBarraPublicaElIngresoYLaTorreConservaSuPildora() throws {
        let app = launch()

        let income = app.otherElements["hud.income"]
        XCTAssertTrue(income.waitForExistence(timeout: 20), "el contador de ingresos nunca apareció")
        attach(app, named: "T6 ingreso por segundo y fila de torre")

        let rate = income.value as? String ?? ""
        XCTAssertFalse(rate.isEmpty, "hud.income es un elemento de estado: tiene que publicar su value")
        // "/s" no se traduce, así que este assert no cae en la trampa 6.
        XCTAssertTrue(rate.hasSuffix("/s"), "el value tiene que leerse como una tasa, salió: \(rate)")

        XCTAssertTrue(app.otherElements["tower.pill"].exists, "la fila de torre perdió su píldora")
        XCTAssertTrue(app.buttons["tower.arrow.up"].exists, "la píldora perdió la flecha de subir")
        XCTAssertTrue(app.buttons["tower.arrow.down"].exists, "la píldora perdió la flecha de bajar")
        XCTAssertTrue(app.otherElements["hud.coins"].exists, "el contador de monedas se perdió al entrar a la barra")
        XCTAssertTrue(app.buttons["hud.map"].exists, "el ascensor tiene que seguir siendo el acceso al mapa")
    }
}
