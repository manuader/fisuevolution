import SwiftUI

/// Celebración de rare drop (bible §1). F5.2 le suma partículas y SFX de rareza.
///
/// Tercer gemelo de los popups de premio (`DailyRewardView`,
/// `OfflineEarningsView`): mismo `PanelCard` con el moño asomando, banner de
/// título, el premio sobre la `GameCard` amarilla y `ActionPill` verde de
/// salida. El protagonista es la SKIN del personaje, grande (corrección del
/// dueño, 2026-08-21: antes iba un glifo de estrella y no se apreciaba a
/// quién te ganaste); la estrella queda de fallback para un special sin arte.
///
/// La misma carta sirve dos momentos: el DROP (celebración, con "¡Es mío!")
/// y el RECAP — el jugador mantiene apretado al special en el tablero y la
/// carta vuelve para contarle qué beneficio le está dando. Cambian el título,
/// el botón y a quién se avisa al cerrar; el cuerpo es idéntico a propósito.
struct SpecialDropView: View {
    @Environment(GameState.self) private var gameState
    let special: SpecialsConfig.Special
    var isRecap = false

    /// El plato del retrato: el mismo cuadrado redondeado de `CareerPortrait`
    /// y de los glifos de Regalos, a escala de protagonista.
    private static let plateShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    private static let portraitSide: CGFloat = 168

    var body: some View {
        // `PanelCard` es el tablón de las hojas en escala de tarjeta: los
        // insets son suyos, no medidos contra ningún arte (pedido del dueño,
        // 2026-08-18: una sola familia visual). El moño asomando sobre el
        // marco es la firma de la familia de premio: se abre como un regalo.
        PanelCard {
            VStack(spacing: Tokens.s16) {
                PanelTitleBanner(titleKey: isRecap ? "special.info.title" : "special.drop.title")
                GameCard(style: .highlighted(Color("PaletteYellow"))) {
                    VStack(spacing: Tokens.s12) {
                        portrait
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
                    titleKey: isRecap ? "special.info.ok" : "special.drop.claim",
                    systemImage: "checkmark",
                    tint: Color("PaletteGreen"),
                    identifier: "special.drop.claim",
                    action: dismiss
                )
            }
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
            ArtCloseButton(action: dismiss)
                .padding(10)
        }
        // Aire para la parte del moño que sobresale del marco: sin esto el
        // borde de la hoja lo recorta.
        .padding(.top, 26)
        .padding(16)
        // Más alto que sus gemelos: el retrato de 168 pt es el pedido — la
        // carta grande para apreciar la skin.
        .presentationDetents([.fraction(0.66)])
        // Sin esto el fondo de sistema deja un rectángulo BLANCO alrededor del
        // tablón (el defecto que `DailyRewardView` ya corrigió): transparente,
        // el panel flota sobre el tablero.
        .fisuSheet()
    }

    /// La skin del personaje especial, por el mismo camino que la dibuja el
    /// tablero (`manifest.characters[special.id]`). Sin arte, la estrella de
    /// "sorpresa" de siempre: la carta no espera al batch para construirse.
    @ViewBuilder private var portrait: some View {
        Group {
            if let asset = gameState.content?.manifest.characters[special.id],
               let image = UIArt.characterImage(atlas: asset.atlas, key: asset.key) {
                AnimatedArtView(clip: .portrait(special.id), role: .popup) {
                    image
                        .resizable()
                        .scaledToFit()
                }
                .padding(Tokens.s8)
            } else {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(Color("PaletteYellow"))
            }
        }
        .frame(width: Self.portraitSide, height: Self.portraitSide)
        .background(Color("PaletteYellow").opacity(0.3))
        .clipShape(Self.plateShape)
        .overlay(Self.plateShape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
        .accessibilityHidden(true)
    }

    private func dismiss() {
        if isRecap {
            gameState.dismissSpecialInfo()
        } else {
            gameState.dismissSpecialDrop()
        }
    }
}
