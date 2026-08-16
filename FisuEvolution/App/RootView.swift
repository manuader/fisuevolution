import SpriteKit
import SwiftUI

struct RootView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch gameState.phase {
            case .loading:
                SplashView()
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
        // La UI está pensada para el mundo cálido/crema del juego; forzamos light
        // para que dark mode no rompa los grises/blancos de los menús.
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, newPhase in
            gameState.handleScenePhase(newPhase)
        }
    }
}

/// Pantalla de carga de marca: fondo crema + logo/mascota + tip, en vez del
/// spinner blanco del sistema (que era la primera impresión de la app).
struct SplashView: View {
    private let tips = [
        "Consejo: arrastrá dos iguales y evolucionan.",
        "Tocá al Fisura para juntar plata.",
        "En Mejoras potenciás tus ganancias.",
    ]
    var body: some View {
        ZStack {
            Color("PaletteCream").ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                // Logo del atlas si ya está disponible; si no, wordmark tipográfico.
                if let logo = UIArt.image("logo") {
                    logo.resizable().scaledToFit().frame(maxWidth: 240, maxHeight: 200)
                } else {
                    VStack(spacing: 2) {
                        Text(verbatim: "FISU")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                        Text(verbatim: "EVOLUTION")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .tracking(6)
                    }
                    .foregroundStyle(Color("PaletteInk"))
                }
                if let fisura = UIArt.image("fisura_celebrate") ?? UIArt.image("fisura_point") {
                    fisura.resizable().scaledToFit().frame(maxWidth: 200, maxHeight: 240)
                }
                Spacer()
                ProgressView()
                    .tint(Color("PaletteOrange"))
                Text(verbatim: tips.randomElement() ?? tips[0])
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 30)
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
    /// La pantalla de la barra inferior que está abierta, o `nil`. Las seis
    /// comparten UN `.sheet(item:)` en vez de tener un `@State showX` cada una:
    /// con un booleano por hoja, dos tabs seguidos podían dejar dos banderas en
    /// `true` y SwiftUI presentar una sola. El enum lo hace imposible.
    @State private var activeScreen: GameScreen?
    @State private var adsProvider = StubAdsProvider()
    // Los popups automáticos no deben pisar el tutorial en el primer arranque.
    @AppStorage("fisuTutorialDone") private var tutorialDone = false
    /// Los pasos del tutorial que se completan abriendo una hoja: la economía no
    /// cambia, así que no hay proyección de `GameState` que los delate.
    @State private var tutorialEvents: TutorialEvents = []
    #if DEBUG
    @State private var showDebugPanel = false
    #endif

    var body: some View {
        @Bindable var gameState = gameState

        ZStack {
            if let scene {
                // `ignoresSiblingOrder` deja que SpriteKit reordene por textura y
                // fusione draw calls. Es seguro porque el orden de dibujo ya está
                // dado por zPosition explícito en todos lados (depthZ para
                // personajes, los pisos por ordinal, y los overlays con z fijo);
                // sin esto tiene que respetar el orden del árbol y dibuja nodo
                // por nodo.
                #if DEBUG
                SpriteView(
                    scene: scene,
                    options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes],
                    debugOptions: [.showsFPS, .showsNodeCount, .showsDrawCount]
                )
                .ignoresSafeArea()
                #else
                SpriteView(scene: scene, options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
                    .ignoresSafeArea()
                #endif
            }
            VStack(spacing: 8) {
                HUDView(
                    onStoreTap: { open(.store) },
                    onMapOpen: { tutorialEvents.insert(.openedMap) }
                )
                // Los contadores de bonus van pegados al HUD y a la izquierda;
                // el banner del evento, que es ancho y centrado, va debajo. Se
                // monta sólo cuando hay algo que contar: así el timer de 1 Hz
                // de la barra no existe durante una partida sin boosts.
                if !gameState.activeBonuses.isEmpty {
                    ActiveBonusBar(bonuses: gameState.activeBonuses)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                }
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

            if let notice = gameState.towerNotice {
                TowerNoticeView(notice: notice) {
                    gameState.dismissTowerNotice(id: notice.id)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let toast = gameState.achievementToast {
                AchievementToastView(toast: toast) {
                    gameState.dismissAchievementToast(id: toast.id)
                }
            }
        }
        // El overlay se monta acá y no dentro del `ZStack` porque necesita los
        // anchors que publican los controles de adentro: `overlayPreferenceValue`
        // los entrega ya recolectados, y el `GeometryReader` a pantalla completa
        // los resuelve a puntos sin que nadie tenga que restar safe areas a mano.
        .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                TutorialOverlay(
                    anchors: anchors.mapValues { proxy[$0] },
                    events: tutorialEvents
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if scene == nil {
                scene = BoardScene(gameState: gameState)
            }
        }
        .sheet(item: Binding(
            get: { tutorialDone ? gameState.careerPrompt : nil },
            set: { gameState.careerPrompt = $0 }
        )) { prompt in
            CareerChoiceView(prompt: prompt)
        }
        .sheet(item: Binding(
            get: { tutorialDone ? gameState.characterSheet : nil },
            set: { gameState.characterSheet = $0 }
        )) { sheet in
            CharacterSheetView(sheet: sheet)
        }
        .sheet(item: Binding(
            get: { tutorialDone ? gameState.skinAward : nil },
            set: { gameState.skinAward = $0 }
        ), onDismiss: { gameState.skinAwardDismissed() }) { award in
            SkinAwardView(award: award)
        }
        .sheet(item: Binding(
            get: { tutorialDone ? gameState.offlineReward : nil },
            set: { gameState.offlineReward = $0 }
        )) { reward in
            OfflineEarningsView(reward: reward)
        }
        .sheet(isPresented: $showPrestige) {
            PrestigeView()
        }
        // Las seis pantallas de la barra inferior, en UN solo sheet. Ya no queda
        // ningún placeholder: el Menú es la última que se construyó (T15) y es
        // la única que navega hacia adentro.
        .sheet(item: $activeScreen) { screen in
            switch screen {
            case .jobs: FisuJobsView()
            case .upgrades: UpgradesView()
            case .skins: CustomizationView()
            case .gifts: GiftsView(adsProvider: adsProvider)
            case .store: StoreView()
            case .menu: MenuView()
            }
        }
        .sheet(item: Binding(
            get: { tutorialDone ? gameState.specialDrop : nil },
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
            get: { tutorialDone ? gameState.dailyClaim.map { IdentifiedClaim(claim: $0) } : nil },
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

    /// Abre una pantalla de la barra y avisa al tutorial cuando el paso se
    /// completa **por abrir la hoja** (la economía no cambia, así que no hay
    /// proyección de `GameState` que lo delate).
    private func open(_ screen: GameScreen) {
        if screen == .upgrades { tutorialEvents.insert(.openedUpgrades) }
        activeScreen = screen
    }

    /// La franja de abajo: el botón flotante de reencarnar y la barra de las 6
    /// pantallas. Conserva `.tutorialAnchor(.bottomBar)`, que no ilumina nada
    /// —es la franja que el globo del tutorial tiene que esquivar—.
    private var bottomBar: some View {
        VStack(spacing: Tokens.s8) {
            prestigeButton
            BottomMenuBar(select: open)
        }
        .padding(.horizontal, Tokens.s8)
        .padding(.bottom, Tokens.s8)
        .tutorialAnchor(.bottomBar)
    }

    /// Reencarnar salió de la barra: es una acción rara y definitiva, y un
    /// séptimo tab la pondría al lado de la tienda. Queda flotando sobre el
    /// tablero contra el borde derecho, y sólo cuando hay algo que cobrar.
    @ViewBuilder private var prestigeButton: some View {
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
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
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
        .padding(.top, 68) // debajo del HUD para no tapar el engranaje de Config
    }
    #endif
}

// `ScreenPlaceholderView` se retiró en la T15 y el último placeholder de todos
// —Ajustes— murió en la T16: las seis pantallas de la barra y las cuatro del
// menú existen de verdad.

/// El banner de un logro recién conseguido: mismo mecanismo que
/// `TowerNoticeView` —aparece, se puede tocar para cerrar y se va solo— pero con
/// la copa y el título del logro adentro.
///
/// Va **más arriba** que el aviso de la torre a propósito: una contratación que
/// llena el piso y cierra el logro de contrataciones publica los dos a la vez, y
/// apilados se leen; superpuestos, ninguno.
private struct AchievementToastView: View {
    let toast: AchievementToast
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// El catálogo nombra el metal (`trophy_bronze`); la vista lo mapea al
    /// icono. Un metal que no exista cae a bronce en vez de dejar el hueco.
    private var tier: VectorTrophyIcon.Tier {
        VectorTrophyIcon.Tier(rawValue: toast.icon.replacingOccurrences(of: "trophy_", with: "")) ?? .bronze
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: Tokens.s8) {
                VectorTrophyIcon(tier: tier)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ach.toast.unlocked")
                        .font(.system(.caption2, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color("PaletteInk").opacity(0.65))
                    Text(verbatim: toast.titleText)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
            )
            .onTapGesture(perform: dismiss)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ach.toast")
            .accessibilityAddTraits(.isButton)
            .task(id: toast.id) {
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { return }
                dismiss()
            }
            .padding(.bottom, 196)
        }
        .padding(.horizontal, 20)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .animation(reduceMotion ? nil : .spring(duration: 0.32), value: toast.id)
    }
}

private struct TowerNoticeView: View {
    let notice: GameState.TowerNotice
    let dismiss: () -> Void

    private var messageKey: LocalizedStringKey {
        switch notice.kind {
        case .floorFull: "tower.notice.floor_full"
        case .destinationFloorFull: "tower.notice.destination_full"
        case .hireUnlocked: "tower.notice.hire_unlocked"
        }
    }

    var body: some View {
        VStack {
            Spacer()
            Text(messageKey)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk"))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color("PaletteCream")).overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3)))
                .onTapGesture(perform: dismiss)
                .accessibilityIdentifier("tower.notice")
                .accessibilityAddTraits(.isButton)
                .task(id: notice.id) {
                    try? await Task.sleep(for: .seconds(2.4))
                    guard !Task.isCancelled else { return }
                    dismiss()
                }
                .padding(.bottom, 132)
        }
        .padding(.horizontal, 20)
        .allowsHitTesting(true)
    }
}
