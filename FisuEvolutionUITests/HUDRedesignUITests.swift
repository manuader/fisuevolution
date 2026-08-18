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

    /// **Pin de regresión: la barra de estado NO se dibuja.** (Pedido nº1 del
    /// dueño: el juego es a pantalla completa y el reloj caía ENCIMA del panel
    /// del HUD, a un par de puntos del contador de plata.)
    ///
    /// Existe porque ese pedido lo sostenía **una sola línea sin ninguna red**:
    /// `RootView.statusBarHidden(true)`. Y al lado, en `project.yml`, vive
    /// `INFOPLIST_KEY_UIStatusBarHidden: YES`, que **no oculta nada** —hace falta
    /// `UIViewControllerBasedStatusBarAppearance: NO`, y esa clave Xcode no la
    /// traduce desde `INFOPLIST_KEY_*`—. O sea que el archivo que *parece* estar
    /// a cargo es un señuelo: si alguien borra el modificador de `RootView`
    /// "porque ya está en el plist", el reloj vuelve y nadie se entera.
    ///
    /// La moraleja de esta rama es que **un pin que no se corre no avisa**, así
    /// que éste vive en `HUDRedesignUITests`, que entra en la suite completa y
    /// corre en las DOS clases de teléfono.
    ///
    /// ⚠️ **Cómo se mide, y por qué no de la forma obvia.** `app.statusBars` da
    /// **0 con la barra visible Y con la barra oculta** —medido con las dos
    /// versiones del modificador—: un assert sobre eso pasaría siempre, que es
    /// la trampa 2 (un test de UI que pasa sin probar nada). La barra la dibuja
    /// SpringBoard, no la app, así que lo que se mira es su árbol. Medido en 16
    /// Pro con `.statusBarHidden(false)`, sus elementos son
    /// `[8:06 AM]`, `[Cellular]`, `[3 of 3 Wi-Fi bars]`, `[100 % battery power]`;
    /// con `true`, la misma barra queda **sin un solo descendiente**.
    ///
    /// Se asserta el CONTEO en cero y no esos labels: son del sistema, cambian
    /// con el idioma del runner (trampa 6), con la hora y con el modelo —el SE
    /// no tiene los mismos indicadores que el 16 Pro—. El conteo es lo único
    /// que significa lo mismo en las dos clases.
    ///
    /// ⚠️ El `descendants(matching: .any)` que la casa prohíbe es el que barre
    /// la app ENTERA en un bucle cerrado (ver `BottomMenuUITests`). Éste corre
    /// **una vez** y sobre el subárbol de una barra de estado, que son cuatro
    /// elementos cuando está visible y cero cuando no.
    @MainActor
    func testLaBarraDeEstadoSigueOculta() throws {
        let app = launch()
        // Con la app ADELANTE: la barra de estado refleja al foreground.
        XCTAssertTrue(app.buttons["hud.coins.plus"].waitForExistence(timeout: 20),
                      "el HUD nunca apareció: sin la app adelante esto no mide nada")
        attach(app, named: "T-status barra de estado oculta")

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let bars = springboard.statusBars
        XCTAssertGreaterThan(bars.count, 0,
                             "SpringBoard dejó de publicar la barra de estado: el mecanismo del pin cambió y hay que re-medirlo")

        var items: [String] = []
        for index in 0..<bars.count {
            for element in bars.element(boundBy: index).descendants(matching: .any).allElementsBoundByIndex {
                items.append("[\(element.identifier)|\(element.label)]")
            }
        }
        XCTAssertTrue(items.isEmpty, """
                      la barra de estado volvió a dibujarse (\(items.count) elementos: \(items.joined(separator: " "))). \
                      Quien manda es `RootView.statusBarHidden(true)`, NO el `INFOPLIST_KEY_UIStatusBarHidden` de project.yml.
                      """)
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

        // La fila de torre se RETIRÓ (decisión del dueño 2026-08-18): el piso
        // se cambia scrolleando el tablero o por el ascensor. Verla volver es
        // una regresión, no una feature.
        XCTAssertFalse(app.otherElements["tower.pill"].exists, "la píldora de piso volvió: se retiró el 2026-08-18")
        XCTAssertFalse(app.buttons["tower.arrow.up"].exists, "la flecha de subir volvió: se retiró con la píldora")
        XCTAssertFalse(app.buttons["tower.arrow.down"].exists, "la flecha de bajar volvió: se retiró con la píldora")
        XCTAssertTrue(app.otherElements["hud.coins"].exists, "el contador de monedas se perdió al entrar a la barra")
        XCTAssertTrue(app.buttons["hud.map"].exists, "el ascensor tiene que seguir siendo el acceso al mapa")
    }
}
