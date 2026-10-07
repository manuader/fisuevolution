import Foundation
import Testing
@testable import EconomyKit

/// `packages.json` sintético, con los números de PLAN-v2 E5.
func fxPackages(
    spawnIntervalSeconds: Double = 120,
    firstPackageAfterSeconds: Double = 120,
    maxWaiting: Int = 2,
    windowTiers: Int = 4,
    ratios: [Double] = [2, 1.8, 1.6, 1.4]
) -> PackagesConfig {
    PackagesConfig(
        schemaVersion: 1,
        spawnIntervalSeconds: spawnIntervalSeconds,
        firstPackageAfterSeconds: firstPackageAfterSeconds,
        maxWaiting: maxWaiting,
        windowTiers: windowTiers,
        tierRatioByBestSupplierLevel: ratios
    )
}

@Suite("Paquete de la Aduana: a quién trae")
struct PackageRollerTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    /// Un tipo por tier, para mirar la ventana sin la torre.
    private func ladder(_ maxTier: Int) -> [CharacterType] {
        (1...maxTier).map { fxType("t\($0)", tier: $0) }
    }

    private func total(_ odds: [PackageRoller.Odds]) -> Double {
        odds.map(\.probability).reduce(0, +)
    }

    private func eligibleIds(
        _ fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable),
        config: EconomyConfig = fxConfig()
    ) -> [String] {
        PackageRoller.eligibleTypes(
            state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, config: config
        ).map(\.id)
    }

    /// `fxConfig` con la compuerta de contratación prendida: la fixture la trae apagada.
    private func gatedConfig(distance: Int) -> EconomyConfig {
        let base = fxConfig()
        return EconomyConfig(
            schemaVersion: base.schemaVersion,
            baseTapYieldTier1: base.baseTapYieldTier1,
            yieldGrowthPerTier: base.yieldGrowthPerTier,
            passiveRatio: base.passiveRatio,
            passiveUnlockCostMultiplier: base.passiveUnlockCostMultiplier,
            hire: .init(
                defaultCostMultiplier: base.hire.defaultCostMultiplier,
                defaultCostGrowth: base.hire.defaultCostGrowth,
                priceGrowthPerTier: base.hire.priceGrowthPerTier,
                gateTierDistance: distance
            ),
            charUpgrades: base.charUpgrades,
            oro: base.oro,
            critChanceBase: base.critChanceBase,
            critMultiplier: base.critMultiplier,
            offlineEfficiencyBase: base.offlineEfficiencyBase,
            offlineCapHours: base.offlineCapHours,
            floors: base.floors
        )
    }

    @Test("con la ventana entera, el tope sale 1 de cada 15 y el de más abajo 8 de cada 15")
    func theTopTierIsOneInFifteen() {
        let odds = PackageRoller.odds(eligible: ladder(4), windowTiers: 4, ratio: 2)
        #expect(odds.map(\.tier) == [4, 3, 2, 1])
        #expect(abs(odds[0].probability - 1.0 / 15) < 1e-12)
        #expect(abs(odds[3].probability - 8.0 / 15) < 1e-12)
        #expect(abs(total(odds) - 1) < 1e-12)
    }

    @Test("sólo entran los cuatro tiers más altos")
    func onlyTheTopFourTiersEnter() {
        let odds = PackageRoller.odds(eligible: ladder(6), windowTiers: 4, ratio: 2)
        #expect(odds.map(\.tier) == [6, 5, 4, 3])
    }

    @Test("con menos tiers la ventana se achica y sigue sumando 1")
    func aShortWindowStillAddsUp() {
        let odds = PackageRoller.odds(eligible: ladder(2), windowTiers: 4, ratio: 2)
        #expect(odds.map(\.tier) == [2, 1])
        #expect(abs(odds[0].probability - 1.0 / 3) < 1e-12)
        #expect(abs(total(odds) - 1) < 1e-12)
    }

    @Test("los tipos de un mismo tier se reparten su parte")
    func typesOfATierShareItsWeight() {
        let eligible = [fxType("y", tier: 3), fxType("x", tier: 3), fxType("z", tier: 2)]
        let odds = PackageRoller.odds(eligible: eligible, windowTiers: 4, ratio: 2)
        #expect(odds.first?.typeIds == ["x", "y"])
    }

    @Test("el mejor proveedor baja r", arguments: zip([0, 1, 2, 3], [2.0, 1.8, 1.6, 1.4]))
    func bestSupplierLowersTheRatio(level: Int, ratio: Double) {
        #expect(fxPackages().tierRatio(bestSupplierLevel: level) == ratio)
    }

    @Test("cada nivel del mejor proveedor sube la chance del tope; un nivel de más se queda en el último")
    func bestSupplierRaisesTheTop() {
        let config = fxPackages()
        let tops = (0...3).map { level in
            let ratio = config.tierRatio(bestSupplierLevel: level)
            return PackageRoller.odds(eligible: ladder(4), windowTiers: 4, ratio: ratio)[0].probability
        }
        #expect(tops == tops.sorted())
        #expect((tops.last ?? 0) > 0.14)
        #expect(config.tierRatio(bestSupplierLevel: 9) == 1.4)
        #expect(config.tierRatio(bestSupplierLevel: -1) == 2)
    }

    @Test("lo que no se vio en esta run no viene")
    func unseenTypesStayOut() throws {
        var fx = try fxStateAndTower(units: ["a": 1])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b"]
        #expect(eligibleIds(fx) == ["a", "b"])
    }

    @Test("un piso lleno saca a los suyos")
    func aFullFloorKeepsItsTypesOut() throws {
        var fx = try fxStateAndTower(units: ["a": 5])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b", "c_prog", "d"]
        #expect(Set(eligibleIds(fx)) == ["c_prog", "d"])
    }

    @Test("un piso cerrado, también")
    func aLockedFloorKeepsItsTypesOut() throws {
        var fx = try fxStateAndTower(units: ["a": 1], unlockedFloors: ["f1"])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b", "c_prog", "d"]
        #expect(Set(eligibleIds(fx)) == ["a", "b"])
    }

    @Test("el nodo de carrera no es un empleado: nunca viene")
    func theChoiceNodeNeverComes() throws {
        var fx = try fxStateAndTower(units: ["a": 1])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b", "choice", "c_prog"]
        #expect(!eligibleIds(fx).contains("choice"))
    }

    @Test("la compuerta de contratación también manda: lo que FisuJobs todavía no vende no viene")
    func theHireGateKeepsTypesOut() throws {
        var fx = try fxStateAndTower(units: ["a": 1])
        fx.state.run.seenTypes = ["a", "b", "c_prog", "d"]
        let gated = gatedConfig(distance: 2)

        fx.state.run.raiseFrontier(to: 4)
        #expect(eligibleIds(fx, config: gated) == ["a", "b"])
        fx.state.run.raiseFrontier(to: 5)
        #expect(eligibleIds(fx, config: gated) == ["a", "b", "c_prog"])
        fx.state.run.raiseFrontier(to: 6)
        #expect(eligibleIds(fx, config: gated) == ["a", "b", "c_prog", "d"])
        #expect(eligibleIds(fx, config: gatedConfig(distance: 0)) == ["a", "b", "c_prog", "d"])
    }

    @Test("sin elegibles no hay sorteo")
    func nothingEligibleRollsNothing() {
        var rng = SeededRNG(seed: 1)
        #expect(PackageRoller.roll(eligible: [], windowTiers: 4, ratio: 2, using: &rng) == nil)
    }

    @Test("los tipos de un mismo tier salen parejo: no siempre el primero")
    func typesOfATierTakeTurns() throws {
        var rng = SeededRNG(seed: 99)
        let eligible = [fxType("y", tier: 3), fxType("x", tier: 3)]
        let draws = 2_000
        var counts: [String: Int] = [:]
        for _ in 0..<draws {
            let pick = try #require(PackageRoller.roll(eligible: eligible, windowTiers: 4, ratio: 2, using: &rng))
            counts[pick.id, default: 0] += 1
        }
        #expect(Set(counts.keys) == ["x", "y"])
        for (id, count) in counts {
            let share = Double(count) / Double(draws)
            #expect(share > 0.45 && share < 0.55, "\(id) salió \(share)")
        }
    }

    @Test("el sorteo respeta la tabla: el tope cae cerca del 6,7 %")
    func theRollFollowsTheTable() throws {
        var rng = SeededRNG(seed: 20_261_007)
        let eligible = ladder(4)
        let draws = 15_000
        var tops = 0
        for _ in 0..<draws {
            let pick = try #require(PackageRoller.roll(eligible: eligible, windowTiers: 4, ratio: 2, using: &rng))
            if pick.tier == 4 { tops += 1 }
        }
        let share = Double(tops) / Double(draws)
        #expect(share > 0.055 && share < 0.078, "el tope salió \(share)")
    }
}

@Suite("Paquete de la Aduana: el reloj de juego activo")
struct PackageSchedulerTests {
    let config = fxPackages()

    @Test("el primero cae a los 120 s de juego, y el reloj se rearma")
    func theFirstDropsAfterTwoMinutes() {
        var state = PackagesState.initial
        #expect(PackageScheduler.advance(&state, delta: 119, rateMultiplier: 1, config: config) == 0)
        #expect(PackageScheduler.advance(&state, delta: 1, rateMultiplier: 1, config: config) == 1)
        #expect(state.waiting == 1)
        #expect(state.secondsUntilNext == 120)
    }

    @Test("con dos esperando el reloj se queda quieto: no se acumula")
    func aFullInboxStopsTheClock() {
        var state = PackagesState(secondsUntilNext: 30, waiting: 2)
        #expect(PackageScheduler.advance(&state, delta: 1000, rateMultiplier: 1, config: config) == 0)
        #expect(state == PackagesState(secondsUntilNext: 30, waiting: 2))
    }

    @Test("al llegar al tope, el siguiente arranca un intervalo entero")
    func reachingTheCapRestartsTheInterval() {
        var state = PackagesState(secondsUntilNext: 1, waiting: 1)
        #expect(PackageScheduler.advance(&state, delta: 2, rateMultiplier: 1, config: config) == 1)
        #expect(state.waiting == 2)
        #expect(state.secondsUntilNext == 120)
    }

    @Test("lo que sobra del delta se descuenta del reloj que se rearma")
    func theLeftoverCarriesOver() {
        var state = PackagesState(secondsUntilNext: 1, waiting: 0)
        #expect(PackageScheduler.advance(&state, delta: 2, rateMultiplier: 1, config: config) == 1)
        #expect(state == PackagesState(secondsUntilNext: 119, waiting: 1))
    }

    @Test("un delta largo deja caer varios, y llegar al tope rearma un intervalo entero")
    func aLongDeltaDropsSeveralUpToTheCap() {
        var state = PackagesState(secondsUntilNext: 10, waiting: 0)
        #expect(PackageScheduler.advance(&state, delta: 300, rateMultiplier: 1, config: config) == 2)
        #expect(state == PackagesState(secondsUntilNext: 120, waiting: 2))
    }

    @Test("con más lugar en el buzón caen todos los que entran en el delta, y el resto sigue corriendo")
    func severalDropsBelowTheCapKeepTheRemainder() {
        let roomy = fxPackages(maxWaiting: 5)
        var state = PackagesState(secondsUntilNext: 10, waiting: 0)
        #expect(PackageScheduler.advance(&state, delta: 249, rateMultiplier: 1, config: roomy) == 2)
        #expect(state == PackagesState(secondsUntilNext: 1, waiting: 2))
        #expect(PackageScheduler.advance(&state, delta: 1, rateMultiplier: 1, config: roomy) == 1)
        #expect(state == PackagesState(secondsUntilNext: 120, waiting: 3))
    }

    @Test("la Lluvia de Paquetes corre el reloj ×10: uno cada 12 s")
    func packageRainRunsTenTimesFaster() {
        var state = PackagesState(secondsUntilNext: 120, waiting: 0)
        #expect(PackageScheduler.advance(&state, delta: 12, rateMultiplier: 10, config: config) == 1)
    }

    @Test("el Piquete lo frena: ×0 no mueve el reloj")
    func theBlockadeStopsIt() {
        var state = PackagesState(secondsUntilNext: 50, waiting: 0)
        #expect(PackageScheduler.advance(&state, delta: 500, rateMultiplier: 0, config: config) == 0)
        #expect(state.secondsUntilNext == 50)
    }

    @Test("el Piquete no deja caer nada ni con el reloj vencido, y una razón negativa vale como cero")
    func theBlockadeHoldsEvenWithAnExpiredClock() {
        for rate in [0.0, -3] {
            var state = PackagesState(secondsUntilNext: 0, waiting: 0)
            #expect(PackageScheduler.advance(&state, delta: 10, rateMultiplier: rate, config: config) == 0)
            #expect(state == PackagesState(secondsUntilNext: 0, waiting: 0))
        }
    }

    @Test("los regalados pasan el tope y el reloj no les saca nada")
    func giftedPackagesCanExceedTheCap() {
        var state = PackagesState(secondsUntilNext: 10, waiting: 5)
        #expect(PackageScheduler.advance(&state, delta: 50, rateMultiplier: 1, config: config) == 0)
        #expect(state.waiting == 5)
    }

    @Test("un delta nulo no mueve nada")
    func aZeroDeltaDoesNothing() {
        var state = PackagesState.initial
        #expect(PackageScheduler.advance(&state, delta: 0, rateMultiplier: 1, config: config) == 0)
        #expect(state == .initial)
    }
}

@Suite("Paquete de la Aduana: el dato")
struct PackagesConfigTests {
    @Test("los números de PLAN-v2 validan")
    func theOwnersNumbersValidate() throws {
        try fxPackages().validate()
    }

    @Test("lo que no puede ser cero, no lo es")
    func zerosAreRejected() {
        #expect(throws: PackagesConfig.ValidationError.notPositive("spawnIntervalSeconds")) {
            try fxPackages(spawnIntervalSeconds: 0).validate()
        }
        #expect(throws: PackagesConfig.ValidationError.notPositive("firstPackageAfterSeconds")) {
            try fxPackages(firstPackageAfterSeconds: 0).validate()
        }
        #expect(throws: PackagesConfig.ValidationError.notPositive("maxWaiting")) {
            try fxPackages(maxWaiting: 0).validate()
        }
        #expect(throws: PackagesConfig.ValidationError.notPositive("windowTiers")) {
            try fxPackages(windowTiers: 0).validate()
        }
    }

    @Test("sin razones, o con una que haría más probable al tope, no carga")
    func ratiosAreChecked() {
        #expect(throws: PackagesConfig.ValidationError.noRatios) { try fxPackages(ratios: []).validate() }
        #expect(throws: PackagesConfig.ValidationError.ratioBelowOne(0.5)) {
            try fxPackages(ratios: [2, 0.5]).validate()
        }
    }

    @Test("un buzón escrito antes de E5 decodifica vacío, y uno a medias también")
    func theStateDecodesFromNothing() throws {
        #expect(try JSONDecoder().decode(PackagesState.self, from: Data("{}".utf8)) == .initial)
        let partial = try JSONDecoder().decode(PackagesState.self, from: Data(#"{"waiting": 2}"#.utf8))
        #expect(partial == PackagesState(secondsUntilNext: nil, waiting: 2))
    }
}
