import XCTest

/// Smoke test: the app launches, loads its content and shows the HUD.
///
/// ⚠️ `--uitest-skip-tutorial` no es decorativo: es el arreglo de la trampa 9
/// del HANDOFF. `fisuTutorialDone` vive en `UserDefaults` y sobrevivía a
/// `--uitest-reset`, así que estos tests pasaban sólo si antes había corrido el
/// que abre la ficha (que dejaba la bandera puesta de rebote). En un simulador
/// limpio el scrim del tutorial les tapaba los controles y fallaban con un
/// "Failed to scroll to visible" que no era del botón (trampa 4). Ahora cada
/// test DECLARA en qué estado quiere el tutorial y ninguno depende del orden.
final class LaunchSmokeTests: XCTestCase {
    @MainActor
    func testLaunchShowsCoinHUD() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let coins = app.otherElements["hud.coins"]
        XCTAssertTrue(coins.waitForExistence(timeout: 15), "HUD coin counter never appeared")
    }

    // MARK: Navegación de pisos sin píldora
    //
    // La fila de torre del HUD se retiró (decisión del dueño 2026-08-18): el
    // piso se cambia arrastrando el tablero o por el ascensor. El piso ACTUAL
    // ya no tiene elemento propio en el HUD: vive en el value de su fila del
    // ascensor ("estás acá", `visibleAwareValue`). Los tests de acá abajo leen
    // ESO, comparando los values de las filas entre dos momentos — nunca texto
    // traducido, que es la trampa 6 (el runner corre la app en inglés).

    /// Abre el ascensor, junta identifier→value de todas las filas y lo
    /// cierra. Es el "dónde estoy" de estos tests.
    @MainActor
    private func floorMapValues(_ app: XCUIApplication) -> [String: String] {
        app.buttons["hud.map"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'map.floor.'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8), "el ascensor no mostró filas")
        var values: [String: String] = [:]
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            values[row.identifier] = (row.value as? String) ?? ""
        }
        app.buttons["sheet.close"].tap()
        // El próximo gesto tiene que caer al TABLERO: esperar a que la hoja
        // termine de cerrarse (el botón del HUD vuelve a ser hittable).
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 8), "la hoja del ascensor no cerró")
        return values
    }

    /// Arrastre vertical en el centro del campo vacío. RF-09, metáfora de
    /// scroll: arrastrar hacia ABAJO (0.45 → 0.75) SUBE un piso; hacia ARRIBA
    /// (0.75 → 0.45) BAJA.
    @MainActor
    private func dragBoard(_ app: XCUIApplication, fromY: CGFloat, toY: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    func testLockedFloorPreviewStopsAtOneFloorAhead() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 15))

        let atAlley = floorMapValues(app)

        // Subir al preview del piso bloqueado: el "estás acá" tiene que mudarse
        // (exactamente dos filas cambian su value: la que lo pierde y la que lo
        // gana).
        dragBoard(app, fromY: 0.45, toY: 0.75)
        let atPreview = floorMapValues(app)
        let movedRows = atAlley.keys.filter { atAlley[$0] != atPreview[$0] }
        XCTAssertEqual(movedRows.count, 2, "el estás-acá tenía que mudarse de una fila a otra; cambiaron: \(movedRows)")

        // Y NO más arriba: un segundo arrastre no puede saltear otro piso
        // bloqueado. Los values quedan idénticos al preview.
        dragBoard(app, fromY: 0.45, toY: 0.75)
        let afterSecondDrag = floorMapValues(app)
        XCTAssertEqual(atPreview, afterSecondDrag, "el preview permitió saltear un segundo piso bloqueado")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "F7.3 locked-floor-preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testBoardSwipeNavigatesOneFloorEachWay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-unlock-tower", "--uitest-skip-tutorial"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 15))

        let initial = floorMapValues(app)

        // Centro del campo vacío: el arrastre no debe iniciar tap/drag de
        // unidad. Hacia abajo = subir un piso.
        dragBoard(app, fromY: 0.45, toY: 0.75)
        let up = floorMapValues(app)
        XCTAssertNotEqual(initial, up, "el arrastre hacia abajo tenía que subir un piso")

        // Y la vuelta: hacia arriba = bajar.
        dragBoard(app, fromY: 0.75, toY: 0.45)
        let back = floorMapValues(app)
        XCTAssertEqual(initial, back, "el arrastre de vuelta tenía que devolver al piso inicial")
    }

    @MainActor
    func testUpgradesExposePermanentOroPurchase() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let upgrades = app.buttons["hud.upgrades"]
        XCTAssertTrue(upgrades.waitForExistence(timeout: 15), "upgrades HUD action never appeared")
        upgrades.tap()

        let permanentTab = app.buttons["upgrades.tab.permanent"]
        XCTAssertTrue(permanentTab.waitForExistence(timeout: 5), "permanent upgrades tab never appeared")
        permanentTab.tap()

        XCTAssertTrue(
            app.buttons["upgrades.permanent.income"].waitForExistence(timeout: 5),
            "an ORO permanent upgrade must remain accessible by a stable identifier"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "F7.4 permanent ORO upgrades"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// La ficha es la superficie canónica por personaje (§3.10): retrato, pager
    /// de apariencias y equipar. El fixture la abre directo porque el long-press
    /// sobre SpriteKit no da coordenadas estables en el runner.
    @MainActor
    func testCharacterSheetExposesSkinPager() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-open-sheet"]
        app.launch()

        let next = app.buttons["character.skin.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15), "character sheet skin pager never appeared")
        XCTAssertTrue(app.buttons["character.skin.previous"].exists)

        // La base es la posición 0: sólo se puede avanzar.
        XCTAssertFalse(app.buttons["character.skin.previous"].isEnabled)
        XCTAssertTrue(next.isEnabled, "the base look must not be the only entry of the pager")
        next.tap()
        XCTAssertTrue(app.buttons["character.skin.previous"].isEnabled)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "F7.5 character sheet"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
