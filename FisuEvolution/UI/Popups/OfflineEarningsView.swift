import SwiftUI

/// "Mientras no estabas…" — el premio offline ya se acreditó al aplicarse; esta
/// hoja es sólo la celebración. F4 le suma el "doblar con un video".
///
/// Habla la misma anatomía que `DailyRewardView`, su gemelo de marco (el
/// mismo `PanelCard` con el moño asomando): banner de título, el monto sobre
/// la `GameCard` amarilla
/// —el acento de premio de la casa— y `ActionPill` verde como salida. Antes era
/// un `borderedProminent` de sistema sobre fuentes sueltas: se leía como una
/// alerta de iOS pegada adentro del moño.
struct OfflineEarningsView: View {
    let reward: GameState.OfflineReward
    @Environment(\.dismiss) private var dismiss
    @Environment(GameState.self) private var gameState
    @Environment(AdsCoordinator.self) private var ads

    /// El video está corriendo: la fila muestra el spinner y el botón de cobrar
    /// no puede cerrar la hoja abajo del anuncio.
    @State private var watching = false
    /// Ya se duplicó EN ESTA hoja. Se lee al abrir desde `GameState` —que es
    /// quien lo sabe si la hoja se reabre— y se sube acá para que la vista
    /// reaccione sin observar `player`.
    @State private var doubled = false

    /// Hay anuncio cargado para esta oferta.
    ///
    /// ⚠️ Es `@State` y se sondea, en vez de leer `ads` directo en el `body`, y
    /// la razón no es estilo: **`AdsCoordinator` no es observable a propósito**
    /// (todo `@ObservationIgnored`, para que reponer inventario no invalide
    /// vistas). Leerlo en el `body` daría `false` para siempre acá, porque el
    /// anuncio tarda 1-3 s en cargar y nada volvería a recomponer la hoja
    /// cuando llegue. El sondeo corto de `.task` es lo que hace aparecer el
    /// botón cuando el inventario llega.
    @State private var adReady = false

    /// La oferta se muestra sólo si hay inventario. Un botón de video que no
    /// carga es peor que no ofrecer nada: promete y no cumple.
    private var canOfferDouble: Bool { !doubled && !watching && adReady }

    private func watchToDouble() {
        guard canOfferDouble else { return }
        watching = true
        Task {
            let earned = await ads.showRewarded(for: .offlineX2)
            if earned {
                gameState.doubleOfflineReward(reward)
                doubled = true
            }
            watching = false
        }
    }

    var body: some View {
        // `PanelCard` es el tablón de las hojas en escala de tarjeta: los
        // insets son suyos, no medidos contra ningún arte (pedido del dueño,
        // 2026-08-18: una sola familia visual). El moño asomando sobre el
        // marco es la firma de la familia de premio: se abre como un regalo.
        PanelCard {
            VStack(spacing: Tokens.s16) {
                PanelTitleBanner(titleKey: "offline.title")
                // El monto sobre la tarjeta destacada en amarillo: el mismo
                // acento con el que el gemelo muestra su premio y la tira de
                // Regalos marca el día en juego.
                GameCard(style: .highlighted(Color("PaletteYellow"))) {
                    HStack(spacing: Tokens.s8) {
                        CoinIcon(size: 34)
                        // Duplicado, el monto que se muestra es el TOTAL: el
                        // jugador miró un video para ver un número más grande,
                        // así que el número más grande es lo que tiene que ver.
                        Text(verbatim: "+\(CoinFormatter.string(from: doubled ? reward.amount * 2 : reward.amount))")
                            .font(Tokens.display)
                            .monospacedDigit()
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.s4)
                }
                // La oferta va ARRIBA del botón de cobrar y no al lado: el
                // orden de lectura es la jerarquía, y "cobrar" es la salida.
                // Al lado, los dos botones compiten y el verde gana por color.
                if canOfferDouble {
                    ActionPill(
                        titleKey: "offline.double",
                        systemImage: "play.rectangle.fill",
                        tint: Color("PaletteBlue"),
                        identifier: "offline.double",
                        action: watchToDouble
                    )
                } else if watching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                ActionPill(
                    titleKey: "offline.collect",
                    systemImage: "checkmark",
                    tint: Color("PaletteGreen"),
                    identifier: "offline.collect",
                    // Con el anuncio en vuelo el botón no cierra: cerrar la
                    // hoja abajo de un anuncio a pantalla completa deja al
                    // jugador mirando publicidad sobre el tablero, y al volver
                    // no hay dónde acreditar.
                    action: { if !watching { dismiss() } }
                )
            }
            // Sin esto el panel se encoge al ancho ideal de su contenido y el
            // marco no llega a los bordes de la hoja (el mismo defecto que
            // anota `SkinAwardView`).
            .frame(maxWidth: .infinity)
            // El moño invade el tope del marco: este aire corre el banner
            // para que no se pisen.
            .padding(.top, Tokens.s8)
        }
        .overlay(alignment: .top) {
            GiftBowOrnament(width: 110)
                .offset(y: -24)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { dismiss() }
                .padding(10)
        }
        // Aire para la parte del moño que sobresale del marco: sin esto el
        // borde de la hoja lo recorta.
        .padding(.top, 26)
        .padding(16)
        .task {
            doubled = gameState.offlineRewardDoubled
            guard !doubled else { return }
            ads.preloadRewarded(for: .offlineX2)
            // Hasta 5 s esperando el inventario, a 4 Hz. Acotado: si el anuncio
            // no llegó, la hoja se queda como estaba —sin oferta— y el jugador
            // cobra y sigue. Ver el aviso de `adReady`.
            for _ in 0..<20 {
                if ads.isRewardedReady(for: .offlineX2) {
                    adReady = true
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        // Más alto cuando hay oferta: con el botón nuevo, 0,42 recortaba el de
        // cobrar contra el borde inferior del marco.
        .presentationDetents([.fraction(canOfferDouble || watching ? 0.52 : 0.42)])
        // El tablón no llega a los bordes de la hoja, así que el fondo de
        // sistema dejaba un rectángulo BLANCO alrededor del panel (el defecto
        // que `DailyRewardView` ya corrigió). Transparente, el panel flota
        // sobre el tablero.
        .presentationBackground(.clear)
    }
}
