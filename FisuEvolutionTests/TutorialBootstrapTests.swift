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

    @Test("lo nuevo de la 2.0 no se da por visto: se le enseña al veterano la primera vez")
    func newMechanicsAreNotKnown() {
        let known = GameState.TutorialLesson.veteranKnownLessons
        for lesson in GameState.TutorialLesson.allCases where lesson.introducedIn == .v2 {
            #expect(!known.contains(lesson.rawValue), "\(lesson)")
        }
    }
}
