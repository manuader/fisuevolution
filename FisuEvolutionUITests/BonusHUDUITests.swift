import XCTest

/// Activar un boost dejaba de tener rastro apenas se cerraba el panel: ni el
/// efecto ni cuánto le faltaba. El contador tiene que quedar en pantalla, con
/// el juego corriendo detrás.
///
/// ⚠️ `--uitest-skip-tutorial` por la trampa 9 del HANDOFF: sin él, en un
/// simulador limpio el scrim se come los toques.
final class BonusHUDUITests: XCTestCase {
    @MainActor
    func testActivatingABoostShowsItsCounterOnTheHUD() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let chip = app.otherElements["hud.bonus.chip"]
        XCTAssertTrue(app.buttons["hud.bonus"].waitForExistence(timeout: 15))
        XCTAssertFalse(chip.exists, "sin ningún bonus corriendo no puede haber contador")

        app.buttons["hud.bonus"].tap()
        // El mate arranca desbloqueado (se abre en el callejón) y sin cooldown.
        let activate = app.buttons["bonus.activate.mate"]
        XCTAssertTrue(activate.waitForExistence(timeout: 6), "el mate tiene que estar disponible en una partida nueva")
        activate.tap()
        app.buttons["sheet.close"].tap()

        // La captura va ANTES de los asserts: si el chip no está, lo que hace
        // falta es ver la pantalla, y un assert que corta se lleva puesta la
        // evidencia. Así se encontró que el chip se dibujaba perfecto y el que
        // fallaba era el árbol de accesibilidad.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "contador de boost activo"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertTrue(chip.waitForExistence(timeout: 6),
                      "el boost activado tiene que dejar su contador en el HUD")
        // El mate descuenta el costo de contratar: su magnitud 0,7 se lee −30%,
        // y el valor lleva además el tiempo que le queda.
        let value = try XCTUnwrap(chip.value as? String)
        XCTAssertTrue(value.contains("30%"), "el chip tiene que decir qué hace, dijo '\(value)'")
        XCTAssertTrue(value.contains("s") || value.contains(":"),
                      "y cuánto le queda, dijo '\(value)'")
    }

    /// Dos bonus corriendo son dos contadores, y de dos orígenes distintos: el
    /// mate es un boost y el ×2 viene de un video. Además fija el orden — primero
    /// el que vence, que es el que urge.
    @MainActor
    func testTwoBonusesShowAtTheSameTime() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        XCTAssertTrue(app.buttons["hud.bonus"].waitForExistence(timeout: 15))
        app.buttons["hud.bonus"].tap()

        let activateMate = app.buttons["bonus.activate.mate"]
        XCTAssertTrue(activateMate.waitForExistence(timeout: 6))
        activateMate.tap()

        // El video del stub tarda 2 s y siempre paga: ×2 a los ingresos por 120 s.
        // ⚠️ Su fila vive abajo de los seis boosts. `BonusView` era una `List`
        // perezosa y la fila **no existía** hasta scrollear; desde que
        // `GiftsView` la reemplazó —`ScrollView` con `VStack` NO perezoso— existe
        // desde el vamos y lo que falta es que entre en la ventana. El bucle mira
        // `isHittable` y no `exists`: con `exists` no deslizaba nunca y el toque
        // caía sobre una fila fuera de pantalla. **Los asserts por id no se
        // tocaron** — el plan sólo autoriza ajustar la navegación.
        let watch = app.buttons["ads.watch.double_earnings"]
        XCTAssertTrue(watch.waitForExistence(timeout: 6), "la fila del video tiene que estar")
        for _ in 0..<6 where !watch.isHittable {
            app.swipeUp()
        }
        watch.tap()
        XCTAssertTrue(app.staticTexts["ads.cooldown.double_earnings"].waitForExistence(timeout: 15)
                        || app.otherElements["ads.cooldown.double_earnings"].waitForExistence(timeout: 1),
                      "el video tiene que terminar y dejar la fila en cooldown")
        app.buttons["sheet.close"].tap()

        let chips = app.otherElements.matching(identifier: "hud.bonus.chip")
        let two = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 2"), object: chips
        )
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "dos contadores a la vez"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertEqual(XCTWaiter().wait(for: [two], timeout: 8), .completed,
                       "dos bonus corriendo son dos contadores, hubo \(chips.count)")

        // El mate dura 60 s y el video 120: primero el mate.
        let first = try XCTUnwrap(chips.element(boundBy: 0).value as? String)
        XCTAssertTrue(first.contains("30%"), "arriba va el que vence primero, había '\(first)'")
    }

    /// **El circuito entero del cofre, de punta a punta.** Es lo único que
    /// prueba que el sistema está ENCHUFADO: hasta esta tarea `openChest()`
    /// existía y no lo llamaba ningún botón, así que los cofres se acumulaban
    /// invisibles y el jugador no tenía cómo abrirlos.
    ///
    /// El recorrido son las tres piezas, en el orden en que las ve el jugador:
    /// el puntito aparece en la pestaña, la tarjeta ofrece el cofre adentro de
    /// Regalos, y el botón lo abre.
    ///
    /// ⚠️ **`--uitest-chest-manual` apaga el reloj de los cuatro latidos**, que
    /// de fábrica avanzan solos a los 1,2 s. Sin él, el testigo de "el botón
    /// abrió el cofre" —el área tappable en pantalla— se desvanece sola mientras
    /// el test la mira, y el assert se vuelve una carrera contra el reloj en vez
    /// de una prueba del botón. Es el mismo motivo por el que lo usa
    /// `ChestOpeningUITests`, visto desde la otra punta.
    ///
    /// ⚠️ **El cofre se gana DESPUÉS del launch, por la puerta de debug**, y no
    /// con un fixture de arranque: el puntito cuelga de una proyección publicada
    /// (`hasPendingChests`) y un cofre que ya existe al primer frame no distingue
    /// una proyección viva de una lectura muerta.
    @MainActor
    func testElCofreSeGanaSeVeYSeAbreDesdeRegalos() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-chest-manual"]
        app.launch()

        let regalos = app.buttons["hud.bonus"]
        XCTAssertTrue(regalos.waitForExistence(timeout: 15))
        XCTAssertTrue(Self.valor(regalos).isEmpty,
                      "sin cofres guardados la pestaña no puede tener puntito")

        // El cofre, por la puerta de debug: la vía real son dos pisos
        // desbloqueados o un video con cooldown.
        let debug = app.buttons["hud.debug"]
        XCTAssertTrue(debug.waitForExistence(timeout: 6))
        debug.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let regalar = app.buttons["debug.chest.award"]
        XCTAssertTrue(regalar.waitForExistence(timeout: 6),
                      "el panel tiene que ofrecer un cofre SIN abrirlo")
        regalar.tap()

        let conPuntito = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != ''"), object: regalos
        )
        XCTAssertEqual(XCTWaiter().wait(for: [conPuntito], timeout: 8), .completed,
                       "un cofre esperando tiene que encender el puntito de la pestaña")
        let puntito = XCTAttachment(screenshot: app.screenshot())
        puntito.name = "cofre: el puntito en la pestaña"
        puntito.lifetime = .keepAlways
        add(puntito)

        // La tarjeta, PRIMERA de la pantalla: sin scrollear.
        regalos.tap()
        let fila = app.otherElements["gifts.chest.row"]
        XCTAssertTrue(fila.waitForExistence(timeout: 8),
                      "la tarjeta del cofre tiene que abrir la pantalla de Regalos")
        XCTAssertTrue(fila.label.contains("1"), "y decir cuántos hay esperando")
        let abrir = app.buttons["gifts.chest.open"]
        XCTAssertTrue(abrir.isHittable, "el botón de abrir tiene que estar a mano, sin deslizar")
        let tarjeta = XCTAttachment(screenshot: app.screenshot())
        tarjeta.name = "cofre: la tarjeta en Regalos"
        tarjeta.lifetime = .keepAlways
        add(tarjeta)

        abrir.tap()

        // ⚠️ `isHittable` y no `exists`: la animación vive en el `ZStack` de
        // `RootView` y Regalos es un `.sheet`, o sea que se presenta POR ENCIMA.
        // Un botón que abriera el cofre sin cerrar la hoja dejaría la animación
        // existiendo debajo, invisible y sorda a los toques — y la cola trabada
        // con el HUD apagado, porque `.chestOpening` no tiene timeout.
        let area = app.buttons["chest.tap"]
        XCTAssertTrue(area.waitForExistence(timeout: 8),
                      "el botón de la tarjeta tiene que abrir el cofre")
        let seToca = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == 1"), object: area
        )
        XCTAssertEqual(XCTWaiter().wait(for: [seToca], timeout: 8), .completed,
                       "la animación quedó debajo de la hoja de Regalos: el botón no la cerró")
        let animacion = XCTAttachment(screenshot: app.screenshot())
        animacion.name = "cofre: abierto desde la tarjeta"
        animacion.lifetime = .keepAlways
        add(animacion)

        // Y el cofre gastado apaga el puntito: los cuatro toques de siempre y
        // la salida por su botón.
        area.tap()
        area.tap()
        area.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chest.card"].waitForExistence(timeout: 8))
        area.tap()
        let salir = app.buttons["chest.dismiss"]
        XCTAssertTrue(salir.waitForExistence(timeout: 8))
        salir.tap()

        let sinPuntito = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == ''"), object: regalos
        )
        XCTAssertEqual(XCTWaiter().wait(for: [sinPuntito], timeout: 10), .completed,
                       "gastado el último cofre, el puntito tiene que apagarse")

        // Y la tarjeta se retira con él: la sección existe mientras haya cofres,
        // no desde que hubo uno. Sin este assert, una tarjeta pegada para
        // siempre —ofreciendo abrir lo que ya no está— pasaría entera.
        regalos.tap()
        XCTAssertTrue(app.otherElements["gifts.row.mate"].waitForExistence(timeout: 8),
                      "la hoja de Regalos tiene que haber vuelto a abrirse")
        XCTAssertFalse(fila.exists, "sin cofres guardados no puede quedar la tarjeta del cofre")
    }

    /// El `value` de un elemento, ya normalizado: sin puntito el juego publica
    /// `Text(verbatim: "")` y XCUITest lo devuelve indistintamente como cadena
    /// vacía o como `nil`.
    @MainActor
    private static func valor(_ element: XCUIElement) -> String {
        (element.value as? String) ?? ""
    }
}
