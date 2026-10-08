import SwiftUI

/// "Mientras no estabas…" — el premio offline ya se acreditó al aplicarse; esta
/// hoja es sólo la celebración. F4 le suma el "doblar con un video".
///
/// Habla la misma anatomía que `DailyRewardView`, su gemelo de marco (el
/// mismo `PanelCard` con el moño asomando): banner de título, el monto sobre
/// la `GameCard` amarilla
/// —el acento de premio de la casa— y `ActionPill` verde como salida. Antes era
/// un `borderedProminent` de sistema sobre fuentes sueltas: se leía como una
/// alerta de iOS pegada adentro del moño.
struct OfflineEarningsView: View {
    let reward: GameState.OfflineReward
    @Environment(\.dismiss) private var dismiss
    @Environment(GameState.self) private var gameState
    @Environment(AdsCoordinator.self) private var ads
    @Environment(NotificationsManager.self) private var notifications
    /// La tarjeta del permiso completo (E11). Se decide UNA vez al abrir: en el
    /// `body` aparecería o se iría a mitad de la lectura cuando el permiso o el
    /// contador cambian atrás.
    @State private var offersPermission = false

    /// El video está cargando o corriendo (lo escribe `RewardedOfferButton`): el
    /// botón de cobrar no puede cerrar la hoja abajo del anuncio. La oferta se
    /// muestra mientras no se haya duplicado, haya o no video ya cargado: el
    /// botón espera la carga y, si no hay videos, lo dice.
    @State private var watching = false
    /// Ya se duplicó EN ESTA hoja. Se lee al abrir desde `GameState` —que es
    /// quien lo sabe si la hoja se reabre— y se sube acá para que la vista
    /// reaccione sin observar `player`.
    @State private var doubled = false

    /// Más alto con la oferta del video (0,42 recortaba el botón de cobrar) y más
    /// alto todavía con la tarjeta del permiso.
    private var sheetFraction: CGFloat {
        let base: CGFloat = doubled ? 0.42 : 0.52
        return offersPermission ? base + 0.26 : base
    }

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

    var body: some View {
        // `PanelCard` es el tablón de las hojas en escala de tarjeta: los
        // insets son suyos, no medidos contra ningún arte (pedido del dueño,
        // 2026-08-18: una sola familia visual). El moño asomando sobre el
        // marco es la firma de la familia de premio: se abre como un regalo.
        PanelCard {
            VStack(spacing: Tokens.s16) {
                PanelTitleBanner(titleKey: "offline.title")
                // El monto sobre la tarjeta destacada en amarillo: el mismo
                // acento con el que el gemelo muestra su premio y la tira de
                // Regalos marca el día en juego.
                GameCard(style: .highlighted(Color("PaletteYellow"))) {
                    HStack(spacing: Tokens.s8) {
                        CoinIcon(size: 34)
                        // Duplicado, el monto que se muestra es el TOTAL: el
                        // jugador miró un video para ver un número más grande,
                        // así que el número más grande es lo que tiene que ver.
                        Text(verbatim: "+\(CoinFormatter.string(from: doubled ? reward.amount * 2 : reward.amount))")
                            .font(Tokens.display)
                            .monospacedDigit()
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.s4)
                }
                // La oferta va ARRIBA del botón de cobrar y no al lado: el
                // orden de lectura es la jerarquía, y "cobrar" es la salida.
                // Al lado, los dos botones compiten y el verde gana por color.
                if !doubled {
                    RewardedOfferButton(
                        title: String(localized: "offline.double"),
                        identifier: "offline.double",
                        placement: .offlineX2,
                        systemImage: "play.rectangle.fill",
                        tint: Color("PaletteBlue"),
                        isBusy: $watching,
                        onRewarded: doubleReward
                    )
                }
                ActionPill(
                    titleKey: "offline.collect",
                    systemImage: "checkmark",
                    tint: Color("PaletteGreen"),
                    identifier: "offline.collect",
                    // Con el anuncio en vuelo el botón no cierra: cerrar la
                    // hoja abajo de un anuncio a pantalla completa deja al
                    // jugador mirando publicidad sobre el tablero, y al volver
                    // no hay dónde acreditar.
                    action: { if !watching { dismiss() } }
                )
                if offersPermission {
                    NotificationPermissionCard(
                        accept: {
                            offersPermission = false
                            Task { await notifications.acceptPermissionCard() }
                        },
                        decline: { offersPermission = false }
                    )
                }
            }
            // Sin esto el panel se encoge al ancho ideal de su contenido y el
            // marco no llega a los bordes de la hoja (el mismo defecto que
            // anota `SkinAwardView`).
            .frame(maxWidth: .infinity)
            // El moño invade el tope del marco: este aire corre el banner
            // para que no se pisen.
            .padding(.top, Tokens.s8)
        }
        .overlay(alignment: .top) {
            GiftBowOrnament(width: 110)
                .offset(y: -24)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { if !watching { dismiss() } }
                .padding(10)
        }
        // Aire para la parte del moño que sobresale del marco: sin esto el
        // borde de la hoja lo recorta.
        .padding(.top, 26)
        .padding(16)
        .task {
            doubled = gameState.offlineRewardDoubled
            await offerPermissionCardIfDue()
        }
        .presentationDetents([.fraction(sheetFraction)])
        // Con el video cargando o corriendo la hoja no se cierra de un
        // deslizamiento: el anuncio aparecería sobre el tablero sin dónde acreditar.
        .interactiveDismissDisabled(watching)
        // El tablón no llega a los bordes de la hoja, así que el fondo de
        // sistema dejaba un rectángulo BLANCO alrededor del panel (el defecto
        // que `DailyRewardView` ya corrigió). Transparente, el panel flota
        // sobre el tablero.
        .fisuSheet()
    }
}
