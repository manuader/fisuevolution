import Foundation
import Testing
@testable import EconomyKit

private func shopEvent(
    _ id: String = "cyber", _ destination: EventCatalog.ShopDestination = .store, focus: String? = "pack"
) -> EventCatalog.Event {
    fxEvent(id, .positive, duration: 0, effects: [.openShop(destination: destination, focus: focus)])
}

@Suite("Eventos de compra (C25)")
struct ShopEventsTests {
    let policy = ShopEventPolicy.standard
    let calm = ShopEventPolicy.Session(activeSeconds: 600, shopEventsSoFar: 0)
    let seasoned = EventsState(clock: 7200)

    @Test("el efecto openShop se lee y se escribe con su destino y su foco")
    func codableRoundTrip() throws {
        let json = #"{"kind": "openShop", "destination": "boosts", "focus": "income_x2"}"#
        let effect = try JSONDecoder().decode(EventCatalog.Effect.self, from: Data(json.utf8))
        #expect(effect == .openShop(destination: .boosts, focus: "income_x2"))
        let again = try JSONDecoder().decode(EventCatalog.Effect.self, from: JSONEncoder().encode(effect))
        #expect(again == effect)
        let bare = try JSONDecoder().decode(EventCatalog.Effect.self, from: Data(#"{"kind":"openShop","destination":"store"}"#.utf8))
        #expect(bare == .openShop(destination: .store, focus: nil))
    }

    @Test("abrir la tienda no toca la economía: ni plata, ni tablero, ni modificadores")
    func doesNotTouchTheEconomy() throws {
        let tiers = try fxTiers()
        let application = EventPlanner.apply(shopEvent(), state: fxState(), tiers: tiers, now: 100)
        #expect(application.coinsSeconds == 0)
        #expect(application.boardIntent == nil)
        #expect(application.modifiers.isEmpty)
        #expect(application.shopOffer == EventCatalog.ShopOffer(destination: .store, focus: "pack"))
    }

    @Test("sin los topes del JSON valen los de siempre; con ellos, los suyos")
    func policyDefaultsAndOverride() throws {
        #expect(fxEventCatalog().shopPolicy == .standard)
        let json = #"""
        {"schemaVersion": 2, "firstEventAfterSeconds": 900, "intervalSeconds": 900, "intervalJitterSeconds": 0,
         "resumeGraceSeconds": 60, "retryWhenNoneApplicableSeconds": 30, "events": [],
         "shopEvents": {"maxPerSession": 2, "minSeparationSeconds": 10, "purchaseQuietSeconds": 20,
                        "minSessionSeconds": 30, "minPlayedSeconds": 40}}
        """#
        let catalog = try JSONDecoder().decode(EventCatalog.self, from: Data(json.utf8))
        #expect(catalog.shopPolicy.maxPerSession == 2 && catalog.shopPolicy.minPlayedSeconds == 40)
    }

    @Test("un evento de compra solo, positivo y sin duración; cualquier otra forma se rechaza")
    func validation() {
        func rejects(_ event: EventCatalog.Event) -> Bool {
            (try? fxEventCatalog(events: [event]).validate(visitorIDs: ["npc_ministro"], scriptIDs: [])) == nil
        }
        #expect(!rejects(shopEvent()))
        #expect(rejects(fxEvent("a", .positive, duration: 30, effects: [.openShop(destination: .store, focus: nil)])))
        #expect(rejects(fxEvent("b", .positive, duration: 0, effects: [.openShop(destination: .store, focus: nil), .coinsSeconds(60)])))
        #expect(rejects(fxEvent("c", .negative, duration: 0, effects: [.openShop(destination: .store, focus: nil)],
                                escapes: [.init(kind: .video, feeSeconds: nil, removes: nil)])))
    }

    @Test("lo que no es de compra no lo frena ningún tope")
    func plainEventsAreNeverGated() {
        let plain = fxEvent("plain", .positive, effects: [.coinsSeconds(60)])
        let hostile = ShopEventPolicy.Session(activeSeconds: 0, shopEventsSoFar: 9)
        #expect(policy.allows(plain, state: EventsState(), session: hostile, now: 0))
    }

    @Test("tope de uno por sesión")
    func oncePerSession() {
        #expect(policy.allows(shopEvent(), state: seasoned, session: calm, now: 0))
        let spent = ShopEventPolicy.Session(activeSeconds: 600, shopEventsSoFar: 1)
        #expect(!policy.allows(shopEvent(), state: seasoned, session: spent, now: 0))
    }

    @Test("nunca en el arranque ni en la primera sesión")
    func neverAtStartup() {
        let fresh = ShopEventPolicy.Session(activeSeconds: 60, shopEventsSoFar: 0)
        #expect(!policy.allows(shopEvent(), state: seasoned, session: fresh, now: 0))
        #expect(!policy.allows(shopEvent(), state: EventsState(clock: 600), session: calm, now: 0))
    }

    @Test("separación mínima de 4 h de juego entre eventos de compra, de cualquier destino")
    func minimumSeparation() {
        var state = seasoned
        state.lastShopEventAt = 7200 - 3 * 3600
        #expect(!policy.allows(shopEvent("x", .boosts), state: state, session: calm, now: 0))
        state.lastShopEventAt = 7200 - 4 * 3600
        #expect(policy.allows(shopEvent("x", .boosts), state: state, session: calm, now: 0))
    }

    @Test("marcar que salió anota el reloj: el siguiente espera la separación")
    func firingStampsTheShopClock() {
        var state = seasoned
        var rng = SystemRandomNumberGenerator()
        EventScheduler.markFired(shopEvent(), state: &state, catalog: fxEventCatalog(), rng: &rng)
        #expect(state.lastShopEventAt == 7200)
        EventScheduler.markFired(fxEvent("plain", .positive, effects: [.coinsSeconds(60)]), state: &state,
                                 catalog: fxEventCatalog(), rng: &rng)
        #expect(state.lastShopEventAt == 7200)
        #expect(!policy.allows(shopEvent(), state: state, session: calm, now: 0))
    }

    @Test("con una compra de las últimas 24 h no sale el de la Tienda; el de Mejoras sí")
    func recentPurchaseSilencesTheStore() {
        var state = seasoned
        let now = 1_000_000.0
        state.lastPurchaseAt = now - 23 * 3600
        #expect(!policy.allows(shopEvent("x", .store), state: state, session: calm, now: now))
        #expect(policy.allows(shopEvent("x", .boosts), state: state, session: calm, now: now))
        #expect(policy.allows(shopEvent("x", .permanent), state: state, session: calm, now: now))
        state.lastPurchaseAt = now - 25 * 3600
        #expect(policy.allows(shopEvent("x", .store), state: state, session: calm, now: now))
    }

    @Test("el estado viejo, sin los campos nuevos, se lee; y el sync se queda con lo más reciente")
    func stateCompatibilityAndResolve() throws {
        let old = try JSONDecoder().decode(EventsState.self, from: Data(#"{"clock": 5}"#.utf8))
        #expect(old.lastShopEventAt == nil && old.lastPurchaseAt == nil)
        let resolved = EventsState.resolve(
            winner: EventsState(clock: 1, lastShopEventAt: 10, lastPurchaseAt: 5),
            loser: EventsState(clock: 2, lastShopEventAt: 20, lastPurchaseAt: nil)
        )
        #expect(resolved.lastShopEventAt == 20 && resolved.lastPurchaseAt == 5)
    }
}
