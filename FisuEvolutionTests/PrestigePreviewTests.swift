import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// RF-16: el popup de reencarnación promete un multiplicador. Estos tests pinean
/// que la promesa se cumple: `prestigePreview` sale de las MISMAS funciones que
/// aplica `PrestigeCalculator`, no de una cuenta paralela.
@Suite("Prestigio: el antes y el después")
@MainActor
struct PrestigePreviewTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "prestige-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    @Test("el multiplicador que promete el popup es el que queda después de confirmar")
    func previewMatchesReality() async throws {
        let gameState = await makeGameState()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        let preview = gameState.prestigePreview
        gameState.confirmPrestige()
        let real = try #require(gameState.player?.meta.globalMultiplier)
        #expect(abs(real - preview.multiplierAfter) < 0.001,
                "si el popup miente, el jugador aprende a no creerle")
    }

    @Test("el ORO prometido es el que se acredita")
    func previewOroMatchesReality() async throws {
        let gameState = await makeGameState()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        let preview = gameState.prestigePreview
        #expect(preview.oroGained > 0, "con lifetime para 3 ORO hay ORO que ganar")
        let oroBefore = try #require(gameState.player?.meta.oro)
        gameState.confirmPrestige()
        let oroAfter = try #require(gameState.player?.meta.oro)
        #expect(oroAfter - oroBefore == preview.oroGained)
    }

    /// El "antes" tiene que ser el multiplicador que el jugador tiene ahora, no
    /// una aproximación: si arranca desfasado, la flecha del popup miente aunque
    /// el "después" sea exacto.
    @Test("el antes es el multiplicador vigente y el después nunca es menor")
    func beforeIsTheLiveMultiplier() async throws {
        let gameState = await makeGameState()
        let cached = try #require(gameState.player?.meta.globalMultiplier)
        #expect(abs(gameState.prestigePreview.multiplierBefore - cached) < 0.000_1)

        gameState.giveEarningsForPrestigeTesting(oro: 3)
        let preview = gameState.prestigePreview
        #expect(preview.multiplierAfter >= preview.multiplierBefore)
        gameState.confirmPrestige()
        // Recién reencarnado no queda nada por cobrar: el "después" del popup ya
        // es el "antes" de la próxima vida.
        let settled = gameState.prestigePreview
        #expect(settled.oroGained == 0)
        #expect(abs(settled.multiplierBefore - preview.multiplierAfter) < 0.000_1)
        #expect(abs(settled.multiplierAfter - preview.multiplierAfter) < 0.000_1)
    }

    /// Lo que se borra también sale en números, y son los de la run vigente.
    @Test("la vista previa cuenta lo que muere con la run")
    func previewCountsWhatDies() async throws {
        let gameState = await makeGameState()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.debugSetMaxTier(5)
        gameState.debugGrantPair()

        let player = try #require(gameState.player)
        let preview = gameState.prestigePreview
        #expect(preview.unitsLost == player.run.totalUnits)
        #expect(preview.unitsLost > 1, "el helper deja el par además de la unidad inicial")
        #expect(preview.coinsLost == player.run.coins)

        gameState.confirmPrestige()
        // `RunState.fresh` arranca con UNA unidad del tipo base: la run vieja
        // murió entera, no quedó nada de lo que el popup contó.
        #expect(gameState.player?.run.totalUnits == 1)
        #expect(gameState.player?.run.coins == 0)
    }

    /// La proyección del HUD se publica por `refreshProjections`, igual que el
    /// resto: la vista nunca lee `PlayerState`.
    @Test("el indicador del HUD se refresca por proyección, no por PlayerState")
    func hudProjectionFollowsRefresh() async throws {
        let gameState = await makeGameState()
        #expect(gameState.prestigePreview.oroGained == 0)

        gameState.giveEarningsForPrestigeTesting(oro: 3)
        #expect(gameState.prestigePreview.oroGained > 0,
                "giveEarningsForPrestigeTesting refresca proyecciones")
        #expect(gameState.prestigePreview == gameState.prestigePreviewNow,
                "la proyección publicada no puede quedar atrasada respecto del cálculo")
    }
}
