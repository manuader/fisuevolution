import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La migración corre en el arranque. Bajo XCTest el gate del núcleo sigue apagado (cada test
/// arma su escenario), pero la migración sí corre: es lo que hace al veterano.
@Suite("Las banderas del tutorial en el arranque", .serialized)
@MainActor
struct TutorialBootstrapTests {
    private let keys = [TutorialFlags.versionKey, TutorialFlags.completedKey,
                        TutorialFlags.tourPendingKey, TutorialFlags.legacyCompletedKey]

    private func withSavedDefaults(_ body: () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let saved = keys.map { defaults.object(forKey: $0) }
        let savedLessons = GameState.TutorialLesson.allCases.map { defaults.object(forKey: $0.defaultsKey) }
        defer {
            for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
            for (lesson, value) in zip(GameState.TutorialLesson.allCases, savedLessons) {
                defaults.set(value, forKey: lesson.defaultsKey)
            }
        }
        for key in keys { defaults.removeObject(forKey: key) }
        for lesson in GameState.TutorialLesson.allCases { defaults.removeObject(forKey: lesson.defaultsKey) }
        try await body()
    }

    private func makeGameState() -> GameState {
        GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "boot-\(UUID().uuidString).json")
        ))
    }

    @Test("un veterano (save + la bandera de la v1) arranca con el núcleo hecho y el Tour pendiente")
    func veteranBoot() async {
        await withSavedDefaults {
            UserDefaults.standard.set(true, forKey: TutorialFlags.legacyCompletedKey)
            makeGameState().applyTutorialMigration(hasSave: true)
            #expect(TutorialFlags.coreCompleted())
            #expect(TutorialFlags.tourPending())
            #expect(!GameState.TutorialLesson.veteranKnownLessons.isEmpty)
            for id in GameState.TutorialLesson.veteranKnownLessons {
                #expect(TutorialFlags.isLessonDone(id), "\(id): la v1 ya la enseñaba")
            }
        }
    }

    @Test("una instalación nueva no es veterana: sin núcleo, sin Tour y con la versión puesta")
    func freshBoot() async {
        await withSavedDefaults {
            makeGameState().applyTutorialMigration(hasSave: false)
            #expect(!TutorialFlags.coreCompleted())
            #expect(!TutorialFlags.tourPending())
            #expect(UserDefaults.standard.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion)
        }
    }

    @Test("la migración corre una sola vez")
    func migratesOnce() async {
        await withSavedDefaults {
            let gameState = makeGameState()
            UserDefaults.standard.set(true, forKey: TutorialFlags.legacyCompletedKey)
            gameState.applyTutorialMigration(hasSave: true)
            TutorialFlags.setTourPending(false)
            gameState.applyTutorialMigration(hasSave: true)
            #expect(!TutorialFlags.tourPending(), "la segunda vez no vuelve a marcar el Tour")
        }
    }

    private func makeRepository() -> PlayerStateRepository {
        PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "boot-\(UUID().uuidString).json")
        )
    }

    @Test("bootstrap con save previo y la bandera de la v1: veterano")
    func bootstrapVeteran() async {
        await withSavedDefaults {
            let repository = makeRepository()
            var existing = PlayerState.newGame(
                startTypeId: "homeless", startFloorId: "alley", offlineEfficiencyBase: 0.5,
                critChanceBase: 0, now: 1_700_000_000
            )
            existing.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
            await repository.save(existing)
            UserDefaults.standard.set(true, forKey: TutorialFlags.legacyCompletedKey)

            await GameState(repository: repository).bootstrap()

            #expect(TutorialFlags.coreCompleted())
            #expect(TutorialFlags.tourPending())
        }
    }

    @Test("bootstrap sin save aunque quede la bandera de la v1: instalación nueva, no veterano")
    func bootstrapFreshInstall() async {
        await withSavedDefaults {
            UserDefaults.standard.set(true, forKey: TutorialFlags.legacyCompletedKey)

            await GameState(repository: makeRepository()).bootstrap()

            #expect(!TutorialFlags.coreCompleted())
            #expect(!TutorialFlags.tourPending())
            #expect(UserDefaults.standard.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion)
        }
    }

    @Test("qué lecciones enseñaba la v1: el conjunto es explícito, lo nuevo no entra")
    func veteranKnownLessonsAreExplicit() {
        #expect(GameState.TutorialLesson.veteranKnownLessons == [
            "upgrades", "elevator", "skins", "achievements", "oroUpgrades", "gifts", "store", "prestige"
        ])
        #expect(GameState.TutorialLesson.quickHire.introducedIn == .v2)
        #expect(GameState.TutorialLesson.visitor.introducedIn == .v2)
        #expect(GameState.TutorialLesson.upgrades.introducedIn == .v1)
    }
}
