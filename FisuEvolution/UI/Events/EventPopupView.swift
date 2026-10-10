import EconomyKit
import SwiftUI

/// El popup de un evento corriendo (PLAN-v2 E4): quien lo anunció, su frase en
/// el globo, qué cambia, cuánto falta y por dónde se sale. Se cierra solo
/// cuando el evento termina.
struct EventPopupView: View {
    let eventId: String
    @Environment(GameState.self) private var gameState
    @State private var now = Date()
    @Environment(\.loopsManifest) private var loops

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        PanelCard {
            if let event = gameState.content?.events.event(id: eventId) {
                VStack(spacing: Tokens.s12) {
                    PanelTitleBanner(verbatim: VisitCopy.text(event.titleKey))
                    illustration(event)
                    HStack(alignment: .center, spacing: Tokens.s12) {
                        VisitorFace(visitorId: gameState.eventPresenterId(event), side: 76)
                        Text(verbatim: VisitCopy.text(event.phraseKey))
                            .font(Tokens.prose)
                            .foregroundStyle(Color("PaletteInk"))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(Tokens.s12)
                            .background(
                                RoundedRectangle(cornerRadius: BubbleGeometry.cornerRadius, style: .continuous)
                                    .fill(Color("PaletteCream"))
                                    .overlay(RoundedRectangle(cornerRadius: BubbleGeometry.cornerRadius, style: .continuous)
                                        .strokeBorder(Color("PaletteInk"), lineWidth: 2))
                            )
                    }
                    if let chip = gameState.activeBonuses.first(where: { $0.eventId == eventId }) {
                        HStack(spacing: Tokens.s8) {
                            Image(systemName: ActiveBonusBar.symbol(event.polarity))
                            Text(verbatim: chip.effectText)
                            Spacer(minLength: Tokens.s8)
                            Text("event.popup.remaining \(ActiveBonusBar.timeText(max(0, chip.expiresAt - now.timeIntervalSince1970)))")
                                .monospacedDigit()
                        }
                        .font(Tokens.body)
                        .foregroundStyle(ActiveBonusBar.tint(event.polarity))
                    }
                    escapes(event)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.s8)
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { gameState.closeEventPopup() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(hasIllustration ? 0.62 : 0.52)])
        .fisuSheet()
        .onReceive(timer) { tick in
            now = tick
            if !gameState.isEventRunning(id: eventId, now: tick.timeIntervalSince1970) { gameState.closeEventPopup() }
        }
    }

    private static let illustrationHeight: CGFloat = 120

    private var hasIllustration: Bool {
        Self.illustrationClip(for: eventId, in: loops) != nil
    }

    /// El clip del evento, sólo si además tiene póster: sin los dos, el popup queda como siempre.
    static func illustrationClip(for eventId: String, in manifest: LoopsManifest) -> ArtClip? {
        guard UIArt.image(posterKey(eventId)) != nil else { return nil }
        return ArtClips.event(eventId, in: manifest)
    }

    private static func posterKey(_ eventId: String) -> String { "ui_event_\(eventId)" }

    @ViewBuilder
    private func illustration(_ event: EventCatalog.Event) -> some View {
        if let clip = Self.illustrationClip(for: event.id, in: loops),
           let poster = UIArt.image(Self.posterKey(event.id)) {
            AnimatedArtView(clip: clip, role: .popup) {
                poster.resizable().scaledToFit()
            }
            .frame(height: Self.illustrationHeight)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func escapes(_ event: EventCatalog.Event) -> some View {
        let usable = gameState.usableEscapes(of: event)
        if usable.isEmpty {
            // Dos `Text` y no un ternario adentro de uno: el ternario de dos literales
            // es un `String` y `Text` lo mostraría crudo, sin traducir.
            (event.polarity == .negative ? Text("event.popup.wait") : Text("event.popup.enjoy"))
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        } else {
            VStack(spacing: Tokens.s8) {
                ForEach(usable, id: \.kind) { escape in
                    escapeButton(escape, of: event)
                }
            }
        }
    }

    @ViewBuilder
    private func escapeButton(_ escape: EventCatalog.Escape, of event: EventCatalog.Event) -> some View {
        switch escape.kind {
        case .video:
            RewardedOfferButton(title: String(localized: "event.escape.video"), identifier: "event.escape") {
                gameState.escapeEvent(id: event.id, via: .video)
            }
        case .fee:
            let title = String(localized: "event.escape.fee \(gameState.eventFeeText(id: event.id))")
            if (gameState.player?.run.coins ?? 0) >= (gameState.eventFee(id: event.id) ?? .infinity) {
                ActionPill(verbatim: title, systemImage: "banknote.fill", tint: Color("PaletteOrange"),
                           identifier: "event.escape.fee") {
                    gameState.escapeEvent(id: event.id, via: .fee)
                }
            } else {
                StateBadge(text: title, systemImage: "lock.fill", textAlignment: .center, muted: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("event.escape.fee")
            }
        case .free:
            ActionPill(titleKey: "event.escape.free", systemImage: "xmark", tint: Color("PaletteBlue"),
                       identifier: "event.escape.free") {
                gameState.escapeEvent(id: event.id, via: .free)
            }
        }
    }
}
