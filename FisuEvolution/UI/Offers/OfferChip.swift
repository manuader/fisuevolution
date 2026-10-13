import EconomyKit
import SwiftUI

/// El sello de la oferta abierta, en la columna de la derecha bajo el
/// especial (C19): el ícono custom de la oferta y, debajo, una cinta con el
/// reloj y cuánto falta. Tocarlo reabre la hoja. Sin oferta abierta no ocupa
/// lugar. El reloj es de la vista (1 Hz), como el de `ActiveBonusBar`: el
/// tiempo restante nunca va a una proyección.
struct OfferChip: View {
    @Environment(GameState.self) private var gameState
    let onOpen: (String) -> Void

    var body: some View {
        let _ = gameState.effectsVersion
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let offer = gameState.visibleOffers(now: context.date.timeIntervalSince1970).first,
               let definition = gameState.content?.offers.offer(id: offer.id) {
                let countdown = OfferCopy.countdown(until: offer.expiresAt, now: context.date)
                Button { onOpen(offer.id) } label: {
                    VStack(spacing: -SideRailLayout.ribbonOverlap) {
                        GameGlyphView(glyph: .art(definition.iconKey), size: SideRailLayout.seal)
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                        HStack(spacing: 3) {
                            GameGlyphView(glyph: .clock, size: 13)
                            Text(verbatim: countdown)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Tokens.s4)
                        .frame(minWidth: SideRailLayout.seal + 2, minHeight: SideRailLayout.ribbonHeight)
                        .background(PillBackground(fill: Color("PalettePink"), lip: 2))
                    }
                    .frame(width: SideRailLayout.touchWidth)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hud.offer.chip")
                .accessibilityValue(Text(verbatim: countdown))
                .accessibilityLabel(Text("offer.chip.ax \(IAPCopy.name(for: definition.productId, fallback: definition.id))"))
                .tutorialAnchor(.offerChip)
            }
        }
    }
}
