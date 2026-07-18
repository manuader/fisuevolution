import SpriteKit
import SwiftUI

struct RootView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        switch gameState.phase {
        case .loading:
            ProgressView("loading.title")
        case .failed(let message):
            ContentUnavailableView(
                String(localized: "error.content.title"),
                systemImage: "exclamationmark.triangle.fill",
                description: Text(verbatim: message)
            )
        case .ready:
            GameBoardView()
        }
    }
}

/// Hosts the SpriteKit board with the SwiftUI HUD overlaid. The scene is created
/// exactly once and kept in `@State` — recreating it per body evaluation would
/// reset the board (classic SwiftUI↔SpriteKit bridge bug).
struct GameBoardView: View {
    @Environment(GameState.self) private var gameState
    @State private var scene: BoardScene?

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            }
            VStack {
                HUDView()
                Spacer()
                SpawnButtonView()
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            if scene == nil {
                scene = BoardScene(gameState: gameState)
            }
        }
    }
}
