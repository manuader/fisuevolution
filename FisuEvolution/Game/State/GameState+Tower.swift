import EconomyKit
import Foundation

/// Accesores de la torre que consumen la escena y las vistas. Separado de
/// `GameState.swift` para que el frente de navegación no comparta archivo con
/// los otros cinco dominios.
extension GameState {
    var floorTable: FloorTable? { content?.floorTable }

    var visibleFloorDef: FloorDef? {
        content.map { $0.floorTable[visibleFloorOrdinal] }
    }

    /// Specials anclados al piso visible (⚠️5: no ocupan slot ni se mergean —
    /// quedan de decorado en el piso donde cayeron). Un special sin ancla (o con
    /// un ancla de una config vieja) simplemente no se dibuja.
    var visibleFloorSpecials: [SpecialsConfig.Special] {
        guard let content, let player, let floorID = visibleFloorDef?.id else { return [] }
        return content.specials.specials.filter {
            player.meta.ownedSpecials.contains($0.id) && player.meta.specialAnchors[$0.id] == floorID
        }
    }

    /// Placements del piso visible (la escena solo dibuja este piso en F7.1).
    var visiblePlacements: [TowerPlacement] {
        tower?.placements(onFloor: visibleFloorOrdinal) ?? []
    }

    var visibleFloorOccupancy: (occupied: Int, capacity: Int) {
        floorOccupancy(ordinal: visibleFloorOrdinal)
    }

    /// Ocupación de un piso cualquiera: la contratación puede caer en uno que no
    /// es el visible, y ahí el lleno que importa es el del destino.
    func floorOccupancy(ordinal: Int) -> (occupied: Int, capacity: Int) {
        guard let tower, tower.floors.indices.contains(ordinal) else { return (0, 0) }
        let floor = tower.floors[ordinal]
        return (floor.occupiedCount, floor.def.capacity)
    }

    /// Cambia el piso visible dentro de los abiertos y permite asomarse a uno
    /// bloqueado. Así se ve la meta siguiente sin poder contratar ni saltar más.
    func setVisibleFloor(_ ordinal: Int) {
        guard let content, let player else { return }
        let unlockedOrdinals = content.floorTable.floors.enumerated()
            .filter { player.run.unlockedFloors.contains($0.element.id) }
            .map(\.offset)
        guard let maxUnlocked = unlockedOrdinals.max() else { return }
        let maxVisible = min(maxUnlocked + 1, content.floorTable.floors.count - 1)
        let clamped = min(max(0, ordinal), maxVisible)
        guard clamped != visibleFloorOrdinal else { return }
        visibleFloorOrdinal = clamped
        bumpBoard()
    }

    /// Navega exactamente un piso en la torre. El límite superior es la vista
    /// previa del próximo piso bloqueado, para que SpriteKit no anime más allá.
    @discardableResult
    func moveVisibleFloor(by direction: Int) -> Bool {
        guard direction == -1 || direction == 1 else { return false }
        let previous = visibleFloorOrdinal
        setVisibleFloor(previous + direction)
        return visibleFloorOrdinal != previous
    }
}
