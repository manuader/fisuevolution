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
        #expect(!gameState.mattressInPlay)
    }

    @Test("con el juego andando, aparece cuando vence su reloj; durante el núcleo del tutorial, no")
    func itAppears() async {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.beginTutorialPhase()
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(!gameState.mattressInPlay)
        gameState.finishTutorialCore()
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.mattressWaiting, "en la columna, pidiendo su video: ya no hay «1 de cada 4» de regalo")
    }

    @Test("el gratis (B31): reloj real, cae a los 30 min, en el tablero y en el piso que se mira; uno solo")
    func theFreeOneDropsOnTheRealClock() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.finishTutorialCore()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.engagement.treasures.freeBoard = FreeBoardMattress(clockStartedAt: now - 1799)
        gameState.advanceEngagement(delta: 0.016)
        #expect(!gameState.freeMattressOnBoard, "todavía no")
        // Con el juego cerrado horas: al volver espera uno solo.
        gameState.player?.meta.engagement.treasures.freeBoard = FreeBoardMattress(clockStartedAt: now - 5 * 3600)
        gameState.advanceEngagement(delta: 0.016)
        #expect(gameState.freeMattressOnBoard)
        #expect(gameState.mattressFloor(.free) == gameState.visibleFloorOrdinal)
        #expect(!gameState.mattressWaiting && !gameState.mattressOnBoard, "no pasa por la columna")
        gameState.refreshPrizeAccess()
        #expect(gameState.prizeAccess.freeMattressOnBoard && !gameState.prizeAccess.mattressReady)
    }

    @Test("el reloj del gratis arranca al cargar un save que no lo tenía, y el flag de DEBUG lo prende solo")
    func theFreeClockStartsOnLoad() async throws {
        let gameState = await makeGameState()
        gameState.finishTutorialCore()
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.player?.meta.engagement.treasures.freeBoard.clockStartedAt == nil, "bajo XCTest, apagado")
        gameState.debugFreeMattressEvery(1)
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        let started = try #require(gameState.player?.meta.engagement.treasures.freeBoard.clockStartedAt)
        #expect(abs(started - Date().timeIntervalSince1970) < 60)
        #expect(!gameState.mattressInPlay, "el flag prende sólo el gratis, no la columna")
        gameState.player?.meta.engagement.treasures.freeBoard.clockStartedAt = started - 2
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.freeMattressOnBoard)
    }

    @Test("sin colchón en el tablero no se abre nada: el de la columna pide su video primero")
    func nothingToOpen() async {
        let gameState = await makeGameState()
        #expect(gameState.openMattress() == nil)
        #expect(gameState.openExtraMattress() == nil)
        gameState.debugSpawnMattress()
        let before = gameState.player
        #expect(gameState.openMattress() == nil)
        #expect(gameState.player == before)
        #expect(gameState.mattressWaiting)
    }

    @Test("abrir el del tablero acredita su premio, lo saca del juego y habilita uno más")
    func openingGrantsAndArmsTheExtra() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        let before = try #require(gameState.player)
        let outcome = try #require(gameState.openMattress())
        let after = try #require(gameState.player)
        #expect(!gameState.mattressInPlay)
        #expect(outcome.extraOpensLeft == 1)
        #expect(after.meta.engagement.treasures.secondsUntilNext == gameState.content?.treasures.spawnIntervalSeconds)
        switch outcome.prizeId {
        case "coins": #expect(after.run.coins > before.run.coins && outcome.coins > 0)
        case "package": #expect(after.meta.engagement.packages.waiting == before.meta.engagement.packages.waiting + 1)
        case "blue": #expect(after.meta.blue == before.meta.blue + 2)
        default: Issue.record("premio desconocido: \(outcome.prizeId)")
        }
    }

    @Test("«otro colchón» sortea de nuevo una sola vez")
    func theExtraIsOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        _ = try #require(gameState.openMattress())
        let extra = try #require(gameState.openExtraMattress())
        #expect(extra.extraOpensLeft == 0)
        #expect(gameState.openExtraMattress() == nil)
    }

    @Test("la plata del colchón son 20 minutos de producción")
    func theCoinsAreTwentyMinutes() async throws {
        let gameState = await makeGameState()
        for _ in 0..<60 {
            gameState.debugSpawnMattress(onBoard: true)
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
        #expect(!gameState.mattressInPlay)
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == 9)
    }

    @Test("en el borde exacto del reloj aparece, y un delta enorme (offline) regala uno solo")
    func theBoundaryAndAHugeDelta() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 1
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.mattressInPlay)
        let phase = gameState.player?.meta.engagement.treasures.phase
        let interval = try #require(gameState.content?.treasures.spawnIntervalSeconds)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == interval)
        gameState.advanceEngagement(delta: 1_000_000)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == interval)
        #expect(gameState.player?.meta.engagement.treasures.phase == phase)
    }

    @Test("un colchón se cobra una sola vez, aunque se toque dos veces")
    func paysOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        _ = try #require(gameState.openMattress())
        let after = try #require(gameState.player)
        #expect(gameState.openMattress() == nil)
        #expect(gameState.player == after)
    }

    @Test("«otro colchón» se pierde cuando aparece el siguiente")
    func theExtraDiesWithTheNextMattress() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.debugSpawnMattress(onBoard: true)
        _ = try #require(gameState.openMattress())
        #expect(gameState.mattressExtraOpensLeft == 1)
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.mattressInPlay)
        #expect(gameState.mattressExtraOpensLeft == 0)
        #expect(gameState.openExtraMattress() == nil)
    }

    @Test("lo cobrado y el estado del colchón sobreviven a un guardado")
    func thePrizeAndTheStateArePersisted() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        _ = try #require(gameState.openMattress())
        let player = try #require(gameState.player)
        let data = try JSONEncoder().encode(player.meta)
        let restored = try JSONDecoder().decode(MetaState.self, from: data)
        #expect(restored == player.meta)
        #expect(restored.engagement.treasures.phase == .none)
        #expect(restored.engagement.treasures.extraOpensLeft == 1)
    }

    @Test("un save anterior a B6 con un colchón esperando migra a la columna: pide su video, no se regala")
    func theOldSaveMigrates() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(gameState.player)) as? [String: Any])
        var meta = try #require(json["meta"] as? [String: Any])
        var engagement = try #require(meta["engagement"] as? [String: Any])
        engagement["treasures"] = ["secondsUntilNext": 120.0, "waiting": true, "extraOpensLeft": 0]
        meta["engagement"] = engagement
        json["meta"] = meta
        let migrated = try SaveMigrator.migrate(JSONSerialization.data(withJSONObject: json))
        #expect(migrated.meta.engagement.treasures == TreasuresState(secondsUntilNext: 120, phase: .waiting))
        gameState.player = migrated
        gameState.refreshPrizeAccess()
        #expect(gameState.prizeAccess.mattressReady && !gameState.prizeAccess.mattressOnBoard)
        #expect(gameState.openMattress() == nil, "migrado, todavía pide su video")
    }

    @Test("pagado y sin abrir, el colchón del tablero sobrevive a matar la app")
    func theBoardMattressSurvivesARelaunch() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        #expect(gameState.payMattress())
        let data = try JSONEncoder().encode(try #require(gameState.player))
        let restored = try SaveMigrator.migrate(data)
        #expect(restored.meta.engagement.treasures.phase == .onBoard)
        gameState.player = restored
        #expect(gameState.mattressOnBoard)
        #expect(!gameState.payMattress(), "no se paga dos veces")
        #expect(gameState.openMattress() != nil)
    }
}
