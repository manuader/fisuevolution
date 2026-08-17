import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El cableado de la cola de celebraciones sobre el contenido real. La lógica de
/// orden es pura y vive en `CelebrationQueueTests`; acá se prueba que
/// `GameState` encole lo que corresponde, que las superficies esperen su turno y
/// —sobre todo— que la cola **nunca apunte a una superficie sin payload**, que es
/// el riesgo conocido de guardar el turno por separado del contenido.
@Suite("Cola de celebraciones: cableado")
@MainActor
struct CelebrationWiringTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "celeb-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    private func anAward(_ gameState: GameState) throws -> GameState.SkinAward {
        let type = try #require(gameState.content?.tiers.baseType)
        return GameState.SkinAward(id: "urban_trailblazer", characterType: type)
    }

    /// El payload de lo que ESTÁ mostrándose tiene que existir. Si esto se rompe,
    /// el jugador ve un hueco: la cola dice "le toca al sheet de skin" y no hay
    /// skin que mostrar, así que no aparece nada y el turno queda trabado.
    private func assertPayloadExists(_ gameState: GameState, _ line: Int = #line) {
        switch gameState.showing {
        case .none, .boardCelebration:
            break   // la del tablero no tiene payload en GameState: la maneja la escena
        case .offlineEarnings: #expect(gameState.offlineReward != nil)
        case .dailyReward: #expect(gameState.dailyClaim != nil)
        case .careerChoice: #expect(gameState.careerPrompt != nil)
        case .skinAward: #expect(gameState.skinAward != nil)
        case .specialDrop: #expect(gameState.specialDrop != nil)
        case .towerNotice: #expect(gameState.towerNotice != nil)
        case .achievements:
            #expect(gameState.achievementToast != nil || !gameState.pendingAchievementToasts.isEmpty)
        case .eventBanner: #expect(gameState.activeEvent != nil)
        }
    }

    @Test("dos celebraciones a la vez salen de a una, por prioridad")
    func twoAtOnceComeOutOneByOne() async throws {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)   // prioridad 6
        gameState.skinAward = try anAward(gameState)                     // prioridad 4
        gameState.flushHUD()

        #expect(gameState.showing == .skinAward, "el sheet tiene más prioridad que el aviso")
        assertPayloadExists(gameState)

        gameState.skinAward = nil
        gameState.celebrationFinished(.skinAward)
        #expect(gameState.showing == .towerNotice, "y el aviso sale después, no encima")
        assertPayloadExists(gameState)
    }

    @Test("la cola nunca apunta a una superficie sin payload")
    func theQueueNeverPointsAtNothing() async throws {
        let gameState = await makeGameState()
        assertPayloadExists(gameState)

        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.flushHUD()
        assertPayloadExists(gameState)

        // Cerrarlo tiene que dejar la cola vacía, no apuntando a un fantasma.
        gameState.dismissTowerNotice(id: try #require(gameState.towerNotice?.id))
        assertPayloadExists(gameState)
        #expect(gameState.showing == nil)
    }

    /// Sin esto, un aviso que se cierra solo se reencolaría para siempre: el
    /// payload seguiría puesto y `syncCelebrations` lo volvería a meter en la
    /// fila en el mismo frame.
    @Test("lo que se cierra solo no vuelve a encolarse")
    func selfClosingItemsDoNotLoop() async throws {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.flushHUD()
        #expect(gameState.showing == .towerNotice)

        gameState.celebrationFinished(.towerNotice)
        gameState.flushHUD()
        #expect(gameState.showing == nil, "el aviso reapareció: el payload no se limpió")
        #expect(gameState.towerNotice == nil)
    }

    @Test("el watchdog destraba lo que nunca avisa que terminó")
    func watchdogUnsticksTheQueue() async throws {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)   // tope 4 s
        gameState.skinAward = try anAward(gameState)
        gameState.flushHUD()

        // El sheet primero (prioridad 4) y NO se vence: lo cierra el jugador.
        #expect(gameState.showing == .skinAward)
        gameState.tick(delta: 60)
        #expect(gameState.showing == .skinAward, "un sheet espera lo que haga falta")

        gameState.skinAward = nil
        gameState.celebrationFinished(.skinAward)
        #expect(gameState.showing == .towerNotice)
        gameState.tick(delta: 4.1)
        #expect(gameState.showing == nil, "el aviso sí tiene tope")
        #expect(gameState.towerNotice == nil)
    }

    @Test("el tap saltea, pero no antes del piso de tiempo")
    func tapSkipsAfterTheFloor() async throws {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.flushHUD()

        gameState.tick(delta: 0.3)
        #expect(gameState.skipCurrentCelebration() == false, "sin piso, el próximo tap lo mataría enseguida")
        #expect(gameState.showing == .towerNotice)

        gameState.tick(delta: 0.4)
        #expect(gameState.skipCurrentCelebration())
        #expect(gameState.showing == nil)
        #expect(gameState.towerNotice == nil)
    }

    @Test("un tap no cierra un sheet")
    func tapDoesNotDismissASheet() async throws {
        let gameState = await makeGameState()
        gameState.skinAward = try anAward(gameState)
        gameState.flushHUD()
        gameState.tick(delta: 5)
        #expect(gameState.skipCurrentCelebration() == false, "el sheet tiene su botón")
        #expect(gameState.showing == .skinAward)
    }

    /// El HUD sólo se apaga en la celebración a pantalla completa.
    @Test("el HUD se atenúa sólo en la del tablero")
    func onlyTheBoardCelebrationDimsTheHUD() async throws {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.flushHUD()
        #expect(gameState.celebrationDimsHUD == false, "un toast no justifica apagar el HUD")

        gameState.celebrationFinished(.towerNotice)
        gameState.celebrate(.boardCelebration)
        #expect(gameState.celebrationDimsHUD)

        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.celebrationDimsHUD == false)
    }
}
