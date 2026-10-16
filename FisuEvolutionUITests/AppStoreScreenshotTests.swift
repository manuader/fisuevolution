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
/// Un solo comando, con los simuladores propios que crea y borra el script
/// (no hay que armar destinos a mano):
///
/// ```bash
/// Tools/v2/capturas.sh                                   # todo: matriz completa + las 3 de revisión
/// Tools/v2/capturas.sh --device "iPhone 17 Pro Max" --lang en
/// Tools/v2/capturas.sh --sin-review                      # sólo la ficha
/// ```
///
/// Por dentro, cada idioma es este `xcodebuild` (el simulador lo pone el script por UDID):
///
/// ```bash
/// xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
///   -destination "id=<UDID>" -derivedDataPath build/DD-capturas.noindex -parallel-testing-enabled NO \
///   -resultBundlePath <x>.xcresult \
///   -only-testing:FisuEvolutionUITests/AppStoreScreenshotTests/testCapturaElRecorridoEnIngles \
///   -only-testing:FisuEvolutionUITests/AppStoreScreenshotTests/testCapturaElVisitanteEnIngles \
///   -only-testing:FisuEvolutionUITests/AppStoreScreenshotTests/testCapturaLaRecompensaEnIngles \
///   -only-testing:FisuEvolutionUITests/AppStoreScreenshotTests/testCapturaLaMarchaEnIngles \
///   -only-testing:FisuEvolutionUITests/AppStoreScreenshotTests/testCapturaLosPersonajesEnIngles \
///   -only-testing:FisuEvolutionUITests/AppStoreScreenshotTests/testCapturaElCofreEnIngles
/// # (…EnCastellano para es) y, una vez, en el iPhone 17 Pro Max:
/// #   -only-testing:FisuEvolutionUITests/AppStoreScreenshotTests/testCapturaLaOfertaBienvenida (y …Renacer, …Mudanza)
/// ```
///
/// Dónde quedan los PNG (`build/` no se versiona):
///
/// - la ficha: `build/capturas/2.0/<dispositivo>/<en|es>/NN-nombre.png`
/// - las de revisión de las ofertas: `build/capturas/2.0/review/offer_<id>.png`
///   (`offer_bienvenida`, `offer_renacer`, `offer_mudanza`, los `productId` de `release.json`;
///   se suben con `releaseops asc screenshot offer_<id> <png>`, 🔒 del dueño)
///
/// ## La matriz
///
/// | Destino | Slot de App Store Connect | Por qué |
/// |---|---|---|
/// | iPhone 17 Pro Max (6,9") | 1320 × 2868 | el slot que ASC pide para iPhone; los de 6,5", 6,3" y menores se escalan de él (el 6,5" sólo se exige si no hay de 6,9") |
/// | iPad Pro 13-inch (M5) | 2064 × 2752 | la 2.0 es universal: el iPad de 13" es el slot obligatorio de iPad |
/// | iPhone 17 Pro (6,3") | 1206 × 2622 | opcional: `--device "iPhone 17 Pro"` |
///
/// Cada uno en **es-MX** (`es`) y **en-US** (`en`), los dos locales de la ficha.
///
/// ## El guion (diez capturas por dispositivo e idioma)
///
/// `01-tablero` (la torre con 15 lugares, una caja de aduana y el colchón sobre el tablero),
/// `02-tienda` (la Tienda de la barra, con sus precios de StoreKit), `03-ruleta`, `04-visitante`
/// (en el medio del piso, con su globo), `05-ascensor`, `06-ranking` (Menú › Oficina central),
/// `07-personajes`, `08-cofre`, `09-recompensa` (el paso 2, «¿Lo duplicás?») y `10-marcha`
/// (La Marcha ganada: el Puntero festeja). Repartidas en una corrida por idioma porque cada una
/// pide fixtures que las otras taparían. `01`, `02`, `03`, `05` y `06` son una sola partida.
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

    /// 01 tablero · 02 tienda · 03 ruleta · 06 ranking · 05 ascensor.
    ///
    /// Una sola partida: la torre entera abierta, los tipos vistos y las pintas
    /// (las pantallas listan lo VISTO), los dos niveles de lugares extra con el
    /// piso lleno (15 lugares), una caja de aduana y el colchón sobre el tablero,
    /// un giro regalado y el servidor simulado del ranking. Todo se alcanza por la
    /// barra (Tienda, Regalos) y el Menú, y se espera un marcador de ADENTRO de
    /// cada pantalla.
    @MainActor
    private func capturaElRecorrido(idioma: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + Self.baseArguments + [
            "--uitest-unlock-tower", "--uitest-seen-types", "--uitest-skins",
            "--uitest-merge-all", "--uitest-extra-slots", "--uitest-wheel-spins=1",
            "--uitest-mattress-board", "--uitest-package-floor=alley",
            "--uitest-ranking-outside-top",
        ]
        app.launch()
        guard app.buttons["hud.hire"].waitForExistence(timeout: 30) else {
            return XCTFail("la barra inferior nunca apareció: sin ella no hay captura que sacar")
        }

        // 01. El tablero es la primera impresión del juego. Los personajes entran de a
        // uno (spawn progresivo): se espera a que el piso termine de llenarse.
        settle(seconds: 8)
        // La caja y el colchón se anuncian por marcadores: vacíos, no hay lugar libre y la foto
        // saldría sin ellos.
        XCTAssertFalse(markerValue(app, "board.package").isEmpty, "la caja de aduana no cayó sobre el tablero")
        XCTAssertFalse(markerValue(app, "board.mattress").isEmpty, "el colchón no cayó sobre el tablero")
        shoot(app, "01-tablero")

        // 02. La Tienda, tercera de la izquierda en la barra. Los precios son los del catálogo
        // local de StoreKit (el scheme lo carga); si aparece el cartel de «no disponible» la
        // foto saldría con precios rotos.
        if open(app, tab: "hud.store", marker: "store.buy.com.fisuevolution.iap.starter_pack") {
            XCTAssertFalse(app.descendants(matching: .any)["store.unavailable"].exists,
                           "la Tienda dice «no disponible»: sin precios de StoreKit no hay captura")
            settle()
            shoot(app, "02-tienda")
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
        guard visitorOnStage(app) else { return XCTFail("el visitante nunca llegó al escenario") }
        settle(seconds: 8)
        shoot(app, "04-visitante")
    }

    // MARK: - La recompensa en dos pasos

    @MainActor
    func testCapturaLaRecompensaEnIngles() throws { try capturaLaRecompensa(idioma: "en") }

    @MainActor
    func testCapturaLaRecompensaEnCastellano() throws { try capturaLaRecompensa(idioma: "es") }

    /// 09. El paso 2 de toda recompensa gratis (E14b B29, D17): el Ministro de Economía paga
    /// con un solo botón y enseguida sale «¿Lo duplicás?», con «×2 con video» y «No, gracias».
    /// El anuncio es el del stub (`--uitest*` nunca usa AdMob), siempre listo: sin él el paso 2
    /// no aparece.
    @MainActor
    private func capturaLaRecompensa(idioma: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + Self.baseArguments + [
            "--uitest-unlock-tower", "--uitest-seen-types", "--uitest-merge-all", "--uitest-extra-slots",
            "--uitest-visitor=ministro_subsidio",
        ]
        app.launch()
        guard visitorOnStage(app) else { return XCTFail("el Ministro nunca llegó al escenario") }
        // Desde B21 su popup no sale solo: se abre tocando su tarjeta.
        app.buttons["stage.chip.visitor"].tap()
        let accept = app.buttons["visit.option.accept"]
        guard accept.waitForExistence(timeout: 10) else { return XCTFail("su tarjeta no abrió el popup") }
        accept.tap()
        guard app.buttons["reward.double.decline"].waitForExistence(timeout: 15) else {
            return XCTFail("cobrada la plata, el paso 2 «¿Lo duplicás?» nunca salió")
        }
        settle()
        shoot(app, "09-recompensa")
    }

    // MARK: - La Marcha

    @MainActor
    func testCapturaLaMarchaEnIngles() throws { try capturaLaMarcha(idioma: "en") }

    @MainActor
    func testCapturaLaMarchaEnCastellano() throws { try capturaLaMarcha(idioma: "es") }

    /// 10. La Marcha del Puntero (E14b B25) ya ganada: sale a festejar con la plaza llena y el
    /// botón de cobrar. `--uitest-marcha-ganada` la deja sellada en el save; los 420 toques
    /// no se automatizan (son toques al tablero por coordenada). El chip de la partida en
    /// juego (`stage.chip.marcha`, con `--uitest-marcha-corta`) lo cubre `MarchUITests`.
    @MainActor
    private func capturaLaMarcha(idioma: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + Self.baseArguments + [
            "--uitest-unlock-tower", "--uitest-seen-types", "--uitest-merge-all", "--uitest-extra-slots",
            "--uitest-marcha-ganada",
        ]
        app.launch()
        guard app.buttons["marcha.result.claim"].waitForExistence(timeout: 40) else {
            return XCTFail("ganada, el Puntero nunca salió a festejar")
        }
        settle(seconds: 3)
        shoot(app, "10-marcha")
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
        // Sin `--uitest-chest-manual` cada latido también se dispara solo a los 1,2 s: los
        // toques sólo adelantan lo que igual llega.
        let area = app.buttons["chest.tap"]
        if area.waitForExistence(timeout: 30) {
            for _ in 0..<3 where area.exists && area.isHittable {
                area.tap()
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

    // MARK: - Las ofertas de revisión

    @MainActor
    func testCapturaLaOfertaBienvenida() throws { try capturaLaOferta("bienvenida") }

    @MainActor
    func testCapturaLaOfertaRenacer() throws { try capturaLaOferta("renacer") }

    @MainActor
    func testCapturaLaOfertaMudanza() throws { try capturaLaOferta("mudanza") }

    /// La captura de revisión de una oferta (`com.fisuevolution.iap.offer_<id>`): la hoja con lo que
    /// contiene el paquete, que es lo que App Review pide ver para un consumible. En inglés,
    /// el idioma del revisor. `--uitest-offer=` la abre sola; se guarda como
    /// `oferta-offer_<id>` y `capturas.sh` la lleva a `review/offer_<id>.png`.
    @MainActor
    private func capturaLaOferta(_ id: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments("en") + Self.baseArguments + ["--uitest-offer=\(id)"]
        app.launch()
        guard app.descendants(matching: .any)["offer.sheet"].waitForExistence(timeout: 30) else {
            return XCTFail("la oferta \(id) no se presentó")
        }
        settle(seconds: 3)
        shoot(app, "oferta-offer_\(id)", prefix: "")
    }

    // MARK: - Utilidades

    /// El visitante en el escenario. Desde B7 se queda en el piso donde entró: si la cámara
    /// todavía bajaba al callejón cuando llegó, espera en otro piso y el aviso lleva hasta él
    /// (abre su trato, que se cierra para dejarlo en escena). Se insiste mientras siga el aviso:
    /// con `--uitest-merge-all` las fusiones del arranque mueven la cámara a su piso, y una que
    /// llega después del toque lo deja otra vez esperando en el piso de arriba.
    @MainActor
    private func visitorOnStage(_ app: XCUIApplication) -> Bool {
        let onStage = app.buttons["stage.chip.visitor"]
        let elsewhere = app.buttons["stage.chip.waiting"]
        let close = app.buttons["sheet.close"]
        let deadline = Date().addingTimeInterval(50)
        while !onStage.exists, Date() < deadline {
            if elsewhere.exists {
                elsewhere.tap()
                if close.waitForExistence(timeout: 4) { close.tap() }
            }
            _ = onStage.waitForExistence(timeout: 3)
        }
        return onStage.waitForExistence(timeout: 10)
    }

    /// El valor de un marcador de accesibilidad del tablero (`board.package`, `board.mattress`):
    /// "x,y" si hay algo y vacío si no. Se espera a que el marcador exista.
    @MainActor
    private func markerValue(_ app: XCUIApplication, _ identifier: String) -> String {
        let marker = app.otherElements[identifier]
        _ = marker.waitForExistence(timeout: 10)
        return marker.value as? String ?? ""
    }

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
    private func shoot(_ app: XCUIApplication, _ name: String, prefix: String = "captura-") {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(prefix)\(name)"
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
