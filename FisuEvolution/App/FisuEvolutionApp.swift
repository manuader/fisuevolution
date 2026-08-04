import SwiftUI

@main
struct FisuEvolutionApp: App {
    @State private var gameState = GameState()
    @State private var storeManager = StoreManager()
    @State private var gameCenter = GameCenterManager()
    @State private var haptics = HapticsManager()
    @State private var audio = AudioManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(gameState)
                .environment(storeManager)
                .environment(gameCenter)
                .environment(haptics)
                .environment(audio)
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
