import Foundation

/// Pisos en marcha (PLAN-v2 §2, crítica de Marco): cada piso con todos sus
/// lugares ocupados suma `staffedBonusPerFloor` a los ingresos globales. Los
/// pisos bajos vuelven a servir para algo.
///
/// La ocupación sale de `run.units` agrupadas por el piso de su tier: es lo que
/// la torre tiene en sus slots (`tower.unitCounts == run.units`) y lo único que
/// tiene el simulador, que no arma torre.
public enum StaffedFloors {
    public static func ordinals(state: PlayerState, tiers: TierRepository, floorTable: FloorTable) -> [Int] {
        var occupied = [Int](repeating: 0, count: floorTable.count)
        for (typeId, count) in state.run.units where count > 0 {
            guard let type = tiers.type(id: typeId), !type.isChoiceNode else { continue }
            occupied[floorTable.ordinal(forTier: type.tier)] += count
        }
        return occupied.indices.filter { occupied[$0] >= floorTable[$0].capacity }
    }

    public static func multiplier(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        let bonus = config.staffedBonusPerFloor
        guard bonus > 0 else { return 1 }
        return 1 + bonus * Double(ordinals(state: state, tiers: tiers, floorTable: floorTable).count)
    }
}
