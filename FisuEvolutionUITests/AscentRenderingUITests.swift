import XCTest

/// Reproduce el bug reportado: al llegar al piso 2 (o sea, tras el primer
/// ascenso) los personajes dejaban de verse. El clon que vuela terminaba su
/// animación con `alpha = 0` y volvía al pool, así que el próximo personaje que
/// lo reutilizaba nacía invisible —pero clickeable—.
///
/// El test deja capturas de cada etapa para inspección visual: no hay forma de
/// asertar la opacidad de un nodo de SpriteKit desde XCUITest, así que el
/// veredicto FINO sobre el render se hace mirando la captura 3.
///
/// Lo que sí se asserta —y es lo que exige la trampa 2— es el EFECTO, no el
/// gesto: el ascenso **ocurre** (la pill cambia de piso) y el tablero **sigue
/// poblado** (`board.units` sube al contratar de vuelta en el callejón, o sea
/// que la unidad que reusa el nodo del clon existe de verdad).
final class AscentRenderingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Anclas del tablero. Un test de UI corre fuera de proceso y no puede
    /// importar la app, así que esto es un ESPEJO de `BoardScene.rebuildAnchors`
    /// + `BoardScene.crowdBand`.
    ///
    /// ⚠️ **Si cambiás la geometría del campo, cambiá esto en el mismo commit.**
    /// Ya se desincronizó CUATRO veces: quedó con el `rowDepth` viejo (no se notó
    /// porque la fila 0 lo multiplica por cero), después con el `frontY` viejo,
    /// que sí rompió, después con `bottomInset` en 110 cuando la escena ya lo
    /// tenía en 114 (arreglado el 2026-08-16), y de nuevo con `bottomInset` en
    /// 114 cuando la barra inferior se fundió con el borde y la escena pasó a
    /// 116 (2026-08-17). Esta última **la agarró el review, no la suite**: con
    /// 2 pt de desfasaje los gates siguen en verde, que es exactamente el verde
    /// falso contra el que avisa este bloque.
    ///
    /// Los gates de `board.units` y de la pill son lo que convierte un desfasaje
    /// en una falla ruidosa en vez de un verde falso. No los saques.
    ///
    /// ⚠️ El jitter determinístico de `rebuildAnchors` (±`cell × 0,04` en x,
    /// ±`cell × 0,03` en y ≈ ±3 pt) **no** se espeja a propósito: replicar el
    /// hash acá sería duplicar código frágil por un desfasaje que el deambular
    /// (±`halfWander` ≈ 58 pt) ya se come entero, y el barrido de slots del
    /// doble toque lo cubre.
    @MainActor
    private func slot(_ index: Int, in app: XCUIApplication) -> XCUICoordinate {
        let width = app.frame.width
        let height = app.frame.height
        // Espejo de `boardColumns`: `ceil(capacidad / filas)`, y los diez pisos
        // tienen capacidad 10 → 5 columnas.
        let columns: CGFloat = 5
        let cell = (width - 32) / columns
        let edgeInset = cell * 0.68
        let colSpacing = (cell * columns - 2 * edgeInset) / columns
        let column = CGFloat(index % 5)
        let row = CGFloat(index / 5)
        let stagger = (row.truncatingRemainder(dividingBy: 2) == 0 ? -1.0 : 1.0) * colSpacing * 0.1
        let x = 16 + edgeInset + column * colSpacing + colSpacing / 2 + stagger

        // Espejo de `crowdBand`: la franja va del piso (`0,55 × cell` sobre el
        // borde del campo) hasta `crowdTopRatio` del alto de pantalla, y las dos
        // filas se reparten ese alto — el ancla de cada una queda a medio
        // deambular de su extremo.
        //
        // Espejo de `BoardScene.bottomInset` (116; subió de 114 el 2026-08-17,
        // cuando la barra inferior se fundió con el borde y estrenó los labels)
        // y de `BoardScene.crowdTopRatio` (0,44; subió de 0,40 el 2026-08-10,
        // cuando los diez fondos se regeneraron con más piso).
        let bottomInset: CGFloat = 116
        let crowdTopRatio: CGFloat = 0.44
        let rows: CGFloat = 2
        let floorY = cell * 0.55
        let topY = max(floorY, height * crowdTopRatio - bottomInset)
        let usable = topY - floorY
        let halfWander = usable / (2 * rows)
        let frontY = floorY + halfWander
        let rowDepth = (usable - 2 * halfWander) / (rows - 1)

        // Se apunta al CENTRO DEL CUERPO (`cell × 0,9` sobre el ancla, igual que
        // el óvalo de `characterNode(at:)`), no a los pies.
        //
        // El ancla es sólo el centro del deambular: en cualquier instante el
        // personaje está hasta media amplitud más arriba o más abajo. Tocando a
        // la altura de los pies, un personaje deambulado hacia arriba deja el
        // punto FUERA de su óvalo y el toque agarra aire. Apuntando al centro del
        // cuerpo, el desfasaje entra siempre: media amplitud (≈58) es bastante
        // menor que el semieje vertical del óvalo (`cell × 1,15` ≈ 85).
        let bodyCenter = cell * 0.9
        let sceneY = bottomInset + frontY + row * rowDepth + bodyCenter

        return app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: height - sceneY))
    }

    // MARK: - Toques

    /// Espera al botón y lo toca. La guarda no es decorativa: sin ella, un toque
    /// sobre un botón que todavía no se presentó cae sobre lo que haya abajo
    /// —el tablero— y puede arrastrar a alguien.
    @MainActor
    private func tap(_ button: XCUIElement, _ what: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no apareció \(what)",
                      file: file, line: line)
        button.tap()
    }

    /// Igual, pero tocando el CENTRO DEL FRAME en vez del elemento.
    ///
    /// ⚠️ No es paranoia: en un simulador recién creado el primer toque de la
    /// corrida se pierde con `Failed to scroll to visible (by AX action)`
    /// —`board.units` es un elemento del tamaño del tablero, aparece listado
    /// antes que los botones del HUD y XCUITest cree que hay algo tapándolos
    /// (trampa 9a en frío, ya anotada por `CustomizationUITests`)—. Este test es
    /// el PRIMERO de su suite, así que es el que se come el device frío: la
    /// corrida del 2026-08-16 murió exactamente ahí, en el `hud.debug` de
    /// `grantPair`, antes de llegar a probar nada. Tocar por coordenada esquiva
    /// el `scrollToVisible` que falla.
    @MainActor
    private func tapHUD(_ button: XCUIElement, _ what: String,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no apareció \(what)",
                      file: file, line: line)
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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

    /// Los strings del panel de debug van en español y a mano: sólo existe en
    /// builds Debug y no pasa por el String Catalog, así que no cambian con el
    /// idioma en el que el runner corre la app.
    @MainActor
    private func grantPair(_ app: XCUIApplication) {
        tapHUD(app.buttons["hud.debug"], "el botón de debug del HUD")
        tap(app.buttons["Invocar par del tier máximo"], "el botón de invocar par")
        dismissSheet(app)
    }

    @MainActor
    private func grantCoins(_ app: XCUIApplication) {
        tapHUD(app.buttons["hud.debug"], "el botón de debug del HUD")
        tap(app.buttons["+ Monedas (1M o costo de spawn ×100)"], "el botón de monedas del panel")
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
    ///
    /// ⚠️ La ventana era de **2 s** de un solo tiro, y eso era un falso rojo
    /// esperando a una máquina cargada: si la hoja llegaba tarde, esto volvía sin
    /// descartar nada y el toque siguiente —la flecha de bajar— caía sobre el
    /// sheet. El test moría en el assert del callejón por CARGA y no por código,
    /// que es exactamente como se ganó estar salteado diez días. Ahora la ventana
    /// es ancha y además se espera a que la hoja **se vaya**: descartarla dispara
    /// una animación, y un toque durante la salida también se pierde.
    @MainActor
    private func dismissSkinAward(_ app: XCUIApplication, timeout: TimeInterval = 10) {
        let nice = app.buttons["skin.award.dismiss"]
        guard nice.waitForExistence(timeout: timeout) else { return }
        nice.tap()
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: nice
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed,
                       "la celebración de la skin no se fue: taparía todo lo que sigue")
    }

    /// Espera a que un control exista Y esté habilitado.
    ///
    /// Se poletea en vez de usar `NSPredicate` sobre `enabled` para no depender
    /// del nombre KVC de la propiedad. Cada consulta al runner cuesta lo suyo,
    /// así que el bucle se autorregula solo.
    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.isEnabled { return true }
        } while Date() < deadline
        return false
    }

    // MARK: - Fusión

    /// El contador de unidades del tablero, que es lo único que prueba que una
    /// fusión ocurrió: publica `player.run.totalUnits`, o sea la torre ENTERA,
    /// así que un ascenso no lo altera de más —el que voló sigue contando—.
    @MainActor
    private func units(_ app: XCUIApplication) -> XCUIElement {
        app.otherElements["board.units"]
    }

    /// `nil` si el valor accesible no se pudo leer o parsear.
    ///
    /// ⚠️ **No devuelve un centinela a propósito.** Devolvía `-1`, y eso volvía
    /// vacuamente cierto el `XCTAssertLessThan(unitCount, before)` de
    /// `mergeTopPair`: una lectura fallida da `-1`, que es menor que cualquier
    /// `before`, así que el assert que existe para cazar "el tablero cambió pero
    /// no por una fusión" pasaba justo cuando no podía saber nada. Con
    /// `Optional` el que falla la lectura tiene que decirlo.
    @MainActor
    private func unitCount(_ app: XCUIApplication) -> Int? {
        (units(app).value as? String).flatMap(Int.init)
    }

    /// Fusiona el par del tier más alto con DOBLE TOQUE, como
    /// `TutorialUITests.mergeTheHighlightedPair` y `BoardGestureUITests`.
    ///
    /// ⚠️ Reemplaza al arrastre `slot(0) → slot(1)` que tuvo este test rojo desde
    /// el 2026-08-06 (`"Alley" != "City"`, confirmado otra vez el 2026-08-16
    /// corriéndolo tal cual). El arrastre necesitaba puntería en los DOS
    /// extremos contra personajes que deambulan a 44 pt/s: el drop caía en el
    /// aire o sobre alguien de otro tipo, no había fusión, y el test moría recién
    /// en el gate del ascenso. El doble toque sólo tiene que acertarle al de
    /// ORIGEN — del destino se encarga `MergeTargeting.nearestPartner`, que mide
    /// contra la posición real y alcanza hasta 2 celdas.
    ///
    /// Barre los slots que `debugGrantPair` puede llegar a ocupar porque el que
    /// tocás pudo haber deambulado fuera de su ancla. Reintentar no puede hacer
    /// pasar el test por la razón equivocada: un doble toque en el vacío no hace
    /// NADA (no hay nodo ahí) y uno sobre un personaje sin compañero de su tipo
    /// tampoco fusiona —cobra monedas y listo—, así que la única forma de que
    /// `board.units` baje es que una fusión haya ocurrido.
    ///
    /// Y la que baja es siempre la del tier MÁS ALTO, que es la que hace falta
    /// para escalar: `debugGrantPair` reparte de a pares del máximo, así que los
    /// tiers de abajo quedan de a uno y no tienen con quién fusionarse.
    @MainActor
    private func mergeTopPair(_ app: XCUIApplication, _ what: String, rounds: Int = 3,
                              file: StaticString = #filePath, line: UInt = #line) {
        let board = units(app)
        guard let before = unitCount(app) else {
            XCTFail("\(what): no se pudo leer board.units (valor: \(board.value ?? "nil"))",
                    file: file, line: line)
            return
        }
        XCTAssertGreaterThan(before, 1, "\(what): el tablero tiene que traer el par a fusionar",
                             file: file, line: line)
        for _ in 0..<rounds {
            for index in 0..<6 {
                slot(index, in: app).doubleTap()
                // Se espera un valor DISTINTO, no `before - 1`: si un barrido
                // llegara a encadenar dos fusiones, un target exacto se lo
                // perdería y el test moriría buscando un número que ya pasó.
                guard waitFor(board, valueOtherThan: String(before), timeout: 2) else { continue }
                guard let after = unitCount(app) else {
                    XCTFail("\(what): board.units dejó de leerse justo tras el doble toque",
                            file: file, line: line)
                    return
                }
                XCTAssertLessThan(after, before,
                                  "\(what): el tablero cambió, pero no por una fusión (\(before) → \(after))",
                                  file: file, line: line)
                return
            }
        }
        XCTFail("""
                \(what): el doble toque no fusionó nada en \(rounds * 6) intentos; \
                board.units sigue en \(board.value ?? "?")
                """, file: file, line: line)
    }

    // MARK: - El test

    @MainActor
    func testCharactersStayVisibleAfterTheFirstAscent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        XCTAssertTrue(units(app).waitForExistence(timeout: 15))

        // 1) Escalar el callejón a fuerza de pares hasta que una fusión dispare
        //    el ASCENSO, que es el momento en que vuela el clon.
        //
        //    ⚠️ La cantidad de fusiones NO se hardcodea, y no es por elegancia:
        //    este test decía "par de Cartoneros → Kiosco (T3) ASCIENDE" y para
        //    el 2026-08-16 eso ya era mentira —el callejón cubre los tiers 1..4
        //    (`economy.json`), así que el primer piso nuevo lo abre un T5 y hacen
        //    falta CUATRO—. El supuesto vencido es parte de por qué el test
        //    estuvo rojo: con el arrastre arreglado seguía sin ascender, porque
        //    fusionaba dos veces y se plantaba en el T3.
        var fusiones = 0
        var ascendio = false
        while fusiones < 8 {
            grantPair(app)
            mergeTopPair(app, "el par del tier máximo (fusión \(fusiones + 1))")
            fusiones += 1
            // ⚠️ Acá había un `Thread.sleep(6)` fijo, calculado sobre la cadena
            // SECUENCIAL del ascenso (vuelo 0,7 s + reveal ~2 s + celebración
            // ~1,3 s). Con la máquina cargada esa cadena se pasa de los 6 s, y
            // entonces el bucle daba por NO ascendida una fusión que sí ascendió
            // y seguía fusionando sobre un piso que ya se estaba moviendo. Se
            // espera por el efecto, con deadline: la fusión que no asciende lo
            // agota y sigue de largo —cuesta tiempo, no correctitud—.
            if waitFor(pill, labelOtherThan: "Alley", timeout: 15) {
                ascendio = true
                break
            }
        }
        XCTAssertTrue(ascendio, """
                      ninguna de las \(fusiones) fusiones ascendió; \
                      la pill sigue en "\(pill.label)"
                      """)
        dismissSkinAward(app)
        add(shot(app, "1 tras el ascenso a Urban"))

        // Gate del test: si no ascendimos, nada de lo que sigue prueba el fix.
        // El label accesible de la pill es el NOMBRE del piso, no el contador, y
        // el runner corre la app en INGLÉS: "City" es `tower.floor.urban`.
        XCTAssertTrue(waitFor(pill, label: "City", timeout: 10), """
                      esperaba que el ascenso llevara la cámara a Urban tras \
                      \(fusiones) fusiones; la pill dice "\(pill.label)"
                      """)

        // 2) Volver al callejón: acá es donde se veían los personajes invisibles.
        let down = app.buttons["tower.arrow.down"]
        // ⚠️ El `isEnabled` iba sin esperar a que el control existiera siquiera:
        // sobre un elemento que todavía no está, `isEnabled` es `false` y el
        // assert moría sin haberle dado tiempo a nada.
        XCTAssertTrue(waitUntilEnabled(down, timeout: 10),
                      "tras el ascenso la flecha de bajar tiene que aparecer y estar viva")
        tapHUD(down, "la flecha de bajar de la torre")
        XCTAssertTrue(waitFor(pill, label: "Alley", timeout: 10),
                      "la flecha de bajar tiene que devolver al callejón; la pill dice \"\(pill.label)\"")
        add(shot(app, "2 de vuelta en el callejon"))

        // 3) Comprar un Fisura nuevo: era el que salía invisible. Desde que el
        //    botón de spawn murió, la compra pasa por FisuJobs (tab `hud.hire`).
        grantCoins(app)
        guard let antesDeContratar = unitCount(app) else {
            XCTFail("no se pudo leer board.units antes de contratar")
            return
        }
        tapHUD(app.buttons["hud.hire"], "el tab de FisuJobs")
        tap(app.buttons["jobs.hire.homeless"], "la fila del Fisura en FisuJobs")
        // ⚠️ Con guarda: hasta el 2026-08-16 esto tapeaba `sheet.close` a ciegas
        // (así quedó al migrarlo en la T7 del plan anterior, con el test
        // salteado). Si la hoja tardaba, el toque caía sobre el tablero.
        tap(app.buttons["sheet.close"], "el botón de cerrar de FisuJobs")
        Thread.sleep(forTimeInterval: 1.0)
        add(shot(app, "3 tras comprar un Fisura nuevo"))

        // Gate final (trampa 2): el tablero sigue POBLADO después del ascenso.
        // XCUITest no puede leer el alpha de un nodo de SpriteKit, así que la
        // prueba al alcance es que la unidad nueva —la que reusa el nodo del clon
        // que voló— entra de verdad al tablero; que además se VEA lo dice la
        // captura 3.
        XCTAssertTrue(waitFor(units(app), value: String(antesDeContratar + 1), timeout: 8),
                      """
                      el Fisura contratado tras el ascenso tiene que entrar al tablero; \
                      board.units quedó en \(units(app).value ?? "?")
                      """)
        XCTAssertTrue(pill.exists, "el HUD debe seguir vivo")
    }

    /// El fondo se sobredimensiona 18% y va anclado abajo, así que el sobrante
    /// asoma por arriba: sin recortarlo al slot, el piso de abajo se ve en la
    /// franja inferior del de arriba. Navega con las flechas (no con arrastres)
    /// para que sea determinista.
    @MainActor
    func testEachFloorRendersOnlyItsOwnBackground() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-unlock-tower", "--uitest-skip-tutorial"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        add(shot(app, "piso 1 alley"))

        let up = app.buttons["tower.arrow.up"]
        XCTAssertTrue(up.isEnabled, "el fixture debe dejar la torre abierta")
        tapHUD(up, "la flecha de subir de la torre")
        Thread.sleep(forTimeInterval: 1.2)
        // El label accesible de la pill es el NOMBRE del piso, no el contador.
        XCTAssertEqual(pill.label, "City", "no llegué al piso 2")
        add(shot(app, "piso 2 urban"))

        if app.buttons["tower.arrow.up"].isEnabled {
            tapHUD(app.buttons["tower.arrow.up"], "la flecha de subir de la torre")
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

    @MainActor
    private func waitFor(_ element: XCUIElement, value: String,
                         timeout: TimeInterval) -> Bool {
        let reached = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value), object: element
        )
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, valueOtherThan stale: String,
                         timeout: TimeInterval) -> Bool {
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", stale), object: element
        )
        return XCTWaiter().wait(for: [changed], timeout: timeout) == .completed
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, label: String,
                         timeout: TimeInterval) -> Bool {
        let reached = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label), object: element
        )
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, labelOtherThan stale: String,
                         timeout: TimeInterval) -> Bool {
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", stale), object: element
        )
        return XCTWaiter().wait(for: [changed], timeout: timeout) == .completed
    }

    /// Baseline de rendimiento: puebla el callejón y captura el overlay de fps
    /// con el tablero cargado, que es el caso que el jugador percibe.
    @MainActor
    func testPerfBaselinePopulatedBoard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
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
