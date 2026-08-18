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
        // `PanelCard` es el tablón de las hojas en escala de tarjeta: los
        // insets son del componente, no medidos contra un PNG (pedido del
        // dueño 2026-08-18: una sola familia visual para hojas y popups).
        PanelCard {
            VStack(spacing: 14) {
                Text("skin.award.title")
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(Color("PaletteInk"))

                SkinAwardPortrait(type: award.characterType, treatment: treatment)
                    // El plato de la casa para todo retrato (`JobPortrait`,
                    // `SkinCard`): amarillo tenue + borde marrón. El padding va
                    // ANTES del frame para que el plato ocupe los mismos 132 pt
                    // y el popup —que vive en un detent .medium sin scroll— no
                    // crezca. Radio 18: acá el retrato es el héroe del popup,
                    // no una celda de lista.
                    .padding(6)
                    .frame(width: 132, height: 132)
                    .background(
                        RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                            .fill(Color("PaletteYellow").opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                            .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
                    )

                Text("skin.award.subtitle \(award.characterType.displayName)")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk").opacity(0.75))
                    .multilineTextAlignment(.center)
                    // Sin esto el texto se trunca a una línea en vez de envolver
                    // cuando el nombre del personaje es largo.
                    .fixedSize(horizontal: false, vertical: true)

                // Equipar desde acá: el premio se gana en medio del loop y
                // mandarlo a buscar la ficha para usarlo es fricción de más.
                // La cápsula caramelo de la casa (ActionPill ES un Button con
                // este identifier: la semántica que tapean los tests no cambia).
                ActionPill(
                    titleKey: "skin.award.equip",
                    systemImage: "tshirt.fill",
                    identifier: "skin.award.equip"
                ) {
                    gameState.equipSkin(id: award.id, forCharacterType: award.characterType.id)
                    dismiss()
                }

                // El "ahora no" va mudo, como el cancelar del prestigio y el
                // saltar del tutorial: al lado del premio, el botón que no hace
                // nada no compite.
                Button {
                    dismiss()
                } label: {
                    Text("skin.award.dismiss")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk").opacity(0.6))
                        .padding(.vertical, Tokens.s4)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("skin.award.dismiss")
            }
            .padding(.vertical, 6)
            // Sin esto el panel se encoge al ancho ideal de su contenido y el
            // subtítulo se desborda por los costados del marco.
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .presentationDetents([.medium])
        // El marco del premio no llega a los bordes de la hoja: sin esto el
        // fondo de sistema deja un rectángulo alrededor del panel. Transparente,
        // el premio flota sobre el tablero como sus gemelos.
        .presentationBackground(.clear)
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
