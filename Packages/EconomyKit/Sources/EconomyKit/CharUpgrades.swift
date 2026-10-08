import Foundation

/// Mejoras POR PERSONAJE compradas con plata (spec §3.6). Se pierden al
/// reencarnar (viven en `run.charUpgradeLevels`). Efecto **secuencial** —×2,
/// ×3, ×4 … ×20 con tope `maxLevel` = 19— y costo exponencial anclado al
/// tapYield del tier.
///
/// ⚠️ **La fórmula del efecto cambió el 2026-08-22.** Era `2 ^ nivel`, o sea
/// ×1.048.576 al nivel 20: un personaje mejorado a fondo tapaba a la torre
/// entera. Pedido textual del dueño: *"en lugar de multiplicar x2 (hasta llegar
/// a 2^20) cada vez, hace que sea secuencial (ej: x2 -> x3 -> x4 -> x5 -> ...
/// -> x20). esto va a reducir mucho las ganancias de plata y hacer que los
/// personajes ganen una cantidad de plata 'real'."*
public enum CharUpgrades {
    /// Multiplicador de income del tipo: `1 + nivel × effectStepPerLevel`.
    ///
    /// El nivel se CLAMPEA al tope aunque el save traiga más: un save anterior
    /// al 2026-08-22 puede traer hasta el nivel 20, que ya no existe.
    public static func multiplier(
        typeId: String,
        levels: [String: Int],
        config: EconomyConfig
    ) -> Double {
        let level = min(levels[typeId] ?? 0, config.charUpgrades.maxLevel)
        guard level > 0 else { return 1.0 }
        return 1.0 + Double(level) * config.charUpgrades.effectStepPerLevel
    }

    /// Cuánto CRECE el income del tipo, en fracción, al comprarle el próximo
    /// nivel. En el tope vale 0: no hay nivel que comprar.
    ///
    /// Existe porque con la recta la ganancia marginal **se achica**: el primer
    /// nivel duplica (+100 %) y el último suma un diecinueveavo (+5,3 %). Con la
    /// potencia era constante —siempre +100 %— y por eso el simulador podía
    /// escribirla como `factor − 1`. Vive acá y no en el bot para que la
    /// decisión de comprar y el efecto que se cobra salgan de la MISMA fuente:
    /// duplicar una fórmula de economía es lo que ya desincronizó una vez al
    /// simulador del juego (`Docs/balance-log.md`).
    public static func nextLevelGainFactor(
        typeId: String,
        levels: [String: Int],
        config: EconomyConfig
    ) -> Double {
        let level = levels[typeId] ?? 0
        guard level < config.charUpgrades.maxLevel else { return 0 }
        let current = multiplier(typeId: typeId, levels: levels, config: config)
        let next = multiplier(typeId: typeId, levels: [typeId: level + 1], config: config)
        return next / current - 1
    }

    /// Si el tipo ya está en el tope y no tiene próximo nivel que comprar.
    public static func isMaxed(
        typeId: String,
        levels: [String: Int],
        config: EconomyConfig
    ) -> Bool {
        (levels[typeId] ?? 0) >= config.charUpgrades.maxLevel
    }

    /// Costo del PRÓXIMO nivel para el tipo, o `nil` si ya está en el tope:
    /// un precio para un nivel que no existe sería mentirle a la UI.
    public static func nextLevelCost(
        type: CharacterType,
        levels: [String: Int],
        config: EconomyConfig,
        economy: StandardEconomy
    ) -> Double? {
        let level = levels[type.id] ?? 0
        guard level < config.charUpgrades.maxLevel else { return nil }
        return config.charUpgrades.baseCostMultiplier
            * economy.tapYield(forTier: type.tier)
            * pow(config.charUpgrades.costGrowth, Double(level))
    }

    public enum PurchaseError: Error, Equatable {
        case insufficientCoins
        /// Ya está en `maxLevel`: no hay nivel que vender (espejo del
        /// `maxLevelReached` de `UpgradeManager`).
        case maxLevelReached
        case spendingFrozen
    }

    /// Compra un nivel (debita `run.coins`, sube `run.charUpgradeLevels`).
    public static func purchase(
        type: CharacterType,
        state: inout PlayerState,
        config: EconomyConfig,
        economy: StandardEconomy,
        now: TimeInterval
    ) throws {
        guard ModifierMath.spendingFrozenUntil(state.run.activeModifiers, now: now) == nil else {
            throw PurchaseError.spendingFrozen
        }
        guard let cost = nextLevelCost(
            type: type, levels: state.run.charUpgradeLevels, config: config, economy: economy
        ) else { throw PurchaseError.maxLevelReached }
        guard state.run.coins >= cost else { throw PurchaseError.insufficientCoins }
        state.run.coins -= cost
        state.run.charUpgradeLevels[type.id, default: 0] += 1
    }
}
