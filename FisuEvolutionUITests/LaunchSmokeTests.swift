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

    @MainActor
    func testLaunchShowsBoundedTowerNavigator() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15), "tower pill never appeared")
        let down = app.buttons["tower.arrow.down"]
        let up = app.buttons["tower.arrow.up"]
        XCTAssertTrue(down.exists, "down arrow missing")
        XCTAssertTrue(up.exists, "up arrow missing")
        XCTAssertFalse(down.isEnabled, "new game must not navigate below the alley")
        XCTAssertTrue(up.isEnabled, "new game should preview its next locked floor")
    }

    @MainActor
    func testLockedFloorPreviewStopsAtOneFloorAhead() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        let initialLabel = pill.label
        let up = app.buttons["tower.arrow.up"]
        up.tap()
        let reachedPreview = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initialLabel), object: pill
        )
        XCTAssertEqual(XCTWaiter().wait(for: [reachedPreview], timeout: 3), .completed)
        XCTAssertFalse(up.isEnabled, "preview must not allow skipping another locked floor")
        XCTAssertTrue(app.buttons["tower.arrow.down"].isEnabled)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "F7.3 locked-floor-preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testTowerArrowsAndEmptyBoardSwipeNavigateOneFloor() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-unlock-tower", "--uitest-skip-tutorial"]
        app.launch()

        let pill = app.otherElements["tower.pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        let up = app.buttons["tower.arrow.up"]
        XCTAssertTrue(up.isEnabled, "fixture should unlock the urban floor")
        let initialLabel = pill.label

        up.tap()
        let movedByArrow = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initialLabel), object: pill
        )
        XCTAssertEqual(XCTWaiter().wait(for: [movedByArrow], timeout: 3), .completed)
        XCTAssertTrue(app.buttons["tower.arrow.down"].isEnabled)

        // Centro del campo vacío: el swipe no debe iniciar tap/drag de unidad.
        // RF-09: metáfora de scroll — para BAJAR un piso hay que arrastrar la
        // torre hacia ARRIBA. Antes este gesto iba al revés (0.45 → 0.75).
        let swipeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let swipeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        swipeStart.press(forDuration: 0.05, thenDragTo: swipeEnd)
        let returnedBySwipe = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", initialLabel), object: pill
        )
        XCTAssertEqual(XCTWaiter().wait(for: [returnedBySwipe], timeout: 3), .completed)
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
