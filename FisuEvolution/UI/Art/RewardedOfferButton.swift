import SwiftUI

/// El botón de "mirá un video y…" de la 2.0 (PLAN-v2, cimientos): Regalos,
/// el offline, el cofre extra, el Corralito y, después, visitantes, cartas del
/// Vendedor, ruleta y ofertas. Es el contrato de E13 ítem 1:
///
/// - **No ofrece lo que no tiene.** Precarga al aparecer y sondea hasta que el
///   video llega (`pollInterval`): mientras tanto dice "Cargando…" en vez de un
///   botón que no haría nada; el sondeo se corta cuando la vista se va.
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
/// `<identifier>.loading` (esperando el video), `<identifier>.watching` (cargando
/// o en pantalla) y `<identifier>.unavailable` (el aviso).
struct RewardedOfferButton: View {
    let title: String
    let identifier: String
    let placement: RewardedPlacement
    var systemImage = "play.fill"
    var tint = Color("PaletteGreen")
    /// Etiqueta hablada, para las filas donde el título solo no dice de QUÉ.
    var accessibilityLabel: Text?
    /// Lo que el padre necesite saber del botón ocupado (p. ej. no cerrar la
    /// hoja bajo el anuncio). Se actualiza solo; el padre sólo lo lee.
    var isBusy: Binding<Bool>?
    let onRewarded: () -> Void

    @Environment(AdsCoordinator.self) private var ads
    @State private var offer = RewardedOffer()
    /// Hay un video listo para mostrar. Lo decide el sondeo, no el toque.
    @State private var inventoryReady = false
    /// Cambia después de cada video: rearranca la espera del próximo.
    @State private var generation = 0

    var body: some View {
        VStack(spacing: Tokens.s4) {
            if offer.phase == .busy {
                busyPill
            } else if !inventoryReady && offer.phase != .unavailable {
                loadingBadge
            } else {
                ActionPill(
                    verbatim: title, systemImage: systemImage, tint: tint, identifier: identifier,
                    accessibilityLabel: accessibilityLabel, action: tap
                )
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
        var attempt = 0
        while !Task.isCancelled {
            if ads.isRewardedReady(for: placement) {
                inventoryReady = true
                return
            }
            try? await Task.sleep(for: Self.pollInterval(attempt: attempt))
            attempt += 1
        }
    }

    private func tap() {
        offer.tap(ads: ads, placement: placement, onRewarded: Self.releasing(isBusy, then: onRewarded))
    }

    /// El premio suelta el `isBusy` ANTES de entregarse: `onRewarded` suele sacar
    /// al botón del árbol, y entonces el `onChange` de la fase ya no corre.
    static func releasing(_ isBusy: Binding<Bool>?, then onRewarded: @escaping () -> Void) -> () -> Void {
        {
            isBusy?.wrappedValue = false
            onRewarded()
        }
    }

    /// Lo que se ve mientras el video no llegó: no es un control.
    private var loadingBadge: some View {
        StateBadge(text: String(localized: "ads.preparing"), systemImage: "hourglass", textAlignment: .center, muted: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("\(identifier).loading")
    }

    /// El botón mientras carga o corre el video: misma cápsula, ruedita y
    /// "Cargando video…". No es un control (los toques se ignoran).
    private var busyPill: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            Text("ads.loading")
                .font(Tokens.body)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
        .padding(.horizontal, Tokens.s12)
        .padding(.vertical, Tokens.s8)
        .frame(minWidth: 92)
        .background(PillBackground(fill: tint))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("ads.loading"))
        .accessibilityIdentifier("\(identifier).watching")
    }
}
