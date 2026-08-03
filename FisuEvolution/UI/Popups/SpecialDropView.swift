import SwiftUI

/// Celebración de rare drop (bible §1). F5.2 le suma partículas y SFX de rareza.
struct SpecialDropView: View {
    @Environment(GameState.self) private var gameState
    let special: SpecialsConfig.Special

    var body: some View {
        GamePanel(art: "panel_reward", insets: EdgeInsets(top: 82, leading: 22, bottom: 24, trailing: 22)) {
            VStack(spacing: 16) {
                Text("special.drop.title")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color("PaletteYellow"))
                Text(LocalizedStringKey(special.displayNameKey))
                    .font(.title3.weight(.bold))
                Text(LocalizedStringKey(special.flavorTextKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    gameState.dismissSpecialDrop()
                } label: {
                    Text("special.drop.claim")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteYellow"))
                .foregroundStyle(Color("PaletteInk"))
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { gameState.dismissSpecialDrop() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.55)])
    }
}
