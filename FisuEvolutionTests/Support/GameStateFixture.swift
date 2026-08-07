import Foundation
@testable import FisuEvolution

/// Un `GameState` arrancado contra el contenido real bundleado, con persistencia
/// en memoria y snapshot descartable.
///
/// Vive acá y no `private` en una suite porque varias suites lo necesitan y dos
/// copias divergen: la que se olvida de `bootstrap()` o la que comparte el
/// snapshot con otra corrida son bugs de test que cuestan una tarde.
@MainActor
func makeGameState() async -> GameState {
    let repository = PlayerStateRepository(
        persistence: PersistenceController(inMemory: true),
        snapshotURL: FileManager.default.temporaryDirectory.appending(path: "fixture-\(UUID().uuidString).json")
    )
    let gameState = GameState(repository: repository)
    await gameState.bootstrap()
    return gameState
}
