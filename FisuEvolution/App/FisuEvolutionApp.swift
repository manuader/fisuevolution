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
                    audio.startMusic()
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
