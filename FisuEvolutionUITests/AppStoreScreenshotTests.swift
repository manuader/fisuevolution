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
/// xcodebuild -project FisuEvolution.xcodeproj -scheme FisuEvolution \
///   -destination 'platform=iOS Simulator,name=Shots 6.9' \
///   -derivedDataPath build-shots -resultBundlePath /tmp/shots.xcresult \
///   test-without-building -parallel-testing-enabled NO \
///   -only-testing:FisuEvolutionUITests/AppStoreScreenshotTests
/// ```
///
/// y después se sacan los PNG del bundle de resultados con
/// `xcrun xcresulttool export attachments`.
///
/// ⚠️ **El simulador tiene que ser de 6,9"** (iPhone 16/17 Pro Max): App Store
/// pide 1320×2868 para esa clase y rechaza cualquier otro tamaño en ese slot.
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

    /// Los dos idiomas de la ficha, con el prefijo que llevan sus archivos.
    ///
    /// `-AppleLanguages` va como **launch argument** y no como variable de
    /// entorno: así lo lee `Foundation` al arrancar el proceso de la app, que
    /// es antes de que corra una línea nuestra.
    private static func languageArguments(_ code: String) -> [String] {
        ["-AppleLanguages", "(\(code))", "-AppleLocale", code]
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    /// El guión de `Distribution/store-metadata.md`, en el orden en que se
    /// suben. Las tres primeras son las que se ven en el listado sin scrollear
    /// y por lo tanto las que venden.
    @MainActor
    func testCapturaLasPantallasEnIngles() throws {
        try capturaLasPantallas(idioma: "en", prefijo: "en")
    }

    @MainActor
    func testCapturaLasPantallasEnCastellano() throws {
        try capturaLasPantallas(idioma: "es", prefijo: "es")
    }

    @MainActor
    private func capturaLasPantallas(idioma: String, prefijo: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + [
            "--screenshot-mode",
            "--uitest-reset",
            "--uitest-skip-tutorial",
            // La partida "con la que uno se quiere sacar la foto": plata para
            // que los precios no se vean todos en rojo, la torre abierta, los
            // tipos vistos (Mejoras y Pintas listan lo VISTO, no lo abierto) y
            // pintas en el ropero.
            "--uitest-coins",
            "--uitest-unlock-tower",
            "--uitest-seen-types",
            "--uitest-skins",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 30),
                      "la barra inferior nunca apareció: sin ella no hay captura que sacar")

        // 1. El tablero. Es la primera impresión del juego.
        settle()
        shoot(app, "\(prefijo)-01-tablero")

        // 2-5. Las cuatro hojas que muestran el sistema.
        for screen in Self.screens {
            let tab = app.buttons[screen.tab]
            guard tab.exists, waitUntilHittable(tab) else {
                XCTFail("el tab \(screen.tab) nunca quedó tocable")
                continue
            }
            tab.tap()
            // Se espera un identifier de ADENTRO de la hoja y no `sheet.close`:
            // con el botón de cerrar alcanza para saber que se abrió *algo*, y
            // una foto de la hoja equivocada se descubre mirando el PNG.
            guard app.descendants(matching: .any)[screen.marker]
                .waitForExistence(timeout: 15) else {
                XCTFail("\(screen.tab) no mostró \(screen.marker)")
                continue
            }
            settle()
            shoot(app, "\(prefijo)-\(screen.name)")

            let close = app.buttons["sheet.close"]
            if close.exists, waitUntilHittable(close) { close.tap() }
            // La hoja saliente sigue en el árbol de AX mientras se desliza, y
            // el próximo tab vive debajo: sin esperar, el toque siguiente cae
            // sobre el contenido en vuelo (trampa 4 de la suite).
            _ = app.buttons["hud.hire"].waitForExistence(timeout: 10)
            XCTAssertTrue(waitUntilHittable(app.buttons["hud.hire"]),
                          "la barra no volvió después de cerrar \(screen.tab)")
        }
    }

    /// El cofre, que es el momento más vistoso del juego. Va en su propia
    /// corrida porque necesita un fixture que las otras capturas no quieren
    /// (`--uitest-chest` abre un cofre en la cara, y taparía el tablero).
    ///
    /// ⚠️ Se fotografía la CARTA del premio, no el estallido: la animación son
    /// 4 s y agarrarla a mitad da un fotograma oscuro lleno de destellos, que
    /// es exactamente lo que salió al intentarlo con `simctl`.
    @MainActor
    func testCapturaElCofreEnIngles() throws {
        try capturaElCofre(idioma: "en", prefijo: "en")
    }

    @MainActor
    func testCapturaElCofreEnCastellano() throws {
        try capturaElCofre(idioma: "es", prefijo: "es")
    }

    @MainActor
    private func capturaElCofre(idioma: String, prefijo: String) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.languageArguments(idioma) + [
            "--screenshot-mode", "--uitest-reset", "--uitest-skip-tutorial",
            "--uitest-coins", "--uitest-chest",
        ]
        app.launch()

        // Los tres toques que abren el cofre. El identifier del escenario es el
        // mismo que ejerce `ChestOpeningUITests`.
        let stage = app.otherElements["chest.stage"]
        if stage.waitForExistence(timeout: 30) {
            for _ in 0..<3 where stage.isHittable {
                stage.tap()
                usleep(900_000)
            }
        }
        // El premio se asienta al final del video (~4 s a 48 fps) más el
        // resorte de la carta.
        Thread.sleep(forTimeInterval: 7)
        shoot(app, "\(prefijo)-06-cofre")
    }

    // MARK: - El guión

    private static let screens: [(tab: String, marker: String, name: String)] = [
        ("hud.hire", "jobs.hire.homeless", "02-fisujobs"),
        ("hud.upgrades", "upgrades.tab.permanent", "03-mejoras"),
        ("hud.skins", "skins.row.base", "04-pintas"),
        ("hud.bonus", "bonus.activate.mate", "05-regalos"),
    ]

    // MARK: - Utilidades

    /// Deja que terminen las animaciones de entrada antes de disparar. Sin
    /// esto, las hojas salen a mitad de su transición y las tarjetas con
    /// stagger aparecen a medio entrar.
    private func settle() {
        Thread.sleep(forTimeInterval: 1.6)
    }

    /// Guarda la captura como attachment del resultado.
    ///
    /// `XCUIScreen.main.screenshot()` y no `app.screenshot()`: el primero toma
    /// la PANTALLA entera al tamaño nativo del device, que es lo que App Store
    /// valida. El segundo recorta al frame de la app y, con hojas presentadas,
    /// puede devolver un tamaño que no es el del simulador.
    @MainActor
    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
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
