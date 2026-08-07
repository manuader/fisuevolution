import EconomyKit
import Foundation

/// Una fila del mapa de la torre (RF-08), ya resuelta: la vista la dibuja sin
/// volver a preguntarle nada al estado ni conocer `PlayerState`.
///
/// No trae el nombre del piso: las claves de localización no se pueden armar
/// por interpolación (`LocalizedStringKey` no las resuelve), así que el mapeo
/// id→clave vive estático en `TowerNaming` y la vista lo consulta con el `id`.
struct FloorMapEntry: Identifiable, Equatable {
    let id: String
    let ordinal: Int
    /// Clave del manifest para la miniatura: el fondo REAL del piso.
    let backgroundKey: String
    let occupied: Int
    let capacity: Int
    let isUnlocked: Bool
    /// El piso donde está parado el jugador ahora mismo.
    let isVisible: Bool
}

/// Accesores de la torre que consumen la escena y las vistas. Separado de
/// `GameState.swift` para que el frente de navegación no comparta archivo con
/// los otros cinco dominios.
extension GameState {
    var floorTable: FloorTable? { content?.floorTable }

    /// La torre entera para el mapa, **de Dios para abajo**: se lee como se ve,
    /// con el callejón al final.
    ///
    /// Todo sale de `floors[]` —el largo, los ids, los fondos y las
    /// capacidades—, así que pasar la torre de once pisos a diez no toca ni
    /// esta proyección ni la vista.
    ///
    /// Es computada y no una proyección observada porque el mapa es un modal:
    /// se arma al abrirlo y la vista se re-evalúa con `boardVersion`, que es lo
    /// único que puede cambiar una ocupación mientras está en pantalla.
    var floorMap: [FloorMapEntry] {
        guard let content, let player else { return [] }
        let unlocked = Set(player.run.unlockedFloors)
        return content.floorTable.floors.enumerated().reversed().map { ordinal, definition in
            FloorMapEntry(
                id: definition.id,
                ordinal: ordinal,
                backgroundKey: definition.background,
                occupied: floorOccupancy(ordinal: ordinal).occupied,
                // La capacidad sale de la definición y no de la torre en
                // memoria: un piso todavía cerrado ya tiene que poder mostrar
                // cuánto entra, que es la mitad de la información del mapa.
                capacity: definition.capacity,
                isUnlocked: unlocked.contains(definition.id),
                isVisible: ordinal == visibleFloorOrdinal
            )
        }
    }

    /// Salta directo a un piso del mapa. Valida contra el MISMO dato que las
    /// flechas del HUD: si el piso no está desbloqueado no hace nada, ni
    /// siquiera se asoma —el preview del piso cerrado es un premio de las
    /// flechas, no un destino que se elige de una lista—.
    func jumpToFloor(ordinal: Int) {
        guard let content, let player,
              content.floorTable.floors.indices.contains(ordinal),
              player.run.unlockedFloors.contains(content.floorTable[ordinal].id) else { return }
        setVisibleFloor(ordinal)
    }

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
