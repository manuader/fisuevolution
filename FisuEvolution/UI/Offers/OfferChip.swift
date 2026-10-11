import EconomyKit
import SwiftUI

/// La oferta abierta, bajo el HUD: su ícono y cuánto falta. Tocarlo reabre la
/// hoja. Sin oferta abierta no ocupa lugar. El reloj es de la vista (1 Hz), como
/// el de `ActiveBonusBar`: el tiempo restante nunca va a una proyección.
struct OfferChip: View {
    @Environment(GameState.self) private var gameState
    let onOpen: (String) -> Void

    var body: some View {
        let _ = gameState.effectsVersion
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let offer = gameState.visibleOffers(now: context.date.timeIntervalSince1970).first,
               let definition = gameState.content?.offers.offer(id: offer.id) {
                Button { onOpen(offer.id) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: definition.symbol)
                            .font(.system(size: 14, weight: .black))
                            .accessibilityHidden(true)
                        Text(verbatim: OfferCopy.countdown(until: offer.expiresAt, now: context.date))
                            .font(Tokens.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Tokens.s12)
                    .padding(.vertical, 6)
                    .background(PillBackground(fill: Color("PalettePink")))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hud.offer.chip")
                .accessibilityValue(Text(verbatim: OfferCopy.countdown(until: offer.expiresAt, now: context.date)))
                .accessibilityLabel(Text("offer.chip.ax \(IAPCopy.name(for: definition.productId, fallback: definition.id))"))
                .tutorialAnchor(.offerChip)
            }
        }
    }
}
