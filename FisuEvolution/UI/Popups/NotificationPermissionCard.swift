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
    /// La campana: la imagen principal de la tarjeta.
    static let imageSide: CGFloat = 88

    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        GameCard(style: .highlighted(Color("PaletteBlue"))) {
            VStack(spacing: Tokens.s8) {
                GameIcon(artKey: "ui_notif_campana", size: Self.imageSide) {
                    IconCanvas { MarkDisc(mark: "!", fill: Color("PaletteBlue")) }
                }
                .accessibilityHidden(true)
                Text("notifications.card.title")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                Text("notifications.card.body")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                HStack(spacing: Tokens.s8) {
                    GameButton(
                        "notifications.card.decline", role: .neutral, medallion: .glyph(.clock),
                        fullWidth: true, identifier: "notifications.card.decline", action: decline
                    )
                    GameButton(
                        "notifications.card.accept", role: .free, medallion: .glyph(.bell),
                        fullWidth: true, identifier: "notifications.card.accept", action: accept
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
