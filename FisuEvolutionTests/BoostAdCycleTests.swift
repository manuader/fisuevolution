import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// C32: el video de un boost en cooldown se usa una vez por ciclo, deja el
/// cooldown completo corriendo, y el mismo boost nunca se apila consigo mismo.
@Suite("Boost por video: una vez por ciclo")
@MainActor
struct BoostAdCycleTests {
    private let turbo = "turbo"

    private func makeRepository() -> PlayerStateRepository {
        PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "boost-ad-\(UUID().uuidString).json")
        )
    }

    private func makeGameState(repository: PlayerStateRepository? = nil) async throws -> GameState {
        let gameState = GameState(repository: repository ?? makeRepository())
        await gameState.bootstrap()
        let content = try #require(gameState.content)
        let boost = try #require(content.boosts.boosts.first { $0.id == turbo })
        var player = try #require(gameState.player)
        player.meta.stats.maxFloorOrdinalEver = try #require(content.floorTable.ordinal(of: boost.unlockFloorId))
        gameState.player = player
        return gameState
    }

    private func boost(_ gameState: GameState) throws -> BoostsConfig.Boost {
        try #require(gameState.content?.boosts.boosts.first { $0.id == turbo })
    }

    /// El Turbo gratis, hace `elapsed` segundos: un cooldown ya en curso.
    private func activatedFree(_ gameState: GameState, elapsed: TimeInterval) throws -> TimeInterval {
        _ = gameState.activateBoost(id: turbo)
        var player = try #require(gameState.player)
        let start = try #require(player.meta.boostActivations[turbo]) - elapsed
        player.meta.boostActivations[turbo] = start
        gameState.player = player
        return start + elapsed
    }

    private func incomeFactor(_ gameState: GameState, now: TimeInterval) -> Double {
        ModifierMath.factor(gameState.player?.run.activeModifiers ?? [], effect: .incomeMultiplier, now: now)
    }

    @Test("después del video corre el cooldown completo y la tarjeta ya no ofrece video")
    func videoLeavesTheFullCooldown() async throws {
        let gameState = try await makeGameState()
        let boost = try boost(gameState)
        let now = try activatedFree(gameState, elapsed: 3600)
        #expect(gameState.boostRows.first { $0.id == turbo }?.offersAd == true, "en cooldown y sin video usado, se ofrece")

        let watched = now + 10
        gameState.activateBoostFromAd(id: turbo, now: watched)

        let player = try #require(gameState.player)
        #expect(BoostManager.cooldownRemaining(of: boost, state: player, now: watched) == boost.cooldownSeconds)
        #expect(incomeFactor(gameState, now: watched) == boost.magnitude, "el video sí activó el boost")
        let row = try #require(gameState.boostRows.first { $0.id == turbo })
        #expect(!row.offersAd)
        #expect(row.cooldownRemaining > boost.cooldownSeconds - 3600, "el reloj no volvió al cooldown viejo")
    }

    @Test("el segundo video del mismo ciclo se rechaza; la próxima activación gratis lo reabre")
    func secondVideoIsRejectedUntilTheNextFreeActivation() async throws {
        let gameState = try await makeGameState()
        let boost = try boost(gameState)
        let now = try activatedFree(gameState, elapsed: 3600)
        gameState.activateBoostFromAd(id: turbo, now: now)
        let afterFirst = try #require(gameState.player)

        gameState.activateBoostFromAd(id: turbo, now: now + 60)
        #expect(gameState.player?.meta.boostActivations[turbo] == afterFirst.meta.boostActivations[turbo])
        #expect(gameState.player?.meta.stats.boostsActivatedEver == afterFirst.meta.stats.boostsActivatedEver)

        // El cooldown pasa entero y se activa gratis: ciclo nuevo, video nuevo.
        var player = try #require(gameState.player)
        player.meta.boostActivations[turbo] = now - boost.cooldownSeconds - 1
        gameState.player = player
        _ = gameState.activateBoost(id: turbo)
        #expect(gameState.boostRows.first { $0.id == turbo }?.offersAd == true)
    }

    @Test("doble toque paga una vez")
    func doubleTapPaysOnce() async throws {
        let gameState = try await makeGameState()
        let boost = try boost(gameState)
        let now = try activatedFree(gameState, elapsed: 600)
        let before = try #require(gameState.player?.meta.stats.boostsActivatedEver)

        gameState.activateBoostFromAd(id: turbo, now: now)
        gameState.activateBoostFromAd(id: turbo, now: now)

        #expect(gameState.player?.meta.stats.boostsActivatedEver == before + 1)
        #expect(incomeFactor(gameState, now: now) == boost.magnitude)
        let turboModifiers = gameState.player?.run.activeModifiers.filter { $0.sourceKey == "boost.\(turbo)" }
        #expect(turboModifiers?.count == 1)
        #expect(turboModifiers?.first?.expiresAt == now + boost.durationSeconds, "el video renovó la duración")
    }

    @Test("tres activaciones no multiplican el boost: el factor nunca pasa su magnitud")
    func repeatedActivationsDoNotMultiply() async throws {
        let gameState = try await makeGameState()
        let boost = try boost(gameState)
        let now = Date().timeIntervalSince1970
        for _ in 0..<3 {
            var player = try #require(gameState.player)
            player.meta.boostActivations[turbo] = nil
            gameState.player = player
            _ = gameState.activateBoost(id: turbo)
        }
        #expect(gameState.player?.meta.stats.boostsActivatedEver == 3, "las tres activaciones ocurrieron")
        #expect(incomeFactor(gameState, now: now + 1) == boost.magnitude)

        // Y el video encima del gratis tampoco multiplica.
        gameState.activateBoostFromAd(id: turbo, now: now + 2)
        #expect(incomeFactor(gameState, now: now + 3) == boost.magnitude)
    }

    @Test("matar la app después del video no regala otro ciclo")
    func relaunchKeepsTheVideoSpent() async throws {
        let repository = makeRepository()
        let first = try await makeGameState(repository: repository)
        let boost = try boost(first)
        let now = try activatedFree(first, elapsed: 3600)
        first.activateBoostFromAd(id: turbo, now: now)
        await first.persistNow(includingCloud: false)

        let second = try await makeGameState(repository: repository)
        let player = try #require(second.player)
        #expect(BoostManager.cooldownRemaining(of: boost, state: player, now: now) == boost.cooldownSeconds)
        #expect(!BoostManager.canOfferAd(of: boost, state: player, now: now))
        second.activateBoostFromAd(id: turbo, now: now + 5)
        #expect(second.player?.meta.boostActivations[turbo] == now, "el relanzamiento no habilitó otro video")
    }

    @Test("un save sin la marca del video sigue ofreciéndolo")
    func saveWithoutTheMarkStillOffers() async throws {
        let gameState = try await makeGameState()
        let boost = try boost(gameState)
        let now = try activatedFree(gameState, elapsed: 60)
        var player = try #require(gameState.player)
        player.meta.rewardedActivations = [:]
        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(PlayerState.self, from: data)
        #expect(BoostManager.canOfferAd(of: boost, state: decoded, now: now))
    }
}
