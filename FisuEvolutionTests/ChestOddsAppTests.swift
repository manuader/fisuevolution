import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La suerte de la tienda: la tabla del cofre y la última respuesta de la puerta")
@MainActor
struct ChestOddsAppTests {
    @Test("sin config que leer, la última respuesta queda cerrada (falla cerrado, como E5a)")
    func lastKnownFailsClosed() async {
        let nowhere = AdsRemoteConfigLoader(
            cacheURL: FileManager.default.temporaryDirectory.appending(path: "no-cache-\(UUID().uuidString).json"),
            bundledURL: nil
        )
        #expect(await LootBoxGate.refreshLastKnown(loader: nowhere) == false)
        #expect(LootBoxGate.lastKnown == false)
    }

    @Test("el juego muestra las probabilidades de su cofre de hoy")
    func gameStateOdds() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        guard case .skins(let odds) = gameState.chestOdds else {
            Issue.record("con pisos abiertos el cofre tiene qué dar")
            return
        }
        #expect(abs(odds.map(\.probability).reduce(0, +) - 1) < 1e-9)
    }

    @Test("los cofres que ya esperan se quedan con las pintas: otro cofre no se vende")
    func pendingChestsCountAgainstStock() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        #expect(try #require(gameState.oroShopContext(chanceAllowed: true)).chestHasSomethingToGive)
        gameState.player?.meta.chestsPending = 10_000
        #expect(try !#require(gameState.oroShopContext(chanceAllowed: true)).chestHasSomethingToGive)
        gameState.player?.meta.chestsPending = 0
        gameState.player?.meta.prestigeChestsPending = 10_000
        #expect(try !#require(gameState.oroShopContext(chanceAllowed: true)).chestHasSomethingToGive)
    }

    @Test("con la colección completa el cofre sigue vendiéndose, y paga plata")
    func completeCollectionStillSells() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        let all = try #require(gameState.content).skins.chestPool.map(\.id)
        gameState.player?.meta.ownedSkins.append(contentsOf: all)
        gameState.player?.meta.chestsPending = 3
        #expect(try #require(gameState.oroShopContext(chanceAllowed: true)).chestHasSomethingToGive)
        #expect(gameState.chestOdds == .coins)
    }
}
