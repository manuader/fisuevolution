import Foundation

/// Cotización de contratación del TIER BASE de un piso (spec §3.3).
public struct HireQuote: Equatable, Sendable {
    public let floorOrdinal: Int
    public let type: CharacterType
    public let cost: Double
    /// Compras previas que forman el exponente de la curva: por PISO si el quote
    /// salió de `hireQuote(floorOrdinal:)`, por TIPO si salió de
    /// `hireQuote(typeId:)`. Es informativo (la pantalla lo muestra); quien cobra
    /// es `cost`.
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
    /// El piso está abierto, pero todavía no habilita contratar: falta
    /// desbloquear el piso de arriba. Distinto de `floorLocked` a propósito —
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
    ///
    /// ⚠️ Su exponente sigue siendo el contador POR PISO (`run.hireCounts`), que
    /// es lo que pinean sus tests y lo que cobra el botón de la torre. La
    /// pantalla de laburos usa `hireQuote(typeId:)`, con el contador por tipo:
    /// mientras los dos caminos convivan, un mismo personaje puede cotizar
    /// distinto según de dónde lo compres. Se unifican cuando la pantalla nueva
    /// reemplace al botón (plan del rediseño).
    ///
    /// ⚠️ `economy` quedó SIN USO cuando `hireCost` pasó a recibir el tier y a
    /// derivar el tapYield de la config (una sola fuente). No se sacó de la firma
    /// en la ronda de fix para no reescribir sus 14 llamadores —entre ellos la
    /// suite pineada `EconomyEngineTests`— por una limpieza cosmética; queda
    /// propuesto como cambio aparte. **No lo uses para nada**: pasarle un
    /// `StandardEconomy` de otra config no cambia el precio.
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
        // `floor.firstTier` y no `type.tier`: son el mismo número —`baseHireType`
        // filtra por `tier == floor.firstTier`— pero acá lo que se cotiza es "el
        // tier base de este piso", que es el contrato de esta función.
        let base = config.hireCost(floor: floor, tier: floor.firstTier, purchases: purchases)
        let modifier = ModifierMath.factor(state.run.activeModifiers, effect: .spawnCostMultiplier, now: now)
        let discount = max(0, 1 - state.meta.derivedEffects.spawnDiscount)
        let cost = base * costMultiplier * modifier * discount
        return HireQuote(floorOrdinal: floorOrdinal, type: type, cost: cost, purchases: purchases)
    }

    /// Cotiza contratar UN TIPO concreto, en el piso al que ese tipo pertenece.
    /// Es la cotización de la pantalla de laburos (§5.2), que vende cualquier
    /// tipo y no sólo el tier base del piso visible.
    ///
    /// `nil` si el `typeId` no existe o es un nodo de elección (`junior`): esos
    /// no son personajes, son la bifurcación de carrera.
    ///
    /// Dos diferencias con `hireQuote(floorOrdinal:)`, las dos a propósito:
    /// - El exponente de la curva es `run.hireCountsByType[typeId]`, no el
    ///   contador por piso: cada personaje tiene su propia curva, que es lo que
    ///   la pantalla muestra ("— N contratados").
    /// - El precio lleva el `tierPremium` de los tiers no-base (ver `hireCost`).
    ///
    /// No mira gate ni saldo: cotizar es sólo poner precio, y la pantalla también
    /// muestra el precio de lo que todavía no podés comprar.
    ///
    /// ⚠️ **Y nadie más abajo lo mira por vos.** Este quote entra a `hire(quote:)`
    /// sin cambios de firma, pero los guards de `hire` son del PISO: piso
    /// desbloqueado, `canHire` de ese piso, saldo y slot libre. **Ninguno mira el
    /// tipo.** Con la cotización por piso eso alcanzaba —el único tipo cotizable
    /// era el tier base—, pero acá ya no: si le pasás el quote de un T4 del
    /// callejón a alguien que nunca mergeó, `hire` se lo vende, se lo coloca y
    /// hasta se lo marca como visto.
    ///
    /// La compuerta por tipo **no existe en EconomyKit todavía**, y es a
    /// propósito: quién puede contratar qué es una decisión de la pantalla de
    /// laburos (la proyección `jobRows` decide qué fila se ofrece como
    /// contratable y cuál sale bloqueada). Mientras tanto, **cotizar un tipo no
    /// es autorizarlo**: quien construya el quote es responsable de que el tipo
    /// sea uno que el jugador puede comprar.
    public static func hireQuote(
        typeId: String,
        state: PlayerState,
        config: EconomyConfig,
        floorTable: FloorTable,
        tiers: TierRepository,
        costMultiplier: Double = 1.0,
        now: TimeInterval = 0
    ) -> HireQuote? {
        guard let type = tiers.type(id: typeId), !type.isChoiceNode else { return nil }
        let ordinal = floorTable.ordinal(forTier: type.tier)
        let floor = floorTable[ordinal]
        let purchases = state.run.hireCountsByType[typeId] ?? 0
        let base = config.hireCost(floor: floor, tier: type.tier, purchases: purchases)
        let modifier = ModifierMath.factor(state.run.activeModifiers, effect: .spawnCostMultiplier, now: now)
        let discount = max(0, 1 - state.meta.derivedEffects.spawnDiscount)
        let cost = base * costMultiplier * modifier * discount
        return HireQuote(floorOrdinal: ordinal, type: type, cost: cost, purchases: purchases)
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

    /// ¿Este piso habilita contratar?
    ///
    /// El backfill sólo tiene sentido cuando tu frontera ya está bastante más
    /// arriba. El precio punitivo lo desalentaba de forma implícita —el jugador
    /// tenía que deducirlo de los números— y esto lo vuelve una regla explícita.
    ///
    /// - El piso de abajo de todo (ordinal 0) SIEMPRE deja contratar: es el motor
    ///   del early game y ya es la excepción de precio.
    /// - El último piso no tiene ninguno por encima, así que desbloquearlo lo
    ///   habilita a sí mismo.
    /// - Un piso puede declararse EXENTO en `economy.json` (`hireGateExempt`).
    ///   Eso cambia la COBERTURA del gate, no su profundidad: sigue siendo de un
    ///   piso. Se agregó para el urbano en la Ola 3, donde el gate se combinaba
    ///   con el remapeo de tiers para dejar 268 h de pared antes de corporativo
    ///   (`balance-log`, "El muro de ×368").
    ///
    /// **Por qué UNO y no dos**: con dos, el juego deja de poder terminarse. El
    /// spec de F7 §3.3 dice que el merge puro es matemáticamente inviable
    /// (T30 = 2²⁹ fisuras) y que el backfill es el puente; pedir dos pisos saca
    /// ese puente justo donde hace falta —no podés comprar material en el piso
    /// que estás atravesando— y queda un huevo-y-gallina, porque la frontera
    /// avanza GRACIAS al backfill. Medido: sin gate Dios cae a las 38 h, con
    /// gate de uno a las 264 h, y con gate de dos el bot se traba en tier 12 y
    /// no llega nunca.
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
        if floorTable[floorOrdinal].hireGateExempt { return true }
        let unlocked = Set(unlockedFloors)
        if let top = floorTable.floors.last, unlocked.contains(top.id) { return true }
        let required = floorOrdinal + 1
        guard required < floorTable.count else { return false }
        return unlocked.contains(floorTable[required].id)
    }

    /// El piso donde CAE una contratación hecha parado en `visibleOrdinal`.
    ///
    /// Normalmente es el piso que estás mirando. Pero cuando el gate lo cierra
    /// —estás en tu frontera y todavía no abriste el de arriba— el botón quedaba
    /// muerto, y quedarse sin nada que comprar en el piso donde más falta hace
    /// material de merge es justo lo contrario de lo que el gate busca. Así que
    /// la compra cae al piso de abajo, que por la propia regla del gate es
    /// siempre el más alto donde SÍ se puede contratar.
    ///
    /// Baja un solo piso a propósito: no hay caso donde haga falta más, porque
    /// si el piso visible está abierto entonces el de abajo tiene el de arriba
    /// abierto y su gate pasa.
    ///
    /// `nil` cuando no se puede contratar desde acá: el piso visible ni siquiera
    /// está abierto (es el preview con candado al que la torre deja asomarse).
    public static func hireTargetFloor(
        visibleOrdinal: Int,
        unlockedFloors: [String],
        floorTable: FloorTable
    ) -> Int? {
        guard visibleOrdinal >= 0, visibleOrdinal < floorTable.count else { return nil }
        let unlocked = Set(unlockedFloors)
        guard unlocked.contains(floorTable[visibleOrdinal].id) else { return nil }
        if canHire(floorOrdinal: visibleOrdinal, unlockedFloors: unlockedFloors, floorTable: floorTable) {
            return visibleOrdinal
        }
        let below = visibleOrdinal - 1
        guard below >= 0, unlocked.contains(floorTable[below].id),
              canHire(floorOrdinal: below, unlockedFloors: unlockedFloors, floorTable: floorTable)
        else { return nil }
        return below
    }

    /// Pisos que pasan de NO contratables a contratables por un desbloqueo.
    ///
    /// En el caso normal es uno solo: el que está justo abajo del que se abrió.
    /// Se calcula comparando la regla contra sí misma en vez de restar ordinales
    /// a mano, así el caso normal y el del escape del tope salen de la misma
    /// fuente y no pueden desincronizarse.
    public static func newlyHireableFloors(
        unlockedBefore: [String],
        unlockedAfter: [String],
        floorTable: FloorTable
    ) -> [Int] {
        (0..<floorTable.count).filter { ordinal in
            !canHire(floorOrdinal: ordinal, unlockedFloors: unlockedBefore, floorTable: floorTable)
                && canHire(floorOrdinal: ordinal, unlockedFloors: unlockedAfter, floorTable: floorTable)
        }
    }

    /// Contrata en el piso del quote. Requiere piso desbloqueado, gate abierto,
    /// slot libre y saldo.
    @discardableResult
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
        // Por TIPO además de por piso: la curva de la pantalla de laburos. Va acá
        // y no en el caller para que ningún camino de contratación se la saltee.
        state.run.hireCountsByType[quote.type.id, default: 0] += 1
        state.meta.stats.totalHiresEver += 1
        state.run.units[quote.type.id, default: 0] += 1
        state.run.markSeen(quote.type.id)
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
        state.run.markSeen(newTypeId)
        state.run.maxTierReached = max(state.run.maxTierReached, newType.tier)
        // Después de los guards, junto al resto de la mutación: un merge que tira
        // `destinationFloorFull` no ocurrió y no se cuenta. El auto-merge de
        // `TowerReconciler` tampoco pasa por acá, y eso es a propósito: es de la
        // carga, no del jugador.
        state.meta.stats.totalMergesEver += 1

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
