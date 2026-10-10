import SwiftUI

/// La ruleta en Regalos: cuántos giros quedan hoy y el botón que la abre.
struct WheelGiftCard: View {
    let availability: WheelAvailability
    let open: () -> Void

    var body: some View {
        GameCard(style: availability.hasFreeSpin ? .highlighted(Color("PaletteYellow")) : .normal) {
            HStack(spacing: Tokens.s12) {
                GameIcon(artKey: "wheel_icon", size: 46) { WheelGlyph() }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("gifts.wheel.title")
                        .font(Tokens.body)
                    Text(verbatim: subtitle)
                        .font(Tokens.caption)
                        .opacity(0.75)
                }
                .foregroundStyle(Color("PaletteInk"))
                Spacer(minLength: Tokens.s8)
                ActionPill(titleKey: "gifts.wheel.open", systemImage: "arrow.clockwise.circle.fill",
                           tint: Color("PaletteOrange"), identifier: "gifts.wheel.open", action: open)
            }
        }
    }

    private var subtitle: String {
        if availability.bonus > 0 { return RewardCopy.text("gifts.wheel.bonus", String(availability.bonus)) }
        if availability.videoLeft > 0 { return RewardCopy.text("gifts.wheel.left", String(availability.videoLeft)) }
        return String(localized: "gifts.wheel.empty")
    }
}
