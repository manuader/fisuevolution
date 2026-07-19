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
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            if remainingSeconds > 0 {
                Text(verbatim: "\(remainingSeconds)s")
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background((event.isBuff ? Color("PaletteGreen") : Color("PalettePink")).opacity(0.92), in: .rect(cornerRadius: 12))
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
