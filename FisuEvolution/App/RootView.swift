import SpriteKit
import SwiftUI

struct RootView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
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
        .onChange(of: scenePhase) { _, newPhase in
            gameState.handleScenePhase(newPhase)
        }
    }
}

/// Hosts the SpriteKit board with the SwiftUI HUD overlaid. The scene is created
/// exactly once and kept in `@State` — recreating it per body evaluation would
/// reset the board (classic SwiftUI↔SpriteKit bridge bug).
struct GameBoardView: View {
    @Environment(GameState.self) private var gameState
    @State private var scene: BoardScene?
    @State private var showPrestige = false
    @State private var showStore = false
    @State private var showBonus = false
    @State private var showUpgrades = false
    @State private var adsProvider = StubAdsProvider()
    #if DEBUG
    @State private var showDebugPanel = false
    #endif

    var body: some View {
        @Bindable var gameState = gameState

        ZStack {
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            }
            VStack(spacing: 8) {
                HUDView(
                    onStoreTap: { showStore = true },
                    onBonusTap: { showBonus = true },
                    onUpgradesTap: { showUpgrades = true }
                )
                if let event = gameState.activeEvent {
                    EventBannerView(event: event)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                bottomBar
            }
            .animation(.spring(duration: 0.35), value: gameState.activeEvent)
            #if DEBUG
            debugButton
            #endif
        }
        .onAppear {
            if scene == nil {
                scene = BoardScene(gameState: gameState)
            }
        }
        .sheet(item: $gameState.careerPrompt) { prompt in
            CareerChoiceView(prompt: prompt)
        }
        .sheet(item: $gameState.passivePrompt) { prompt in
            PassiveUnlockView(prompt: prompt)
        }
        .sheet(item: $gameState.offlineReward) { reward in
            OfflineEarningsView(reward: reward)
        }
        .sheet(isPresented: $showPrestige) {
            PrestigeView()
        }
        .sheet(isPresented: $showStore) {
            StoreView()
        }
        .sheet(isPresented: $showBonus) {
            BonusView(adsProvider: adsProvider)
        }
        .sheet(isPresented: $showUpgrades) {
            UpgradesView()
        }
        .sheet(item: Binding(
            get: { gameState.specialDrop },
            set: { if $0 == nil { gameState.dismissSpecialDrop() } }
        )) { special in
            SpecialDropView(special: special)
        }
        .sheet(item: Binding(
            get: { gameState.shareCardSubject },
            set: { if $0 == nil { gameState.dismissShareCard() } }
        )) { subject in
            ShareCardSheet(subject: subject)
        }
        .sheet(item: Binding(
            get: { gameState.dailyClaim.map { IdentifiedClaim(claim: $0) } },
            set: { if $0 == nil { gameState.dismissDailyClaim() } }
        )) { wrapped in
            DailyRewardView(claim: wrapped.claim)
        }
        #if DEBUG
        .sheet(isPresented: $showDebugPanel) {
            DebugPanelView()
        }
        #endif
        // Invisible para la UI, medible para los UI tests.
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("board.units")
                .accessibilityValue(Text(verbatim: String(gameState.unitCount)))
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if gameState.prestigeAvailable {
                Button {
                    showPrestige = true
                } label: {
                    Label {
                        Text("prestige.button")
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PalettePink"))
                .accessibilityIdentifier("hud.prestige")
            }
            SpawnButtonView()
        }
        .padding(.bottom, 20)
    }

        /// DailyRewardManager.Claim no es Identifiable; wrapper para .sheet(item:).
    private struct IdentifiedClaim: Identifiable {
        let id = UUID()
        let claim: DailyRewardManager.Claim
    }

    #if DEBUG
    private var debugButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    showDebugPanel = true
                } label: {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.body)
                        .padding(10)
                }
                .tint(Color("PaletteInk"))
                .accessibilityIdentifier("hud.debug")
            }
            Spacer()
        }
        .padding(.trailing, 8)
    }
    #endif
}
