import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
        /// Hay un save pero no se pudo leer: no se juega ni se escribe nada hasta
        /// que el jugador reintente o empiece de nuevo.
        case recovery(UnreadableSave)
    }

    struct CareerPrompt: Identifiable, Equatable {
        let id = UUID()
        let options: [CharacterType]
        let floorOrdinal: Int
        /// Slots de ese piso (el merge diferido ocurre donde se arrastró).
        let sourceCell: Int
        let targetCell: Int
    }

    /// Modelo mínimo de la ficha abierta desde un personaje del tablero. Mantiene
    /// el slot para que despedir siga siendo una acción explícita y confirmable.
    struct CharacterSheet: Identifiable, Equatable {
        let id = UUID()
        let type: CharacterType
        /// Slot del piso visible.
        let cellIndex: Int
        let instanceCount: Int
        let isUnlocked: Bool
        let canAfford: Bool
        /// Se puede "dejar de contratar" si no es la última unidad de la torre.
        let canDismiss: Bool
    }

    struct OfflineReward: Identifiable, Equatable {
        let id = UUID()
        let amount: Double
    }

    /// Skin recién ganada por milestone. Se publica una sola vez por skin (el
    /// crédito en MetaState es idempotente) para que la UI celebre sin volver a
    /// consultar el catálogo ni el estado.
    struct SkinAward: Identifiable, Equatable {
        let id: String
        let characterType: CharacterType
    }

    /// Lo que salió de un cofre recién abierto. El id es propio y no el de la
    /// pinta: el premio puede ser plata, y dos cofres seguidos que dan lo mismo
    /// tienen que ser dos presentaciones distintas para la vista.
    struct ChestReward: Identifiable, Equatable {
        let id = UUID().uuidString
        let outcome: ChestOutcome
        /// Cuánta plata pagó, cuando el premio es plata.
        ///
        /// Viaja acá y no adentro de `ChestOutcome` porque el sorteo no lo
        /// conoce: el monto sale de `passiveUnlockCost × factor`, que es
        /// economía del jugador y no del cofre. Y viaja porque la animación
        /// **apaga el HUD**: sin el número en el payload, la carta del premio de
        /// plata sería la única del juego que celebra sin decir cuánto.
        var coins: Double?
    }

    /// Proyección chica y estable para los controles de navegación de la torre.
    /// La UI no inspecciona `PlayerState` ni `TowerState`: recibe sólo el piso
    /// visible, su capacidad y los límites desbloqueados de la run actual.
    struct TowerNavigation: Equatable {
        let floorID: String
        let ordinal: Int
        let totalFloors: Int
        let occupied: Int
        let capacity: Int
        let canNavigateUp: Bool
        let canNavigateDown: Bool

        static let empty = TowerNavigation(
            floorID: "",
            ordinal: 0,
            totalFloors: 0,
            occupied: 0,
            capacity: 0,
            canNavigateUp: false,
            canNavigateDown: false
        )
    }

    /// Mensaje efímero que la escena o el HUD presenta sin conocer errores de
    /// EconomyKit. La lógica conserva el error tipado; la UI recibe intención.
    struct TowerNotice: Identifiable, Equatable {
        enum Kind: Equatable {
            case floorFull
            case destinationFloorFull(floorID: String)
            /// Un piso que antes no dejaba contratar ahora sí.
            case hireUnlocked(floorID: String)
            /// El Corralito rebotó una compra de plata.
            case spendingFrozen
        }

        let id = UUID()
        let kind: Kind
    }

    /// Los tres hitos del FTUE, como proyección `Equatable` para que publicarlos
    /// no invalide SwiftUI en cada `refreshProjections`.
    struct FTUEMilestones: Equatable {
        var tapped = false
        var spawned = false
        var merged = false
    }

    /// Qué pide iluminar el tutorial sobre el tablero.
    ///
    /// No se pide "el slot N": el slot lo resuelve la escena contra las
    /// unidades que hay de verdad, así que el recorte sigue cayendo bien
    /// aunque cambie el layout o el personaje se mueva.
    enum TutorialBoardTarget: Equatable {
        /// Cualquier unidad del piso visible (paso "tocá al Fisura").
        case anyUnit
        /// Una de un par mergeable, si existe (paso "arrastrá uno sobre otro").
        case mergePair
    }

    enum DropResolution {
        /// `evolvedTo` presente cuando el merge alcanzó un tier nuevo (reveal).
        /// `promotedToFloor` presente cuando el resultado ascendió de piso.
        case merged(
            targetCell: Int,
            evolvedTo: CharacterType?,
            promotedType: CharacterType?,
            promotedToFloor: Int?,
            unlockedFloorId: String?
        )
        case moved
        case careerPending
        case snapBack
    }
}
