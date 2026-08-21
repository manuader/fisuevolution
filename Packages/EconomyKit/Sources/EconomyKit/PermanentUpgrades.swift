import Foundation

/// Una de las mejoras permanentes que se compran con ORO, vista por EconomyKit:
/// sólo lo que la ECONOMÍA necesita para simularla.
///
/// El catálogo canónico —`upgrades.json` + `UpgradesConfig`— vive en el app
/// target y **se queda ahí**: arrastra `titleKey`, `iconKey` y moneda, o sea
/// presentación, que es justo lo que un paquete PURO no puede conocer. Traerlo
/// entero para que el simulador pudiera comprar mejoras habría metido la UI
/// adentro de EconomyKit. En vez de eso el LLAMADOR arma estas líneas —el app
/// target desde su `UpgradesConfig`, `pacing-sim` desde el JSON— y se las pasa
/// al bot.
///
/// Es ORO por contrato: `UpgradesConfig` sabe de monedas y acá no hay `currency`
/// justamente porque quien arma la lista es responsable de filtrar las líneas
/// que se pagan con plata.
public struct PermanentUpgradeLine: Sendable, Equatable, Identifiable {
    /// Espejo de `UpgradesConfig.EffectType`. Los `rawValue` son los MISMOS a
    /// propósito: el mapeo desde el catálogo de la app es directo y un tipo de
    /// efecto nuevo allá revienta acá al decodificar, en vez de traducirse en
    /// silencio a "ninguno".
    public enum Effect: String, Codable, Sendable, Equatable, CaseIterable {
        case incomeMultiplier
        case spawnCostDiscount
        case offlineEfficiency
        case tapMultiplier
        case critChance
        case goldenTouchChance
        case prestigeBonusPerSoulPoint
    }

    public let id: String
    public let effect: Effect
    public let magnitudePerLevel: Double
    public let maxLevel: Int
    public let baseCost: Double
    public let costGrowth: Double

    public init(
        id: String,
        effect: Effect,
        magnitudePerLevel: Double,
        maxLevel: Int,
        baseCost: Double,
        costGrowth: Double
    ) {
        self.id = id
        self.effect = effect
        self.magnitudePerLevel = magnitudePerLevel
        self.maxLevel = maxLevel
        self.baseCost = baseCost
        self.costGrowth = costGrowth
    }

    /// Precio del nivel siguiente cuando ya tenés `level`. Misma curva que
    /// `UpgradeManager.cost(of:level:)` en la app.
    public func cost(atLevel level: Int) -> Double {
        baseCost * pow(costGrowth, Double(level))
    }
}

/// Las fórmulas de las mejoras permanentes que el simulador necesita.
///
/// ⚠️ `recomputeDerivedEffects` es el ESPEJO de
/// `UpgradeManager.recomputeDerivedEffects` (app target) restringido a las
/// líneas: acá no hay specials, ni referidos, ni la milanesa, porque el bot no
/// los tiene. Están separadas porque EconomyKit no puede llamar al app target,
/// no porque la fórmula sea otra — `PermanentUpgradesTests` la pinea justamente
/// para que no se separen sin que nadie se entere.
public enum PermanentUpgrades {
    /// Reconstruye `meta.derivedEffects` desde `meta.oroUpgradeLevels` × el
    /// catálogo, y recalcula el `globalMultiplier` (que depende del
    /// `prestigeBonus` que acaba de cambiar) — igual que la app.
    ///
    /// ⚠️ **No aplica los topes de `EffectCaps`** (crit 0,5 · offline 1,0 ·
    /// golden 0,1 · spawn 0,6), que viven en el app target. Con el catálogo
    /// vigente ninguna línea los alcanza —offline llega a 0,35 + 10×0,05 = 0,85
    /// y spawn a 10×0,03 = 0,30—, así que el bot y el juego coinciden. Si la
    /// calibración sube algún `maxLevel` o `magnitudePerLevel`, el bot pasaría a
    /// modelar un efecto que el juego recorta: hay que pasarle los topes.
    public static func recomputeDerivedEffects(
        state: inout PlayerState,
        lines: [PermanentUpgradeLine],
        economy: StandardEconomy
    ) {
        var income = 1.0
        var tap = 1.0
        var crit = economy.config.critChanceBase
        var offline = economy.config.offlineEfficiencyBase
        var golden = 0.0
        var spawnDiscount = 0.0
        var prestigeBonus = 0.0

        for line in lines {
            // CLAMPEADO al tope, igual que `CharUpgrades.multiplier`: un save
            // viejo puede traer más niveles de los que la línea admite hoy (el
            // rebalance de pacing bajó `income` y `tap` de 20 a 10 y `crit` de
            // 25 a 10), y sin el clamp ese save cobraría ×5,0 de income donde el
            // tope es 3,0. Que el catálogo se achique no puede resucitar un
            // efecto que ya no existe.
            let level = Double(min(state.meta.oroUpgradeLevels[line.id] ?? 0, line.maxLevel))
            guard level > 0 else { continue }
            switch line.effect {
            case .incomeMultiplier: income += level * line.magnitudePerLevel
            case .tapMultiplier: tap += level * line.magnitudePerLevel
            case .critChance: crit += level * line.magnitudePerLevel
            case .offlineEfficiency: offline += level * line.magnitudePerLevel
            case .goldenTouchChance: golden += level * line.magnitudePerLevel
            case .spawnCostDiscount: spawnDiscount += level * line.magnitudePerLevel
            case .prestigeBonusPerSoulPoint: prestigeBonus += level * line.magnitudePerLevel
            }
        }

        state.meta.derivedEffects.incomeMultiplier = income
        state.meta.derivedEffects.tapMultiplier = tap
        state.meta.derivedEffects.critChance = crit
        state.meta.derivedEffects.offlineEfficiency = offline
        state.meta.derivedEffects.goldenChance = golden
        state.meta.derivedEffects.spawnDiscount = spawnDiscount
        state.meta.derivedEffects.prestigeBonus = prestigeBonus
        state.meta.globalMultiplier = economy.globalMultiplier(
            oroEarnedLifetime: state.meta.oroEarnedLifetime,
            prestigeBonus: prestigeBonus
        )
    }

    /// ¿Están TODAS las líneas al tope? Es la condición de victoria del dueño
    /// (maxear las siete desbloquea las skins doradas).
    ///
    /// Un catálogo vacío NO cuenta como maxeado: `allSatisfy` sobre la lista
    /// vacía es `true` y eso haría que una corrida sin catálogo —el modelo
    /// viejo— reportara "maxeado en el segundo cero".
    public static func allMaxed(levels: [String: Int], lines: [PermanentUpgradeLine]) -> Bool {
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy { (levels[$0.id] ?? 0) >= $0.maxLevel }
    }
}
