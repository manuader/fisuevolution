import EconomyKit

/// Adónde lleva «¡Vamos!» en un evento de compra (C25): la pantalla y el ítem en foco.
struct ShopRequest: Equatable {
    let destination: EventCatalog.ShopDestination
    let focus: String?

    var screen: GameScreen {
        destination == .store ? .store : .upgrades
    }
}
