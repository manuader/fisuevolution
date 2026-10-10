import Foundation
import Testing
@testable import EconomyKit

@Suite("Las ofertas de 24 h: disparadores, ventana y enfriamiento")
struct OffersEngineTests {
    static let json = """
    {"schemaVersion": 1, "windowHours": 24, "cooldownDays": 3, "offers": [
      {"id": "bienvenida", "productId": "p.bienvenida", "trigger": "secondDay", "oncePerAccount": true, "isChance": true,
       "iconKey": "k", "symbol": "s",
       "rewards": [{"kind": "oro", "amount": 120}, {"kind": "coinsSeconds", "seconds": 7200}, {"kind": "skinChest", "count": 1}]},
      {"id": "renacer", "productId": "p.renacer", "trigger": "reincarnation", "iconKey": "k", "symbol": "s",
       "rewards": [{"kind": "oro", "amount": 300}]},
      {"id": "mudanza", "productId": "p.mudanza", "trigger": "newFloor", "iconKey": "k", "symbol": "s",
       "rewards": [{"kind": "oro", "amount": 500}, {"kind": "package", "count": 3}]}
    ]}
    """

    let catalog: OffersCatalog
    private let day: Double = 86_400

    init() throws {
        catalog = try JSONDecoder().decode(OffersCatalog.self, from: Data(Self.json.utf8))
    }

    private func signals(
        today: String = "2026-10-07", first: String? = "2026-10-07", prestige: Int = 0, floors: Int = 1
    ) -> OfferSignals {
        OfferSignals(today: today, firstLaunchDay: first, prestigeLevel: prestige, unlockedFloorCount: floors)
    }

    @discardableResult
    private func evaluate(_ state: inout OffersState, _ signals: OfferSignals, now: Double, offerable: Bool = true) -> [String] {
        OffersEngine.evaluate(&state, catalog: catalog, signals: signals, now: now, isOfferable: { _ in offerable })
    }

    @Test("el catálogo se lee y se valida")
    func catalogDecodes() throws {
        try catalog.validate()
        #expect(catalog.windowSeconds == 86_400)
        #expect(catalog.cooldownSeconds == 3 * 86_400)
        #expect(catalog.offer(id: "renacer")?.oroAmount == 300)
        #expect(catalog.offer(productId: "p.mudanza")?.id == "mudanza")
        #expect(catalog.offer(id: "bienvenida")?.oncePerAccount == true)
        #expect(catalog.offer(id: "renacer")?.oncePerAccount == false)
    }

    @Test("la primera vez sólo toma la línea de base: un veterano no recibe tres ofertas al actualizar")
    func baselineFirst() {
        var state = OffersState.initial
        #expect(evaluate(&state, signals(prestige: 4, floors: 6), now: 0).isEmpty)
        #expect(state.seenPrestigeLevel == 4)
        #expect(state.seenUnlockedFloors == 6)
    }

    @Test("Bienvenida sale el 2º día, y una sola vez por cuenta")
    func welcomeOnce() {
        var state = OffersState.initial
        #expect(evaluate(&state, signals(), now: 0).isEmpty, "el primer día, no")
        #expect(evaluate(&state, signals(today: "2026-10-08"), now: day) == ["bienvenida"])
        evaluate(&state, signals(today: "2026-10-09"), now: 2 * day)
        #expect(OffersEngine.activeOffers(state, now: 2 * day).isEmpty, "venció a las 24 h")
        #expect(evaluate(&state, signals(today: "2026-10-20"), now: 13 * day).isEmpty, "no vuelve nunca")
    }

    @Test("Renacer sale al reencarnar y dura 24 h de reloj")
    func rebirthWindow() throws {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 1), now: 0)
        #expect(evaluate(&state, signals(prestige: 2), now: 100) == ["renacer"])
        let offer = try #require(OffersEngine.activeOffers(state, now: 100).first)
        #expect(offer.expiresAt == 100 + day)
        #expect(!offer.presented)
        #expect(OffersEngine.activeOffers(state, now: 100 + day).isEmpty)
    }

    @Test("volver a dispararse no estira la ventana")
    func retriggerDoesNotExtend() throws {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 1), now: 0)
        evaluate(&state, signals(prestige: 2), now: 100)
        #expect(evaluate(&state, signals(prestige: 3), now: 3_700).isEmpty)
        #expect(try #require(state.active.first).expiresAt == 100 + day)
    }

    @Test("cerrada la ventana, 3 días de enfriamiento")
    func cooldown() {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 1), now: 0)
        evaluate(&state, signals(prestige: 2), now: 0)
        evaluate(&state, signals(prestige: 2), now: day)
        #expect(state.lastClosedAt["renacer"] == day)
        #expect(evaluate(&state, signals(prestige: 3), now: day + 2 * day).isEmpty, "a los 2 días, todavía no")
        #expect(evaluate(&state, signals(prestige: 4), now: day + 3 * day) == ["renacer"])
    }

    @Test("Mudanza sale al abrir un piso; reencarnar no la dispara")
    func movingDay() {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 0, floors: 3), now: 0)
        #expect(evaluate(&state, signals(prestige: 0, floors: 4), now: 10) == ["mudanza"])
        var other = OffersState.initial
        evaluate(&other, signals(prestige: 0, floors: 5), now: 0)
        #expect(evaluate(&other, signals(prestige: 1, floors: 1), now: 10) == ["renacer"], "la run nueva arranca con un piso")
        #expect(other.seenUnlockedFloors == 1)
    }

    @Test("comprar cierra la ventana y arranca el enfriamiento")
    func purchaseCloses() {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 1), now: 0)
        evaluate(&state, signals(prestige: 2), now: 0)
        OffersEngine.markPurchased("renacer", in: &state, now: 500)
        #expect(state.active.isEmpty)
        #expect(state.purchases["renacer"] == 1)
        #expect(state.lastClosedAt["renacer"] == 500)
    }

    @Test("una compra fuera de la ventana se cuenta igual y marca el cierre")
    func purchaseOutsideTheWindow() {
        var state = OffersState.initial
        OffersEngine.markPurchased("mudanza", in: &state, now: 9_999)
        #expect(state.purchases["mudanza"] == 1)
        #expect(state.lastClosedAt["mudanza"] == 9_999, "toda compra marca el cierre: otro dispositivo no la vuelve a vender")
    }

    @Test("lo que no se puede ofrecer no se abre, y no se gasta")
    func notOfferable() {
        var state = OffersState.initial
        #expect(evaluate(&state, signals(today: "2026-10-08"), now: day, offerable: false).isEmpty)
        #expect(!state.everOpened.contains("bienvenida"))
        #expect(evaluate(&state, signals(today: "2026-10-09"), now: 2 * day) == ["bienvenida"])
    }

    @Test("el validador rechaza ids repetidos, ofertas vacías y azar sin declarar")
    func validation() throws {
        func decode(_ offers: String) throws -> OffersCatalog {
            try JSONDecoder().decode(OffersCatalog.self, from: Data(#"{"schemaVersion": 1, "windowHours": 24, "cooldownDays": 3, "offers": [\#(offers)]}"#.utf8))
        }
        let a = #"{"id": "a", "productId": "p.a", "trigger": "newFloor", "iconKey": "k", "symbol": "s", "rewards": [{"kind": "oro", "amount": 1}]}"#
        #expect(throws: OffersCatalog.ValidationError.duplicateID("a")) { try decode("\(a), \(a)").validate() }
        let empty = #"{"id": "e", "productId": "p.e", "trigger": "newFloor", "iconKey": "k", "symbol": "s", "rewards": []}"#
        #expect(throws: OffersCatalog.ValidationError.emptyRewards("e")) { try decode(empty).validate() }
        let chest = #"{"id": "c", "productId": "p.c", "trigger": "newFloor", "iconKey": "k", "symbol": "s", "rewards": [{"kind": "skinChest", "count": 1}]}"#
        #expect(throws: OffersCatalog.ValidationError.chanceNotDeclared("c")) { try decode(chest).validate() }
    }
}
