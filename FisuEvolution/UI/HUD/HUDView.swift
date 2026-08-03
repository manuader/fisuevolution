import SwiftUI

/// HUD superior: tienda | monedas | bonus. Observa proyecciones de `GameState`.
struct HUDView: View {
    @Environment(GameState.self) private var gameState
    var onStoreTap: () -> Void = {}
    var onBonusTap: () -> Void = {}
    var onUpgradesTap: () -> Void = {}
    var onSettingsTap: () -> Void = {}

    var body: some View {
        // Agrupado izq/der con Spacers flexibles: los botones de las puntas nunca
        // se recortan contra el borde de la pantalla (bug de desborde horizontal).
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                hudIconButton(systemName: "cart.fill", tint: Color("PaletteOrange"), labelKey: "hud.store.label", identifier: "hud.store", action: onStoreTap)
                hudIconButton(systemName: "arrow.up.circle.fill", tint: Color("PaletteGreen"), labelKey: "hud.upgrades.label", identifier: "hud.upgrades", action: onUpgradesTap)
            }
            Spacer(minLength: 6)
            coinCounter
            Spacer(minLength: 6)
            HStack(spacing: 8) {
                hudIconButton(systemName: "gift.fill", tint: Color("PalettePink"), labelKey: "hud.bonus.label", identifier: "hud.bonus", action: onBonusTap)
                hudIconButton(systemName: "gearshape.fill", tint: Color("PaletteBlue"), labelKey: "hud.settings.label", identifier: "hud.settings", action: onSettingsTap)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        // Scrim crema translúcido: despega el HUD del arte de fondo (tendedero,
        // graffiti) para que los botones siempre se lean.
        .background {
            LinearGradient(
                colors: [Color("PaletteCream").opacity(0.55), Color("PaletteCream").opacity(0.0)],
                startPoint: .top, endPoint: .bottom
            )
            .padding(.top, -60)   // extiende el scrim bajo la barra de estado
            .allowsHitTesting(false)
        }
    }

    private var coinCounter: some View {
        CurrencyPill {
            HStack(spacing: 6) {
                CoinIcon(size: 26)
                Text(verbatim: gameState.coinsText)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: 108)
            }
            .frame(minWidth: 84)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.coins")
        .accessibilityLabel(Text("hud.coins.label"))
        .accessibilityValue(Text(verbatim: gameState.coinsText))
    }

    /// Botón de icono unificado: misma base (círculo crema + borde ink), mismo
    /// tamaño; el color del glifo codifica la función. Un solo sistema en vez de
    /// cuatro formas/colores distintos.
    private func hudIconButton(systemName: String, tint: Color, labelKey: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(
                    Circle().fill(Color("PaletteCream"))
                        .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey)))
    }
}
