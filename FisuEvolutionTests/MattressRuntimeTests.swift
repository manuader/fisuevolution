import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El Colchón en la partida")
@MainActor
struct MattressRuntimeTests {
    @Test("bajo XCTest no aparece solo")
    func autorunIsOffUnderTests() async {
        let gameState = await makeGameState()
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(!gameState.mattressWaiting)
    }

    @Test("con el juego andando, aparece cuando vence su reloj; durante el núcleo del tutorial, no")
    func itAppears() async {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.beginTutorialPhase()
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(!gameState.mattressWaiting)
        gameState.tutorialPhaseFinished()
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.mattressWaiting)
    }

    @Test("sin colchón esperando no se abre nada")
    func nothingToOpen() async {
        let gameState = await makeGameState()
        #expect(gameState.openMattress() == nil)
        #expect(gameState.openExtraMattress() == nil)
    }

    @Test("abrirlo acredita su premio, deja de esperar y habilita uno más")
    func openingGrantsAndArmsTheExtra() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        let before = try #require(gameState.player)
        let outcome = try #require(gameState.openMattress())
        let after = try #require(gameState.player)
        #expect(!gameState.mattressWaiting)
        #expect(outcome.extraOpensLeft == 1)
        #expect(after.meta.engagement.treasures.secondsUntilNext == gameState.content?.treasures.spawnIntervalSeconds)
        switch outcome.prizeId {
        case "coins": #expect(after.run.coins > before.run.coins && outcome.coins > 0)
        case "package": #expect(after.meta.engagement.packages.waiting == before.meta.engagement.packages.waiting + 1)
        case "oro": #expect(after.meta.oro == before.meta.oro + 2)
        default: Issue.record("premio desconocido: \(outcome.prizeId)")
        }
    }

    @Test("«otro colchón» sortea de nuevo una sola vez")
    func theExtraIsOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        _ = try #require(gameState.openMattress())
        let extra = try #require(gameState.openExtraMattress())
        #expect(extra.extraOpensLeft == 0)
        #expect(gameState.openExtraMattress() == nil)
    }

    @Test("la plata del colchón son 20 minutos de producción")
    func theCoinsAreTwentyMinutes() async throws {
        let gameState = await makeGameState()
        for _ in 0..<60 {
            gameState.debugSpawnMattress()
            let player = try #require(gameState.player)
            let content = try #require(gameState.content)
            let economy = try #require(gameState.economy)
            let outcome = try #require(gameState.openMattress())
            guard outcome.prizeId == "coins" else { continue }
            let expected = GameState.coinReward(seconds: 1200, player: player, content: content, economy: economy)
            #expect(abs(outcome.coins - expected) < 1e-6 * max(1, expected))
            return
        }
        Issue.record("en 60 colchones no salió plata (60 % cada uno)")
    }

    @Test("el reloj no se mueve con delta 0 ni negativo (reloj atrasado) y espera mientras hay uno")
    func theClockNeverRunsBackwards() async {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 10
        gameState.advanceEngagement(delta: 0)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == 10)
        gameState.advanceEngagement(delta: -5)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == 10)
        #expect(!gameState.mattressWaiting)
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == 9)
    }

    @Test("en el borde exacto del reloj aparece, y un delta enorme (offline) regala uno solo")
    func theBoundaryAndAHugeDelta() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 1
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.mattressWaiting)
        let interval = try #require(gameState.content?.treasures.spawnIntervalSeconds)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == interval)
        gameState.advanceEngagement(delta: 1_000_000)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == interval)
        #expect(gameState.mattressWaiting)
    }

    @Test("un colchón se cobra una sola vez, aunque se toque dos veces")
    func paysOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        _ = try #require(gameState.openMattress())
        let after = try #require(gameState.player)
        #expect(gameState.openMattress() == nil)
        #expect(gameState.player == after)
    }

    @Test("«otro colchón» se pierde cuando aparece el siguiente")
    func theExtraDiesWithTheNextMattress() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.debugSpawnMattress()
        _ = try #require(gameState.openMattress())
        #expect(gameState.mattressExtraOpensLeft == 1)
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.mattressWaiting)
        #expect(gameState.mattressExtraOpensLeft == 0)
        #expect(gameState.openExtraMattress() == nil)
    }

    @Test("lo cobrado y el estado del colchón sobreviven a un guardado")
    func thePrizeAndTheStateArePersisted() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        _ = try #require(gameState.openMattress())
        let player = try #require(gameState.player)
        let data = try JSONEncoder().encode(player.meta)
        let restored = try JSONDecoder().decode(MetaState.self, from: data)
        #expect(restored == player.meta)
        #expect(!restored.engagement.treasures.waiting)
        #expect(restored.engagement.treasures.extraOpensLeft == 1)
    }
}
