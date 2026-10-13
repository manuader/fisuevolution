import SwiftUI

/// "Mientras no estabas…" — el premio offline ya se acreditó al aplicarse; este
/// popup es sólo la celebración, con el ritmo de la casa (E14 C15): el título,
/// la ilustración con el monto y abajo los botones —el video del ×2 y cobrar,
/// lado a lado— en el `PopupContainer`.
struct OfflineEarningsView: View {
    let reward: GameState.OfflineReward
    /// Cierra el popup (lo pone quien lo presenta).
    let onClose: () -> Void
    @Environment(GameState.self) private var gameState
    @Environment(AdsCoordinator.self) private var ads
    @Environment(NotificationsManager.self) private var notifications
    /// La tarjeta del permiso completo (E11). Se decide UNA vez al abrir: en el
    /// `body` aparecería o se iría a mitad de la lectura cuando el permiso o el
    /// contador cambian atrás.
    @State private var offersPermission = false

    /// El video está cargando o corriendo (lo escribe `RewardedOfferButton`): el
    /// botón de cobrar no puede cerrar el popup abajo del anuncio. La oferta se
    /// muestra mientras no se haya duplicado, haya o no video ya cargado: el
    /// botón espera la carga y, si no hay videos, lo dice.
    @State private var watching = false
    /// Ya se duplicó EN ESTE popup. Se lee al abrir desde `GameState` —que es
    /// quien lo sabe si el popup se reabre— y se sube acá para que la vista
    /// reaccione sin observar `player`.
    @State private var doubled = false

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

    private func doubleReward() {
        gameState.doubleOfflineReward(reward)
        doubled = true
    }

    /// Con el anuncio en vuelo no se cierra: el anuncio quedaría sobre el
    /// tablero sin dónde acreditar.
    private func close() {
        if !watching { onClose() }
    }

    var body: some View {
        PopupContainer("offline.title", ribbonTint: Color("PaletteGreen"), onClose: close) {
            RewardIllustration(kind: .coins, size: 96)
            // Duplicado, el monto que se muestra es el TOTAL: el jugador miró un
            // video para ver un número más grande, así que el número más grande
            // es lo que tiene que ver.
            Text(verbatim: "+\(CoinFormatter.string(from: doubled ? reward.amount * 2 : reward.amount))")
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
            if !doubled {
                RewardedOfferButton(
                    title: String(localized: "offline.double"),
                    identifier: "offline.double",
                    placement: .offlineX2,
                    isBusy: $watching,
                    gameRole: .video,
                    onRewarded: doubleReward
                )
            }
            GameButton("offline.collect", role: .free, identifier: "offline.collect", action: close)
        }
        .task {
            doubled = gameState.offlineRewardDoubled
            await offerPermissionCardIfDue()
        }
        .inlineLesson(.offline)
    }
}
