import Foundation
import Testing
@testable import FisuEvolution

/// La barra progresiva contra el `GameState` real: qué se publica, qué se
/// guarda y que nunca se vuelve a cerrar.
///
/// Las banderas del tutorial van a un dominio de `UserDefaults` propio de cada test
/// (`isolatedForTest()`): el host no se entera.
@Suite("Las pestañas progresivas en el GameState", .serialized)
@MainActor
struct TabUnlockWiringTests {
    private func makeGameState(core: Bool, sessions: Int) async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "tabs-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        gameState.flagDefaults = .isolatedForTest()
        TutorialFlags.setCoreCompleted(core, in: gameState.flagDefaults)
        gameState.flagDefaults.set(sessions, forKey: GameState.sessionsAfterPhaseKey)
        await gameState.bootstrap()
        return gameState
    }

    @Test("partida nueva: Contratar y Mejoras, sin ¡Nuevo!")
    func freshGame() async {
        let gameState = await makeGameState(core: false, sessions: 0)
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs == [.jobs, .upgrades])
        #expect(gameState.newTabs.isEmpty, "las que abren desde el arranque no son novedad")
        #expect(gameState.unlockedTabsInBarOrder == [.upgrades, .jobs])
    }

    @Test("terminar el núcleo abre Bonus, Menú y Ranking, con ¡Nuevo!, y se guarda")
    func coreUnlocksAndPersists() async throws {
        let gameState = await makeGameState(core: false, sessions: 0)
        gameState.refreshProjections()
        TutorialFlags.setCoreCompleted(true, in: gameState.flagDefaults)
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs == [.jobs, .upgrades, .gifts, .menu, .ranking])
        #expect(gameState.newTabs == [.gifts, .menu, .ranking])
        let saved = try #require(gameState.player?.meta.unlockedTabs)
        #expect(saved.isSuperset(of: ["gifts", "menu"]))

        gameState.markTabOpened(.gifts)
        #expect(gameState.newTabs == [.menu, .ranking])
    }

    @Test("con el interruptor del ranking apagado la pestaña no está, pero sigue abierta en el save")
    func rankingSwitchHidesTheTab() async {
        let gameState = await makeGameState(core: true, sessions: 0)
        let off = RankingConfig(
            schemaVersion: RankingConfig.supportedSchemaVersion, enabled: false, baseURL: nil, anonKey: nil)
        let store = RankingStore(client: SimulatedRankingClient(), config: off)
        gameState.attachRanking(store)
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs.contains(.ranking))
        #expect(!gameState.unlockedTabsInBarOrder.contains(.ranking))
    }

    @Test("una pestaña abierta no se vuelve a cerrar")
    func neverCloses() async {
        let gameState = await makeGameState(core: true, sessions: 0)
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs.contains(.menu))
        TutorialFlags.setCoreCompleted(false, in: gameState.flagDefaults)
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs.contains(.menu))
    }

    @Test("la primera pinta abre Vestimenta")
    func firstSkinOpensSkins() async {
        let gameState = await makeGameState(core: true, sessions: 0)
        let skin = gameState.content?.skins.skins.first { $0.isMilestone }
        #expect(skin != nil, "el catálogo real tiene skins de milestone")
        gameState.grantMilestoneSkinsForTests([skin?.id].compactMap { $0 })
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs.contains(.skins))
    }

    @Test("apagada (corridas de UI sin el flag), la barra está entera y sin ¡Nuevo!")
    func disabledShowsTheWholeBar() async {
        let gameState = await makeGameState(core: false, sessions: 0)
        gameState.progressiveTabsEnabled = false
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs == Set(GameScreen.barOrder))
        #expect(gameState.newTabs.isEmpty)
    }

    @Test("un save de la v1 que trae la Tienda no la cuela en la barra, y no se la borra")
    func legacyStoreStaysOutOfTheBar() async {
        let gameState = await makeGameState(core: true, sessions: 1)
        gameState.player?.meta.unlockedTabs.insert("store")
        gameState.refreshProjections()
        #expect(!gameState.unlockedTabsInBarOrder.contains(.store))
        #expect(!gameState.unlockedTabs.contains(.store))
        #expect(gameState.player?.meta.unlockedTabs.contains("store") == true)
    }
}
