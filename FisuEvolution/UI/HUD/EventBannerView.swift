import SwiftUI

/// Banner del evento activo (bible §1). Accesible para daltónicos: además del
/// color lleva ícono direccional y texto — nunca solo color.
struct EventBannerView: View {
    let event: EventManager.ActiveEvent
    @Environment(GameState.self) private var gameState
    @Environment(AdsCoordinator.self) private var ads
    @State private var now = Date()
    @State private var videoReady = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // El botón va debajo y no al costado: al lado le robaba el ancho al
        // texto y en el iPhone SE el motivo del evento salía cortado.
        VStack(alignment: .trailing, spacing: 8) {
            bannerText
            if event.escapableByVideo && videoReady {
                ActionPill(
                    titleKey: "event.escape.video", systemImage: "play.fill",
                    tint: Color("PaletteGreen"), identifier: "event.escape"
                ) {
                    Task {
                        if await ads.showRewarded(for: .visitor) { gameState.escapeActiveEvent() }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            // Materiales v3: el mismo tono con su borde hundido, como todo
            // chip del juego (la tipografía de sistema y el rect sin borde
            // eran el único resto del pre-rediseño en el HUD).
            let fill = (event.isBuff ? Color("PaletteGreen") : Color("PalettePink")).opacity(0.92)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(fill.deepened(0.3), lineWidth: 2)
                )
        }
        .foregroundStyle(Color("PaletteInk"))
        .padding(.horizontal, 16)
        .onAppear { refreshVideoReady(preloading: true) }
        .onReceive(timer) {
            now = $0
            refreshVideoReady(preloading: false)
        }
    }

    /// El texto del evento es el único elemento con `hud.event`: el botón de
    /// video queda afuera (un id en un contenedor pisa el de sus hijos).
    private var bannerText: some View {
        HStack(spacing: 8) {
            Image(systemName: event.isBuff ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
            Text(LocalizedStringKey(event.flavorTextKey))
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

    private func refreshVideoReady(preloading: Bool) {
        guard event.escapableByVideo else { return }
        if preloading { ads.preloadRewarded(for: .visitor) }
        let ready = ads.isRewardedReady(for: .visitor)
        if videoReady != ready { videoReady = ready }
    }

    private var remainingSeconds: Int {
        max(0, Int(event.endsAt - now.timeIntervalSince1970))
    }
}
