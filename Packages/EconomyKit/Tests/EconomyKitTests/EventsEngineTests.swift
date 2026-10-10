import Foundation
import Testing
@testable import EconomyKit

/// Un catálogo chico con un evento de cada forma.
func fxEventCatalog(
    first: Double = 900,
    interval: Double = 900,
    jitter: Double = 300,
    events: [EventCatalog.Event]? = nil
) -> EventCatalog {
    EventCatalog(
        schemaVersion: 2,
        firstEventAfterSeconds: first,
        intervalSeconds: interval,
        intervalJitterSeconds: jitter,
        resumeGraceSeconds: 60,
        retryWhenNoneApplicableSeconds: 30,
        events: events ?? [
            fxEvent("boom", .positive, effects: [.modifier(effect: .incomeMultiplier, magnitude: 3)]),
            fxEvent("bajon", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.5)],
                    escapes: [.init(kind: .video, feeSeconds: nil, removes: nil)]),
            fxEvent("mezcla", .mixed, effects: [
                .modifier(effect: .spawnCostMultiplier, magnitude: 2),
                .modifier(effect: .incomeMultiplier, magnitude: 3),
            ], escapes: [.init(kind: .video, feeSeconds: nil, removes: [.spawnCostMultiplier])]),
            fxEvent("regalo", .positive, duration: 0, effects: [.grantUnit(tiersBelowFrontier: 1), .coinsSeconds(300)]),
        ]
    )
}

func fxEvent(
    _ id: String,
    _ polarity: EventCatalog.Polarity,
    duration: Double = 60,
    weight: Int = 10,
    minTier: Int = 1,
    cooldown: Double = 600,
    effects: [EventCatalog.Effect],
    escapes: [EventCatalog.Escape] = [],
    scene: EventCatalog.Scene? = nil,
    candleStep: Double? = nil
) -> EventCatalog.Event {
    EventCatalog.Event(
        id: id, polarity: polarity, durationSeconds: duration, weight: weight, minTier: minTier,
        cooldownSeconds: cooldown, titleKey: "event.\(id).title", phraseKey: "event.\(id).phrase",
        presenters: ["npc_ministro"], effects: effects, escapes: escapes, scene: scene, candleStep: candleStep
    )
}

@Suite("Eventos v2: el catálogo")
struct EventCatalogTests {
    @Test("se lee la forma del JSON del juego")
    func decodesTheDataShape() throws {
        let json = """
        {"schemaVersion": 2, "firstEventAfterSeconds": 900, "intervalSeconds": 900, "intervalJitterSeconds": 300,
         "resumeGraceSeconds": 60, "retryWhenNoneApplicableSeconds": 30,
         "events": [
           {"id": "paro_general", "polarity": "negative", "durationSeconds": 30, "weight": 8, "minTier": 6,
            "cooldownSeconds": 2400, "titleKey": "event.paro_general.title", "phraseKey": "event.paro_general.phrase",
            "presenters": ["npc_sindicalista"],
            "effects": [{"kind": "modifier", "effect": "passiveMultiplier", "magnitude": 0}],
            "escapes": [{"kind": "fee", "feeSeconds": 120}, {"kind": "video"}]},
           {"id": "cepo", "polarity": "negative", "durationSeconds": 60, "weight": 6, "minTier": 6,
            "cooldownSeconds": 3600, "titleKey": "event.cepo.title", "phraseKey": "event.cepo.phrase",
            "presenters": ["npc_ministro"],
            "effects": [{"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 1.5},
                        {"kind": "callVisitor", "script": "arbolito_blue"}],
            "escapes": [{"kind": "video"}]},
           {"id": "apagon", "polarity": "negative", "durationSeconds": 45, "weight": 8, "minTier": 5,
            "cooldownSeconds": 2400, "titleKey": "event.apagon.title", "phraseKey": "event.apagon.phrase",
            "presenters": ["npc_vecina"], "scene": "blackout", "candleStep": 0.07,
            "effects": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 0.3}],
            "escapes": [{"kind": "video"}]},
           {"id": "blanqueo", "polarity": "positive", "durationSeconds": 0, "weight": 4, "minTier": 9,
            "cooldownSeconds": 5400, "titleKey": "event.blanqueo.title", "phraseKey": "event.blanqueo.phrase",
            "presenters": ["npc_ministro"], "effects": [{"kind": "grantUnit", "tiersBelowFrontier": 3}], "escapes": []},
           {"id": "startup_comprada", "polarity": "positive", "durationSeconds": 0, "weight": 8, "minTier": 5,
            "cooldownSeconds": 2700, "titleKey": "event.startup_comprada.title", "phraseKey": "event.startup_comprada.phrase",
            "presenters": ["npc_conductor"], "effects": [{"kind": "evolveBestUnit"}], "escapes": []}
         ]}
        """
        let catalog = try JSONDecoder().decode(EventCatalog.self, from: Data(json.utf8))
        let paro = try #require(catalog.event(id: "paro_general"))
        #expect(paro.effects == [.modifier(effect: .passiveMultiplier, magnitude: 0)])
        #expect(paro.escapes.map(\.kind) == [.fee, .video])
        #expect(paro.escapes.first?.feeSeconds == 120)
        #expect(catalog.event(id: "cepo")?.effects.last == .callVisitor(script: "arbolito_blue"))
        #expect(catalog.event(id: "apagon")?.scene == .blackout)
        #expect(catalog.event(id: "apagon")?.candleStep == 0.07)
        #expect(catalog.event(id: "blanqueo")?.effects == [.grantUnit(tiersBelowFrontier: 3)])
        #expect(catalog.event(id: "startup_comprada")?.effects == [.evolveBestUnit])
        #expect(try JSONDecoder().decode(EventCatalog.self, from: JSONEncoder().encode(catalog)) == catalog)
        try catalog.validate(
            visitorIDs: ["npc_sindicalista", "npc_ministro", "npc_vecina", "npc_conductor"],
            scriptIDs: ["arbolito_blue"]
        )
    }

    private func reject(_ event: EventCatalog.Event) {
        let catalog = fxEventCatalog(events: [event])
        #expect(throws: EventCatalog.ValidationError.self) {
            try catalog.validate(visitorIDs: ["npc_ministro"], scriptIDs: ["arbolito_blue"])
        }
    }

    @Test("el validador frena lo que el juego no puede cumplir")
    func validationRejectsBrokenEvents() {
        // Un negativo siempre tiene salida por video (decisión del dueño, PLAN-v2 §2).
        reject(fxEvent("a", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.5)]))
        reject(fxEvent("b", .mixed, effects: [.modifier(effect: .incomeMultiplier, magnitude: 3)],
                       escapes: [.init(kind: .free, feeSeconds: nil, removes: nil)]))
        reject(fxEvent("c", .positive, duration: 0, effects: [.modifier(effect: .incomeMultiplier, magnitude: 3)]))
        reject(fxEvent("d", .positive, effects: []))
        reject(fxEvent("e", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.5)],
                       escapes: [.init(kind: .video, feeSeconds: nil, removes: [.tapMultiplier])]))
        reject(fxEvent("f", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.5)],
                       escapes: [.init(kind: .fee, feeSeconds: 0, removes: nil), .init(kind: .video, feeSeconds: nil, removes: nil)]))
        reject(fxEvent("g", .positive, effects: [.callVisitor(script: "nadie")]))
        reject(fxEvent("h", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.3)],
                       escapes: [.init(kind: .video, feeSeconds: nil, removes: nil)], scene: .blackout))
        reject(EventCatalog.Event(
            id: "i", polarity: .positive, durationSeconds: 0, weight: 1, minTier: 1, cooldownSeconds: 0,
            titleKey: "t", phraseKey: "p", presenters: ["npc_nadie"], effects: [.coinsSeconds(300)], escapes: [],
            scene: nil, candleStep: nil
        ))
    }

    @Test("dos eventos con el mismo id no se distinguen en los cooldowns")
    func duplicateIds() {
        let event = fxEvent("x", .positive, effects: [.coinsSeconds(10)])
        #expect(throws: EventCatalog.ValidationError.duplicateId("x")) {
            try fxEventCatalog(events: [event, event]).validate(visitorIDs: ["npc_ministro"], scriptIDs: [])
        }
    }

    @Test("el fixture es válido")
    func fixtureIsValid() throws {
        try fxEventCatalog().validate(visitorIDs: ["npc_ministro"], scriptIDs: [])
    }
}

@Suite("Eventos v2: el sorteo en reloj de juego")
struct EventSchedulerTests {
    let catalog = fxEventCatalog()

    private func advance(_ state: inout EventsState, seconds: Double) -> Bool {
        var due = false
        var elapsed = 0.0
        while elapsed < seconds {
            due = EventScheduler.advance(&state, delta: 1, catalog: catalog) || due
            elapsed += 1
        }
        return due
    }

    @Test("el primero vence a los firstEventAfterSeconds de juego, no antes")
    func firstEventAfterPlayTime() {
        var state = EventsState.initial
        #expect(!advance(&state, seconds: 899))
        #expect(advance(&state, seconds: 1))
        #expect(state.clock == 900)
    }

    @Test("un salto grande del tick no cuenta: el background no es juego")
    func deltaIsClamped() {
        var state = EventsState.initial
        _ = EventScheduler.advance(&state, delta: 3600, catalog: catalog)
        #expect(state.clock == IncomeTicker.deltaClampThreshold)
        #expect(state.secondsUntilNext == 900 - IncomeTicker.deltaClampThreshold)
    }

    @Test("el cooldown se mide en reloj de juego")
    func cooldownInPlayClock() {
        var state = EventsState(clock: 1000, lastFiredAt: ["boom": 500])
        let ids = EventScheduler.eligible(catalog: catalog, state: state, maxTier: 5, isImmune: false) { _ in true }.map(\.id)
        #expect(!ids.contains("boom"))
        state.clock = 1100
        #expect(EventScheduler.eligible(catalog: catalog, state: state, maxTier: 5, isImmune: false) { _ in true }
            .map(\.id).contains("boom"))
    }

    @Test("el tier mínimo y lo inaplicable quedan afuera")
    func tierAndApplicability() {
        let gated = fxEventCatalog(events: [fxEvent("alto", .positive, minTier: 9, effects: [.coinsSeconds(1)])])
        #expect(EventScheduler.eligible(catalog: gated, state: .initial, maxTier: 8, isImmune: false) { _ in true }.isEmpty)
        #expect(EventScheduler.eligible(catalog: catalog, state: .initial, maxTier: 5, isImmune: false) { $0.id != "regalo" }
            .map(\.id).sorted() == ["bajon", "boom", "mezcla"])
    }

    @Test("con inmunidad no sale un negativo; un mixto sí")
    func immunityFiltersNegativesOnly() {
        let ids = EventScheduler.eligible(catalog: catalog, state: .initial, maxTier: 5, isImmune: true) { _ in true }.map(\.id)
        #expect(!ids.contains("bajon"))
        #expect(ids.contains("mezcla"))
    }

    @Test("el sorteo respeta los pesos y sólo elige elegibles")
    func rollRespectsWeights() {
        var rng = SeededRNG(seed: 7)
        var seen: Set<String> = []
        for _ in 0..<200 {
            guard let event = EventScheduler.roll(catalog: catalog, state: .initial, maxTier: 5, isImmune: true,
                                                  isApplicable: { $0.id != "boom" }, rng: &rng) else { continue }
            seen.insert(event.id)
        }
        #expect(seen == ["mezcla", "regalo"])
    }

    @Test("sin elegibles no hay evento")
    func emptyRoll() {
        var rng = SeededRNG(seed: 1)
        #expect(EventScheduler.roll(catalog: catalog, state: .initial, maxTier: 5, isImmune: false,
                                    isApplicable: { _ in false }, rng: &rng) == nil)
    }

    @Test("lo que la Vecina adelanta es lo que sale")
    func upcomingIsWhatComes() throws {
        var state = EventsState.initial
        var rng = SeededRNG(seed: 3)
        let peeked = try #require(EventScheduler.peekUpcoming(catalog: catalog, state: &state, maxTier: 5, isImmune: false,
                                                              isApplicable: { _ in true }, rng: &rng))
        for seed in UInt64(0)..<20 {
            var other = SeededRNG(seed: seed)
            var copy = state
            #expect(EventScheduler.takeDue(catalog: catalog, state: &copy, maxTier: 5, isImmune: false,
                                           isApplicable: { _ in true }, rng: &other)?.id == peeked.id)
            #expect(copy.upcomingId == nil)
        }
    }

    @Test("si lo adelantado dejó de ser elegible, se sortea otro")
    func upcomingDroppedWhenIneligible() throws {
        var state = EventsState(upcomingId: "bajon")
        var rng = SeededRNG(seed: 3)
        let event = try #require(EventScheduler.takeDue(catalog: catalog, state: &state, maxTier: 5, isImmune: true,
                                                        isApplicable: { _ in true }, rng: &rng))
        #expect(event.id != "bajon")
    }

    @Test("salir programa el próximo entre el intervalo y el intervalo más el jitter")
    func markFiredSchedulesTheNext() throws {
        var state = EventsState(clock: 1234)
        var rng = SeededRNG(seed: 9)
        let event = try #require(catalog.event(id: "boom"))
        EventScheduler.markFired(event, state: &state, catalog: catalog, rng: &rng)
        #expect(state.lastFiredAt["boom"] == 1234)
        let next = try #require(state.secondsUntilNext)
        #expect(next >= 900 && next < 1200)
    }

    @Test("un sorteo vacío reintenta pronto, sin gastar el intervalo")
    func retrySoon() {
        var state = EventsState(secondsUntilNext: -3)
        EventScheduler.retrySoon(state: &state, catalog: catalog)
        #expect(state.secondsUntilNext == 30)
    }

    @Test("al volver, un evento vencido espera la gracia; uno lejano no se toca")
    func resumeGrace() {
        var overdue = EventsState(secondsUntilNext: 0)
        EventScheduler.applyResumeGrace(state: &overdue, catalog: catalog)
        #expect(overdue.secondsUntilNext == 60)
        var far = EventsState(secondsUntilNext: 500)
        EventScheduler.applyResumeGrace(state: &far, catalog: catalog)
        #expect(far.secondsUntilNext == 500)
    }
}

@Suite("Eventos v2: qué hace cada uno")
struct EventPlannerTests {
    let catalog = fxEventCatalog()
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    @Test("los modificadores llevan el origen del evento y vencen con él")
    func modifiersCarryTheSourceKey() throws {
        let event = try #require(catalog.event(id: "mezcla"))
        let application = EventPlanner.apply(event, state: fxState(), tiers: tiers, now: 100)
        #expect(application.modifiers.map(\.effect) == [.spawnCostMultiplier, .incomeMultiplier])
        #expect(application.modifiers.allSatisfy { $0.sourceKey == "event.mezcla" && $0.expiresAt == 160 })
        #expect(application.boardIntent == nil)
    }

    @Test("el regalo pide una llegada un tier abajo de la frontera, y paga sus segundos")
    func grantUnitAndCoins() throws {
        var state = fxState()
        state.run.raiseFrontier(to: 4)
        let application = EventPlanner.apply(try #require(catalog.event(id: "regalo")), state: state, tiers: tiers, now: 0)
        #expect(application.boardIntent == .grantUnit(typeId: "c_prog") || application.boardIntent == .grantUnit(typeId: "c_law"))
        #expect(application.coinsSeconds == 300)
    }

    @Test("el tipo regalado respeta la carrera elegida")
    func grantedTypeRespectsTheCareer() throws {
        var state = fxState()
        state.run.raiseFrontier(to: 4)
        state.run.chosenCareerPath = "law"
        #expect(EventPlanner.grantedUnitType(tiersBelowFrontier: 1, state: state, tiers: tiers)?.id == "c_law")
        #expect(EventPlanner.grantedUnitType(tiersBelowFrontier: 9, state: state, tiers: tiers)?.tier == 1)
    }

    @Test("la startup pide evolucionar y el cepo llama a su visitante")
    func intents() {
        let startup = fxEvent("startup", .positive, duration: 0, effects: [.evolveBestUnit])
        #expect(EventPlanner.apply(startup, state: fxState(), tiers: tiers, now: 0).boardIntent == .evolveBestUnit)
        let cepo = fxEvent("cepo", .negative, effects: [.modifier(effect: .spawnCostMultiplier, magnitude: 1.5), .callVisitor(script: "arbolito_blue")])
        #expect(EventPlanner.apply(cepo, state: fxState(), tiers: tiers, now: 0).calledScript == "arbolito_blue")
    }

    @Test("una salida saca todo el evento; la de la hiperinflación, sólo lo que dice")
    func escapes() throws {
        let mezcla = try #require(catalog.event(id: "mezcla"))
        let other = ActiveModifier(effect: .tapMultiplier, magnitude: 2, expiresAt: 999, sourceKey: "boost.cafe")
        let modifiers = EventPlanner.apply(mezcla, state: fxState(), tiers: tiers, now: 0).modifiers + [other]
        let partial = EventPlanner.escape(mezcla.escapes[0], of: mezcla, from: modifiers)
        #expect(partial.map(\.effect) == [.incomeMultiplier, .tapMultiplier])
        let full = EventPlanner.escape(EventCatalog.Escape(kind: .free, feeSeconds: nil, removes: nil), of: mezcla, from: modifiers)
        #expect(full == [other])
    }

    @Test("la obra social corta los negativos y deja mixtos y positivos")
    func cutNegatives() throws {
        let modifiers = ["boom", "bajon", "mezcla"].flatMap { id in
            EventPlanner.apply(catalog.event(id: id)!, state: fxState(), tiers: tiers, now: 0).modifiers
        }
        let kept = EventPlanner.cutNegatives(modifiers, catalog: catalog)
        #expect(Set(kept.map(\.sourceKey)) == ["event.boom", "event.mezcla"])
    }

    @Test("un chip por evento corriendo, con su vencimiento más lejano")
    func runningEvents() throws {
        let mezcla = try #require(catalog.event(id: "mezcla"))
        var modifiers = EventPlanner.apply(mezcla, state: fxState(), tiers: tiers, now: 0).modifiers
        modifiers.append(ActiveModifier(effect: .incomeMultiplier, magnitude: 3, expiresAt: 5, sourceKey: "event.boom"))
        let running = EventPlanner.running(modifiers, catalog: catalog, now: 10)
        #expect(running.map(\.id) == ["mezcla"], "el boom ya venció")
        #expect(running.first?.expiresAt == 60)
        #expect(running.first?.presenterId == "npc_ministro")
    }

    @Test("cada velita sube el apagón hasta ×1, y ahí no hay más")
    func candles() throws {
        let apagon = fxEvent("apagon", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.3)],
                             escapes: [.init(kind: .video, feeSeconds: nil, removes: nil)], scene: .blackout, candleStep: 0.07)
        var modifiers = EventPlanner.apply(apagon, state: fxState(), tiers: tiers, now: 0).modifiers
        var lit = 0
        while let next = EventPlanner.lightCandle(modifiers, event: apagon, now: 1) {
            modifiers = next
            lit += 1
        }
        #expect(lit == 10)
        #expect(modifiers.first?.magnitude == 1)
        #expect(EventPlanner.lightCandle(modifiers, event: apagon, now: 1) == nil)
    }
}
