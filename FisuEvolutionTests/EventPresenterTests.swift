import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los eventos entran con su presentador", .serialized)
@MainActor
struct EventPresenterTests {
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 10)
        gameState.debugGrantCoins()
        return gameState
    }

    private func arrive(_ gameState: GameState) throws {
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
    }

    private func running(_ gameState: GameState, _ id: String) -> Bool {
        gameState.player?.run.activeModifiers.contains { $0.sourceKey == "event.\(id)" } == true
    }

    @Test("el sorteo manda al presentador; el evento no pasa hasta que llega")
    func theDrawSendsThePresenter() async throws {
        let gameState = await world()
        gameState.fireDueEvent(now: Date().timeIntervalSince1970)
        let visit = try #require(gameState.stageVisit)
        guard case .presenter(let id) = visit.role else { Issue.record("no es un presentador"); return }
        #expect(!running(gameState, id))
        let event = try #require(gameState.content?.events.event(id: id))
        #expect(event.presenters.contains(visit.actorId))
    }

    @Test("al llegar, el evento pasa, el globo dice su frase y se va enseguida")
    func arrivingStartsTheEvent() async throws {
        let gameState = await world()
        gameState.debugPresentEvent(id: "devaluacion")
        #expect(!running(gameState, "devaluacion"))
        try arrive(gameState)
        #expect(running(gameState, "devaluacion"))
        let event = try #require(gameState.content?.events.event(id: "devaluacion"))
        #expect(gameState.stageVisit?.bubble == VisitCopy.text(event.phraseKey))
        #expect(gameState.stageRuntime.eventPresenters["devaluacion"] == gameState.stageVisit?.actorId)
        gameState.advanceStage(delta: (gameState.content?.visitors.presenterTalkSeconds ?? 4) + 0.1)
        #expect(gameState.stageVisit?.phase == .leaving)
    }

    @Test("con inmunidad, el presentador de un negativo llega y no pasa nada")
    func immunityStopsANegativeAtTheDoor() async throws {
        let gameState = await world()
        gameState.grant(.eventImmunity(seconds: 600), source: "visit.test")
        gameState.debugPresentEvent(id: "devaluacion")
        try arrive(gameState)
        #expect(!running(gameState, "devaluacion"))
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("event.immune"))
    }

    @Test("un evento que dejó de aplicar mientras caminaba no se presenta")
    func anEventThatStoppedApplyingIsNotPresented() async throws {
        let gameState = await world()
        gameState.debugPresentEvent(id: "aguinaldo")
        gameState.player?.run.activeModifiers.removeAll()
        // Sin pasivo no hay Aguinaldo que dar.
        gameState.player?.run.coins = 0
        let event = try #require(gameState.content?.events.event(id: "aguinaldo"))
        #expect(!gameState.eventIsApplicable(event), "sin pasivo no hay Aguinaldo")
        try arrive(gameState)
        #expect(gameState.stageVisit?.bubble == nil)
        gameState.advanceStage(delta: 0)
        #expect(gameState.stageVisit?.phase == .leaving)
        #expect(gameState.stageRuntime.eventPresenters["aguinaldo"] == nil)
    }

    @Test("con el escenario ocupado el evento espera, y entra antes que el próximo visitante")
    func theEventWaitsForTheStage() async throws {
        let gameState = await world()
        let script = try #require(gameState.content?.visitors.script(id: "turista_propina"))
        gameState.presentVisitor(script)
        try arrive(gameState)
        gameState.debugPresentEvent(id: "ola_calor")
        #expect(gameState.stageRuntime.pendingEvent?.id == "ola_calor")
        #expect(gameState.stageVisit?.role == .visitor(scriptId: "turista_propina"))
        let visitor = try #require(gameState.stageVisit?.id)
        gameState.sendStageActorAway()
        gameState.stageActorLeft(id: visitor)
        gameState.advanceEngagement(delta: 0)
        #expect(gameState.stageVisit?.role == .presenter(eventId: "ola_calor"))
        #expect(gameState.stageRuntime.pendingEvent == nil)
    }

    @Test("con un evento esperando no entra ningún visitante, aunque su carril esté listo")
    func noVisitorCutsInFrontOfAPendingEvent() async throws {
        let gameState = await world()
        gameState.engagementAutorun = true
        let script = try #require(gameState.content?.visitors.script(id: "turista_propina"))
        gameState.presentVisitor(script)
        gameState.debugPresentEvent(id: "ola_calor")
        gameState.sendStageActorAway()
        gameState.stageActorLeft(id: try #require(gameState.stageVisit?.id))
        gameState.player?.meta.engagement.visitors.secondsUntilVisit = 0
        gameState.advanceVisitors(delta: 1)
        #expect(gameState.stageVisit == nil, "el visitante no pasa delante del evento")
        gameState.advanceEngagement(delta: 0)
        #expect(gameState.stageVisit?.role == .presenter(eventId: "ola_calor"))
    }

    @Test("durante un reto no entra nadie: la calma es la de isBoardBusy")
    func nobodyEntersDuringAChallenge() async throws {
        let gameState = await world()
        gameState.stageChallenge = StageChallenge(
            scriptId: "coach_reto",
            terms: ChallengeTerms(taps: 15, windowSeconds: 20, coins: 0, rewards: [], videoDoubles: false),
            taps: 0, endsAt: .infinity
        )
        #expect(gameState.isBoardBusy)
        #expect(!gameState.canPresentOnStage)
        let script = try #require(gameState.content?.visitors.script(id: "turista_propina"))
        gameState.presentVisitor(script)
        #expect(gameState.stageVisit == nil)
        gameState.debugPresentEvent(id: "ola_calor")
        #expect(gameState.stageVisit == nil)
        #expect(gameState.stageRuntime.pendingEvent?.id == "ola_calor", "el evento espera")
    }

    @Test("el popup de un evento corta los intersticiales y la paciencia")
    func theEventPopupCountsAsAnOpenSheet() async throws {
        let gameState = await world()
        gameState.debugStartEvent(id: "paro_general")
        #expect(!gameState.naturalBreakContext.sheetOpen)
        gameState.openEventPopup(id: "paro_general")
        #expect(gameState.naturalBreakContext.sheetOpen)
        #expect(!gameState.isCalmMoment)
    }

    @Test("tocar al presentador abre el popup del evento")
    func tappingThePresenterOpensTheEvent() async throws {
        let gameState = await world()
        gameState.debugPresentEvent(id: "devaluacion")
        try arrive(gameState)
        gameState.stageActorTapped(id: try #require(gameState.stageVisit?.id))
        #expect(gameState.eventPopup?.eventId == "devaluacion")
    }

    @Test("salir del evento cierra su popup; un evento que no corre no abre ninguno")
    func escapingClosesThePopup() async throws {
        let gameState = await world()
        gameState.openEventPopup(id: "paro_general")
        #expect(gameState.eventPopup == nil, "no está corriendo")
        gameState.debugStartEvent(id: "paro_general")
        gameState.openEventPopup(id: "paro_general")
        #expect(gameState.eventPopup?.eventId == "paro_general")
        #expect(gameState.escapeEvent(id: "paro_general", via: .fee))
        #expect(gameState.eventPopup == nil)
    }

    @Test("un doble toque en la salida cobra una sola vez; sin evento, un video no paga")
    func escapingTwiceChargesOnce() async throws {
        let gameState = await world()
        gameState.debugStartEvent(id: "paro_general")
        let before = try #require(gameState.player?.run.coins)
        #expect(gameState.escapeEvent(id: "paro_general", via: .fee))
        let afterFirst = try #require(gameState.player?.run.coins)
        #expect(afterFirst < before)
        #expect(!gameState.escapeEvent(id: "paro_general", via: .fee))
        #expect(gameState.player?.run.coins == afterFirst, "el segundo toque no cobra")
        #expect(!gameState.escapeEvent(id: "hiperinflacion", via: .video), "no corre: no hay nada que premiar")
    }

    @Test("el chip del evento lleva la cara de quien lo anunció")
    func theChipCarriesThePresentersFace() async throws {
        let gameState = await world()
        gameState.debugPresentEvent(id: "hiperinflacion")
        let presenter = try #require(gameState.stageVisit?.actorId)
        try arrive(gameState)
        gameState.refreshProjections()
        let chip = try #require(gameState.activeBonuses.first { $0.eventId == "hiperinflacion" })
        #expect(chip.icon == .face(presenter))
        #expect(chip.polarity == .mixed)
        #expect(gameState.activeBonuses.filter { $0.eventId == "hiperinflacion" }.count == 1,
                "un evento con dos efectos es UN chip")
    }
}
