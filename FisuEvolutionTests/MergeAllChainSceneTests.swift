import EconomyKit
import SpriteKit
import Testing
@testable import FisuEvolution

/// Sin `SKView` nadie evalúa las `SKAction`: la escena expone en DEBUG el paso
/// que dispararía la acción en curso (patrón de `BoardGestureTests`).
@Suite("Fusionar todo: la escena encadena")
@MainActor
struct MergeAllChainSceneTests {
    private func sceneWithChain() async -> (BoardScene, GameState) {
        let gameState = await makeGameState()
        gameState.debugSeedMergeAll(homeless: 8)
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        gameState.syncCelebrations()
        return (scene, gameState)
    }

    @Test("los siete eslabones corren en un turno: nadie se mete en el medio")
    func theSceneKeepsTheTurn() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        #expect(scene.debugPlayingChain?.index == 0)
        var guardrail = 0
        while scene.debugIsPlayingBoardChange || scene.debugPlayingChain != nil, guardrail < 60 {
            #expect(gameState.showing == .boardCelebration)
            scene.debugCompleteBoardChangeStep()
            guardrail += 1
        }
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.units["cartonero"] == 1)
        #expect(gameState.player?.run.revealedTier == 4, "los tres tiers nuevos se revelaron en la cadena")
        #expect(gameState.showing != .boardCelebration, "al final, el turno se suelta")
    }

    @Test("una hoja a mitad de cadena suelta el turno y la cadena sigue después")
    func aSheetPausesTheChain() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        scene.debugCompleteBoardChangeStep()
        gameState.uiCoversBoard = true
        for _ in 0..<6 where gameState.showing == .boardCelebration { scene.debugCompleteBoardChangeStep() }
        #expect(gameState.showing != .boardCelebration)
        #expect(!gameState.pendingBoardChanges.isEmpty)
    }

    @Test("el watchdog que asienta un eslabón corta la escena sin trabar la cadena")
    func watchdogMidChain() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        for _ in 0..<15 { gameState.tick(delta: 1) }
        scene.update(2)
        #expect(scene.debugPlayingChain == nil || gameState.inFlightBoardChange != nil,
                "o cortó, o arrancó el turno siguiente con el eslabón que sigue")
    }
}
