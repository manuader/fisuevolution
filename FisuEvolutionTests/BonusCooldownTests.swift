import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// RF-11: cada recompensa por video tiene su propio cooldown de 4 horas y los
/// cuatro corren en paralelo. El reloj se inyecta porque la alternativa es un test
/// que tarda cuatro horas.
@Suite("Cooldown de los videos")
@MainActor
struct BonusCooldownTests {
    private func makeRepository() -> PlayerStateRepository {
        PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "bonus-\(UUID().uuidString).json")
        )
    }

    private func makeGameState(repository: PlayerStateRepository? = nil) async -> GameState {
        let gameState = GameState(repository: repository ?? makeRepository())
        await gameState.bootstrap()
        return gameState
    }

    @Test("mirar un video bloquea esa recompensa 4 horas")
    func rewardGoesOnCooldown() async {
        let gameState = await makeGameState()
        let id = "double_earnings"

        #expect(gameState.rewardCooldownRemaining(id: id, now: 1000) == 0)
        gameState.applyRewardedReward(rewardId: id, now: 1000)

        #expect(gameState.rewardCooldownRemaining(id: id, now: 1000) == 4 * 3600)
        #expect(gameState.rewardCooldownRemaining(id: id, now: 1000 + 4 * 3600) == 0)
    }

    @Test("los cuatro cooldowns corren en paralelo")
    func cooldownsAreIndependent() async {
        let gameState = await makeGameState()
        gameState.applyRewardedReward(rewardId: "double_earnings", now: 1000)

        #expect(gameState.rewardCooldownRemaining(id: "double_earnings", now: 1000) > 0)
        for other in ["temp_multiplier", "accelerate_evolution", "spawn_rare"] {
            #expect(gameState.rewardCooldownRemaining(id: other, now: 1000) == 0, "\(other) no debería estar bloqueado")
        }
    }

    @Test("un segundo video durante el cooldown no paga de nuevo")
    func secondWatchDuringCooldownIsRejected() async {
        let gameState = await makeGameState()
        let id = "double_earnings"
        gameState.applyRewardedReward(rewardId: id, now: 1000)
        let modifiers = gameState.player?.run.activeModifiers.count ?? 0

        gameState.applyRewardedReward(rewardId: id, now: 1000 + 60)

        #expect(gameState.player?.run.activeModifiers.count == modifiers, "el cooldown tiene que cortar el efecto, no sólo el botón")
        // Y la marca no se corre hacia adelante: el cooldown termina cuando decía.
        #expect(gameState.rewardCooldownRemaining(id: id, now: 1000 + 4 * 3600) == 0)
    }

    /// El cooldown vive en `meta`, al lado de `boostActivations`, así que sobrevive
    /// a cerrar la app y a reencarnar. Si viviera en `run`, reencarnar sería la
    /// forma de mirar los cuatro videos otra vez.
    @Test("cerrar y abrir la app no resetea el cooldown")
    func cooldownSurvivesRelaunch() async {
        let repository = makeRepository()
        let first = await makeGameState(repository: repository)
        first.applyRewardedReward(rewardId: "spawn_rare", now: 1000)
        await first.persistNow()

        let second = await makeGameState(repository: repository)
        #expect(second.rewardCooldownRemaining(id: "spawn_rare", now: 1000) == 4 * 3600)
    }

    @Test("reencarnar no resetea el cooldown")
    func cooldownSurvivesReincarnation() async throws {
        let gameState = await makeGameState()
        gameState.applyRewardedReward(rewardId: "spawn_rare", now: 1000)

        var player = try #require(gameState.player)
        player.run = .fresh(startTypeId: "homeless", startFloorId: "alley")
        gameState.player = player

        #expect(gameState.rewardCooldownRemaining(id: "spawn_rare", now: 1000) == 4 * 3600)
    }
}
