import SwiftUI

/// Las dos esquinas de arriba, bajo el HUD (PLAN-v2 E14 C9). A la izquierda, los
/// sellos de premios con su cinta de estado; a la derecha, en este orden fijo:
/// la tarjeta del personaje especial, el sello de la oferta, los relojes de
/// eventos y los boosts. Cada cosa tiene su lugar y nada se apila encima de otra.
///
/// Las dos columnas sólo reciben toques donde hay un control: el resto del
/// ancho es el tablero.
struct CornersView: View {
    @Environment(GameState.self) private var gameState
    @Binding var railOffer: SideRailKind?
    let onOffer: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            SideRailView(offer: $railOffer)
                .zIndex(1)
            Spacer(minLength: 0)
            rightColumn
        }
        .padding(.horizontal, SideRailLayout.edgeInset)
        .playColumn()
    }

    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            StageChips()
            if !gameState.visibleOffers().isEmpty {
                OfferChip(onOpen: onOffer)
                    .padding(.bottom, SideRailLayout.spacing)
            }
            if !gameState.activeBonuses.isEmpty {
                ActiveBonusBar(bonuses: gameState.activeBonuses) { gameState.openEventPopup(id: $0) }
            }
        }
    }
}
