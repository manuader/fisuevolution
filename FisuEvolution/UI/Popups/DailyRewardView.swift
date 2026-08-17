import SwiftUI

/// Popup del **premio del día** (ciclo de 7 días, spec §9).
///
/// El premio ya está acreditado cuando esta hoja se abre —el daily se cobra solo
/// en el bootstrap y al volver a foreground— así que acá no se decide nada: es la
/// celebración. Por eso el botón dice "Cobrar" pero lo único que hace es cerrar.
///
/// Habla la gramática de la casa (T18): `PanelTitleBanner` como las seis hojas de
/// la barra, `GameCard` destacada en amarillo para el premio —el mismo acento con
/// el que la tira de `GiftsView` marca el día en juego—, `ActionPill` verde para
/// la salida y `Tokens` para toda la tipografía. Antes eran `Text` con
/// `.system(.title2)` sueltos y un `borderedProminent` de sistema: se leía como
/// una alerta de iOS pegada adentro del moño.
///
/// El marco sigue siendo `panel_reward`, el mismo que enmarca la pantalla de
/// Regalos: el popup y el calendario que lo explica son parientes a la vista.
struct DailyRewardView: View {
    @Environment(GameState.self) private var gameState
    let claim: DailyRewardManager.Claim

    /// ⚠️ **El monto NO rueda con `.contentTransition(.numericText())`, y se
    /// probó.** La versión que arrancaba en `+0` y rodaba hasta el premio
    /// terminaba **antes de que la hoja terminara de subir**: medido cuadro a
    /// cuadro sobre un video del simulador, el popup recién asoma cuando el
    /// número ya dice `+210`. O sea que no se veía ni el rodado ni el `+0` — era
    /// una animación muerta con dos propiedades de estado atrás. El contador del
    /// HUD, que sí cambia con la hoja quieta, es el que la usa de verdad.
    private var amountText: String {
        "+\(CoinFormatter.string(from: claim.coinsGranted))"
    }

    /// El personaje que tira el día del cofre, si el catálogo lo conoce.
    private var special: SpecialsConfig.Special? {
        guard let id = claim.specialGranted else { return nil }
        return gameState.content?.specials.specials.first { $0.id == id }
    }

    /// El plato del glifo de premio: el mismo cuadrado redondeado con el que la
    /// tira de Regalos encuadra su calendario y el fork sus caras.
    private static let plateShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        // ⚠️ Los márgenes laterales y el de abajo son **medidos contra el arte**,
        // no heredados: `panel_reward` trae un marco DOBLE (verde y rojo) y con
        // los 22/24 que traía esta hoja —que le alcanzaban cuando el contenido
        // era texto centrado que nunca llegaba a los bordes— la tarjeta de premio
        // y el botón le pisaban las dos líneas. Medido sobre una captura a 3×: el
        // interior dorado empieza a 163 px del borde de pantalla y la tarjeta
        // arrancaba en 118. A 40 pt entra adentro con aire.
        GamePanel(art: "panel_reward", insets: EdgeInsets(top: 84, leading: 40, bottom: 44, trailing: 40)) {
            VStack(spacing: Tokens.s16) {
                PanelTitleBanner(titleKey: "daily.title")
                prizeCard
                ActionPill(
                    titleKey: "offline.collect",
                    systemImage: "checkmark",
                    tint: Color("PaletteGreen"),
                    identifier: "daily.collect",
                    action: { gameState.dismissDailyClaim() }
                )
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { gameState.dismissDailyClaim() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.52)])
        // El moño de `panel_reward` no llega a los bordes de la hoja, así que el
        // fondo de sistema dejaba un rectángulo BLANCO alrededor del panel —el
        // único blanco puro de todo el juego, y justo en la pantalla que celebra
        // la racha—. Transparente, el moño flota sobre el tablero, igual que la
        // ficha del personaje (`CharacterSheetView`), que resolvió lo mismo.
        .presentationBackground(.clear)
    }

    /// El premio: qué día es y qué te dio. Es **una** parada de VoiceOver
    /// (patrón T8): adentro no hay ningún control que un elemento contenedor
    /// pudiera borrar del árbol (trampa 9a), así que colapsarlo es lo que evita
    /// que el título, el monto y el icono se lean como tres paradas mudas.
    private var prizeCard: some View {
        GameCard(style: .highlighted(Color("PaletteYellow"))) {
            VStack(spacing: Tokens.s12) {
                Text(LocalizedStringKey(claim.day.titleKey))
                    .font(Tokens.title)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                prize
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.s4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(claim.day.titleKey)))
        .accessibilityValue(axValue)
    }

    /// Los dos premios posibles: un personaje special (día 7) o plata.
    @ViewBuilder private var prize: some View {
        if let special {
            VStack(spacing: Tokens.s4) {
                // El moño sobre su plato amarillo: el glifo del premio es el
                // retrato del popup, y en los materiales v3 los retratos no
                // flotan sueltos sobre la tarjeta — el plato con su borde
                // marrón es lo que los ancla (mismo encuadre que `DailyStrip`
                // y que el personaje de `SpecialDropView`).
                GameIcon(artKey: "ui_tab_gifts", size: 52) { VectorTabGiftsIcon() }
                    .padding(Tokens.s8)
                    .background(Color("PaletteYellow").opacity(0.3))
                    .clipShape(Self.plateShape)
                    .overlay(Self.plateShape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                Text(LocalizedStringKey(special.displayNameKey))
                    .font(Tokens.display)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
        } else {
            HStack(spacing: Tokens.s8) {
                CoinIcon(size: 34)
                Text(verbatim: amountText)
                    .font(Tokens.display)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    /// Lo que VoiceOver anuncia como valor de la tarjeta: el premio, sea el
    /// personaje del cofre o la plata.
    private var axValue: Text {
        if let special {
            return Text(LocalizedStringKey(special.displayNameKey))
        }
        return Text(verbatim: amountText)
    }
}
