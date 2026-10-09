import EconomyKit
import Foundation
import SwiftUI
import Testing
@testable import FisuEvolution

/// Los ganchos del ranking en `GameState` (E12 T11): el cronómetro arranca con el núcleo del tutorial,
/// cuenta sólo el tiempo en `.active` y se sella al revelar a Dios.
@MainActor
@Suite("Ranking: los ganchos de GameState")
struct RankingWiringTests {
    private final class Clock: @unchecked Sendable {
        var value: TimeInterval = 10_000
    }

    private struct Rig {
        let gameState: GameState
        let store: RankingStore
        let simulated: SimulatedRankingClient
        let clock: Clock
        let godTier: Int
    }

    private let config = RankingConfig(
        schemaVersion: RankingConfig.supportedSchemaVersion, enabled: true,
        baseURL: URL(string: "https://example.test"), anonKey: "k")

    private func makeRig(_ state: RankingState = .newGame, atGodFrontier: Bool = false) async throws -> Rig {
        let gameState = await makeGameState()
        let godTier = try #require(gameState.godTier)
        gameState.player?.meta.ranking = state
        if atGodFrontier { gameState.player?.run.raiseFrontier(to: godTier) }
        let clock = Clock()
        let simulated = SimulatedRankingClient(now: { clock.value })
        let store = RankingStore(
            client: simulated, config: config, now: { clock.value }, appVersion: "2.0",
            cacheURL: URL.temporaryDirectory.appending(path: "ranking-board-\(UUID().uuidString).json"))
        gameState.beginTutorialPhase()
        gameState.attachRanking(store)
        await store.settled()
        return Rig(gameState: gameState, store: store, simulated: simulated, clock: clock, godTier: godTier)
    }

    private func startRunCount(_ rig: Rig) async -> Int {
        await rig.simulated.calls.filter { if case .startRun = $0 { true } else { false } }.count
    }

    private func sealCount(_ rig: Rig) async -> Int {
        await rig.simulated.calls.filter { if case .finishRun = $0 { true } else { false } }.count
    }

    private func closeTutorialCore(_ rig: Rig) async {
        rig.gameState.tutorialPhaseFinished()
        await rig.store.settled()
    }

    @Test("cerrar el núcleo del tutorial en una partida nueva registra la partida")
    func closingTheCoreStartsTheRun() async throws {
        let rig = try await makeRig()
        #expect(await startRunCount(rig) == 0)

        rig.gameState.tutorialPhaseFinished()
        await rig.store.settled()

        #expect(await startRunCount(rig) == 1)
        guard case .running = rig.gameState.player?.meta.ranking.phase else {
            Issue.record("la partida debía quedar en running")
            return
        }
    }

    @Test("un save legacy no compite: cerrar el núcleo no manda nada")
    func legacyNeverStarts() async throws {
        let rig = try await makeRig(.legacy)

        await closeTutorialCore(rig)

        #expect(await startRunCount(rig) == 0)
        #expect(rig.gameState.player?.meta.ranking == .legacy)
    }

    @Test("el tiempo jugado suma la sesión en .active y no el background")
    func playedSecondsIgnoreBackground() async throws {
        let rig = try await makeRig()
        await closeTutorialCore(rig)
        let before = try #require(rig.gameState.player?.meta.ranking.playedSeconds)

        rig.clock.value += 10
        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: rig.clock.value)
        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: rig.clock.value)
        rig.clock.value += 30
        rig.gameState.handleScenePhase(from: .background, to: .active, now: rig.clock.value)
        rig.clock.value += 5
        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: rig.clock.value)
        await rig.store.settled()

        let played = try #require(rig.gameState.player?.meta.ranking.playedSeconds)
        #expect(played - before == 15)
    }

    @Test("revelar el tier de Dios sella una vez y abre la tarjeta")
    func revealingGodSealsOnce() async throws {
        let rig = try await makeRig()
        await closeTutorialCore(rig)

        rig.gameState.markRevealed(tier: rig.godTier)
        await rig.store.settled()

        #expect(await sealCount(rig) == 1)
        #expect(rig.store.entryPrompt != nil)

        rig.gameState.markRevealed(tier: rig.godTier)
        rig.store.reachedGod()
        await rig.store.settled()

        #expect(await sealCount(rig) == 1)
    }

    @Test("con el tutorial abierto la partida no corre; el núcleo la arranca sin el tramo del tutorial")
    func tutorialDoesNotRunTheClock() async throws {
        let rig = try await makeRig()
        rig.clock.value += 100
        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: rig.clock.value)
        rig.clock.value += 100
        rig.gameState.handleScenePhase(from: .inactive, to: .active, now: rig.clock.value)
        await rig.store.settled()
        #expect(await startRunCount(rig) == 0)

        rig.clock.value += 100
        rig.gameState.tutorialPhaseFinished()
        await rig.store.settled()
        #expect(await startRunCount(rig) == 1)

        rig.clock.value += 7
        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: rig.clock.value)
        #expect(rig.gameState.player?.meta.ranking.playedSeconds == 7)
    }

    @Test("revelar un tier que no es Dios no toca el ranking")
    func revealingOtherTiersIsSilent() async throws {
        let rig = try await makeRig()
        await closeTutorialCore(rig)
        let before = rig.gameState.player?.meta.ranking

        rig.gameState.markRevealed(tier: rig.godTier - 1)
        await rig.store.settled()

        #expect(rig.gameState.player?.meta.ranking == before)
    }

    @Test("arrancar con la frontera en Dios y la partida corriendo la deja en reachedGod")
    func bootReconcilesArrival() async throws {
        let rig = try await makeRig(
            RankingState(phase: .running(runId: "run-1", serverStartedAt: 1_000)), atGodFrontier: true)

        guard case .reachedGod = rig.gameState.player?.meta.ranking.phase else {
            Issue.record("la partida debía quedar en reachedGod")
            return
        }
    }

    @Test("el arranque descarta la sesión huérfana de un cierre a la fuerza")
    func bootDropsOrphanSession() async throws {
        var orphan = RankingState(phase: .running(runId: "run-1", serverStartedAt: 1_000))
        orphan.activeSince = 5
        let rig = try await makeRig(orphan)

        #expect(rig.gameState.player?.meta.ranking.activeSince == nil)
        #expect(rig.gameState.player?.meta.ranking.playedSeconds == 0)
    }

    @Test("reencarnar no toca la partida rankeada")
    func prestigeLeavesRankingAlone() async throws {
        let rig = try await makeRig()
        await closeTutorialCore(rig)
        let before = rig.gameState.player?.meta.ranking

        rig.gameState.giveEarningsForPrestigeTesting(oro: 9)
        rig.gameState.confirmPrestige()
        #expect(rig.gameState.player?.meta.prestigeLevel == 1)
        await rig.store.settled()

        #expect(rig.gameState.player?.meta.ranking == before)
    }
}
