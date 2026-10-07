import Foundation

/// Los premios en minutos de producción real (PLAN-v2 E2a). Un premio dice
/// "N minutos" y paga lo que la torre rinde en N minutos ahora mismo.
///
/// Dos correcciones sobre el pasivo a secas, heredadas de los logros:
/// 1. **Sin los modificadores temporales.** Cobrar es una decisión del
///    jugador: si el premio mirara un ×3 vivo, guardárselo para el próximo
///    Plan Platita pagaría por esperar.
/// 2. **Con piso.** Al arrancar —o al volver de reencarnar— la torre produce
///    cero, y "cero × minutos" sería un premio que no paga. El piso es el
///    rinde de catálogo de UN personaje pelado (sin multiplicadores de piso,
///    global ni mejoras) del `rewardTier`.
public enum RewardScale {
    /// Hasta cuántos tiers por encima de la frontera mira el piso. El que
    /// reencarna conserva algo de su historia sin que guardarse un premio para
    /// después de reencarnar sea un golpe de suerte.
    public static let floorTiersAboveFrontier = 3

    /// El tier con el que se cotiza el piso: el primero del piso más alto que
    /// la cuenta tocó (sobrevive a reencarnar), nunca debajo de la frontera ni
    /// más de `floorTiersAboveFrontier` arriba de ella.
    public static func rewardTier(state: PlayerState, floorTable: FloorTable) -> Int {
        let frontier = state.run.maxTierReached
        let ordinal = min(max(state.meta.stats.maxFloorOrdinalEver, 0), floorTable.count - 1)
        let history = max(frontier, floorTable[ordinal].firstTier)
        return min(history, frontier + floorTiersAboveFrontier)
    }

    public static func productionPerSecond(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        let produced = IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config)
        let lonelyWorker = StandardEconomy(config: config).passiveYield(forTier: rewardTier(state: state, floorTable: floorTable))
        return max(produced, lonelyWorker)
    }

    public static func coinPayout(
        seconds: Double,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        guard seconds > 0 else { return 0 }
        return productionPerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config) * seconds
    }

    public static func coinPayout(
        minutes: Double,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        coinPayout(seconds: minutes * 60, state: state, tiers: tiers, floorTable: floorTable, config: config)
    }
}
