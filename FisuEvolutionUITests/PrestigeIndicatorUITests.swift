import XCTest

/// RF-16: el jugador tiene que poder ver qué compra reencarnar. Este test mira
/// la PANTALLA, no el modelo: que el indicador del HUD exista y crezca, y —la
/// trampa 5 del HANDOFF, que ya salió mal dos veces en este repo— que ninguna
/// clave `prestige.*` termine cruda a la vista por interpolar mal un `%@`.
final class PrestigeIndicatorUITests: XCTestCase {
    /// Nada en la pantalla puede ser una clave de localización sin traducir.
    @MainActor
    private func assertNoRawKeys(_ app: XCUIApplication, context: String) {
        for label in app.staticTexts.allElementsBoundByIndex.map(\.label)
        where label.hasPrefix("prestige.") || label.hasPrefix("hud.prestige") {
            XCTFail("\(context): la clave salió cruda en pantalla — \(label)")
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPrestigeIndicatorGrowsAndPopupNeverShowsRawKeys() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-prestige"]
        app.launch()

        // El indicador es PERMANENTE y muestra el antes → después mientras haya
        // ORO por cobrar.
        let indicator = app.otherElements["hud.prestige.multiplier"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 15), "el indicador del HUD nunca apareció")
        let firstLife = indicator.value as? String ?? ""
        XCTAssertTrue(firstLife.contains("→"), "sin flecha no se ve qué compra reencarnar: \(firstLife)")
        assertNoRawKeys(app, context: "HUD de la primera vida")
        attach(app, named: "RF-16 indicador permanente del HUD")

        let prestige = app.buttons["hud.prestige"]
        XCTAssertTrue(prestige.waitForExistence(timeout: 5), "el botón de reencarnar nunca apareció")
        prestige.tap()

        let arrow = app.otherElements["prestige.multiplier"]
        XCTAssertTrue(arrow.waitForExistence(timeout: 5), "el popup no muestra el antes/después")
        assertNoRawKeys(app, context: "popup de reencarnación")
        attach(app, named: "RF-16 popup: el antes y el después")

        app.buttons["prestige.confirm"].tap()

        // Confirmado: el "después" que prometía el popup ya es el multiplicador
        // vigente, y sin ORO por cobrar la flecha se retira.
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", firstLife), object: indicator
        )
        XCTAssertEqual(XCTWaiter().wait(for: [settled], timeout: 10), .completed,
                       "el indicador no siguió a las proyecciones")
        let afterPrestige = indicator.value as? String ?? ""
        XCTAssertFalse(afterPrestige.contains("→"),
                       "recién reencarnado no queda nada por cobrar: \(afterPrestige)")

        // Segunda vida sobre el mismo save: ahora el "antes" ya no es ×1, que es
        // el caso que el popup tiene que saber contar.
        app.launchArguments = ["--uitest-prestige"]
        app.launch()
        XCTAssertTrue(indicator.waitForExistence(timeout: 15))
        let secondLife = indicator.value as? String ?? ""
        XCTAssertTrue(secondLife.contains("→"), "la segunda vida vuelve a tener ORO por cobrar")
        XCTAssertFalse(secondLife.hasPrefix("×1,0 "), "el antes ya no puede ser ×1: \(secondLife)")

        prestige.tap()
        XCTAssertTrue(arrow.waitForExistence(timeout: 5))
        assertNoRawKeys(app, context: "popup de la segunda vida")
        attach(app, named: "RF-16 segunda vida: el antes ya no es ×1")
    }
}
