import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

private struct FixedRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("Eventos: el sorteo")
@MainActor
struct EventSchedulingTests {
    @Test("un sorteo sin candidatos no gasta el intervalo")
    func emptyDrawRetriesSoon() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        gameState.nextEventAt = now - 1
        gameState.fireEventIfDue(now: now)
        let retry = try #require(gameState.content?.events.retryWhenNoneApplicableSeconds)
        #expect(gameState.nextEventAt == now + retry)
    }

    @Test("lo que no aplica no sale nunca")
    func inapplicableEventsAreNeverDrawn() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        var state = try #require(gameState.player)
        state.run.raiseFrontier(to: 20)
        for seed in UInt64(0)..<300 {
            var rng = FixedRNG(state: seed)
            var copy = state
            let roll = EventManager.fireRandomEvent(
                state: &copy, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
                economy: try #require(gameState.economy), now: 1_000_000, lastFired: [:],
                isApplicable: { $0.id != "startup_comprada" }, rng: &rng
            )
            #expect(roll?.event.id != "startup_comprada")
        }
    }

    @Test("sin nadie que pueda crecer solo, la Startup no evoluciona: aplica por su plata de respaldo")
    func startupFallsBackToCashWhenNobodyCanEvolve() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.player?.run.units = ["administrativo": 1]
        gameState.reconcileTower()
        let startup = try #require(content.events.events.first { $0.id == "startup_comprada" })
        #expect(gameState.startupEvolution(for: startup) == nil)
        #expect(gameState.eventIsApplicable(startup))
    }

    @Test("sin respaldo y sin nadie que evolucione, la Startup no aplica")
    func startupWithoutFallbackNeedsSomeoneWhoCanEvolve() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.player?.run.units = ["administrativo": 1]
        gameState.reconcileTower()
        let startup = try #require(content.events.events.first { $0.id == "startup_comprada" })
        let bare = EventsConfig.Event(
            id: startup.id, effectType: startup.effectType, magnitude: startup.magnitude,
            durationSeconds: startup.durationSeconds, weight: startup.weight, minTier: startup.minTier,
            cooldownSeconds: startup.cooldownSeconds, flavorTextKey: startup.flavorTextKey,
            isBuff: startup.isBuff, escape: startup.escape, fallback: nil
        )
        #expect(!gameState.eventIsApplicable(bare))
    }

    @Test("sin pasivo, el Aguinaldo no aplica")
    func aguinaldoNeedsPassiveIncome() async throws {
        let gameState = await makeGameState()
        let aguinaldo = try #require(gameState.content?.events.events.first { $0.id == "aguinaldo" })
        #expect(!gameState.eventIsApplicable(aguinaldo))
    }
}
