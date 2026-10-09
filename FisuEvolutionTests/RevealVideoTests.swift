import EconomyKit
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("La revelación con el cuerpo entero")
@MainActor
struct RevealVideoTests {
    private func manifest(characters: [String]) throws -> LoopsManifest {
        let entries = characters.map {
            #""\#($0)":{"file":"cine_arresto.mov","width":512,"height":512,"fps":24,"frames":120,"alpha":true,"audio":false}"#
        }.joined(separator: ",")
        let json = #"{"schemaVersion":1,"characters":{\#(entries)}}"#
        return try JSONDecoder().decode(LoopsManifest.self, from: Data(json.utf8))
    }

    /// `BoardScene` guarda el `GameState` como `unowned`: el test tiene que sostenerlo.
    private func sceneWithChain(characters: [String]?, pool: VideoPlayerPool) async throws -> (BoardScene, GameState) {
        let gameState = await makeGameState()
        let ids = characters ?? gameState.content?.tiers.concreteTypes.map(\.id) ?? []
        let scene = BoardScene(gameState: gameState, loops: try manifest(characters: ids), videoPool: pool)
        gameState.debugSeedMergeAll(homeless: 8)
        scene.didMove(to: SKView())
        gameState.syncCelebrations()
        scene.update(1)
        scene.scrollSettled()
        return (scene, gameState)
    }

    /// Sin `SKView` nadie evalúa la `SKAction` que asienta la cámara tras un cambio de piso:
    /// el test la asienta a mano antes de cada paso.
    private func stepUntilReveal(_ scene: BoardScene) -> Bool {
        for _ in 0..<20 {
            scene.scrollSettled()
            if scene.debugRevealVideo != nil { return true }
            scene.debugCompleteBoardChangeStep()
        }
        return scene.debugRevealVideo != nil
    }

    @Test("el reveal de un tier con loop pide su lease y el paso que lo cierra lo suelta")
    func revealHoldsTheLeaseUntilItCloses() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await sceneWithChain(characters: nil, pool: pool)
        #expect(stepUntilReveal(scene))
        #expect(pool.liveCount == 1)
        scene.debugCompleteBoardChangeStep()
        #expect(scene.debugRevealVideo == nil && pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("sin entrada en el manifest el reveal es el de siempre")
    func noEntryNoVideo() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await sceneWithChain(characters: [], pool: pool)
        for _ in 0..<20 { scene.debugCompleteBoardChangeStep() }
        #expect(scene.debugRevealVideo == nil && pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("un toque que apura la cadena en pleno reveal suelta el video")
    func hurryingReleases() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await sceneWithChain(characters: nil, pool: pool)
        #expect(stepUntilReveal(scene))
        gameState.tick(delta: 1)
        scene.debugTapDuringCelebration()
        #expect(scene.debugRevealVideo == nil && pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("el watchdog que se lleva el turno en pleno reveal suelta el video")
    func watchdogReleases() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await sceneWithChain(characters: nil, pool: pool)
        #expect(stepUntilReveal(scene))
        for _ in 0..<15 { gameState.tick(delta: 1) }
        scene.update(2)
        #expect(scene.debugRevealVideo == nil && pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("sacar la escena de la vista baja el lease y volver lo recupera")
    func detachingReleases() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await sceneWithChain(characters: nil, pool: pool)
        #expect(stepUntilReveal(scene))
        scene.willMove(from: SKView())
        #expect(pool.liveCount == 0)
        scene.didMove(to: SKView())
        scene.scrollSettled()
        #expect(pool.liveCount == 1)
        scene.debugCompleteBoardChangeStep()
        #expect(pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("con la política apagada el reveal queda en la foto")
    func stillPolicyKeepsThePhoto() async throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let (scene, gameState) = try await sceneWithChain(characters: nil, pool: pool)
        #expect(stepUntilReveal(scene))
        #expect(pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("la segunda tanda real ya tiene entrada para los tipos que se revelan, en un pack ODR")
    func realCharactersHaveEntries() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let ids = content.tiers.concreteTypes.map(\.id).filter { LoopsManifest.main.characters[$0] != nil }
        #expect(!ids.isEmpty)
        for id in ids {
            #expect(LoopsManifest.main.odrTag(for: .character(id)) != nil, "\(id)")
        }
    }
}
