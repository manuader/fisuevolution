import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Eventos v2 en la partida")
@MainActor
struct EventsRuntimeTests {
    /// Partida con la torre abierta hasta `tier` y el Fisura produciendo.
    private func game(throughTier tier: Int = 12) async throws -> GameState {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.debugUnlockFloors(throughTier: tier)
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        return gameState
    }

    private func event(_ id: String, in gameState: GameState) throws -> EventCatalog.Event {
        try #require(gameState.content?.events.event(id: id))
    }

    /// Lo que salió del sorteo, leído del cooldown y no del banner: E4b cambia
    /// cómo se anuncia (un presentador), no cómo se sortea.
    private func fired(_ gameState: GameState) -> Set<String> {
        Set(gameState.player?.meta.engagement.events.lastFiredAt.keys.map { $0 } ?? [])
    }

    @Test("bajo XCTest el motor no corre solo")
    func autorunIsOffUnderTests() async {
        let gameState = await makeGameState()
        #expect(!gameState.engagementAutorun)
        gameState.player?.meta.engagement.events.secondsUntilNext = 0
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.player?.meta.engagement.events.clock == 0)
        #expect(fired(gameState).isEmpty)
    }

    @Test("cuando vence, sale uno, anota su cooldown y programa el siguiente")
    func dueEventStartsAndReschedules() async throws {
        let gameState = try await game()
        gameState.player?.meta.engagement.events.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        let id = try #require(fired(gameState).first)
        let content = try #require(gameState.content)
        let state = try #require(gameState.player?.meta.engagement.events)
        #expect(state.lastFiredAt[id] == state.clock)
        let next = try #require(state.secondsUntilNext)
        #expect(next >= content.events.intervalSeconds)
        #expect(next < content.events.intervalSeconds + content.events.intervalJitterSeconds)
    }

    @Test("un sorteo sin candidatos no gasta el intervalo")
    func emptyDrawRetriesSoon() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.player?.meta.engagement.events.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(fired(gameState).isEmpty, "frontera 1: ningún evento es elegible")
        let retry = try #require(gameState.content?.events.retryWhenNoneApplicableSeconds)
        #expect(gameState.player?.meta.engagement.events.secondsUntilNext == retry)
    }

    @Test("sin nadie que pueda crecer solo, la Startup no aplica")
    func startupNeedsSomeoneWhoCanEvolve() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["administrativo": 1]
        gameState.reconcileTower()
        #expect(!gameState.eventIsApplicable(try event("startup_comprada", in: gameState)))
    }

    @Test("sin pasivo, el Aguinaldo no aplica; los paquetes esperan a E5")
    func applicability() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.eventIsApplicable(try event("aguinaldo", in: gameState)))
        #expect(!gameState.eventIsApplicable(try event("lluvia_paquetes", in: gameState)))
        #expect(!gameState.eventIsApplicable(try event("piquete", in: gameState)))
        #expect(gameState.eventIsApplicable(try event("devaluacion", in: gameState)))
    }

    @Test("con obra social no sale un negativo")
    func immunityFiltersNegatives() async throws {
        let gameState = try await game(throughTier: 30)
        gameState.grant(.eventImmunity(seconds: 1800), source: "test")
        let content = try #require(gameState.content)
        var seen: Set<String> = []
        for _ in 0..<60 {
            gameState.player?.meta.engagement.events.secondsUntilNext = 0.1
            gameState.player?.meta.engagement.events.lastFiredAt = [:]
            gameState.advanceEngagement(delta: 1)
            seen.formUnion(fired(gameState))
        }
        #expect(!seen.isEmpty)
        for id in seen {
            #expect(content.events.event(id: id)?.polarity != .negative, "\(id) salió con inmunidad")
        }
    }

    @Test("arrancar deja los modificadores con su origen")
    func startEventAppliesEverything() async throws {
        let gameState = try await game()
        let hiper = try event("hiperinflacion", in: gameState)
        gameState.startEvent(hiper, now: 1000)
        let modifiers = try #require(gameState.player?.run.activeModifiers.filter { $0.sourceKey == "event.hiperinflacion" })
        #expect(Set(modifiers.map(\.effect)) == [.spawnCostMultiplier, .incomeMultiplier])
        #expect(modifiers.allSatisfy { $0.expiresAt == 1060 })
    }

    @Test("el banner muestra el evento con sus salidas")
    func bannerShowsTheEvent() async throws {
        let gameState = try await game()
        gameState.startEvent(try event("hiperinflacion", in: gameState), now: 1000)
        #expect(gameState.activeEvent?.id == "hiperinflacion")
        #expect(gameState.activeEvent?.escapes.map(\.kind) == [.video])
    }

    @Test("la salida por video saca el evento; la de la hiperinflación, sólo el ×2 de contratar")
    func videoEscapes() async throws {
        let gameState = try await game()
        let now = Date().timeIntervalSince1970
        gameState.startEvent(try event("devaluacion", in: gameState), now: now)
        #expect(gameState.escapeEvent(id: "devaluacion", via: .video, now: now))
        #expect(gameState.player?.run.activeModifiers.contains { $0.sourceKey == "event.devaluacion" } == false)
        gameState.startEvent(try event("hiperinflacion", in: gameState), now: now)
        #expect(gameState.escapeEvent(id: "hiperinflacion", via: .video, now: now))
        let left = try #require(gameState.player?.run.activeModifiers.filter { $0.sourceKey == "event.hiperinflacion" })
        #expect(left.map(\.effect) == [.incomeMultiplier], "la caja ×3 se queda")
        #expect(!gameState.escapeEvent(id: "plan_platita", via: .video, now: now), "un positivo no tiene salida")
    }

    @Test("la cuota del paro cobra su plata y lo saca; sin plata, no")
    func feeEscape() async throws {
        let gameState = try await game()
        let now = Date().timeIntervalSince1970
        let paro = try event("paro_general", in: gameState)
        gameState.player?.run.coins = 0
        gameState.startEvent(paro, now: now)
        #expect(!gameState.escapeEvent(id: "paro_general", via: .fee, now: now))
        let fee = try #require(gameState.eventFee(id: "paro_general"))
        gameState.player?.run.coins = fee * 2
        #expect(gameState.escapeEvent(id: "paro_general", via: .fee, now: now))
        let coins = try #require(gameState.player?.run.coins)
        #expect(abs(coins - fee) < 1e-6 * max(1, fee))
    }

    @Test("la Startup y el Blanqueo pasan por el embudo de E1")
    func boardIntentsGoThroughTheFunnel() async throws {
        let gameState = try await game()
        let units = try #require(gameState.player?.run.units)
        gameState.startEvent(try event("startup_comprada", in: gameState), now: 0)
        #expect(gameState.player?.run.units == units, "no muta en el acto")
        #expect(gameState.pendingBoardChanges.last?.origin == .eventStartup)
        gameState.startEvent(try event("blanqueo", in: gameState), now: 0)
        guard case .arrival(let typeId)? = gameState.pendingBoardChanges.last?.kind else {
            Issue.record("el Blanqueo no planeó una llegada")
            return
        }
        #expect(gameState.content?.tiers.type(id: typeId)?.tier == 12 - 3)
    }

    @Test("el Aguinaldo paga sus segundos de producción")
    func aguinaldoPays() async throws {
        let gameState = try await game()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        gameState.startEvent(try event("aguinaldo", in: gameState), now: 0)
        let expected = GameState.coinReward(seconds: 300, player: before, content: content, economy: economy)
        let paid = try #require(gameState.player?.run.coins) - before.run.coins
        #expect(abs(paid - expected) < 1e-6 * max(1, expected))
    }

    @Test("cortar los negativos deja los mixtos y los positivos")
    func cutNegatives() async throws {
        let gameState = try await game()
        let now = Date().timeIntervalSince1970
        for id in ["devaluacion", "hiperinflacion", "plan_platita"] {
            gameState.startEvent(try event(id, in: gameState), now: now)
        }
        gameState.cutNegativeEvents(now: now)
        let sources = Set(gameState.player?.run.activeModifiers.map(\.sourceKey) ?? [])
        #expect(!sources.contains("event.devaluacion"))
        #expect(sources.contains("event.hiperinflacion"))
        #expect(sources.contains("event.plan_platita"))
    }

    @Test("lo que la Vecina adelanta es lo que sale")
    func upcomingIsWhatComes() async throws {
        let gameState = try await game(throughTier: 30)
        let peeked = try #require(gameState.peekUpcomingEvent())
        gameState.player?.meta.engagement.events.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(fired(gameState) == [peeked.id])
    }

    @Test("el banner de un evento instantáneo dura sus segundos y se va")
    func bannerLifetime() async throws {
        let gameState = try await game()
        gameState.startEvent(try event("aguinaldo", in: gameState), now: 100)
        #expect(gameState.activeEvent?.endsAt == 100 + GameState.instantEventBannerSeconds)
        gameState.expireActiveEvent(now: 100 + GameState.instantEventBannerSeconds)
        #expect(gameState.activeEvent == nil)
    }

    @Test("resetear la partida limpia los relojes de eventos y de visitantes, y el banner")
    func debugResetClearsEngagement() async throws {
        let gameState = try await game()
        gameState.startEvent(try event("devaluacion", in: gameState), now: 1000)
        gameState.player?.meta.engagement.events = EventsState(clock: 500, secondsUntilNext: 3, lastFiredAt: ["devaluacion": 400])
        gameState.player?.meta.engagement.visitors = VisitorsState(secondsUntilVisit: 9, recentScripts: ["x"], visitsToday: ["x": 1])
        gameState.debugResetSave()
        #expect(gameState.player?.meta.engagement.events == .initial)
        #expect(gameState.player?.meta.engagement.visitors == .initial)
        #expect(gameState.activeEvent == nil)
    }
}
