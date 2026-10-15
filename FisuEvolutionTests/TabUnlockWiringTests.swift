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

    @Test("terminar el núcleo abre Bonus, Menú y Tienda, con ¡Nuevo!, y se guarda")
    func coreUnlocksAndPersists() async throws {
        let gameState = await makeGameState(core: false, sessions: 0)
        gameState.refreshProjections()
        TutorialFlags.setCoreCompleted(true, in: gameState.flagDefaults)
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs == [.jobs, .upgrades, .gifts, .menu, .store])
        #expect(gameState.newTabs == [.gifts, .menu, .store])
        let saved = try #require(gameState.player?.meta.unlockedTabs)
        #expect(saved.isSuperset(of: ["gifts", "menu"]))

        gameState.markTabOpened(.gifts)
        #expect(gameState.newTabs == [.menu, .store])
    }

    @Test("con el interruptor del ranking apagado la tarjeta del Menú no aparece, y la barra no cambia")
    func rankingSwitchHidesTheCard() async {
        let gameState = await makeGameState(core: true, sessions: 0)
        let off = RankingConfig(
            schemaVersion: RankingConfig.supportedSchemaVersion, enabled: false, baseURL: nil, anonKey: nil)
        let store = RankingStore(client: SimulatedRankingClient(), config: off)
        gameState.attachRanking(store)
        gameState.refreshProjections()
        #expect(!gameState.rankingCardIsShown)
        #expect(!gameState.unlockedTabsInBarOrder.contains(.ranking))
        #expect(gameState.unlockedTabsInBarOrder.contains(.store))
    }

    @Test("con el interruptor del ranking prendido la tarjeta del Menú está")
    func rankingCardShowsWhenEnabled() async {
        let gameState = await makeGameState(core: true, sessions: 0)
        gameState.refreshProjections()
        #expect(gameState.rankingCardIsShown)
    }

    @Test("la Tienda pedida por el + de la moneda abre sola mientras la barra no la tiene, y como página si ya está")
    func storePagesDependOnTheBar() async {
        let gameState = await makeGameState(core: false, sessions: 0)
        gameState.refreshProjections()
        #expect(gameState.menuPages(startingAt: .store) == [.store])
        TutorialFlags.setCoreCompleted(true, in: gameState.flagDefaults)
        gameState.refreshProjections()
        #expect(gameState.menuPages(startingAt: .store) == gameState.unlockedTabsInBarOrder)
        #expect(gameState.menuPages(startingAt: .store).first == .store)
    }

    @Test("un save que trae el Ranking como pestaña no lo cuela en la barra, y no se lo borra")
    func legacyRankingStaysOutOfTheBar() async {
        let gameState = await makeGameState(core: true, sessions: 1)
        gameState.player?.meta.unlockedTabs.insert("ranking")
        gameState.refreshProjections()
        #expect(!gameState.unlockedTabsInBarOrder.contains(.ranking))
        #expect(!gameState.unlockedTabs.contains(.ranking))
        #expect(gameState.player?.meta.unlockedTabs.contains("ranking") == true)
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
}
