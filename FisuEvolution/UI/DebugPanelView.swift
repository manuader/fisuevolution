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
                // La misma carta que reabre el long-press sobre el personaje
                // del tablero, sin pelear el gesto: es la puerta de los tests
                // (precedente `--uitest-open-sheet`: los gestos del tablero no
                // se automatizan por coordenada) y sirve para mirar el
                // beneficio sin puntería.
                if let special = gameState.visibleFloorSpecials.first {
                    Section("Specials") {
                        Button("Carta del special activo") {
                            gameState.presentSpecialInfo(id: special.id)
                            dismiss()
                        }
                        .accessibilityIdentifier("debug.special.info")
                    }
                }
                // Un cofre abierto de una, con su animación. La vía real —cada
                // dos pisos, un video, el día 7— es media hora de partida por
                // cofre, así que sin esto la animación no se puede mirar dos
                // veces seguidas para juzgarla.
                Section("Cofres") {
                    Button("Abrir un cofre") {
                        gameState.debugOpenChest()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.chest.open")
                    // El de arriba aterriza directo en la animación; éste deja
                    // el cofre GUARDADO, que es lo que hace falta para recorrer
                    // el camino del jugador entero: el puntito de la pestaña, la
                    // tarjeta de Regalos y el botón que la abre.
                    Button("Regalar un cofre (sin abrir)") {
                        gameState.debugAwardChest()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.chest.award")
                }
                // La ficha con un segundo Fisura en la torre: el fixture
                // `--uitest-open-sheet` la abre sobre el único de una partida
                // nueva, que no se puede despedir.
                Section("Ficha") {
                    Button("Abrir la ficha (con otro para despedir)") {
                        gameState.debugGrantCoins()
                        if let base = gameState.content?.tiers.baseType.id {
                            gameState.hireCharacter(typeId: base)
                        }
                        if let slot = gameState.visiblePlacements.first?.slot {
                            gameState.presentCharacterSheet(cellIndex: slot)
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.sheet.open")
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
