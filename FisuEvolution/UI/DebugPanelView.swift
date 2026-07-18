#if DEBUG
import SwiftUI

/// Herramientas de balance y QA. Solo existe en builds Debug — jamás shippea,
/// por eso sus strings no pasan por el String Catalog.
struct DebugPanelView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    @State private var timeWarpOn = false

    var body: some View {
        NavigationStack {
            List {
                Section("Economía") {
                    Button("+ Monedas (1M o costo de spawn ×100)") {
                        gameState.debugGrantCoins()
                    }
                    Button("Invocar par del tier máximo") {
                        gameState.debugGrantPair()
                    }
                    Toggle("Time-warp ×60", isOn: $timeWarpOn)
                        .onChange(of: timeWarpOn) { _, on in
                            gameState.debugTimeScale = on ? 60 : 1
                        }
                }
                Section("Offline") {
                    Button("Simular 4 h offline") {
                        gameState.debugSimulateOffline(hours: 4)
                    }
                }
                Section("Peligro") {
                    Button("Resetear partida", role: .destructive) {
                        gameState.debugResetSave()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            timeWarpOn = gameState.debugTimeScale > 1
        }
    }
}
#endif
