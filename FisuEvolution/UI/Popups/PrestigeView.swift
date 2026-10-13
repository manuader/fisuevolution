import SwiftUI

/// Reencarnación: mata la run, preserva MetaState y acredita ORO.
///
/// RF-16: antes decía sólo cuánto ORO ganabas. Un número chico ("ganás 14") sin
/// forma de saber qué compra. Ahora la pantalla es el **antes y el después** del
/// multiplicador global, que es lo que ese ORO paga.
struct PrestigeView: View {
    @Environment(GameState.self) private var gameState
    /// Cierra el popup (lo pone quien lo presenta).
    let onClose: () -> Void

    var body: some View {
        // Una sola lectura de la proyección: todas las filas cuentan la misma
        // historia aunque el refresco de 8 Hz caiga en el medio del layout.
        let preview = gameState.prestigePreview

        return PopupContainer("prestige.title", ribbonTint: Color("PalettePink"), onClose: onClose) {
            if preview.isWorthIt {
                oroGain(preview)
                multiplierArrow(preview)
            } else {
                // El teaser ("al llegar a lujo"): todavía no hay ORO por
                // cobrar, así que el popup no promete — muestra el camino
                // al primero y qué compra cada uno.
                nextOroProgress(preview)
            }

            Text("prestige.body \(gameState.prestigeMultiplierPerOroText)")
                .font(.system(.footnote, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))

            Text("prestige.prices_reset")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("prestige.prices_reset")

            if preview.isWorthIt {
                VStack(alignment: .leading, spacing: 6) {
                    PrestigeLine(
                        mark: "−", tint: GameTint.alert,
                        text: Text("prestige.loses \(String(preview.unitsLost)) \(preview.coinsLostText)")
                    )
                    PrestigeLine(
                        mark: "★", tint: Color("PaletteGreen"),
                        text: Text("prestige.keeps \(preview.multiplierAfterText)")
                    )
                    if let inherited = preview.inheritedPassivesText {
                        PrestigeLine(mark: "+", tint: Color("PaletteBlue"), text: Text(verbatim: inherited))
                            .accessibilityIdentifier("prestige.inherited")
                    }
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color("PaletteInk"))
                // Sin esto las filas se truncan con "…" y el jugador no ve los
                // números, que son justamente lo que vino a leer.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } actions: {
            // En el teaser NO se dibuja la acción: una que no corresponde no se
            // apaga, no existe (la doctrina de `GameButton`).
            if preview.isWorthIt {
                if let goal = preview.wallGoalText {
                    // El piso móvil: hay ORO, falta la pared. No se apaga el
                    // botón, se dice qué falta.
                    GameButton(verbatim: goal, role: .blue, medallion: .glyph(.lock), available: false,
                               identifier: "prestige.wall") {}
                } else {
                    GameButton("prestige.confirm", role: .blue, identifier: "prestige.confirm") {
                        gameState.confirmPrestige()
                        onClose()
                    }
                }
            }
            // El "mejor no" va en crema a propósito: al lado de una decisión
            // irreversible, el botón que no hace nada no compite.
            GameButton("prestige.cancel", role: .neutral, identifier: "prestige.cancel", action: onClose)
        }
    }

    /// El camino al PRÓXIMO ORO, cuando todavía no hay ninguno por cobrar: lo
    /// que falta juntar y la barra del progreso. Es lo único que la hoja puede
    /// contar sin mentir en el teaser.
    private func nextOroProgress(_ preview: PrestigePreview) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                OroIcon(size: 30)
                Text("prestige.oro.next \(CoinFormatter.string(from: preview.coinsToNextOro))")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color("PaletteInk"))
            ProgressBar(
                progress: preview.nextOroProgress,
                tint: Color("PalettePink"),
                labelText: preview.nextOroProgress.formatted(.percent.precision(.fractionLength(0)))
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("prestige.oro.progress")
    }

    private func oroGain(_ preview: PrestigePreview) -> some View {
        HStack(spacing: 8) {
            OroIcon(size: 30)
            Text("prestige.oro.gain \(String(preview.oroGained))")
                // `Tokens.display` es este mismo cuerpo (.title rounded) con el
                // peso de la casa: el número grande del popup habla el idioma
                // de los otros números grandes del juego.
                .font(Tokens.display)
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
            Text(verbatim: "→")
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
            RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                .fill(Color("PaletteCream"))
                .overlay(RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.75), lineWidth: 2.5))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("prestige.multiplier")
        .accessibilityLabel(Text("prestige.multiplier \(preview.multiplierBeforeText) \(preview.multiplierAfterText)"))
    }
}

/// Una fila de «qué perdés / qué te llevás»: su disco dibujado (sin SF Symbols)
/// y el texto al lado.
private struct PrestigeLine: View {
    let mark: String
    let tint: Color
    let text: Text

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.s8) {
            IconCanvas { MarkDisc(mark: mark, fill: tint) }
                .frame(width: 18, height: 18)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                .accessibilityHidden(true)
            text
        }
    }
}
