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
                        Text(verbatim: "+\(CoinFormatter.string(from: reward.amount))")
                            .font(Tokens.display)
                            .monospacedDigit()
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.s4)
                }
                ActionPill(
                    titleKey: "offline.collect",
                    systemImage: "checkmark",
                    tint: Color("PaletteGreen"),
                    identifier: "offline.collect",
                    action: { dismiss() }
                )
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
            ArtCloseButton { dismiss() }
                .padding(10)
        }
        // Aire para la parte del moño que sobresale del marco: sin esto el
        // borde de la hoja lo recorta.
        .padding(.top, 26)
        .padding(16)
        .presentationDetents([.fraction(0.42)])
        // El tablón no llega a los bordes de la hoja, así que el fondo de
        // sistema dejaba un rectángulo BLANCO alrededor del panel (el defecto
        // que `DailyRewardView` ya corrigió). Transparente, el panel flota
        // sobre el tablero.
        .presentationBackground(.clear)
    }
}
