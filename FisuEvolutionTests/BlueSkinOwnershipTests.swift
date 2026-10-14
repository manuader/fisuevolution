import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Una pinta de blue sobrevive a StoreKit")
@MainActor
struct BlueSkinOwnershipTests {
    private let skin = "pijama"
    private let type = "homeless"

    private func price(_ gameState: GameState) throws -> Int {
        try #require(gameState.content?.skins.bluePrice(of: skin))
    }

    @Test("la sincronización de StoreKit no la borra ni la desequipa")
    func survivesTheSync() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.blue = try price(gameState)
        #expect(gameState.buySkinWithBlue(skinID: skin) == .bought)
        gameState.equipSkin(id: skin, forCharacterType: type)
        #expect(gameState.activeSkinID(forCharacterType: type) == skin)
        gameState.applyStoreEntitlements(removedAds: true, ownedSkins: [])
        #expect(gameState.ownsSkin(skin))
        #expect(gameState.activeSkinID(forCharacterType: type) == skin, "StoreKit no desequipa lo comprado con blue")
        gameState.applyStoreEntitlements(removedAds: false, ownedSkins: ["mundialista"])
        #expect(gameState.ownsSkin(skin))
        #expect(gameState.activeSkinID(forCharacterType: type) == skin)
        #expect(gameState.player?.meta.ownedSkins.contains(skin) == false, "la caché de StoreKit no la hereda")
    }

    @Test("con el blue justo se compra y queda en cero")
    func exactBalance() async throws {
        let gameState = await makeGameState()
        let cost = try price(gameState)
        gameState.player?.meta.blue = cost
        #expect(gameState.buySkinWithBlue(skinID: skin) == .bought)
        #expect(gameState.player?.meta.blue == 0)
        #expect(gameState.player?.meta.engagement.shop.skins.contains(skin) == true)
    }

    @Test("con un blue menos no se cobra ni se entrega")
    func oneShort() async throws {
        let gameState = await makeGameState()
        let cost = try price(gameState)
        gameState.player?.meta.blue = cost - 1
        #expect(gameState.buySkinWithBlue(skinID: skin) == .refused(.cantAfford))
        #expect(gameState.player?.meta.blue == cost - 1)
        #expect(!gameState.ownsSkin(skin))
    }

    @Test("un doble toque cobra una sola vez")
    func secondCallDoesNotCharge() async throws {
        let gameState = await makeGameState()
        let cost = try price(gameState)
        gameState.player?.meta.blue = cost * 3
        #expect(gameState.buySkinWithBlue(skinID: skin) == .bought)
        #expect(gameState.buySkinWithBlue(skinID: skin) == .unavailable)
        #expect(gameState.player?.meta.blue == cost * 2)
        #expect(gameState.player?.meta.stats.blueSpentEver == cost)
    }

    @Test("lo que ya es tuyo por otra vía no se cobra")
    func alreadyOwnedIsFree() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.ownedSkins = [skin]
        gameState.player?.meta.blue = try price(gameState) * 2
        let before = gameState.player?.meta.blue
        #expect(gameState.buySkinWithBlue(skinID: skin) == .unavailable)
        #expect(gameState.player?.meta.blue == before)
    }

    @Test("una pinta sin precio en blue no se vende por blue")
    func notForSale() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.blue = 10_000
        #expect(gameState.buySkinWithBlue(skinID: "mundialista") == .unavailable)
        #expect(gameState.buySkinWithBlue(skinID: "no_existe") == .unavailable)
        #expect(gameState.player?.meta.blue == 10_000)
    }

    @Test("el catálogo la ofrece por su precio y, comprada, deja de ofrecerla")
    func catalogRow() async throws {
        let gameState = await makeGameState()
        let cost = try price(gameState)
        let row = try #require(gameState.skinCatalogRows(forCharacterType: type).first { $0.id == skin })
        #expect(row.state == .bluePurchasable(price: cost))
        gameState.player?.meta.blue = cost
        gameState.buySkinWithBlue(skinID: skin)
        let bought = try #require(gameState.skinCatalogRows(forCharacterType: type).first { $0.id == skin })
        #expect(bought.state == .owned)
    }
}
