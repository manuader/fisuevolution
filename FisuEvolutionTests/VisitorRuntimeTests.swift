import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los visitantes en la partida", .serialized)
@MainActor
struct VisitorRuntimeTests {
    /// Frontera en 6 (abre el arresto, el Arbolito y la compra del Turista), plata
    /// y dos pares del tier de la frontera: hay duplicados para llevarse.
    private func world(frontier: Int = 6) async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: frontier)
        gameState.debugGrantCoins()
        gameState.debugGrantPair()
        gameState.debugGrantPair()
        gameState.engagementAutorun = true
        return gameState
    }

    /// Lo pone en escena y lo hace llegar como lo haría la escena.
    private func arrive(_ gameState: GameState, _ scriptId: String) throws {
        let script = try #require(gameState.content?.visitors.script(id: scriptId))
        gameState.presentVisitor(script)
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
    }

    private func coins(_ gameState: GameState) -> Double { gameState.player?.run.coins ?? 0 }

    @Test("el carril listo pone a alguien en escena y anota la visita")
    func aReadyLaneBringsSomeone() async throws {
        let gameState = await world()
        gameState.player?.meta.engagement.visitors.secondsUntilVisit = 1
        gameState.player?.meta.engagement.visitors.secondsUntilVendor = 999
        gameState.advanceVisitors(delta: 2)
        let visit = try #require(gameState.stageVisit)
        guard case .visitor(let scriptId) = visit.role else { Issue.record("no es un visitante"); return }
        #expect(gameState.player?.meta.engagement.visitors.recentScripts.last == scriptId)
        #expect(gameState.player?.meta.engagement.visitors.visitsToday[scriptId] == 1)
        #expect((gameState.player?.meta.engagement.visitors.secondsUntilVisit ?? 0) >= 240, "el próximo, a 4–6 min")
    }

    @Test("con el escenario ocupado el carril espera, sin perder su turno")
    func aBusyStageMakesTheLaneWait() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let first = gameState.stageVisit?.id
        gameState.player?.meta.engagement.visitors.secondsUntilVisit = 1
        gameState.advanceVisitors(delta: 2)
        #expect(gameState.stageVisit?.id == first)
        #expect((gameState.player?.meta.engagement.visitors.secondsUntilVisit ?? 1) <= 0, "sigue listo para cuando se libere")
    }

    @Test("sin el motor prendido no viene nadie (los tests y los --uitest ajenos)")
    func autorunOffMeansNobody() async {
        let gameState = await world()
        gameState.engagementAutorun = false
        gameState.player?.meta.engagement.visitors.secondsUntilVisit = 1
        gameState.advanceVisitors(delta: 2)
        #expect(gameState.stageVisit == nil)
    }

    @Test("la oferta se cotiza al llegar y el globo la nombra")
    func theOfferIsQuotedOnArrival() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let visit = try #require(gameState.stageVisit)
        let offer = try #require(visit.offer)
        #expect(offer.options.map(\.id) == ["accept", "video"])
        #expect(offer.options[0].coins > 0)
        #expect(offer.options[1].coins == offer.options[0].coins * 2)
        #expect(visit.bubble?.isEmpty == false)
    }

    @Test("aceptar cobra lo cotizado, agradece y se va al rato")
    func acceptingPaysAndLeaves() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let option = try #require(gameState.stageVisit?.offer?.option(id: "accept"))
        let before = coins(gameState)
        #expect(gameState.chooseVisitOption("accept"))
        #expect(abs(coins(gameState) - (before + option.coins)) < 0.01)
        #expect(gameState.stageVisit?.offer == nil, "sin oferta, el chip se va")
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.thanks"))
        gameState.advanceStage(delta: GameState.shortStaySeconds + 0.1)
        #expect(gameState.stageVisit?.phase == .leaving)
    }

    @Test("un modificador de visita lleva la fuente del guion; con video, la del ×2")
    func modifiersCarryTheScript() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_cryptobro")
        try arrive(gameState, "cryptobro_senal")
        #expect(gameState.chooseVisitOption("video"))
        let modifier = try #require(gameState.player?.run.activeModifiers.last)
        #expect(modifier.sourceKey == "visit.cryptobro_senal.x2")
        #expect(modifier.effect == .incomeMultiplier)
    }

    @Test("dejar ir al arrestado paga más de lo que cuesta reponerlo y se lo lleva a la vista")
    func releasingTheArrestedPaysAndDeparts() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let offer = try #require(gameState.stageVisit?.offer)
        let release = try #require(offer.option(id: "release"))
        let typeId = try #require(offer.subjectTypeId)
        let unitsBefore = gameState.player?.run.units[typeId] ?? 0
        let before = coins(gameState)
        #expect(gameState.chooseVisitOption("release"))
        #expect(coins(gameState) > before)
        #expect(gameState.pendingBoardChanges.count == release.departures.count, "la salida va por el embudo, a la vista")
        #expect(gameState.player?.run.units[typeId] == unitsBefore, "todavía no se fue: se va en su turno")
        gameState.settleAllPendingBoardChanges()
        #expect(gameState.player?.run.units[typeId] == unitsBefore - 1)
    }

    @Test("pagar la fianza cobra la fianza y no se lleva a nadie")
    func payingBail() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let bail = try #require(gameState.stageVisit?.offer?.option(id: "bail"))
        let before = coins(gameState)
        #expect(gameState.chooseVisitOption("bail"))
        #expect(abs(coins(gameState) - (before - bail.cost)) < 0.01)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("sin plata, o con corralito, no se paga; la oferta sigue en pie")
    func cantPayWithoutCoinsOrFrozen() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let bail = try #require(gameState.stageVisit?.offer?.option(id: "bail"))
        gameState.player?.run.coins = 0
        #expect(!gameState.canAfford(bail))
        #expect(!gameState.chooseVisitOption("bail"))
        #expect(gameState.stageVisit?.offer != nil)
        gameState.debugGrantCoins()
        gameState.debugStartEvent(id: "corralito")
        #expect(!gameState.canAfford(bail), "el corralito congela también los pagos a visitantes")
        #expect(gameState.canAfford(try #require(gameState.stageVisit?.offer?.option(id: "release"))), "cobrar, sí")
    }

    @Test("si el tablero cambió y ya no hay a quién llevarse, no hay trato")
    func aStaleDealIsOff() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let typeId = try #require(gameState.stageVisit?.offer?.subjectTypeId)
        gameState.player?.run.units[typeId] = 1
        let before = coins(gameState)
        #expect(!gameState.chooseVisitOption("release"))
        #expect(coins(gameState) == before)
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.deal_off"))
        #expect(gameState.stageVisit?.offer == nil)
    }

    @Test("el que llega sin trato posible se equivoca de oficina y se va enseguida")
    func wrongOffice() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        try arrive(gameState, "comisario_arresto")
        #expect(gameState.stageVisit?.offer == nil)
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.wrong_office"))
        gameState.advanceStage(delta: GameState.shortStaySeconds + 0.1)
        #expect(gameState.stageVisit?.phase == .leaving)
    }

    @Test("la Vecina adelanta el próximo evento, y queda anotado para salir")
    func gossipRevealsTheNextEvent() async throws {
        let gameState = await world()
        try arrive(gameState, "vecina_chisme")
        #expect(gameState.chooseVisitOption("listen"))
        let upcoming = try #require(gameState.player?.meta.engagement.events.upcomingId)
        let event = try #require(gameState.content?.events.event(id: upcoming))
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.gossip.next", [VisitCopy.text(event.titleKey)]))
    }

    @Test("el reto cuenta los toques a los empleados y paga al llegar")
    func theChallengeCountsTaps() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_coach")
        try arrive(gameState, "coach_reto")
        #expect(gameState.chooseVisitOption("challenge"))
        let challenge = try #require(gameState.stageChallenge)
        #expect(gameState.visitorPopup == nil, "el reto se juega en el tablero")
        let now = Date().timeIntervalSince1970
        for _ in 0..<challenge.terms.taps { gameState.noteStageTap(now: now) }
        #expect(gameState.stageChallenge == nil)
        #expect(gameState.player?.run.activeModifiers.contains { $0.sourceKey == "visit.coach_reto" } == true)
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.challenge.won"))
    }

    @Test("el reto vencido no paga nada")
    func anExpiredChallengePaysNothing() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_coach")
        try arrive(gameState, "coach_reto")
        #expect(gameState.chooseVisitOption("challenge"))
        let endsAt = try #require(gameState.stageChallenge?.endsAt)
        gameState.noteStageTap(now: endsAt - 1)
        gameState.advanceStage(delta: 0.1, now: endsAt + 0.1)
        #expect(gameState.stageChallenge == nil)
        #expect(gameState.player?.run.activeModifiers.contains { $0.sourceKey == "visit.coach_reto" } != true)
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.challenge.lost"))
    }

    @Test("un reto ganado con video doble ofrece el ×2 de lo que acaba de dar")
    func aWonChallengeOffersTheDouble() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let terms = ChallengeTerms(taps: 1, windowSeconds: 10, coins: 100, rewards: [], videoDoubles: true)
        gameState.beginChallenge(scriptId: "vecina_favor", terms: terms, now: 0)
        let before = coins(gameState)
        gameState.noteStageTap(now: 1)
        #expect(coins(gameState) == before + 100)
        let double = try #require(gameState.stageVisit?.offer?.option(id: "video"))
        #expect(double.requiresVideo)
        #expect(gameState.chooseVisitOption("video"))
        #expect(coins(gameState) == before + 200)
    }

    @Test("el Cepo llama al Arbolito del blue, aunque el sorteo no lo traería nunca")
    func theCepoCallsTheArbolito() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_arbolito")
        gameState.debugStartEvent(id: "cepo")
        #expect(gameState.stageRuntime.calledScript == "arbolito_blue")
        gameState.advanceVisitors(delta: 0)
        #expect(gameState.stageVisit?.role == .visitor(scriptId: "arbolito_blue"))
        #expect(gameState.stageRuntime.calledScript == nil)
    }

    @Test("cambiar ORO con el Arbolito cuenta para el tope del día; el blue, no")
    func exchangesCountTowardsTheDailyCap() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_arbolito")
        gameState.player?.run.coins = 1e30
        try arrive(gameState, "arbolito_cambio")
        let oro = gameState.player?.meta.oro ?? 0
        #expect(gameState.chooseVisitOption("exchange"))
        #expect(gameState.player?.meta.oro == oro + 1)
        #expect(gameState.player?.meta.engagement.visitors.oroExchangedToday == 1)
        gameState.sendStageActorAway()
        gameState.stageActorLeft(id: try #require(gameState.stageVisit?.id))
        try arrive(gameState, "arbolito_blue")
        #expect(gameState.chooseVisitOption("exchange"))
        #expect(gameState.player?.meta.engagement.visitors.oroExchangedToday == 1)
    }

    @Test("con alguien en escena nadie más entra, ni a la fuerza")
    func aBusyStageRefusesASecondActor() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let first = gameState.stageVisit?.id
        #expect(!gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme")))
        #expect(gameState.stageVisit?.id == first)
    }

    @Test("la paciencia espera a que se cierre el anuncio a pantalla completa")
    func patienceWaitsForAnAd() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let provider = ScriptedAdsProvider()
        provider.holdsOpen = true
        let ads = AdsCoordinator(provider: provider)
        gameState.ads = ads
        let showing = Task { await ads.showInterstitial() }
        await provider.waitUntilShowing()
        let before = gameState.stageRuntime.patienceLeft
        gameState.advanceStage(delta: 5)
        #expect(gameState.stageRuntime.patienceLeft == before)
        provider.closeCurrentAd()
        _ = await showing.value
        gameState.advanceStage(delta: 5)
        #expect(gameState.stageRuntime.patienceLeft == before - 5)
    }

    @Test("el fixture de arranque presenta al visitante en el primer momento calmo")
    func theBootFixtureWaitsForACalmMoment() async {
        let gameState = await world()
        gameState.applyEngagementFixtures(arguments: ["--uitest-visitor=turista_propina"])
        #expect(gameState.stageVisit == nil)
        gameState.advanceVisitors(delta: 0)
        #expect(gameState.stageVisit?.role == .visitor(scriptId: "turista_propina"))
        #expect(gameState.stageRuntime.debugScript == nil)
    }

    @Test("reencarnar despide al visitante y cancela el reto y el llamado")
    func reincarnatingDismissesTheVisitor() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_coach")
        try arrive(gameState, "coach_reto")
        #expect(gameState.chooseVisitOption("challenge"))
        gameState.stageRuntime.calledScript = "arbolito_blue"
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.confirmPrestige()
        #expect(gameState.stageChallenge == nil)
        #expect(gameState.stageRuntime.calledScript == nil)
        #expect(gameState.stageVisit == nil || gameState.stageVisit?.phase == .leaving)
        #expect(gameState.stageVisit?.offer == nil)
    }

    @Test("lo que se lleva un visitante cuenta como pagado: un kill no deja plata y unidad")
    func visitorDeparturesArePrepaid() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let typeId = try #require(gameState.stageVisit?.offer?.subjectTypeId)
        let unitsBefore = gameState.player?.run.units[typeId] ?? 0
        #expect(gameState.chooseVisitOption("release"))
        gameState.settlePrepaidBoardChanges()
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.units[typeId] == unitsBefore - 1)
    }

    @Test("un toque real a un empleado cuenta para el reto")
    func aRealTapCountsForTheChallenge() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_coach")
        try arrive(gameState, "coach_reto")
        #expect(gameState.chooseVisitOption("challenge"))
        let slot = try #require(gameState.visiblePlacements.first?.slot)
        #expect(gameState.registerTap(cellIndex: slot) != nil)
        #expect(gameState.stageChallenge?.taps == 1)
    }

    @Test("una segunda elección sobre un trato cerrado no toca la plata")
    func aSecondChoiceIsRefused() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        #expect(gameState.chooseVisitOption("accept"))
        let after = coins(gameState)
        #expect(!gameState.chooseVisitOption("accept"))
        #expect(coins(gameState) == after)
    }

    @Test("con un anuncio en pantalla nadie entra a escena")
    func noEntranceOverAnAd() async throws {
        let gameState = await world()
        let provider = ScriptedAdsProvider()
        provider.holdsOpen = true
        let ads = AdsCoordinator(provider: provider)
        gameState.ads = ads
        let showing = Task { await ads.showInterstitial() }
        await provider.waitUntilShowing()
        #expect(!gameState.canPresentOnStage)
        provider.closeCurrentAd()
        _ = await showing.value
        #expect(gameState.canPresentOnStage)
    }
}
