import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El núcleo del tutorial (`core.tap` → `core.hire` → `core.merge` → `core.finish`) corre en el
/// director: no se saltea, el cierre espera su candado de 5 s, y al cerrarlo la cola se libera
/// y cae el cofre de bienvenida.
///
/// ⚠️ Los milestones `ftue.*` viven en los defaults del host y se leen en el `init`: se barren
/// antes de crear el `GameState`. Las del núcleo van al dominio propio de cada test
/// (`UserDefaults.isolatedForTest()`): cerrarlo acá no le deja nada al host.
@Suite("El núcleo del tutorial en el director", .serialized)
@MainActor
struct TutorialCoreTests {
    private let flagKeys = [TutorialFlags.versionKey, TutorialFlags.completedKey,
                            TutorialFlags.tourPendingKey, TutorialFlags.legacyCompletedKey,
                            TutorialFlags.sessionsAfterCoreKey]

    private func makeGameState() async -> GameState {
        for key in TutorialFlags.milestoneKeys { UserDefaults.standard.set(false, forKey: key) }
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "core-\(UUID().uuidString).json")
        ))
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        return gameState
    }

    /// Una partida con los tres milestones hechos: el núcleo arranca en el cierre.
    private func gameStateAtTheFinish() async -> GameState {
        let gameState = await makeGameState()
        gameState.ftueTapped = true
        gameState.ftueSpawned = true
        gameState.ftueMerged = true
        gameState.debugGrantCoins()
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        return gameState
    }

    @Test("empieza en core.tap y avanza por acciones")
    func walksTheCore() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .core)
        #expect(gameState.tutorialRun?.step?.id == "core.tap")
        #expect(gameState.tutorialBoardTarget == .anyUnit, "el recorte del tablero lo pide el director")
        gameState.debugGrantCoins()
        gameState.ftueTapped = true
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "core.hire")
        #expect(gameState.tutorialBoardTarget == nil, "contratar no ilumina el tablero")
        #expect(gameState.tutorialPhaseActive)
    }

    @Test("un paso de acción no se cumple sin hacerlo: «Entendido» y el tiempo no lo mueven")
    func actionStepsWaitForTheAction() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        gameState.confirmTutorialStep()
        gameState.advanceTutorial(delta: 60)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "core.tap")
        gameState.ftueTapped = true
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "core.hire", "haciéndolo, sí avanza")
    }

    @Test("retoma en el primer paso no cumplido (los milestones persisten)")
    func resumes() async {
        let gameState = await makeGameState()
        gameState.ftueTapped = true
        gameState.ftueSpawned = true
        // Sin plata a propósito: quien ya contrató no vuelve a `core.tap` a juntar para contratar.
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "core.merge")
        #expect(gameState.tutorialBoardTarget == .mergePair)
    }

    @Test("el cierre espera 5 s, entrega el cofre una vez y termina la fase")
    func theFinishStep() async {
        let gameState = await gameStateAtTheFinish()
        #expect(gameState.tutorialRun?.step?.id == "core.finish")
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialPhaseActive, "con el candado puesto, «¡Vamos!» no hace nada")
        gameState.advanceTutorial(delta: 4.9)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialPhaseActive, "a los 4,9 s tampoco")
        #expect(gameState.tutorialRun?.unlocked == false)
        gameState.advanceTutorial(delta: 0.1)
        #expect(gameState.tutorialRun?.unlocked == true, "a los 5 s el candado se abre")
        gameState.confirmTutorialStep()
        #expect(!gameState.tutorialPhaseActive)
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.tutorialBoardTarget == nil)
        #expect(TutorialFlags.coreCompleted(in: gameState.flagDefaults))
        #expect(gameState.player?.meta.welcomeChestGiven == true)
    }

    @Test("el candado del cierre no corre con una celebración en pantalla (el reveal del merge)")
    func theLockWaitsForTheReveal() async {
        let gameState = await gameStateAtTheFinish()
        gameState.celebrateBoard(showsSomethingNew: true)
        #expect(gameState.showing == .boardCelebration)
        gameState.advanceTutorial(delta: 5)
        #expect(gameState.tutorialRun?.unlocked == false, "el cierre todavía no se ve")
        gameState.celebrationFinished(.boardCelebration)
        gameState.advanceTutorial(delta: 5)
        #expect(gameState.tutorialRun?.unlocked == true)
    }

    @Test("al cerrar el núcleo la cola se libera: lo que esperó desfila")
    func theCoreReleasesTheQueue() async {
        let gameState = await gameStateAtTheFinish()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        #expect(gameState.showing == nil, "con el núcleo vivo, el aviso espera (y el núcleo no ocupa turno)")
        gameState.advanceTutorial(delta: 5)
        gameState.confirmTutorialStep()
        #expect(gameState.showing != nil, "la cola quedó libre al cerrar")
        // Lo que esperaba (el aviso y el cofre de bienvenida) desfila de a uno, sin trabarse.
        var seen: Set<CelebrationKind> = []
        var turns = 0
        while let current = gameState.showing, turns < 6 {
            turns += 1
            seen.insert(current)
            switch current {
            case .chestOpening: gameState.dismissChestReward()
            default: gameState.celebrationFinished(current)
            }
        }
        #expect(seen.contains(.towerNotice))
        #expect(seen.contains(.chestOpening))
        #expect(gameState.showing == nil)
    }

    @Test("ninguna otra corrida pisa al núcleo vivo (la cola quedaría restringida para siempre)")
    func nothingReplacesTheCore() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        gameState.startTutorialRun(.lesson("probe"), steps: [.explain("probe.explain", text: "tutorial.step.finish")])
        #expect(gameState.tutorialRun?.script == .core)
        #expect(gameState.showing == nil, "y no pidió turno en la cola")
        #expect(gameState.tutorialPhaseActive)
    }

    @Test("el toque al tablero no saltea el núcleo")
    func boardTouchesDoNotSkip() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        #expect(!gameState.skipCurrentCelebration())
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "core.tap")
        #expect(gameState.tutorialPhaseActive)
    }

    @Test("durante el núcleo no hay momento calmo: no nacen paquetes, colchones ni visitantes")
    func noCalmDuringTheCore() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        #expect(!gameState.isCalmMoment)
    }

    @Test("un veterano de la v1 no ve el núcleo otra vez; una instalación nueva sí")
    func veteransSkipTheCore() async {
        // El bootstrap ya corrió su migración (partida en memoria = instalación nueva): las
        // banderas se barren DESPUÉS, para que la del test sea la primera.
        do {
            let veteran = await makeGameState()
            for key in flagKeys { veteran.flagDefaults.removeObject(forKey: key) }
            veteran.flagDefaults.set(true, forKey: TutorialFlags.legacyCompletedKey)
            veteran.applyTutorialMigration(hasSave: true)
            veteran.startTutorialCoreIfPending()
            #expect(!veteran.tutorialPhaseActive)
            #expect(veteran.tutorialRun?.script != .core)
        }
        do {
            let fresh = await makeGameState()
            for key in flagKeys { fresh.flagDefaults.removeObject(forKey: key) }
            fresh.applyTutorialMigration(hasSave: false)
            fresh.startTutorialCoreIfPending()
            #expect(fresh.tutorialPhaseActive)
            #expect(fresh.tutorialRun?.script == .core)
        }
    }
}
