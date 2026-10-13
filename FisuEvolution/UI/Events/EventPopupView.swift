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
        if let event = gameState.content?.events.event(id: eventId) {
            PopupContainer(verbatim: VisitCopy.text(event.titleKey), ribbonTint: ActiveBonusBar.tint(event.polarity),
                           onClose: { gameState.closeEventPopup() }) {
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
                        IconCanvas { MarkDisc(mark: Self.mark(event.polarity), fill: ActiveBonusBar.tint(event.polarity)) }
                            .frame(width: 22, height: 22)
                            .accessibilityHidden(true)
                        Text(verbatim: chip.effectText)
                        Spacer(minLength: Tokens.s8)
                        Text("event.popup.remaining \(ActiveBonusBar.timeText(max(0, chip.expiresAt - now.timeIntervalSince1970)))")
                            .monospacedDigit()
                    }
                    .font(Tokens.body)
                    .foregroundStyle(ActiveBonusBar.tint(event.polarity))
                }
                waitLine(event)
            } actions: {
                escapes(event)
            }
            .onReceive(timer) { tick in
                now = tick
                if !gameState.isEventRunning(id: eventId, now: tick.timeIntervalSince1970) { gameState.closeEventPopup() }
            }
        }
    }

    /// La marca del disco de la polaridad: sube, baja o las dos.
    private static func mark(_ polarity: EventCatalog.Polarity) -> String {
        switch polarity {
        case .positive: "↑"
        case .negative: "↓"
        case .mixed: "↕"
        }
    }

    private static let illustrationHeight: CGFloat = 120

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

    /// Sin salida a mano, la línea de «aguantá» o «disfrutalo». Dos `Text` y no
    /// un ternario adentro de uno: el ternario de dos literales es un `String` y
    /// `Text` lo mostraría crudo, sin traducir.
    @ViewBuilder
    private func waitLine(_ event: EventCatalog.Event) -> some View {
        if gameState.usableEscapes(of: event).isEmpty {
            (event.polarity == .negative ? Text("event.popup.wait") : Text("event.popup.enjoy"))
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        }
    }

    /// Las salidas, en el pie del popup.
    @ViewBuilder
    private func escapes(_ event: EventCatalog.Event) -> some View {
        ForEach(gameState.usableEscapes(of: event), id: \.kind) { escape in
            escapeButton(escape, of: event)
        }
    }

    @ViewBuilder
    private func escapeButton(_ escape: EventCatalog.Escape, of event: EventCatalog.Event) -> some View {
        switch escape.kind {
        case .video:
            RewardedOfferButton(title: String(localized: "event.escape.video"), identifier: "event.escape", placement: .visitor,
                                gameRole: .video) {
                gameState.escapeEvent(id: event.id, via: .video)
            }
        case .fee:
            let title = String(localized: "event.escape.fee \(gameState.eventFeeText(id: event.id))")
            let affords = (gameState.player?.run.coins ?? 0) >= (gameState.eventFee(id: event.id) ?? .infinity)
            GameButton(verbatim: title, role: .coins, available: affords, identifier: "event.escape.fee") {
                if affords { gameState.escapeEvent(id: event.id, via: .fee) }
            }
        case .free:
            GameButton("event.escape.free", role: .neutral, medallion: .none, identifier: "event.escape.free") {
                gameState.escapeEvent(id: event.id, via: .free)
            }
        }
    }
}
