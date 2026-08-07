import XCTest

/// RF-04: el pasivo se compra desde el menú y el long-press queda para las skins.
///
/// Las dos mitades del pedido se prueban por separado porque viven en pantallas
/// distintas: la fila del menú tiene que **tener** su botón de pasivo, y la ficha
/// del personaje tiene que **no** tenerlo.
final class UpgradesMenuUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Cada fila de Personajes lleva dos botones con identificador estable: uno
    /// sube el multiplicador y otro compra el ingreso pasivo.
    @MainActor
    func testCharacterRowExposesBothButtons() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let upgrades = app.buttons["hud.upgrades"]
        XCTAssertTrue(upgrades.waitForExistence(timeout: 15), "upgrades HUD action never appeared")
        upgrades.tap()

        // Partida nueva: el único tipo visto es el base.
        let multiplier = app.buttons["upgrades.character.homeless.multiplier"]
        let passive = app.buttons["upgrades.character.homeless.passive"]
        XCTAssertTrue(multiplier.waitForExistence(timeout: 5), "la fila perdió el botón de multiplicador")
        XCTAssertTrue(
            passive.waitForExistence(timeout: 5),
            "el pasivo tiene que poder comprarse desde el menú, no sólo manteniendo apretado"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RF-04 dos botones por fila"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// La ficha —lo único que abre el long-press del tablero— quedó como
    /// superficie de skins: ya no vende el pasivo.
    ///
    /// El fixture la abre directo porque el long-press sobre SpriteKit no da
    /// coordenadas estables en el runner (trampa 3 del HANDOFF); lo que se
    /// asserta es el efecto —qué muestra la ficha—, que es lo que el gesto
    /// termina produciendo.
    @MainActor
    func testCharacterSheetNoLongerSellsPassiveIncome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-open-sheet"]
        app.launch()

        XCTAssertTrue(
            app.buttons["character.skin.equip"].waitForExistence(timeout: 15),
            "character sheet skin section never appeared"
        )

        // La sección de pasivo nunca tuvo accessibility identifier, así que
        // asertar su ausencia por id no probaría nada: se busca su copy. El
        // idioma de desarrollo del proyecto es es, y estas dos claves
        // (`passive.title`, `passive.unlock`) son las que la sección mostraba.
        // La sección de pasivo nunca tuvo accessibility identifier, así que se
        // asserta por lo que sí es estable: TODO botón de la ficha tiene que ser
        // uno de los controles conocidos de skins/despedir. El botón de comprar
        // el pasivo aparecía con identificador vacío, así que su vuelta rompe
        // esto. Asertar su copy no serviría: el runner corre la app en inglés
        // aunque el idioma de desarrollo sea es (verificado con un volcado del
        // árbol de accesibilidad).
        let known: Set<String> = [
            "character.skin.previous",
            "character.skin.next",
            "character.skin.equip",
            "character.dismiss",
        ]
        let sheetButtons = app.scrollViews.firstMatch.buttons
        let identifiers = Set((0 ..< sheetButtons.count).map { sheetButtons.element(boundBy: $0).identifier })
        XCTAssertFalse(identifiers.isEmpty, "la ficha no expuso ningún control: el query no encontró la hoja")
        XCTAssertTrue(
            identifiers.isSubset(of: known),
            "la ficha tiene controles que no son de skins (\(identifiers.subtracting(known))); el pasivo se compra en el menú"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RF-04 ficha sólo de skins"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
