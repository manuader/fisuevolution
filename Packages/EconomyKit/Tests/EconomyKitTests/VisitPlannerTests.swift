import Foundation
import Testing
@testable import EconomyKit

@Suite("Visitantes: la oferta, cotizada al llegar")
struct VisitPlannerTests {
    let tiers: TierRepository
    let economy = fxConfig()
    let valuation = VisitValuation(coinsPerSecond: 10)

    init() throws {
        tiers = try fxTiers()
    }

    /// Pisos de 10 lugares: con los de 5 del fixture, siete unidades en `f1` se
    /// auto-fusionarían al reconciliar y el test mediría otra torre.
    private func world(_ units: [String: Int], frontier: Int = 1, coins: Double = 1_000_000) throws
        -> (state: PlayerState, tower: TowerState, floorTable: FloorTable) {
        var fx = try fxStateAndTower(units: units, config: fxConfig(capacity: 10))
        fx.state.run.raiseFrontier(to: frontier)
        fx.state.run.coins = coins
        return fx
    }

    private func plan(
        _ mechanic: VisitorsConfig.Mechanic,
        in fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable),
        config: VisitorsConfig = fxVisitors()
    ) -> VisitOffer? {
        VisitPlanner.offer(fxScript("x", mechanic: mechanic), config: config, state: fx.state, tower: fx.tower,
                           tiers: tiers, floorTable: fx.floorTable, economy: economy, valuation: valuation)
    }

    private func replacement(_ typeId: String, in fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable)) throws -> Double {
        try #require(TowerActions.hireQuote(typeId: typeId, state: fx.state, config: economy,
                                            floorTable: fx.floorTable, tiers: tiers)).cost
    }

    private let arrest = VisitorsConfig.Mechanic.arrest(pick: .lowestDuplicate, bailMultiplier: 1, releaseMultiplier: 2)

    @Test("un regalo cotiza sus segundos al llegar y el video duplica plata y duración")
    func giftIsPricedOnArrival() throws {
        let gift = VisitorsConfig.Mechanic.gift(
            rewards: [.coinsSeconds(900), .modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 600)], videoDoubles: true
        )
        let offer = try #require(plan(gift, in: try world(["a": 1])))
        let accept = try #require(offer.option(id: "accept"))
        let video = try #require(offer.option(id: "video"))
        #expect(accept.coins == 9000)
        #expect(accept.rewards == [.modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 600)])
        #expect(!accept.requiresVideo)
        #expect(video.coins == 18000)
        #expect(video.requiresVideo)
        #expect(video.rewards == [.modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 1200)])
    }

    @Test("la escala del config mueve toda la plata de los guiones (la palanca de E2b)")
    func coinsScale() throws {
        let gift = VisitorsConfig.Mechanic.gift(rewards: [.coinsSeconds(900)], videoDoubles: false)
        let offer = try #require(plan(gift, in: try world(["a": 1]), config: fxVisitors(coinsSecondsScale: 0.5)))
        #expect(offer.option(id: "accept")?.coins == 4500)
        #expect(offer.option(id: "video") == nil)
    }

    @Test("el arresto se lleva un duplicado del tier más bajo y siempre indemniza más de lo que cuesta reponerlo")
    func arrestAlwaysCompensates() throws {
        let fx = try world(["a": 3, "b": 2])
        let offer = try #require(plan(arrest, in: fx))
        let price = try replacement("a", in: fx)
        #expect(offer.subjectTypeId == "a")
        let bail = try #require(offer.option(id: "bail"))
        let release = try #require(offer.option(id: "release"))
        #expect(bail.coins == -price)
        #expect(bail.departures.isEmpty, "pagar la fianza no se lleva a nadie")
        #expect(release.coins > price)
        #expect(release.departures.count == 1)
        #expect(release.departures.first?.origin == .visitor)
        guard case .departure(_, _, let typeId)? = release.departures.first?.kind else {
            Issue.record("la salida no es una departure")
            return
        }
        #expect(typeId == "a")
    }

    @Test("nunca se lleva al último de su tipo ni deja la torre con menos de dos")
    func neverTakesTheLastOne() throws {
        #expect(plan(arrest, in: try world(["a": 1, "b": 1])) == nil, "sin duplicados no hay arresto")
        #expect(plan(arrest, in: try world(["a": 2])) == nil, "dejaría un solo empleado en la torre")
        let take = VisitorsConfig.Mechanic.take(pick: .lowestDuplicate, count: 3, rewards: [.coinsSeconds(600)], minValueMultiplier: 1.5)
        #expect(plan(take, in: try world(["a": 3, "b": 2])) == nil, "se llevaría a todos los de su tipo")
        let fine = try #require(plan(take, in: try world(["a": 4, "b": 1])))
        #expect(fine.option(id: "accept")?.departures.count == 3)
        #expect(Set(fine.option(id: "accept")?.departures.map(\.id) ?? []).count == 3)
    }

    @Test("lo que se lleva gente paga por lo menos lo que cuesta reponerla")
    func takingPaysAtLeastTheReplacement() throws {
        let fx = try world(["a": 5])
        let take = VisitorsConfig.Mechanic.take(pick: .lowestDuplicate, count: 3, rewards: [.coinsSeconds(1), .package(1)], minValueMultiplier: 1.5)
        let accept = try #require(plan(take, in: fx)?.option(id: "accept"))
        #expect(accept.coins >= 1.5 * 3 * (try replacement("a", in: fx)))
        #expect(accept.rewards == [.package(1)])
    }

    @Test("el turista compra el duplicado más alto que respeta su distancia a la frontera, a su múltiplo del precio")
    func saleRespectsTheFrontier() throws {
        let fx = try world(["a": 3, "b": 2, "d": 1], frontier: 4)
        let sale = VisitorsConfig.Mechanic.sale(pick: .highestDuplicate, priceMultiplier: 4, tiersBelowFrontier: 2)
        let offer = try #require(plan(sale, in: fx))
        #expect(offer.subjectTypeId == "b")
        #expect(offer.option(id: "sell")?.coins == 4 * (try replacement("b", in: fx)))
        #expect(plan(sale, in: try world(["a": 3, "b": 2], frontier: 3))?.subjectTypeId == "a")
        #expect(plan(sale, in: try world(["a": 3, "b": 2], frontier: 2)) == nil, "nada a dos tiers de la frontera")
    }

    @Test("la multa topea en su fracción de la caja; sin caja no hay multa; el video la perdona")
    func fineIsCapped() throws {
        let stamp = RewardSpec.modifier(effect: .incomeMultiplier, magnitude: 1.25, seconds: 180)
        let fine = VisitorsConfig.Mechanic.fine(seconds: 180, capFraction: 0.08, stamp: stamp)
        let capped = try #require(plan(fine, in: try world(["a": 1], coins: 1000)))
        #expect(capped.option(id: "pay")?.coins == -80)
        #expect(capped.option(id: "pay")?.rewards == [stamp])
        #expect(capped.option(id: "video")?.coins == 0)
        #expect(capped.option(id: "video")?.requiresVideo == true)
        #expect(plan(fine, in: try world(["a": 1], coins: 0)) == nil)
    }

    @Test("el cambio cotiza su costo y respeta el tope del día")
    func exchangeCap() throws {
        var fx = try world(["a": 1])
        let exchange = VisitorsConfig.Mechanic.exchange(costSeconds: 5400, oro: 1, dailyOroCap: 3)
        let open = try #require(plan(exchange, in: fx)?.option(id: "exchange"))
        #expect(open.coins == -54000)
        #expect(open.rewards == [.oro(1)])
        fx.state.meta.engagement.visitors.oroExchangedToday = 3
        #expect(plan(exchange, in: fx) == nil)
        let blue = VisitorsConfig.Mechanic.exchange(costSeconds: 3600, oro: 1, dailyOroCap: nil)
        #expect(plan(blue, in: fx) != nil, "el blue no tiene tope")
    }

    @Test("el reto, el vendedor y el chisme")
    func otherMechanics() throws {
        let fx = try world(["a": 1])
        let challenge = VisitorsConfig.Mechanic.challenge(
            taps: 40, windowSeconds: 30, rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 90)], videoDoubles: false
        )
        let terms = try #require(plan(challenge, in: fx)?.option(id: "challenge")?.challenge)
        #expect(terms.taps == 40 && terms.windowSeconds == 30)
        #expect(terms.rewards == [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 90)])
        let card = VisitorsConfig.VendorCard(id: "mate", nameKey: "boost.mate.name", iconKey: "ui_boost_mate",
                                             reward: .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 90))
        let vendor = try #require(plan(.vendor(cards: [card]), in: fx))
        #expect(vendor.options.map(\.id) == ["card.mate"])
        #expect(vendor.options.allSatisfy { $0.requiresVideo })
        #expect(plan(.gossip(rewards: [.coinsSeconds(300)]), in: fx)?.option(id: "listen")?.coins == 3000)
    }

    @Test("ignorar no cuesta nada: ninguna opción gratis resta, y lo que resta da algo a cambio")
    func everyVisitIsPositiveOrNeutral() throws {
        let fx = try world(["a": 5, "b": 2], frontier: 4)
        let stamp = RewardSpec.modifier(effect: .incomeMultiplier, magnitude: 1.25, seconds: 180)
        let mechanics: [VisitorsConfig.Mechanic] = [
            .gift(rewards: [.coinsSeconds(900)], videoDoubles: true),
            arrest,
            .fine(seconds: 180, capFraction: 0.08, stamp: stamp),
            .exchange(costSeconds: 5400, oro: 1, dailyOroCap: 3),
            .sale(pick: .highestDuplicate, priceMultiplier: 4, tiersBelowFrontier: 2),
            .take(pick: .lowestDuplicate, count: 3, rewards: [.coinsSeconds(600)], minValueMultiplier: 1.5),
            .gossip(rewards: [.coinsSeconds(300)]),
        ]
        for mechanic in mechanics {
            let offer = try #require(plan(mechanic, in: fx))
            for option in offer.options {
                if option.coins < 0 {
                    #expect(!option.rewards.isEmpty || option.kind == .payBail, "\(option.id): resta sin dar nada")
                }
                for change in option.departures {
                    guard case .departure(_, _, let typeId) = change.kind else { continue }
                    #expect(option.coins >= (try replacement(typeId, in: fx)) * Double(option.departures.count),
                            "\(option.id): se lleva gente sin pagarla")
                }
            }
        }
    }

    @Test("aceptar revalida: si el arrestado se movió se replanea; si ya no está, no hay trato")
    func revalidation() throws {
        var fx = try world(["a": 3, "b": 1])
        let release = try #require(plan(arrest, in: fx)?.option(id: "release"))
        guard case let .departure(ordinal, slot, _)? = release.departures.first?.kind else {
            Issue.record("sin salida")
            return
        }
        let free = try #require(fx.tower.floors[ordinal].firstFreeSlot())
        #expect(TowerActions.move(floorOrdinal: ordinal, fromSlot: slot, toSlot: free, tower: &fx.tower))
        let moved = try #require(VisitPlanner.revalidate(release, state: fx.state, tower: fx.tower))
        #expect(moved.departures.first?.id == release.departures.first?.id, "mismo cambio, replaneado")
        #expect(moved != release)
        fx.state.run.units["a"] = 1
        #expect(VisitPlanner.revalidate(release, state: fx.state, tower: fx.tower) == nil)
    }

    @Test("sin plata no se paga la fianza; la salida gratis sigue en pie")
    func bailNeedsTheMoney() throws {
        let fx = try world(["a": 3, "b": 1])
        let offer = try #require(plan(arrest, in: fx))
        var broke = fx
        broke.state.run.coins = 0
        #expect(VisitPlanner.revalidate(try #require(offer.option(id: "bail")), state: broke.state, tower: broke.tower) == nil)
        #expect(VisitPlanner.revalidate(try #require(offer.option(id: "release")), state: broke.state, tower: broke.tower) != nil)
    }
}
