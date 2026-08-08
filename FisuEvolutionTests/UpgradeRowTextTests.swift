import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los textos de la fila de personaje (pestaña Personajes).
///
/// **Decisión del dueño (2026-08-07)**: la fila dice el estado ACTUAL de la
/// mejora y nada más. Decía "Plata ×1 → ×2 para El Fisura" y eran tres datos
/// para una línea: el de ahora, el de después y un nombre que ya está escrito
/// arriba en la propia card. El "después" ya lo insinúa el botón con su precio.
@Suite("Textos de la fila de mejora", .serialized)
@MainActor
struct UpgradeRowTextTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "rows-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    private func baseRow(_ gameState: GameState) throws -> GameState.CharacterUpgradeRow {
        try #require(gameState.characterUpgradeRows.first)
    }

    @Test("la línea del multiplicador dice lo que rinde hoy, sin el próximo nivel")
    func multiplierLineShowsOnlyTheCurrentState() async throws {
        let gameState = await makeGameState()
        let row = try baseRow(gameState)

        let text = gameState.characterIncomeText(for: row)

        #expect(text.contains(row.multiplierText))
        #expect(!text.contains("→"), "la fila sigue mostrando el próximo nivel")
        // El nombre ya está en el encabezado de la card: repetirlo es ruido.
        #expect(!text.contains(row.displayName))
        #expect(!text.contains("upgrades.character"), "quedó la clave cruda en pantalla")
    }

    @Test("la línea del pasivo dice el rendimiento, sin repetir el nombre")
    func passiveLineDropsTheCharacterName() async throws {
        let gameState = await makeGameState()
        let row = try baseRow(gameState)

        #expect(!row.passiveEffectText.contains(row.displayName))
        #expect(!row.passiveEffectText.contains("upgrades.character"), "quedó la clave cruda en pantalla")
        #expect(row.passiveEffectText.contains("/s"), "perdió la unidad, que es lo que lo hace legible")
    }
}
