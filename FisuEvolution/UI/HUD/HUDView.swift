import SwiftUI

/// HUD superior: tienda | monedas | bonus. Observa proyecciones de `GameState`.
struct HUDView: View {
    @Environment(GameState.self) private var gameState
    var onStoreTap: () -> Void = {}
    var onBonusTap: () -> Void = {}
    var onUpgradesTap: () -> Void = {}
    var onSettingsTap: () -> Void = {}
    /// El mapa se presenta desde acá y no desde `RootView` a propósito: vive
    /// pegado a las flechas de la torre, que es lo único que reemplaza.
    @State private var showFloorMap = false

    var body: some View {
        // Agrupado izq/der con Spacers flexibles: los botones de las puntas nunca
        // se recortan contra el borde de la pantalla (bug de desborde horizontal).
        VStack(spacing: 5) {
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
            towerNavigator
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

    private var towerNavigator: some View {
        let navigation = gameState.towerNavigation
        return HStack(spacing: 6) {
            towerArrow(systemName: "chevron.down", direction: -1, enabled: navigation.canNavigateDown, identifier: "tower.arrow.down")
            VStack(spacing: 1) {
                Text(floorNameKey(for: navigation.floorID))
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .lineLimit(1)
                Text("\(navigation.ordinal + 1)/\(navigation.totalFloors) · \(navigation.occupied)/\(navigation.capacity) · \(gameState.towerIncomePerSecondText)/s")
                    .font(.system(size: 10, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(Color("PaletteInk"))
            .frame(minWidth: 130)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("tower.pill")
            .accessibilityLabel(Text(floorNameKey(for: navigation.floorID)))
            .accessibilityValue("\(navigation.occupied)/\(navigation.capacity)")
            towerArrow(systemName: "chevron.up", direction: 1, enabled: navigation.canNavigateUp, identifier: "tower.arrow.up")
            mapButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color("PaletteCream")).overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 2)))
        .sheet(isPresented: $showFloorMap) { FloorMapView() }
    }

    /// Va en la cápsula de la torre y no en la fila de íconos de arriba: es el
    /// atajo de las flechas que tiene al lado, y arriba ya no entra otro botón
    /// de 52 pt sin comerse el contador de monedas en las pantallas angostas.
    private var mapButton: some View {
        Button {
            showFloorMap = true
        } label: {
            Image(systemName: "building.2.fill")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color("PaletteOrange"))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.map")
        .accessibilityLabel(Text("map.hud.label"))
    }

    private func towerArrow(systemName: String, direction: Int, enabled: Bool, identifier: String) -> some View {
        Button {
            _ = gameState.moveVisibleFloor(by: direction)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(enabled ? Color("PaletteBlue") : Color("PaletteInk").opacity(0.28))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(direction > 0 ? "tower.navigate.up" : "tower.navigate.down"))
    }

    private func floorNameKey(for floorID: String) -> LocalizedStringKey {
        TowerNaming.floorNameKey(for: floorID)
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
