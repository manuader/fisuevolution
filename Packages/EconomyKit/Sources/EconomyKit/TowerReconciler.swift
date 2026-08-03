import Foundation

/// Reconstruye la torre desde `run.units` contra el mapeo `floors[]` VIGENTE.
/// Corre en CADA carga (no solo en migraciones): así un remapeo tier→piso o un
/// cambio de capacidad entre versiones reacomoda las partidas existentes en vez
/// de romperlas (spec §3.1, drill de remapeo §7).
public enum TowerReconciler {
    public struct Outcome: Sendable, Equatable {
        public var tower: TowerState
        /// Unidades auto-mergeadas por overflow (pares del mismo tipo → tier+1).
        public var autoMerged: Int
        /// Unidades descartadas porque ni el auto-merge liberó capacidad
        /// (se descartan las de MENOR tier, regla de mayor-tier existente).
        public var discarded: [String: Int]
    }

    /// Coloca `run.units` piso por piso, resuelve overflow y sincroniza
    /// `run.unlockedFloors` y `run.maxTierReached`. Muta `run` (units si hubo
    /// auto-merge/descarte, unlockedFloors, maxTierReached).
    @discardableResult
    public static func reconcile(
        run: inout RunState,
        floorTable: FloorTable,
        tiers: TierRepository
    ) -> Outcome {
        var autoMerged = 0
        var discarded: [String: Int] = [:]

        // 1. Agrupar unidades por piso según el mapeo VIGENTE (tipos desconocidos
        //    —removidos de la config— se descartan con registro).
        var byFloor: [Int: [(type: CharacterType, count: Int)]] = [:]
        for (typeId, count) in run.units where count > 0 {
            guard let type = tiers.type(id: typeId), !type.isChoiceNode else {
                discarded[typeId, default: 0] += count
                run.units[typeId] = nil
                continue
            }
            let ordinal = floorTable.ordinal(forTier: type.tier)
            byFloor[ordinal, default: []].append((type, count))
        }

        // 2. Resolver overflow por piso: auto-merge de pares (sube de a tier+1,
        //    puede cruzar de piso), luego descarte de menor tier si sigue lleno.
        //    Iteramos hasta el punto fijo porque un auto-merge puede desbordar
        //    el piso siguiente.
        var settled = false
        var guardRail = 0
        while !settled && guardRail < 64 {
            settled = true
            guardRail += 1
            for ordinal in byFloor.keys.sorted() {
                let capacity = floorTable[ordinal].capacity
                var entries = byFloor[ordinal] ?? []
                var total = entries.reduce(0) { $0 + $1.count }
                guard total > capacity else { continue }
                settled = false

                // 2a. Auto-merge: pares del mismo tipo → mergesInto (via MergeRules
                //     para respetar carrera; saltea choice nodes sin carrera).
                entries.sort { $0.type.tier < $1.type.tier }
                var index = 0
                while total > capacity && index < entries.count {
                    let entry = entries[index]
                    let outcome = MergeRules.evaluate(
                        sourceTypeId: entry.type.id,
                        targetTypeId: entry.type.id,
                        chosenCareerPath: run.chosenCareerPath,
                        tiers: tiers
                    )
                    guard case .merged(let newTypeId) = outcome,
                          let newType = tiers.type(id: newTypeId),
                          entry.count >= 2
                    else {
                        index += 1
                        continue
                    }
                    let pairs = min(entry.count / 2, total - capacity)
                    guard pairs > 0 else { index += 1; continue }

                    entries[index].count -= pairs * 2
                    run.units[entry.type.id, default: 0] -= pairs * 2
                    if run.units[entry.type.id] == 0 { run.units[entry.type.id] = nil }
                    run.units[newTypeId, default: 0] += pairs
                    run.maxTierReached = max(run.maxTierReached, newType.tier)
                    autoMerged += pairs
                    total -= pairs * 2

                    let targetOrdinal = floorTable.ordinal(forTier: newType.tier)
                    if targetOrdinal == ordinal {
                        entries.append((newType, pairs))
                        total += pairs
                    } else {
                        byFloor[targetOrdinal, default: []].append((newType, pairs))
                    }
                }

                // 2b. Si sigue desbordado (tipos impares/sin merge legal): descartar
                //     los de MENOR tier hasta entrar en capacidad.
                entries.removeAll { $0.count <= 0 }
                entries.sort { $0.type.tier < $1.type.tier }
                var overflowIndex = 0
                total = entries.reduce(0) { $0 + $1.count }
                while total > capacity && overflowIndex < entries.count {
                    let drop = min(entries[overflowIndex].count, total - capacity)
                    entries[overflowIndex].count -= drop
                    let typeId = entries[overflowIndex].type.id
                    run.units[typeId, default: 0] -= drop
                    if run.units[typeId] == 0 { run.units[typeId] = nil }
                    discarded[typeId, default: 0] += drop
                    total -= drop
                    overflowIndex += 1
                }
                entries.removeAll { $0.count <= 0 }
                byFloor[ordinal] = entries
            }
        }

        // 3. Materializar slots (mayor tier primero dentro del piso: los "mejores"
        //    quedan en los primeros slots, estable ante reordenamientos).
        var tower = TowerState(floorTable: floorTable)
        for (ordinal, entries) in byFloor {
            var slot = 0
            for entry in entries.sorted(by: { $0.type.tier > $1.type.tier }) {
                for _ in 0..<entry.count where slot < tower.floors[ordinal].slots.count {
                    tower.floors[ordinal].slots[slot] = entry.type.id
                    slot += 1
                }
            }
        }

        // 4. Sincronizar unlockedFloors (por ID; nunca quita): pisos con unidades
        //    + pisos cuyo unlockTier ya fue alcanzado + siempre el piso base.
        var unlocked = Set(run.unlockedFloors)
        unlocked.insert(floorTable[0].id)
        for (ordinal, entries) in byFloor where !entries.isEmpty {
            unlocked.insert(floorTable[ordinal].id)
        }
        for floor in floorTable.floors where run.maxTierReached >= floor.unlockTier {
            unlocked.insert(floor.id)
        }
        // Orden estable por ordinal (los ids desconocidos de configs viejas se filtran).
        run.unlockedFloors = floorTable.floors.filter { unlocked.contains($0.id) }.map(\.id)

        return Outcome(tower: tower, autoMerged: autoMerged, discarded: discarded)
    }
}
