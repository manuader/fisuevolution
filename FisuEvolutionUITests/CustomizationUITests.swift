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
    /// El Fisura: tier 1 y primero del carrusel. ⚠️ **No es el que la pantalla
    /// elige sola** desde f541bde (el default es el personaje más nuevo): los
    /// tests que razonan desde su grilla lo tocan explícitamente.
    private static let firstType = "homeless"
    /// El Cartonero: tier 4, también visto con `--uitest-seen-types`. Sirve para
    /// probar que tocar OTRA cara cambia la grilla.
    private static let otherType = "cartonero"
    /// Su skin de milestone, acreditada por `--uitest-skins`.
    private static let ownedSkin = "second_life"
    /// La camiseta: skin paga del Fisura, la única fila que se compra.
    private static let paidSkin = "mundialista"
    /// La skin del Cartonero. ⚠️ **NO llega por `--uitest-skins`**: desde los
    /// cofres es `chestRarity: comun` y ese fixture filtra por `isMilestone`.
    /// Los tests de abajo la usan BLOQUEADA, que es lo que la grilla dibuja.
    private static let otherSkin = "urban_trailblazer"
    /// La Deidad (tier 36) y su pinta legendaria: el personaje de tier más alto
    /// que reparten los cofres, o sea lo que `--uitest-unseen-skin` elige. Van
    /// como literal —igual que las tres de arriba— porque XCUITest no puede
    /// preguntarle al catálogo; si algún día la cima del catálogo cambia, esto
    /// se pone rojo y hay que releerla acá.
    private static let unseenType = "deidad"
    private static let unseenSkin = "oraculo"
    /// El Empleado de Fast Food: tier 8, el más nuevo que marca
    /// `--uitest-seen-types` y por lo tanto el aterrizaje por defecto con ese
    /// fixture. Celda 8 de 43: fuera del cuadro con el carrusel en cero.
    private static let landingType = "fast_food"

    @MainActor
    func testPonerseUnaPintaSeLaSacaALaQueEstabaPuesta() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-seen-types", "--uitest-skins"
        ]
        app.launch()

        // Desde f541bde la pantalla abre en el personaje más nuevo que VISTE
        // —con este fixture, el de tier 8—: para assertar sobre las pintas del
        // Fisura hay que elegirlo primero.
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

        // Con el Fisura recién elegido: su camiseta está en la grilla y la del
        // Cartonero no.
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

    /// **La pinta que ganaste sin conocer al personaje.**
    ///
    /// Desde los cofres, el sorteo puede darte la pinta de la Deidad a los
    /// veinte minutos de partida, y `run.seenTypes` además **muere al
    /// reencarnar**. Con el filtro de Mejoras, esa pinta quedaba ganada y sin
    /// ficha donde ponérsela: la cara no estaba en el carrusel.
    ///
    /// ⚠️ **Es el único test que ejerce el criterio DESDE LA VISTA.** Los
    /// unitarios pinean `skinnableTypes`; si `CustomizationView` volviera a leer
    /// `characterUpgradeTypes` —que es de dónde venía y que a propósito NO
    /// cambió—, todos ellos seguirían verdes y sólo se pondría rojo acá.
    ///
    /// El fixture no marca vistos: la run ve al Fisura y a nadie más, así que
    /// todo lo que aparezca además de él llegó por la colección.
    ///
    /// ⚠️ Y ejerce las DOS mitades, que son opuestas y se pisan si una se
    /// implementa sin la otra: la Deidad **entra en la lista** (la unión) pero
    /// **la pantalla NO abre en ella** (el aterrizaje sigue siendo lo último que
    /// el jugador vio). Un test que sólo mirara la primera se pondría verde con
    /// la pantalla abriendo en un desconocido.
    @MainActor
    func testUnaPintaGanadaTraeSuPersonajeAlCarruselAunqueNoLoHayasVisto() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-unseen-skin"
        ]
        app.launch()

        openSkins(app)

        // La cara de la Deidad EXISTE y es un botón. `exists` no scrollea, así
        // que esto no depende de dónde esté parado el carrusel — y con
        // `characterUpgradeTypes` puesta no existiría en absoluto.
        let cara = app.buttons["skins.character.\(Self.unseenType)"]
        let hayCara = cara.waitForExistence(timeout: 10)
        // La grilla del Fisura: `mundialista` es SU pinta paga y de nadie más,
        // así que su presencia dice en quién abrió la pantalla sin leer un solo
        // texto traducido (trampa 6).
        let delFisura = app.otherElements["skins.row.\(Self.paidSkin)"]
        let abrioEnElFisura = delFisura.waitForExistence(timeout: 10)
        // La captura va ANTES de todo assert que pueda cortar (trampa 9a-bis).
        attach(app, named: "T10 la pinta de un personaje nunca visto, en el carrusel")
        XCTAssertTrue(hayCara,
                      "la pinta es suya y es tuya: su cara tiene que estar y tiene que poder tocarse")
        XCTAssertTrue(abrioEnElFisura,
                      "la pantalla tiene que abrir en el más nuevo VISTO, que en esta run es el Fisura")
        XCTAssertFalse(app.otherElements["skins.row.\(Self.unseenSkin)"].exists,
                       "abrir en la Deidad es aterrizar en un desconocido: la unión manda en la lista, no acá")

        // RF-03 sigue en pie: lo que NO trajo una pinta sigue en silueta y sin
        // botón. El Oficinista es tier 9 y esta run no vio a nadie más que al
        // Fisura.
        XCTAssertFalse(app.buttons["skins.character.oficinista"].exists,
                       "un personaje del que no tenés nada sigue sin poder elegirse")

        // Y elegirla lleva a SU grilla, que es lo que hace que la pinta ganada
        // se pueda poner: verla en el carrusel sin poder llegar a ella sería el
        // mismo bug con otra cara.
        // XCUITest, para tocar una cara fuera del cuadro, scrollea TODOS los scrolls
        // de arriba, y el del menú deslizable lo sacaría de Pintas. Se la trae a
        // la vista a mano, deslizando sólo el carrusel (la mitad S2 del paginador).
        let cuadro = app.windows.firstMatch.frame
        let tira = app.buttons["skins.character.\(Self.firstType)"].frame.midY
        for _ in 0..<12 where !cuadro.contains(cara.frame) {
            let window = app.windows.firstMatch
            let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: tira / cuadro.height))
            let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: tira / cuadro.height))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        cara.tap()
        let pinta = app.otherElements["skins.row.\(Self.unseenSkin)"]
        let llego = pinta.waitForExistence(timeout: 10)
        attach(app, named: "T10 la grilla del personaje nunca visto")
        XCTAssertTrue(llego, "elegir su cara tiene que traer la grilla de la Deidad")

        let base = app.otherElements["skins.row.base"]
        let equippedValue = try XCTUnwrap(base.value as? String, "la tarjeta no publica su estado como valor")
        let equip = app.buttons["skins.equip.\(Self.unseenSkin)"]
        XCTAssertTrue(equip.waitForExistence(timeout: 10), "la pinta ganada tiene que ofrecer ponérsela")
        equip.tap()

        let quedoPuesta = XCTNSPredicateExpectation(
            predicate: NSPredicate { element, _ in
                ((element as? XCUIElement)?.value as? String) == equippedValue
            },
            object: pinta
        )
        let puesta = XCTWaiter().wait(for: [quedoPuesta], timeout: 10) == .completed
        attach(app, named: "T10 la pinta del personaje nunca visto, puesta")
        XCTAssertTrue(puesta,
                      "la pinta tenía que quedar puesta; quedó en \(pinta.value ?? "?") (esperaba \(equippedValue))")
    }

    /// **La cara elegida tiene que estar EN PANTALLA al abrir.**
    ///
    /// El carrusel son 43 celdas de 82 pt y en un iPhone entran cuatro y media,
    /// así que a partir del quinto personaje el marco amarillo cae fuera del
    /// cuadro: la pantalla dice a quién estás vistiendo y la tira no muestra
    /// nada resaltado. Con `--uitest-seen-types` el aterrizaje es el Empleado de
    /// Fast Food (tier 8, celda 8), que con el scroll en 0 no se ve.
    ///
    /// ⚠️ **No mide `exists`**: los 43 EXISTEN siempre (el `HStack` no es
    /// perezoso, y de eso se ocupa el otro test). Lo que mide es si la celda cae
    /// **dentro del cuadro de la pantalla**, que es lo único que distingue el
    /// carrusel scrolleado del carrusel en su lugar.
    ///
    /// ⚠️⚠️ **Y tampoco mide `isHittable`, que es lo que uno escribiría.**
    /// Mientras el carrusel está animando su scroll, XCUITest puede no poder
    /// calcular el punto de activación de una celda, y entonces `isHittable`
    /// **tira** en vez de contestar que no: *"Failed to determine hittability:
    /// Activation point invalid and no suggested hit points based on element
    /// frame"*. Eso convierte una espera —que reintentaría— en un error duro, y
    /// puso este test rojo en una corrida con la máquina cargada. El **marco** sí
    /// se puede leer siempre, y dice lo mismo que la pregunta quiere decir.
    @MainActor
    func testElCarruselAbreMostrandoLaCaraElegida() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-seen-types", "--uitest-unseen-skin"
        ]
        app.launch()

        openSkins(app)

        let elegida = app.buttons["skins.character.\(Self.landingType)"]
        XCTAssertTrue(elegida.waitForExistence(timeout: 10), "el carrusel no dibujó al aterrizaje")

        // El cuadro se toma UNA vez y como valor: el bloque del predicado corre
        // muchas veces y la ventana no se mueve.
        let cuadro = app.windows.firstMatch.frame
        // Se espera en vez de medirse una sola vez: el carrusel llega animando.
        let aLaVista = XCTNSPredicateExpectation(
            predicate: NSPredicate { elemento, _ in
                guard let marco = (elemento as? XCUIElement)?.frame else { return false }
                return Self.centroDentro(marco, de: cuadro)
            },
            object: elegida
        )
        let seVe = XCTWaiter().wait(for: [aLaVista], timeout: 10) == .completed
        attach(app, named: "T10 fix — el carrusel abre mostrando la cara elegida")
        XCTAssertTrue(seVe, """
            la cara en la que abre la pantalla tiene que estar a la vista: es la \
            única que lleva el marco amarillo, y con el carrusel en cero queda \
            fuera del cuadro.
            """)
        // Y el primero del catálogo, que es donde el carrusel arrancaba, quedó
        // detrás: si esto siguiera a la vista, no se scrolleó nada.
        XCTAssertFalse(
            Self.centroDentro(app.buttons["skins.character.\(Self.firstType)"].frame, de: cuadro),
            "el carrusel tenía que haberse movido, y el Fisura quedó igual en pantalla"
        )
    }

    /// ¿El centro de esta celda cae adentro de la pantalla?
    ///
    /// El **centro** y no una intersección cualquiera: una celda asomando un
    /// punto por el borde no está "a la vista" en ningún sentido útil. Un marco
    /// vacío es la respuesta de XCUITest para lo que está recortado del scroll, y
    /// cuenta como fuera.
    ///
    /// Recibe el marco YA leído y no el elemento: `XCUIElement.frame` está
    /// aislado al main actor y esto se llama también desde el bloque de un
    /// `NSPredicate`, que no lo está. Con la geometría del lado de afuera, la
    /// cuenta es pura y no hay isolation que negociar.
    private static func centroDentro(_ marco: CGRect, de cuadro: CGRect) -> Bool {
        guard marco.width > 0, marco.height > 0 else { return false }
        return cuadro.contains(CGPoint(x: marco.midX, y: marco.midY))
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
    /// desde `f541bde` la pantalla abre en el más nuevo que el jugador VIO
    /// (`defaultSkinnableType`), no en el primero del catálogo: un test que
    /// asserta sobre las pintas de un personaje CONCRETO tiene que elegirlo, no
    /// confiar en el orden del default.
    ///
    /// ⚠️ Pintas **ya no comparte proyección con Mejoras** —la de acá suma los
    /// personajes de los que tenés una pinta sin haberlos visto— y el aterrizaje
    /// tampoco sale de esa lista. Con los fixtures de este archivo las dos
    /// coinciden, y por eso los tests siguen valiendo; el día que uno acredite
    /// una pinta de alguien no visto, deja de coincidir.
    ///
    /// ⚠️⚠️ Y desde el auto-scroll del carrusel, el Fisura **ya no está en
    /// pantalla** al abrir con `--uitest-seen-types`: la tira se centra en el
    /// aterrizaje (tier 8). Este `tap()` se apoya entonces en el
    /// `scrollToVisible` automático de XCUITest sobre un scroll horizontal —el
    /// mismo mecanismo que `openSkins` documenta como frágil en frío—. Corre
    /// verde, pero es superficie de flakiness nueva: si algún día uno de estos
    /// tres tests empieza a fallar en `tap()`, es acá donde hay que mirar.
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
