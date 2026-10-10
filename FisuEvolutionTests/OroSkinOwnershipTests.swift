import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Una pinta de ORO sobrevive a StoreKit")
@MainActor
struct OroSkinOwnershipTests {
    private let skin = "pijama"
    private let type = "homeless"

    private func price(_ gameState: GameState) throws -> Int {
        try #require(gameState.content?.skins.oroPrice(of: skin))
    }

    @Test("la sincronización de StoreKit no la borra ni la desequipa")
    func survivesTheSync() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = try price(gameState)
        #expect(gameState.buySkinWithOro(skinID: skin) == .bought)
        gameState.equipSkin(id: skin, forCharacterType: type)
        #expect(gameState.activeSkinID(forCharacterType: type) == skin)
        gameState.applyStoreEntitlements(removedAds: true, ownedSkins: [])
        #expect(gameState.ownsSkin(skin))
        #expect(gameState.activeSkinID(forCharacterType: type) == skin, "StoreKit no desequipa lo comprado con ORO")
        gameState.applyStoreEntitlements(removedAds: false, ownedSkins: ["mundialista"])
        #expect(gameState.ownsSkin(skin))
        #expect(gameState.activeSkinID(forCharacterType: type) == skin)
        #expect(gameState.player?.meta.ownedSkins.contains(skin) == false, "la caché de StoreKit no la hereda")
    }

    @Test("con el ORO justo se compra y queda en cero")
    func exactBalance() async throws {
        let gameState = await makeGameState()
        let cost = try price(gameState)
        gameState.player?.meta.oro = cost
        #expect(gameState.buySkinWithOro(skinID: skin) == .bought)
        #expect(gameState.player?.meta.oro == 0)
        #expect(gameState.player?.meta.engagement.shop.skins.contains(skin) == true)
    }

    @Test("con un ORO menos no se cobra ni se entrega")
    func oneShort() async throws {
        let gameState = await makeGameState()
        let cost = try price(gameState)
        gameState.player?.meta.oro = cost - 1
        #expect(gameState.buySkinWithOro(skinID: skin) == .refused(.cantAfford))
        #expect(gameState.player?.meta.oro == cost - 1)
        #expect(!gameState.ownsSkin(skin))
    }

    @Test("un doble toque cobra una sola vez")
    func secondCallDoesNotCharge() async throws {
        let gameState = await makeGameState()
        let cost = try price(gameState)
        gameState.player?.meta.oro = cost * 3
        #expect(gameState.buySkinWithOro(skinID: skin) == .bought)
        #expect(gameState.buySkinWithOro(skinID: skin) == .unavailable)
        #expect(gameState.player?.meta.oro == cost * 2)
        #expect(gameState.player?.meta.stats.oroSpentEver == cost)
    }

    @Test("lo que ya es tuyo por otra vía no se cobra")
    func alreadyOwnedIsFree() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.ownedSkins = [skin]
        gameState.player?.meta.oro = try price(gameState) * 2
        let before = gameState.player?.meta.oro
        #expect(gameState.buySkinWithOro(skinID: skin) == .unavailable)
        #expect(gameState.player?.meta.oro == before)
    }

    @Test("una pinta sin precio en ORO no se vende por ORO")
    func notForSale() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 10_000
        #expect(gameState.buySkinWithOro(skinID: "mundialista") == .unavailable)
        #expect(gameState.buySkinWithOro(skinID: "no_existe") == .unavailable)
        #expect(gameState.player?.meta.oro == 10_000)
    }

    @Test("el catálogo la ofrece por su precio y, comprada, deja de ofrecerla")
    func catalogRow() async throws {
        let gameState = await makeGameState()
        let cost = try price(gameState)
        let row = try #require(gameState.skinCatalogRows(forCharacterType: type).first { $0.id == skin })
        #expect(row.state == .oroPurchasable(price: cost))
        gameState.player?.meta.oro = cost
        gameState.buySkinWithOro(skinID: skin)
        let bought = try #require(gameState.skinCatalogRows(forCharacterType: type).first { $0.id == skin })
        #expect(bought.state == .owned)
    }
}
