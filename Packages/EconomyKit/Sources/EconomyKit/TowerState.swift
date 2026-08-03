import Foundation

/// Posición concreta de una unidad en la torre (piso + slot). Modelo de JUEGO,
/// no de save: lo canónico es `run.units` (por tipo) y esto se reconstruye por
/// `TowerReconciler` en cada carga (spec §3.1/⚠️10).
public struct TowerPlacement: Sendable, Equatable {
    public let floorOrdinal: Int
    public let slot: Int
    public let typeId: String

    public init(floorOrdinal: Int, slot: Int, typeId: String) {
        self.floorOrdinal = floorOrdinal
        self.slot = slot
        self.typeId = typeId
    }
}

/// La torre en memoria: por piso, un array denso de slots (`capacity` posiciones,
/// nil = vacío). Invariante mantenida por `TowerActions`/`TowerReconciler`:
/// `unitCounts == run.units` después de cada mutación.
public struct TowerState: Sendable, Equatable {
    public struct Floor: Sendable, Equatable {
        public let def: FloorDef
        public var slots: [String?]

        public init(def: FloorDef) {
            self.def = def
            self.slots = Array(repeating: nil, count: def.capacity)
        }

        public var occupiedCount: Int { slots.lazy.compactMap { $0 }.count }
        public var isFull: Bool { occupiedCount >= def.capacity }
        public func firstFreeSlot() -> Int? { slots.firstIndex(where: { $0 == nil }) }
    }

    public var floors: [Floor]

    public init(floorTable: FloorTable) {
        self.floors = floorTable.floors.map(Floor.init(def:))
    }

    /// Conteo por tipo derivado de los slots (para verificar el invariante).
    public var unitCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for floor in floors {
            for case let typeId? in floor.slots {
                counts[typeId, default: 0] += 1
            }
        }
        return counts
    }

    public var totalUnits: Int {
        floors.reduce(0) { $0 + $1.occupiedCount }
    }

    public func typeId(floorOrdinal: Int, slot: Int) -> String? {
        guard floors.indices.contains(floorOrdinal),
              floors[floorOrdinal].slots.indices.contains(slot) else { return nil }
        return floors[floorOrdinal].slots[slot]
    }

    public func placements(onFloor floorOrdinal: Int) -> [TowerPlacement] {
        guard floors.indices.contains(floorOrdinal) else { return [] }
        return floors[floorOrdinal].slots.enumerated().compactMap { slot, typeId in
            typeId.map { TowerPlacement(floorOrdinal: floorOrdinal, slot: slot, typeId: $0) }
        }
    }
}
