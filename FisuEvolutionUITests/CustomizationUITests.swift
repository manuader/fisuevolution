import XCTest

/// **Pintas** (spec §7): el Customization Shop.
///
/// Lo que prueba y por qué ESO: que la pantalla **cambia lo que el personaje
/// lleva puesto**. Un smoke de "la hoja abre y tiene tarjetas" pasaría con una
/// grilla decorativa; lo que hace falta saber es que el botón de una tarjeta
/// mueve el estado de las OTRAS — porque equipar una pinta es, en el modelo,
/// sacarle la puesta a otra.
///
/// ⚠️ Todo va por accessibility identifier y **ningún assert mira texto
/// traducido**: el runner corre la app en INGLÉS aunque el idioma de desarrollo
/// sea `es` (trampa 6 del HANDOFF). Para saber que una tarjeta quedó "puesta" se
/// compara su valor contra el de la tarjeta que estaba puesta antes: el string
/// sale del catálogo en el idioma que sea, y la igualdad vale en los dos.
final class CustomizationUITests: XCTestCase {
    /// El Fisura: tier 1, primero del carrusel y el que la pantalla elige sola.
    private static let firstType = "homeless"
    /// El Cartonero: tier 4, también visto con `--uitest-seen-types`. Sirve para
    /// probar que tocar OTRA cara cambia la grilla.
    private static let otherType = "cartonero"
    /// Su skin de milestone, acreditada por `--uitest-skins`.
    private static let ownedSkin = "second_life"
    /// La camiseta: skin paga del Fisura, la única fila que se compra.
    private static let paidSkin = "mundialista"
    /// La skin del Cartonero, que llega por el mismo fixture.
    private static let otherSkin = "urban_trailblazer"

    @MainActor
    func testPonerseUnaPintaSeLaSacaALaQueEstabaPuesta() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-seen-types", "--uitest-skins"
        ]
        app.launch()

        // Desde f541bde la pantalla abre en el personaje MÁS NUEVO: para
        // assertar sobre las pintas del Fisura hay que elegirlo primero.
        openSkins(app)
        selectCharacter(app, id: Self.firstType)
        let base = app.otherElements["skins.row.base"]
        XCTAssertTrue(base.waitForExistence(timeout: 10))
        let owned = app.otherElements["skins.row.\(Self.ownedSkin)"]
        XCTAssertTrue(owned.waitForExistence(timeout: 10), "falta la tarjeta de la skin ganada")
        let equip = app.buttons["skins.equip.\(Self.ownedSkin)"]
        XCTAssertTrue(equip.waitForExistence(timeout: 10), "la skin ganada no ofrece ponérsela")

        // ⚠️ La captura va ANTES de todo assert (trampa 9a-bis): un assert que
        // corta se lleva puesta la evidencia, y lo que hace falta ver cuando esto
        // falla es si la pantalla está bien y el roto es el árbol de AX.
        attach(app, named: "T11 Pintas abierta")

        // La tarjeta es UNA parada de VoiceOver, no cuatro: el resumen reemplaza
        // a sus textos en vez de sumarse a ellos.
        //
        // ⚠️ Esto es además el guardián de una trampa concreta: con `LazyVGrid`
        // —la forma obvia de escribir una grilla de dos columnas— el
        // `accessibilityHidden` de la tarjeta **deja de podar** y el nombre, el
        // badge y el preview vuelven a ser elementos sueltos (medido volcando el
        // árbol el 2026-08-15). Si alguien cambia el `VStack` de filas por una
        // grilla perezosa, este assert se pone rojo.
        //
        // ⚠️ El nombre contra el que se compara sale del propio árbol
        // (`owned.label` = el nombre de la pinta ya traducido al idioma del
        // runner) y no de un literal: los nombres de skin SÍ salen del catálogo
        // de strings, así que escribir "Segunda vida" sería la trampa 6.
        let skinName = owned.label
        XCTAssertFalse(skinName.isEmpty, "la tarjeta tiene que anunciarse con el nombre de la pinta")
        XCTAssertFalse(app.staticTexts[skinName].exists,
                       "el nombre de la pinta no puede ser su propio elemento de AX: lo anuncia la tarjeta")
        XCTAssertTrue(equip.exists, "el silenciado de la tarjeta no puede borrar su botón")

        // El estado "puesta" no se asserta por su texto (que el runner traduce):
        // se lee de la tarjeta que HOY está puesta —la original— y se compara.
        let equippedValue = try XCTUnwrap(base.value as? String, "la tarjeta no publica su estado como valor")
        XCTAssertFalse(equippedValue.isEmpty)
        XCTAssertNotEqual(owned.value as? String, equippedValue,
                          "una skin que sólo tenés no puede publicar el mismo estado que la que está puesta")

        equip.tap()

        // Y ahora la puesta es la otra: mismo valor, y el botón de ponérsela se
        // fue (la que ya está puesta no se vuelve a poner).
        let becameEquipped = XCTNSPredicateExpectation(
            predicate: NSPredicate { element, _ in
                ((element as? XCUIElement)?.value as? String) == equippedValue
            },
            object: owned
        )
        let equipped = XCTWaiter().wait(for: [becameEquipped], timeout: 10) == .completed
        attach(app, named: "T11 Pintas despues de ponerse la skin")
        XCTAssertTrue(equipped,
                      "la skin equipada tenía que quedar como la puesta; quedó en \(owned.value ?? "?") (esperaba \(equippedValue))")
        XCTAssertFalse(app.buttons["skins.equip.\(Self.ownedSkin)"].exists,
                       "la que ya está puesta no puede seguir ofreciendo ponérsela")
        XCTAssertNotEqual(base.value as? String, equippedValue,
                          "la original tenía que dejar de estar puesta: sólo una pinta a la vez")
        XCTAssertTrue(app.buttons["skins.equip.base"].exists,
                      "sin botón en la original no hay forma de volver a la apariencia de siempre")
    }

    /// El carrusel: quién se puede elegir, quién no, y que elegir CAMBIA la
    /// grilla de abajo.
    @MainActor
    func testElCarruselCambiaDePersonajeYLoNuncaVistoNoSeElige() throws {
        let app = XCUIApplication()
        // ⚠️ Este va **sin** `--uitest-skins`: es el estado en el que el jugador
        // encuentra la pantalla por primera vez —todas las pintas por ganar— y es
        // el único de los dos que ejerce (y fotografía) la tarjeta bloqueada con
        // su condición.
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-seen-types"
        ]
        app.launch()

        _ = openSkins(app)
        let first = app.buttons["skins.character.\(Self.firstType)"]
        XCTAssertTrue(first.waitForExistence(timeout: 10), "el carrusel no dibujó al primer personaje")
        // Desde f541bde el default es el personaje más nuevo: este test razona
        // desde la grilla del Fisura, así que lo elige explícitamente.
        first.tap()
        attach(app, named: "T11 carrusel de personajes")

        // Lo nunca visto se dibuja en silueta pero NO es un botón: elegirlo
        // espoilearía la cadena de evolución (RF-03). El Oficinista es tier 9,
        // fuera del alcance de `--uitest-seen-types`.
        XCTAssertFalse(app.buttons["skins.character.oficinista"].exists,
                       "un personaje que nunca viste no se puede elegir")

        // El Fisura es el que la pantalla eligió sola: su camiseta está en la
        // grilla y la del Cartonero no.
        XCTAssertTrue(app.otherElements["skins.row.\(Self.paidSkin)"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["skins.row.\(Self.otherSkin)"].exists,
                       "la grilla tiene que mostrar UN personaje por vez")

        let other = app.buttons["skins.character.\(Self.otherType)"]
        XCTAssertTrue(other.exists, "el Cartonero está visto: tiene que poder elegirse")
        other.tap()

        let otherRow = app.otherElements["skins.row.\(Self.otherSkin)"]
        XCTAssertTrue(otherRow.waitForExistence(timeout: 10),
                      "elegir otra cara tiene que cambiar la grilla de abajo")
        attach(app, named: "T11 grilla del segundo personaje")
        XCTAssertFalse(app.otherElements["skins.row.\(Self.paidSkin)"].exists,
                       "la grilla del personaje anterior tenía que irse")
        // La base está siempre: es cómo se vuelve a la apariencia de siempre.
        XCTAssertTrue(app.otherElements["skins.row.base"].exists)
    }

    /// La tienda que no contesta: una skin PAGA sin precio no puede decir que no
    /// está a la venta.
    ///
    /// Acompaña al finding de la ronda 1: `price(for:) == nil` mandaba la tarjeta
    /// al mismo lugar que una skin de milestone sin cumplir —desaturada, con
    /// candado y "Todavía no está a la venta"—, así que una falla de red
    /// terminaba **afirmando algo falso sobre la skin**.
    ///
    /// ⚠️ **Qué pinea este test y qué NO.** Pinea la ESTRUCTURA: que la tarjeta
    /// siga en la grilla sin precio, que no ofrezca comprar, y que publique un
    /// estado propio. **No pinea el texto ni el tono**, y conviene no creer que
    /// sí: el defecto viejo ya publicaba un valor distinto al de la bloqueada
    /// ("Not for sale yet" contra "Reach reincarnation 1"), así que el
    /// `assertNotEqual` de abajo **habría pasado igual con el bug puesto**. Queda
    /// porque cubre la regresión de mañana —que alguien vuelva a resolver el
    /// "sin precio" como un `milestoneLocked`— y no la de ayer.
    ///
    /// Lo que sí prueba el cambio de copy y de tono es la **captura** que este
    /// test adjunta: XCUITest no puede leer la desaturación de una `GameCard`,
    /// y asertar el texto en inglés sería la trampa 6. Ver el reporte, §Fix
    /// ronda 1.
    @MainActor
    func testSinPrecioLaSkinPagaNoDiceQueNoEstaALaVenta() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-seen-types",
            "--uitest-storekit-empty"
        ]
        app.launch()

        _ = openSkins(app)
        selectCharacter(app, id: Self.firstType)
        let paid = app.otherElements["skins.row.\(Self.paidSkin)"]
        XCTAssertTrue(paid.waitForExistence(timeout: 10),
                      "la skin paga tiene que seguir en la grilla aunque no haya precio")
        attach(app, named: "T11 fix — skin paga sin precio (StoreKit vacio)")

        // Sin producto cargado no hay nada que comprar: el botón no se dibuja.
        XCTAssertFalse(app.buttons["store.buy.com.fisuevolution.iap.skin_mundialista"].exists,
                       "sin precio no puede haber botón de compra")

        let paidValue = try XCTUnwrap(paid.value as? String, "la tarjeta no publica su estado")
        XCTAssertFalse(paidValue.isEmpty)

        // La de milestone sin cumplir: ESA sí está legítimamente bloqueada.
        let locked = app.otherElements["skins.row.\(Self.ownedSkin)"]
        XCTAssertTrue(locked.exists, "sin el fixture de skins, la de reencarnación está bloqueada")
        let lockedValue = try XCTUnwrap(locked.value as? String)

        // Guarda de futuro (ver el ⚠️ de arriba: NO es lo que atrapa al bug viejo).
        XCTAssertNotEqual(paidValue, lockedValue,
                          """
                          una skin paga sin precio no puede publicar el mismo estado que una \
                          bloqueada por milestone: la primera dice que falta el precio, la \
                          segunda que falta cumplir la condición. Las dos dicen "\(paidValue)".
                          """)
    }

    /// Abre Pintas y devuelve la tarjeta de la apariencia original, que existe en
    /// toda partida.
    ///
    /// ⚠️ El toque va **por coordenada** y con un reintento, y no es paranoia: en
    /// un simulador recién creado el primer toque sobre la barra inferior se
    /// pierde con `Failed to scroll to visible (by AX action)` —`board.units`, que
    /// es un elemento del tamaño del tablero, aparece listado antes que los
    /// botones y XCUITest cree que hay algo tapándolos (trampa 9a en frío, ya
    /// anotada por la T8)—. Tocar el centro del frame del botón esquiva el
    /// `scrollToVisible` que falla, y el reintento cubre el caso de que la hoja no
    /// llegue a presentarse.
    /// Selecciona un personaje del carrusel y espera su grilla. Existe porque
    /// desde `f541bde` la pantalla abre en el personaje MÁS NUEVO (la lista de
    /// mejoras abre en lo nuevo y Pintas comparte la proyección): un test que
    /// asserta sobre las pintas de un personaje CONCRETO tiene que elegirlo,
    /// no confiar en el orden del default.
    @MainActor
    private func selectCharacter(_ app: XCUIApplication, id: String) {
        let face = app.buttons["skins.character.\(id)"]
        XCTAssertTrue(face.waitForExistence(timeout: 10), "el carrusel no dibujó a \(id)")
        face.tap()
    }

    @MainActor
    @discardableResult
    private func openSkins(_ app: XCUIApplication) -> XCUIElement {
        let tab = app.buttons["hud.skins"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "el tab de Pintas no está en la barra")
        let base = app.otherElements["skins.row.base"]
        for attempt in 0..<3 {
            // Sólo se vuelve a tocar el tab si la hoja NO está arriba: con la hoja
            // abierta, el toque caería sobre SU contenido (trampa 4).
            if !app.buttons["sheet.close"].exists {
                tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            if base.waitForExistence(timeout: attempt == 0 ? 8 : 12) { return base }
        }
        XCTFail("Pintas no abrió: la grilla del primer personaje nunca apareció")
        return base
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
