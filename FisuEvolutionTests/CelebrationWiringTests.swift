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

    /// Slots (ordenados) que ocupa un tipo en el piso VISIBLE. Los slots
    /// concretos los decide `firstFreeSlot`, así que no se pinean.
    private func slots(of typeId: String, in gameState: GameState) -> [Int] {
        gameState.visiblePlacements.filter { $0.typeId == typeId }.map(\.slot).sorted()
    }

    /// Fusiona el par de `typeId` que hay en el piso visible por el camino REAL
    /// (`handleDrop`): es el único que pide el turno y el único que sabe si el
    /// ascenso abrió un piso.
    @discardableResult
    private func mergePair(of typeId: String, in gameState: GameState) throws -> GameState.DropResolution {
        let pair = slots(of: typeId, in: gameState)
        try #require(pair.count >= 2, "el fixture no dejó un par de \(typeId) en el piso visible")
        return gameState.handleDrop(fromCell: pair[0], toCell: pair[1])
    }

    /// Vacía la cola. Un ascenso que abre piso deja atrás su propia comitiva —el
    /// sheet de la skin de milestone, el aviso de "ya podés contratar acá", los
    /// logros— y con la cola ocupada no se puede mirar la PRÓXIMA del tablero.
    /// Se despachan los payloads primero: sin eso `syncCelebrations` los
    /// reencolaría en el mismo frame y el bucle no terminaría nunca.
    private func drainCelebrations(_ gameState: GameState) {
        gameState.skinAward = nil
        gameState.towerNotice = nil
        gameState.specialDrop = nil
        gameState.offlineReward = nil
        gameState.dailyClaim = nil
        gameState.careerPrompt = nil
        gameState.achievementToast = nil
        gameState.pendingAchievementToasts.removeAll()
        // Con tope: si algo se reencolara igual, el test falla por el `#expect`
        // de su llamador y no colgando la suite entera.
        for _ in 0..<12 {
            guard let current = gameState.showing else { return }
            gameState.celebrationFinished(current)
        }
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

    /// La UI se apaga sólo en la celebración a pantalla completa **y sólo cuando
    /// esa celebración abre un piso por primera vez**.
    @Test("la UI se apaga sólo en la del tablero, y sólo si abre piso")
    func onlyTheBoardCelebrationHidesTheUI() async throws {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.flushHUD()
        #expect(gameState.celebrationHidesUI == false, "un toast no justifica apagar la interfaz")

        gameState.celebrationFinished(.towerNotice)
        gameState.celebrateBoard(opensNewFloor: true)
        #expect(gameState.celebrationHidesUI)

        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.celebrationHidesUI == false, "y vuelve sola al terminar")
    }

    // MARK: Apagar la UI es exclusivo del primer desbloqueo de un piso

    /// El pedido del dueño: la animación de subir al piso siguiente apaga la UI
    /// **sólo la primera vez que ese piso se desbloquea**.
    @Test("el ascenso que abre un piso por primera vez apaga la UI")
    func theFirstUnlockOfAFloorHidesTheUI() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(4)
        gameState.debugGrantPair()   // dos cartoneros (T4) en el callejón

        guard case .merged(_, _, _, _, let unlockedFloorId) = try mergePair(of: "cartonero", in: gameState) else {
            Issue.record("se esperaba el ascenso a urbano")
            return
        }
        #expect(unlockedFloorId == "urban", "este merge tiene que ABRIR el piso")
        #expect(gameState.showing == .boardCelebration, "la celebración se reproduce igual")
        #expect(gameState.celebrationHidesUI, "el momento más grande del juego se ve solo")
    }

    /// El mismo ascenso, con el piso destino YA abierto: la animación se
    /// reproduce igual, pero no hay nada que justifique apagar la interfaz.
    @Test("ascender a un piso ya desbloqueado no apaga la UI")
    func promotingToAnAlreadyUnlockedFloorKeepsTheUI() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(4)
        gameState.debugUnlockFloors(throughTier: 5)   // urbano ya abierto
        gameState.debugGrantPair()

        guard case .merged(_, _, let promotedType, _, let unlockedFloorId) = try mergePair(of: "cartonero", in: gameState) else {
            Issue.record("se esperaba el ascenso a urbano")
            return
        }
        #expect(promotedType?.id == "mantero", "ascendió igual")
        #expect(unlockedFloorId == nil, "pero no abrió nada: el piso ya estaba")
        #expect(gameState.showing == .boardCelebration, "la celebración se reproduce igual")
        #expect(gameState.celebrationHidesUI == false)
    }

    /// El reveal que se queda en el mismo piso tampoco apaga nada: no hay
    /// ascenso, y mucho menos un piso nuevo.
    @Test("el reveal en el mismo piso no apaga la UI")
    func aSameFloorRevealKeepsTheUI() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()   // dos fisuras (T1) en el callejón

        guard case .merged(_, let evolvedTo, _, let promotedToFloor, _) = try mergePair(of: "homeless", in: gameState) else {
            Issue.record("se esperaba la fusión a trapito")
            return
        }
        #expect(evolvedTo?.id == "trapito", "hay reveal")
        #expect(promotedToFloor == nil, "pero se queda en el callejón")
        #expect(gameState.showing == .boardCelebration, "la celebración se reproduce igual")
        #expect(gameState.celebrationHidesUI == false)
    }

    /// La bandera describe UNA celebración, no un estado del juego: si sobrevive
    /// a la suya, el próximo ascenso común hereda la pantalla apagada. Se prueban
    /// las tres salidas de la cola, que es donde tiene que soltarse.
    @Test("apagar la UI no sobrevive a su propia celebración")
    func theHidingFlagDoesNotOutliveItsCelebration() async throws {
        for exit in ["finish", "skip", "watchdog"] {
            let gameState = await makeGameState()
            gameState.debugSetMaxTier(4)
            gameState.debugGrantPair()
            try mergePair(of: "cartonero", in: gameState)
            #expect(gameState.celebrationHidesUI, "\(exit): el desbloqueo apaga la UI")

            switch exit {
            case "finish":
                gameState.celebrationFinished(.boardCelebration)
            case "skip":
                gameState.tick(delta: 1)   // pasa el piso de tiempo del tap
                #expect(gameState.skipCurrentCelebration())
            default:
                gameState.tick(delta: 8.1)   // tope de `.boardCelebration`
            }
            #expect(gameState.showing != .boardCelebration, "\(exit): la celebración terminó")
            drainCelebrations(gameState)
            #expect(gameState.showing == nil)

            // Una del tablero que nadie marcó como desbloqueo: si la bandera
            // quedó puesta, ésta hereda la pantalla apagada.
            gameState.celebrate(.boardCelebration)
            #expect(gameState.showing == .boardCelebration)
            #expect(gameState.celebrationHidesUI == false, "\(exit): quedó una bandera vieja")
        }
    }

    /// Mientras la del tablero ESPERA turno, la cola la deduplica en un solo
    /// casillero y la escena pisa el payload con el del último merge: lo que se
    /// reproduce es el último, así que la bandera tiene que ser la del último.
    @Test("mientras espera turno, gana el último merge")
    func whileQueuedTheLastMergeWins() async throws {
        let gameState = await makeGameState()
        // Lo de arranque de sesión tiene más prioridad: retiene el turno y deja
        // a la del tablero esperando en la fila, que es la única ventana en la
        // que un segundo merge puede pisar al primero.
        gameState.offlineReward = GameState.OfflineReward(amount: 1_000)
        gameState.flushHUD()
        #expect(gameState.showing == .offlineEarnings)

        gameState.debugGrantPair()
        try mergePair(of: "homeless", in: gameState)   // común: no abre piso
        gameState.debugSetMaxTier(4)
        gameState.debugGrantPair()
        try mergePair(of: "cartonero", in: gameState)  // y encima cae el que SÍ abre

        gameState.offlineReward = nil
        gameState.celebrationFinished(.offlineEarnings)
        #expect(gameState.showing == .boardCelebration)
        #expect(gameState.celebrationHidesUI, "se reproduce el último, y ése abre piso")
    }
}
