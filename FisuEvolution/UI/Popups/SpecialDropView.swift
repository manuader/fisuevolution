import SwiftUI

/// Celebración de rare drop (bible §1). F5.2 le suma partículas y SFX de rareza.
///
/// Tercer gemelo de los popups de premio (`DailyRewardView`,
/// `OfflineEarningsView`): mismo marco `panel_reward`, banner de título, el
/// premio sobre la `GameCard` amarilla y `ActionPill` verde de salida. La
/// estrella no es arte del personaje —es el glifo de "sorpresa"— y por eso va
/// sobre el plato de retrato de la casa, el mismo encuadre con el que el fork
/// de carrera muestra sus caras.
struct SpecialDropView: View {
    @Environment(GameState.self) private var gameState
    let special: SpecialsConfig.Special

    /// El plato del glifo: el mismo cuadrado redondeado de `CareerPortrait` y
    /// de los glifos de Regalos.
    private static let plateShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        // ⚠️ Márgenes medidos contra el arte, no heredados (ver
        // `DailyRewardView`, mismo marco doble): con los 22/24 de antes la
        // tarjeta amarilla pisaría las dos líneas del marco.
        GamePanel(art: "panel_reward", insets: EdgeInsets(top: 84, leading: 40, bottom: 44, trailing: 40)) {
            VStack(spacing: Tokens.s16) {
                PanelTitleBanner(titleKey: "special.drop.title")
                GameCard(style: .highlighted(Color("PaletteYellow"))) {
                    VStack(spacing: Tokens.s12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color("PaletteYellow"))
                            .padding(Tokens.s8)
                            .background(Color("PaletteYellow").opacity(0.3))
                            .clipShape(Self.plateShape)
                            .overlay(Self.plateShape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                        Text(LocalizedStringKey(special.displayNameKey))
                            .font(Tokens.title)
                            .foregroundStyle(Color("PaletteInk"))
                            .multilineTextAlignment(.center)
                            // Envolver, nunca truncar: el nombre sale del
                            // catálogo y un nombre cortado no nombra a nadie
                            // (la misma guarda que anota `SkinAwardView`).
                            .fixedSize(horizontal: false, vertical: true)
                        Text(LocalizedStringKey(special.flavorTextKey))
                            .font(Tokens.prose)
                            .foregroundStyle(Color("PaletteInk").opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.s4)
                }
                ActionPill(
                    titleKey: "special.drop.claim",
                    systemImage: "checkmark",
                    tint: Color("PaletteGreen"),
                    identifier: "special.drop.claim",
                    action: { gameState.dismissSpecialDrop() }
                )
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { gameState.dismissSpecialDrop() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.55)])
        // Sin esto el fondo de sistema deja un rectángulo BLANCO alrededor del
        // moño de `panel_reward` (el defecto que `DailyRewardView` ya
        // corrigió): transparente, el panel flota sobre el tablero.
        .presentationBackground(.clear)
    }
}
