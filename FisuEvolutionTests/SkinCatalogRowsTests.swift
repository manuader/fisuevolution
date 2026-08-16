import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La proyección del Customization Shop (spec §7): qué skins se ofrecen por
/// personaje y en qué estado.
///
/// Lo que estos tests protegen no es el orden de una grilla: es **qué se puede
/// tocar y qué dice cada tarjeta**. Tres cosas concretas, y las tres se rompen
/// en silencio:
///
/// 1. **Los textos de condición llegan RESUELTOS.** `LocalizedStringKey` no
///    resuelve claves armadas por interpolación (trampa 5 del HANDOFF), así que
///    la condición se arma acá con `String(localized:)`. Si alguien la vuelve a
///    mudar a la vista, en pantalla queda "skins.unlock.floor" crudo — y eso no
///    lo detecta ningún compilador.
/// 2. **El producto de una skin paga es el DEDICADO, no el combo.** `mundialista`
///    la venden DOS productos (`skin_mundialista` y el `starter_pack`, que la
///    trae adentro): ofrecer el combo cuando el jugador quiere la skin le cobra
///    de más.
/// 3. **Tener una skin no es tenerla puesta.** Son dos estados distintos y sólo
///    uno de los dos muestra el botón de equipar.
@Suite("Customization: el catálogo de skins por personaje", .serialized)
@MainActor
struct SkinCatalogRowsTests {
    private func rows(_ gameState: GameState, _ typeID: String) -> [SkinCatalogRow] {
        gameState.skinCatalogRows(forCharacterType: typeID)
    }

    private func row(_ gameState: GameState, _ typeID: String, _ skinID: String) throws -> SkinCatalogRow {
        try #require(
            rows(gameState, typeID).first { $0.id == skinID },
            "no hay fila \(skinID) para \(typeID)"
        )
    }

    // MARK: La forma de la grilla

    @Test("la apariencia base es la primera fila y arranca puesta")
    func baseComesFirstAndStartsEquipped() async throws {
        let gameState = await makeGameState()

        let rows = rows(gameState, "homeless")

        // El Fisura tiene dos skins en el catálogo: una de reencarnación y una
        // paga. La base va delante de las dos y no se persiste como id.
        #expect(rows.map(\.id) == ["base", "second_life", "mundialista"])
        let base = try #require(rows.first)
        #expect(base.state == .equipped, "sin skin activa, la que está puesta es la base")
        #expect(base.textureKey == nil, "la base no tiene textura: es el arte del personaje")
        #expect(!base.displayName.isEmpty)
        #expect(!base.displayName.contains("skins."), "quedó la clave cruda en el nombre")
    }

    @Test("un tipo que no existe no tiene nada que personalizar")
    func unknownTypeHasNoRows() async throws {
        let gameState = await makeGameState()

        #expect(rows(gameState, "no_existe").isEmpty)
        // `junior` es el nodo de elección de carrera, no un personaje.
        #expect(rows(gameState, "junior").isEmpty)
    }

    @Test("cada fila trae el nombre y la textura ya resueltos")
    func rowsCarryResolvedNameAndTexture() async throws {
        let gameState = await makeGameState()

        let skin = try row(gameState, "homeless", "second_life")
        #expect(skin.textureKey == "homeless_idle__second_life")
        #expect(!skin.displayName.isEmpty)
        #expect(!skin.displayName.contains("skin.name"), "el nombre llegó como clave, no como texto")
    }

    // MARK: Los cuatro estados

    @Test("una skin de piso bloqueada dice a dónde hay que llegar, con el piso resuelto")
    func lockedFloorSkinResolvesItsCondition() async throws {
        let gameState = await makeGameState()

        // El Cartonero desbloquea su skin al abrir la Ciudad, que en una partida
        // nueva está cerrada.
        let skin = try row(gameState, "cartonero", "urban_trailblazer")

        guard case .milestoneLocked(let text) = skin.state else {
            Issue.record("una skin de milestone sin cumplir tiene que salir bloqueada, y salió \(skin.state)")
            return
        }
        #expect(!text.contains("skins.unlock"), "quedó la clave cruda en pantalla")
        #expect(!text.contains("tower.floor"), "el nombre del piso llegó como clave, no como texto")
        #expect(text.contains(TowerNaming.floorName(for: "urban")),
                "la condición tiene que nombrar el piso; dice \"\(text)\"")
    }

    @Test("una skin de reencarnación dice cuántas vidas faltan")
    func prestigeSkinResolvesItsCondition() async throws {
        let gameState = await makeGameState()

        let skin = try row(gameState, "homeless", "second_life")

        guard case .milestoneLocked(let text) = skin.state else {
            Issue.record("con prestigio 0 la skin de reencarnación tiene que estar bloqueada, y salió \(skin.state)")
            return
        }
        #expect(!text.contains("skins.unlock"), "quedó la clave cruda en pantalla")
        #expect(text.contains("1"), "la condición tiene que decir el número; dice \"\(text)\"")
    }

    @Test("una skin paga se ofrece con SU producto, no con el combo que la trae adentro")
    func purchasableSkinPointsAtItsOwnProduct() async throws {
        let gameState = await makeGameState()

        let skin = try row(gameState, "homeless", "mundialista")

        #expect(skin.state == .purchasable(productID: "com.fisuevolution.iap.skin_mundialista"))
        // El starter pack también entrega `mundialista`. Si la fila apuntara al
        // combo, el jugador que quiere la camiseta pagaría el pack entero.
        if case .purchasable(let productID) = skin.state {
            #expect(productID != "com.fisuevolution.iap.starter_pack")
        }
    }

    @Test("una skin ganada queda 'la tenés' hasta que te la ponés")
    func grantedSkinBecomesOwnedThenEquipped() async throws {
        let gameState = await makeGameState()

        gameState.grantMilestoneSkinsForTests(["second_life"])

        #expect(try row(gameState, "homeless", "second_life").state == .owned)
        #expect(try row(gameState, "homeless", "base").state == .equipped)

        gameState.equipSkin(id: "second_life", forCharacterType: "homeless")

        #expect(try row(gameState, "homeless", "second_life").state == .equipped)
        #expect(try row(gameState, "homeless", "base").state == .owned,
                "la base no desaparece al equipar otra: es cómo se vuelve atrás")
    }

    @Test("una skin comprada deja de estar a la venta")
    func purchasedSkinIsNoLongerForSale() async throws {
        let gameState = await makeGameState()

        // Es el camino real: StoreKit es la fuente de verdad y el save cachea.
        gameState.applyStoreEntitlements(removedAds: false, ownedSkins: ["mundialista"])

        #expect(try row(gameState, "homeless", "mundialista").state == .owned)
    }

    @Test("equipar en un personaje no le mueve el estado a otro")
    func equippingIsPerCharacter() async throws {
        let gameState = await makeGameState()
        gameState.grantMilestoneSkinsForTests(["second_life", "parrillero"])

        gameState.equipSkin(id: "second_life", forCharacterType: "homeless")

        #expect(try row(gameState, "homeless", "second_life").state == .equipped)
        #expect(try row(gameState, "god", "parrillero").state == .owned)
        #expect(try row(gameState, "god", "base").state == .equipped)
    }
}
