import SwiftUI

/// El botón de "mirá un video y…" de la 2.0 (PLAN-v2, cimientos): Regalos,
/// el offline, el cofre extra, el Corralito y, después, visitantes, cartas del
/// Vendedor, ruleta y ofertas. Es el contrato de E13 ítem 1:
///
/// - **Responde al primer toque.** Desde ahí dice "Cargando video…" con su
///   ruedita, aunque el anuncio todavía no haya llegado: el proveedor espera la
///   carga hasta 8 s y presenta apenas está.
/// - **Un solo video por botón.** Mientras carga o presenta, los toques se
///   ignoran (`RewardedOffer`).
/// - **Si no hay videos, lo dice** ("No hay videos ahora, probá en un rato") y
///   queda tappable por si el jugador reintenta.
/// - **Precarga al aparecer** la unidad de su `placement`.
///
/// La recompensa se entrega SÓLO si el anuncio terminó con premio
/// (`onRewarded`). Los ids de accesibilidad: `<identifier>` (el botón),
/// `<identifier>.watching` (cargando o en pantalla) y `<identifier>.unavailable`
/// (el aviso).
struct RewardedOfferButton: View {
    let title: String
    let identifier: String
    var placement: RewardedPlacement = .visitor
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

    var body: some View {
        VStack(spacing: Tokens.s4) {
            if offer.phase == .busy {
                busyPill
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
        .onAppear { ads.preloadRewarded(for: placement) }
        .onDisappear { offer.cancel() }
        .onChange(of: offer.phase) { _, phase in
            isBusy?.wrappedValue = phase == .busy
        }
    }

    private func tap() {
        offer.tap(ads: ads, placement: placement, onRewarded: onRewarded)
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
