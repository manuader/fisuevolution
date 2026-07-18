import SwiftUI

@main
struct FisuEvolutionApp: App {
    @State private var gameState = GameState()
    @State private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(gameState)
                .environment(storeManager)
                .task {
                    await gameState.bootstrap()
                    await storeManager.start(gameState: gameState)
                }
        }
    }
}
