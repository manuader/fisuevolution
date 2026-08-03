import Foundation
import Testing
@testable import EconomyKit

// MARK: - FloorTable (F7 §3.1/§3.8): validación del init + lookups totales
//
// Configs rotas se arman inline (no alcanza con fxConfig, que es siempre válida).
// Los lookups sí usan la torre fixture: f1 {T1-2} / f2 {T3-4}, maxTier 4.

private func floorDef(
    _ id: String,
    _ firstTier: Int,
    _ lastTier: Int,
    capacity: Int = 5,
    unlockTier: Int? = nil
) -> FloorDef {
    FloorDef(
        id: id, background: "alley", firstTier: firstTier, lastTier: lastTier,
        capacity: capacity, incomeMultiplier: 1.0, unlockTierOverride: unlockTier
    )
}

@Suite("FloorTable: validación")
struct FloorTableValidationTests {
    @Test("floors[] vacío se rechaza")
    func rejectsEmptyFloors() {
        #expect(throws: FloorValidationError.empty) {
            try FloorTable(floors: [], maxTier: 4)
        }
    }

    @Test("id de piso duplicado se rechaza")
    func rejectsDuplicateId() {
        #expect(throws: FloorValidationError.duplicateId("f1")) {
            try FloorTable(floors: [floorDef("f1", 1, 2), floorDef("f1", 3, 4)], maxTier: 4)
        }
    }

    @Test("rango invertido (firstTier > lastTier) se rechaza")
    func rejectsInvertedRange() {
        #expect(throws: FloorValidationError.nonAscendingRange(floorId: "f1")) {
            try FloorTable(floors: [floorDef("f1", 2, 1)], maxTier: 2)
        }
    }

    @Test("pisos con rangos solapados se rechazan")
    func rejectsOverlappingFloors() {
        // f2 arranca en T2 pero f1 ya lo cubre: el error nombra a ambos.
        #expect(throws: FloorValidationError.overlappingFloors("f1", "f2")) {
            try FloorTable(floors: [floorDef("f1", 1, 2), floorDef("f2", 2, 4)], maxTier: 4)
        }
    }

    @Test("hueco entre pisos se rechaza con el tier huérfano")
    func rejectsGapBetweenFloors() {
        // T2 no pertenece a ningún piso.
        #expect(throws: FloorValidationError.tierNotCovered(2)) {
            try FloorTable(floors: [floorDef("f1", 1, 1), floorDef("f2", 3, 4)], maxTier: 4)
        }
    }

    @Test("pisos que no arrancan en tier 1 se rechazan")
    func rejectsFloorsNotStartingAtTierOne() {
        #expect(throws: FloorValidationError.tierNotCovered(1)) {
            try FloorTable(floors: [floorDef("f1", 2, 4)], maxTier: 4)
        }
    }

    @Test("escalera más alta que los pisos se rechaza")
    func rejectsLadderTallerThanFloors() {
        // Los pisos cubren hasta T3 pero la escalera llega a T5.
        #expect(throws: FloorValidationError.tierBeyondFloors(maxFloorTier: 3, maxTier: 5)) {
            try FloorTable(floors: [floorDef("f1", 1, 2), floorDef("f2", 3, 3)], maxTier: 5)
        }
    }

    @Test("capacity cero se rechaza")
    func rejectsZeroCapacity() {
        #expect(throws: FloorValidationError.invalidCapacity(floorId: "f1")) {
            try FloorTable(floors: [floorDef("f1", 1, 4, capacity: 0)], maxTier: 4)
        }
    }

    @Test("capacity negativa se rechaza")
    func rejectsNegativeCapacity() {
        #expect(throws: FloorValidationError.invalidCapacity(floorId: "f1")) {
            try FloorTable(floors: [floorDef("f1", 1, 4, capacity: -3)], maxTier: 4)
        }
    }

    @Test("unlockTierOverride por encima de maxTier se rechaza")
    func rejectsUnlockTierAboveMax() {
        #expect(throws: FloorValidationError.unlockTierOutOfRange(floorId: "f2")) {
            try FloorTable(
                floors: [floorDef("f1", 1, 2), floorDef("f2", 3, 4, unlockTier: 5)],
                maxTier: 4
            )
        }
    }

    @Test("unlockTierOverride menor a 1 se rechaza")
    func rejectsUnlockTierBelowOne() {
        #expect(throws: FloorValidationError.unlockTierOutOfRange(floorId: "f1")) {
            try FloorTable(floors: [floorDef("f1", 1, 4, unlockTier: 0)], maxTier: 4)
        }
    }
}

@Suite("FloorTable: lookups")
struct FloorTableLookupTests {
    let table: FloorTable

    init() throws {
        table = try fxFloorTable()
    }

    @Test("input desordenado queda ordenado por firstTier")
    func unorderedInputGetsSortedByFirstTier() throws {
        // El JSON puede venir en cualquier orden: el ordinal lo define el rango.
        let shuffled = try FloorTable(
            floors: [floorDef("top", 3, 4), floorDef("base", 1, 2)],
            maxTier: 4
        )
        #expect(shuffled.count == 2)
        #expect(shuffled[0].id == "base")
        #expect(shuffled[1].id == "top")
        #expect(shuffled.floors.map(\.id) == ["base", "top"])
    }

    @Test("ordinal(forTier:) mapea cada tier del rango a su piso")
    func ordinalForEachTierInRange() {
        #expect(table.ordinal(forTier: 1) == 0)
        #expect(table.ordinal(forTier: 2) == 0)
        #expect(table.ordinal(forTier: 3) == 1)
        #expect(table.ordinal(forTier: 4) == 1)
    }

    @Test("tier por debajo del rango clampa al piso del tier 1")
    func tierBelowRangeClampsToFirstFloor() {
        #expect(table.ordinal(forTier: 0) == 0)
        #expect(table.ordinal(forTier: -7) == 0)
    }

    @Test("tier por encima del rango clampa al último piso")
    func tierAboveRangeClampsToLastFloor() {
        #expect(table.ordinal(forTier: 5) == 1)
        #expect(table.ordinal(forTier: 99) == 1)
    }

    @Test("floor(forTier:) devuelve el FloorDef correcto, con clamp incluido")
    func floorForTierReturnsMatchingDef() {
        #expect(table.floor(forTier: 1).id == "f1")
        #expect(table.floor(forTier: 4).id == "f2")
        #expect(table.floor(forTier: 99).id == "f2")
    }

    @Test("ordinal(of:) resuelve ids conocidos y da nil para desconocidos")
    func ordinalByIdResolvesKnownAndRejectsUnknown() {
        #expect(table.ordinal(of: "f1") == 0)
        #expect(table.ordinal(of: "f2") == 1)
        #expect(table.ordinal(of: "ghost") == nil)
    }

    @Test("unlockTier defaultea a firstTier sin override")
    func unlockTierDefaultsToFirstTier() {
        // La fixture no overridea: cada piso se desbloquea con su tier base.
        #expect(table[0].unlockTier == 1)
        #expect(table[1].unlockTier == 3)
    }

    @Test("unlockTier devuelve el override cuando existe")
    func unlockTierHonorsOverride() throws {
        let custom = try FloorTable(
            floors: [floorDef("f1", 1, 2), floorDef("f2", 3, 4, unlockTier: 4)],
            maxTier: 4
        )
        #expect(custom[1].unlockTier == 4)
        #expect(custom[1].firstTier == 3)
    }

    @Test("FloorDef.contains(tier:) respeta ambos bordes")
    func containsChecksBothBoundaries() {
        let def = floorDef("f", 2, 3)
        #expect(!def.contains(tier: 1))
        #expect(def.contains(tier: 2))
        #expect(def.contains(tier: 3))
        #expect(!def.contains(tier: 4))
    }
}
