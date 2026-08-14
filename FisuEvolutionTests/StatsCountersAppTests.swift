import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los tres choke points de la capa app: el tap, el video y el boost.
///
/// La regla que los ordena es la misma en los tres: se cuenta lo que el jugador
/// HIZO, y "hizo" se mide donde el juego ya decidió que la acción ocurrió.
/// El video es la excepción interesante — se cuenta aunque el efecto no caiga,
/// exactamente donde se marca el cooldown, porque el video se miró igual.
@Suite("Contadores históricos en la capa app")
@MainActor
struct StatsCountersAppTests {
    // MARK: Taps

    @Test("cada tap cobrado suma uno")
    func tapsAreCounted() async throws {
        let gameState = await makeGameState()
        let slot = try #require(gameState.visiblePlacements.first?.slot)
        #expect(gameState.player?.meta.stats.totalTapsEver == 0)

        for _ in 0..<3 {
            #expect(gameState.registerTap(cellIndex: slot) != nil)
        }

        #expect(gameState.player?.meta.stats.totalTapsEver == 3)
    }

    @Test("un toque en una celda vacía no cobra ni cuenta")
    func tapOnEmptyCellDoesNotCount() async throws {
        let gameState = await makeGameState()
        let empty = try #require(gameState.tower?.floors[gameState.visibleFloorOrdinal].firstFreeSlot())

        #expect(gameState.registerTap(cellIndex: empty) == nil)

        #expect(gameState.player?.meta.stats.totalTapsEver == 0)
    }

    // MARK: Videos

    @Test("mirar un video suma uno")
    func watchedVideoIsCounted() async throws {
        let gameState = await makeGameState()

        gameState.applyRewardedReward(rewardId: "double_earnings", now: 1000)

        #expect(gameState.player?.meta.stats.videosWatchedEver == 1)
    }

    /// El contador va donde va el cooldown: si el efecto no encuentra dónde caer
    /// —acá, un `instantMerge` en una partida nueva, que tiene una sola unidad y
    /// por lo tanto ningún par— el video igual se miró y el anunciante igual cobró.
    @Test("el video cuenta aunque el efecto no caiga")
    func videoCountsEvenWhenEffectDoesNotLand() async throws {
        let gameState = await makeGameState()

        gameState.applyRewardedReward(rewardId: "accelerate_evolution", now: 1000)

        #expect(gameState.player?.meta.stats.videosWatchedEver == 1)
        #expect(gameState.player?.meta.stats.totalMergesEver == 0, "no había par: no hubo fusión que contar")
    }

    @Test("un video rechazado por cooldown no suma")
    func videoOnCooldownDoesNotCount() async throws {
        let gameState = await makeGameState()
        gameState.applyRewardedReward(rewardId: "double_earnings", now: 1000)

        gameState.applyRewardedReward(rewardId: "double_earnings", now: 1000 + 60)

        #expect(gameState.player?.meta.stats.videosWatchedEver == 1)
    }

    // MARK: Boosts

    @Test("activar un boost suma uno")
    func activatedBoostIsCounted() async throws {
        let gameState = await makeGameState()
        let open = try #require(gameState.boostRows.first { $0.isUnlocked })

        _ = gameState.activateBoost(id: open.id)

        #expect(gameState.player?.meta.stats.boostsActivatedEver == 1)
    }

    @Test("un boost bloqueado no suma")
    func lockedBoostDoesNotCount() async throws {
        let gameState = await makeGameState()
        let locked = try #require(gameState.boostRows.first { !$0.isUnlocked })

        _ = gameState.activateBoost(id: locked.id)

        #expect(gameState.player?.meta.stats.boostsActivatedEver == 0)
    }

    /// El segundo click cae en el cooldown y `BoostManager` lo rechaza: no hubo
    /// activación, así que no hay nada que contar.
    @Test("un boost en cooldown no suma de nuevo")
    func boostOnCooldownDoesNotCountTwice() async throws {
        let gameState = await makeGameState()
        let open = try #require(gameState.boostRows.first { $0.isUnlocked })

        _ = gameState.activateBoost(id: open.id)
        _ = gameState.activateBoost(id: open.id)

        #expect(gameState.player?.meta.stats.boostsActivatedEver == 1)
    }
}
