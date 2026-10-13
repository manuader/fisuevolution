import EconomyKit
import SwiftUI

/// Celebración de una skin ganada por milestone. Es el único momento en que el
/// juego interrumpe por una apariencia: el resto de la vida de las skins vive en
/// la ficha de personaje. Se presenta gateada por tutorial, como todos los popups.
struct SkinAwardView: View {
    @Environment(GameState.self) private var gameState
    let award: GameState.SkinAward
    /// Cierra el popup (lo pone quien lo presenta).
    let onClose: () -> Void

    private var treatment: SkinResolver.Treatment {
        SkinResolver.treatment(
            for: award.id,
            characterType: award.characterType.id,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
    }

    var body: some View {
        PopupContainer("skin.award.title", ribbonTint: Color("PaletteGreen"), onClose: onClose) {
            SkinAwardPortrait(type: award.characterType, treatment: treatment)
                // El plato de la casa para todo retrato (`JobPortrait`,
                // `SkinCard`): amarillo tenue + borde marrón. Radio 18: acá el
                // retrato es el héroe del popup, no una celda de lista.
                .padding(6)
                .frame(width: 140, height: 140)
                .background(
                    RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                        .fill(Color("PaletteYellow").opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                        .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
                )

            Text("skin.award.subtitle \(award.characterType.localizedName)")
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                // Sin esto el texto se trunca a una línea en vez de envolver
                // cuando el nombre del personaje es largo.
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            // Equipar desde acá: el premio se gana en medio del loop y mandarlo
            // a buscar la ficha para usarlo es fricción de más.
            GameButton("skin.award.equip", role: .free, identifier: "skin.award.equip") {
                gameState.equipSkin(id: award.id, forCharacterType: award.characterType.id)
                onClose()
            }
            GameButton("skin.award.dismiss", role: .neutral, identifier: "skin.award.dismiss", action: onClose)
        }
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
                RewardIllustration(kind: .gift, size: 70, spinsRays: false)
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
