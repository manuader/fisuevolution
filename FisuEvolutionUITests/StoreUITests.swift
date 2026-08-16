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

    /// Busca una fila, scrolleando si hace falta.
    ///
    /// ⚠️ Desde la T12 la tienda **no es una `List`**: es un `ScrollView` con un
    /// `VStack` (no `LazyVStack`), así que las diez tarjetas existen en el árbol
    /// de accesibilidad sin scrollear y esto devuelve `true` en la primera
    /// vuelta. Los deslizamientos quedan igual a propósito: son la red que
    /// atrapa el día en que la columna se vuelva perezosa —por diez productos
    /// más, o por un `LazyVStack` de vuelta— sin que este test tenga que
    /// enterarse. Lo que se asserta es lo mismo de siempre: que la fila ESTÁ.
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

        attach(app, named: "RF-02b la tienda con los packs")

        // Y el fondo de la vidriera, que es donde viven las skins con su
        // preview: XCUITest no puede leer si el retrato de la Mundialista se
        // dibujó, así que lo único que prueba ese pedazo del rediseño es la
        // captura. Sin este deslizamiento la única evidencia visual de la
        // pantalla sería su encabezado.
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        attach(app, named: "T12 la góndola de skins")
    }

    /// La otra mitad del pedido: que las filas digan qué dan. El número sale
    /// calculado contra la partida, así que no puede vivir en el `.storekit`.
    @MainActor
    func testEachPackSaysWhatItGives() throws {
        let app = openStore()

        attach(app, named: "RF-02b la tienda al abrirla")

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

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
