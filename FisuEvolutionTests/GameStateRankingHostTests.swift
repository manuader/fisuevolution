import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El `GameState` como dueño del `RankingState` (E12 T10): lo que el store lee y muta vive en `meta.ranking`.
@MainActor
@Suite("GameState como host del ranking")
struct GameStateRankingHostTests {
    @Test("el store lee y muta meta.ranking; godTier es el último tier del contenido")
    func readsAndMutatesMetaRanking() async {
        let state = await makeGameState()
        state.saveTask = nil
        #expect(state.rankingState == state.player?.meta.ranking)
        #expect(state.godTier == state.content?.tiers.maxTier)
        #expect(state.godTier != nil)

        state.updateRanking { $0.lastName = "Ana" }

        #expect(state.player?.meta.ranking.lastName == "Ana")
        #expect(state.saveTask != nil, "la mutación agenda el guardado")
        state.saveTask?.cancel()
        #expect(state.rankingState?.lastName == "Ana")
    }

    @Test("sin partida cargada no hay ranking que leer ni mutar")
    func noPlayerNoRanking() async {
        let state = await makeGameState()
        state.player = nil
        state.saveTask = nil
        var called = false
        state.updateRanking { _ in called = true }
        #expect(state.rankingState == nil)
        #expect(!called)
        #expect(state.saveTask == nil)
    }
}
