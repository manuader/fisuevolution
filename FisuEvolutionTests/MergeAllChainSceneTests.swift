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
            scene.update(1 + Double(guardrail) * 0.01)
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

    @Test("el watchdog que se lleva el turno en pleno reveal corta la cadena")
    func watchdogMidChain() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        var guardrail = 0
        while scene.debugIsPlayingBoardChange, guardrail < 10 {
            scene.debugCompleteBoardChangeStep()
            guardrail += 1
        }
        #expect(scene.debugPlayingChain != nil, "el reveal del eslabón 0 sigue con la cadena viva")
        for _ in 0..<15 { gameState.tick(delta: 1) }
        scene.update(2)
        #expect(
            (scene.debugPlayingChain == nil && gameState.showing != .boardCelebration)
                || scene.debugPlayingChain?.index == 1,
            "o cortó, o retomó la cadena en el eslabón siguiente"
        )
    }

    @Test("un toque a mitad de cadena apura: el eslabón se asienta y la cadena sigue")
    func aTapHurriesTheChain() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        gameState.tick(delta: 1)
        let pending = gameState.pendingBoardChanges.count
        scene.debugTapDuringCelebration()
        #expect(gameState.showing == .boardCelebration, "el toque no se come la cadena")
        #expect(gameState.pendingBoardChanges.count == pending - 1, "arrancó el eslabón siguiente")
        #expect(scene.debugPlayingChain?.index == 1)
    }

    @Test("antes del piso del skip, el toque no apura")
    func aTapBeforeTheFloorDoesNothing() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        let pending = gameState.pendingBoardChanges.count
        scene.debugTapDuringCelebration()
        #expect(gameState.pendingBoardChanges.count == pending)
        #expect(scene.debugPlayingChain?.index == 0)
    }

    @Test("tocando sin parar, la cadena termina igual y el tier más alto se revela")
    func tappingThroughStillReveals() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        for step in 0..<80 {
            gameState.syncCelebrations()
            gameState.tick(delta: 1)
            scene.debugTapDuringCelebration()
            scene.update(TimeInterval(2 + step))
        }
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.units["cartonero"] == 1)
        #expect(gameState.player?.run.revealedTier == 4)
    }

    @Test("durante la cadena, un toque nunca agarra a un personaje")
    func aTapDuringTheChainGrabsNothing() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        gameState.tick(delta: 1)
        #expect(scene.debugTapDuringCelebration(), "el toque se consume: no llega a agarrar a nadie")
        #expect(scene.debugPlayingChain != nil)
    }

    @Test("el contador cuenta desde el segundo eslabón")
    func theComboCounts() async {
        let (scene, gameState) = await sceneWithChain()
        defer { withExtendedLifetime(gameState) {} }
        scene.update(1)
        #expect(scene.debugComboText == nil)
        var guardrail = 0
        while scene.debugComboText == nil, guardrail < 20 {
            scene.debugCompleteBoardChangeStep()
            guardrail += 1
        }
        #expect(scene.debugComboText == "×2")
    }

    @Test("fuera de una cadena, el toque saltea como siempre")
    func outsideAChainTheTapSkips() async {
        let gameState = await makeGameState()
        gameState.debugPlanBoardChange()
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        gameState.syncCelebrations()
        scene.update(1)
        gameState.tick(delta: 1)
        scene.debugTapDuringCelebration()
        #expect(gameState.inFlightBoardChange == nil)
        #expect(scene.debugIsPlayingBoardChange == false)
    }
}
