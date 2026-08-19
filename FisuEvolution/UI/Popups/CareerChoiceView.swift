import EconomyKit
import SwiftUI

/// El fork de carrera de T9 (bible §1): "Te recibiste en la UBA. ¿Ahora qué?".
/// Elegir completa el merge diferido, y la elección dura hasta la próxima
/// reencarnación.
///
/// ⚠️ **Era la última pantalla con `.buttonStyle(.borderedProminent)`**: cuatro
/// rectángulos azules del sistema, sin retrato, dentro de un panel de la casa.
/// Se veía de otra app — y encima pedía la decisión MÁS definitiva del juego a
/// ciegas, porque no mostraba a quién estabas eligiendo.
///
/// Ahora usa la anatomía de fila de FisuJobs, que es la referencia visual de
/// todas las pantallas: retrato a la izquierda, datos al medio, y la tarjeta
/// entera es el control. La cara importa acá más que en ningún otro lado: es lo
/// único que hace concreta una elección permanente entre cuatro nombres que
/// terminan todos en "Jr.".
struct CareerChoiceView: View {
    @Environment(GameState.self) private var gameState
    let prompt: GameState.CareerPrompt

    var body: some View {
        // `PanelCard` es el tablón de las hojas en escala de tarjeta: los
        // insets son del componente, no medidos contra un PNG (pedido del
        // dueño 2026-08-18: una sola familia visual para hojas y popups).
        PanelCard {
            VStack(spacing: Tokens.s16) {
                header
                // La recompensa se muestra ANTES de tocar (RF-15): una elección a
                // ciegas entre cuatro botones idénticos no es una elección.
                let rewards = gameState.careerRewards
                VStack(spacing: Tokens.s12) {
                    ForEach(prompt.options) { option in
                        optionRow(option, reward: rewards[option.id]?.previewText)
                    }
                }
            }
            // Un suspiro sobre los 28 del marco: que el título no nazca pegado
            // a la banda (el aire que antes regalaba el ornamento del arte).
            .padding(.top, Tokens.s4)
        }
        .padding(Tokens.s16)
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        // El tablón no llega a los bordes de la hoja: sin esto el fondo de
        // sistema deja un rectángulo alrededor del panel. Transparente, el
        // fork flota sobre el tablero que está por bifurcar (mismo criterio
        // que la ficha y los popups de premio).
        .presentationBackground(.clear)
    }

    private var header: some View {
        VStack(spacing: Tokens.s4) {
            Text("career.title")
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
            Text("career.subtitle")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    /// Una carrera, con la misma anatomía que una fila de FisuJobs.
    private func optionRow(_ option: CharacterType, reward: String?) -> some View {
        Button {
            gameState.chooseCareer(optionId: option.id)
        } label: {
            GameCard {
                HStack(spacing: Tokens.s12) {
                    CareerPortrait(faceKey: "\(option.id)_face")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: option.displayName)
                            .font(Tokens.title)
                            .foregroundStyle(Color("PaletteInk"))
                            // Dos renglones y no uno, por lo mismo que en
                            // FisuJobs: con `lineLimit(1)` un nombre largo se
                            // encoge al `minimumScaleFactor` y DESPUÉS trunca,
                            // y un nombre truncado no nombra a nadie.
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true)
                        if let reward {
                            Text(verbatim: reward)
                                .font(Tokens.caption)
                                .foregroundStyle(Color("PaletteInk").opacity(0.72))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // El chevron es lo que dice "esto se toca": la tarjeta entera
                    // es el control, así que sin él se lee como una ficha
                    // informativa. Mismo rol que el `PricePill` en FisuJobs.
                    Image(systemName: "chevron.right")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk").opacity(0.45))
                }
            }
        }
        .buttonStyle(.plain)
        // Una sola parada de VoiceOver por carrera, con el premio adentro: el
        // patrón T8 de la casa. Sin esto la tarjeta publica el nombre y el
        // premio como `StaticText` sueltos y la pantalla pasa a tener ocho
        // paradas para cuatro opciones.
        .accessibilityRepresentation {
            Color.clear
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text(verbatim: option.displayName))
                .accessibilityValue(Text(verbatim: reward ?? ""))
        }
        .accessibilityIdentifier("career.option.\(option.id)")
    }
}

/// El retrato de una carrera: cuadrado de esquinas redondeadas con fondo tenue y
/// borde ink, igual que `JobPortrait`.
///
/// A diferencia de allá **nunca va en silueta**: en FisuJobs la silueta es el
/// "todavía no lo viste", y acá las cuatro son elegibles ahora mismo. Si el arte
/// faltara cae al mismo SF Symbol, que es un legajo sin foto — que en una
/// pantalla de recibido es exactamente lo que corresponde.
private struct CareerPortrait: View {
    let faceKey: String

    private static let side: CGFloat = 72

    var body: some View {
        Color.clear
            .frame(width: Self.side, height: Self.side)
            .overlay { face.padding(3) }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder private var face: some View {
        if let image = UIArt.image(faceKey) {
            image.resizable().scaledToFit()
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(12)
                .foregroundStyle(Color("PaletteInk").opacity(0.35))
        }
    }
}
