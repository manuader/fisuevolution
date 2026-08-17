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
        // Sin barra de estado: el juego es a pantalla completa y el panel ink del
        // HUD llega hasta el borde físico, así que el reloj caía ENCIMA del panel.
        // Y como forzamos light, el sistema lo dibuja en negro sobre el ink
        // (contraste 1,50:1, ilegible) — el estilo del reloj sale del color scheme
        // del controller raíz y no hay forma de aclararlo desde SwiftUI.
        //
        // ⚠️ Va acá y NO en `project.yml`: `INFOPLIST_KEY_UIStatusBarHidden` está
        // puesto desde siempre y nunca funcionó, porque manda el view controller
        // salvo que `UIViewControllerBasedStatusBarAppearance` sea NO — y esa clave
        // Xcode no la traduce desde `INFOPLIST_KEY_*` (no está en su whitelist, así
        // que se pierde sin avisar). Este modificador ES el mecanismo que el
        // default espera.
        .statusBarHidden(true)
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

            // Mismo patrón —y misma razón— que el toast de logros de acá abajo:
            // una `.transition` sólo corre si la INSERCIÓN ocurre dentro de una
            // transacción animada, y esa transacción la abre el PADRE. Sin el
            // `ZStack` + `.animation(value:)`, la transition estaba declarada
            // pero muerta y el aviso de piso aparecía de golpe. Es el defecto que
            // la T18 le arregló al toast y que quedó confirmado y diferido acá.
            ZStack {
                if let notice = gameState.towerNotice {
                    TowerNoticeView(notice: notice) {
                        gameState.dismissTowerNotice(id: notice.id)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.32), value: gameState.towerNotice?.id)

            // ⚠️ La animación de entrada va ACÁ y no adentro del banner: una
            // `.transition` sólo corre si la INSERCIÓN ocurre dentro de una
            // transacción animada, y esa transacción la abre el padre. Con el
            // `.animation(value:)` puesto sobre el propio banner —como estaba
            // hasta la T18— el toast aparecía de golpe: el modificador animaba
            // los cambios de adentro, no su propio nacimiento.
            //
            // El contenedor es un `ZStack` REAL y no un `Group` por HIGIENE, no
            // porque el `Group` fallara: se midió cuadro a cuadro con las dos
            // versiones y el banner recorre los MISMOS 229 pt en los mismos
            // ~0,35 s (fix ronda 1 de la T18). La razón es que `Group` reparte
            // sus modificadores a cada hijo, y acá el único "hijo" es el
            // `if let` entero —el envoltorio opcional, que existe igual cuando
            // el toast es `nil`—, así que la `.animation` cae afuera de la
            // rama y abre la transacción lo mismo. Es una propiedad de tener UN
            // solo hijo opcional: agregarle un segundo hermano al `Group`
            // pondría una `.animation` por hermano. El `ZStack` no depende de
            // eso, está montado siempre, y es la forma que ya usan el `VStack`
            // del `EventBannerView` (arriba, misma pantalla) y el de
            // `ActiveBonusBar`.
            //
            // No cambia el layout: el hijo se ancla solo (su raíz es un `VStack`
            // con `Spacer()`, o sea que ocupa todo el alto igual que antes).
            // Y acota el alcance al toast, para no teñir de spring los cambios
            // del HUD que caigan en el mismo frame.
            ZStack {
                if let toast = gameState.achievementToast {
                    AchievementToastView(toast: toast) {
                        gameState.dismissAchievementToast(id: toast.id)
                    }
                }
            }
            .animation(.spring(duration: 0.32), value: gameState.achievementToast?.id)
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
    ///
    /// ⚠️ Sin paddings propios: la barra se funde con los tres bordes (su panel
    /// se estira solo bajo el home indicator, ver `GameTabBar.bottomPanel`) y
    /// cualquier margen acá le dejaría una lonja de tablero al costado, que es
    /// justo la isla que dejó de ser. El aire lo pide el botón de prestigio, que
    /// SÍ flota, así que el margen lateral se mudó a él.
    private var bottomBar: some View {
        VStack(spacing: Tokens.s8) {
            prestigeButton
                .padding(.horizontal, Tokens.s8)
            BottomMenuBar(select: open)
        }
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
    /// Dispara el pulso de la copa. Sube UNA vez por logro —desde el mismo
    /// `.task(id:)` que ya cuenta los 2,4 s— y no es un `repeatForever`: el
    /// trofeo late al llegar y se queda quieto. El banner es el mismo objeto para
    /// dos logros seguidos (la cola reusa la vista), así que el disparo tiene que
    /// colgar del `id` y no de un `onAppear`, que la segunda vez no corre.
    @State private var pulse = 0

    /// El catálogo nombra el metal (`trophy_bronze`); la vista lo mapea al
    /// icono. Un metal que no exista cae a bronce en vez de dejar el hueco.
    private var tier: VectorTrophyIcon.Tier {
        VectorTrophyIcon.Tier(rawValue: toast.icon.replacingOccurrences(of: "trophy_", with: "")) ?? .bronze
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: Tokens.s8) {
                // Misma costura que la fila de Logros: el `rawValue` del metal es
                // el sufijo de la clave del atlas (`ui_trophy_bronze/silver/gold`,
                // prompts 224–226 de la cola). Sin PNG cae al vector, así que el
                // pulso de abajo sigue midiendo lo mismo.
                GameIcon(artKey: "ui_trophy_\(tier.rawValue)", size: 34) {
                    VectorTrophyIcon(tier: tier)
                }
                    .keyframeAnimator(initialValue: 1.0, trigger: pulse) { view, scale in
                        view.scaleEffect(scale)
                    } keyframes: { _ in
                        KeyframeTrack {
                            SpringKeyframe(1.3, duration: 0.2, spring: .bouncy)
                            SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                        }
                    }
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
                if !reduceMotion { pulse += 1 }
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { return }
                dismiss()
            }
            // Un piso más arriba que el aviso de la torre (ver `TowerNoticeView`),
            // para que los dos se apilen cuando salen juntos. Sube los mismos
            // 2 pt que creció la barra.
            .padding(.bottom, 198)
        }
        .padding(.horizontal, 20)
        // Con Reduce Motion el banner se funde en vez de deslizarse: la guía de
        // Apple pide reemplazar el movimiento por un fundido, no borrar el aviso.
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
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
                // Flota justo encima de la franja de abajo: 82 pt de barra
                // (medidos desde la safe area) + los ~38 del botón de prestigio
                // que puede estar apoyado sobre ella + 14 de aire. La barra
                // creció 2 pt al ganar el label debajo del icono, así que el
                // aviso sube los mismos 2 y conserva el aire de siempre.
                //
                // ⚠️ En un teléfono sin home indicator la barra mide 94 (el piso
                // de `GameTabBar.minimumBottomGap`), así que ahí el aviso apoya a
                // 2 pt del botón de prestigio en vez de a 14. No se pisan, pero
                // es el número que hay que volver a mirar cuando la T4 meta su
                // botón nuevo encima de la barra.
                .padding(.bottom, 134)
        }
        .padding(.horizontal, 20)
        .allowsHitTesting(true)
    }
}
