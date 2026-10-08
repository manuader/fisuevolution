import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Cambios del tablero: los productores")
@MainActor
struct BoardChangeProducersTests {
    @Test("la Startup ya no evoluciona en el acto: deja el cambio planeado")
    func startupPlansInsteadOfMutating() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        gameState.debugSetMaxTier(5)
        var state = try #require(gameState.player)
        let units = state.run.units
        let lastFired = Dictionary(
            uniqueKeysWithValues: content.events.events.filter { $0.id != "startup_comprada" }.map { ($0.id, 999.0) }
        )
        let roll = try #require(EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: 1000, lastFired: lastFired, isApplicable: { _ in true }, rng: &gameState.rng
        ))
        #expect(state.run.units == units)
        #expect(roll.boardIntent == .evolveBestUnit)
        gameState.handleEventRoll(roll, now: 1000)
        #expect(gameState.pendingBoardChanges.first?.origin == .eventStartup)
        #expect(gameState.player?.run.units == units)
    }

    @Test("la Startup evoluciona sólo a quien está 2 tiers o más por debajo de la frontera")
    func startupNeverOpensATier() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let event = try #require(content.events.events.first { $0.id == "startup_comprada" })
        gameState.debugSetMaxTier(5)
        let change = try #require(gameState.startupEvolution(for: event))
        let result = try #require(change.resultTypeId.flatMap { content.tiers.type(id: $0) })
        #expect(result.tier <= 5 - 1, "a lo sumo frontera − 1: nunca revela un tier")
    }

    @Test("sin nadie que pueda evolucionar, la Startup paga plata y lo dice")
    func startupPaysCashWhenNobodyFits() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let event = try #require(content.events.events.first { $0.id == "startup_comprada" })
        gameState.debugSetMaxTier(2)          // el Fisura (tier 1) no está 2 tiers abajo
        #expect(gameState.startupEvolution(for: event) == nil)
        #expect(gameState.eventIsApplicable(event))
        let before = try #require(gameState.player?.run.coins)
        let lifetimeBefore = try #require(gameState.player?.meta.lifetimeEarnings)
        let expected = gameState.startupFallbackCoins(for: event)
        let roll = EventManager.Roll(event: event, active: EventManager.ActiveEvent(
            id: event.id, flavorTextKey: event.flavorTextKey, isBuff: true, endsAt: 1006, escapableByVideo: false
        ), boardIntent: .evolveBestUnit)
        gameState.handleEventRoll(roll, now: 1000)
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(expected > 0)
        #expect(try #require(gameState.player?.run.coins) == before + expected)
        #expect(try #require(gameState.player?.meta.lifetimeEarnings) == lifetimeBefore + expected)
        #expect(gameState.activeEvent?.flavorTextKey == event.fallback?.flavorTextKey)
    }

    @Test("con alguien a quien ascender, la Startup no paga plata")
    func startupDoesNotPayWhenItEvolves() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let event = try #require(content.events.events.first { $0.id == "startup_comprada" })
        gameState.debugSetMaxTier(5)
        let before = try #require(gameState.player?.run.coins)
        let roll = EventManager.Roll(event: event, active: EventManager.ActiveEvent(
            id: event.id, flavorTextKey: event.flavorTextKey, isBuff: true, endsAt: 1006, escapableByVideo: false
        ), boardIntent: .evolveBestUnit)
        gameState.handleEventRoll(roll, now: 1000)
        #expect(gameState.pendingBoardChanges.count == 1)
        #expect(try #require(gameState.player?.run.coins) == before)
        #expect(gameState.activeEvent?.flavorTextKey == event.flavorTextKey)
    }

    @Test("el Blanqueo llega por el embudo")
    func blanqueoPlansAnArrival() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.debugUnlockFloors(throughTier: 9)
        let event = try #require(content.events.events.first { $0.id == "blanqueo" })
        let player = try #require(gameState.player)
        let type = try #require(EventManager.blanqueoType(for: event, state: player, tiers: content.tiers))
        let roll = EventManager.Roll(event: event, active: nil, boardIntent: .grantUnit(typeId: type.id))
        gameState.handleEventRoll(roll, now: 1000)
        #expect(gameState.pendingBoardChanges.first?.origin == .eventBlanqueo)
    }

    @Test("el video de evolución gratis planea su merge y no toca el tablero")
    func freeMergeVideoPlans() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        let units = try #require(gameState.player?.run.units)
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        #expect(gameState.player?.run.units == units)
        #expect(gameState.pendingBoardChanges.first?.origin == .rewardedInstantMerge)
    }

    @Test("el personaje de regalo llega por el embudo")
    func rareUnitVideoPlans() async throws {
        let gameState = await makeGameState()
        gameState.applyRewardedReward(rewardId: "spawn_rare")
        #expect(gameState.pendingBoardChanges.first?.origin == .rewardedRareUnit)
    }

    @Test("elegir carrera acredita ya y deja el merge para su turno, con revelación")
    func careerDefersTheMerge() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let options = try #require(content.tiers.type(id: "junior")?.choiceOptions)
            .compactMap { content.tiers.type(id: $0) }
        gameState.player?.run.units = ["administrativo": 2]
        gameState.reconcileTower()
        let floor = content.floorTable.ordinal(forTier: 10)
        gameState.visibleFloorOrdinal = floor
        let pair = gameState.visiblePlacements.map(\.slot).sorted()
        gameState.careerPrompt = GameState.CareerPrompt(
            options: options, floorOrdinal: floor, sourceCell: pair[0], targetCell: pair[1]
        )
        gameState.player?.run.raiseFrontier(to: 10)
        gameState.markRevealed(tier: 10)
        gameState.chooseCareer(optionId: "junior_programmer")
        #expect(gameState.careerPrompt == nil)
        #expect(gameState.player?.run.units["administrativo"] == 2)
        let change = try #require(gameState.beginNextBoardChange())
        let resolution = gameState.confirmBoardChange(id: change.id)
        guard case .merged(_, let evolvedTo, _, _, _)? = resolution else {
            Issue.record("la carrera no se fusionó")
            return
        }
        #expect(evolvedTo?.id == "junior_programmer")
    }
}
