import Foundation

public enum PassiveUnlockError: Error, Equatable {
    case unknownType
    case alreadyUnlocked
    case insufficientCoins
}

/// Player actions as pure mutations over `PlayerState`. No UI, fully unit-tested.
/// (La contratación vive en `TowerActions` — F7 §3.3; acá quedan tap y passive.)
extension StandardEconomy {
    /// Tap income sobre una unidad del piso visible. Aplica los multiplicadores
    /// por tipo (charUpgrades) y por piso además de los globales. El de piso entra
    /// por `config.tapFloorMultiplier(for:)` y no crudo: el tap y el pasivo dejaron
    /// de compartir esa curva en el rebalance de pacing (el click del tier alto
    /// financiaba el piso siguiente en un minuto).
    /// Returns the gain so the scene can show feedback.
    public func applyTap(
        type: CharacterType,
        state: inout PlayerState,
        floorTable: FloorTable,
        now: TimeInterval
    ) -> Double {
        let modifierFactor = ModifierMath.factor(state.run.activeModifiers, effect: .incomeMultiplier, now: now)
            * ModifierMath.factor(state.run.activeModifiers, effect: .tapMultiplier, now: now)
        let gain = type.tapYield
            * CharUpgrades.multiplier(typeId: type.id, levels: state.run.charUpgradeLevels, config: config)
            * config.tapFloorMultiplier(for: floorTable.floor(forTier: type.tier))
            * state.meta.derivedEffects.tapMultiplier
            * state.meta.derivedEffects.incomeMultiplier
            * state.meta.globalMultiplier
            * modifierFactor
        state.run.coins += gain
        state.meta.lifetimeEarnings += gain
        return gain
    }

    /// Comprar el passive de un tipo hace que TODAS sus instancias generen income
    /// (en todos los pisos, siempre — F7 §3.5). Per-type, independent purchases.
    public func applyPassiveUnlock(typeId: String, state: inout PlayerState, tiers: TierRepository) throws {
        guard let type = tiers.type(id: typeId) else { throw PassiveUnlockError.unknownType }
        guard state.run.passiveUnlocked[typeId] != true else { throw PassiveUnlockError.alreadyUnlocked }
        guard state.run.coins >= type.passiveUnlockCost else { throw PassiveUnlockError.insufficientCoins }
        state.run.coins -= type.passiveUnlockCost
        state.run.passiveUnlocked[typeId] = true
    }
}
