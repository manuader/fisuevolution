import Foundation
import Testing
@testable import EconomyKit

func fxScript(
    _ id: String,
    visitor: String = "npc_turista",
    lane: VisitorsConfig.Lane = .main,
    weight: Int = 10,
    minTier: Int = 1,
    dailyCap: Int = 3,
    eventOnly: Bool = false,
    mechanic: VisitorsConfig.Mechanic
) -> VisitorsConfig.Script {
    VisitorsConfig.Script(id: id, visitor: visitor, lane: lane, weight: weight, minTier: minTier,
                          dailyCap: dailyCap, eventOnly: eventOnly, mechanic: mechanic)
}

/// Visitantes sintéticos: dos de la calle, un especial y el vendedor.
func fxVisitors(scripts: [VisitorsConfig.Script]? = nil, antiRepeat: Int = 1, coinsSecondsScale: Double = 1) -> VisitorsConfig {
    VisitorsConfig(
        schemaVersion: 1,
        firstVisitAfterSeconds: 600,
        intervalMinSeconds: 240,
        intervalMaxSeconds: 360,
        vendorIntervalSeconds: 180,
        vendorJitterSeconds: 30,
        retryWhenNoneSeconds: 30,
        patienceSeconds: 30,
        presenterTalkSeconds: 4,
        antiRepeat: antiRepeat,
        coinsSecondsScale: coinsSecondsScale,
        visitors: [
            .init(id: "npc_turista", kind: .npc, nameKey: "visitor.npc_turista.name", fallbackSymbol: "camera.fill", fallbackTint: "PaletteGreen"),
            .init(id: "npc_comisario", kind: .npc, nameKey: "visitor.npc_comisario.name", fallbackSymbol: "figure.stand", fallbackTint: "PaletteBlue"),
            .init(id: "npc_vendedor", kind: .npc, nameKey: "visitor.npc_vendedor.name", fallbackSymbol: "cart.fill", fallbackTint: "PaletteOrange"),
            .init(id: "sp_cryptobro", kind: .special, nameKey: "special.cryptobro.name", fallbackSymbol: "chart.line.uptrend.xyaxis", fallbackTint: "PaletteOrange"),
        ],
        scripts: scripts ?? [
            fxScript("propina", mechanic: .gift(rewards: [.coinsSeconds(900)], videoDoubles: true)),
            fxScript("subsidio", mechanic: .gift(rewards: [.coinsSeconds(1200)], videoDoubles: true)),
            fxScript("senal", visitor: "sp_cryptobro",
                     mechanic: .gift(rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 60)], videoDoubles: true)),
            fxScript("bolson", mechanic: .gift(rewards: [.package(1)], videoDoubles: true)),
            fxScript("arresto", visitor: "npc_comisario", minTier: 3,
                     mechanic: .arrest(pick: .lowestDuplicate, bailMultiplier: 1, releaseMultiplier: 2)),
            fxScript("ofertas", visitor: "npc_vendedor", lane: .vendor, dailyCap: 20, mechanic: .vendor(cards: [
                .init(id: "mate", nameKey: "boost.mate.name", iconKey: "ui_boost_mate",
                      reward: .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 90)),
            ])),
            fxScript("blue", visitor: "sp_cryptobro", eventOnly: true,
                     mechanic: .exchange(costSeconds: 3600, oro: 1, dailyOroCap: nil)),
        ]
    )
}

private let everything = Set(RewardSpec.Kind.allCases)

@Suite("Visitantes: el config")
struct VisitorsConfigTests {
    @Test("se lee la forma del JSON del juego, una mecánica de cada una")
    func decodesEveryMechanic() throws {
        let json = """
        {"schemaVersion": 1, "firstVisitAfterSeconds": 600, "intervalMinSeconds": 240, "intervalMaxSeconds": 360,
         "vendorIntervalSeconds": 180, "vendorJitterSeconds": 30, "retryWhenNoneSeconds": 30, "patienceSeconds": 30,
         "presenterTalkSeconds": 4, "antiRepeat": 3, "coinsSecondsScale": 1,
         "visitors": [{"id": "npc_comisario", "kind": "npc", "nameKey": "visitor.npc_comisario.name",
                       "fallbackSymbol": "figure.stand", "fallbackTint": "PaletteBlue"}],
         "scripts": [
          {"id": "g", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "gift", "rewards": [{"kind": "coinsSeconds", "seconds": 900}], "videoDoubles": true}},
          {"id": "a", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "arrest", "pick": "lowestDuplicate", "bailMultiplier": 1, "releaseMultiplier": 2}},
          {"id": "f", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "fine", "seconds": 180, "capFraction": 0.08,
                        "stamp": {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 1.25, "seconds": 180}}},
          {"id": "e", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1, "eventOnly": true,
           "mechanic": {"kind": "exchange", "costSeconds": 3600, "oro": 1}},
          {"id": "s", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "sale", "pick": "highestDuplicate", "priceMultiplier": 4, "tiersBelowFrontier": 2}},
          {"id": "t", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "take", "pick": "lowestDuplicate", "count": 3, "minValueMultiplier": 1.5,
                        "rewards": [{"kind": "package", "count": 1}, {"kind": "coinsSeconds", "seconds": 600}]}},
          {"id": "c", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "challenge", "taps": 40, "windowSeconds": 30,
                        "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 90}]}},
          {"id": "v", "visitor": "npc_comisario", "lane": "vendor", "weight": 1, "minTier": 1, "dailyCap": 9,
           "mechanic": {"kind": "vendor", "cards": [{"id": "mate", "nameKey": "boost.mate.name", "iconKey": "ui_boost_mate",
                        "reward": {"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 0.7, "seconds": 90}}]}},
          {"id": "o", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "gossip", "rewards": [{"kind": "coinsSeconds", "seconds": 300}]}}
         ]}
        """
        let config = try JSONDecoder().decode(VisitorsConfig.self, from: Data(json.utf8))
        try config.validate()
        #expect(config.script(id: "g")?.lane == .main, "sin carril, el principal")
        #expect(config.script(id: "g")?.eventOnly == false)
        #expect(config.script(id: "e")?.eventOnly == true)
        #expect(config.script(id: "e")?.mechanic == .exchange(costSeconds: 3600, oro: 1, dailyOroCap: nil))
        #expect(config.script(id: "c")?.mechanic == .challenge(
            taps: 40, windowSeconds: 30,
            rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 90)], videoDoubles: false
        ))
        #expect(config.script(id: "t")?.mechanic.rewards == [.package(1), .coinsSeconds(600)])
        #expect(config.script(id: "a")?.mechanic.rewards.isEmpty == true)
        #expect(config.script(id: "o")?.bubbleKey == "visit.o.bubble")
        #expect(try JSONDecoder().decode(VisitorsConfig.self, from: JSONEncoder().encode(config)) == config)
    }

    private func reject(_ script: VisitorsConfig.Script) {
        #expect(throws: VisitorsConfig.ValidationError.self) { try fxVisitors(scripts: [script]).validate() }
    }

    @Test("el validador frena lo que el juego no puede cumplir")
    func validationRejectsBrokenScripts() {
        // El arresto siempre indemniza más de lo que cuesta reponer (PLAN-v2 E4).
        reject(fxScript("a", mechanic: .arrest(pick: .lowestDuplicate, bailMultiplier: 1, releaseMultiplier: 1)))
        reject(fxScript("b", mechanic: .vendor(cards: [])))
        reject(fxScript("c", lane: .vendor, mechanic: .gift(rewards: [.coinsSeconds(1)], videoDoubles: false)))
        reject(fxScript("d", visitor: "npc_nadie", mechanic: .gift(rewards: [.coinsSeconds(1)], videoDoubles: false)))
        reject(fxScript("e", mechanic: .take(pick: .lowestDuplicate, count: 1, rewards: [.coinsSeconds(1)], minValueMultiplier: 0.9)))
        reject(fxScript("f", mechanic: .sale(pick: .highestDuplicate, priceMultiplier: 1, tiersBelowFrontier: 2)))
        reject(fxScript("g", mechanic: .gift(rewards: [.coinsSeconds(0)], videoDoubles: false)))
        reject(fxScript("h", mechanic: .fine(seconds: 180, capFraction: 1.5,
                                             stamp: .modifier(effect: .incomeMultiplier, magnitude: 1.25, seconds: 180))))
        reject(fxScript("i", mechanic: .challenge(taps: 0, windowSeconds: 30, rewards: [.coinsSeconds(1)], videoDoubles: false)))
    }

    @Test("el id de un visitante es su id de arte: npc_ para los nuevos, sp_ para los especiales")
    func visitorIdsFollowTheArtConvention() {
        let config = VisitorsConfig(
            schemaVersion: 1, firstVisitAfterSeconds: 600, intervalMinSeconds: 240, intervalMaxSeconds: 360,
            vendorIntervalSeconds: 180, vendorJitterSeconds: 30, retryWhenNoneSeconds: 30, patienceSeconds: 30,
            presenterTalkSeconds: 4, antiRepeat: 1, coinsSecondsScale: 1,
            visitors: [.init(id: "comisario", kind: .npc, nameKey: "x", fallbackSymbol: "x", fallbackTint: "x")],
            scripts: []
        )
        #expect(throws: VisitorsConfig.ValidationError.self) { try config.validate() }
    }

    @Test("el fixture es válido")
    func fixtureIsValid() throws {
        try fxVisitors().validate()
    }
}

@Suite("Visitantes: los dos carriles")
struct VisitorSchedulerTests {
    let config = fxVisitors()
    let context = VisitContext(maxTier: 5, ownedSpecials: [], grantable: [.coinsSeconds, .oro, .modifier])

    private func play(_ state: inout VisitorsState, seconds: Int, rng: inout SeededRNG) -> VisitorsConfig.Lane? {
        var lane: VisitorsConfig.Lane?
        for _ in 0..<seconds {
            lane = VisitorScheduler.advance(&state, delta: 1, config: config, rng: &rng) ?? lane
        }
        return lane
    }

    @Test("la primera visita llega a los 600 s de juego, no antes")
    func firstVisit() {
        var state = VisitorsState.initial
        var rng = SeededRNG(seed: 1)
        #expect(play(&state, seconds: 599, rng: &rng) == nil)
        #expect(play(&state, seconds: 1, rng: &rng) == .main)
    }

    @Test("un salto grande del tick no cuenta")
    func clampedDelta() {
        var state = VisitorsState.initial
        var rng = SeededRNG(seed: 1)
        #expect(VisitorScheduler.advance(&state, delta: 3600, config: config, rng: &rng) == nil)
        #expect(state.secondsUntilVisit == 600 - IncomeTicker.deltaClampThreshold)
    }

    @Test("después de una visita, la próxima entre 240 y 360 s")
    func nextVisitInterval() throws {
        var rng = SeededRNG(seed: 4)
        for _ in 0..<50 {
            var state = VisitorsState(secondsUntilVisit: 0)
            VisitorScheduler.markVisited(try #require(config.script(id: "propina")), state: &state, config: config, rng: &rng)
            let next = try #require(state.secondsUntilVisit)
            #expect(next >= 240 && next <= 360)
        }
    }

    @Test("el vendedor tiene su carril: cada 180 s ± 30")
    func vendorLane() throws {
        var rng = SeededRNG(seed: 5)
        for _ in 0..<50 {
            var state = VisitorsState(secondsUntilVisit: 999, secondsUntilVendor: 0)
            VisitorScheduler.markVisited(try #require(config.script(id: "ofertas")), state: &state, config: config, rng: &rng)
            let next = try #require(state.secondsUntilVendor)
            #expect(next >= 150 && next <= 210)
            #expect(state.secondsUntilVisit == 999, "un carril no mueve al otro")
        }
    }

    @Test("si vencen los dos, primero el principal")
    func mainBeatsVendor() {
        var state = VisitorsState(secondsUntilVisit: 0.5, secondsUntilVendor: 0.5)
        var rng = SeededRNG(seed: 1)
        #expect(VisitorScheduler.advance(&state, delta: 1, config: config, rng: &rng) == .main)
    }

    @Test("elegibles: carril, tier, tope, especiales conseguidos y premios entregables")
    func eligibility() {
        let ids = VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: context) { _ in true }.map(\.id)
        #expect(Set(ids) == ["propina", "subsidio", "arresto"], "sin el especial, sin paquetes y sin lo que llama un evento")
        let withSpecial = VisitContext(maxTier: 2, ownedSpecials: ["sp_cryptobro"], grantable: context.grantable)
        #expect(Set(VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: withSpecial) { _ in true }.map(\.id))
                == ["propina", "subsidio", "senal"], "el arresto pide tier 3")
        let capped = VisitorsState(day: "d", visitsToday: ["propina": 3])
        #expect(!VisitorScheduler.eligible(lane: .main, config: config, state: capped, context: context) { _ in true }
            .map(\.id).contains("propina"))
        #expect(VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: context) { $0.id == "subsidio" }
            .map(\.id) == ["subsidio"], "lo que no tiene oferta posible no viene")
        #expect(VisitorScheduler.eligible(lane: .vendor, config: config, state: .initial, context: context) { _ in true }
            .map(\.id) == ["ofertas"])
    }

    @Test("anti-repetición: el último no vuelve si hay otro; si es el único, sí")
    func antiRepeat() throws {
        let recent = VisitorsState(recentScripts: ["propina"])
        let ids = VisitorScheduler.eligible(lane: .main, config: config, state: recent, context: context) { _ in true }.map(\.id)
        #expect(!ids.contains("propina"))
        let only = VisitorScheduler.eligible(lane: .main, config: config, state: recent, context: context) { $0.id == "propina" }
        #expect(only.map(\.id) == ["propina"])
    }

    @Test("lo que llama un evento no sale en el sorteo, pero sí cuando lo llaman")
    func eventOnlyScripts() throws {
        let blue = try #require(config.script(id: "blue"))
        #expect(!VisitorScheduler.isAvailable(blue, config: config, state: .initial, context: context) { _ in true },
                "el especial no está conseguido")
        let owned = VisitContext(maxTier: 5, ownedSpecials: ["sp_cryptobro"], grantable: context.grantable)
        #expect(VisitorScheduler.isAvailable(blue, config: config, state: .initial, context: owned) { _ in true })
        #expect(!VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: owned) { _ in true }
            .map(\.id).contains("blue"))
    }

    @Test("el sorteo sale de los elegibles y respeta los pesos")
    func pick() {
        var rng = SeededRNG(seed: 11)
        var seen: Set<String> = []
        for _ in 0..<200 {
            if let script = VisitorScheduler.pickNext(lane: .main, config: config, state: .initial, context: context,
                                                      isOfferable: { _ in true }, rng: &rng) {
                seen.insert(script.id)
            }
        }
        #expect(seen == ["propina", "subsidio", "arresto"])
    }

    @Test("visitar anota el guion, cuenta el día y recorta la memoria")
    func markVisitedBookkeeping() throws {
        var state = VisitorsState(day: "d")
        var rng = SeededRNG(seed: 2)
        let propina = try #require(config.script(id: "propina"))
        for _ in 0..<5 { VisitorScheduler.markVisited(propina, state: &state, config: config, rng: &rng) }
        #expect(state.visitsToday["propina"] == 5)
        #expect(state.recentScripts.count <= max(config.antiRepeat, 1) * 2)
        #expect(state.recentScripts.last == "propina")
    }

    @Test("el día nuevo resetea los topes; el mismo día no")
    func rollDay() {
        var state = VisitorsState(day: "2026-10-07", visitsToday: ["a": 2], oroExchangedToday: 3)
        VisitorScheduler.rollDay(&state, today: "2026-10-07")
        #expect(state.visitsToday == ["a": 2])
        VisitorScheduler.rollDay(&state, today: "2026-10-08")
        #expect(state.visitsToday.isEmpty)
        #expect(state.oroExchangedToday == 0)
        #expect(state.day == "2026-10-08")
    }

    @Test("un carril sin nadie para mandar reintenta pronto")
    func retrySoon() {
        var state = VisitorsState(secondsUntilVisit: -1, secondsUntilVendor: -1)
        VisitorScheduler.retrySoon(lane: .vendor, state: &state, config: config)
        #expect(state.secondsUntilVendor == 30)
        #expect(state.secondsUntilVisit == -1)
    }

    @Test("con todo entregable, todo guion del fixture sale por su carril")
    func everythingGrantable() {
        let all = VisitContext(maxTier: 9, ownedSpecials: ["sp_cryptobro"], grantable: everything)
        let main = VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: all) { _ in true }.map(\.id)
        #expect(Set(main) == ["propina", "subsidio", "senal", "bolson", "arresto"])
    }
}
