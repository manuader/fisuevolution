import SwiftUI

/// El atajo de contratación de la pantalla principal: compra al personaje del
/// TIER MÁS ALTO que la plata alcanza (proyección `bestHire`), sin abrir
/// FisuJobs. Mismo contrato visual que `PricePill`: nunca `.disabled`, verde
/// cuando alcanza, temblor cuando no.
///
/// La cara viene del atlas por `faceKey` (las 43 existen — auditoría RF-05);
/// no lleva fallback vectorial porque `UIArt` ya cae a su placeholder.
///
/// ⚠️ **La oferta NO se recalcula al tocar.** El botón lee la proyección
/// publicada y le pasa el `typeId` a `hireBestCharacter()`, que hace lo mismo:
/// en el filo de los ~125 ms de `refreshProjections` se puede tocar una oferta
/// recién vencida, y eso es deliberado — `TowerActions.hire` revalida piso,
/// gate, saldo y lugar, así que lo peor que pasa es un `hire rejected` con su
/// háptico de error. Recalcular acá sería una segunda regla de selección que
/// mantener sincronizada con `computeBestHire`, que es justo lo que la
/// proyección viene a evitar.
///
/// ⚠️ Sin `.tutorialAnchor`: el tutorial no lo ilumina en ningún paso (el paso
/// "hire" ilumina el tab `hud.hire`, que abre FisuJobs). Queda bajo el scrim
/// como el resto de la franja.
struct QuickHireButton: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake = 0

    var body: some View {
        if let best = gameState.bestHire {
            button(for: best)
        }
    }

    private func button(for best: BestHire) -> some View {
        Button {
            // El temblor reemplaza al `.disabled` (patrón `PricePill`): dice "no
            // te alcanza" sin apagar el botón. Va ANTES de la acción, que en el
            // caso caro no va a comprar nada.
            if !best.affordable, !reduceMotion { shake += 1 }
            gameState.hireBestCharacter()
        } label: {
            HStack(spacing: Tokens.s8) {
                GameIcon(artKey: best.faceKey, size: 40) { EmptyView() }
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: best.displayName)
                        .font(Tokens.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 5) {
                        CoinIcon(size: 20)
                        Text(verbatim: best.costText)
                            .font(Tokens.body)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            .foregroundStyle(best.affordable ? .white : Color("PaletteInk"))
            .shadow(color: .black.opacity(best.affordable ? 0.45 : 0), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s16)
            .padding(.vertical, Tokens.s8)
            .frame(minWidth: 170)
            .background(
                Capsule()
                    .fill(best.affordable ? Color("PaletteGreen") : Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
            )
            .saturation(best.affordable ? 1 : 0.7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.quickhire")
        .accessibilityLabel(spokenLabel(for: best))
        // ±4 pt, cuatro tramos, 0,3 s en total — las mismas keyframes que
        // `PricePill`, para que los dos botones de compra del juego digan "no"
        // igual. Va **último** para que el identifier quede pegado al botón y no
        // a un contenedor de más (trampa 9a-bis): `offset` no crea un elemento
        // de accesibilidad.
        .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, dx in
            view.offset(x: dx)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-4, duration: 0.07)
                CubicKeyframe(4, duration: 0.08)
                CubicKeyframe(-3, duration: 0.08)
                CubicKeyframe(0, duration: 0.07)
            }
        }
    }

    /// "Contratar a {nombre}, {monto} monedas": propósito + monto CON su
    /// moneda, mismo reparto que arma `PricePill` (el glifo de la moneda es un
    /// dibujo y VoiceOver no lo ve).
    private func spokenLabel(for best: BestHire) -> Text {
        Text(verbatim: String(localized: "quickhire.ax.purpose \(best.displayName)"))
            + Text(verbatim: ", \(String(localized: "price.ax.coins \(best.costText)"))")
    }
}
