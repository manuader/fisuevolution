import SwiftUI

/// El botón de "mirá un video y…" de la 2.0 (PLAN-v2, cimientos): Regalos,
/// el offline, el cofre extra, el Corralito y, después, visitantes, cartas del
/// Vendedor, ruleta y ofertas. Es el contrato de E13 ítem 1:
///
/// - **No ofrece lo que no tiene.** Precarga al aparecer y sondea hasta que el
///   video llega (`pollInterval`): mientras tanto dice "Cargando…" en vez de un
///   botón que no haría nada; el sondeo se corta cuando la vista se va.
/// - **Sin red, lo dice.** Si a los 10 s el video no llegó, el "Cargando…" pasa a
///   "Sin conexión" y un toque reintenta (`InventoryWait`): vuelve a "Cargando…"
///   y reinicia el reloj. El sondeo sigue: si el video llega, el botón aparece.
/// - **Responde al primer toque.** Desde ahí dice "Cargando video…" con su
///   ruedita, aunque el anuncio todavía no haya llegado: el proveedor espera la
///   carga hasta 8 s y presenta apenas está.
/// - **Un solo video por botón.** Mientras carga o presenta, los toques se
///   ignoran (`RewardedOffer`).
/// - **Si no hay videos, lo dice** ("No hay videos ahora, probá en un rato") y
///   queda tappable por si el jugador reintenta.
/// - **La unidad es obligatoria** (`placement`): cada llamador es una fila del
///   mapa de ubicaciones (`AdPlacementMapTests`).
///
/// La recompensa se entrega SÓLO si el anuncio terminó con premio
/// (`onRewarded`). Los ids de accesibilidad: `<identifier>` (el botón),
/// `<identifier>.loading` (esperando el video), `<identifier>.offline` (pasaron
/// 10 s sin video; tappable), `<identifier>.watching` (cargando o en pantalla) y
/// `<identifier>.unavailable` (el aviso).
/// El reloj de la espera del video: a los `timeout` sin que llegue, el botón
/// pasa de "Cargando…" a "Sin conexión". Valor puro: el instante de "ahora" lo
/// pone el llamador, así la transición se prueba sin esperar.
struct InventoryWait: Equatable {
    static let timeout: Duration = .seconds(10)

    let startedAt: ContinuousClock.Instant

    func isOffline(at now: ContinuousClock.Instant) -> Bool {
        now - startedAt >= Self.timeout
    }
}

struct RewardedOfferButton: View {
    let title: String
    let identifier: String
    let placement: RewardedPlacement
    /// Etiqueta hablada, para las filas donde el título solo no dice de QUÉ.
    var accessibilityLabel: Text?
    /// Lo que el padre necesite saber del botón ocupado (p. ej. no cerrar la
    /// hoja bajo el anuncio). Se actualiza solo; el padre sólo lo lee.
    var isBusy: Binding<Bool>?
    /// El botón de la casa de E14 (C19): el video es `.video` y todos los
    /// estados —cargando, sin conexión, en curso— hablan `GameButton`.
    var gameRole: GameButton.Role = .video
    /// Chico y sin medallón, para la fila de cartas del Vendedor (tres en el SE).
    var gameCompact = false
    /// El ciclo del video para quien lo sigue fuera de la vista (el paso 2 del ×2, E14b B29): `onWatchStarted`
    /// al aceptar el toque y `onWatchEnded` cuando el anuncio vuelve —con premio, después de `onRewarded`—,
    /// aunque el botón ya no esté en pantalla.
    var onWatchStarted: () -> Void = {}
    var onWatchEnded: (_ earned: Bool) -> Void = { _ in }
    let onRewarded: () -> Void

    @Environment(AdsCoordinator.self) private var ads
    @State private var offer = RewardedOffer()
    /// Hay un video listo para mostrar. Lo decide el sondeo, no el toque.
    @State private var inventoryReady = false
    /// Pasaron `InventoryWait.timeout` sin video: el badge dice "Sin conexión".
    @State private var offline = false
    /// Cambia después de cada video: rearranca la espera del próximo.
    @State private var generation = 0

    var body: some View {
        VStack(spacing: Tokens.s4) {
            if offer.phase == .busy {
                gameStatus(String(localized: "ads.loading"), role: gameRole, suffix: "watching")
            } else if !inventoryReady && offer.phase != .unavailable {
                if offline {
                    gameStatus(String(localized: "ads.offline"), role: .neutral, suffix: "offline", action: retry)
                } else {
                    gameStatus(String(localized: "ads.preparing"), role: .neutral, suffix: "loading")
                }
            } else {
                GameButton(verbatim: title, role: gameRole, medallion: gameCompact ? .none : .automatic,
                           size: gameCompact ? .compact : .regular, identifier: identifier,
                           accessibilityLabel: accessibilityLabel, action: tap)
            }
            if offer.phase == .unavailable {
                Text("ads.unavailable.now")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).unavailable")
            }
        }
        .task(id: generation) { await waitForInventory() }
        .onDisappear {
            offer.cancel()
            isBusy?.wrappedValue = false
        }
        .onChange(of: offer.phase) { old, phase in
            isBusy?.wrappedValue = phase == .busy
            if old == .busy {
                // El video se gastó: el próximo hay que esperarlo de nuevo.
                inventoryReady = false
                offline = false
                generation += 1
            }
        }
    }

    /// 4 Hz los primeros 5 s (un video suele tardar 1–3 s) y después cada 2 s,
    /// mientras la vista exista: si el video llega tarde, el botón aparece solo.
    nonisolated static func pollInterval(attempt: Int) -> Duration {
        attempt < 20 ? .milliseconds(250) : .seconds(2)
    }

    /// Precarga y sondea hasta que el video está. `.task` lo cancela solo cuando
    /// la vista se va, así que no quedan esperas colgadas.
    private func waitForInventory() async {
        ads.preloadRewarded(for: placement)
        let wait = InventoryWait(startedAt: .now)
        var attempt = 0
        while !Task.isCancelled {
            if ads.isRewardedReady(for: placement) {
                inventoryReady = true
                offline = false
                return
            }
            if wait.isOffline(at: .now) { offline = true }
            try? await Task.sleep(for: Self.pollInterval(attempt: attempt))
            attempt += 1
        }
    }

    private func tap() {
        let started = offer.tap(ads: ads, placement: placement, onRewarded: Self.releasing(isBusy, then: onRewarded),
                                onFinished: onWatchEnded)
        if started { onWatchStarted() }
    }

    /// El premio suelta el `isBusy` ANTES de entregarse: `onRewarded` suele sacar
    /// al botón del árbol, y entonces el `onChange` de la fase ya no corre.
    static func releasing(_ isBusy: Binding<Bool>?, then onRewarded: @escaping () -> Void) -> () -> Void {
        {
            isBusy?.wrappedValue = false
            onRewarded()
        }
    }

    /// Los estados de espera con el botón de la casa: el reloj en el medallón,
    /// sin SF Symbols. No son controles salvo el reintento (`action`).
    private func gameStatus(
        _ text: String, role: GameButton.Role, suffix: String, action: @escaping () -> Void = {}
    ) -> some View {
        GameButton(verbatim: text, role: role, medallion: role == .neutral && !gameCompact ? .glyph(.clock) : .none,
                   size: gameCompact ? .compact : .regular, identifier: "\(identifier).\(suffix)", action: action)
    }

    private func retry() {
        offline = false
        generation += 1
    }
}
