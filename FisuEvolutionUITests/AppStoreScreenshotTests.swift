import XCTest

/// **Las capturas de la App Store**, generadas y no sacadas a mano.
///
/// No es un test: no afirma nada sobre el juego. Es un GENERADOR que vive en la
/// suite de UI porque necesita lo único que da XCUITest — **tocar la pantalla**.
/// Las hojas que venden el juego (FisuJobs, Pintas, Regalos, la Tienda) se
/// abren con un toque en la barra inferior, y `simctl` no sabe tocar: puede
/// lanzar la app con fixtures y fotografiar lo que quedó, nada más. Intentado
/// primero, y el resultado fue un tablero casi vacío y ninguna hoja.
///
/// ## Cómo se corre
///
/// ```bash
/// Tools/v2/capturas.sh [--device "iPhone 17 Pro Max"] [--lang en|es]
/// ```
///
/// `capturas.sh` crea el simulador, corre este generador por idioma, saca los
/// adjuntos del `.xcresult` a `build/capturas/2.0/<device>/<lang>/NN-nombre.png`
/// y valida el tamaño de cada PNG contra el slot de App Store Connect
/// (1320 × 2868, 1206 × 2622 y 2064 × 2752).
///
/// El guion de la 2.0 son ocho capturas, repartidas en cuatro corridas por
/// idioma porque cada una pide fixtures que las otras taparían:
/// `01-tablero`, `02-tienda-blue`, `03-ruleta`, `05-ascensor`, `06-ranking`
/// (una sola partida, navegando el menú deslizable), `04-visitante`,
/// `07-personajes` y `08-cofre`.
///
/// ⚠️ **`--screenshot-mode` es obligatorio.** Apaga el contador de FPS del
/// `SpriteView` y el botón de herramientas, que son `#if DEBUG` y saldrían en
/// la foto. No usa Release porque Release también se lleva puestos los
/// fixtures `--uitest-*`, que son los que ponen en pantalla en un segundo lo
/// que jugando cuesta horas.
///
/// ⚠️ **El runner corre la app en INGLÉS** aunque el idioma de desarrollo sea
/// `es` (trampa 6 del HANDOFF). Por eso las capturas se sacan DOS VECES, con
/// `-AppleLanguages` forzado en cada corrida: la ficha tiene dos locales
/// (en-US primaria y es-MX) y App Store Connect acepta un set de capturas por
/// locale. Sin forzar, las dos tandas saldrían idénticas y en inglés.
final class AppStoreScreenshotTests: XCTestCase {

    /// Los dos idiomas de la ficha.
    ///
    /// `-AppleLanguages` va como **launch argument** y no como variable de
    /// entorno: así lo lee `Foundation` al arrancar el proceso de la app, que
    /// es antes de que corra una línea nuestra.
    private static func languageArguments(_ code: String) -> [String] {
        ["-AppleLanguages", "(\(code))", "-AppleLocale", code]
    }

    /// Los fixtures comunes: la partida "con la que uno se quiere sacar la foto".
    private static let baseArguments = [
        "--screenshot-mode", "--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins",
    ]

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    // MARK: - Una partida, cinco capturas

    @MainActor
    func testCapturaElRecorridoEnIngles() throws { try capturaElRecorrido(idioma: "en") }

    @MainActor
    func testCapturaElRecorridoEnCastellano() throws { try capturaElRecorrido(idioma: "es") }

    /// 01 tablero · 02 tienda de blue · 03 ruleta · 06 ranking · 05 ascensor.
    ///
    /// Una sola partida: la torre entera abierta, los tipos vistos y las pintas
    /// (las pantallas listan lo VISTO), los dos niveles de lugares extra con el
    /// piso lleno (15 lugares), blue para la tienda, un giro regalado y el
    /// servidor simulado del ranking. Todo se alcanza por la barra y el menú
    /// deslizable, y se espera un marcador de ADENTRO de cada pantalla.
    @MainActor
    private func capturaElRecorrido(idioma: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + Self.baseArguments + [
            "--uitest-unlock-tower", "--uitest-seen-types", "--uitest-skins",
            "--uitest-merge-all", "--uitest-extra-slots", "--uitest-blue=500", "--uitest-wheel-spins=1",
            "--uitest-ranking-outside-top",
        ]
        app.launch()
        guard app.buttons["hud.hire"].waitForExistence(timeout: 30) else {
            return XCTFail("la barra inferior nunca apareció: sin ella no hay captura que sacar")
        }

        // 01. El tablero es la primera impresión del juego. Los personajes entran de a
        // uno (spawn progresivo): se espera a que el piso termine de llenarse.
        settle(seconds: 8)
        shoot(app, "01-tablero")

        // 02. Mejoras, del lado del blue (la Tienda muestra el precio de StoreKit, que
        // en el simulador sin catálogo dice "no disponible").
        if open(app, tab: "hud.upgrades", marker: "upgrades.tab.boosts") {
            app.buttons["upgrades.tab.boosts"].tap()
            if app.descendants(matching: .any)["blueShop.balance"].waitForExistence(timeout: 15) {
                settle()
                shoot(app, "02-tienda-blue")
            } else {
                XCTFail("Mejoras no mostró el saldo de blue")
            }
        }
        closeSheet(app)

        // 03. La ruleta, con la tabla de premios a la vista, sin girar.
        if open(app, tab: "hud.bonus", marker: "gifts.wheel.open") {
            app.buttons["gifts.wheel.open"].tap()
            if app.descendants(matching: .any)["wheel.odds.coins_30"].waitForExistence(timeout: 15) {
                settle()
                shoot(app, "03-ruleta")
            } else {
                XCTFail("la ruleta no mostró su tabla")
            }
        }
        closeSheet(app)

        // 06. El Ranking, la tarjeta de Menú › Oficina central (E14b B26).
        if open(app, tab: "hud.settings", marker: "menu.card.ranking") {
            app.buttons["menu.card.ranking"].tap()
            if app.descendants(matching: .any)["ranking.row.pinned"].waitForExistence(timeout: 15) {
                settle()
                shoot(app, "06-ranking")
            } else {
                XCTFail("el Ranking no mostró la fila propia")
            }
        }
        closeSheet(app)

        // 05. La botonera del ascensor, desplegada con el toque largo.
        let map = app.buttons["hud.map"]
        if waitUntilHittable(map) {
            map.press(forDuration: 0.9)
            if app.otherElements["hud.elevator.keypad"].waitForExistence(timeout: 5) {
                settle()
                shoot(app, "05-ascensor")
            } else {
                XCTFail("mantener apretado el ascensor no desplegó la botonera")
            }
        } else {
            XCTFail("el ícono del ascensor nunca quedó tocable")
        }
    }

    // MARK: - El visitante

    @MainActor
    func testCapturaElVisitanteEnIngles() throws { try capturaElVisitante(idioma: "en") }

    @MainActor
    func testCapturaElVisitanteEnCastellano() throws { try capturaElVisitante(idioma: "es") }

    /// 04. El visitante en el escenario, con su globo. Llega solo (cada 4-6 min
    /// de juego) y `--uitest-visitor=` lo adelanta; se fotografía con el chip
    /// puesto y sin abrir el trato.
    @MainActor
    private func capturaElVisitante(idioma: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + Self.baseArguments + [
            "--uitest-unlock-tower", "--uitest-seen-types", "--uitest-merge-all", "--uitest-extra-slots",
            "--uitest-visitor=turista_propina",
        ]
        app.launch()
        let onStage = app.buttons["stage.chip.visitor"]
        let elsewhere = app.buttons["stage.chip.waiting"]
        // Desde B7 el visitante se queda en el piso donde entró: si la cámara todavía bajaba al
        // callejón cuando llegó, espera en otro piso y el aviso lleva hasta él (abre su trato).
        let deadline = Date().addingTimeInterval(40)
        while !onStage.exists, !elsewhere.exists, Date() < deadline {
            _ = onStage.waitForExistence(timeout: 2)
        }
        if !onStage.exists, elsewhere.exists {
            elsewhere.tap()
            let close = app.buttons["sheet.close"]
            if close.waitForExistence(timeout: 8) { close.tap() }
        }
        guard onStage.waitForExistence(timeout: 10) else {
            return XCTFail("el visitante nunca llegó al escenario")
        }
        settle(seconds: 8)
        shoot(app, "04-visitante")
    }

    // MARK: - Los personajes

    @MainActor
    func testCapturaLosPersonajesEnIngles() throws { try capturaLosPersonajes(idioma: "en") }

    @MainActor
    func testCapturaLosPersonajesEnCastellano() throws { try capturaLosPersonajes(idioma: "es") }

    /// 07. La ficha de un personaje, abierta por `--uitest-open-sheet`: el
    /// toque largo sobre SpriteKit no es determinista en el runner.
    @MainActor
    private func capturaLosPersonajes(idioma: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + Self.baseArguments + [
            "--uitest-unlock-tower", "--uitest-seen-types", "--uitest-skins", "--uitest-open-sheet",
        ]
        app.launch()
        guard app.descendants(matching: .any)["character.portrait"].waitForExistence(timeout: 30) else {
            return XCTFail("la ficha no mostró su retrato")
        }
        settle()
        shoot(app, "07-personajes")
    }

    // MARK: - El cofre

    @MainActor
    func testCapturaElCofreEnIngles() throws { try capturaElCofre(idioma: "en") }

    @MainActor
    func testCapturaElCofreEnCastellano() throws { try capturaElCofre(idioma: "es") }

    /// 08. La CARTA del premio, no el estallido: la animación son 4 s y agarrarla
    /// a mitad da un fotograma oscuro lleno de destellos.
    @MainActor
    private func capturaElCofre(idioma: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + Self.baseArguments + ["--uitest-chest"]
        app.launch()

        // Los tres toques que abren el cofre (el mismo escenario que ejerce `ChestOpeningUITests`).
        let stage = app.otherElements["chest.stage"]
        if stage.waitForExistence(timeout: 30) {
            for _ in 0..<3 where stage.isHittable {
                stage.tap()
                usleep(900_000)
            }
        }
        guard app.descendants(matching: .any)["chest.card"].waitForExistence(timeout: 20) else {
            return XCTFail("el cofre no llegó a la carta del premio")
        }
        // El premio se asienta al final del video (~4 s) más el resorte de la carta.
        Thread.sleep(forTimeInterval: 3)
        shoot(app, "08-cofre")
    }

    // MARK: - Navegación

    /// Abre una pestaña de la barra y espera un identifier de ADENTRO de la
    /// pantalla (no `sheet.close`: con la X sólo se sabe que se abrió *algo*, y
    /// una foto de la hoja equivocada se descubre mirando el PNG).
    @MainActor
    private func open(_ app: XCUIApplication, tab identifier: String, marker: String) -> Bool {
        let tab = app.buttons[identifier]
        guard tab.waitForExistence(timeout: 15), waitUntilHittable(tab) else {
            XCTFail("el tab \(identifier) nunca quedó tocable")
            return false
        }
        tab.tap()
        guard app.descendants(matching: .any)[marker].waitForExistence(timeout: 15) else {
            XCTFail("\(identifier) no mostró \(marker)")
            return false
        }
        return true
    }

    /// Cierra la hoja del menú y espera a que la barra vuelva: la saliente sigue
    /// en el árbol de AX mientras se desliza, y el toque siguiente caería sobre
    /// el contenido en vuelo (trampa 4 de la suite).
    @MainActor
    private func closeSheet(_ app: XCUIApplication) {
        let close = app.buttons["sheet.close"]
        if close.exists, waitUntilHittable(close) { close.tap() }
        _ = close.waitForNonExistence(timeout: 10)
        XCTAssertTrue(waitUntilHittable(app.buttons["hud.hire"]), "la barra no volvió después de cerrar la hoja")
    }

    // MARK: - Utilidades

    /// Deja que terminen las animaciones de entrada antes de disparar. Sin
    /// esto, las hojas salen a mitad de su transición y las tarjetas con
    /// stagger aparecen a medio entrar.
    private func settle(seconds: TimeInterval = 1.6) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Guarda la captura como attachment del resultado (`captura-NN-nombre`; el
    /// dispositivo y el idioma los pone `capturas.sh` por carpeta).
    ///
    /// `XCUIScreen.main.screenshot()` y no `app.screenshot()`: el primero toma
    /// la PANTALLA entera al tamaño nativo del device, que es lo que App Store
    /// valida. El segundo recorta al frame de la app y, con hojas presentadas,
    /// puede devolver un tamaño que no es el del simulador.
    @MainActor
    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "captura-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable { return true }
            usleep(200_000)
        }
        return false
    }
}
