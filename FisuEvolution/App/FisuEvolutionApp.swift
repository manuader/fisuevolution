import SwiftUI

@main
struct FisuEvolutionApp: App {
    @State private var gameState = GameState()
    @State private var storeManager = StoreManager()
    @State private var gameCenter = GameCenterManager()
    @State private var haptics = HapticsManager()
    @State private var audio = AudioManager()
    /// El recordatorio diario de Ajustes (T16). No pide permiso al arrancar —lo
    /// pide el toggle— así que construirlo acá no le muestra un diálogo a nadie.
    @State private var notifications = NotificationsManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(gameState)
                .environment(storeManager)
                .environment(gameCenter)
                .environment(haptics)
                .environment(audio)
                .environment(notifications)
                .task {
                    haptics.prepare()
                    audio.prepare()
                    // El audio se carga en paralelo con el bootstrap en vez de
                    // demorarlo: la lectura de los `.caf` corre fuera de main y
                    // deja los diez SFX listos antes de que el jugador pueda
                    // dispararlos.
                    Task {
                        await audio.startMusic()
                        await audio.preloadSFX()
                    }
                    gameState.attachHaptics(haptics)
                    gameState.attachAudio(audio)
                    await gameState.bootstrap()
                    await storeManager.start(gameState: gameState)
                    if let content = gameState.content {
                        gameState.attachGameCenter(gameCenter)
                        gameCenter.start(content: content)
                    }
                }
        }
    }
}
