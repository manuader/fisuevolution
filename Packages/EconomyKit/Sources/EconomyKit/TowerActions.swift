import Foundation

/// Cotización de contratación del TIER BASE de un piso (spec §3.3).
public struct HireQuote: Equatable, Sendable {
    public let floorOrdinal: Int
    public let type: CharacterType
    public let cost: Double
    /// Compras previas en ESTE piso (exponente de la curva).
    public let purchases: Int

    public init(floorOrdinal: Int, type: CharacterType, cost: Double, purchases: Int) {
        self.floorOrdinal = floorOrdinal
        self.type = type
        self.cost = cost
        self.purchases = purchases
    }
}

public enum TowerError: Error, Equatable {
    case floorLocked
    case floorFull
    case destinationFloorFull(floorId: String)
    case insufficientCoins
    case invalidSlot
    case noHireableType
    /// El piso está abierto, pero todavía no habilita contratar: falta que se
    /// desbloqueen dos pisos por encima. Distinto de `floorLocked` a propósito —
    /// un piso puede estar abierto y aun así no dejar contratar.
    case hireLocked
}

/// Resultado de un merge en la torre.
public enum TowerMergeResult: Equatable, Sendable {
    /// El resultado sigue perteneciendo al mismo piso.
    case stayed(floorOrdinal: Int, slot: Int, newTypeId: String)
    /// El resultado pertenece a un piso superior: ascendió. `unlockedFloorId`
    /// viene seteado si este ascenso desbloqueó el piso por primera vez.
    case promoted(toFloorOrdinal: Int, slot: Int, newTypeId: String, unlockedFloorId: String?)
    /// El merge requiere elegir carrera (se difiere, igual que hoy).
    case requiresCareerChoice(options: [String])
}

/// Mutaciones de la torre. Mantienen el invariante `tower.unitCounts == run.units`
/// y son puras (state + tower in-out): EconomyKit no conoce UI.
public enum TowerActions {
    // MARK: Hire (contratación contextual al piso — spec §3.3)

    /// Cotiza contratar el tier base del piso. `nil` si el piso no tiene un tipo
    /// concreto en su firstTier (config rota — la validación lo impide).
    public static func hireQuote(
        floorOrdinal: Int,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        economy: StandardEconomy,
        costMultiplier: Double = 1.0,
        now: TimeInterval = 0
    ) -> HireQuote? {
        guard floorOrdinal >= 0, floorOrdinal < floorTable.count else { return nil }
        let floor = floorTable[floorOrdinal]
        guard let type = baseHireType(for: floor, state: state, tiers: tiers) else { return nil }
        let purchases = state.run.hireCounts[floor.id] ?? 0
        let base = config.hireCost(
            floor: floor,
            tapYield: economy.tapYield(forTier: type.tier),
            purchases: purchases
        )
        let modifier = ModifierMath.factor(state.run.activeModifiers, effect: .spawnCostMultiplier, now: now)
        let discount = max(0, 1 - state.meta.derivedEffects.spawnDiscount)
        let cost = base * costMultiplier * modifier * discount
        return HireQuote(floorOrdinal: floorOrdinal, type: type, cost: cost, purchases: purchases)
    }

    /// El tipo concreto que vende un piso: su firstTier; si ese tier tiene ramas
    /// de carrera, respeta la elegida (mismo criterio que el spawn viejo).
    private static func baseHireType(
        for floor: FloorDef,
        state: PlayerState,
        tiers: TierRepository
    ) -> CharacterType? {
        let candidates = tiers.concreteTypes.filter { $0.tier == floor.firstTier }
        guard !candidates.isEmpty else { return nil }
        if candidates.count > 1, let career = state.run.chosenCareerPath,
           let match = candidates.first(where: { $0.id.hasSuffix(career) }) {
            return match
        }
        return candidates.sorted { $0.id < $1.id }.first
    }

    /// Contrata en el piso del quote. Requiere piso desbloqueado, slot libre y saldo.
    @discardableResult
    /// ¿Este piso habilita contratar?
    ///
    /// El backfill sólo tiene sentido cuando tu frontera ya está bastante más
    /// arriba. El precio punitivo lo desalentaba de forma implícita —el jugador
    /// tenía que deducirlo de los números— y esto lo vuelve una regla explícita.
    ///
    /// - El piso de abajo de todo (ordinal 0) SIEMPRE deja contratar: es el motor
    ///   del early game y ya es la excepción de precio.
    /// - Los dos pisos del tope nunca van a tener dos por encima, así que
    ///   desbloquear el último piso de la torre los habilita.
    ///
    /// La usan `hire` y `PacingSimulator`. **No duplicar la condición**: es el
    /// mismo error que el balance-log documenta para la fórmula de costo, que
    /// hacía que el simulador cotizara distinto que el juego.
    public static func canHire(
        floorOrdinal: Int,
        unlockedFloors: [String],
        floorTable: FloorTable
    ) -> Bool {
        guard floorOrdinal >= 0, floorOrdinal < floorTable.count else { return false }
        if floorOrdinal == 0 { return true }
        let unlocked = Set(unlockedFloors)
        if let top = floorTable.floors.last, unlocked.contains(top.id) { return true }
        let required = floorOrdinal + 2
        guard required < floorTable.count else { return false }
        return unlocked.contains(floorTable[required].id)
    }

    public static func hire(
        quote: HireQuote,
        state: inout PlayerState,
        tower: inout TowerState,
        floorTable: FloorTable
    ) throws -> TowerPlacement {
        let floor = floorTable[quote.floorOrdinal]
        guard state.run.unlockedFloors.contains(floor.id) else { throw TowerError.floorLocked }
        guard canHire(
            floorOrdinal: quote.floorOrdinal,
            unlockedFloors: state.run.unlockedFloors,
            floorTable: floorTable
        ) else { throw TowerError.hireLocked }
        guard state.run.coins >= quote.cost else { throw TowerError.insufficientCoins }
        guard let slot = tower.floors[quote.floorOrdinal].firstFreeSlot() else { throw TowerError.floorFull }

        state.run.coins -= quote.cost
        state.run.hireCounts[floor.id, default: 0] += 1
        state.run.units[quote.type.id, default: 0] += 1
        tower.floors[quote.floorOrdinal].slots[slot] = quote.type.id
        return TowerPlacement(floorOrdinal: quote.floorOrdinal, slot: slot, typeId: quote.type.id)
    }

    // MARK: Move (reacomodar dentro del piso)

    @discardableResult
    public static func move(
        floorOrdinal: Int,
        fromSlot: Int,
        toSlot: Int,
        tower: inout TowerState
    ) -> Bool {
        guard fromSlot != toSlot,
              let typeId = tower.typeId(floorOrdinal: floorOrdinal, slot: fromSlot),
              tower.typeId(floorOrdinal: floorOrdinal, slot: toSlot) == nil,
              tower.floors[floorOrdinal].slots.indices.contains(toSlot)
        else { return false }
        tower.floors[floorOrdinal].slots[fromSlot] = nil
        tower.floors[floorOrdinal].slots[toSlot] = typeId
        return true
    }

    // MARK: Merge (con ascenso de piso — spec §3.4)

    /// Aplica un merge YA VALIDADO por `MergeRules` (newTypeId concreto).
    /// Si el tier resultante pertenece a un piso superior, la unidad asciende;
    /// piso destino lleno ⇒ `TowerError.destinationFloorFull` (default ⚠️2:
    /// bloqueo — el caller no muta nada).
    public static func applyMerge(
        floorOrdinal: Int,
        sourceSlot: Int,
        targetSlot: Int,
        newTypeId: String,
        state: inout PlayerState,
        tower: inout TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) throws -> TowerMergeResult {
        guard let sourceType = tower.typeId(floorOrdinal: floorOrdinal, slot: sourceSlot),
              let targetType = tower.typeId(floorOrdinal: floorOrdinal, slot: targetSlot),
              sourceSlot != targetSlot,
              let newType = tiers.type(id: newTypeId)
        else { throw TowerError.invalidSlot }

        let destinationOrdinal = floorTable.ordinal(forTier: newType.tier)

        if destinationOrdinal != floorOrdinal {
            // Ascenso: necesita slot en el piso destino ANTES de consumir el par.
            guard tower.floors[destinationOrdinal].firstFreeSlot() != nil else {
                throw TowerError.destinationFloorFull(floorId: floorTable[destinationOrdinal].id)
            }
        }

        // Consumir el par.
        tower.floors[floorOrdinal].slots[sourceSlot] = nil
        tower.floors[floorOrdinal].slots[targetSlot] = nil
        state.run.units[sourceType, default: 0] -= 1
        state.run.units[targetType, default: 0] -= 1
        if state.run.units[sourceType] == 0 { state.run.units[sourceType] = nil }
        if state.run.units[targetType] == 0 { state.run.units[targetType] = nil }
        state.run.units[newTypeId, default: 0] += 1
        state.run.maxTierReached = max(state.run.maxTierReached, newType.tier)

        if destinationOrdinal == floorOrdinal {
            tower.floors[floorOrdinal].slots[targetSlot] = newTypeId
            return .stayed(floorOrdinal: floorOrdinal, slot: targetSlot, newTypeId: newTypeId)
        }

        let destinationFloor = floorTable[destinationOrdinal]
        let slot = tower.floors[destinationOrdinal].firstFreeSlot()!
        tower.floors[destinationOrdinal].slots[slot] = newTypeId

        var unlockedFloorId: String?
        if !state.run.unlockedFloors.contains(destinationFloor.id) {
            // Desbloqueo por primera creación del unlockTier (spec §3.8).
            state.run.unlockedFloors = floorTable.floors
                .filter { Set(state.run.unlockedFloors).union([destinationFloor.id]).contains($0.id) }
                .map(\.id)
            unlockedFloorId = destinationFloor.id
        }
        return .promoted(
            toFloorOrdinal: destinationOrdinal,
            slot: slot,
            newTypeId: newTypeId,
            unlockedFloorId: unlockedFloorId
        )
    }

    // MARK: Remove ("dejar de contratar")

    /// Saca una unidad. Falla (false) si es la última de toda la torre.
    @discardableResult
    public static func removeUnit(
        floorOrdinal: Int,
        slot: Int,
        state: inout PlayerState,
        tower: inout TowerState
    ) -> Bool {
        guard let typeId = tower.typeId(floorOrdinal: floorOrdinal, slot: slot),
              state.run.totalUnits > 1
        else { return false }
        tower.floors[floorOrdinal].slots[slot] = nil
        state.run.units[typeId, default: 0] -= 1
        if state.run.units[typeId] == 0 { state.run.units[typeId] = nil }
        return true
    }
}
