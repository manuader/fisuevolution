import SwiftUI

/// Celebración de rare drop (bible §1). F5.2 le suma partículas y SFX de rareza.
///
/// Gemelo de los popups de premio (`DailyRewardView`, `OfflineEarningsView`) en
/// el `PopupContainer` de la casa (E14 C15): el título en la cinta, el premio
/// —la SKIN del personaje, grande (corrección del dueño, 2026-08-21: antes iba
/// un glifo de estrella y no se apreciaba a quién te ganaste)— sobre su plato,
/// su frase y abajo el botón de cobrar.
struct SpecialDropView: View {
    @Environment(GameState.self) private var gameState
    let special: SpecialsConfig.Special

    /// El plato del retrato: el mismo cuadrado redondeado de `CareerPortrait`
    /// y de los glifos de Regalos, a escala de protagonista.
    private static let plateShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    private static let portraitSide: CGFloat = 150

    var body: some View {
        PopupContainer("special.drop.title", ribbonTint: Color("PaletteGreen"), onClose: dismiss) {
            portrait
            Text(LocalizedStringKey(special.displayNameKey))
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                // Envolver, nunca truncar: el nombre sale del catálogo y un
                // nombre cortado no nombra a nadie (la misma guarda que anota
                // `SkinAwardView`).
                .fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(special.flavorTextKey))
                .font(Tokens.prose)
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("special.drop.album_hint")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            GameButton("special.drop.claim", role: .free, identifier: "special.drop.claim", action: dismiss)
        }
    }

    /// La skin del personaje especial, por el mismo camino que la dibuja el
    /// tablero (`manifest.characters[special.id]`). Sin arte, la estrella de
    /// "sorpresa" de siempre: la carta no espera al batch para construirse.
    @ViewBuilder private var portrait: some View {
        Group {
            if let asset = gameState.content?.manifest.characters[special.id],
               let image = UIArt.characterImage(atlas: asset.atlas, key: asset.key) {
                AnimatedArtView(clip: .character(special.id), role: .popup) {
                    image
                        .resizable()
                        .scaledToFit()
                }
                .padding(Tokens.s8)
            } else {
                RewardIllustration(kind: .gift, size: 84, spinsRays: false)
            }
        }
        .frame(width: Self.portraitSide, height: Self.portraitSide)
        .background(Color("PaletteYellow").opacity(0.3))
        .clipShape(Self.plateShape)
        .overlay(Self.plateShape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
        .accessibilityHidden(true)
    }

    private func dismiss() {
        gameState.dismissSpecialDrop()
    }
}
