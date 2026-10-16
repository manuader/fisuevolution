import Foundation
import Testing
@testable import EconomyKit

func fxScript(
    _ id: String,
    visitor: String = "npc_turista",
    weight: Int = 10,
    minTier: Int = 1,
    dailyCap: Int = 3,
    eventOnly: Bool = false,
    mechanic: VisitorsConfig.Mechanic,
    weeklyCap: Int? = nil,
    realClock: Bool = false
) -> VisitorsConfig.Script {
    VisitorsConfig.Script(id: id, visitor: visitor, weight: weight, minTier: minTier,
                          dailyCap: dailyCap, eventOnly: eventOnly, mechanic: mechanic,
                          weeklyCap: weeklyCap, realClock: realClock)
}

/// Visitantes sintéticos: dos de la calle, un especial y el vendedor.
func fxVisitors(scripts: [VisitorsConfig.Script]? = nil, coinsSecondsScale: Double = 1) -> VisitorsConfig {
    VisitorsConfig(
        schemaVersion: 1,
        firstVisitAfterSeconds: 600,
        intervalMinSeconds: 240,
        intervalMaxSeconds: 360,
        retryWhenNoneSeconds: 30,
        patienceSeconds: 30,
        presenterTalkSeconds: 4,
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
            fxScript("ofertas", visitor: "npc_vendedor", dailyCap: 2, mechanic: .vendor(cards: [
                .init(id: "mate", nameKey: "boost.mate.name", iconKey: "ui_boost_mate",
                      reward: .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 90)),
            ])),
            fxScript("blue", visitor: "sp_cryptobro", eventOnly: true,
                     mechanic: .exchange(costSeconds: 3600, blue: 1, dailyBlueCap: nil)),
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
           "mechanic": {"kind": "exchange", "costSeconds": 3600, "blue": 1}},
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
        #expect(config.script(id: "g")?.eventOnly == false)
        #expect(config.script(id: "e")?.eventOnly == true)
        #expect(config.script(id: "e")?.mechanic == .exchange(costSeconds: 3600, blue: 1, dailyBlueCap: nil))
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
            retryWhenNoneSeconds: 30, patienceSeconds: 30, presenterTalkSeconds: 4, coinsSecondsScale: 1,
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

