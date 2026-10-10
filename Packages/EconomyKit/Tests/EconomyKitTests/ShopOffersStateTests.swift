import Foundation
import Testing
@testable import EconomyKit

/// La tienda de ORO y las ofertas de 24 h recuerdan en `meta.engagement`
/// (PLAN-v2 E6), sin subir el schema del save.
@Suite("EngagementState: tienda y ofertas")
struct ShopOffersStateTests {
    @Test("un engagement escrito antes de E6 decodifica con los tres en su estado inicial")
    func decodesWithoutTheKeys() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(state.shop == .initial)
        #expect(state.offers == .initial)
        #expect(state.firstLaunchDay == nil)
    }

    @Test("un estado a medias también decodifica")
    func partialStatesDecode() throws {
        let json = #"{"shop": {"levels": {"better_supplier": 2}}, "offers": {"everOpened": ["bienvenida"]}}"#
        let state = try JSONDecoder().decode(EngagementState.self, from: Data(json.utf8))
        #expect(state.shop.levels == ["better_supplier": 2])
        #expect(state.shop.purchasesToday.isEmpty)
        #expect(state.shop.skins.isEmpty)
        #expect(state.offers.everOpened == ["bienvenida"])
        #expect(state.offers.active.isEmpty)
        #expect(state.offers.seenPrestigeLevel == nil, "sin línea de base: la toma el motor la primera vez")
    }

    @Test("ida y vuelta, adentro del save entero")
    func roundTripInsideTheSave() throws {
        var player = fxState()
        player.meta.engagement.shop = ShopState(
            day: "2026-10-07", purchasesToday: ["income_x2": 2], levels: ["wheel_spins": 1],
            pendingOfflineMultiplier: 3, pendingDailyMultiplier: nil, skins: ["neon"]
        )
        player.meta.engagement.offers = OffersState(
            active: [ActiveOffer(id: "renacer", openedAt: 100, expiresAt: 86_500, presented: false)],
            lastClosedAt: ["mudanza": 50], everOpened: ["renacer", "mudanza"], purchases: ["mudanza": 1],
            seenPrestigeLevel: 2, seenUnlockedFloors: 3
        )
        player.meta.engagement.firstLaunchDay = "2026-10-06"
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(player))
        #expect(decoded.meta.engagement == player.meta.engagement)
    }

    @Test("otro día: los topes vuelven a cero y lo demás queda")
    func anotherDayResetsTheCaps() {
        let shop = ShopState(day: "2026-10-07", purchasesToday: ["income_x2": 3], levels: ["better_supplier": 1],
                             pendingOfflineMultiplier: 3)
        let tomorrow = shop.on(day: "2026-10-08")
        #expect(tomorrow.day == "2026-10-08")
        #expect(tomorrow.purchasesToday.isEmpty)
        #expect(tomorrow.levels == ["better_supplier": 1])
        #expect(tomorrow.pendingOfflineMultiplier == 3, "lo comprado espera su offline, no vence con el día")
        #expect(shop.on(day: "2026-10-07") == shop)
    }

    @Test("al resolver un conflicto, lo comprado no retrocede")
    func resolveKeepsWhatWasBought() {
        let winner = ShopState(day: "2026-10-07", purchasesToday: ["income_x2": 1], levels: ["better_supplier": 1],
                               pendingOfflineMultiplier: nil, pendingDailyMultiplier: 3, skins: ["neon"])
        let loser = ShopState(day: "2026-10-07", purchasesToday: ["income_x2": 2, "merge_all": 1],
                              levels: ["better_supplier": 2, "wheel_spins": 1], pendingOfflineMultiplier: 3,
                              skins: ["pijama"])
        let resolved = ShopState.resolve(winner: winner, loser: loser)
        #expect(resolved.levels == ["better_supplier": 2, "wheel_spins": 1])
        #expect(resolved.skins == ["neon", "pijama"])
        #expect(resolved.pendingOfflineMultiplier == 3)
        #expect(resolved.pendingDailyMultiplier == 3)
        #expect(resolved.purchasesToday == ["income_x2": 2, "merge_all": 1], "dos dispositivos no duplican el cupo")
    }

    @Test("el cupo de otro día no cuenta")
    func resolveIgnoresAnotherDaysCaps() {
        let winner = ShopState(day: "2026-10-08", purchasesToday: ["income_x2": 1])
        let loser = ShopState(day: "2026-10-07", purchasesToday: ["income_x2": 3])
        #expect(ShopState.resolve(winner: winner, loser: loser).purchasesToday == ["income_x2": 1])
    }

    @Test("ofertas: las abiertas viajan con el ganador; lo usado y lo comprado, unidos")
    func resolveOffers() {
        let winner = OffersState(
            active: [ActiveOffer(id: "renacer", openedAt: 10, expiresAt: 100, presented: true)],
            lastClosedAt: ["mudanza": 5], everOpened: ["renacer"], purchases: [:],
            seenPrestigeLevel: 3, seenUnlockedFloors: 2
        )
        let loser = OffersState(
            active: [], lastClosedAt: ["mudanza": 50, "renacer": 7], everOpened: ["bienvenida"],
            purchases: ["bienvenida": 1], seenPrestigeLevel: 1, seenUnlockedFloors: 5
        )
        let resolved = OffersState.resolve(winner: winner, loser: loser)
        #expect(resolved.active == winner.active)
        #expect(resolved.lastClosedAt == ["mudanza": 50, "renacer": 7])
        #expect(resolved.everOpened == ["renacer", "bienvenida"], "la de una vez no vuelve por el otro dispositivo")
        #expect(resolved.purchases == ["bienvenida": 1])
        #expect(resolved.seenPrestigeLevel == 3)
        #expect(resolved.seenUnlockedFloors == 2)
    }

    @Test("el primer día es el más viejo de los dos")
    func resolveFirstLaunchDay() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.firstLaunchDay = "2026-10-08"
        loser.firstLaunchDay = "2026-10-06"
        #expect(EngagementState.resolve(winner: winner, loser: loser).firstLaunchDay == "2026-10-06")
        loser.firstLaunchDay = nil
        #expect(EngagementState.resolve(winner: winner, loser: loser).firstLaunchDay == "2026-10-08")
    }

    @Test("EngagementState.resolve usa las reglas de la tienda y de las ofertas")
    func engagementResolveDelegates() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.shop = ShopState(levels: ["wheel_spins": 1])
        loser.shop = ShopState(levels: ["wheel_spins": 3])
        loser.offers = OffersState(everOpened: ["bienvenida"])
        let resolved = EngagementState.resolve(winner: winner, loser: loser)
        #expect(resolved.shop.levels == ["wheel_spins": 3])
        #expect(resolved.offers.everOpened == ["bienvenida"])
    }

    @Test("una oferta que el otro dispositivo ya compró no sigue abierta ni se cobra dos veces")
    func resolveDropsAnOfferBoughtElsewhere() {
        let open = ActiveOffer(id: "mudanza", openedAt: 10, expiresAt: 100, presented: true)
        let winner = OffersState(active: [open], everOpened: ["mudanza"])
        let loser = OffersState(lastClosedAt: ["mudanza": 40], everOpened: ["mudanza"], purchases: ["mudanza": 1])
        let resolved = OffersState.resolve(winner: winner, loser: loser)
        #expect(resolved.active.isEmpty)
        #expect(resolved.purchases == ["mudanza": 1])
        #expect(resolved.lastClosedAt == ["mudanza": 40])
    }

    @Test("el cierre de una apertura anterior no cierra la oferta que se volvió a abrir")
    func resolveKeepsAReopenedOffer() {
        let reopened = ActiveOffer(id: "mudanza", openedAt: 500, expiresAt: 900, presented: false)
        let winner = OffersState(active: [reopened], lastClosedAt: ["mudanza": 100], purchases: ["mudanza": 1])
        let loser = OffersState(lastClosedAt: ["mudanza": 100], purchases: ["mudanza": 1])
        #expect(OffersState.resolve(winner: winner, loser: loser).active == [reopened])
    }

    @Test("con los dos ×3 pendientes, gana el mayor y no se suman")
    func resolveDoesNotStackPendingMultipliers() {
        let winner = ShopState(pendingOfflineMultiplier: 3)
        let loser = ShopState(pendingOfflineMultiplier: 3)
        #expect(ShopState.resolve(winner: winner, loser: loser).pendingOfflineMultiplier == 3)
    }

    @Test("resolver no pierde los campos de las épicas anteriores")
    func resolveKeepsTheOtherEngagementFields() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.seenCinematics = ["dios": 1]
        loser.seenCinematics = ["dios": 2]
        loser.sharedMoments = ["first"]
        loser.shop = ShopState(skins: ["neon"])
        let resolved = EngagementState.resolve(winner: winner, loser: loser)
        #expect(resolved.seenCinematics == ["dios": 2])
        #expect(resolved.sharedMoments == ["first"])
        #expect(resolved.shop.skins == ["neon"])
    }
}
