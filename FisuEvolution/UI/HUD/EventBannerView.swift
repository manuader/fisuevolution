import EconomyKit
import SwiftUI

/// El banner del evento activo: la frase, cuánto falta y sus salidas. Accesible
/// para daltónicos: además del color lleva ícono direccional y texto — nunca
/// sólo color. Vive hasta que E4b lo reemplace por el chip con la cara del
/// presentador.
struct EventBannerView: View {
    let event: GameState.ActiveEvent
    @Environment(GameState.self) private var gameState
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // Las salidas van debajo y no al costado: al lado le robaban el ancho al
        // texto y en el iPhone SE el motivo del evento salía cortado.
        VStack(alignment: .trailing, spacing: 8) {
            bannerText
            if !event.escapes.isEmpty {
                HStack(spacing: 8) {
                    ForEach(event.escapes, id: \.kind) { escape in
                        escapeButton(escape)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            // Materiales v3: el mismo tono con su borde hundido, como todo
            // chip del juego.
            let fill = tint.opacity(0.92)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(fill.deepened(0.3), lineWidth: 2)
                )
        }
        .foregroundStyle(Color("PaletteInk"))
        .padding(.horizontal, 16)
        .onReceive(timer) { now = $0 }
    }

    /// El texto del evento es el único elemento con `hud.event`: los botones
    /// quedan afuera (un id en un contenedor pisa el de sus hijos).
    private var bannerText: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
            Text(LocalizedStringKey(event.phraseKey))
                .font(Tokens.body)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            if remainingSeconds > 0 {
                Text(verbatim: "\(remainingSeconds)s")
                    .font(Tokens.caption)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hud.event")
    }

    @ViewBuilder
    private func escapeButton(_ escape: EventCatalog.Escape) -> some View {
        switch escape.kind {
        case .video:
            RewardedOfferButton(
                title: String(localized: "event.escape.video"),
                identifier: "event.escape",
                placement: .visitor
            ) {
                gameState.escapeEvent(id: event.id, via: .video)
            }
        case .fee:
            ActionPill(
                verbatim: String(localized: "event.escape.fee \(gameState.eventFeeText(id: event.id))"),
                systemImage: "banknote.fill", tint: Color("PaletteOrange"), identifier: "event.escape.fee"
            ) {
                gameState.escapeEvent(id: event.id, via: .fee)
            }
        case .free:
            ActionPill(titleKey: "event.escape.free", systemImage: "xmark", tint: Color("PaletteBlue"),
                       identifier: "event.escape.free") {
                gameState.escapeEvent(id: event.id, via: .free)
            }
        }
    }

    private var tint: Color {
        switch event.polarity {
        case .positive: Color("PaletteGreen")
        case .negative: Color("PalettePink")
        case .mixed: Color("PaletteOrange")
        }
    }

    private var symbol: String {
        switch event.polarity {
        case .positive: "arrow.up.circle.fill"
        case .negative: "arrow.down.circle.fill"
        case .mixed: "arrow.up.arrow.down.circle.fill"
        }
    }

    private var remainingSeconds: Int {
        max(0, Int(event.endsAt - now.timeIntervalSince1970))
    }
}
