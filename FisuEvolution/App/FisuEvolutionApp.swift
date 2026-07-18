import SwiftUI

@main
struct FisuEvolutionApp: App {
    @State private var gameState = GameState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(gameState)
                .task {
                    await gameState.bootstrap()
                }
        }
    }
}
