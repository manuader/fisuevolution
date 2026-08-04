import EconomyKit
import SwiftUI

/// Celebración de una skin ganada por milestone. Es el único momento en que el
/// juego interrumpe por una apariencia: el resto de la vida de las skins vive en
/// la ficha de personaje. Se presenta gateada por tutorial, como todos los popups.
struct SkinAwardView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    let award: GameState.SkinAward

    private var treatment: SkinResolver.Treatment {
        SkinResolver.treatment(
            for: award.id,
            characterType: award.characterType.id,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
    }

    var body: some View {
        GamePanel(art: "panel_dialog", insets: EdgeInsets(top: 58, leading: 24, bottom: 26, trailing: 24)) {
            VStack(spacing: 14) {
                Text("skin.award.title")
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(Color("PaletteInk"))

                SkinAwardPortrait(type: award.characterType, treatment: treatment)
                    .frame(width: 132, height: 132)

                Text("skin.award.subtitle \(award.characterType.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("skin.award.dismiss") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("PaletteBlue"))
                    .accessibilityIdentifier("skin.award.dismiss")
            }
            .padding(.vertical, 6)
        }
        .padding(16)
        .presentationDetents([.medium])
    }
}

/// Retrato del premio con el mismo criterio de fallback que la ficha y el
/// tablero: si el arte de la skin todavía no existe, se muestra el base.
private struct SkinAwardPortrait: View {
    let type: CharacterType
    let treatment: SkinResolver.Treatment
    @Environment(GameState.self) private var gameState

    var body: some View {
        Group {
            if let image = portrait {
                image
                    .resizable()
                    .scaledToFit()
                    .colorMultiply(SkinResolver.swiftUITint(for: treatment) ?? .white)
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .foregroundStyle(Color("PaletteInk"))
            }
        }
        .accessibilityHidden(true)
    }

    private var portrait: Image? {
        guard let asset = gameState.content?.manifest.characters[type.id] else { return nil }
        if case let .texture(key) = treatment,
           let skinImage = UIArt.characterImage(atlas: asset.atlas, key: key) {
            return skinImage
        }
        return UIArt.characterImage(atlas: asset.atlas, key: asset.key)
    }
}
