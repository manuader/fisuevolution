import EconomyKit
import SwiftUI

/// Las medidas y los colores de la tarjeta del premio del cofre (E14b B8, D7).
///
/// La tarjeta es una figurita: fondo liso **del mismo color para todas las
/// rarezas**, borde grueso y el nombre adentro. Lo único que cambia con la
/// rareza es el color del brillo (detrás de la tarjeta) y el del sello que la
/// nombra. Pura: la vista sólo la consulta y los tests la pinean.
enum ChestCardStyle {
    static let width: CGFloat = 150
    static let height: CGFloat = 164
    static let portraitSide: CGFloat = 96
    static let borderWidth: CGFloat = 5
    static let cornerRadius: CGFloat = 16

    /// El color liso de la tarjeta: el mismo para las cuatro rarezas.
    static let paperAsset = "PaletteCream"
    /// El borde grueso: también el mismo para todas.
    static let borderAsset = "PaletteBrown"

    /// El color del brillo que va detrás de la tarjeta.
    static func glowAsset(_ rarity: SkinsConfig.Rarity) -> String {
        switch rarity {
        case .comun: "PaletteGreen"
        case .rara: "PaletteBlue"
        case .epica: "PalettePink"
        case .legendaria: "PaletteYellow"
        }
    }

    /// El color del sello de rareza: el mismo que el brillo, para que se lea
    /// como una sola señal.
    static func sealAsset(_ rarity: SkinsConfig.Rarity) -> String {
        glowAsset(rarity)
    }

    static func glow(_ rarity: SkinsConfig.Rarity) -> Color { Color(glowAsset(rarity)) }
    static func seal(_ rarity: SkinsConfig.Rarity) -> Color { Color(sealAsset(rarity)) }
}

/// La tarjeta de figurita del premio del cofre: brillo del color de la rareza
/// detrás, la tarjeta lisa con borde grueso, el arte adentro, el nombre abajo y
/// —sólo cuando el premio es una pinta— el sello con la rareza en una esquina.
struct ChestPrizeCard<Art: View>: View {
    let rarity: SkinsConfig.Rarity
    let name: String
    let showsSeal: Bool
    @ViewBuilder let art: () -> Art

    private static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ChestCardStyle.cornerRadius, style: .continuous)
    }

    var body: some View {
        card
            // El brillo va DETRÁS de la tarjeta (nunca encima del arte ni del
            // nombre): rayos y halo del color de la rareza.
            .background {
                glow
            }
            .overlay(alignment: .topTrailing) {
                if showsSeal {
                    seal
                        .offset(x: 14, y: -12)
                }
            }
            .overlay { PrizePop() }
    }

    private var card: some View {
        VStack(spacing: Tokens.s4) {
            art()
                .frame(width: ChestCardStyle.portraitSide, height: ChestCardStyle.portraitSide)
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(name)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                // Envolver, nunca truncar: el nombre sale del catálogo y un
                // nombre cortado no nombra a nadie.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity)
        }
        .padding(Tokens.s8)
        .frame(width: ChestCardStyle.width, height: ChestCardStyle.height)
        .background(Color(ChestCardStyle.paperAsset), in: Self.shape)
        .overlay(
            Self.shape.strokeBorder(Color(ChestCardStyle.borderAsset), lineWidth: ChestCardStyle.borderWidth)
        )
    }

    private var glow: some View {
        ZStack {
            RewardRays(tint: ChestCardStyle.glow(rarity))
                .frame(width: ChestCardStyle.width * 1.9, height: ChestCardStyle.width * 1.9)
            Self.shape
                .fill(ChestCardStyle.glow(rarity))
                .frame(width: ChestCardStyle.width + 14, height: ChestCardStyle.height + 14)
                .blur(radius: 14)
        }
    }

    /// El sello: un cuño torcido con el nombre de la rareza, del color del brillo.
    private var seal: some View {
        Text(ChestRarityStyle.nameKey(rarity))
            .font(Tokens.caption)
            .foregroundStyle(Color("PaletteInk"))
            .padding(.horizontal, Tokens.s8)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ChestCardStyle.seal(rarity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color("PaletteInk").opacity(0.85), lineWidth: 2)
                    )
            }
            .rotationEffect(.degrees(8))
            .accessibilityHidden(true)
    }
}
