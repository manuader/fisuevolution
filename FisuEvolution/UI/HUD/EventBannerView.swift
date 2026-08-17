import SwiftUI

/// Banner del evento activo (bible §1). Accesible para daltónicos: además del
/// color lleva ícono direccional y texto — nunca solo color.
struct EventBannerView: View {
    let event: EventManager.ActiveEvent
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
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
        .onReceive(timer) { now = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hud.event")
    }

    private var remainingSeconds: Int {
        max(0, Int(event.endsAt - now.timeIntervalSince1970))
    }
}
