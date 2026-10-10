import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La pantalla de la tienda de ORO: lo que se dice del azar y el cerrojo del cobro")
@MainActor
struct OroShopScreenTests {
    private func chestRow(_ gameState: GameState, chanceAllowed: Bool) -> OroShopRow? {
        gameState.oroShopRows(chanceAllowed: chanceAllowed).first { $0.id == "skin_chest" }
    }

    @Test("la tabla del cofre llega entera: las rarezas que se sortean, sumando uno")
    func skinsTable() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        let item = try #require(chestRow(gameState, chanceAllowed: true)).item
        guard case .table(let rows) = ChestOddsDisplay.make(for: item, odds: gameState.chestOdds) else {
            Issue.record("con pisos abiertos el cofre muestra su tabla")
            return
        }
        #expect(abs(rows.map(\.probability).reduce(0, +) - 1) < 1e-9)
        #expect(Set(rows.map(\.id)).isSubset(of: Set(SkinsConfig.Rarity.allCases.map(\.rawValue))))
    }

    @Test("con la colección completa el cofre se vende y dice que paga monedas")
    func collectionComplete() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        let all = try #require(gameState.content).skins.chestPool.map(\.id)
        gameState.player?.meta.ownedSkins.append(contentsOf: all)
        let item = try #require(chestRow(gameState, chanceAllowed: true)).item
        #expect(ChestOddsDisplay.make(for: item, odds: gameState.chestOdds) == .collectionComplete)
    }

    @Test("sin pinta alcanzable no hay qué mostrar, y la fila comprable nunca llega a ese caso")
    func nothingYetIsNeverSold() async {
        #expect(ChestOddsDisplay.make(for: .nothingYet) == .hidden)
        let fresh = await makeGameState()
        for tier in [0, 1, 3, 12] {
            if tier > 0 { fresh.debugUnlockFloors(throughTier: tier) }
            let row = chestRow(fresh, chanceAllowed: true)
            #expect((row != nil) == (fresh.chestOdds != .nothingYet), "tier \(tier): se vende sólo si hay qué sortear")
        }
    }

    @Test("el azar cerrado no se vende, ni con ORO de sobra")
    func closedChanceHidesTheChest() async {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        gameState.player?.meta.oro = 10_000
        #expect(chestRow(gameState, chanceAllowed: false) == nil)
        #expect(gameState.buyOroShopItem(id: "skin_chest", chanceAllowed: false) == .unavailable)
        #expect(gameState.player?.meta.oro == 10_000)
    }

    @Test("lo que no es azar no lleva tabla")
    func plainRowsHaveNoTable() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 500
        let item = try #require(gameState.oroShopRows(chanceAllowed: false).first { $0.id == "income_x2" }).item
        #expect(ChestOddsDisplay.make(for: item, odds: gameState.chestOdds) == .notChance)
    }

    @Test("el cerrojo deja pasar un toque y frena el siguiente hasta soltarlo")
    func latch() {
        var latch = PurchaseLatch()
        let first = latch.claim()
        let second = latch.claim()
        #expect(first)
        #expect(latch.isLocked)
        #expect(!second)
        latch.release()
        let third = latch.claim()
        #expect(third)
    }

    @Test("cobrar y entregar son un paso sincrónico: ninguna animación es condición")
    func purchaseDoesNotWaitForTheView() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 500
        #expect(gameState.buyOroShopItem(id: "offline_x3", chanceAllowed: false) == .bought)
        #expect(gameState.player?.meta.oro == 380)
        #expect(gameState.player?.meta.engagement.shop.pendingOfflineMultiplier == 3, "el ×3 queda esperando su popup")
        #expect(gameState.buyOroShopItem(id: "offline_x3", chanceAllowed: false) == .refused(.alreadyPending))
        #expect(gameState.player?.meta.oro == 380)
    }
}
