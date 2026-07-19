import SwiftUI

/// HUD superior: tienda | monedas | bonus. Observa proyecciones de `GameState`.
struct HUDView: View {
    @Environment(GameState.self) private var gameState
    var onStoreTap: () -> Void = {}
    var onBonusTap: () -> Void = {}
    var onUpgradesTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            hudIconButton(systemName: "cart.fill", labelKey: "hud.store.label", identifier: "hud.store", action: onStoreTap)
            hudIconButton(systemName: "arrow.up.circle.fill", labelKey: "hud.upgrades.label", identifier: "hud.upgrades", action: onUpgradesTap)
            Spacer()
            coinCounter
            Spacer()
            hudIconButton(systemName: "gift.fill", labelKey: "hud.bonus.label", identifier: "hud.bonus", action: onBonusTap)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var coinCounter: some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(Color("PaletteYellow"))
            Text(verbatim: gameState.coinsText)
                .font(.title2.weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color("PaletteCream"), in: .capsule)
        .overlay(Capsule().stroke(Color("PaletteInk").opacity(0.3), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.coins")
        .accessibilityLabel(Text("hud.coins.label"))
        .accessibilityValue(Text(verbatim: gameState.coinsText))
    }

    private func hudIconButton(systemName: String, labelKey: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .padding(10)
                .background(Color("PaletteCream"), in: .circle)
                .overlay(Circle().stroke(Color("PaletteInk").opacity(0.3), lineWidth: 1.5))
        }
        .tint(Color("PaletteInk"))
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey)))
    }
}
