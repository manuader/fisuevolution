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

    /// El botón adelantado (dueño, 2026-08-28: "al llegar a lujo"): desde el
    /// piso configurado en `oro.prestigeTeaserFloorId` el botón EXISTE sin ORO
    /// por cobrar, y la preview sabe contar el camino al próximo.
    @Test("el teaser se enciende al llegar al piso configurado, sin ORO todavía")
    func teaserLightsUpAtTheConfiguredFloor() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let floorId = try #require(content.economy.oro.prestigeTeaserFloorId)
        let ordinal = try #require(
            (0..<content.floorTable.count).first { content.floorTable[$0].id == floorId }
        )

        gameState.refreshProjections()
        #expect(!gameState.prestigeTeaser, "en el callejón el botón todavía no existe")
        #expect(!gameState.prestigeAvailable)

        var player = try #require(gameState.player)
        player.run.unlockedFloors = (0...ordinal).map { content.floorTable[$0].id }
        gameState.player = player
        gameState.refreshProjections()

        #expect(gameState.prestigeTeaser, "llegar al piso del teaser enciende el botón")
        #expect(!gameState.prestigeAvailable, "sin ORO por cobrar sigue sin poder reencarnar")
        let preview = gameState.prestigePreview
        #expect(!preview.isWorthIt)
        #expect(preview.coinsToNextOro > 0, "el camino al primer ORO tiene que ser medible")
        #expect(preview.nextOroProgress >= 0 && preview.nextOroProgress < 1)
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

    private func walledGame(lastWall: Int, frontier: Int, career: String? = nil) async throws -> GameState {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.economy = StandardEconomy(config: try content.economy.tuned(EconomyKnobs(requiresLastRunWall: true)))
        gameState.giveEarningsForPrestigeTesting(oro: 9)
        gameState.player?.meta.lastRunMaxTier = lastWall
        _ = gameState.player?.run.raiseFrontier(to: frontier)
        gameState.player?.run.chosenCareerPath = career.map { MergeRules.careerPath(fromOptionId: $0) }
        // `refreshProjections` y no sólo la vista previa: `prestigeAvailable`
        // también se republica ahí, y el fixture de ORO lo dejó calculado antes
        // de la pared.
        gameState.refreshProjections()
        return gameState
    }

    @Test("con el piso móvil, la vista previa nombra la meta y confirmar no hace nada")
    func theMovingWallNamesTheGoal() async throws {
        let gameState = try await walledGame(lastWall: 13, frontier: 9)
        let content = try #require(gameState.content)
        let preview = gameState.prestigePreview
        #expect(preview.isWorthIt)
        #expect(preview.wallGoalTier == 13)
        #expect(preview.wallGoalName == content.tiers.type(id: "director")?.localizedName)
        #expect(!gameState.prestigeAvailable)
        let level = gameState.player?.meta.prestigeLevel
        gameState.confirmPrestige()
        #expect(gameState.player?.meta.prestigeLevel == level)
    }

    @Test("con cuatro carreras posibles y ninguna elegida, la meta es el número de tier")
    func anAmbiguousWallNamesTheTier() async throws {
        let preview = try await walledGame(lastWall: 11, frontier: 9).prestigePreview
        #expect(preview.wallGoalTier == 11)
        #expect(preview.wallGoalName == nil)
        #expect(preview.wallGoalText?.contains("11") == true)
        #expect(preview.wallGoalText?.contains("prestige.wall") == false, "quedó la clave cruda")
        #expect(preview.wallGoalShortText?.contains("prestige.wall") == false, "quedó la clave cruda")
    }

    @Test("con la carrera elegida, la meta es el personaje de esa rama")
    func theChosenCareerNamesTheBranch() async throws {
        let gameState = try await walledGame(lastWall: 12, frontier: 11, career: "junior_lawyer")
        let content = try #require(gameState.content)
        #expect(gameState.prestigePreview.wallGoalName == content.tiers.type(id: "senior_lawyer")?.localizedName)
    }

    @Test("sin la perilla no hay meta: es la v1")
    func withoutTheKnobThereIsNoWall() async throws {
        let gameState = await makeGameState()
        gameState.giveEarningsForPrestigeTesting(oro: 9)
        gameState.player?.meta.lastRunMaxTier = 13
        gameState.refreshProjections()
        #expect(!gameState.prestigePreview.isBlockedByWall)
        #expect(gameState.prestigeAvailable)
    }
}
