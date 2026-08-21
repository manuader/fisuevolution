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
        // Sin barra de estado: el juego es a pantalla completa y el panel del HUD
        // llega hasta el borde físico, así que el reloj cae ENCIMA del panel —a
        // un par de puntos del contador de plata, que es lo que ese renglón tiene
        // que decir—. Cuando el panel era ink había además un problema de
        // contraste (negro sobre ink, 1,50:1, ilegible, y el estilo del reloj sale
        // del color scheme del controller raíz: desde SwiftUI no hay forma de
        // aclararlo). Con el panel crema el reloj se lee, pero sigue estorbando:
        // la razón de ocultarlo pasó a ser de composición, no de contraste.
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
            hudColumn
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
                if let notice = gameState.towerNotice, gameState.showing == .towerNotice {
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
                if let toast = gameState.achievementToast, gameState.showing == .achievements {
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
        .sheet(item: careerPromptBinding) { prompt in
            CareerChoiceView(prompt: prompt)
        }
        .sheet(item: Binding(
            get: { tutorialDone ? gameState.characterSheet : nil },
            set: { gameState.characterSheet = $0 }
        )) { sheet in
            CharacterSheetView(sheet: sheet)
        }
        .sheet(item: skinAwardBinding, onDismiss: { gameState.celebrationFinished(.skinAward) }) { award in
            SkinAwardView(award: award)
        }
        .sheet(item: offlineRewardBinding, onDismiss: { gameState.celebrationFinished(.offlineEarnings) }) { reward in
            OfflineEarningsView(reward: reward)
        }
        .sheet(isPresented: $showPrestige) {
            PrestigeView()
        }
        // Las seis pantallas de la barra inferior, en UN solo sheet. Ya no queda
        // ningún placeholder: el Menú es la última que se construyó (T15) y es
        // la única que navega hacia adentro.
        .sheet(item: $activeScreen) { screen in
            Group {
                switch screen {
                case .jobs: FisuJobsView()
                case .upgrades: UpgradesView()
                case .skins: CustomizationView()
                case .gifts: GiftsView(adsProvider: adsProvider)
                case .store: StoreView()
                case .menu: MenuView()
                }
            }
            // El panel del `panelSheet` ES la hoja: sin el material del sistema
            // debajo, flota sobre el juego atenuado con su banda inferior a la
            // vista — como los popups, que es como componen las referencias.
            .presentationBackground(.clear)
        }
        .sheet(item: specialDropBinding) { special in
            SpecialDropView(special: special)
        }
        .sheet(item: Binding(
            get: { gameState.shareCardSubject },
            set: { if $0 == nil { gameState.dismissShareCard() } }
        )) { subject in
            ShareCardSheet(subject: subject)
        }
        .sheet(item: dailyClaimBinding) { wrapped in
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
        // El piso visible, como ID crudo (no nombre traducido: a prueba de la
        // trampa 6). Desde que la píldora del HUD se retiró (2026-08-18) es el
        // único observable del piso que sobrevive a las celebraciones que
        // apagan la UI — `exists` y `value` se leen igual con la opacidad en 0.
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("board.floor")
                .accessibilityValue(Text(verbatim: gameState.towerNavigation.floorID))
        )
    }

    // MARK: Bindings de las celebraciones
    //
    // Cada una es una propiedad con TIPO EXPLÍCITO y no un `Binding(...)` inline
    // en el `body`. Con el gate de la cola adentro del `get`, las diez hojas
    // encadenadas hacían caer al type-checker de SwiftUI ("unable to type-check
    // this expression in reasonable time"). Declaradas por separado, cada una se
    // resuelve sola y el `body` sólo las referencia.
    //
    // El patrón es siempre el mismo: se muestra **si es su turno en la cola**.
    // El payload sigue viviendo donde siempre. El gate por `tutorialDone` que
    // tenían estas cinco se retiró: la cola es el único árbitro —con la fase
    // obligatoria viva ninguno de estos kinds toma el turno
    // (`beginTutorialPhase`)—, y el doble gate era justamente lo que congelaba
    // la cola cuando un kind de sheet tomaba `current` con el tutorial arriba.

    private var careerPromptBinding: Binding<GameState.CareerPrompt?> {
        Binding(
            get: { gameState.showing == .careerChoice ? gameState.careerPrompt : nil },
            set: { gameState.careerPrompt = $0 }
        )
    }

    private var skinAwardBinding: Binding<GameState.SkinAward?> {
        Binding(
            get: { gameState.showing == .skinAward ? gameState.skinAward : nil },
            set: { gameState.skinAward = $0 }
        )
    }

    private var offlineRewardBinding: Binding<GameState.OfflineReward?> {
        Binding(
            get: { gameState.showing == .offlineEarnings ? gameState.offlineReward : nil },
            set: { gameState.offlineReward = $0 }
        )
    }

    private var specialDropBinding: Binding<SpecialsConfig.Special?> {
        Binding(
            get: { gameState.showing == .specialDrop ? gameState.specialDrop : nil },
            set: { if $0 == nil { gameState.dismissSpecialDrop() } }
        )
    }

    private var dailyClaimBinding: Binding<IdentifiedClaim?> {
        Binding(
            get: {
                guard gameState.showing == .dailyReward, let claim = gameState.dailyClaim else { return nil }
                return IdentifiedClaim(claim: claim)
            },
            set: { if $0 == nil { gameState.dismissDailyClaim() } }
        )
    }

    /// El HUD y todo lo que va encima del tablero.
    ///
    /// Vive fuera del `body` porque agregarle la atenuación de celebraciones lo
    /// hizo caer en "the compiler is unable to type-check this expression in
    /// reasonable time": el `ZStack` del `body` ya venía al límite. Extraer una
    /// rama es el remedio estándar y además hace legible el orden de capas.
    @ViewBuilder private var hudColumn: some View {
        VStack(spacing: 8) {
            HUDView(
                onStoreTap: { open(.store) },
                onMapOpen: { tutorialEvents.insert(.openedMap) }
            )
            // Los contadores de bonus van pegados al HUD y a la izquierda; el
            // banner del evento, que es ancho y centrado, va debajo. Se monta
            // sólo cuando hay algo que contar: así el timer de 1 Hz de la barra
            // no existe durante una partida sin boosts.
            if !gameState.activeBonuses.isEmpty {
                ActiveBonusBar(bonuses: gameState.activeBonuses)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
            }
            if let event = gameState.activeEvent, gameState.eventBannerIsVisible {
                EventBannerView(event: event)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
            bottomBar
        }
        .animation(.spring(duration: 0.35), value: gameState.activeEvent)
        // Durante la celebración a pantalla completa la UI se va del todo: el
        // reveal va centrado en la pantalla entera y no tiene que esquivar nada.
        // Con `allowsHitTesting` atado a lo mismo, además, no se puede tocar algo
        // que no se ve. Sólo esa celebración lo hace — un toast de logro de 4 s
        // no justifica apagar la interfaz.
        .opacity(hidesUIForCelebration ? 0 : 1)
        .allowsHitTesting(!hidesUIForCelebration)
        .animation(.easeInOut(duration: 0.25), value: hidesUIForCelebration)
    }

    /// Apagar la UI vuelve a correr TAMBIÉN durante el tutorial: desde que la
    /// fase obligatoria arbitra en la cola (`beginTutorialPhase`), el overlay
    /// entero se esconde mientras el reveal tiene el turno —ver el `body` de
    /// `TutorialOverlay`—, así que ya no queda nada señalando una barra
    /// invisible (el bug que el viejo parche `&& tutorialDone` tapaba) y el
    /// reveal del primer merge se ve limpio y a pantalla completa, que es
    /// exactamente lo que la fase quiere mostrar.
    private var hidesUIForCelebration: Bool {
        gameState.celebrationHidesUI
    }

    /// Abre una pantalla de la barra y avisa al tutorial cuando el paso se
    /// completa **por abrir la hoja** (la economía no cambia, así que no hay
    /// proyección de `GameState` que lo delate).
    private func open(_ screen: GameScreen) {
        if screen == .upgrades { tutorialEvents.insert(.openedUpgrades) }
        activeScreen = screen
    }

    /// La franja de abajo: el botón flotante de reencarnar, el atajo de
    /// contratar al mejor y la barra de las 6 pantallas. Conserva
    /// `.tutorialAnchor(.bottomBar)`, que no ilumina nada —es la franja que el
    /// globo del tutorial tiene que esquivar—.
    ///
    /// ⚠️ Sin paddings propios: la barra se funde con los tres bordes (su panel
    /// se estira solo bajo el home indicator, ver `GameTabBar.bottomPanel`) y
    /// cualquier margen acá le dejaría una lonja de tablero al costado, que es
    /// justo la isla que dejó de ser. El aire lo pide el botón de prestigio, que
    /// SÍ flota, así que el margen lateral se mudó a él.
    ///
    /// ⚠️ El orden de los tres importa y no es casual: `QuickHireButton` va
    /// PEGADO a la barra —debajo del prestigio— porque es un botón que se toca
    /// seguido y el pulgar llega mejor abajo; y porque así el que se dibuja o se
    /// va (el prestigio, que aparece recién cuando hay ORO que cobrar) queda en
    /// la punta de arriba y no le mueve el piso al que sí está siempre. La
    /// contracara está anotada en los dos toasts: **el tope de esta pila cambió
    /// de altura** y sus paddings se re-derivaron para el caso más alto.
    ///
    /// La aparición/desaparición del atajo (`bestHire` pasa a `nil` cuando no
    /// queda nada contratable) va **sin animación**, igual que la del botón de
    /// prestigio que tiene arriba: son los dos hijos opcionales de la misma
    /// pila, y animar uno solo dejaría la franja moviéndose de dos maneras
    /// distintas. Si algún día se anima, se animan los dos juntos y con
    /// `accessibilityReduceMotion` apagándolo.
    private var bottomBar: some View {
        VStack(spacing: Tokens.s8) {
            // Contratar a la izquierda y reencarnar a la derecha, en la MISMA
            // fila y cada uno contra su borde: los dos extremos de la misma
            // decisión —lo que comprás y lo que cobrás— leídos de un vistazo.
            // Antes reencarnar flotaba solo en su propio renglón, lo que lo
            // dejaba sin par visual y le comía una franja al tablero.
            //
            // `alignment: .top` y no `.center`: si con Dynamic Type una cápsula
            // crece más que la otra, se alinean por arriba en vez de descolgarse
            // media altura cada una.
            HStack(alignment: .top, spacing: Tokens.s8) {
                QuickHireButton()
                Spacer(minLength: Tokens.s8)
                PrestigeButton { showPrestige = true }
            }
            .padding(.horizontal, Tokens.s8)
            BottomMenuBar(select: open)
        }
        .tutorialAnchor(.bottomBar)
    }

        /// DailyRewardManager.Claim no es Identifiable; wrapper para .sheet(item:).
    private struct IdentifiedClaim: Identifiable {
        let id = UUID()
        let claim: DailyRewardManager.Claim
    }

    #if DEBUG
    /// La llave del panel de debug, flotando arriba a la derecha.
    ///
    /// ⚠️ Su posición la manda el panel del HUD, que desde el rediseño llega
    /// hasta el borde físico y es MÁS ALTO que la isla que reemplazó: con los 68
    /// pt de antes la llave caía adentro del panel, y ahí se pierde —era ink
    /// sobre ink cuando el panel era oscuro, y hoy que es crema sería una llave
    /// crema sobre crema—. Tiene que caer DEBAJO del borde de abajo del panel en
    /// los dos tamaños de teléfono que soportamos.
    ///
    /// El padding se cuenta desde la safe area, no desde el borde físico, y eso
    /// invierte cuál es el caso apretado: **el SE**. Ahí la safe area superior
    /// es 0 —la barra de estado está oculta— y el panel llega a **90** pt
    /// (14 del piso de `HUDView.minimumTopGap` + 64 del botón + 12 de padding),
    /// así que 104 lo deja con **14 pt** de aire. En un teléfono con notch la
    /// safe area ya pone 62 por su cuenta y el panel termina a **140**
    /// (62 + 2 + 64 + 12), así que los mismos 104 lo dejan a 166: sobrado por
    /// 26, y todavía muy por encima de la barra de abajo.
    ///
    /// Los dos crecieron 4 pt con los iconos más grandes de la enmienda del
    /// dueño (el botón del HUD pasó de 60 a 64), y como el 104 se quedó donde
    /// estaba, el aire del SE se comió esos 4: pasó de 18 a 14. Sigue siendo el
    /// caso apretado y sigue sobrando, pero **el margen es finito**: si el botón
    /// del HUD volviera a crecer, a los 14 pt les quedan tres puntos y medio de
    /// vida antes de que la llave se meta adentro del panel. Medido en captura
    /// sobre el simulador (SE 3: el contorno ink del panel ocupa 87–90 pt;
    /// 16 Pro: 137–140), no estimado.
    ///
    /// El glifo va sobre plato crema con contorno ink, como los chips del HUD:
    /// el tablero es un dibujo a todo color y un icono pelado se pierde contra
    /// cualquier piso.
    private var debugButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    showDebugPanel = true
                } label: {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .padding(8)
                        .background(
                            Circle().fill(Color("PaletteCream"))
                                .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 2))
                        )
                }
                .accessibilityIdentifier("hud.debug")
            }
            Spacer()
        }
        .padding(.trailing, 8)
        .padding(.top, 104)
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
                // Misma costura que la fila de Logros, con la MISMA clave: vive
                // en `Tier.artKey` para que un batch que aterrice no muestre dos
                // trofeos distintos. Sin PNG cae al vector y el pulso de abajo
                // sigue midiendo lo mismo.
                GameIcon(artKey: tier.artKey, size: 34) { VectorTrophyIcon(tier: tier) }
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
                    .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2.5))
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
            // Un piso más arriba que el aviso de la torre (ver `TowerNoticeView`,
            // que es donde está contada la suma entera), para que los dos se
            // apilen cuando salen juntos: los mismos 84 + 8 + 56 + 8 + 45 = 201
            // de aquél —el 56 es el atajo de contratar, que se metió en el medio
            // de la franja—, más los **63** que mide el aviso de la torre con su
            // aire —medidos, no estimados—, = 264.
            //
            // Los dos altos que se mueven entran por SÍMBOLO —`barHeight` y
            // `capsuleHeight`— así que los dos toasts suben juntos y la pila no
            // se descuajeringa. Que el atajo esté acá por símbolo es justamente
            // lo que impide que este renglón y el del aviso se desincronicen.
            //
            // Y arrastra el MISMO piso de abajo: si el aviso sube 12 en un
            // teléfono sin home indicator y éste no, la distancia entre los dos
            // se come esos 12 y dejan de leerse como una pila.
            .padding(.bottom, GameTabBar.barHeight + 8 + QuickHireButton.capsuleHeight
                + 8 + 45 + 63 + GameTabBar.bottomFloor)
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
                .background(Capsule().fill(Color("PaletteCream")).overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2.5)))
                .onTapGesture(perform: dismiss)
                .accessibilityIdentifier("tower.notice")
                .accessibilityAddTraits(.isButton)
                .task(id: notice.id) {
                    try? await Task.sleep(for: .seconds(2.4))
                    guard !Task.isCancelled else { return }
                    dismiss()
                }
                // Flota justo encima de la franja de abajo ENTERA, que no es sólo
                // la barra: `bottomBar` es un `VStack(spacing: Tokens.s8)` con el
                // atajo de contratar y el botón de prestigio apoyados arriba de
                // ella. Contando desde la safe area, y con los números leídos del
                // árbol de AX de una corrida real (no estimados):
                //
                //     GameTabBar.barHeight             84  (+ el piso de abajo)
                //     spacing del VStack                8
                //     QuickHireButton.capsuleHeight    56  (56,0 EXACTOS en las
                //                                          dos escalas: acá no
                //                                          hay medio punto que
                //                                          redondear)
                //     spacing del VStack                8
                //     botón de prestigio               45  (mide 44,0 en 3× y
                //                                          44,5 en 2×: va el
                //                                          entero de arriba para
                //                                          que un solo número
                //                                          sirva en los dos)
                //                                    ----
                //                                     201  (+ el piso de abajo)
                //
                // Los dos altos entran por SÍMBOLO y no por literal a propósito.
                // La barra, porque fue el tercer commit seguido en que cambiaba
                // (80 → 82 → 84) y las dos veces anteriores hubo que acordarse de
                // mover este número a mano. El atajo, porque su alto lo consumen
                // los DOS toasts —éste y el de logros— y un literal copiado se
                // arregla en uno y se olvida en el otro.
                //
                // ⚠️ El único alto que sigue siendo literal es el **45** del
                // botón de prestigio, que es de otra tarea y no lo publica nadie.
                //
                // ⚠️⚠️ Y el gatillo de que estos números dejen de valer NO es un
                // rediseño: es **Dynamic Type**. El atajo y el prestigio están
                // tipografiados con text styles dinámicos y ninguno de los dos
                // tiene el alto clavado, así que a tamaños de accesibilidad los
                // dos crecen y el pelo de despeje de acá abajo se puede comer en
                // RUNTIME. Está contado con nombre y apellido en
                // `QuickHireButton.capsuleHeight`; los números de este bloque
                // valen al tamaño por defecto, que es donde se midieron.
                //
                // ⚠️ El `+ GameTabBar.bottomFloor` NO es decorativo: sin home
                // indicator la barra mide 96 y la pila entera llega a 212,5, así
                // que un 201 pelado terminaría 11,5 pt POR DEBAJO de su tope
                // —solapados de verdad, medido en la vuelta anterior—. Sumando
                // el mismo piso que subió la barra, el aviso despeja a la pila en
                // las dos clases de teléfono, y por los MISMOS márgenes de antes
                // de que el atajo existiera: por **1,0 pt** con notch (201 contra
                // 200,0 medidos en 16 Pro) y por **0,5 pt** sin él (213 contra
                // 212,5 medidos en SE 3). Es finísimo A PROPÓSITO —el aviso tiene
                // que quedar pegado a la franja, no flotando— pero es finito: el
                // que le agregue un pixel a cualquiera de los tres pisos tiene
                // que volver a medir.
                //
                // ⚠️ Cuando `bestHire` es `nil` el atajo no se dibuja y la pila
                // baja 64 pt (la cápsula + su spacing), pero el aviso NO baja: se
                // queda donde está y flota esos 64 pt más arriba de lo que
                // necesita. Es cosmético y es la elección correcta: el número es
                // una constante y el caso que no se puede pisar es el ALTO.
                .padding(.bottom, GameTabBar.barHeight + 8 + QuickHireButton.capsuleHeight
                    + 8 + 45 + GameTabBar.bottomFloor)
        }
        .padding(.horizontal, 20)
        .allowsHitTesting(true)
    }
}
