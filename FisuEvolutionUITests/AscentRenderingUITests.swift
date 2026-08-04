import XCTest

/// Reproduce el bug reportado: al llegar al piso 2 (o sea, tras el primer
/// ascenso) los personajes dejaban de verse. El clon que vuela terminaba su
/// animación con `alpha = 0` y volvía al pool, así que el próximo personaje que
/// lo reutilizaba nacía invisible —pero clickeable—.
///
/// El test deja capturas de cada etapa para inspección visual: no hay forma de
/// asertar la opacidad de un nodo SpriteKit desde XCUITest, así que la prueba
/// automatiza la secuencia y el veredicto sobre el render se hace mirando.
final class AscentRenderingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Anclas del tablero, en coordenadas normalizadas. Salen de la geometría de
    /// `BoardScene.rebuildAnchors` (2 filas × 5 columnas, `edgeInset` 0.68 y
    /// `frontY` 0.55 del `cellSize`), no de tantear la pantalla.
    @MainActor
    private func slot(_ index: Int, in app: XCUIApplication) -> XCUICoordinate {
        let width = app.frame.width
        let height = app.frame.height
        let cell = (width - 32) / 5
        let edgeInset = cell * 0.68
        let colSpacing = (cell * 5 - 2 * edgeInset) / 5
        let column = CGFloat(index % 5)
        let row = CGFloat(index / 5)
        let stagger = (row.truncatingRemainder(dividingBy: 2) == 0 ? -1.0 : 1.0) * colSpacing * 0.1
        let x = 16 + edgeInset + column * colSpacing + colSpacing / 2 + stagger
        let sceneY = 110 + cell * 0.55 + row * cell * 0.95
        return app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: height - sceneY))
    }

    /// El panel de debug es un sheet sin botón de cerrar: se descarta
    /// arrastrándolo hacia abajo.
    @MainActor
    private func dismissSheet(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            .press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        Thread.sleep(forTimeInterval: 0.6)
    }

    @MainActor
    private func grantPair(_ app: XCUIApplication) {
        app.buttons["hud.debug"].tap()
        app.buttons["Invocar par del tier máximo"].tap()
        dismissSheet(app)
    }

    /// Llegar a Urban acredita la skin de milestone `urban_trailblazer`, y su
    /// celebración es un sheet MODAL: mientras está arriba tapa el tablero —que
    /// es de lo que este test da veredicto mirando la captura— y deja todo el
    /// HUD inalcanzable, incluidas las flechas de la torre.
    ///
    /// Aparece sólo con el tutorial dado por visto, o sea que depende de un
    /// `@AppStorage` que `--uitest-reset` NO toca y que el propio test puede
    /// terminar de avanzar a fuerza de taps. Por eso se tolera que esté o no en
    /// vez de asumir una de las dos ramas.
    @MainActor
    private func dismissSkinAward(_ app: XCUIApplication) {
        let nice = app.buttons["skin.award.dismiss"]
        guard nice.waitForExistence(timeout: 2) else { return }
        nice.tap()
        Thread.sleep(forTimeInterval: 0.6)
    }

    @MainActor
    func testCharactersStayVisibleAfterTheFirstAscent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        XCTAssertTrue(app.otherElements["tower.pill"].waitForExistence(timeout: 15))

        // 1) Par de Fisuras y merge → Cartonero (mismo piso, sin ascenso).
        grantPair(app)
        slot(0, in: app).press(forDuration: 0.05, thenDragTo: slot(1, in: app))
        Thread.sleep(forTimeInterval: 1.2)
        add(shot(app, "1 tras el merge de Fisuras"))

        // 2) Par de Cartoneros y merge → Kiosco (T3): ASCIENDE a Urban y lo abre.
        //    Tras el merge anterior el tablero queda T2@0, T2@1, T1@2, T2@3: hay
        //    que unir 0 y 1. Arrastrar sobre el slot 2 (el Fisura suelto) da
        //    tipos distintos y snap-back — el test pasaba sin ascender nada.
        grantPair(app)
        slot(0, in: app).press(forDuration: 0.05, thenDragTo: slot(1, in: app))
        // La cadena es SECUENCIAL desde 2026-08-04: vuelo (0,7 s) + reveal
        // (~2 s) + celebración de piso (~1,3 s) antes de que aparezca el sheet.
        Thread.sleep(forTimeInterval: 6.0)
        dismissSkinAward(app)
        add(shot(app, "2 tras el ascenso a Urban"))
        // Gate: sin ascenso, nada de lo que sigue prueba el arreglo del pool.
        let pillTrasAscenso = app.otherElements["tower.pill"].label
        // Gate del test: si no ascendimos, nada de lo que sigue prueba el fix.
        // El label accesible de la pill es el NOMBRE del piso, no el contador.
        XCTAssertEqual(pillTrasAscenso, "City",
                       "esperaba que el ascenso llevara la cámara a Urban")

        // 3) Volver al callejón: acá es donde se veían los personajes invisibles.
        let down = app.buttons["tower.arrow.down"]
        if down.isEnabled { down.tap() }
        Thread.sleep(forTimeInterval: 1.0)
        add(shot(app, "3 de vuelta en el callejon"))

        // 4) Comprar un Fisura nuevo: era el que salía invisible.
        app.buttons["hud.debug"].tap()
        app.buttons["+ Monedas (1M o costo de spawn ×100)"].tap()
        dismissSheet(app)
        let spawn = app.buttons["hud.spawn"]
        if spawn.waitForExistence(timeout: 3), spawn.isEnabled { spawn.tap() }
        Thread.sleep(forTimeInterval: 1.0)
        add(shot(app, "4 tras comprar un Fisura nuevo"))

        let pillSigueVivo = app.otherElements["tower.pill"].exists
        XCTAssertTrue(pillSigueVivo, "el HUD debe seguir vivo")
    }

    /// El fondo se sobredimensiona 18% y va anclado abajo, así que el sobrante
    /// asoma por arriba: sin recortarlo al slot, el piso de abajo se ve en la
    /// franja inferior del de arriba. Navega con las flechas (no con arrastres)
    /// para que sea determinista.
    @MainActor
    func testEachFloorRendersOnlyItsOwnBackground() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-unlock-tower"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        add(shot(app, "piso 1 alley"))

        let up = app.buttons["tower.arrow.up"]
        XCTAssertTrue(up.isEnabled, "el fixture debe dejar la torre abierta")
        up.tap()
        Thread.sleep(forTimeInterval: 1.2)
        // El label accesible de la pill es el NOMBRE del piso, no el contador.
        XCTAssertEqual(pill.label, "City", "no llegué al piso 2")
        add(shot(app, "piso 2 urban"))

        if app.buttons["tower.arrow.up"].isEnabled {
            app.buttons["tower.arrow.up"].tap()
            Thread.sleep(forTimeInterval: 1.2)
            add(shot(app, "piso 3 corporate"))
        }
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }

    /// Baseline de rendimiento: puebla el callejón y captura el overlay de fps
    /// con el tablero cargado, que es el caso que el jugador percibe.
    @MainActor
    func testPerfBaselinePopulatedBoard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()
        XCTAssertTrue(app.otherElements["tower.pill"].waitForExistence(timeout: 15))

        for _ in 0..<4 { grantPair(app) }       // 8 unidades + la inicial
        Thread.sleep(forTimeInterval: 3.0)      // dejar que el wander se estabilice
        add(shot(app, "perf tablero poblado"))

        // Tapear un rato: es el uso real, y cada tap corre el pipeline de feedback.
        let centro = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.82))
        for _ in 0..<15 { centro.tap() }
        Thread.sleep(forTimeInterval: 2.0)
        add(shot(app, "perf tras 15 taps"))
    }
}
