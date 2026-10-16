import EconomyKit
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
                ContentFailedView(message: message)
            case .recovery:
                SaveRecoveryView()
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
        .onChange(of: scenePhase) { old, new in
            gameState.handleScenePhase(from: old, to: new)
        }
    }
}

/// Pantalla de carga de marca: fondo crema + logo de Ader Games + mascota + tip, en vez del
/// spinner blanco del sistema (que era la primera impresión de la app).
struct SplashView: View {
    /// Claves del catálogo y no texto: eran `Text(verbatim:)` en castellano, y el
    /// jugador en inglés los leía en castellano.
    private static let tips: [LocalizedStringKey] = [
        "splash.tip.merge",
        "splash.tip.tap",
        "splash.tip.upgrades",
    ]
    /// El consejo se sortea UNA vez: sorteado en el `body`, cada pasada cambiaba el alto del texto,
    /// el logo se medía en otro lugar (`onGeometryChange`) y la pasada siguiente volvía a sortear;
    /// el arranque se colgaba en ese bucle de layout.
    @State private var tip = Self.tips.randomElement() ?? Self.tips[0]
    /// El logo mide lo mismo que en la pantalla de lanzamiento (`UILaunchScreen › UIImageName`,
    /// mismo imageset): iOS lo dibuja centrado a su tamaño natural, y el splash arranca ahí.
    private static let logoWidth: CGFloat = 180
    private static let logoAsset = "AderGamesLogo"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `false` mientras el logo está en el centro (como en la pantalla de lanzamiento); `true`
    /// cuando sube a su lugar y aparecen la ruedita y el consejo.
    @State private var risen = false
    /// El Fisura aparece recién con el logo ya arriba: el logo sube pasando por el lugar de su
    /// cabeza, y fundidos a la vez quedaban encimados. El arranque en frío suele terminar a mitad
    /// de la subida, así que ese cuadro encimado era el último que se veía del splash.
    @State private var fisuraShown = false
    @State private var screenMidY: CGFloat?
    /// El centro del logo en su lugar de arriba: se mide ANTES del `offset`, que no mueve el layout.
    @State private var logoMidY: CGFloat?

    /// Cuánto hay que bajar el logo para que caiga en el centro de la pantalla.
    private var offsetToCenter: CGFloat {
        guard let screenMidY, let logoMidY else { return 0 }
        return screenMidY - logoMidY
    }

    var body: some View {
        ZStack {
            Color("PaletteCream")
                .ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { screenMidY = $0 }
            VStack(spacing: 22) {
                Spacer()
                // Se mide un lugar vacío del tamaño del logo y el logo va encima con su `offset`: medido
                // adentro del `offset`, el marco global se corría con él, cambiaba el `offset` y el
                // arranque se colgaba en ese bucle de layout.
                logo
                    .hidden()
                    .accessibilityHidden(true)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { logoMidY = $0 }
                    .overlay {
                        logo
                            .offset(y: risen || reduceMotion ? 0 : offsetToCenter)
                            // Hasta medir, el logo no se dibuja: así no hace un salto desde arriba.
                            .opacity(reduceMotion || (logoMidY != nil && screenMidY != nil) ? 1 : 0)
                    }
                Group {
                    if let fisura = UIArt.image("fisura_celebrate") {
                        fisura.resizable().scaledToFit().frame(maxWidth: 200, maxHeight: 240)
                    }
                }
                .opacity(fisuraShown ? 1 : 0)
                Spacer()
                VStack(spacing: 22) {
                    ProgressView()
                        .tint(Color("PaletteOrange"))
                    Text(tip)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color("PaletteInk").opacity(0.7))
                }
                .opacity(risen ? 1 : 0)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 30)
        }
        .task {
            // Un instante con el logo quieto en el centro (el último cuadro de la pantalla de
            // lanzamiento) y recién ahí sube. Con Reduce Motion no sube: sólo aparece lo demás.
            try? await Task.sleep(for: .milliseconds(150))
            if reduceMotion {
                withAnimation(.easeIn(duration: 0.3)) {
                    risen = true
                    fisuraShown = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.4)) {
                    risen = true
                } completion: {
                    withAnimation(.easeOut(duration: 0.25)) { fisuraShown = true }
                }
            }
        }
    }

    /// El logo de Ader Games; si el asset faltara, el wordmark tipográfico.
    @ViewBuilder private var logo: some View {
        if let image = UIImage(named: Self.logoAsset) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: Self.logoWidth)
                .accessibilityLabel(Text(verbatim: "Ader Games"))
        } else {
            VStack(spacing: 2) {
                Text(verbatim: "ADER")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                Text(verbatim: "GAMES")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .tracking(6)
            }
            .foregroundStyle(Color("PaletteInk"))
            .frame(width: Self.logoWidth)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "Ader Games"))
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
    /// La oferta que el jugador abrió desde el chip (o que se presentó sola).
    @State private var offerSelection: OfferPresentation?
    /// El selector del atajo: un overlay sobre el juego, no una hoja.
    @State private var showQuickHirePicker = false
    /// La tarjeta del video de la columna plegable (E7b), o `nil`.
    @State private var railOffer: SideRailKind?
    /// La sesión del menú deslizable, o `nil`. Su `id` es estable mientras la
    /// hoja está arriba: deslizar entre pestañas cambia la página adentro, no
    /// la sesión, así que la hoja no se vuelve a presentar (PLAN-v2 E3). Las
    /// seis pestañas comparten UN `.fisuSheet(item:)`: con un booleano por hoja,
    /// dos tabs seguidos podían dejar dos banderas en `true` y SwiftUI presentar
    /// una sola.
    @State private var menuSession: MenuSession?

    private struct MenuSession: Identifiable {
        let id = UUID()
        var start: GameScreen
    }
    /// El coordinador de anuncios lo construye la App (necesita los feature
    /// flags, que no existen cuando este `@State` se inicializaría): acá sólo
    /// se lee del entorno.
    @Environment(AdsCoordinator.self) private var adsProvider
    @Environment(AudioManager.self) private var audio
    @Environment(RankingStore.self) private var ranking
    /// La tarjeta del nombre de Dios ya salió: desde ahí se queda hasta que el store la suelta, aunque el
    /// momento deje de ser calmo (la propia tarjeta tapa el tablero).
    @State private var rankingCardUp = false
    // La ficha de personaje espera al tutorial: no es una celebración de la
    // cola, así que éste es su único gate.
    @AppStorage(TutorialFlags.completedKey) private var tutorialDone = false
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
                if Self.isScreenshotMode {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
                        .ignoresSafeArea()
                } else {
                    SpriteView(
                        scene: scene,
                        options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes],
                        debugOptions: [.showsFPS, .showsNodeCount, .showsDrawCount]
                    )
                    .ignoresSafeArea()
                }
                #else
                SpriteView(scene: scene, options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
                    .ignoresSafeArea()
                #endif
            }
            hudColumn
            #if DEBUG
            if !Self.isScreenshotMode {
                debugButton
            }
            #endif

            // La animación del cofre va ÚLTIMA en el `ZStack`: es la única
            // celebración que ocupa la pantalla entera con su propio telón, así
            // que tiene que quedar por encima de todo lo demás —incluido el
            // botón de debug— y no al revés.
            //
            // ⚠️ **No es un `sheet`** (spec §9): el gesto de arrastre de una hoja
            // puede matar la animación por la mitad, y los otros dos overlays
            // no-modales del juego ya viven acá.
            //
            // Y va en su propio `ZStack`, por la misma razón que los dos de
            // arriba: la `.animation` puesta sobre el `ZStack` externo abre la
            // transacción que la `.transition(.opacity)` necesita, pero de paso
            // tiñe de easeInOut TODO lo que cambie en ese frame —el `SpriteView`,
            // el `hudColumn`, el botón de debug—, y acá sí cambian:
            // `celebrationHidesUI` se mueve en el mismo ciclo que `chestReward`.
            ZStack {
                if let chest = gameState.chestReward, gameState.showing == .chestOpening {
                    ChestOpeningView(reward: chest)
                        // La identidad por premio: dos cofres seguidos son dos
                        // animaciones, no una vista que cambia de contenido a la
                        // mitad de sus latidos.
                        .id(chest.id)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: gameState.chestReward?.id)

            // La tarjeta del nombre del ranking va debajo de la cinemática: sale en el primer momento
            // calmo, o sea después de ella, y nunca a la vez.
            rankingCardLayer

            // La cinemática, al lado del cofre y por lo mismo: pantalla entera, su propio telón y su
            // propio `ZStack` para que la `.animation` no tiña el resto.
            ZStack {
                if let cinematic = gameState.cinematic, gameState.showing == .cinematic {
                    CinematicOverlay(id: cinematic)
                        .id(cinematic)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: gameState.showing == .cinematic)

            // La pantalla previa de la pausa publicitaria (E7b): encima de todo,
            // como el cofre, y sin hoja (ver la vista).
            ZStack {
                if let offer = gameState.adBreakOffer {
                    RewardedInterstitialIntroView(offer: offer)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: gameState.adBreakOffer?.id)
        }
        .modifier(NoticesLayer())
        // El globo del visitante va encima del HUD y de los avisos (E14b B19); el selector del
        // atajo, los pop-ups y el tutorial, que se montan después, encima de él.
        .modifier(StageBubbleLayer(feed: scene?.stageBubbleFeed, hidden: rankingCardUp))
        // El selector del atajo va ANTES del overlay del tutorial: así su cara fijada le llega.
        .modifier(QuickHirePickerLayer(isPresented: $showQuickHirePicker))
        .modifier(RewardFlightLayer())
        .modifier(ShareOfferLayer())
        .modifier(NewCharacterCardPopup())
        .modifier(MomentOfferLayer())
        .modifier(AdValueProbe())
        // El overlay se monta acá y no dentro del `ZStack` porque necesita los
        // anchors que publican los controles de adentro: `overlayPreferenceValue`
        // los entrega ya recolectados, y el `GeometryReader` a pantalla completa
        // los resuelve a puntos sin que nadie tenga que restar safe areas a mano.
        .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                let resolved = anchors.mapValues { proxy[$0] }
                ZStack {
                    // El renderer único del tutorial: el núcleo y las lecciones.
                    TutorialOverlay(anchors: resolved)
                }
            }
            .ignoresSafeArea()
        }
        // El director no dispara lecciones con una hoja (o el popup de
        // prestigio) tapando el tablero: el coach señala controles de ESTA
        // pantalla. `GameState` no puede ver estos `@State`, así que se los
        // publica esta vista.
        .onChange(of: menuSession?.id) { _, id in
            gameState.uiCoversBoard = boardIsCovered
            // **La pausa natural del juego**: el jugador cerró el menú entero y
            // vuelve al tablero (no cada página: deslizar no es una pausa). No
            // estaba tapeando, no hay nada en curso, y no se le interrumpe
            // ninguna acción — que es exactamente lo que un interstitial
            // disparado por reloj NO puede garantizar por su cuenta. Si no le
            // toca, esto no hace nada y vuelve enseguida.
            if id == nil {
                Task { await gameState.menuDidClose() }
            }
        }
        .onChange(of: showPrestige) {
            gameState.uiCoversBoard = boardIsCovered
        }
        .onChange(of: gameState.visitorPopup) {
            gameState.uiCoversBoard = boardIsCovered
        }
        .onChange(of: gameState.eventPopup) {
            gameState.uiCoversBoard = boardIsCovered
        }
        .onChange(of: gameState.shareCardMoment) {
            gameState.uiCoversBoard = boardIsCovered
        }
        .onChange(of: gameState.adBreakOffer?.id) { _, _ in
            gameState.uiCoversBoard = boardIsCovered
        }
        // La música por piso sigue al piso visible que ya publica `GameState`
        // —scroll, ascensor, el piso con el que carga la partida—, sin que la
        // navegación tenga que saber que hay música. `initial` pone el primer
        // tema apenas aparece el tablero.
        .onChange(of: gameState.visibleFloorDef?.id, initial: true) { _, floorID in
            audio.showFloor(floorID)
        }
        .onAppear {
            if scene == nil {
                scene = BoardScene(gameState: gameState)
            }
        }
        .fisuSheet(item: Binding(
            get: { tutorialDone ? gameState.characterSheet : nil },
            set: { gameState.characterSheet = $0 }
        )) { sheet in
            CharacterSheetView(sheet: sheet)
        }
        .modifier(GamePopups(showPrestige: $showPrestige))
        // El menú deslizable: las pestañas desbloqueadas como páginas de UNA
        // hoja. Sólo la página quieta queda montada (con su `NavigationStack`,
        // su marco y su X; al deslizar se desmonta y pierde su estado); el
        // panel del `panelSheet` ES la hoja (`fisuSheet` la deja sin el material
        // del sistema debajo): flota sobre el juego atenuado con su banda
        // inferior a la vista, como los popups. La Tienda es pestaña (E14b B26); si el `+` de la
        // plata la abre antes de que la barra la tenga, va sola, sin flechas ni puntos.
        .fisuSheet(item: $menuSession) { session in
            MenuPagerView(
                pages: gameState.menuPages(startingAt: session.start),
                start: session.start,
                adsProvider: adsProvider,
                onStore: { menuSession?.start = .store }
            ) { page in
                gameState.menuPageChanged(to: page)
            }
            .id(session.start)
        }
        .modifier(PrizeSheets(syncCover: { gameState.uiCoversBoard = boardIsCovered }))
        .modifier(OfferSheets(selection: $offerSelection, syncCover: { gameState.uiCoversBoard = boardIsCovered }))
        // El paso 2 de las recompensas gratis (E14b B29): encima de los pop-ups que lo dieron.
        .modifier(RewardDoubleLayer(host: .board, syncCover: { gameState.uiCoversBoard = boardIsCovered }))
        #if DEBUG
        .sheet(isPresented: $showDebugPanel) {
            DebugPanelView()
        }
        #endif
        .modifier(ShopRequestRouter(open: openRequestedShop))
        .background(uiTestMarkers)
        // La geometría del tablero ("5x2@112·1.25"), para `IPadLayoutUITests`.
        .background(boardLayoutMarker)
    }

    /// Invisibles para la UI, medibles para los UI tests. Tres marcas en un solo `background`: el `body`
    /// ya venía al límite del type-checker.
    private var uiTestMarkers: some View {
        ZStack {
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("board.units")
                .accessibilityValue(Text(verbatim: String(gameState.unitCount)))
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("board.revealed")
                .accessibilityValue(Text(verbatim: String(gameState.revealedTierMarker)))
            // El piso visible, como ID crudo (no nombre traducido: a prueba de la trampa 6). Desde que la
            // píldora del HUD se retiró (2026-08-18) es el único observable del piso que sobrevive a las
            // celebraciones que apagan la UI — `exists` y `value` se leen igual con la opacidad en 0.
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("board.floor")
                .accessibilityValue(Text(verbatim: gameState.towerNavigation.floorID))
        }
    }

    /// La tarjeta del nombre de Dios. Cerrarla sin elegir es "Ahora no".
    private var rankingCardLayer: some View {
        ZStack {
            if rankingCardUp, let prompt = ranking.entryPrompt {
                RankingEntryCard(
                    prompt: prompt, nameError: ranking.nameError, isSubmitting: ranking.isSubmitting,
                    onSubmit: { name in Task { await ranking.submit(name: name) } },
                    onLater: { ranking.postpone() })
            }
        }
        .animation(.easeInOut(duration: 0.25), value: rankingCardUp)
        .onChange(of: gameState.rankingCardDue(alreadyUp: rankingCardUp)) { _, due in
            rankingCardUp = due
            gameState.uiCoversBoard = boardIsCovered
        }
    }

    /// Lo que tapa el tablero y vive en esta vista; `GameState` no puede ver estos `@State`.
    private var boardIsCovered: Bool {
        menuSession != nil || showPrestige || rankingCardUp
            || gameState.shareCardMoment != nil || gameState.visitorPopup != nil
            || gameState.eventPopup != nil || gameState.mattressPopup != nil || gameState.wheelSheet != nil
            || gameState.packagePopup != nil || gameState.adBreakOffer != nil || offerSelection != nil
            || gameState.rewardDouble?.host == .board
    }

    private var boardLayoutMarker: some View {
        Color.clear
            .accessibilityElement()
            .accessibilityIdentifier("board.layout")
            .accessibilityValue(Text(verbatim: gameState.boardLayoutMarker))
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

    /// El HUD y todo lo que va encima del tablero.
    ///
    /// Vive fuera del `body` porque agregarle la atenuación de celebraciones lo
    /// hizo caer en "the compiler is unable to type-check this expression in
    /// reasonable time": el `ZStack` del `body` ya venía al límite. Extraer una
    /// rama es el remedio estándar y además hace legible el orden de capas.
    @ViewBuilder private var hudColumn: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                HUDView(
                    onStoreTap: { open(.store) },
                    onMapOpen: { gameState.tutorialTipCompleted(.elevator) }
                )
                // Las esquinas: sellos de premios a la izquierda; el especial, los
                // eventos y los boosts a la derecha (C9).
                CornersView(railOffer: $railOffer) {
                    gameState.markOfferPresented(id: $0)
                    offerSelection = OfferPresentation(id: $0)
                }
            }
            // Durante la celebración a pantalla completa el HUD de arriba se va: el
            // reveal va centrado y no tiene que esquivar nada. Sólo esa celebración
            // lo hace — un toast de logro de 4 s no justifica apagar la interfaz.
            .opacity(hidesUIForCelebration ? 0 : 1)
            Spacer()
            // La barra de abajo NO se apaga nunca (regla del dueño, r56): el fondo del
            // escenario termina arriba de ella (`BoardScene.floorBottom`) y sin la barra
            // quedaba a la vista un rectángulo vacío.
            bottomBar
        }
        // Con `allowsHitTesting` atado a la celebración no se toca nada durante ella:
        // ni lo que no se ve ni la barra, que queda a la vista pero quieta.
        .modifier(SideRailTapAway(offer: $railOffer))
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

    /// Abre el menú deslizable en una pestaña (la barra o el `+` de la plata).
    /// Si la lección contextual en pantalla señalaba justo esta hoja, abrirla la
    /// da por cumplida — la mejor de sus tres salidas.
    private func open(_ screen: GameScreen) {
        gameState.menuDidOpen(at: screen)
        menuSession = MenuSession(start: screen)
    }

    /// «¡Vamos!» de un evento de compra (C25): abre la hoja en la Tienda o en Mejoras; la pantalla de
    /// destino toma el pedido y deja el ítem en foco.
    private func openRequestedShop(_ request: ShopRequest) {
        open(request.screen)
    }

    /// La franja de abajo: la barra de las 6 pantallas con las solapas de
    /// Contratar y Reencarnar montadas en su borde (C18). Conserva
    /// `.tutorialAnchor(.bottomBar)`, que no ilumina nada —es la franja que el
    /// globo del tutorial tiene que esquivar—.
    ///
    /// ⚠️ Sin paddings propios: la barra se funde con los tres bordes (su panel
    /// se estira solo bajo el home indicator, ver `GameTabBar.bottomPanel`) y
    /// cualquier margen acá le dejaría una lonja de tablero al costado.
    ///
    /// El atajo no desaparece nunca (PLAN-v2 E3); el prestigio aparece recién
    /// cuando hay blue que cobrar. Esa aparición va **sin animación**: si algún día
    /// se anima, con `accessibilityReduceMotion` apagándolo.
    private var bottomBar: some View {
        BottomMenuBar(select: open)
            .overlay(alignment: .top) {
                BarFlaps(
                    onChooseHire: { withAnimation(.spring(duration: 0.3)) { showQuickHirePicker = true } },
                    onPrestige: {
                        gameState.tutorialTipCompleted(.prestige)
                        showPrestige = true
                    }
                )
            }
        .tutorialAnchor(.bottomBar)
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
    /// Modo captura: apaga el andamiaje de DEBUG —el contador de FPS del
    /// SpriteView y el botón de herramientas— para poder fotografiar el juego
    /// con los fixtures de `--uitest-*`, que también son DEBUG y por lo tanto
    /// no existen en Release.
    ///
    /// Va en un flag propio y no en `--uitest`: `AscentRenderingUITests` toca
    /// `hud.debug`, así que esconder el botón en toda corrida de UI tests
    /// rompería esa suite.
    static let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshot-mode")

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


/// Escucha el pedido de un evento de compra y abre la hoja. Aparte del `body` de `RootView`, que ya
/// está al límite del type-checker.
private struct ShopRequestRouter: ViewModifier {
    @Environment(GameState.self) private var gameState
    let open: (ShopRequest) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: gameState.shopRequest) { _, request in
            if let request { open(request) }
        }
    }
}
