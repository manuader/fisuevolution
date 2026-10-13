import SwiftUI

/// Popup del **premio del día** (ciclo de 7 días, spec §9).
///
/// El premio ya está acreditado cuando se abre —el daily se cobra solo en el
/// bootstrap y al volver a foreground— así que acá no se decide nada: es la
/// celebración. Por eso el botón dice "Cobrar" pero lo único que hace es cerrar.
///
/// Vive en el `PopupContainer` de la casa (E14 C15): el título en la cinta, el
/// premio ilustrado al centro —el mismo acento amarillo con el que la tira de
/// `GiftsView` marca el día en juego— y abajo los botones de `GameButton`.
struct DailyRewardView: View {
    @Environment(GameState.self) private var gameState
    let claim: DailyRewardManager.Claim
    /// Cierra el popup (lo pone quien lo presenta).
    let onClose: () -> Void

    /// El ×2 se miró en esta hoja: el botón se va por estado local (el `player`
    /// no se observa acá), como en el popup offline.
    @State private var doubled = false
    @State private var watching = false

    private var offersDouble: Bool {
        !doubled && gameState.canDoubleDailyReward(claim)
    }

    /// Duplicado, el monto que se muestra es el TOTAL (el mismo criterio del offline).
    private var shownCoins: Double {
        doubled ? claim.coinsGranted * 2 : claim.coinsGranted
    }

    /// ⚠️ **El monto NO rueda con `.contentTransition(.numericText())`, y se
    /// probó.** La versión que arrancaba en `+0` y rodaba hasta el premio
    /// terminaba **antes de que la hoja terminara de subir**: medido cuadro a
    /// cuadro sobre un video del simulador, el popup recién asoma cuando el
    /// número ya dice `+210`. O sea que no se veía ni el rodado ni el `+0` — era
    /// una animación muerta con dos propiedades de estado atrás. El contador del
    /// HUD, que sí cambia con la hoja quieta, es el que la usa de verdad.
    private var amountText: String {
        "+\(CoinFormatter.string(from: shownCoins))"
    }

    /// Los tres premios que puede traer el ciclo. Excluyentes: la tarjeta muestra
    /// uno solo.
    enum Prize: Equatable {
        case special(displayNameKey: String)
        case chest
        case coins
    }

    /// Qué premio muestra esta tarjeta.
    ///
    /// ⚠️ La decisión vive en UN solo lugar y es estática a propósito. Cuando
    /// estaba repartida entre el `ViewBuilder` y `axValue` eran dos ramas para
    /// tres premios, y el cofre del día 7 —sin special y sin plata— caía en el
    /// `else` de la plata: el jugador veía una moneda y **"+0"** mientras se le
    /// acreditaba un cofre en silencio. Pura y estática, además, para que el
    /// test pregunte qué se muestra sin instanciar la vista.
    static func prize(for claim: DailyRewardManager.Claim, specials: SpecialsConfig?) -> Prize {
        if let id = claim.specialGranted,
           let special = specials?.specials.first(where: { $0.id == id }) {
            return .special(displayNameKey: special.displayNameKey)
        }
        if claim.chestGranted { return .chest }
        return .coins
    }

    var body: some View {
        PopupContainer("daily.title", ribbonTint: Color("PaletteGreen"), onClose: close) {
            prizeCard
        } actions: {
            if offersDouble || watching {
                RewardedOfferButton(
                    title: String(localized: "daily.double"),
                    identifier: "daily.double",
                    placement: .daily,
                    isBusy: $watching,
                    gameRole: .video
                ) {
                    gameState.doubleDailyReward(claim)
                    doubled = true
                }
            }
            GameButton("offline.collect", role: .free, identifier: "daily.collect", action: close)
        }
    }

    /// Con el anuncio en vuelo no cierra (como el offline).
    private func close() {
        if !watching { onClose() }
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

    /// Los tres premios posibles: un personaje special (día 7), un cofre de
    /// pintas o plata.
    @ViewBuilder private var prize: some View {
        switch Self.prize(for: claim, specials: gameState.content?.specials) {
        case .special(let displayNameKey):
            portrait(titleKey: displayNameKey, kind: .gift)
        case .chest:
            portrait(titleKey: "daily.prize.chest", kind: .chest)
        case .coins:
            VStack(spacing: Tokens.s4) {
                RewardIllustration(kind: .coins, size: 88)
                Text(verbatim: amountText)
                    .font(Tokens.display)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    /// La ilustración del premio con el nombre debajo: el encuadre que
    /// comparten el special y el cofre.
    private func portrait(titleKey: String, kind: RewardKind) -> some View {
        VStack(spacing: Tokens.s4) {
            RewardIllustration(kind: kind, size: 88)
            Text(LocalizedStringKey(titleKey))
                .font(Tokens.display)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
    }

    /// Lo que VoiceOver anuncia como valor de la tarjeta: el premio, sea el
    /// personaje, el cofre o la plata.
    private var axValue: Text {
        switch Self.prize(for: claim, specials: gameState.content?.specials) {
        case .special(let displayNameKey):
            return Text(LocalizedStringKey(displayNameKey))
        case .chest:
            return Text(LocalizedStringKey("daily.prize.chest"))
        case .coins:
            return Text(verbatim: amountText)
        }
    }
}
