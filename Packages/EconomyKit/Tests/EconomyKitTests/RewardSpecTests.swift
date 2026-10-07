import Foundation
import Testing
@testable import EconomyKit

@Suite("RewardSpec: el vocabulario de premios")
struct RewardSpecTests {
    /// Un ejemplo por tipo, con un `switch` SIN `default`: un tipo nuevo sin
    /// ejemplo no compila, así que nunca queda uno sin ida y vuelta por JSON.
    static func sample(_ kind: RewardSpec.Kind) -> RewardSpec {
        switch kind {
        case .coinsSeconds: .coinsSeconds(900)
        case .oro: .oro(3)
        case .package: .package(1)
        case .skinChest: .skinChest(1)
        case .modifier: .modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 600)
        case .clearBoostCooldowns: .clearBoostCooldowns
        case .autoTap: .autoTap(perSecond: 5, seconds: 600)
        case .nextOfflineMultiplier: .nextOfflineMultiplier(3)
        case .nextDailyMultiplier: .nextDailyMultiplier(3)
        case .wheelSpin: .wheelSpin(1)
        case .extraSlots: .extraSlots(3)
        case .eventImmunity: .eventImmunity(seconds: 1800)
        }
    }

    @Test("todo tipo va y vuelve por JSON", arguments: RewardSpec.Kind.allCases)
    func roundTrip(kind: RewardSpec.Kind) throws {
        let spec = Self.sample(kind)
        let decoded = try JSONDecoder().decode(RewardSpec.self, from: JSONEncoder().encode(spec))
        #expect(decoded == spec)
        #expect(decoded.kind == kind)
    }

    @Test("se lee la forma que escriben los JSON del juego")
    func decodesTheDataShape() throws {
        let json = """
        [
          {"kind": "coinsSeconds", "seconds": 900},
          {"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 0.7, "seconds": 90},
          {"kind": "package", "count": 1},
          {"kind": "oro", "amount": 1},
          {"kind": "clearBoostCooldowns"}
        ]
        """
        let specs = try JSONDecoder().decode([RewardSpec].self, from: Data(json.utf8))
        #expect(specs == [
            .coinsSeconds(900),
            .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 90),
            .package(1),
            .oro(1),
            .clearBoostCooldowns,
        ])
    }

    @Test("un tipo desconocido no se adivina: el archivo entero no carga")
    func unknownKindFails() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RewardSpec.self, from: Data(#"{"kind": "jackpot", "count": 1}"#.utf8))
        }
    }

    @Test("el ×2 con video: lo contable se duplica y lo que dura, dura el doble")
    func videoDoublesAmountsAndDurations() {
        #expect(RewardSpec.coinsSeconds(900).scaled(by: 2) == .coinsSeconds(1800))
        #expect(RewardSpec.package(1).scaled(by: 2) == .package(2))
        #expect(RewardSpec.oro(1).scaled(by: 2) == .oro(2))
        #expect(RewardSpec.wheelSpin(1).scaled(by: 2) == .wheelSpin(2))
        // Un −30 % al doble sería un −60 % que nadie diseñó: lo que crece es el tiempo.
        #expect(RewardSpec.modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 60).scaled(by: 2)
                == .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 120))
        #expect(RewardSpec.eventImmunity(seconds: 1800).scaled(by: 2) == .eventImmunity(seconds: 3600))
    }

    @Test("lo que no es una cantidad no se duplica")
    func nonQuantitiesStayTheSame() {
        for spec in [RewardSpec.clearBoostCooldowns, .nextOfflineMultiplier(3), .nextDailyMultiplier(3), .extraSlots(3)] {
            #expect(spec.scaled(by: 2) == spec)
        }
    }

    @Test("validar rechaza premios vacíos y modificadores neutros")
    func validationRejectsEmptyRewards() {
        #expect(throws: RewardSpec.ValidationError.notPositive(.coinsSeconds)) { try RewardSpec.coinsSeconds(0).validate() }
        #expect(throws: RewardSpec.ValidationError.notPositive(.package)) { try RewardSpec.package(0).validate() }
        #expect(throws: RewardSpec.ValidationError.notPositive(.modifier)) {
            try RewardSpec.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 0).validate()
        }
        #expect(throws: RewardSpec.ValidationError.neutralModifier) {
            try RewardSpec.modifier(effect: .incomeMultiplier, magnitude: 1, seconds: 60).validate()
        }
        #expect(throws: RewardSpec.ValidationError.notPositive(.nextOfflineMultiplier)) {
            try RewardSpec.nextOfflineMultiplier(1).validate()
        }
        for kind in RewardSpec.Kind.allCases {
            #expect(throws: Never.self) { try Self.sample(kind).validate() }
        }
    }
}
