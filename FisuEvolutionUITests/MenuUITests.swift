import XCTest

/// El Menú y sus sub-pantallas (spec §10): la grilla 2×2, el organigrama, las
/// estadísticas, los logros, los ajustes y los documentos legales.
///
/// ⚠️ Todo va por **identifier y por valor de accesibilidad**, nunca por texto:
/// el runner corre la app en INGLÉS aunque el idioma de desarrollo sea `es`
/// (trampa 6 del HANDOFF), así que un assert sobre "Cobrado" pasaría por la
/// razón equivocada — no encontraría el texto nunca, ni cuando está.
///
/// ⚠️ Se navega **cerrando y reabriendo la hoja** en vez de usar el chevron de
/// "atrás". El botón de volver lo pone el sistema y no tiene identifier propio:
/// buscarlo por posición en la barra ata el test a que nadie agregue otro botón
/// ahí. Abrir de nuevo cuesta un segundo y no depende de nada del sistema.
final class MenuUITests: XCTestCase {
    /// Las cuatro tarjetas de la grilla, en el orden en que se leen.
    private static let cards = [
        "menu.card.orgchart", "menu.card.stats", "menu.card.achievements", "menu.card.settings"
    ]

    // MARK: La grilla

    @MainActor
    func testElMenuAbreConSusCuatroTarjetas() throws {
        let app = launch()
        openMenu(app)

        // ⚠️ La captura va ANTES de los asserts: un assert que corta se lleva
        // puesta la evidencia, y las capturas del xcresult son la única forma de
        // ver por qué (trampa 9a-bis).
        attach(app, named: "T15 menú 2×2")

        for card in Self.cards {
            XCTAssertTrue(app.buttons[card].exists, "falta la tarjeta \(card) en la grilla del menú")
        }
    }

    // MARK: Ajustes

    /// Ajustes de punta a punta: los controles que el spec §10.4 pinea por
    /// identifier, y el toggle de partículas ejercido de verdad.
    ///
    /// ⚠️ El estado del toggle se lee por **valor de accesibilidad sin
    /// traducir** (`on`/`off`), igual que el estado de los logros: el runner
    /// corre la app en inglés (trampa 6) y un valor traducido pasaría por la
    /// razón equivocada.
    ///
    /// ⚠️ Que arranque en `on` depende de que `--uitest-reset` limpie
    /// `settings.particlesEnabled`: la preferencia vive en `UserDefaults` y
    /// sobrevive al borrado de la partida (misma trampa que las banderas del
    /// tutorial). Sin eso, este test pasaría la primera vez y fallaría la
    /// segunda.
    @MainActor
    func testAjustesTraeSusControlesYApagaLasParticulas() throws {
        let app = launch()
        openMenu(app)
        app.buttons["menu.card.settings"].tap()

        // ⚠️ Los toggles son `switches` y no `buttons`: la fila lleva el trait
        // `.isToggle` (que es lo correcto — VoiceOver la anuncia como interruptor
        // y lee su estado), y eso la saca de `app.buttons`.
        let particles = app.switches["settings.particles"]
        XCTAssertTrue(particles.waitForExistence(timeout: 10), "la tarjeta de Ajustes no abrió la pantalla")
        attach(app, named: "T16 ajustes")

        // Restaurar compras y los dos legales tienen su fila. (Que "Restaurar"
        // se VEA sin scrollear lo garantiza la tienda, que lo lleva en su
        // cabecera fija: acá se comprueba que también se puede llegar desde
        // Ajustes, que es donde el jugador lo va a buscar.)
        for control in ["settings.restore", "settings.privacy", "settings.terms"] {
            XCTAssertTrue(app.buttons[control].exists, "falta el control \(control) en Ajustes")
        }
        for toggle in ["settings.notifications", "settings.haptics"] {
            XCTAssertTrue(app.switches[toggle].exists, "falta el toggle \(toggle) en Ajustes")
        }
        // Y el idioma arranca en "el del teléfono", que es el único estado que
        // no eligió nadie.
        XCTAssertEqual(app.buttons["settings.language.system"].value as? String, "selected",
                       "sin elección previa, el idioma tiene que ser el del sistema")

        XCTAssertEqual(particles.value as? String, "on", "las partículas arrancan prendidas")
        particles.tap()

        let off = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "off"),
            object: app.switches["settings.particles"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [off], timeout: 10), .completed,
                       "tocar el toggle de partículas no cambió su estado")
        attach(app, named: "T16 partículas apagadas")

        // Y el final de la pantalla: la versión sale del bundle, así que un
        // "Version settings.about.version" delataría la clave cruda (trampa 5).
        app.swipeUp()
        app.swipeUp()
        attach(app, named: "T16 ajustes abajo")
        let version = app.staticTexts["settings.about.version"]
        XCTAssertTrue(version.exists, "falta la línea de versión en Acerca de")
        let label = version.label
        XCTAssertFalse(label.contains("settings.about"), "la versión muestra su clave cruda: \(label)")
        XCTAssertTrue(label.contains("("), "la versión tiene que traer el build entre paréntesis: \(label)")
    }

    /// Los términos se leen ADENTRO del juego: es lo que comprueba que los `.md`
    /// viajan en el bundle y que el parser los dibuja (un documento que no carga
    /// se ve igual de vacío que uno que no existe).
    @MainActor
    func testLosTerminosSeAbrenDesdeAjustes() throws {
        let app = launch()
        openMenu(app)
        app.buttons["menu.card.settings"].tap()
        XCTAssertTrue(app.buttons["settings.terms"].waitForExistence(timeout: 10))
        app.buttons["settings.terms"].tap()

        XCTAssertTrue(app.staticTexts["legal.terms"].waitForExistence(timeout: 10),
                      "la fila de Términos no abrió el documento")
        attach(app, named: "T16 términos")
        // El documento trae texto de verdad: el contacto está en las dos
        // versiones y no depende del idioma del runner.
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "adermanu@gmail.com")
        ).firstMatch.exists, "el documento se dibujó vacío: revisá Resources/Legal en el bundle")
    }

    // MARK: Organigrama

    @MainActor
    func testElOrganigramaMuestraLaCadenaDesdeElJefe() throws {
        let app = launch(extraArguments: ["--uitest-seen-types", "--uitest-unlock-tower", "--uitest-coins"])
        openMenu(app)
        app.buttons["menu.card.orgchart"].tap()

        let boss = app.otherElements["orgchart.boss"]
        XCTAssertTrue(boss.waitForExistence(timeout: 10), "la tarjeta del Jefe nunca apareció")
        attach(app, named: "T15 organigrama")

        // El Fisura es el único nodo que existe en TODA partida: es el tipo con
        // el que se arranca. El resto del organigrama depende de lo que el
        // jugador haya visto.
        let fisura = app.otherElements["orgchart.node.homeless"]
        XCTAssertTrue(fisura.exists, "el nodo del Fisura tiene que estar siempre")
        XCTAssertEqual(fisura.value as? String, "×1", "el nodo publica su conteo como valor")

        // Y el jefe está ARRIBA de la cadena: es lo que hace que la pantalla se
        // lea como un organigrama y no como una lista invertida. El Fisura es
        // tier 1, o sea el último de todos.
        XCTAssertLessThan(boss.frame.minY, fisura.frame.minY,
                          "el Jefe tiene que estar por encima de sus empleados")
        // Y el techo de la torre está más arriba que el callejón: tiers DESC.
        let god = app.otherElements["orgchart.node.god"]
        XCTAssertTrue(god.exists, "falta el nodo de Dios")
        XCTAssertLessThan(god.frame.minY, fisura.frame.minY,
                          "Dios (tier 37) tiene que estar por encima del Fisura (tier 1)")
    }

    /// La bifurcación de carrera es lo que hace que esto sea un organigrama y no
    /// una lista: cuatro tipos comparten tier y se dibujan como HERMANOS, en una
    /// fila, colgando de la misma barra.
    ///
    /// Se comprueba sin scrollear porque la pantalla usa `VStack` y no
    /// `LazyVStack`: los 43 nodos existen en el árbol de accesibilidad desde el
    /// primer frame, con su geometría real. Si alguien cambiara la columna a
    /// perezosa, este test se cae — que es exactamente lo que se quiere.
    @MainActor
    func testLasCuatroCarrerasSeDibujanComoHermanos() throws {
        let app = launch(extraArguments: ["--uitest-seen-types"])
        openMenu(app)
        app.buttons["menu.card.orgchart"].tap()
        XCTAssertTrue(app.otherElements["orgchart.boss"].waitForExistence(timeout: 10))

        let siblings = ["junior_architect", "junior_doctor", "junior_lawyer", "junior_programmer"]
            .map { app.otherElements["orgchart.node.\($0)"] }
        for (id, node) in zip(siblings.indices, siblings) {
            XCTAssertTrue(node.exists, "falta el hermano \(id) del tier de carrera")
        }

        // Misma fila (mismo `minY`) y columnas distintas: eso es una
        // bifurcación. Con tolerancia de 1 pt por el redondeo del layout.
        let tops = siblings.map(\.frame.minY)
        let lefts = siblings.map(\.frame.minX).sorted()
        XCTAssertLessThan((tops.max() ?? 0) - (tops.min() ?? 0), 1,
                          "los cuatro juniors tienen que estar en la MISMA fila: \(tops)")
        for (lhs, rhs) in zip(lefts, lefts.dropFirst()) {
            XCTAssertGreaterThan(rhs - lhs, 1, "dos hermanos comparten columna: \(lefts)")
        }
    }

    // MARK: Stats

    @MainActor
    func testLasEstadisticasTraenValorEnSusFilas() throws {
        // Con plata y tipos vistos: una pantalla de stats en cero pasaría el
        // "no viene vacío" con un "0" en todas las filas y no probaría que los
        // números llegan de donde tienen que llegar.
        let app = launch(extraArguments: ["--uitest-coins", "--uitest-seen-types", "--uitest-unlock-tower"])
        openMenu(app)
        app.buttons["menu.card.stats"].tap()

        let merges = app.otherElements["stats.row.total_merges"]
        XCTAssertTrue(merges.waitForExistence(timeout: 10), "no apareció la fila de fusiones")
        attach(app, named: "T15 estadísticas")

        // El valor no puede venir vacío: una fila de stats sin número es
        // exactamente el bug que la proyección existe para evitar.
        for key in ["total_merges", "total_taps", "max_floor", "seen_types", "lifetime_earnings"] {
            let row = app.otherElements["stats.row.\(key)"]
            XCTAssertTrue(row.exists, "falta la fila stats.row.\(key)")
            let value = row.value as? String ?? ""
            XCTAssertFalse(value.isEmpty, "stats.row.\(key) llegó sin valor")
            // Y trae un NÚMERO o un nombre, no la clave cruda del catálogo
            // (trampa 5: `stats.row.max_floor` en pantalla sería el síntoma).
            XCTAssertFalse(value.hasPrefix("stats.row."), "stats.row.\(key) muestra su clave cruda: \(value)")
        }

        // Los ratios de colección se dicen "tenés/hay", y con `--uitest-seen-types`
        // hay más de uno visto: un "1/43" acá delataría que la proyección cuenta
        // otra cosa. El total sale del catálogo, no de un literal.
        let seen = app.otherElements["stats.row.seen_types"].value as? String ?? ""
        XCTAssertTrue(seen.hasSuffix("/43"), "los personajes conocidos se cuentan contra los 43: \(seen)")
        XCTAssertFalse(seen.hasPrefix("1/"), "con --uitest-seen-types hay más de un tipo visto: \(seen)")
        // Y el piso máximo llega con NOMBRE, no con su id (trampa 5).
        let floor = app.otherElements["stats.row.max_floor"].value as? String ?? ""
        XCTAssertFalse(floor.contains("tower.floor."), "el piso llegó como clave cruda: \(floor)")
    }

    // MARK: Logros

    @MainActor
    func testCobrarUnLogroLoPasaACobrado() throws {
        let app = launch(extraArguments: ["--uitest-achievements"])
        openMenu(app)
        app.buttons["menu.card.achievements"].tap()

        // El fixture siembra los contadores de estos tres. Se prueba con el
        // primero que esté cobrable: si el catálogo se reordena, el test sigue
        // midiendo lo mismo.
        let candidates = ["ach_merges_1", "ach_taps_1000", "ach_videos_1"]
        var target: String?
        for id in candidates where app.buttons["ach.claim.\(id)"].waitForExistence(timeout: 10) {
            target = id
            break
        }
        attach(app, named: "T15 logros con premios para cobrar")
        let claimable = try XCTUnwrap(target, "el fixture --uitest-achievements no dejó ningún logro cobrable")

        let row = app.otherElements["ach.row.\(claimable)"]
        XCTAssertTrue(row.exists, "la fila del logro cobrable no existe")
        XCTAssertEqual(row.value as? String, "unlocked", "el logro sembrado tiene que estar sin cobrar")

        app.buttons["ach.claim.\(claimable)"].tap()

        // El valor de la fila es el estado, sin traducir a propósito: es lo
        // único que se puede comparar con la app en inglés.
        let claimed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "claimed"),
            object: app.otherElements["ach.row.\(claimable)"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [claimed], timeout: 10), .completed,
                       "cobrar el logro no cambió su estado a claimed")
        attach(app, named: "T15 logro cobrado")

        // Y el botón de cobrar se fue: cobrar es de una sola vía.
        XCTAssertFalse(app.buttons["ach.claim.\(claimable)"].exists,
                       "el botón de cobrar sigue ahí después de cobrar")
    }

    // MARK: Andamio

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extraArguments
        app.launch()
        return app
    }

    /// Abre el tab del menú y espera a que la grilla esté en pantalla.
    @MainActor
    private func openMenu(_ app: XCUIApplication) {
        let tab = app.buttons["hud.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "la barra inferior nunca apareció")
        // ⚠️ Tocable y no sólo existente: la barra existe debajo de cualquier
        // hoja que esté cerrándose, y el toque caería sobre el contenido de la
        // hoja en vuelo (precedente `BottomMenuUITests`).
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: tab
        )
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed,
                       "el tab del menú nunca quedó tocable")
        tab.tap()
        XCTAssertTrue(app.buttons["menu.card.orgchart"].waitForExistence(timeout: 10),
                      "el menú no abrió su grilla")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
