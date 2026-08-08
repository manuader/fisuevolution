import XCTest

/// RF-02b: la tienda tiene qué vender.
///
/// El pedido del playtest era literal —"el icono del carrito tiene que tener
/// compras con plata (no tiene ninguna)"—, así que lo que hay que probar es que
/// las filas **están** cuando se abre el carrito de verdad. Los tests unitarios
/// prueban qué acredita cada pack; esto prueba que se pueden ver y tocar.
///
/// ⚠️ Todo se asserta por accessibility identifier: el runner corre la app en
/// inglés aunque el idioma de desarrollo sea `es` (trampa 6 del HANDOFF), así
/// que un assert sobre "Puñado de Plata" pasaría por no encontrar nunca nada.
final class StoreUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openStore() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let store = app.buttons["hud.store"]
        XCTAssertTrue(store.waitForExistence(timeout: 20), "el botón del carrito nunca apareció")
        store.tap()
        return app
    }

    /// La lista es perezosa: una fila que no está a la vista no existe en el
    /// árbol de accesibilidad, así que buscarla exige scrollear. Sin esto el
    /// test fallaría por los productos de abajo aunque la tienda esté completa.
    @MainActor
    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists { return true }
            app.swipeUp()
        }
        return element.exists
    }

    @MainActor
    func testTheStoreSellsCoinPacksOroPacksAndTheStarterPack() throws {
        let app = openStore()

        let ids = [
            "starter_pack",
            "remove_ads",
            "coins_small",
            "coins_medium",
            "coins_large",
            "oro_small",
            "oro_medium",
            "oro_large",
            "skin_mundialista",
            "skin_parrillero",
        ]
        for id in ids {
            let buy = app.buttons["store.buy.com.fisuevolution.iap.\(id)"]
            XCTAssertTrue(
                scrollUntilVisible(buy, in: app),
                "\(id) no se ofrece en la tienda"
            )
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RF-02b la tienda con los packs"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// La otra mitad del pedido: que las filas digan qué dan. El número sale
    /// calculado contra la partida, así que no puede vivir en el `.storekit`.
    @MainActor
    func testEachPackSaysWhatItGives() throws {
        let app = openStore()

        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "RF-02b la tienda al abrirla"
        top.lifetime = .keepAlways
        add(top)

        for id in ["starter_pack", "coins_small", "oro_small"] {
            let reward = app.staticTexts["store.reward.com.fisuevolution.iap.\(id)"]
            XCTAssertTrue(
                scrollUntilVisible(reward, in: app),
                "\(id) no dice qué te da"
            )
        }

        // Y lo que no es pack no inventa una línea: su descripción la pone
        // StoreKit y duplicarla sería una segunda fuente de verdad.
        XCTAssertFalse(
            app.staticTexts["store.reward.com.fisuevolution.iap.remove_ads"].exists,
            "quitar los ads no es un pack y no debería tener línea calculada"
        )
    }
}
