import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El diario ×2 y la carrera ×2 (PLAN-v2 E7, unidad `daily`).
@Suite("El diario y la carrera ×2 por video", .serialized)
@MainActor
struct AdPlacementRewardsTests {
    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "adplace-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    private func coinsClaim(_ gameState: GameState, coins: Double = 500) throws -> DailyRewardManager.Claim {
        let day = try #require(gameState.content?.dailyRewards.days.first)
        return DailyRewardManager.Claim(day: day, coinsGranted: coins, specialGranted: nil, chestGranted: false)
    }

    @Test("el diario de plata se duplica una vez por día")
    func dailyDoublesOncePerDay() async throws {
        let gameState = await makeGameState()
        let claim = try coinsClaim(gameState)
        let now = Date()
        let before = try #require(gameState.player?.run.coins)
        #expect(gameState.canDoubleDailyReward(claim, now: now))
        gameState.doubleDailyReward(claim, now: now)
        #expect(try #require(gameState.player?.run.coins) == before + 500)
        #expect(!gameState.canDoubleDailyReward(claim, now: now))
        gameState.doubleDailyReward(claim, now: now)
        #expect(try #require(gameState.player?.run.coins) == before + 500, "una vez")
        #expect(gameState.canDoubleDailyReward(claim, now: now.addingTimeInterval(86_400)), "mañana es otro diario")
    }

    @Test("el duplicado suma lo mismo que ya se acreditó, ×3 de la tienda incluido")
    func doublesTheAmountShown() async throws {
        let gameState = await makeGameState()
        let shown = try coinsClaim(gameState, coins: 1_500)
        let before = try #require(gameState.player?.run.coins)
        gameState.doubleDailyReward(shown)
        #expect(try #require(gameState.player?.run.coins) == before + 1_500)
    }

    @Test("el cofre o el special del día 7 no se duplican")
    func onlyCoinsDouble() async throws {
        let gameState = await makeGameState()
        let day = try #require(gameState.content?.dailyRewards.days.last)
        let chest = DailyRewardManager.Claim(day: day, coinsGranted: 0, specialGranted: nil, chestGranted: true)
        #expect(!gameState.canDoubleDailyReward(chest))
    }

    @Test("carrera ×2: elegir con video paga el premio de una vez dos veces")
    func careerTimesTwo() async throws {
        let once = await makeGameState()
        once.debugPresentCareerChoice()
        let before = try #require(once.player?.run.coins)
        once.chooseCareer(optionId: "junior_lawyer")
        let lump = try #require(once.player?.run.coins) - before

        let twice = await makeGameState()
        twice.debugPresentCareerChoice()
        let start = try #require(twice.player?.run.coins)
        twice.chooseCareerWithVideo(optionId: "junior_lawyer")
        let paid = try #require(twice.player?.run.coins) - start

        #expect(lump > 0)
        #expect(abs(paid - 2 * lump) <= max(1, lump) * 0.0001)
        #expect(twice.careerPrompt == nil, "se eligió")
    }

    @Test("sólo las carreras con premio de una vez ofrecen el ×2")
    func onlyLumpCareersOffer() async {
        let gameState = await makeGameState()
        #expect(gameState.careerLumpMinutes(optionId: "junior_lawyer") != nil)
        #expect(gameState.careerLumpMinutes(optionId: "junior_doctor") != nil)
        #expect(gameState.careerLumpMinutes(optionId: "junior_programmer") == nil)
    }
}
