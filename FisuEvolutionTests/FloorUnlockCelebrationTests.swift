import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

/// El desbloqueo de piso nuevo no se saltea (E14 C21, D6) sobre el `GameState` real.
/// La regla pura vive en `FloorUnlockRuleTests` (EconomyKit); acá, que el toque la respete.
@Suite("Desbloqueo de piso: insalteable")
@MainActor
struct FloorUnlockCelebrationTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "floor-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        gameState.markRevealed(tier: gameState.player?.run.maxTierReached ?? 1)
        return gameState
    }

    /// Pone la celebración del tablero en pantalla, con el reloj ya pasado el piso del skip.
    private func showBoardCelebration(_ gameState: GameState) {
        gameState.celebrate(.boardCelebration)
        gameState.tick(delta: CelebrationQueue.skipFloor + 0.1)
    }

    @Test("la primera vez diez toques no la cortan, y el reloj de seguridad sí la libera")
    func firstTimeSurvivesTenTaps() async throws {
        let gameState = await makeGameState()
        showBoardCelebration(gameState)
        #expect(gameState.showing == .boardCelebration)

        let presentation = gameState.beginFloorUnlockCelebration(floorID: "f2")
        #expect(!presentation.skippable)
        #expect(gameState.currentCelebrationIsUnskippable)
        for _ in 0..<10 { #expect(!gameState.skipCurrentCelebration()) }
        #expect(gameState.showing == .boardCelebration)

        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == nil)
        #expect(!gameState.currentCelebrationIsUnskippable)
    }

    @Test("la segunda vez en la misma vida se saltea como cualquier celebración")
    func secondTimeInTheSameLifeSkips() async throws {
        let gameState = await makeGameState()
        showBoardCelebration(gameState)
        gameState.beginFloorUnlockCelebration(floorID: "f2")
        gameState.celebrationFinished(.boardCelebration)

        showBoardCelebration(gameState)
        let again = gameState.beginFloorUnlockCelebration(floorID: "f2")
        #expect(again.skippable)
        #expect(again.short)
        #expect(!gameState.currentCelebrationIsUnskippable)
        #expect(gameState.skipCurrentCelebration())
    }

    @Test("en una vida nueva vuelve a ser insalteable, en versión corta, una sola vez")
    func newLifeIsUnskippableOnceAndShort() async throws {
        let gameState = await makeGameState()
        showBoardCelebration(gameState)
        gameState.beginFloorUnlockCelebration(floorID: "f2")
        gameState.celebrationFinished(.boardCelebration)

        gameState.player?.meta.prestigeLevel += 1
        showBoardCelebration(gameState)
        let reborn = gameState.beginFloorUnlockCelebration(floorID: "f2")
        #expect(!reborn.skippable)
        #expect(reborn.short)
        #expect(!gameState.skipCurrentCelebration())
        gameState.celebrationFinished(.boardCelebration)

        showBoardCelebration(gameState)
        #expect(gameState.beginFloorUnlockCelebration(floorID: "f2").skippable)
    }

    @Test("sin piso nuevo, la celebración del tablero y los avisos se siguen salteando")
    func everythingElseStaysSkippable() async throws {
        let gameState = await makeGameState()
        showBoardCelebration(gameState)
        #expect(!gameState.currentCelebrationIsUnskippable)
        #expect(gameState.skipCurrentCelebration())

        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.flushHUD()
        #expect(gameState.showing == .towerNotice)
        gameState.tick(delta: CelebrationQueue.skipFloor + 0.1)
        #expect(gameState.skipCurrentCelebration())
    }

    @Test("el cerrojo de un piso no se hereda a la celebración que sigue")
    func lockDoesNotLeakToTheNextItem() async throws {
        let gameState = await makeGameState()
        showBoardCelebration(gameState)
        gameState.beginFloorUnlockCelebration(floorID: "f2")
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == .towerNotice)
        gameState.tick(delta: CelebrationQueue.skipFloor + 0.1)
        #expect(gameState.skipCurrentCelebration())
    }

    @Test("en la escena, el toque durante el piso nuevo se consume sin cortar nada; sin piso, no se consume")
    func sceneConsumesTapsOnlyWhileLocked() async throws {
        let gameState = await makeGameState()
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        showBoardCelebration(gameState)
        #expect(!scene.debugTapDuringCelebration(), "sin piso nuevo el toque sigue de largo (y saltea)")

        showBoardCelebration(gameState)
        gameState.beginFloorUnlockCelebration(floorID: "f9")
        for _ in 0..<10 { #expect(scene.debugTapDuringCelebration(), "el toque no llega a agarrar un personaje") }
        #expect(gameState.showing == .boardCelebration)
    }
}
