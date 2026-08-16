import XCTest

/// RF-01: el tutorial ilumina controles reales y avanza **por acción**.
///
/// ⚠️ Todo se asserta por **accessibility identifier** y por valores sin
/// traducir. El runner corre la app en INGLÉS aunque el idioma de desarrollo sea
/// `es` (trampa 6 del HANDOFF): un assert sobre el texto del globo pasaría por
/// no encontrar nunca nada, que es pasar por la razón equivocada.
final class TutorialUITests: XCTestCase {
    /// Partida nueva CON tutorial y con plata para poder contratar. Sin la
    /// plata, el primer paso pide ~50 toques sobre un personaje que deambula.
    @MainActor
    private func launchWithTutorial(coins: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"] + (coins ? ["--uitest-coins"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func stepID(_ app: XCUIApplication) -> String? {
        app.otherElements["tutorial.step"].value as? String
    }

    @MainActor
    private func waitForStep(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 6) -> Bool {
        let marker = app.otherElements["tutorial.step"]
        let reached = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", id), object: marker
        )
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
    }

    /// El recorte publicado por el overlay, en coordenadas de pantalla.
    @MainActor
    private func spotlight(_ app: XCUIApplication) -> CGRect? {
        guard let raw = app.otherElements["tutorial.spotlight"].value as? String else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    // MARK: - El corazón de RF-01

    @MainActor
    func testTocarFueraDelRecorteNoAvanzaYLaAccionSi() throws {
        let app = launchWithTutorial()
        XCTAssertTrue(app.otherElements["tutorial.step"].waitForExistence(timeout: 20),
                      "el tutorial no apareció en una partida nueva")
        XCTAssertEqual(stepID(app), "tap", "el tutorial tiene que arrancar por el paso del tap")

        // Cuatro esquinas, todas fuera del recorte del paso 1 (que está sobre el
        // personaje, abajo a la izquierda). Ninguna puede avanzar el paso.
        for offset in [CGVector(dx: 0.5, dy: 0.06), CGVector(dx: 0.9, dy: 0.5),
                       CGVector(dx: 0.5, dy: 0.95), CGVector(dx: 0.05, dy: 0.5)] {
            app.coordinate(withNormalizedOffset: offset).tap()
        }
        XCTAssertEqual(stepID(app), "tap", "tocar afuera del recorte NO puede avanzar el paso")

        // La acción que el paso pide sí: tocar al personaje iluminado.
        try tapSpotlight(app, advancesTo: "hire")

        // Y el paso siguiente ilumina el tab de FisuJobs, que abre la pantalla
        // donde se contrata de verdad — y contratar vuelve a avanzar.
        try hireFromFisuJobs(app)
        XCTAssertTrue(waitForStep(app, "merge"), "contratar tiene que completar el paso")
    }

    /// El agujero cae sobre el frame REAL del control, no sobre coordenadas
    /// escritas a mano. Es la parte que se rompe sola cuando alguien mueve un
    /// botón, y por eso se compara contra el frame que reporta XCUITest.
    @MainActor
    func testElRecorteCaeSobreElControlDeVerdad() throws {
        let app = launchWithTutorial()
        XCTAssertTrue(app.otherElements["tutorial.step"].waitForExistence(timeout: 20))
        try tapSpotlight(app, advancesTo: "hire")

        let raw = app.otherElements["tutorial.spotlight"].value as? String ?? "<sin marcador>"
        let hole = try XCTUnwrap(spotlight(app),
                                 "el paso de contratar tiene que publicar un recorte, publicó \(raw)")
        // El ancla `.hire` se mudó del botón de spawn al TAB de FisuJobs: el
        // recorte tiene que caer sobre él y no sobre la barra entera.
        let button = app.buttons["hud.hire"].frame
        XCTAssertTrue(hole.contains(CGPoint(x: button.midX, y: button.midY)),
                      "el recorte \(hole) no cubre el centro del tab real \(button)")
        // Y no es un recorte gigante que "contiene todo": tiene que ser el tab.
        XCTAssertLessThan(abs(hole.midX - button.midX), 24, "recorte descentrado en X")
        XCTAssertLessThan(abs(hole.midY - button.midY), 24, "recorte descentrado en Y")
        XCTAssertLessThan(hole.width, button.width * 3,
                          "un recorte del ancho de la barra no enseña cuál de los seis tabs tocar")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "RF-01 recorte sobre el tab de FisuJobs"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// El resto de la pantalla no responde al toque: con el paso de contratar
    /// activo, el botón de mejoras está debajo del scrim y no abre nada.
    @MainActor
    func testElScrimBloqueaLosControlesQueNoSonLosDelPaso() throws {
        let app = launchWithTutorial()
        XCTAssertTrue(app.otherElements["tutorial.step"].waitForExistence(timeout: 20))
        try tapSpotlight(app, advancesTo: "hire")

        // ⚠️ Se toca por COORDENADA sobre el frame real del botón, no con
        // `upgrades.tap()`. Un `.tap()` sobre un elemento que XCUITest considera
        // no-hittable se pasa un minuto reintentando "scroll to visible" y al
        // final prueba igual: el test terminaba pasando, pero tardando 115 s y
        // sin distinguir "el scrim se comió el toque" de "XCUITest se negó a
        // tocar". La coordenada se saltea la hittability y prueba lo que importa.
        //
        // ⚠️ Y ahora el tab de mejoras es el VECINO del que el paso ilumina: el
        // recorte cae sobre FisuJobs y este toque, a un tab de distancia, tiene
        // que seguir muriendo en el scrim.
        let upgrades = app.buttons["hud.upgrades"]
        XCTAssertTrue(upgrades.exists)
        let target = upgrades.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: target.midX, dy: target.midY))
            .tap()
        XCTAssertFalse(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 3),
                       "el scrim tiene que impedir abrir Mejoras durante un paso que no es el suyo")
        XCTAssertEqual(stepID(app), "hire", "y el paso no puede haberse movido")
    }

    // MARK: - El recorrido entero

    @MainActor
    func testRecorreElTutorialEnteroHastaElFinal() throws {
        let app = launchWithTutorial()
        XCTAssertTrue(app.otherElements["tutorial.step"].waitForExistence(timeout: 20))

        try tapSpotlight(app, advancesTo: "hire")

        try hireFromFisuJobs(app)
        XCTAssertTrue(waitForStep(app, "merge"))

        try mergeTheHighlightedPair(app)
        XCTAssertTrue(waitForStep(app, "upgrades", timeout: 8))

        app.buttons["hud.upgrades"].tap()
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 6),
                      "el paso de mejoras tiene que dejar abrir Mejoras")
        dismissSheet(app)
        XCTAssertTrue(waitForStep(app, "map"))

        app.buttons["hud.map"].tap()
        XCTAssertTrue(app.buttons["map.floor.alley"].waitForExistence(timeout: 6),
                      "el paso del mapa tiene que dejar abrir el mapa")
        dismissSheet(app)
        XCTAssertTrue(waitForStep(app, "finish"))

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "RF-01 último paso"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["tutorial.done"].tap()
        XCTAssertFalse(app.otherElements["tutorial.step"].waitForExistence(timeout: 3),
                       "el botón final tiene que cerrar el tutorial")
        // Y con el tutorial cerrado el juego vuelve a responder entero.
        app.buttons["hud.upgrades"].tap()
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 6))
    }

    /// Saltear cierra el tutorial y devuelve la pantalla.
    @MainActor
    func testSaltearCierraElTutorialYDevuelveLosControles() throws {
        let app = launchWithTutorial(coins: false)
        XCTAssertTrue(app.otherElements["tutorial.step"].waitForExistence(timeout: 20))
        app.buttons["tutorial.skip"].tap()
        XCTAssertFalse(app.otherElements["tutorial.step"].waitForExistence(timeout: 3),
                       "saltear tiene que cerrar el tutorial")
        app.buttons["hud.upgrades"].tap()
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 6),
                      "sin tutorial, el HUD tiene que volver a responder")
    }

    // MARK: - Helpers

    /// El paso de contratar, entero: abrir FisuJobs desde el tab iluminado,
    /// contratar al Fisura y cerrar la hoja.
    ///
    /// ⚠️ La hoja se presenta **por encima** del overlay del tutorial, y está
    /// bien: el scrim existe para gobernar el tablero, no para tapar una hoja
    /// modal que el propio paso mandó abrir. El paso se completa apenas
    /// `hireCharacter` marca `ftue.spawned` —o sea con la hoja todavía puesta—,
    /// así que al cerrarla el tutorial ya está en "fusioná".
    @MainActor
    private func hireFromFisuJobs(_ app: XCUIApplication) throws {
        let tab = app.buttons["hud.hire"]
        XCTAssertTrue(tab.waitForExistence(timeout: 6), "el tab de FisuJobs no está en la barra")
        tab.tap()
        let hire = app.buttons["jobs.hire.homeless"]
        XCTAssertTrue(hire.waitForExistence(timeout: 6),
                      "el tab iluminado tiene que abrir FisuJobs con el Fisura contratable")
        hire.tap()
        dismissSheet(app)
    }

    /// Toca el centro del recorte publicado hasta que el paso avanza.
    ///
    /// ⚠️ Reintenta releyendo el recorte, y no porque el tutorial necesite varios
    /// toques: la escena congela el deambular del personaje iluminado, pero
    /// consultar un elemento desde el runner cuesta ~2 s y el primer toque de una
    /// corrida puede llegar mientras la escena todavía está acomodando el campo.
    /// Un toque que cae al lado no hace NADA (no hay nodo ahí), así que reintentar
    /// no puede hacer pasar el test por la razón equivocada — lo que se prueba es
    /// que el paso avanza sólo tocando al personaje, y eso lo cubre el assert de
    /// los cuatro toques afuera.
    @MainActor
    private func tapSpotlight(_ app: XCUIApplication, advancesTo next: String,
                              attempts: Int = 5) throws {
        for _ in 0..<attempts {
            // ⚠️ Se relee el paso ANTES de volver a tocar. Sin esto, un reintento
            // que llega después de que el paso ya avanzó toca el recorte NUEVO
            // —el botón de contratar— y se salta un paso entero: el test quedaba
            // esperando para siempre un "hire" que ya había pasado. Cada consulta
            // al runner cuesta ~1 s, así que la espera se pasa de largo sola.
            if stepID(app) == next { return }
            let hole = try XCTUnwrap(spotlight(app), "el paso no publicó ningún recorte")
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: hole.midX, dy: hole.midY))
                .tap()
            if waitForStep(app, next, timeout: 4) { return }
        }
        XCTFail("tocar el recorte no llevó al paso '\(next)' en \(attempts) intentos")
    }

    /// Fusiona el par iluminado con un doble toque.
    ///
    /// Antes esto arrastraba, y barría **ocho** coordenadas de destino para
    /// conseguirlo: la escena resolvía el drop contra el ANCLA del slot y no
    /// contra dónde estaba parado el personaje, que desde el reconciliador
    /// difieren hasta media celda (trampa 3 del HANDOFF). El doble toque no
    /// necesita puntería en el destino —el compañero lo busca la escena— así que
    /// alcanza con tocar dos veces el recorte, que es la posición real del nodo.
    ///
    /// Se conservan reintentos por la razón de siempre: consultar un elemento
    /// desde el runner cuesta ~2 s y el primer intento de una corrida puede
    /// llegar mientras la escena todavía acomoda el campo. Un doble toque que
    /// cae al lado no hace nada (no hay nodo ahí), así que reintentar no puede
    /// hacer pasar el test por la razón equivocada.
    @MainActor
    private func mergeTheHighlightedPair(_ app: XCUIApplication, attempts: Int = 4) throws {
        let marker = app.otherElements["tutorial.step"]
        for _ in 0..<attempts {
            guard (marker.value as? String) == "merge" else { return }
            guard let hole = spotlight(app) else { continue }
            // El recorte abraza a los DOS del par: su centro puede caer en el
            // aire entre medio. Se apunta al cuerpo del de la izquierda.
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: hole.minX + hole.width * 0.25, dy: hole.midY))
                .doubleTap()
            if waitForStep(app, "upgrades", timeout: 3) { return }
        }
        XCTFail("el doble toque no fusionó el par iluminado en \(attempts) intentos")
    }

    /// Todas las hojas del juego cierran por el mismo `ArtCloseButton`.
    @MainActor
    private func dismissSheet(_ app: XCUIApplication) {
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "la hoja no trae botón de cerrar")
        close.tap()
    }
}
