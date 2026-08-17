import SwiftUI

/// "Mientras no estabas…" — el premio offline ya se acreditó al aplicarse; esta
/// hoja es sólo la celebración. F4 le suma el "doblar con un video".
///
/// Habla la misma anatomía que `DailyRewardView`, su gemelo de marco
/// (`panel_reward`): banner de título, el monto sobre la `GameCard` amarilla
/// —el acento de premio de la casa— y `ActionPill` verde como salida. Antes era
/// un `borderedProminent` de sistema sobre fuentes sueltas: se leía como una
/// alerta de iOS pegada adentro del moño.
struct OfflineEarningsView: View {
    let reward: GameState.OfflineReward
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // ⚠️ Márgenes medidos contra el arte, no heredados: `panel_reward` trae
        // un marco DOBLE (verde y rojo) y con los 22/24 que traía esta hoja
        // —que le alcanzaban cuando el contenido era texto centrado— la tarjeta
        // y el botón le pisarían las dos líneas. La medición es la de
        // `DailyRewardView`, que comparte marco y anatomía: a 40/44 el
        // contenido entra en el interior dorado con aire.
        GamePanel(art: "panel_reward", insets: EdgeInsets(top: 84, leading: 40, bottom: 44, trailing: 40)) {
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
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { dismiss() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.42)])
        // El moño de `panel_reward` no llega a los bordes de la hoja, así que
        // el fondo de sistema dejaba un rectángulo BLANCO alrededor del panel
        // (el defecto que `DailyRewardView` ya corrigió). Transparente, el
        // moño flota sobre el tablero.
        .presentationBackground(.clear)
    }
}
