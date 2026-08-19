import Foundation

/// Mejoras POR PERSONAJE compradas con plata (spec §3.6). Se pierden al
/// reencarnar (viven en `run.charUpgradeLevels`). Efecto ×2/nivel con tope
/// `maxLevel` (20: máximo = base × 2^20 — sin tope, el exponencial terminaba
/// en overflow; decisión del dueño, 2026-08-19); costo exponencial anclado al
/// tapYield del tier.
public enum CharUpgrades {
    /// Multiplicador de income del tipo: `effectFactorPerLevel ^ nivel`.
    ///
    /// El nivel se CLAMPEA al tope aunque el save traiga más (un save viejo o
    /// tocado a mano no puede resucitar el overflow que el tope mata).
    public static func multiplier(
        typeId: String,
        levels: [String: Int],
        config: EconomyConfig
    ) -> Double {
        let level = min(levels[typeId] ?? 0, config.charUpgrades.maxLevel)
        guard level > 0 else { return 1.0 }
        return pow(config.charUpgrades.effectFactorPerLevel, Double(level))
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
    }

    /// Compra un nivel (debita `run.coins`, sube `run.charUpgradeLevels`).
    public static func purchase(
        type: CharacterType,
        state: inout PlayerState,
        config: EconomyConfig,
        economy: StandardEconomy
    ) throws {
        guard let cost = nextLevelCost(
            type: type, levels: state.run.charUpgradeLevels, config: config, economy: economy
        ) else { throw PurchaseError.maxLevelReached }
        guard state.run.coins >= cost else { throw PurchaseError.insufficientCoins }
        state.run.coins -= cost
        state.run.charUpgradeLevels[type.id, default: 0] += 1
    }
}
