import EconomyKit
import SwiftUI

/// Spawn purchase button: shows the progressive-spawn offer (type + current cost)
/// and disables itself while coins are short. F2 adds the merge loop on top.
struct SpawnButtonView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    private var shouldPulse: Bool {
        gameState.showSpawnHint && !reduceMotion
    }

    var body: some View {
        if let quote = gameState.spawnQuote {
            ArtButton(art: "ui_btn_buy", tint: Color("PaletteGreen")) {
                gameState.buySpawn()
            } label: {
                VStack(spacing: 2) {
                    buttonTitle(for: quote)
                    buttonDetail(for: quote)
                }
            }
            // Sin saldo: NO usamos `.disabled` (el dimming del sistema bajaba el
            // texto a ~0.3 y lo volvía ilegible). El botón queda tappable —
            // `buySpawn()` falla solo si no alcanza — y comunicamos el estado con
            // texto blanco (afford) o ink (sin saldo) + una leve desaturación.
            .foregroundStyle(gameState.canAffordSpawn ? .white : Color("PaletteInk"))
            .shadow(color: .black.opacity(gameState.canAffordSpawn ? 0.55 : 0), radius: 2, y: 1)
            .shadow(color: .black.opacity(gameState.canAffordSpawn ? 0.35 : 0), radius: 0.5, y: 0)
            .saturation(gameState.canAffordSpawn ? 1 : 0.7)
            .opacity(gameState.canAffordSpawn ? 1 : 0.92)
            .frame(maxWidth: 300)
            .fixedSize(horizontal: false, vertical: true)
            // El pulso vive SÓLO mientras el hint está activo. Antes `pulsing` se
            // encendía en `onAppear` y no se apagaba nunca, así que un
            // `repeatForever` mantenía el display link de SwiftUI corriendo toda
            // la sesión —en paralelo al de SpriteKit— aunque el hint estuviera
            // oculto y el `scaleEffect` lo neutralizara visualmente.
            .scaleEffect(pulsing ? 1.06 : 1.0)
            .animation(pulsing ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true) : .default,
                       value: pulsing)
            .onChange(of: shouldPulse, initial: true) { _, active in
                pulsing = active
            }
            .accessibilityIdentifier("hud.spawn")
            .accessibilityHint(Text("spawn.button.hint"))
        }
    }

    @ViewBuilder
    private func buttonTitle(for quote: HireQuote) -> some View {
        Group {
            switch gameState.hireOffer {
            case .full: Text("spawn.button.full")
            case .floorLocked: Text("spawn.button.locked")
            case .unavailable: Text("spawn.button.hire_locked")
            case .here, .floorBelow: Text("spawn.button.title \(quote.type.displayName)")
            }
        }
        .font(.system(.headline, design: .rounded).weight(.bold))
    }

    /// El detalle nombra el piso cuando la compra NO cae en el que estás
    /// mirando: si no, la unidad aparecería en otro piso y el tap se sentiría
    /// como que no pasó nada.
    @ViewBuilder
    private func buttonDetail(for quote: HireQuote) -> some View {
        Group {
            switch gameState.hireOffer {
            case .here:
                price(for: quote)
            case .floorBelow(let floorID):
                HStack(spacing: 4) {
                    price(for: quote)
                    floorTag(floorID)
                }
            case .full(let belowFloorID):
                if let belowFloorID {
                    HStack(spacing: 4) {
                        Text("spawn.button.full.detail")
                        floorTag(belowFloorID)
                    }
                } else {
                    Text("spawn.button.full.detail")
                }
            case .floorLocked:
                Text("spawn.button.locked.detail")
            case .unavailable:
                Text("spawn.button.hire_locked.detail")
            }
        }
        .font(.subheadline.weight(.semibold))
    }

    private func price(for quote: HireQuote) -> some View {
        HStack(spacing: 4) {
            CoinIcon(size: 18)
            Text(verbatim: CoinFormatter.string(from: quote.cost))
                .monospacedDigit()
        }
    }

    /// Nombre del piso de destino. La clave es estática (`TowerNaming`) porque
    /// `LocalizedStringKey` no resuelve claves armadas por interpolación.
    private func floorTag(_ floorID: String) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: "·")
            Text(TowerNaming.floorNameKey(for: floorID))
        }
        .opacity(0.85)
    }
}
