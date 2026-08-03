import Foundation

/// Mejoras POR PERSONAJE compradas con plata (spec §3.6). Se pierden al
/// reencarnar (viven en `run.charUpgradeLevels`). Efecto ×2/nivel sin tope
/// (default ⚠️4); costo exponencial anclado al tapYield del tier.
public enum CharUpgrades {
    /// Multiplicador de income del tipo: `effectFactorPerLevel ^ nivel`.
    public static func multiplier(
        typeId: String,
        levels: [String: Int],
        config: EconomyConfig
    ) -> Double {
        let level = levels[typeId] ?? 0
        guard level > 0 else { return 1.0 }
        return pow(config.charUpgrades.effectFactorPerLevel, Double(level))
    }

    /// Costo del PRÓXIMO nivel para el tipo.
    public static func nextLevelCost(
        type: CharacterType,
        levels: [String: Int],
        config: EconomyConfig,
        economy: StandardEconomy
    ) -> Double {
        let level = levels[type.id] ?? 0
        return config.charUpgrades.baseCostMultiplier
            * economy.tapYield(forTier: type.tier)
            * pow(config.charUpgrades.costGrowth, Double(level))
    }

    public enum PurchaseError: Error, Equatable {
        case insufficientCoins
    }

    /// Compra un nivel (debita `run.coins`, sube `run.charUpgradeLevels`).
    public static func purchase(
        type: CharacterType,
        state: inout PlayerState,
        config: EconomyConfig,
        economy: StandardEconomy
    ) throws {
        let cost = nextLevelCost(type: type, levels: state.run.charUpgradeLevels, config: config, economy: economy)
        guard state.run.coins >= cost else { throw PurchaseError.insufficientCoins }
        state.run.coins -= cost
        state.run.charUpgradeLevels[type.id, default: 0] += 1
    }
}
