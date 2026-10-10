import Testing
@testable import EconomyKit

@Suite("El piso de los descuentos de contratar")
struct SpawnCostFloorTests {
    private func discount(_ magnitude: Double, _ source: String) -> ActiveModifier {
        ActiveModifier(effect: .spawnCostMultiplier, magnitude: magnitude, expiresAt: 100, sourceKey: source)
    }

    @Test("apilados, nunca bajan de un cuarto del precio de lista")
    func stackedDiscountsHaveAFloor() {
        let stacked = [discount(0.5, "event.liquidacion"), discount(0.7, "boost.mate"), discount(0.7, "visit.arca_factura")]
        #expect(ModifierMath.factor(stacked, effect: .spawnCostMultiplier, now: 0) == ModifierMath.spawnCostStackFloor)
    }

    @Test("arriba del piso, el producto de siempre")
    func aboveTheFloorNothingChanges() {
        let two = [discount(0.5, "event.liquidacion"), discount(0.7, "boost.mate")]
        #expect(abs(ModifierMath.factor(two, effect: .spawnCostMultiplier, now: 0) - 0.35) < 1e-12)
    }

    @Test("contratar gratis no es un descuento: sigue valiendo cero, también con descuentos encima")
    func freeHiringSkipsTheFloor() {
        let free = [discount(0, "boost.free_hire"), discount(0.5, "event.liquidacion")]
        #expect(ModifierMath.factor(free, effect: .spawnCostMultiplier, now: 0) == 0)
    }

    @Test("el piso es sólo de contratar: un ingreso puede bajar más")
    func onlyHiringHasAFloor() {
        let income = [
            ActiveModifier(effect: .incomeMultiplier, magnitude: 0.3, expiresAt: 100, sourceKey: "event.apagon"),
            ActiveModifier(effect: .incomeMultiplier, magnitude: 0.5, expiresAt: 100, sourceKey: "event.devaluacion"),
        ]
        #expect(abs(ModifierMath.factor(income, effect: .incomeMultiplier, now: 0) - 0.15) < 1e-12)
    }
}
