import SwiftUI

/// "Mientras no estabas…" — el premio offline ya se acreditó al aplicarse; este
/// popup es sólo la celebración, con el ritmo de la casa (E14 C15): el título,
/// la ilustración con el monto y abajo un solo botón, cobrar. El ×2 con video
/// sale después, en su propio pop-up (paso 2, E14b B29).
struct OfflineEarningsView: View {
    let reward: GameState.OfflineReward
    /// Cierra el popup (lo pone quien lo presenta).
    let onClose: () -> Void
    @Environment(GameState.self) private var gameState
    @Environment(NotificationsManager.self) private var notifications
    /// La tarjeta del permiso completo (E11). Se decide UNA vez al abrir: en el
    /// `body` aparecería o se iría a mitad de la lectura cuando el permiso o el
    /// contador cambian atrás.
    @State private var offersPermission = false

    /// La primera vuelta con popup offline es el momento del permiso completo
    /// (PLAN-v2 E11): el jugador acaba de ver lo que la torre juntó sin él.
    private func offerPermissionCardIfDue() async {
        guard let card = gameState.content?.notifications.permissionCard else { return }
        await notifications.refreshAuthorization()
        let now = Date().timeIntervalSince1970
        guard notifications.permissionCardDue(now: now, config: card) else { return }
        notifications.recordPermissionCardOffer(now: now)
        offersPermission = true
    }

    var body: some View {
        PopupContainer("offline.title", ribbonTint: Color("PaletteGreen"), onClose: onClose) {
            RewardIllustration(kind: .coins, size: 110)
            Text(verbatim: "+\(CoinFormatter.string(from: reward.amount))")
                .font(Tokens.display)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .accessibilityIdentifier("offline.amount")
            if offersPermission {
                NotificationPermissionCard(
                    accept: {
                        offersPermission = false
                        Task { await notifications.acceptPermissionCard() }
                    },
                    decline: { offersPermission = false }
                )
            }
        } actions: {
            GameButton("offline.collect", role: .free, identifier: "offline.collect", action: onClose)
        }
        .task { await offerPermissionCardIfDue() }
        .inlineLesson(.offline)
    }
}
