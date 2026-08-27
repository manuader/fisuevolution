import XCTest

/// RF-08: el mapa de pisos lleva directo a un piso desbloqueado y no deja tocar
/// los cerrados. Se asserta el EFECTO —qué dice la pill de la torre después del
/// salto— y no que el tap no crashee (trampa 2 del HANDOFF).
final class FloorMapUITests: XCTestCase {
    /// El tutorial arranca tapando la pantalla entera con su scrim y se guarda
    /// en `AppStorage`, así que un test pasa o falla según qué corrió antes en
    /// ese simulador. Estos dos lo sacan de en medio con `--uitest-skip-tutorial`
    /// —el mismo fixture que el resto de la suite— y no tocando "Saltar" en
    /// pantalla. (Sin nada de esto, `hud.map` falla con "Failed to scroll to
    /// visible", que es la trampa 4 del HANDOFF: nunca es el botón.)
    ///
    /// ⚠️ Pasar del "Saltar" al launch argument no es cosmético: saltear TERMINA
    /// la fase obligatoria, y desde el cofre de bienvenida terminar la fase hace
    /// caer un cofre que apaga el HUD hasta que alguien lo cierra. Con el
    /// fixture la fase nunca arranca, así que no hay cofre que atravesar.
    private static let fixture = ["--uitest-reset", "--uitest-unlock-tower", "--uitest-skip-tutorial"]

    @MainActor
    func testElMapaLlevaAlPisoMasAltoDesbloqueado() throws {
        let app = XCUIApplication()
        app.launchArguments = Self.fixture
        app.launch()

        // La píldora se retiró (2026-08-18): el piso visible se lee de
        // `board.floor`, que publica el ID crudo (a prueba de la trampa 6).
        let floor = app.otherElements["board.floor"]
        XCTAssertTrue(floor.waitForExistence(timeout: 15), "board.floor never appeared")
        let startingFloor = (floor.value as? String) ?? ""

        let map = app.buttons["hud.map"]
        XCTAssertTrue(map.waitForExistence(timeout: 5), "map action missing from the HUD")
        map.tap()

        // El fixture abre la torre hasta `urban`: es el piso más alto al que el
        // mapa puede llevar. El id sale de floors[], no de la vista.
        let urban = app.buttons["map.floor.urban"]
        XCTAssertTrue(urban.waitForExistence(timeout: 5), "the map never listed the unlocked floors")
        XCTAssertTrue(urban.isEnabled, "an unlocked floor must be reachable")
        urban.tap()

        let moved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", startingFloor), object: floor
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [moved], timeout: 5), .completed,
            "tapping an unlocked floor must fly the camera there"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RF-08 salto desde el mapa"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testLosPisosBloqueadosNoRespondenAlToque() throws {
        let app = XCUIApplication()
        app.launchArguments = Self.fixture
        app.launch()

        XCTAssertTrue(app.otherElements["board.floor"].waitForExistence(timeout: 15))
        app.buttons["hud.map"].tap()

        // La Luna está muy por encima de lo que el fixture desbloquea: tiene que
        // figurar en la lista (el mapa muestra la torre ENTERA) y no ser un
        // destino. Que el botón esté deshabilitado ES la prueba: tocarlo desde
        // el runner sería un error del test, no una navegación.
        let moon = app.buttons["map.floor.moon"]
        XCTAssertTrue(moon.waitForExistence(timeout: 5), "the map must list locked floors too")
        XCTAssertFalse(moon.isEnabled, "a locked floor must not be tappable")
        // El techo de la torre también, para que el mapa no dependa de dónde
        // caiga el corte de pisos entre versiones.
        XCTAssertFalse(app.buttons["map.floor.god_realm"].isEnabled)
        XCTAssertTrue(app.buttons["map.floor.alley"].isEnabled, "the alley is always open")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RF-08 el mapa de la torre"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
