import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La migración corre en el arranque. Bajo XCTest el gate del núcleo sigue apagado (cada test
/// arma su escenario), pero la migración sí corre: es lo que hace al veterano. Las banderas
/// van al dominio propio de cada test (`isolatedForTest()`), no al del host.
@Suite("Las banderas del tutorial en el arranque", .serialized)
@MainActor
struct TutorialBootstrapTests {
    private func makeRepository() -> PlayerStateRepository {
        PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "boot-\(UUID().uuidString).json")
        )
    }

    private func makeGameState(repository: PlayerStateRepository? = nil) -> GameState {
        let gameState = GameState(repository: repository ?? makeRepository())
        gameState.flagDefaults = .isolatedForTest()
        return gameState
    }

    @Test("un veterano (save + la bandera de la v1) arranca con el núcleo hecho y el Tour pendiente")
    func veteranBoot() {
        let gameState = makeGameState()
        let defaults = gameState.flagDefaults
        defaults.set(true, forKey: TutorialFlags.legacyCompletedKey)
        gameState.applyTutorialMigration(hasSave: true)
        #expect(TutorialFlags.coreCompleted(in: defaults))
        #expect(TutorialFlags.tourPending(in: defaults))
        #expect(!GameState.TutorialLesson.veteranKnownLessons.isEmpty)
        for id in GameState.TutorialLesson.veteranKnownLessons {
            #expect(TutorialFlags.isLessonDone(id, in: defaults), "\(id): la v1 ya la enseñaba")
        }
    }

    @Test("una instalación nueva no es veterana: sin núcleo, sin Tour y con la versión puesta")
    func freshBoot() {
        let gameState = makeGameState()
        let defaults = gameState.flagDefaults
        gameState.applyTutorialMigration(hasSave: false)
        #expect(!TutorialFlags.coreCompleted(in: defaults))
        #expect(!TutorialFlags.tourPending(in: defaults))
        #expect(defaults.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion)
    }

    @Test("la migración corre una sola vez")
    func migratesOnce() {
        let gameState = makeGameState()
        let defaults = gameState.flagDefaults
        defaults.set(true, forKey: TutorialFlags.legacyCompletedKey)
        gameState.applyTutorialMigration(hasSave: true)
        TutorialFlags.setTourPending(false, in: defaults)
        gameState.applyTutorialMigration(hasSave: true)
        #expect(!TutorialFlags.tourPending(in: defaults), "la segunda vez no vuelve a marcar el Tour")
    }

    @Test("bootstrap con save previo y la bandera de la v1: veterano")
    func bootstrapVeteran() async {
        let repository = makeRepository()
        var existing = PlayerState.newGame(
            startTypeId: "homeless", startFloorId: "alley", offlineEfficiencyBase: 0.5,
            critChanceBase: 0, now: 1_700_000_000
        )
        existing.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
        await repository.save(existing)
        let gameState = makeGameState(repository: repository)
        gameState.flagDefaults.set(true, forKey: TutorialFlags.legacyCompletedKey)

        await gameState.bootstrap()

        #expect(TutorialFlags.coreCompleted(in: gameState.flagDefaults))
        #expect(TutorialFlags.tourPending(in: gameState.flagDefaults))
    }

    @Test("bootstrap sin save aunque quede la bandera de la v1: instalación nueva, no veterano")
    func bootstrapFreshInstall() async {
        let gameState = makeGameState()
        gameState.flagDefaults.set(true, forKey: TutorialFlags.legacyCompletedKey)

        await gameState.bootstrap()

        #expect(!TutorialFlags.coreCompleted(in: gameState.flagDefaults))
        #expect(!TutorialFlags.tourPending(in: gameState.flagDefaults))
        #expect(gameState.flagDefaults.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion)
    }

    @Test("qué mecánicas conocía la v1: el conjunto es explícito, lo nuevo no entra")
    func veteranKnownLessonsAreExplicit() {
        #expect(GameState.TutorialLesson.veteranKnownLessons == [
            "upgrades", "elevator", "skins", "achievements", "oroUpgrades", "gifts", "store", "prestige",
            "passive", "orgChart", "floorSwipe", "floorFull",
        ])
        #expect(GameState.TutorialLesson.quickHire.introducedIn == .v2)
        #expect(GameState.TutorialLesson.visitor.introducedIn == .v2)
        #expect(GameState.TutorialLesson.upgrades.introducedIn == .v1)
    }
}
