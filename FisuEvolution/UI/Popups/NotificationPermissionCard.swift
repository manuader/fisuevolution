import SwiftUI

/// "¿Te aviso cuando la caja fuerte se llene?" (PLAN-v2 E11): el segundo paso del
/// permiso, adentro del popup offline, que es cuando el jugador acaba de ver lo
/// que la torre juntó sin él.
///
/// Es la lección `notifications.permission` del tutorial: E9 la registra en
/// `TutorialCoverageTests` (y decide si lleva el candado de 5 s de las
/// `TutorialInlineCard`).
struct NotificationPermissionCard: View {
    static let lessonID = "notifications.permission"

    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        GameCard(style: .highlighted(Color("PaletteBlue"))) {
            VStack(spacing: Tokens.s8) {
                HStack(spacing: Tokens.s8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color("PaletteBlue"))
                        .accessibilityHidden(true)
                    Text("notifications.card.title")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("notifications.card.body")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Tokens.s8) {
                    ActionPill(
                        titleKey: "notifications.card.decline",
                        systemImage: "clock",
                        tint: Color("PaletteBrown"),
                        identifier: "notifications.card.decline",
                        action: decline
                    )
                    ActionPill(
                        titleKey: "notifications.card.accept",
                        systemImage: "bell.fill",
                        tint: Color("PaletteGreen"),
                        identifier: "notifications.card.accept",
                        action: accept
                    )
                }
            }
        }
        // Marcador para los tests: la tarjeta no es un control (trampa 9a-bis).
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("notifications.card")
        )
    }
}
