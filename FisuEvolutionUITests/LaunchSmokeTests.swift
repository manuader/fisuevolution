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
    // piso se cambia arrastrando el tablero o por el ascensor. El observable
    // del piso actual es `board.floor`, que publica el ID crudo (a prueba de
    // la trampa 6) y sobrevive a las celebraciones que apagan la UI.
    //
    // ⚠️ El value de las filas del ascensor —que también dice "estás acá",
    // para VoiceOver— NO sirve de observable: XCUITest no surfacea el
    // accessibilityValue de esos Buttons (medido 2026-08-18: las diez filas
    // devuelven cadena vacía aunque VoiceOver las lea bien). El estás-acá se
    // queda porque es para personas; los tests leen board.floor.

    /// El piso visible, como ID crudo.
    @MainActor
    private func visibleFloor(_ app: XCUIApplication) -> String {
        (app.otherElements["board.floor"].value as? String) ?? ""
    }

    /// Espera a que `board.floor` publique (o abandone) un ID.
    @MainActor
    private func waitFloor(_ app: XCUIApplication, equals expected: String?,
                           otherThan stale: String? = nil,
                           timeout: TimeInterval) -> Bool {
        let element = app.otherElements["board.floor"]
        let predicate: NSPredicate
        if let expected {
            predicate = NSPredicate(format: "value == %@", expected)
        } else {
            predicate = NSPredicate(format: "value != %@", stale ?? "")
        }
        let reached = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
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

        let floor = app.otherElements["board.floor"]
        XCTAssertTrue(floor.waitForExistence(timeout: 15), "board.floor nunca apareció")
        let home = visibleFloor(app)
        XCTAssertFalse(home.isEmpty, "board.floor tiene que publicar el piso inicial")

        // Subir al preview del piso bloqueado.
        dragBoard(app, fromY: 0.45, toY: 0.75)
        XCTAssertTrue(waitFloor(app, equals: nil, otherThan: home, timeout: 5),
                      "el arrastre hacia abajo tenía que subir al preview; sigue en \(visibleFloor(app))")
        let preview = visibleFloor(app)

        // Y NO más arriba: un segundo arrastre no puede saltear otro piso
        // bloqueado. Se le da tiempo real a equivocarse antes de mirar.
        dragBoard(app, fromY: 0.45, toY: 0.75)
        _ = waitFloor(app, equals: nil, otherThan: preview, timeout: 3)
        XCTAssertEqual(visibleFloor(app), preview,
                       "el preview permitió saltear un segundo piso bloqueado")

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

        let floor = app.otherElements["board.floor"]
        XCTAssertTrue(floor.waitForExistence(timeout: 15), "board.floor nunca apareció")
        let home = visibleFloor(app)
        XCTAssertFalse(home.isEmpty)

        // Centro del campo vacío: el arrastre no debe iniciar tap/drag de
        // unidad. Hacia abajo = subir un piso.
        dragBoard(app, fromY: 0.45, toY: 0.75)
        XCTAssertTrue(waitFloor(app, equals: nil, otherThan: home, timeout: 5),
                      "el arrastre hacia abajo tenía que subir un piso; sigue en \(visibleFloor(app))")

        // Y la vuelta: hacia arriba = bajar.
        dragBoard(app, fromY: 0.75, toY: 0.45)
        XCTAssertTrue(waitFloor(app, equals: home, timeout: 5),
                      "el arrastre de vuelta tenía que devolver a \(home); quedó \(visibleFloor(app))")
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
