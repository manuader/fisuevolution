import Foundation
import Testing
@testable import FisuEvolution

/// La barra progresiva contra el `GameState` real: qué se publica, qué se
/// guarda y que nunca se vuelve a cerrar.
///
/// ⚠️ Las banderas del tutorial viven en `UserDefaults` y el host de los tests
/// las comparte: cada test las pone y las restaura.
@Suite("Las pestañas progresivas en el GameState", .serialized)
@MainActor
struct TabUnlockWiringTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "tabs-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    private func withDefaults(core: Bool, sessions: Int, _ body: @MainActor () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let savedCore = defaults.object(forKey: "fisuTutorialDone")
        let savedSessions = defaults.object(forKey: GameState.sessionsAfterPhaseKey)
        let savedNew = defaults.object(forKey: GameState.newTabsKey)
        defaults.set(core, forKey: "fisuTutorialDone")
        defaults.set(sessions, forKey: GameState.sessionsAfterPhaseKey)
        defaults.removeObject(forKey: GameState.newTabsKey)
        defer {
            defaults.set(savedCore, forKey: "fisuTutorialDone")
            defaults.set(savedSessions, forKey: GameState.sessionsAfterPhaseKey)
            defaults.set(savedNew, forKey: GameState.newTabsKey)
        }
        try await body()
    }

    @Test("partida nueva: Contratar y Mejoras, sin ¡Nuevo!")
    func freshGame() async {
        await withDefaults(core: false, sessions: 0) {
            let gameState = await makeGameState()
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs == [.jobs, .upgrades])
            #expect(gameState.newTabs.isEmpty, "las que abren desde el arranque no son novedad")
            #expect(gameState.unlockedTabsInBarOrder == [.upgrades, .jobs])
        }
    }

    @Test("terminar el núcleo abre Bonus y Menú, con ¡Nuevo!, y se guarda")
    func coreUnlocksAndPersists() async throws {
        try await withDefaults(core: false, sessions: 0) {
            let gameState = await makeGameState()
            gameState.refreshProjections()
            UserDefaults.standard.set(true, forKey: "fisuTutorialDone")
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs == [.jobs, .upgrades, .gifts, .menu])
            #expect(gameState.newTabs == [.gifts, .menu])
            let saved = try #require(gameState.player?.meta.unlockedTabs)
            #expect(saved.isSuperset(of: ["gifts", "menu"]))

            gameState.markTabOpened(.gifts)
            #expect(gameState.newTabs == [.menu])
        }
    }

    @Test("una pestaña abierta no se vuelve a cerrar")
    func neverCloses() async {
        await withDefaults(core: true, sessions: 0) {
            let gameState = await makeGameState()
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs.contains(.menu))
            UserDefaults.standard.set(false, forKey: "fisuTutorialDone")
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs.contains(.menu))
        }
    }

    @Test("la primera pinta abre Vestimenta")
    func firstSkinOpensSkins() async {
        await withDefaults(core: true, sessions: 0) {
            let gameState = await makeGameState()
            let skin = gameState.content?.skins.skins.first { $0.isMilestone }
            #expect(skin != nil, "el catálogo real tiene skins de milestone")
            gameState.grantMilestoneSkinsForTests([skin?.id].compactMap { $0 })
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs.contains(.skins))
        }
    }

    @Test("apagada (corridas de UI sin el flag), la barra está entera y sin ¡Nuevo!")
    func disabledShowsTheWholeBar() async {
        await withDefaults(core: false, sessions: 0) {
            let gameState = await makeGameState()
            gameState.progressiveTabsEnabled = false
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs == Set(GameScreen.barOrder))
            #expect(gameState.newTabs.isEmpty)
        }
    }

    @Test("un save de la v1 que trae la Tienda no la cuela en la barra, y no se la borra")
    func legacyStoreStaysOutOfTheBar() async {
        await withDefaults(core: true, sessions: 1) {
            let gameState = await makeGameState()
            gameState.player?.meta.unlockedTabs.insert("store")
            gameState.refreshProjections()
            #expect(!gameState.unlockedTabsInBarOrder.contains(.store))
            #expect(!gameState.unlockedTabs.contains(.store))
            #expect(gameState.player?.meta.unlockedTabs.contains("store") == true)
        }
    }
}
