import SwiftUI

/// Reencarnación: mata la run, preserva MetaState y acredita ORO.
///
/// RF-16: antes decía sólo cuánto ORO ganabas. Un número chico ("ganás 14") sin
/// forma de saber qué compra. Ahora la pantalla es el **antes y el después** del
/// multiplicador global, que es lo que ese ORO paga.
struct PrestigeView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Una sola lectura de la proyección: todas las filas cuentan la misma
        // historia aunque el refresco de 8 Hz caiga en el medio del layout.
        let preview = gameState.prestigePreview

        return GamePanel(art: "panel_prestige", insets: EdgeInsets(top: 76, leading: 22, bottom: 24, trailing: 22)) {
            VStack(spacing: 14) {
                Text("prestige.title")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))

                oroGain(preview)
                multiplierArrow(preview)

                Text("prestige.body \(gameState.prestigeMultiplierPerOroText)")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color("PaletteInk").opacity(0.75))

                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        "prestige.loses \(String(preview.unitsLost)) \(preview.coinsLostText)",
                        systemImage: "arrow.counterclockwise"
                    )
                    Label(
                        "prestige.keeps \(preview.multiplierAfterText)",
                        systemImage: "sparkles"
                    )
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color("PaletteInk"))
                // Sin esto las dos filas se truncan con "…" y el jugador no ve
                // los números, que son justamente lo que vino a leer.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    gameState.confirmPrestige()
                    dismiss()
                } label: {
                    Text("prestige.confirm")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PalettePink"))
                .accessibilityIdentifier("prestige.confirm")

                Button {
                    dismiss()
                } label: {
                    Text("prestige.cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("prestige.cancel")
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { dismiss() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.68)])
    }

    private func oroGain(_ preview: PrestigePreview) -> some View {
        HStack(spacing: 8) {
            OroIcon(size: 30)
            Text("prestige.oro.gain \(String(preview.oroGained))")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(Color("PaletteInk"))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("prestige.oro")
    }

    /// El de la izquierda es el multiplicador que tenés; el de la derecha, el que
    /// te llevás si confirmás. `PrestigePreviewTests` pinea que el de la derecha
    /// es exactamente el que queda después.
    private func multiplierArrow(_ preview: PrestigePreview) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: "×\(preview.multiplierBeforeText)")
                .foregroundStyle(Color("PaletteInk").opacity(0.6))
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color("PaletteInk").opacity(0.45))
            Text(verbatim: "×\(preview.multiplierAfterText)")
                .foregroundStyle(Color("PalettePink"))
        }
        .font(.system(.title2, design: .rounded).weight(.heavy))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color("PaletteCream"))
                .overlay(Capsule().strokeBorder(Color("PaletteInk").opacity(0.85), lineWidth: 3))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("prestige.multiplier")
        .accessibilityLabel(Text("prestige.multiplier \(preview.multiplierBeforeText) \(preview.multiplierAfterText)"))
    }
}
