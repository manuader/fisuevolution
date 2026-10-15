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
            // Cae sin asignar: a quién trae lo decide `PackageRoller.assignPending` con el estado
            // de este momento (E14b B18), que el reloj no conoce.
            state.boxes.append(.unassigned)
            dropped += 1
            remaining += config.spawnIntervalSeconds
        }
        state.secondsUntilNext = state.waiting < config.maxWaiting ? remaining : config.spawnIntervalSeconds
        return dropped
    }
}

/// A quién trae un paquete. El sorteo es cuando la caja aparece (E14b B18): los
/// candidatos son los que FisuJobs vende con lugar, y entre ellos pesan más los
/// tiers de abajo. El tipo sorteado fija el piso de la caja.
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

    /// La chance de cada tipo, la que se le muestra al jugador: el tier se
    /// sortea con `odds` y sus tipos se la reparten parejo, igual que `roll`.
    public struct TypeOdds: Sendable, Equatable {
        public let typeId: String
        public let tier: Int
        public let probability: Double
    }

    public static func typeOdds(eligible: [CharacterType], windowTiers: Int, ratio: Double) -> [TypeOdds] {
        odds(eligible: eligible, windowTiers: windowTiers, ratio: ratio).flatMap { tier in
            tier.typeIds.map { TypeOdds(typeId: $0, tier: tier.tier, probability: tier.probability / Double(tier.typeIds.count)) }
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

    // MARK: - La caja de un piso (E14b B18)

    /// Sortea una caja que aparece: el mismo sorteo de siempre (`roll`), y el tipo fija su piso
    /// (`floorTable.ordinal(forTier:)`) y un lugar al azar de la franja del piso. `nil` sin
    /// nadie a quien traer.
    public static func rollBox<R: RandomNumberGenerator>(
        eligible: [CharacterType],
        windowTiers: Int,
        ratio: Double,
        floorTable: FloorTable,
        using rng: inout R
    ) -> PackageBox? {
        guard let type = roll(eligible: eligible, windowTiers: windowTiers, ratio: ratio, using: &rng) else {
            return nil
        }
        return PackageBox(
            floor: floorTable.ordinal(forTier: type.tier),
            typeId: type.id,
            x: Double.random(in: 0...1, using: &rng)
        )
    }

    /// Si una caja ya sorteada sigue valiendo en esta run: su tipo existe, se vio y es de su
    /// piso, y el piso está abierto. Una reencarnación cierra los pisos: lo que cayó arriba se
    /// vuelve a sortear (`assignPending`). Que el piso esté lleno no la invalida: espera lugar.
    public static func belongs(
        _ box: PackageBox,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> Bool {
        guard let floor = box.floor, let typeId = box.typeId,
              floorTable.floors.indices.contains(floor),
              let type = tiers.type(id: typeId), !type.isChoiceNode
        else { return false }
        return floorTable.ordinal(forTier: type.tier) == floor
            && state.run.seenTypes.contains(typeId)
            && state.run.unlockedFloors.contains(floorTable[floor].id)
    }

    /// Sortea las cajas sin asignar y las que dejaron de valer (`belongs`), con el estado de
    /// ahora. Las que no tienen a quién traer quedan sin asignar. Devuelve cuántas se sortearon.
    @discardableResult
    public static func assignPending<R: RandomNumberGenerator>(
        _ packages: inout PackagesState,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        occupancy: [Int],
        windowTiers: Int,
        ratio: Double,
        using rng: inout R
    ) -> Int {
        var eligible: [CharacterType]?
        var assigned = 0
        for index in packages.boxes.indices
        where !belongs(packages.boxes[index], state: state, tiers: tiers, floorTable: floorTable) {
            let candidates = eligible ?? eligibleTypes(
                state: state, tiers: tiers, floorTable: floorTable, config: config, occupancy: occupancy
            )
            eligible = candidates
            guard let box = rollBox(
                eligible: candidates, windowTiers: windowTiers, ratio: ratio, floorTable: floorTable, using: &rng
            ) else {
                packages.boxes[index] = .unassigned
                continue
            }
            packages.boxes[index] = box
            assigned += 1
        }
        return assigned
    }
}
