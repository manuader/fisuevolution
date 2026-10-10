import Foundation

/// El reloj del Paquete de la Aduana. Lo llama el tick, que no corre en
/// segundo plano: afuera no se acumula nada.
public enum PackageScheduler {
    /// Avanza el reloj y devuelve cuántos cayeron. Con el buzón en el tope el
    /// reloj espera; `rateMultiplier` es el `packageRateMultiplier` de los
    /// eventos (×10 la Lluvia, ×0 el Piquete, que no deja caer nada).
    @discardableResult
    public static func advance(
        _ state: inout PackagesState,
        delta: Double,
        rateMultiplier: Double,
        config: PackagesConfig
    ) -> Int {
        guard delta > 0, rateMultiplier > 0, state.waiting < config.maxWaiting else { return 0 }
        var remaining = (state.secondsUntilNext ?? config.firstPackageAfterSeconds) - delta * rateMultiplier
        var dropped = 0
        while remaining <= 0, state.waiting < config.maxWaiting {
            state.waiting += 1
            dropped += 1
            remaining += config.spawnIntervalSeconds
        }
        state.secondsUntilNext = state.waiting < config.maxWaiting ? remaining : config.spawnIntervalSeconds
        return dropped
    }
}

/// A quién trae un paquete. El sorteo es al tocarlo: los candidatos son los que
/// FisuJobs vende con lugar, y entre ellos pesan más los tiers de abajo.
public enum PackageRoller {
    /// Un tier de la ventana con su chance (sus tipos se la reparten parejo).
    public struct Odds: Sendable, Equatable {
        public let tier: Int
        public let typeIds: [String]
        public let probability: Double
    }

    /// Los que un paquete puede traer AHORA: visto en esta run, piso abierto,
    /// compuerta de contratación abierta y lugar libre en su piso. Es la fila
    /// "contratable" de FisuJobs (`GameState.jobState`): un paquete no
    /// espoilea la cadena ni trae a quien no entra.
    public static func eligibleTypes(
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> [CharacterType] {
        eligibleTypes(
            state: state, tiers: tiers, floorTable: floorTable, config: config,
            occupancy: tower.floors.map(\.occupiedCount)
        )
    }

    /// La misma regla sin torre en memoria: `occupancy` trae cuántas unidades
    /// hay en cada piso y el lugar libre sale de la capacidad del piso. Es la
    /// que usa el simulador, que no mantiene slots.
    public static func eligibleTypes(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        occupancy: [Int]
    ) -> [CharacterType] {
        tiers.concreteTypes.filter { type in
            let ordinal = floorTable.ordinal(forTier: type.tier)
            return state.run.seenTypes.contains(type.id)
                && state.run.unlockedFloors.contains(floorTable[ordinal].id)
                && TowerActions.canHire(
                    tier: type.tier, maxTierReached: state.run.maxTierReached,
                    floorTable: floorTable, config: config
                )
                && occupancy.indices.contains(ordinal)
                && occupancy[ordinal] < floorTable[ordinal].capacity
        }
    }

    /// La tabla: los `windowTiers` tiers más altos entre los elegibles; el tope
    /// pesa 1 y cada uno de abajo `ratio` veces más (1, r, r², r³).
    public static func odds(eligible: [CharacterType], windowTiers: Int, ratio: Double) -> [Odds] {
        let byTier = Dictionary(grouping: eligible, by: \.tier)
        let window = Array(byTier.keys.sorted(by: >).prefix(max(0, windowTiers)))
        let weights = window.indices.map { pow(ratio, Double($0)) }
        return zip(window, WeightedDraw.probabilities(weights: weights)).map { tier, probability in
            Odds(tier: tier, typeIds: byTier[tier, default: []].map(\.id).sorted(), probability: probability)
        }
    }

    public static func roll<R: RandomNumberGenerator>(
        eligible: [CharacterType],
        windowTiers: Int,
        ratio: Double,
        using rng: inout R
    ) -> CharacterType? {
        let table = odds(eligible: eligible, windowTiers: windowTiers, ratio: ratio)
        guard let pick = WeightedDraw.index(weights: table.map(\.probability), using: &rng),
              let typeId = table[pick].typeIds.randomElement(using: &rng)
        else { return nil }
        return eligible.first { $0.id == typeId }
    }
}
