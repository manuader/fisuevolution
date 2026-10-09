import Foundation

/// Un cambio del tablero que no hizo el jugador. Se planea en el acto y se
/// aplica recién en su turno, a la vista: así no hay evoluciones sin ver.
public struct BoardChange: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case merge(floorOrdinal: Int, typeId: String, sourceSlot: Int, targetSlot: Int, newTypeId: String)
        case evolve(floorOrdinal: Int, slot: Int, typeId: String, newTypeId: String)
        case arrival(typeId: String)
        case departure(floorOrdinal: Int, slot: Int, typeId: String)
    }

    public enum Origin: String, Sendable, Equatable {
        case eventStartup
        case eventBlanqueo
        /// "Fusionar todo" por video: Regalos y la columna de E7b.
        case rewardedMergeAll
        case rewardedRareUnit
        case career
        case debug
    }

    /// Un eslabón de "Fusionar todo": la escena encadena los de la misma cadena
    /// en un solo turno, con su ritmo y su contador.
    public struct Chain: Sendable, Equatable {
        public let id: UUID
        public let index: Int
        public let count: Int

        public init(id: UUID, index: Int, count: Int) {
            self.id = id
            self.index = index
            self.count = count
        }

        public var isLast: Bool { index == count - 1 }
    }

    public let id: UUID
    public let kind: Kind
    public let origin: Origin
    public let chain: Chain?

    public init(id: UUID = UUID(), kind: Kind, origin: Origin, chain: Chain? = nil) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.chain = chain
    }

    public var resultTypeId: String? {
        switch kind {
        case .merge(_, _, _, _, let newTypeId), .evolve(_, _, _, let newTypeId): newTypeId
        case .arrival(let typeId): typeId
        case .departure: nil
        }
    }

    /// El piso al que la escena tiene que ir antes de reproducirlo.
    public func floorOrdinal(floorTable: FloorTable, tiers: TierRepository) -> Int? {
        switch kind {
        case .merge(let ordinal, _, _, _, _), .evolve(let ordinal, _, _, _), .departure(let ordinal, _, _):
            ordinal
        case .arrival(let typeId):
            tiers.type(id: typeId).map { floorTable.ordinal(forTier: $0.tier) }
        }
    }

    func replanned(_ kind: Kind) -> BoardChange {
        BoardChange(id: id, kind: kind, origin: origin, chain: chain)
    }
}

public struct BoardChangeOutcome: Sendable, Equatable {
    /// Dónde quedó el resultado en el piso del cambio; `nil` si ascendió o salió.
    public let slot: Int?
    public let resultTypeId: String?
    public let tierBefore: Int
    public let promotedToFloor: Int?
    public let unlockedFloorId: String?
}

public enum BoardChangePlanner {
    /// El par más alto de la torre cuyo resultado tiene lugar. Nunca toca el par
    /// que pide elegir carrera. A igual tier gana el id más bajo: el plan no
    /// depende del orden de un diccionario.
    public static func planAutoMerge(
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        origin: BoardChange.Origin
    ) -> BoardChange? {
        let pairs = tower.floors.indices.flatMap { ordinal in
            Dictionary(grouping: tower.placements(onFloor: ordinal), by: \.typeId)
                .compactMap { typeId, placements -> (ordinal: Int, typeId: String, slots: [Int], tier: Int)? in
                    guard placements.count >= 2, let type = tiers.type(id: typeId) else { return nil }
                    return (ordinal, typeId, placements.map(\.slot).sorted(), type.tier)
                }
        }
        for pair in pairs.sorted(by: { (-$0.tier, $0.ordinal, $0.typeId) < (-$1.tier, $1.ordinal, $1.typeId) }) {
            guard case .merged(let newTypeId) = MergeRules.evaluate(
                sourceTypeId: pair.typeId, targetTypeId: pair.typeId,
                chosenCareerPath: state.run.chosenCareerPath, tiers: tiers
            ), fits(newTypeId, from: pair.ordinal, tower: tower, tiers: tiers, floorTable: floorTable)
            else { continue }
            return BoardChange(
                kind: .merge(floorOrdinal: pair.ordinal, typeId: pair.typeId,
                             sourceSlot: pair.slots[0], targetSlot: pair.slots[1], newTypeId: newTypeId),
                origin: origin
            )
        }
        return nil
    }

    /// "Fusionar todo" (PLAN-v2 §2): todos los pares de un piso, en el orden en
    /// que se funden. Lo que sale de una fusión vuelve a contar, así que la
    /// cadena sube sola; nunca toca el par que pide carrera ni planea un ascenso
    /// sin lugar arriba. Se planea sobre una copia: cada cambio se juega después
    /// en su turno, revalidado como cualquier otro. Cada cambio lleva su eslabón
    /// (`chain`): la escena los juega en un solo turno.
    public static func planMergeAll(
        floorOrdinal: Int,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        origin: BoardChange.Origin
    ) -> [BoardChange] {
        guard tower.floors.indices.contains(floorOrdinal) else { return [] }
        var scratchState = state
        var scratchTower = tower
        var plan: [BoardChange] = []
        // Cada fusión saca al menos una unidad del piso: el tope es su capacidad.
        for _ in 0..<tower.floors[floorOrdinal].slots.count {
            guard let change = lowestPair(onFloor: floorOrdinal, state: scratchState, tower: scratchTower,
                                          tiers: tiers, floorTable: floorTable, origin: origin),
                  (try? BoardChangeApplier.apply(change, state: &scratchState, tower: &scratchTower,
                                                tiers: tiers, floorTable: floorTable, config: config)) != nil
            else { break }
            plan.append(change)
        }
        let chainID = UUID()
        return plan.enumerated().map { index, change in
            BoardChange(id: change.id, kind: change.kind, origin: change.origin,
                        chain: BoardChange.Chain(id: chainID, index: index, count: plan.count))
        }
    }

    /// El par más bajo del piso que se puede fundir: la cadena sube de abajo.
    private static func lowestPair(
        onFloor ordinal: Int,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        origin: BoardChange.Origin
    ) -> BoardChange? {
        let groups = Dictionary(grouping: tower.placements(onFloor: ordinal), by: \.typeId)
            .compactMap { typeId, placements -> (typeId: String, slots: [Int], tier: Int)? in
                guard placements.count >= 2, let type = tiers.type(id: typeId) else { return nil }
                return (typeId, placements.map(\.slot).sorted(), type.tier)
            }
            .sorted { $0.tier == $1.tier ? $0.typeId < $1.typeId : $0.tier < $1.tier }
        for group in groups {
            guard case .merged(let newTypeId) = MergeRules.evaluate(
                sourceTypeId: group.typeId, targetTypeId: group.typeId,
                chosenCareerPath: state.run.chosenCareerPath, tiers: tiers
            ), fits(newTypeId, from: ordinal, tower: tower, tiers: tiers, floorTable: floorTable)
            else { continue }
            return BoardChange(
                kind: .merge(floorOrdinal: ordinal, typeId: group.typeId,
                             sourceSlot: group.slots[0], targetSlot: group.slots[1], newTypeId: newTypeId),
                origin: origin
            )
        }
        return nil
    }

    /// La mejor unidad que puede subir sola un tier. Un nodo de carrera no se
    /// cruza solo: eso lo decide el jugador.
    ///
    /// `maxSourceTier`: el tier más alto que puede evolucionar. La Startup pasa
    /// `frontera − 2` y así nunca revela un tier (PLAN-v2 E13). `revalidate`
    /// conserva el tope: replanea con otra unidad del mismo tipo.
    public static func planEvolve(
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        maxSourceTier: Int,
        origin: BoardChange.Origin
    ) -> BoardChange? {
        let units = tower.floors.indices
            .flatMap { tower.placements(onFloor: $0) }
            .compactMap { placement in tiers.type(id: placement.typeId).map { (placement, $0) } }
            .sorted { (-$0.1.tier, $0.0.floorOrdinal, $0.0.slot) < (-$1.1.tier, $1.0.floorOrdinal, $1.0.slot) }
        for (placement, type) in units where type.tier <= maxSourceTier {
            guard let nextId = type.mergesInto, let next = tiers.type(id: nextId), !next.isChoiceNode,
                  fits(nextId, from: placement.floorOrdinal, tower: tower, tiers: tiers, floorTable: floorTable)
            else { continue }
            return BoardChange(
                kind: .evolve(floorOrdinal: placement.floorOrdinal, slot: placement.slot, typeId: type.id, newTypeId: nextId),
                origin: origin
            )
        }
        return nil
    }

    /// El tipo de un premio "de frontera − n" (el video del personaje de regalo):
    /// respeta la carrera y nunca baja del tier 1.
    public static func giftType(tiersBelowFrontier: Int, state: PlayerState, tiers: TierRepository) -> CharacterType? {
        let tier = max(1, state.run.maxTierReached - tiersBelowFrontier)
        let path = state.run.chosenCareerPath
        return tiers.concreteTypes.first { $0.tier == tier && (path.map($0.id.hasSuffix) ?? true) }
            ?? tiers.concreteTypes.first { $0.tier == tier }
    }

    public static func planArrival(
        typeId: String,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        origin: BoardChange.Origin
    ) -> BoardChange? {
        guard let type = tiers.type(id: typeId), !type.isChoiceNode else { return nil }
        let ordinal = floorTable.ordinal(forTier: type.tier)
        guard state.run.unlockedFloors.contains(floorTable[ordinal].id),
              tower.floors[ordinal].firstFreeSlot() != nil
        else { return nil }
        return BoardChange(kind: .arrival(typeId: typeId), origin: origin)
    }

    /// Lo planeado contra el tablero de AHORA: sigue valiendo, se replanea la
    /// misma intención (mismo id y origen), o `nil` si ya no hay cómo.
    public static func revalidate(
        _ change: BoardChange,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> BoardChange? {
        switch change.kind {
        case let .merge(ordinal, typeId, source, target, newTypeId):
            guard fits(newTypeId, from: ordinal, tower: tower, tiers: tiers, floorTable: floorTable) else { return nil }
            if source != target,
               tower.typeId(floorOrdinal: ordinal, slot: source) == typeId,
               tower.typeId(floorOrdinal: ordinal, slot: target) == typeId {
                return change
            }
            let slots = tower.placements(onFloor: ordinal).filter { $0.typeId == typeId }.map(\.slot).sorted()
            guard slots.count >= 2 else { return nil }
            return change.replanned(.merge(floorOrdinal: ordinal, typeId: typeId,
                                           sourceSlot: slots[0], targetSlot: slots[1], newTypeId: newTypeId))
        case let .evolve(ordinal, slot, typeId, newTypeId):
            guard fits(newTypeId, from: ordinal, tower: tower, tiers: tiers, floorTable: floorTable) else { return nil }
            if tower.typeId(floorOrdinal: ordinal, slot: slot) == typeId { return change }
            return tower.placements(onFloor: ordinal).first { $0.typeId == typeId }
                .map { change.replanned(.evolve(floorOrdinal: ordinal, slot: $0.slot, typeId: typeId, newTypeId: newTypeId)) }
        case let .arrival(typeId):
            return planArrival(typeId: typeId, state: state, tower: tower, tiers: tiers,
                               floorTable: floorTable, origin: change.origin).map { _ in change }
        case let .departure(ordinal, slot, typeId):
            if tower.typeId(floorOrdinal: ordinal, slot: slot) == typeId { return change }
            return tower.placements(onFloor: ordinal).first { $0.typeId == typeId }
                .map { change.replanned(.departure(floorOrdinal: ordinal, slot: $0.slot, typeId: typeId)) }
        }
    }

    /// Lo único que apaga la UI: un personaje que no se reveló o un piso que no
    /// estaba abierto (la misma regla que el merge del jugador).
    public static func revealsSomethingNew(
        _ change: BoardChange,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> Bool {
        guard let resultTypeId = change.resultTypeId, let result = tiers.type(id: resultTypeId) else { return false }
        let destination = floorTable[floorTable.ordinal(forTier: result.tier)]
        return result.tier > state.run.revealedTier || !state.run.unlockedFloors.contains(destination.id)
    }

    private static func fits(
        _ newTypeId: String,
        from ordinal: Int,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> Bool {
        guard let newType = tiers.type(id: newTypeId) else { return false }
        let destination = floorTable.ordinal(forTier: newType.tier)
        return destination == ordinal || tower.floors[destination].firstFreeSlot() != nil
    }
}

public enum BoardChangeApplier {
    public static func apply(
        _ change: BoardChange,
        state: inout PlayerState,
        tower: inout TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) throws -> BoardChangeOutcome {
        let tierBefore = state.run.maxTierReached
        guard isStillWhatWasPlanned(change, in: tower) else { throw TowerError.invalidSlot }
        switch change.kind {
        case let .merge(ordinal, _, source, target, newTypeId):
            let result = try TowerActions.applyMerge(
                floorOrdinal: ordinal, sourceSlot: source, targetSlot: target, newTypeId: newTypeId,
                state: &state, tower: &tower, tiers: tiers, floorTable: floorTable, config: config
            )
            return outcome(result, tierBefore: tierBefore)
        case let .evolve(ordinal, slot, _, newTypeId):
            let result = try TowerActions.evolveUnit(
                floorOrdinal: ordinal, slot: slot, newTypeId: newTypeId,
                state: &state, tower: &tower, tiers: tiers, floorTable: floorTable, config: config
            )
            return outcome(result, tierBefore: tierBefore)
        case let .arrival(typeId):
            let placement = try TowerActions.placeUnit(
                typeId: typeId, state: &state, tower: &tower, tiers: tiers, floorTable: floorTable, config: config
            )
            return BoardChangeOutcome(slot: placement.slot, resultTypeId: typeId, tierBefore: tierBefore,
                                      promotedToFloor: nil, unlockedFloorId: nil)
        case let .departure(ordinal, slot, _):
            guard TowerActions.removeUnit(floorOrdinal: ordinal, slot: slot, state: &state, tower: &tower) else {
                throw TowerError.invalidSlot
            }
            return BoardChangeOutcome(slot: nil, resultTypeId: nil, tierBefore: tierBefore,
                                      promotedToFloor: nil, unlockedFloorId: nil)
        }
    }

    /// El plan se hizo mirando unos slots: si hoy tienen otro tipo, aplicarlo
    /// tocaría a quien no corresponde.
    private static func isStillWhatWasPlanned(_ change: BoardChange, in tower: TowerState) -> Bool {
        switch change.kind {
        case let .merge(ordinal, typeId, source, target, _):
            tower.typeId(floorOrdinal: ordinal, slot: source) == typeId
                && tower.typeId(floorOrdinal: ordinal, slot: target) == typeId
        case let .evolve(ordinal, slot, typeId, _), let .departure(ordinal, slot, typeId):
            tower.typeId(floorOrdinal: ordinal, slot: slot) == typeId
        case .arrival:
            true
        }
    }

    private static func outcome(_ result: TowerMergeResult, tierBefore: Int) -> BoardChangeOutcome {
        switch result {
        case let .stayed(_, slot, newTypeId):
            BoardChangeOutcome(slot: slot, resultTypeId: newTypeId, tierBefore: tierBefore,
                               promotedToFloor: nil, unlockedFloorId: nil)
        case let .promoted(toFloor, _, newTypeId, unlockedFloorId):
            BoardChangeOutcome(slot: nil, resultTypeId: newTypeId, tierBefore: tierBefore,
                               promotedToFloor: toFloor, unlockedFloorId: unlockedFloorId)
        }
    }
}
