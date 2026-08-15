import XCTest

/// **FisuJobs** (spec §5.1): la pantalla de contratación por personaje.
///
/// Lo que prueba y por qué ESO: que contratar desde la tienda mueve las **dos**
/// cosas que tienen que moverse —el precio de la fila (la curva de crecimiento
/// por tipo) y el tablero (la unidad existe de verdad)—. Con una sola de las dos
/// el test pasaría con media feature: un botón que cobra sin poner al personaje,
/// o un personaje que aparece a precio fijo para siempre.
///
/// ⚠️ Todo va por accessibility identifier. El runner corre la app en INGLÉS
/// aunque el idioma de desarrollo sea `es` (trampa 6 del HANDOFF), así que un
/// assert sobre texto en español pasaría por no encontrar NADA nunca. Por eso el
/// valor de `jobs.row.<id>` de una fila contratable es el precio pelado ("50"),
/// que no se traduce.
final class FisuJobsUITests: XCTestCase {
    /// El Fisura: el único tipo visto en una partida nueva, así que su fila es
    /// la primera de "Vacantes abiertas" y no hace falta scrollear para verla.
    private static let firstType = "homeless"
    /// El Mantero, tier 5 → piso `urban`, que en una partida nueva está cerrado.
    private static let lockedType = "mantero"
    /// El Oficinista, tier 9: fuera del alcance de `--uitest-seen-types`.
    private static let unseenType = "oficinista"

    @MainActor
    func testContratarSubeElPrecioDeLaFilaYPoneLaUnidadEnElTablero() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 20), "el tablero nunca apareció")
        let unitsBefore = units.value as? String

        let tab = app.buttons["hud.hire"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "el tab de FisuJobs no está en la barra")
        tab.tap()

        let row = app.otherElements["jobs.row.\(Self.firstType)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "FisuJobs no dibujó la fila del Fisura")
        let hire = app.buttons["jobs.hire.\(Self.firstType)"]
        XCTAssertTrue(hire.waitForExistence(timeout: 10), "la fila del Fisura no ofrece contratar")
        scrollIntoView(hire, in: app)

        // ⚠️ La captura va ANTES de todo assert (trampa 9a-bis): un assert que
        // corta se lleva puesta la evidencia, y lo que hace falta ver cuando
        // esto falla es si la pantalla está bien y el roto es el árbol de AX.
        attach(app, named: "T8 FisuJobs abierta")

        // La tarjeta es UNA parada de VoiceOver, no cinco: el resumen de la fila
        // reemplaza a sus textos en vez de sumarse a ellos. Si alguien saca el
        // `.accessibilityHidden(true)` de la columna de datos, el nombre vuelve a
        // ser un elemento suelto y esto se pone rojo.
        //
        // ⚠️ Asertar sobre "El Fisura" NO es la trampa 6: los nombres de
        // personaje salen de `tiers.json` como dato y son el MISMO string en las
        // dos localizaciones (el runner corre en inglés y la captura los muestra
        // en español igual). Lo que no se puede asertar es texto del catálogo.
        XCTAssertFalse(app.staticTexts["El Fisura"].exists,
                       "el nombre no puede ser su propio elemento de AX: lo anuncia la fila")
        // Y el botón tiene que seguir siendo la SEGUNDA parada: tapar los datos
        // no puede llevarse puesto el único control de la tarjeta.
        XCTAssertTrue(hire.exists, "el silenciado de la fila no puede borrar el botón de contratar")

        // El valor de la fila contratable ES su precio. Se lee antes de tocar
        // porque después de contratar ya no se puede recuperar.
        let priceBefore = row.value as? String
        XCTAssertNotNil(priceBefore, "la fila tiene que publicar su precio como valor de accesibilidad")
        XCTAssertFalse(priceBefore?.isEmpty ?? true, "la fila publicó un precio vacío")

        hire.tap()

        // El precio de contratar crece con cada compra del MISMO tipo (growth
        // del piso, 1,2 en el callejón: 50 → 60). Si no se mueve, la compra no
        // llegó al contador por tipo y el personaje sale siempre lo mismo.
        let priceGrew = XCTNSPredicateExpectation(
            predicate: NSPredicate { element, _ in
                ((element as? XCUIElement)?.value as? String) != priceBefore
            },
            object: row
        )
        let grew = XCTWaiter().wait(for: [priceGrew], timeout: 10) == .completed
        attach(app, named: "T8 FisuJobs después de contratar")
        XCTAssertTrue(grew,
                      "el precio de la fila tenía que subir después de contratar; quedó en \(row.value ?? "?") (era \(priceBefore ?? "?"))")

        app.buttons["sheet.close"].tap()

        // Y el tablero es el único testigo de que la compra salió del modelo.
        let unitsGrew = XCTNSPredicateExpectation(
            predicate: NSPredicate { element, _ in
                ((element as? XCUIElement)?.value as? String) != unitsBefore
            },
            object: units
        )
        XCTAssertEqual(XCTWaiter().wait(for: [unitsGrew], timeout: 10), .completed,
                       "contratar tiene que sumar una unidad al tablero; quedó en \(units.value ?? "?") (era \(unitsBefore ?? "?"))")
    }

    /// Las tres clases de fila conviven en la misma lista y cada una se
    /// distingue por su valor: la contratable publica un precio (dígitos), y las
    /// otras dos publican un mensaje de estado.
    ///
    /// ⚠️ El assert es "hay dígitos" / "no hay dígitos" y **no** el texto: el
    /// runner traduce al inglés y comparar contra "Se abre en Ciudad" pasaría
    /// por no encontrarlo jamás (trampa 6).
    ///
    /// `--uitest-seen-types` marca vistos hasta el tier 8 y es lo que hace que
    /// las tres secciones tengan contenido a la vez: los tiers 1-4 son del
    /// callejón (abierto → contratables), los 5-8 de la ciudad (vista pero con
    /// el piso cerrado → bloqueadas) y de ahí para arriba nadie los vio nunca.
    @MainActor
    func testLasFilasBloqueadasPublicanEstadoEnVezDePrecio() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins", "--uitest-seen-types"
        ]
        app.launch()

        let tab = app.buttons["hud.hire"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "el tab de FisuJobs no está en la barra")
        tab.tap()

        let hirable = app.otherElements["jobs.row.\(Self.firstType)"]
        XCTAssertTrue(hirable.waitForExistence(timeout: 10), "FisuJobs no dibujó la fila del Fisura")
        attach(app, named: "T8 FisuJobs, arriba de todo")

        XCTAssertTrue(hasDigits(hirable.value as? String),
                      "una fila contratable publica su precio, y este dice \(hirable.value ?? "?")")

        // El Mantero es tier 5: visto por el fixture, pero su piso —la ciudad—
        // todavía no está abierto. Es la primera fila de la sección cerrada.
        let locked = app.otherElements["jobs.row.\(Self.lockedType)"]
        XCTAssertTrue(locked.waitForExistence(timeout: 10),
                      "FisuJobs tiene que listar también lo que todavía no se puede contratar")
        scrollIntoView(locked, in: app)
        attach(app, named: "T8 FisuJobs, seccion cerrada")

        let lockedValue = locked.value as? String
        XCTAssertFalse(hasDigits(lockedValue),
                       "una fila bloqueada no ofrece precio: tiene que decir su estado, y dice \(lockedValue ?? "?")")
        XCTAssertFalse(app.buttons["jobs.hire.\(Self.lockedType)"].exists,
                       "una fila bloqueada no puede tener botón de contratar")

        // Y el Oficinista es tier 9: nunca visto, así que su tarjeta va en
        // silueta, sin nombre y sin rendimiento.
        let unseen = app.otherElements["jobs.row.\(Self.unseenType)"]
        XCTAssertTrue(unseen.waitForExistence(timeout: 10),
                      "FisuJobs tiene que listar también las búsquedas confidenciales")
        scrollIntoView(unseen, in: app)
        attach(app, named: "T8 FisuJobs, seccion confidencial")

        XCTAssertFalse(hasDigits(unseen.value as? String),
                       "una fila nunca vista no publica precio, y dice \(unseen.value ?? "?")")
        XCTAssertFalse(app.buttons["jobs.hire.\(Self.unseenType)"].exists,
                       "una fila nunca vista no puede tener botón de contratar")

        // El texto EN PANTALLA de una fila confidencial es "???" —el misterio es
        // el diseño—, pero VoiceOver lee eso como puntuación. El nombre hablado
        // sale de una clave propia. Se asserta "no es ??? y no está vacío" en vez
        // del texto traducido, que sería la trampa 6.
        let spokenName = unseen.label
        XCTAssertFalse(spokenName.isEmpty, "una fila confidencial tiene que anunciarse con algo")
        XCTAssertNotEqual(spokenName, "???",
                          "\"???\" no es pronunciable: la fila confidencial necesita un label hablable")
    }

    // MARK: Helpers

    /// ¿El valor trae dígitos? Es lo que separa un precio ("50", "1,2M") de un
    /// mensaje de estado en CUALQUIER idioma.
    @MainActor
    private func hasDigits(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.rangeOfCharacter(from: .decimalDigits) != nil
    }

    /// Sube el elemento a la pantalla si quedó abajo. La lista de FisuJobs no es
    /// perezosa —las 43 tarjetas existen en el árbol de AX apenas abre—, pero
    /// existir no es estar VISIBLE: un elemento fuera del viewport no es
    /// `hittable` y `.tap()` se pasa ~60 s reintentando antes de tocar igual
    /// (trampa 9c).
    @MainActor
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
