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
    public let purchases: Double

    public init(floorOrdinal: Int, type: CharacterType, cost: Double, purchases: Double) {
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
    /// El piso está abierto, pero a este personaje todavía le falta compuerta:
    /// tu frontera de merge no llegó `hire.gateTierDistance` tiers por encima
    /// de su tier. Distinto de `floorLocked` a propósito — un piso puede estar
    /// abierto y aun así no dejar contratar a la mitad de sus tipos.
    case hireLocked
}

/// Resultado de un merge en la torre.
public enum TowerMergeResult: Equatable, Sendable {
    /// El resultado sigue perteneciendo al mismo piso.
    case stayed(floorOrdinal: Int, slot: Int, newTypeId: String)
    /// El resultado pertenece a un piso superior: ascendió. `unlockedFloorId`
    /// viene seteado si este ascenso desbloqueó el piso por primera vez.
    case promoted(toFloorOrdinal: Int, slot: Int, newTypeId: String, unlockedFloorId: String?)
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
    public static func hireQuote(
        floorOrdinal: Int,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
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
        let base = config.hireCost(
            floor: floor, tier: floor.firstTier,
            frontierTier: state.run.maxTierReached, purchases: purchases
        )
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
    /// - El precio de un tier por ENCIMA de tu frontera sube `priceGrowthPerTier`
    ///   por tier (ver `hireCost`), que es lo que ordena la vitrina: la fila
    ///   bloqueada de arriba se ve más cara que la de abajo.
    ///
    /// No mira compuerta ni saldo: cotizar es sólo poner precio, y la pantalla
    /// también muestra el precio de lo que todavía no podés comprar.
    ///
    /// **Cotizar un tipo sigue sin autorizarlo** — pero desde el 2026-08-22 el
    /// que autoriza es `hire`, y no la vista. Su guard de compuerta mira el TIPO
    /// (`canHire(tier:)`), así que el quote de un T4 del callejón en manos de
    /// alguien que nunca mergeó vuelve rebotado con `hireLocked` en vez de
    /// venderse. Antes los guards de `hire` eran todos del PISO y este hueco era
    /// real: la proyección `jobRows` era la única compuerta por tipo del juego.
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
        let base = config.hireCost(
            floor: floor, tier: type.tier,
            frontierTier: state.run.maxTierReached, purchases: purchases
        )
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

    /// ¿Se puede contratar un personaje de este TIER?
    ///
    /// **La regla se mide en tiers**: hace falta que tu frontera de merge
    /// (`run.maxTierReached`) esté `hire.gateTierDistance` tiers por encima del
    /// que querés comprar. O sea que cada personaje nuevo sale de `2^distancia`
    /// compras del más alto que sí podés comprar, y eso vale compres donde
    /// compres.
    ///
    /// **El tier base de la torre está exento** (el Fisura): es el motor del
    /// early game, el tutorial lo enseña y de él sale todo lo demás. Es la ÚNICA
    /// excepción.
    ///
    /// ⚠️ **Antes se medía en PISOS y por eso había un borde dentado.** La regla
    /// vieja pedía el piso de arriba desbloqueado, pero un piso son cuatro tiers
    /// y la pantalla de laburos los vende todos: comprar el TOPE del piso
    /// habilitado dejaba la frontera a UN tier, o sea a DOS unidades de merge, y
    /// comprar la BASE la dejaba a cuatro (dieciséis unidades). La regla decía
    /// "un piso de profundidad" y lo que ataba era el caso más barato, así que
    /// todo pasaba entre dos pisos contiguos y el ascensor no se usaba nunca
    /// (queja del dueño, 2026-08-22). Medida en tiers, la distancia es la misma
    /// por todos lados y el borde desaparece por construcción.
    ///
    /// La usan `hire`, la pantalla de laburos y `PacingSimulator`. **No duplicar
    /// la condición**: es el mismo error que el balance-log documenta para la
    /// fórmula de costo, que hacía que el simulador cotizara distinto que el
    /// juego.
    public static func canHire(
        tier: Int,
        maxTierReached: Int,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Bool {
        // Cero (o menos) es la compuerta APAGADA, no una distancia de cero
        // tiers: ver `HireConfig.noTierGate`. Vive acá y no repetido en cada
        // llamador porque el sentido del sentinel es parte de la regla.
        let distance = config.hire.gateTierDistance
        guard distance > 0 else { return true }
        // El exento sale del `floorTable` y no de un `1` escrito acá: la torre
        // es data-driven y su tier base es el que diga la config.
        guard let base = floorTable.floors.first?.firstTier, tier > base else { return true }
        return maxTierReached >= tier + distance
    }

    /// ¿Este piso habilita contratar? Es la regla de arriba aplicada al tier
    /// BASE del piso, que es lo único que el botón de la torre vende.
    ///
    /// Existe como envoltorio y no como regla propia para que la torre y la
    /// pantalla de laburos no puedan contestar distinto sobre el mismo
    /// personaje.
    public static func canHire(
        floorOrdinal: Int,
        maxTierReached: Int,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Bool {
        guard floorOrdinal >= 0, floorOrdinal < floorTable.count else { return false }
        return canHire(
            tier: floorTable[floorOrdinal].firstTier,
            maxTierReached: maxTierReached,
            floorTable: floorTable,
            config: config
        )
    }

    /// El piso donde CAE una contratación hecha parado en `visibleOrdinal`: el
    /// más alto, de acá para abajo, que esté abierto y cuya compuerta pase.
    ///
    /// Normalmente es el piso que estás mirando. Pero cuando la compuerta lo
    /// cierra —estás en tu frontera y todavía te faltan tiers— el botón quedaba
    /// muerto, y quedarse sin nada que comprar en el piso donde más falta hace
    /// material de merge es justo lo contrario de lo que la compuerta busca. Así
    /// que la compra cae más abajo.
    ///
    /// ⚠️ **Baja lo que haga falta, no un piso.** Con la compuerta por pisos
    /// alcanzaba con bajar uno —si el visible estaba abierto, el de abajo tenía
    /// el de arriba abierto y su gate pasaba por construcción—, y esa garantía
    /// se fue con la regla vieja: parado en un piso cuya base pide `firstTier +
    /// N`, la base del piso de abajo pide `firstTier − 4 + N`, que tampoco tiene
    /// por qué estar alcanzada. El fondo siempre contesta, eso sí: el tier base
    /// de la torre está exento.
    ///
    /// `nil` cuando no se puede contratar desde acá: el piso visible ni siquiera
    /// está abierto (es el preview con candado al que la torre deja asomarse).
    public static func hireTargetFloor(
        visibleOrdinal: Int,
        unlockedFloors: [String],
        maxTierReached: Int,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Int? {
        guard visibleOrdinal >= 0, visibleOrdinal < floorTable.count else { return nil }
        let unlocked = Set(unlockedFloors)
        guard unlocked.contains(floorTable[visibleOrdinal].id) else { return nil }
        return (0...visibleOrdinal).reversed().first { ordinal in
            unlocked.contains(floorTable[ordinal].id)
                && canHire(
                    floorOrdinal: ordinal, maxTierReached: maxTierReached,
                    floorTable: floorTable, config: config
                )
        }
    }

    /// Pisos que pasan de NO contratables a contratables porque la frontera
    /// subió.
    ///
    /// ⚠️ **El disparador es la FRONTERA, no el desbloqueo de un piso.** Con la
    /// regla vieja las dos cosas eran la misma —un piso se abría y el de abajo
    /// se habilitaba—, y ahora no: la frontera sube con cualquier fusión, hasta
    /// con una que no cambia de piso, y lo que se destraba puede estar cuatro
    /// pisos más abajo.
    ///
    /// Se calcula comparando la regla contra sí misma en vez de hacer cuentas de
    /// tiers a mano, así el caso normal y los bordes salen de la misma fuente y
    /// no pueden desincronizarse.
    public static func newlyHireableFloors(
        maxTierBefore: Int,
        maxTierAfter: Int,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> [Int] {
        (0..<floorTable.count).filter { ordinal in
            !canHire(floorOrdinal: ordinal, maxTierReached: maxTierBefore, floorTable: floorTable, config: config)
                && canHire(floorOrdinal: ordinal, maxTierReached: maxTierAfter, floorTable: floorTable, config: config)
        }
    }

    /// Contrata el TIPO del quote. Requiere piso desbloqueado, compuerta abierta
    /// para ese tipo, slot libre y saldo.
    ///
    /// ⚠️ **La autorización por tipo vive acá desde el 2026-08-22**, y antes no
    /// existía en ningún lado: los guards eran todos del PISO, así que el quote
    /// de un T4 del callejón se le vendía a alguien que nunca mergeó. El
    /// docstring de `hireQuote(typeId:)` lo declaraba ("cotizar un tipo no es
    /// autorizarlo") y dejaba la compuerta en manos de la pantalla. Con la regla
    /// medida en tiers ese hueco se cierra: cotizar sigue sin autorizar, pero
    /// ahora quien autoriza es esta función y no la vista.
    @discardableResult
    public static func hire(
        quote: HireQuote,
        state: inout PlayerState,
        tower: inout TowerState,
        floorTable: FloorTable,
        config: EconomyConfig,
        countsAsPurchase: Bool
    ) throws -> TowerPlacement {
        let floor = floorTable[quote.floorOrdinal]
        guard state.run.unlockedFloors.contains(floor.id) else { throw TowerError.floorLocked }
        guard canHire(
            tier: quote.type.tier,
            maxTierReached: state.run.maxTierReached,
            floorTable: floorTable,
            config: config
        ) else { throw TowerError.hireLocked }
        guard state.run.coins >= quote.cost else { throw TowerError.insufficientCoins }
        guard let slot = tower.floors[quote.floorOrdinal].firstFreeSlot() else { throw TowerError.floorFull }

        state.run.coins -= quote.cost
        // `registerHire` mueve las dos curvas, la del piso y la del tipo, y va acá
        // y no en el caller para que ningún camino de contratación se la saltee.
        // Una contratación que no costó nada (`countsAsPurchase: false`) no es una
        // compra: encarecería la curva sin haber pagado, pero sí es una contratación.
        if countsAsPurchase {
            state.run.registerHire(floorId: floor.id, typeId: quote.type.id)
        }
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
        state.run.raiseFrontier(to: newType.tier)
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
