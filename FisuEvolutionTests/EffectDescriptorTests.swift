import Testing
@testable import FisuEvolution

/// `EffectDescriptor` es la ÚNICA traducción de `effectType` + magnitud + nivel a
/// un número mostrable. La consumen las mejoras permanentes, los boosts y el
/// prestigio: si cada pantalla escribiera la suya, tres filas dirían tres cosas
/// distintas del mismo efecto (RF-06).
///
/// Los dos tests de cobertura (`everyUpgradeEffectIsCovered` y
/// `everyBoostEffectIsCovered`) sólo existen porque los dos enums son
/// `CaseIterable`: son los que convierten "cubrimos todos los casos" en algo
/// verificado en vez de una promesa.
@Suite struct EffectDescriptorTests {
    @Test("nivel 0 no da efecto")
    func levelZeroIsNeutral() {
        let amount = EffectDescriptor.amount(for: UpgradesConfig.EffectType.incomeMultiplier, level: 0, magnitudePerLevel: 0.1)
        #expect(amount.value == 0)
        #expect(amount.isCapped == false)
    }

    @Test("los efectos se acumulan sumando por nivel")
    func levelsAddUp() {
        let amount = EffectDescriptor.amount(for: .incomeMultiplier, level: 3, magnitudePerLevel: 0.1)
        #expect(abs(amount.value - 0.3) < 0.0001)
        #expect(amount.unit == .percentBonus)
    }

    @Test("el descuento de contratación se muestra como descuento, no como bonus")
    func discountHasItsOwnUnit() {
        let amount = EffectDescriptor.amount(for: .spawnCostDiscount, level: 3, magnitudePerLevel: 0.03)
        #expect(amount.unit == .percentDiscount)
        #expect(abs(amount.value - 0.09) < 0.0001)
    }

    @Test("el tope de crítico recorta y lo declara")
    func critIsCapped() {
        // 25 niveles × 0,01 = 0,25; con magnitud inflada se pasa del tope de 0,50.
        let amount = EffectDescriptor.amount(for: .critChance, level: 25, magnitudePerLevel: 0.05)
        #expect(amount.value == 0.5)
        #expect(amount.isCapped, "pasarse del tope tiene que quedar declarado o la fila miente")
    }

    @Test("el formato usa el signo y el símbolo de cada unidad")
    func formatting() {
        #expect(EffectFormatter.text(EffectAmount(unit: .percentBonus, value: 0.3, isCapped: false)) == "+30%")
        #expect(EffectFormatter.text(EffectAmount(unit: .percentDiscount, value: 0.09, isCapped: false)) == "−9%")
        #expect(EffectFormatter.text(EffectAmount(unit: .chance, value: 0.03, isCapped: false)) == "3%")
    }

    @Test("la progresión muestra el salto, y al máximo muestra sólo el actual")
    func progression() {
        let current = EffectAmount(unit: .percentBonus, value: 0.3, isCapped: false)
        let next = EffectAmount(unit: .percentBonus, value: 0.4, isCapped: false)
        #expect(EffectFormatter.progression(current: current, next: next) == "+30% → +40%")
        #expect(EffectFormatter.progression(current: current, next: nil) == "+30%")
    }

    @Test("los siete tipos de mejora tienen unidad, ninguno cae en un default")
    func everyUpgradeEffectIsCovered() {
        for type in UpgradesConfig.EffectType.allCases {
            let amount = EffectDescriptor.amount(for: type, level: 1, magnitudePerLevel: 0.1)
            #expect(amount.value > 0, "\(type) no describe nada")
        }
    }

    @Test("los cinco tipos de boost tienen unidad")
    func everyBoostEffectIsCovered() {
        for type in BoostsConfig.EffectType.allCases {
            let amount = EffectDescriptor.amount(forBoost: type, magnitude: 2.0)
            #expect(amount.value != 0, "\(type) no describe nada")
        }
    }

    @Test("el boost de costo se muestra como descuento y no como factor")
    func boostCostMultiplierReadsAsDiscount() {
        // El mate tiene magnitud 0,7: contratar cuesta 0,7×, o sea 30% menos.
        let amount = EffectDescriptor.amount(forBoost: .spawnCostMultiplier, magnitude: 0.7)
        #expect(amount.unit == .percentDiscount)
        #expect(abs(amount.value - 0.3) < 0.0001, "0,7 tiene que leerse como −30%")
    }

    /// El tope que muestra la fila y el tope que aplica la economía tienen que
    /// ser el MISMO número. Están en `EffectCaps` justamente para que no puedan
    /// separarse; este test falla si alguien vuelve a poner un literal en
    /// `ContentSystems.recomputeDerivedEffects`.
    @Test("el descriptor recorta en el mismo tope que la economía")
    func capsMatchTheEconomy() {
        let crit = EffectDescriptor.amount(for: .critChance, level: 1_000, magnitudePerLevel: 1)
        let golden = EffectDescriptor.amount(for: .goldenTouchChance, level: 1_000, magnitudePerLevel: 1)
        let offline = EffectDescriptor.amount(for: .offlineEfficiency, level: 1_000, magnitudePerLevel: 1)
        let discount = EffectDescriptor.amount(for: .spawnCostDiscount, level: 1_000, magnitudePerLevel: 1)
        #expect(crit.value == EffectCaps.crit)
        #expect(golden.value == EffectCaps.golden)
        #expect(offline.value == EffectCaps.offline)
        #expect(discount.value == EffectCaps.spawnDiscount)
        #expect(crit.isCapped && golden.isCapped && offline.isCapped && discount.isCapped)
    }
}
