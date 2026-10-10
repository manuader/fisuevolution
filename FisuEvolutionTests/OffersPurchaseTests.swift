import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Comprar una oferta")
@MainActor
struct OffersPurchaseTests {
    private func entry(_ offerId: String) throws -> ProductCatalog.Entry {
        try #require(try ProductCatalog.load(from: .main).products.first { $0.offerId == offerId })
    }

    @Test("Renacer entrega su ORO como comprado, sus 4 h y su ×3")
    func rebirthDelivers() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let production = GameState.coinReward(seconds: 14_400, player: before, content: content, economy: economy)
        gameState.creditStorePurchase(try entry("renacer"), transactionID: "offer-1")
        let after = try #require(gameState.player)
        #expect(after.meta.oro == before.meta.oro + 300)
        #expect(after.meta.oroPurchasedLifetime == before.meta.oroPurchasedLifetime + 300)
        #expect(after.meta.oroEarnedLifetime == before.meta.oroEarnedLifetime, "lo comprado no es multiplicador")
        #expect(abs(after.run.coins - before.run.coins - production) < 1e-6 * max(1, production))
        let boost = try #require(after.run.activeModifiers.first { $0.sourceKey == "offer.renacer" })
        #expect(boost.effect == .incomeMultiplier)
        #expect(boost.magnitude == 3)
        #expect(after.meta.engagement.offers.purchases["renacer"] == 1)
    }

    @Test("Bienvenida trae su cofre")
    func welcomeBringsAChest() async throws {
        let gameState = await makeGameState()
        let chests = try #require(gameState.player?.meta.chestsPending)
        gameState.creditStorePurchase(try entry("bienvenida"), transactionID: "offer-2")
        #expect(gameState.player?.meta.chestsPending == chests + 1)
        #expect(gameState.player?.meta.oroPurchasedLifetime == 120)
    }

    @Test("la misma transacción no se acredita dos veces")
    func creditsOnce() async throws {
        let gameState = await makeGameState()
        let renacer = try entry("renacer")
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let production = GameState.coinReward(seconds: 14_400, player: before, content: content, economy: economy)
        gameState.creditStorePurchase(renacer, transactionID: "offer-3")
        gameState.creditStorePurchase(renacer, transactionID: "offer-3")
        let player = try #require(gameState.player)
        #expect(player.meta.oroPurchasedLifetime == 300)
        #expect(player.meta.oro == 300)
        #expect(player.meta.engagement.offers.purchases["renacer"] == 1)
        #expect(player.run.activeModifiers.filter { $0.sourceKey == "offer.renacer" }.count == 1)
        #expect(abs(player.run.coins - production) < 1e-6 * max(1, production), "la plata, una sola vez")
    }

    @Test("una oferta que el catálogo no conoce no consume la transacción")
    func unknownOfferKeepsTheTransactionOpen() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)
        var ghost = try entry("renacer")
        ghost.offerId = "fantasma"
        gameState.creditStorePurchase(ghost, transactionID: "offer-6")
        #expect(gameState.player?.meta.creditedPurchases.contains("offer-6") == false)
        #expect(gameState.player?.meta.oro == before.meta.oro)
        gameState.creditStorePurchase(try entry("renacer"), transactionID: "offer-6")
        #expect(gameState.player?.meta.oro == before.meta.oro + 300)
    }

    @Test("una oferta comprada en el dispositivo que pierde entra una sola vez al cruzar los saves")
    func purchaseOnTheLosingDeviceCreditsOnce() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.player)
        gameState.creditStorePurchase(try entry("renacer"), transactionID: "offer-7")
        var loser = try #require(gameState.player)
        loser.meta.lifetimeEarnings = base.meta.lifetimeEarnings
        var winner = base
        winner.meta.lifetimeEarnings = base.meta.lifetimeEarnings + 1_000
        let resolved = SaveConflictResolver.resolve(local: winner, remote: loser)
        #expect(resolved.meta.oro == winner.meta.oro + 300)
        #expect(resolved.meta.oroPurchasedLifetime == 300)
        let again = SaveConflictResolver.resolve(local: resolved, remote: loser)
        #expect(again.meta.oro == resolved.meta.oro)
        #expect(again.meta.engagement.offers.purchases["renacer"] == 1)
    }

    @Test("una compra cierra su ventana; fuera de la ventana se entrega igual")
    func windowClosesButNeverRefuses() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let now = Date().timeIntervalSince1970
        var player = try #require(gameState.player)
        OffersEngine.open("mudanza", in: &player.meta.engagement.offers, catalog: content.offers, now: now)
        gameState.player = player
        gameState.creditStorePurchase(try entry("mudanza"), transactionID: "offer-4")
        #expect(gameState.player?.meta.engagement.offers.active.isEmpty == true)
        #expect(gameState.player?.meta.oro == 500)
        // Ya cerrada (y en enfriamiento), otra transacción también se entrega.
        gameState.creditStorePurchase(try entry("mudanza"), transactionID: "offer-5")
        #expect(gameState.player?.meta.oro == 1000)
        #expect(gameState.player?.meta.engagement.offers.purchases["mudanza"] == 2)
        #expect(gameState.player?.meta.engagement.offers.lastClosedAt["mudanza"] != nil, "la compra arranca el enfriamiento")
    }

    @Test("una oferta no inventa una línea de pack ni un número en su descripción")
    func noPackLine() async throws {
        let gameState = await makeGameState()
        let renacer = try entry("renacer")
        #expect(gameState.packRewardText(for: renacer) == nil)
        #expect(IAPCopy.quantity(for: renacer, skins: gameState.content?.skins) == nil)
    }
}
