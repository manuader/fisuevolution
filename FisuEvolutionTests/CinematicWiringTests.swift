import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El turno de la cinemática")
@MainActor
struct CinematicWiringTests {
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.cinematicsAutorun = true
        return gameState
    }

    @Test("bajo XCTest no corre sola")
    func offUnderTests() async {
        let gameState = await makeGameState()
        #expect(!gameState.cinematicsAutorun)
        #expect(!gameState.playCinematicIfDue(.dios))
        #expect(gameState.showing == nil)
    }

    @Test("pide turno, apaga el HUD y al cerrar se anota vista")
    func takesTheTurnAndRecords() async {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.reencarnacion))
        #expect(gameState.showing == .cinematic)
        #expect(gameState.cinematic == .reencarnacion)
        #expect(gameState.celebrationHidesUI)
        #expect(!gameState.isCalmMoment)
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.cinematic == nil)
        #expect(gameState.showing == nil)
        #expect(!gameState.celebrationHidesUI)
        #expect(gameState.player?.meta.engagement.seenCinematics["reencarnacion"] == 1)
    }

    @Test("Dios una vez, el arresto dos, la reencarnación siempre")
    func playLimits() async {
        let gameState = await world()
        for (id, plays) in [(CinematicID.dios, 1), (.arresto, 2), (.reencarnacion, 5)] {
            for _ in 0..<plays {
                #expect(gameState.playCinematicIfDue(id), "\(id.rawValue)")
                gameState.celebrationFinished(.cinematic)
            }
        }
        #expect(!gameState.playCinematicIfDue(.dios))
        #expect(!gameState.playCinematicIfDue(.arresto))
        #expect(gameState.playCinematicIfDue(.reencarnacion))
    }

    @Test("la intro suena una sola vez")
    func introPlaysOnce() async {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.intro))
        gameState.celebrationFinished(.cinematic)
        #expect(!gameState.playCinematicIfDue(.intro))
    }

    @Test("el watchdog también la cuenta vista")
    func watchdogRecords() async {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.dios))
        gameState.advanceCelebrations(delta: 12.5)
        #expect(gameState.showing == nil)
        #expect(gameState.player?.meta.engagement.seenCinematics["dios"] == 1)
    }

    @Test("el tap que saltea también la cuenta vista, y una sola vez")
    func skipRecordsOnce() async {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.arresto))
        gameState.advanceCelebrations(delta: CelebrationQueue.skipFloor)
        #expect(gameState.skipCurrentCelebration())
        #expect(gameState.showing == nil)
        gameState.celebrationFinished(.cinematic)
        gameState.advanceCelebrations(delta: 12.5)
        #expect(gameState.player?.meta.engagement.seenCinematics["arresto"] == 1)
    }

    @Test("una segunda pedida mientras otra espera se descarta, no se pisa")
    func oneAtATime() async {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.arresto))
        #expect(!gameState.playCinematicIfDue(.reencarnacion))
        #expect(gameState.cinematic == .arresto)
    }

    @Test("espera detrás del que está en pantalla y sale después, sin repetirse")
    func waitsItsTurnAndDoesNotRepeat() async {
        let gameState = await world()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.flushHUD()
        #expect(gameState.showing == .towerNotice)
        #expect(gameState.playCinematicIfDue(.dios))
        #expect(gameState.showing == .towerNotice, "no corta lo que se está viendo")
        gameState.celebrationFinished(.towerNotice)
        #expect(gameState.showing == .cinematic)
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.showing == nil, "ni la cinemática ni el aviso vuelven")
    }

    @Test("lo visto sobrevive al guardado: la cuenta restaurada no la repite")
    func seenSurvivesSaveAndRestore() async throws {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.dios))
        gameState.celebrationFinished(.cinematic)
        let saved = try JSONEncoder().encode(try #require(gameState.player))
        let restored = await world()
        #expect(restored.isCinematicDue(.dios))
        restored.player = try JSONDecoder().decode(PlayerState.self, from: saved)
        #expect(!restored.isCinematicDue(.dios))
        #expect(!restored.playCinematicIfDue(.dios))
        #expect(restored.playCinematicIfDue(.reencarnacion))
    }

    @Test("el autorun es del arranque: no viaja en el save")
    func autorunIsNotSaved() async throws {
        let gameState = await world()
        let saved = try JSONEncoder().encode(try #require(gameState.player))
        let text = String(decoding: saved, as: UTF8.self)
        #expect(!text.contains("cinematicsAutorun"))
    }
}
