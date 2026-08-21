import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El director de las lecciones contextuales (`GameState+TutorialTips`). La
/// regla que se pinea acá es la del dueño: **ninguna lección manda a una
/// pantalla donde en ese momento no hay nada que hacer** — ni al nacer, ni
/// después de esperar turno.
///
/// ⚠️ Los defaults de lecciones persisten en el host de los tests: cada caso
/// arranca barriéndolos, o una lección "dada" por el test anterior cambia qué
/// nace en éste. Y el director arranca APAGADO bajo XCTest (mismo criterio que
/// el gate del bootstrap): cada test lo prende explícito.
@Suite("Lecciones contextuales del tutorial", .serialized)
@MainActor
struct TutorialTipsTests {
    private func makeGameState() async -> GameState {
        for lesson in GameState.TutorialLesson.allCases {
            UserDefaults.standard.removeObject(forKey: lesson.defaultsKey)
        }
        UserDefaults.standard.removeObject(forKey: GameState.sessionsAfterPhaseKey)
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "tips-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        return gameState
    }

    @Test("sin señal no nace ninguna lección; con la señal, nace la primera del orden")
    func lessonsWaitForTheirSignal() async {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "partida nueva sin plata: no hay nada que hacer en ninguna pantalla")

        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades,
                "con plata, la mejora es pagable y la lección de Mejoras es la primera del orden")
        #expect(gameState.showing == .tutorialTip, "y viaja por la cola como cualquier celebración")
    }

    @Test("con la fase obligatoria viva no nace ninguna lección")
    func noLessonsDuringThePhase() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "las lecciones arrancan recién cuando la fase termina")
        gameState.tutorialPhaseFinished()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades)
    }

    @Test("una lección dada no vuelve, y el turno la marca al cerrarse")
    func aLessonPlaysOnce() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.showing == .tutorialTip)

        gameState.dismissTutorialTip()
        #expect(gameState.showing != .tutorialTip)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.upgrades.defaultsKey),
                "cerrarla la deja dada: no vuelve nunca")

        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson != .upgrades, "la que sigue puede nacer, la dada no")
    }

    @Test("abrir el destino cumple la lección sin esperar el piso de skip")
    func openingTheDestinationCompletesTheLesson() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades)

        gameState.tutorialTipHandled(opening: .upgrades)
        #expect(gameState.showing != .tutorialTip, "hacer lo que señala es la mejor salida")
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.upgrades.defaultsKey))
    }

    @Test("la condición que muere esperando turno la retira sin quemarla")
    func aStaleTipRetiresWithoutBurningTheLesson() async {
        let gameState = await makeGameState()
        // La cola ocupada: la lección nace pero queda esperando turno.
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        #expect(gameState.showing == .towerNotice)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades)
        #expect(gameState.showing == .towerNotice, "el aviso sigue en pantalla; la lección espera")

        // La plata se va antes de que le toque: la lección ya no manda a nada.
        gameState.player?.run.coins = 0
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "la regla de oro vale hasta el último frame")
        #expect(!UserDefaults.standard.bool(forKey: GameState.TutorialLesson.upgrades.defaultsKey),
                "no se quema: nunca estuvo en pantalla")

        // Y cuando el momento vuelve, vuelve.
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades)
    }

    @Test("con una hoja tapando el tablero no nace nada")
    func noLessonUnderAnOpenSheet() async {
        let gameState = await makeGameState()
        gameState.uiCoversBoard = true
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "el coach señala controles que están DEBAJO de la hoja")

        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades, "al cerrarse, el próximo refresh la agarra")
    }

    @Test("el badge de logros: la señal nace con el cobrable y muere al cobrarlo")
    func claimableSignalTracksTheSets() async throws {
        let gameState = await makeGameState()
        let before = gameState.hasClaimableAchievements
        gameState.debugSeedAchievements()
        gameState.refreshProjections()
        #expect(gameState.hasClaimableAchievements, "tres logros conseguidos y sin cobrar: hay puntito")

        let player = try #require(gameState.player)
        for id in player.meta.unlockedAchievements.subtracting(player.meta.claimedAchievements) {
            gameState.claimAchievement(id: id)
        }
        #expect(!gameState.hasClaimableAchievements, "cobrado el último, el puntito muere")
        _ = before
    }
}
