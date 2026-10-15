import EconomyKit
import SwiftUI

/// El color y el nombre de una rareza de cofre.
///
/// Los cuatro colores de la paleta lockeada del spec —verde `#6BCB77`, azul
/// `#4D96FF`, rosa `#FF4D6D`, amarillo `#FFD93D`— **son** los cuatro del
/// catálogo de assets, así que la rareza se pinta con los `Color("Palette…")`
/// de siempre y no con literales hexadecimales sueltos.
///
/// Las claves se nombran una por una en vez de interpolar `rawValue`: una clave
/// armada en tiempo de ejecución es invisible para el compilador y para el grep,
/// que es exactamente cómo se llegó a mostrar "gifts.payout 8,4 M" en pantalla.
enum ChestRarityStyle {
    static func color(_ rarity: SkinsConfig.Rarity) -> Color {
        switch rarity {
        case .comun: Color("PaletteGreen")
        case .rara: Color("PaletteBlue")
        case .epica: Color("PalettePink")
        case .legendaria: Color("PaletteYellow")
        }
    }

    static func nameKey(_ rarity: SkinsConfig.Rarity) -> LocalizedStringKey {
        switch rarity {
        case .comun: "chest.rarity.comun"
        case .rara: "chest.rarity.rara"
        case .epica: "chest.rarity.epica"
        case .legendaria: "chest.rarity.legendaria"
        }
    }

    /// El nombre ya traducido, para las tablas de probabilidades.
    static func name(_ rarity: SkinsConfig.Rarity) -> String {
        switch rarity {
        case .comun: String(localized: "chest.rarity.comun")
        case .rara: String(localized: "chest.rarity.rara")
        case .epica: String(localized: "chest.rarity.epica")
        case .legendaria: String(localized: "chest.rarity.legendaria")
        }
    }

    /// El ícono de la fila (SF Symbols), para `OddsDisclosureView.Row.symbol`.
    static func symbol(_ rarity: SkinsConfig.Rarity) -> String {
        switch rarity {
        case .comun: "circle.fill"
        case .rara: "diamond.fill"
        case .epica: "star.fill"
        case .legendaria: "crown.fill"
        }
    }
}


/// La geometría del escenario del cofre (r56), en puntos desde su centro. Los
/// clips (`cofre_espera`, `cofre_sacude`, `cofre_abre`) son cuadros de 512 px:
/// el cofre cerrado ocupa ~310×230 px centrado y, abierto, la tapa sube hasta
/// ~y 45.
///
/// Dos encuadres: **cerrado**, el cofre es el protagonista de la pantalla
/// (grande, al medio); **abierto**, la cámara se aleja —el cofre se achica y
/// baja— para dejarle arriba el lugar al premio que sale volando de adentro
/// (D14: cero superposición).
enum ChestStage {
    static let clipPixels: CGFloat = 512
    /// El lado del cuadro del clip con el cofre cerrado.
    static let closedSide: CGFloat = 460
    /// El lado del cuadro del clip con el cofre abierto.
    static let openSide: CGFloat = 290
    /// El centro del cuadro, cerrado y abierto.
    static let closedClipY: CGFloat = -10
    static let openClipY: CGFloat = 46
    /// El cofre cerrado en el cuadro del clip (px).
    static let closedChest = CGRect(x: 100, y: 140, width: 310, height: 230)
    /// La parte alta de la tapa abierta y el piso del cofre (px del cuadro).
    static let openLidTop: CGFloat = 45
    static let chestFloor: CGFloat = 400
    /// La boca del cofre abierto (px): de ahí sale la figurita.
    static let openMouth: CGFloat = 205
    /// El centro del premio.
    static let prizeY: CGFloat = -192
    /// El alto que ocupa el bloque del premio (tarjeta con su nombre y el detalle).
    static let prizeHeight: CGFloat = 220
    /// El centro de los botones, debajo del cofre abierto.
    static let controlsY: CGFloat = 214
    /// Media altura de la pila de botones más alta (equipar + otro cofre + después).
    static let controlsHalfHeight: CGFloat = 84
    /// El cartel de «tocá» y los tres puntos, debajo del cofre cerrado.
    static let hintY: CGFloat = 160
    /// Lo que el sello de la rareza sobresale arriba de la tarjeta del premio.
    static let sealOverhang: CGFloat = 16
    /// Aire entre los botones y la barra de abajo.
    static let barGap: CGFloat = 8

    static var closedScale: CGFloat { closedSide / clipPixels }
    static var openScale: CGFloat { openSide / clipPixels }

    /// Y de la punta de la tapa abierta.
    static var lidTopY: CGFloat { openClipY + (openLidTop - clipPixels / 2) * openScale }
    /// Y del piso del cofre abierto.
    static var openFloorY: CGFloat { openClipY + (chestFloor - clipPixels / 2) * openScale }
    /// Y del piso del cofre cerrado (donde se levanta el polvo de la caída).
    static var closedFloorY: CGFloat { closedClipY + (closedChest.maxY - clipPixels / 2) * closedScale }
    /// Y de la cerradura del cofre cerrado (de donde saltan las chispas).
    static var lockY: CGFloat { closedClipY + (closedChest.midY - clipPixels / 2) * closedScale }
    /// Y de la boca del cofre abierto.
    static var mouthY: CGFloat { openClipY + (openMouth - clipPixels / 2) * openScale }
    /// Y del borde de abajo del bloque del premio.
    static var prizeBottomY: CGFloat { prizeY + prizeHeight / 2 }

    /// La mitad del alto del escenario entero, desde su centro: el escenario es
    /// simétrico porque todo va con offsets desde el centro.
    static var halfHeight: CGFloat {
        max(-(prizeY - prizeHeight / 2) + sealOverhang, controlsY + controlsHalfHeight)
    }

    /// La escala que hace entrar el escenario en el alto libre arriba de la barra
    /// (en el SE no entra a tamaño natural). Nunca agranda.
    static func fit(height: CGFloat) -> CGFloat {
        min(1, max(0.5, height / (halfHeight * 2)))
    }

    /// Lo que ocupa la barra inferior desde el borde físico: la barra NO se apaga
    /// durante el cofre (regla del dueño, r56) y el escenario vive arriba de ella
    /// (D14). Alto con las solapas + su piso + la safe area de abajo.
    @MainActor static var barClearance: CGFloat {
        GameTabBar.barHeight + GameTabBar.bottomFloor + ScreenInsets.shared.bottom + barGap
    }
}

/// Qué clip corre en cada momento del cofre. Pura: la vista sólo la consulta.
enum ChestClip {
    static func id(opening: Bool, shaking: Bool) -> String {
        if opening { return "cofre_abre" }
        return shaking ? "cofre_sacude" : "cofre_espera"
    }
}

/// La pose del cofre en un toque: squash & stretch con el pie fijo, el bamboleo
/// y el saltito.
private struct ChestPose {
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var angle: Double = 0
    var lift: CGFloat = 0
}

/// La figurita sale volando de la boca del cofre: chiquita, girando, y se
/// asienta en su lugar con el rebote del resorte que la inserta.
///
/// El desplazamiento va DESPUÉS de la escala y el giro: girar una vista ya
/// corrida con `offset` la hace orbitar alrededor del centro del escenario (la
/// figurita salía por abajo a la izquierda).
private struct CardFlight: ViewModifier {
    let launched: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(launched ? 0.16 : 1)
            .rotationEffect(.degrees(launched ? -220 : 0))
            .opacity(launched ? 0.4 : 1)
            .offset(y: launched ? ChestStage.mouthY : ChestStage.prizeY)
    }
}

/// Abrir un cofre (E14 C4/C26, rehecho en r56): el cofre cae al piso, grande,
/// y respira con `cofre_espera`. Cada toque lo sacude (`cofre_sacude`) con
/// squash & stretch, chispas, una onda y un temblor que crecen 1-2-3; al
/// tercero corre `cofre_abre`, la cámara se aleja y, cuando la tapa revienta,
/// un fogonazo con los rayos y las estrellas del color de la rareza larga la
/// figurita del premio (`ChestPrizeCard`) volando hasta su lugar, arriba del
/// cofre (D14).
///
/// Los clips van por `ChestClipDeck` y no por el pool de video: el cofre no se
/// queda en póster por el Modo de bajo consumo o la térmica (ver
/// `ChestMotion`). Con Reduce Motion no hay caída, sacudidas ni partículas: un
/// solo toque lleva al premio con fundidos.
///
/// ⚠️ **No es un `sheet`**: los otros dos overlays no-modales del juego
/// (`towerNotice`, `achievementToast`) ya viven en el `ZStack` de `RootView`, y
/// un sheet trae un gesto de arrastre que puede matar la animación por la mitad.
///
/// ⚠️ **El cierre pasa SIEMPRE por `gameState.dismissChestReward()`**, que
/// limpia el payload antes de cerrar el turno. El porqué —y lo que pasa si se
/// invierte— está en el doc de ese método.
struct ChestOpeningView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Se ofrece el cofre extra por video. Se decide una vez, al abrir el
    /// cofre; que el video esté cargado ya no es condición: el botón espera la
    /// carga y, si no hay videos, lo dice (`RewardedOfferButton`).
    @State private var offersExtraChest = false
    /// El video del cofre extra está cargando o corriendo (lo escribe
    /// `RewardedOfferButton`). Mientras tanto las salidas se ignoran: cerrar el
    /// premio con el anuncio por aparecer lo dejaría presentarse fuera de
    /// contexto y `grantExtraChestFromAd()` actuaría sobre otro cofre.
    @State private var extraChestBusy = false

    let reward: GameState.ChestReward

    @State private var beat: Beat = .arriving
    @State private var deck: ChestClipDeck?
    /// La caída del cofre (o su fundido, con Reduce Motion).
    @State private var entered = false
    @State private var breathing = false
    /// Cuántas veces se tocó el candado (los tres puntos y la fuerza del golpe).
    @State private var taps = 0
    @State private var poseKick = 0
    @State private var landKick = 0
    @State private var quakeKick = 0
    @State private var ringKick = 0
    @State private var burstRingKick = 0
    /// La cámara se alejó: el cofre en su encuadre de abierto.
    @State private var opened = false
    /// La tapa reventó: rayos, luz de la rareza y el cofre abierto quieto.
    @State private var burst = false
    @State private var raysFaded = false
    @State private var flash: Double = 0
    @State private var emissions: [ChestEmission] = []
    /// El premio sobre el cofre.
    @State private var contentRevealed = false

    /// Apaga el auto-avance de los latidos que esperan un toque, para que la
    /// animación avance **sólo con el dedo**.
    ///
    /// ⚠️ Existe por el defecto que en este proyecto ya apareció seis veces: un
    /// test que queda verde con la funcionalidad desenchufada. Como cada latido
    /// se dispara solo a los 1,2 s, un smoke que tapea y espera la carta
    /// **pasa igual con `tap()` muerta** — el reloj llega al mismo lugar.
    /// Sin reloj, un toque que no hace nada deja la animación parada y el test
    /// se pone rojo.
    ///
    /// En Release es `false` en tiempo de compilación: la puerta no existe en lo
    /// que se shippea.
    private static let waitsForTapsOnly: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitest-chest-manual")
        #else
        false
        #endif
    }()

    /// La caída: arranca arriba, fuera del escenario.
    private static let dropHeight: CGFloat = 640
    private static let dropSeconds = 0.34
    /// Del estallido a la figurita asentada, y de ahí a los botones.
    private static let flightSeconds = 0.6
    private static let settleSeconds = 0.55

    private var budget: ChestFX.Budget {
        ChestFX.budget(maxLiveVideos: VideoPlayerPool.shared.maxLive)
    }

    var body: some View {
        // Un `ZStack` pelado y offsets en PUNTOS desde el centro, no un
        // `GeometryReader` con fracciones: adentro del `ZStack` de `RootView` el
        // lector NO mide la pantalla —mide lo que le proponen— y el layout
        // terminaba a media altura. Centrado + offsets no depende de qué le
        // propongan.
        //
        // El telón cubre la pantalla entera —también la barra de abajo, que
        // queda a la vista pero apagada—; el escenario vive en el alto libre
        // entre el borde de arriba y la barra (`stageArea`).
        let top = ScreenInsets.shared.top
        let bottom = ChestStage.barClearance
        return ZStack {
            // El telón: el HUD de arriba ya está apagado por la cola
            // (`celebrationHidesUI`), esto apaga el tablero.
            Color.black.opacity(0.66)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { proxy in
                stageArea
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(ChestStage.fit(height: proxy.size.height))
            }
            .padding(.top, top)
            .padding(.bottom, bottom)

            // El fogonazo de la apertura.
            Color.white
                .opacity(flash)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // El área tappable: una capa propia, ARRIBA del arte y ABAJO de
            // los botones, que se retira en el reposo para no comerse sus
            // toques. El identifier va acá —en el control de verdad— y no en
            // ningún contenedor.
            if beat < .resting {
                Button(action: tap) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chest.tap")
                .accessibilityLabel(Text("chest.tap.hint"))
            }

            #if DEBUG
            clipMarker
            #endif
        }
        .ignoresSafeArea()
        // Sin esto VoiceOver se va al HUD apagado que quedó debajo.
        .accessibilityAddTraits(.isModal)
        // Los decodificadores del tablero se sueltan mientras el cofre corre:
        // los tres del cofre son los únicos vivos (también en el SE).
        .suspendsVideoPool(deck?.animates == true)
        .task(id: beat) { await choreograph(beat) }
        .task {
            await offerExtraChestIfAllowed()
        }
        .onDisappear { deck?.stop() }
    }

    #if DEBUG
    /// Para el UI test: qué clip manda y si ya pintó (`ChestClipDeck.status`).
    /// Un cofre que se queda en su póster dice `still` o `…-loading`.
    private var clipMarker: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityIdentifier("chest.clip")
            .accessibilityValue(Text(verbatim: deck?.status ?? "none"))
            .allowsHitTesting(false)
    }
    #endif

    /// El escenario: la luz, el cofre, las partículas, el premio arriba y los
    /// botones abajo, con offsets en puntos desde su centro.
    private var stageArea: some View {
        let still = reduceMotion
        let amplitude = quakeAmplitude
        return ZStack {
            spotlight
            rays
            ChestShockwave(trigger: ringKick, tint: Color("PaletteCream"))
                .frame(width: 200, height: 200)
                .offset(y: ChestStage.lockY)
            ChestShockwave(trigger: burstRingKick, tint: rarityColor, reach: 2.8)
                .frame(width: 200, height: 200)
                .offset(y: ChestStage.mouthY)

            chest
                .accessibilityHidden(true)

            ChestParticleField(emissions: emissions)
                .frame(width: 900, height: 1100)

            if contentRevealed {
                cardContent
            }

            if beat == .resting {
                controls
                    .frame(maxWidth: 250)
                    .offset(y: ChestStage.controlsY)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 24)))
            } else if beat >= .waiting, beat < .cinematic {
                hint
                    .offset(y: ChestStage.hintY)
                    .transition(.opacity)
            }
        }
        // Los botones del reposo entran con su propio resorte.
        .animation(still ? .easeOut(duration: 0.25) : .spring(duration: 0.4, bounce: 0.3),
                   value: beat == .resting)
        // El temblor de cada golpe: el escenario entero, no sólo el cofre.
        .keyframeAnimator(initialValue: CGFloat(0), trigger: quakeKick) { content, dx in
            content.offset(x: still ? 0 : dx)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(amplitude, duration: 0.035)
                LinearKeyframe(-amplitude * 0.8, duration: 0.05)
                LinearKeyframe(amplitude * 0.5, duration: 0.05)
                LinearKeyframe(-amplitude * 0.25, duration: 0.05)
                LinearKeyframe(0, duration: 0.05)
            }
        }
    }

    /// Más fuerte con cada toque, y el doble en la apertura.
    private var quakeAmplitude: CGFloat {
        burst ? 11 : CGFloat(2 + 2 * min(taps, 3))
    }

    /// La luz que cae sobre el cofre: dorada mientras se lo fuerza (más con cada
    /// toque), del color de la rareza cuando revienta.
    private var spotlight: some View {
        // Asentada la figurita, la luz baja: la atención es de ella.
        let level = burst ? (raysFaded ? 0.28 : 0.6) : 0.16 + 0.1 * Double(min(taps, 3))
        let tint = burst ? rarityColor : Color("PaletteYellow")
        return RadialGradient(
            colors: [tint.opacity(level), tint.opacity(level * 0.35), .clear],
            center: .center,
            startRadius: 8,
            endRadius: 340
        )
        .frame(width: 760, height: 760)
        .offset(y: opened ? ChestStage.openClipY : ChestStage.closedClipY)
        .opacity(entered ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: taps)
        .animation(.easeOut(duration: 0.4), value: burst)
        .animation(.easeOut(duration: 0.8), value: raysFaded)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Los rayos de la rareza detrás del cofre abierto. Se apagan cuando la
    /// figurita se asienta: la atención pasa a ella (que trae los suyos).
    @ViewBuilder private var rays: some View {
        if burst, !reduceMotion {
            RewardRays(tint: rarityColor)
                .frame(width: 620, height: 620)
                .offset(y: ChestStage.mouthY)
                .opacity(raysFaded ? 0 : 0.9)
                .transition(.scale(scale: 0.15).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    // MARK: El cofre

    /// El cofre con sus transformaciones: la caída, el golpe del aterrizaje, la
    /// pose de cada toque, el respiro de la espera y el encuadre (cerrado o
    /// abierto). El pie queda fijo en todas: el cofre se aplasta contra el piso.
    private var chest: some View {
        let force = CGFloat(min(max(taps, 1), 3))
        return chestArt
            .keyframeAnimator(initialValue: ChestPose(), trigger: poseKick) { content, pose in
                content
                    .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
                    .rotationEffect(.degrees(pose.angle), anchor: .bottom)
                    .offset(y: pose.lift)
            } keyframes: { _ in
                KeyframeTrack(\.scaleY) {
                    CubicKeyframe(1 - 0.06 * force, duration: 0.07)
                    SpringKeyframe(1 + 0.04 * force, duration: 0.12)
                    SpringKeyframe(1, duration: 0.32, spring: .bouncy)
                }
                KeyframeTrack(\.scaleX) {
                    CubicKeyframe(1 + 0.06 * force, duration: 0.07)
                    SpringKeyframe(1 - 0.03 * force, duration: 0.12)
                    SpringKeyframe(1, duration: 0.32, spring: .bouncy)
                }
                KeyframeTrack(\.angle) {
                    LinearKeyframe(-2.5 * force, duration: 0.06)
                    LinearKeyframe(2.5 * force, duration: 0.09)
                    LinearKeyframe(-1.2 * force, duration: 0.08)
                    SpringKeyframe(0, duration: 0.25)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(0, duration: 0.07)
                    CubicKeyframe(-10 * force, duration: 0.12)
                    SpringKeyframe(0, duration: 0.28, spring: .bouncy)
                }
            }
            .keyframeAnimator(initialValue: ChestPose(), trigger: landKick) { content, pose in
                content.scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.scaleY) {
                    CubicKeyframe(0.8, duration: 0.06)
                    SpringKeyframe(1.06, duration: 0.14)
                    SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                }
                KeyframeTrack(\.scaleX) {
                    CubicKeyframe(1.16, duration: 0.06)
                    SpringKeyframe(0.96, duration: 0.14)
                    SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                }
            }
            .scaleEffect(breathing ? 1.025 : 1, anchor: .bottom)
            .animation(
                // El respiro de la espera es un `repeatForever` **atado a
                // la bandera**: al apagarse, el mismo modificador pasa a
                // ser un resorte común (la forma de `TapHereHand`).
                breathing
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .spring(duration: 0.28),
                value: breathing
            )
            .scaleEffect(opened ? ChestStage.openSide / ChestStage.closedSide : 1)
            .offset(y: chestOffset)
            // Sin Reduce Motion el cofre cae desde arriba, fuera de cuadro; con
            // Reduce Motion aparece con un fundido.
            .opacity(entered || !reduceMotion ? 1 : 0)
    }

    private var chestOffset: CGFloat {
        let resting = opened ? ChestStage.openClipY : ChestStage.closedClipY
        guard !entered, !reduceMotion else { return resting }
        return resting - Self.dropHeight
    }

    /// El arte: el clip que manda o, mientras no pintó (o si no hay video), su
    /// cuadro quieto. Los tres clips quedan montados: cambiar es cambiar cuál se
    /// ve, sin decodificador nuevo.
    private var chestArt: some View {
        ZStack {
            stillArt
                .opacity(clipCovers ? 0 : 1)
            if let deck, deck.animates {
                ForEach([ChestClipDeck.Clip.idle, .shake, .open], id: \.self) { clip in
                    if let player = deck.players[clip] {
                        ChestClipSurface(player: player) { deck.markReady(clip) }
                            .opacity(deck.showing == clip && deck.ready.contains(clip) ? 1 : 0)
                    }
                }
            }
        }
        .frame(width: ChestStage.closedSide, height: ChestStage.closedSide)
    }

    /// El clip que manda ya pintó: el cuadro quieto no hace falta.
    private var clipCovers: Bool {
        guard let deck, deck.animates else { return false }
        return deck.ready.contains(deck.showing)
    }

    /// El cofre quieto: el primer cuadro de la espera (o el último de la
    /// apertura, ya abierto), sacados del clip; si todavía no están, el cofre
    /// del atlas en el lugar del cofre del clip.
    @ViewBuilder private var stillArt: some View {
        let side = ChestStage.closedSide
        let still = burst || (opened && reduceMotion) ? deck?.openedStill : deck?.closedStill
        if let still {
            Image(uiImage: still)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
        } else if let image = UIArt.image("ui_chest_closed") {
            let box = ChestStage.closedChest
            image
                .resizable()
                .scaledToFit()
                .frame(width: box.width * ChestStage.closedScale, height: box.height * ChestStage.closedScale)
                .offset(x: (box.midX - ChestStage.clipPixels / 2) * ChestStage.closedScale,
                        y: (box.midY - ChestStage.clipPixels / 2) * ChestStage.closedScale)
                .frame(width: side, height: side)
        }
    }

    // MARK: El cartel

    /// Lo que hay que hacer, a la vista (E14 C4), con los tres puntos que se
    /// llenan con cada toque.
    private var hint: some View {
        VStack(spacing: Tokens.s8) {
            Text("chest.tap.hint")
                .font(Tokens.title)
                .foregroundStyle(.white)
                .shadow(color: Color("PaletteInk"), radius: 0, x: 0, y: 2)
                .shadow(color: Color("PaletteInk"), radius: 0, x: 1.5, y: 0)
                .shadow(color: Color("PaletteInk"), radius: 0, x: -1.5, y: 0)
                .shadow(color: Color("PaletteInk"), radius: 0, x: 0, y: -1.5)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            HStack(spacing: Tokens.s12) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index < taps ? Color("PaletteYellow") : Color("PaletteCream").opacity(0.35))
                        .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
                        .frame(width: 16, height: 16)
                        .scaleEffect(index < taps ? 1.15 : 1)
                        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.6), value: taps)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// El cofre extra por video se decide una vez, al abrir.
    private func offerExtraChestIfAllowed() async {
        // ⚠️ **Durante el tutorial no se ofrece NADA.** El cofre de
        // bienvenida cae al cerrar la fase obligatoria, y un jugador que
        // todavía está aprendiendo a fusionar no tiene que elegir si mira
        // publicidad. Es la misma regla que `isCalmMoment`
        // aplica del otro lado, y la que hace que la primera sesión no
        // arranque vendiendo.
        //
        // Vale de más bajo `--uitest*`, donde el stub contesta "hay
        // anuncio" al instante: sin este guard el botón aparecería en el
        // cofre del tutorial en toda corrida de tests.
        guard !gameState.tutorialPhaseActive else { return }
        // El cofre de un video no vuelve a ofrecer otro: sin este freno la
        // cadena no tiene fin y las 41 pintas se vacían en una tarde. Y no
        // se ofrece un cofre que no tendría nada desbloqueado que dar.
        guard gameState.canOfferExtraChest else { return }
        offersExtraChest = true
    }

    // MARK: El premio

    /// El premio, arriba del cofre abierto: la figurita (`ChestPrizeCard`) con
    /// sus rayos y el pop, y el detalle en blanco sobre el telón. Vive como capa
    /// hermana del escenario para que ninguna transformación del arte rasterice
    /// el texto.
    private var cardContent: some View {
        VStack(spacing: Tokens.s8) {
            ChestPrizeCard(rarity: rarity, name: prizeName, showsSeal: isSkinPrize) {
                prizeArt
            }
            Text(subtitle)
                .font(Tokens.caption)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.s8)
        .frame(width: 240, height: ChestStage.prizeHeight)
        // La aparición la anima el `withAnimation` que prende
        // `contentRevealed`: sale volando de la boca del cofre hasta su lugar
        // (la identidad de `CardFlight` es la que la deja a su altura). Con
        // Reduce Motion entra con un fundido, ya en su lugar.
        .offset(y: reduceMotion ? ChestStage.prizeY : 0)
        .transition(
            reduceMotion
                ? .opacity
                : .modifier(active: CardFlight(launched: true), identity: CardFlight(launched: false))
        )
        // La parada de AX es el contenido del premio. `children: .ignore` la
        // colapsa en UN elemento (patrón de `DailyRewardView.prizeCard`); los
        // dos botones viven afuera, en `controls`.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("chest.card")
        .accessibilityLabel(Text(prizeName))
        .accessibilityValue(cardValue)
    }

    /// La rareza, para VoiceOver. Se canta sólo con una pinta (como el sello): es
    /// la etiqueta de la pinta, no del monto de plata.
    private var cardValue: Text {
        guard case .skin = reward.outcome else { return Text(verbatim: "") }
        return Text(ChestRarityStyle.nameKey(rarity))
    }

    /// El retrato del premio, por el mismo camino que lo dibuja el tablero. Con
    /// plata, la moneda gigante en su lugar.
    @ViewBuilder private var prizeArt: some View {
        switch reward.outcome {
        case let .skin(id, characterType, _):
            skinPortrait(skinID: id, typeID: characterType)
        case .coins:
            RewardArt(kind: .coins).padding(Tokens.s8)
        }
    }

    private var isSkinPrize: Bool {
        if case .skin = reward.outcome { return true }
        return false
    }

    private var rarityColor: Color { ChestCardStyle.glow(rarity) }

    /// Mismo criterio de fallback que la ficha y el tablero: si el arte de la
    /// pinta todavía no existe, se muestra el base en vez de un hueco roto.
    @ViewBuilder private func skinPortrait(skinID: String, typeID: String) -> some View {
        let treatment = SkinResolver.treatment(
            for: skinID,
            characterType: typeID,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
        if let image = portraitImage(typeID: typeID, treatment: treatment) {
            image
                .resizable()
                .scaledToFit()
                .padding(Tokens.s4)
                .colorMultiply(SkinResolver.swiftUITint(for: treatment) ?? .white)
        } else {
            Text(verbatim: "?")
                .font(Tokens.display)
                .foregroundStyle(Color("PaletteInk").opacity(0.6))
        }
    }

    private func portraitImage(typeID: String, treatment: SkinResolver.Treatment) -> Image? {
        guard let asset = gameState.content?.manifest.characters[typeID] else { return nil }
        if case let .texture(key) = treatment,
           let skinImage = UIArt.characterImage(atlas: asset.atlas, key: key) {
            return skinImage
        }
        return UIArt.characterImage(atlas: asset.atlas, key: asset.key)
    }

    // MARK: Los latidos

    /// El latido que está corriendo. Avanza **por completion y por tap**, nunca
    /// por `delay` encadenado: cada auto-avance es un `Task.sleep` cancelable que
    /// el `.task(id:)` mata solo cuando el jugador toca antes.
    private enum Beat: Int, Comparable {
        case arriving, waiting, forced1, forced2, cinematic, resting

        static func < (lhs: Beat, rhs: Beat) -> Bool { lhs.rawValue < rhs.rawValue }

        var next: Beat { Beat(rawValue: rawValue + 1) ?? .resting }

        /// Los latidos que ESPERAN un toque. Son los que
        /// `--uitest-chest-manual` deja sin reloj.
        var awaitsTap: Bool {
            switch self {
            case .waiting, .forced1, .forced2: true
            case .arriving, .cinematic, .resting: false
            }
        }

        /// Segundos hasta el auto-avance. El cinemático no lleva reloj: lo
        /// termina su propia coreografía.
        var autoAdvance: Double? {
            switch self {
            case .arriving: 0.15
            case .waiting, .forced1, .forced2: 1.2
            case .cinematic, .resting: nil
            }
        }
    }

    /// A dónde lleva el dedo. Tocar durante la llegada fuerza el candado igual
    /// en vez de gastar un toque: tres toques y el clip hace el resto. La
    /// apertura no se saltea — es el espectáculo.
    private var beatForTap: Beat? {
        switch beat {
        case .arriving, .waiting: .forced1
        case .forced1: .forced2
        case .forced2: .cinematic
        case .cinematic, .resting: nil
        }
    }

    private func tap() {
        // Con Reduce Motion **un solo toque** lleva al estado FINAL: el premio
        // con su fundido, sin sacudidas ni video.
        guard let target = reduceMotion ? .resting : beatForTap else { return }
        enter(target)
    }

    private func enter(_ target: Beat) {
        guard target != beat else { return }
        Log.assets.info("chest beat: \(String(describing: beat)) -> \(String(describing: target))")
        // Cualquier camino que salte al reposo —Reduce Motion, el auto-avance—
        // tiene que dejar el estado final entero armado.
        if target == .resting {
            entered = true
        }
        beat = target
    }

    private func advance() {
        enter(reduceMotion ? .resting : beat.next)
    }

    /// La coreografía de un latido: su háptico, su sonido y su auto-avance.
    private func choreograph(_ beat: Beat) async {
        switch beat {
        case .arriving:
            arm()
            guard await arrive() else { return }
        case .waiting:
            breathing = !reduceMotion
        case .forced1:
            knock(1)
        case .forced2:
            knock(2)
        case .cinematic:
            knock(3)
            await open()
            return
        case .resting:
            rest()
            return
        }
        guard let delay = autoAdvanceDelay(after: beat) else { return }
        guard await pause(delay) else { return }
        advance()
    }

    /// El mazo de clips y el retrato del premio, los dos en la llegada: latidos
    /// enteros de margen antes de que se vean.
    private func arm() {
        if deck == nil {
            let plays = ChestMotion.playsClips(policy: VideoPlayerPool.shared.policy, reduceMotion: reduceMotion)
            deck = ChestClipDeck(animates: plays)
            deck?.start()
        }
        // ⚠️ El retrato se precalienta ACÁ, latidos antes de que se vea,
        // y EN BACKGROUND: la PRIMERA lectura del personaje premiado
        // cuesta 320–470 ms (la página del atlas), contra 0,1 ms cacheada.
        // Hacerla en línea en este mismo latido congelaba el resorte de
        // entrada: la "traba al principio" que reportó el dueño.
        warmPrizeArt()
    }

    /// La caída: el cofre baja con aceleración, pega contra el piso (golpe,
    /// polvo, aplastón) y rebota. Con Reduce Motion, un fundido.
    private func arrive() async -> Bool {
        await deck?.waitForClosedStill(timeout: 0.8)
        guard !Task.isCancelled else { return false }
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.3)) { entered = true }
            return true
        }
        withAnimation(.easeIn(duration: Self.dropSeconds)) { entered = true }
        guard await pause(Self.dropSeconds) else { return false }
        landKick += 1
        emit(ChestFX.dust(at: CGPoint(x: 0, y: ChestStage.closedFloorY), budget: budget))
        gameState.audio?.play(.chestLand)
        play(.merge)
        return await pause(0.3)
    }

    /// Un toque al candado: cada uno más fuerte que el anterior (1-2-3) en la
    /// pose, el temblor, las chispas, la luz, el sonido y el háptico.
    private func knock(_ count: Int) {
        // Un dedo apurado que toca durante la caída la corta: el cofre llega ya.
        if !entered {
            withAnimation(.spring(duration: 0.3, bounce: 0.3)) { entered = true }
        }
        breathing = false
        taps = count
        guard !reduceMotion else { return }
        poseKick += 1
        quakeKick += 1
        ringKick += 1
        emit(ChestFX.tapSparks(tap: count, at: CGPoint(x: 0, y: ChestStage.lockY), budget: budget))
        gameState.audio?.play(.chestKnock, rate: 1 + 0.12 * Float(count - 1))
        switch count {
        case 1:
            deck?.playShake()
            gameState.audio?.play(.chestShakeA)
            play(.merge)                       // un golpe
        case 2:
            deck?.playShake()
            gameState.audio?.play(.chestShakeA, rate: 1.1)
            play(.purchase)                    // dos golpes
        default:
            gameState.audio?.play(.chestShakeB)
            play(.mergeAllFinale)              // tres, crecientes
        }
    }

    /// La apertura: corre `cofre_abre` y la cámara se aleja; cuando la tapa
    /// revienta (`burstDelay`, el cuadro de los rayos del clip), el fogonazo,
    /// los rayos y las estrellas de la rareza, y la figurita sale volando de la
    /// boca del cofre hasta su lugar. Asentada, suena la fanfarria de su rareza.
    private func open() async {
        let started = ContinuousClock.now
        deck?.playOpen()
        withAnimation(.spring(duration: 0.6, bounce: 0.18)) { opened = true }
        if let deck, deck.animates {
            await deck.waitForOpenFrame(ChestClipDeck.openBurstFrame, timeout: ChestClipDeck.burstDelay + 0.9)
            guard !Task.isCancelled else { return }
        } else {
            guard await pause(ChestClipDeck.burstDelay) else { return }
        }

        Log.assets.info("chest burst a \(String(describing: ContinuousClock.now - started)) del tercer toque")
        flash = 0.7
        withAnimation(.easeOut(duration: 0.55)) { flash = 0 }
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { burst = true }
        burstRingKick += 1
        quakeKick += 1
        emit(ChestFX.burst(rarity: rarity, at: CGPoint(x: 0, y: ChestStage.mouthY), budget: budget))
        gameState.audio?.play(.chestBurst)
        play(.evolution)                       // el más grande del juego
        withAnimation(.spring(duration: Self.flightSeconds, bounce: 0.38)) {
            contentRevealed = true
        }
        gameState.audio?.play(.revealWhoosh)

        guard await pause(Self.flightSeconds) else { return }
        playFanfare()
        play(.rarity)
        withAnimation(.easeOut(duration: 0.8)) { raysFaded = true }

        guard await pause(Self.settleSeconds) else { return }
        advance()
    }

    /// El estado final: el cofre abierto, el premio arriba y los botones. Por
    /// acá entra también Reduce Motion (un toque) con fundidos.
    private func rest() {
        breathing = false
        if reduceMotion {
            opened = true
            withAnimation(.easeOut(duration: 0.3)) { contentRevealed = true }
            playFanfare()
            return
        }
        // El auto-avance o un salto directo: lo que la apertura no llegó a armar.
        if !contentRevealed {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                opened = true
                contentRevealed = true
            }
        }
        withAnimation(.easeOut(duration: 0.4)) { raysFaded = true }
    }

    private func playFanfare() {
        switch rarity {
        case .comun: gameState.audio?.play(.chestFanfareComun)
        case .rara: gameState.audio?.play(.chestFanfareRara)
        case .epica: gameState.audio?.play(.chestFanfareEpica)
        case .legendaria: gameState.audio?.play(.chestFanfareLegendaria)
        }
        if case .coins = reward.outcome {
            gameState.audio?.play(.coin)
        }
    }

    /// Suma una tanda de partículas y la retira cuando ya se apagó: el reloj del
    /// `Canvas` se detiene sin emisiones vivas.
    private func emit(_ particles: [ChestParticle]) {
        guard !reduceMotion, !particles.isEmpty else { return }
        let emission = ChestEmission(start: .now, particles: particles)
        emissions.append(emission)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(ChestFX.maxLifetime))
            emissions.removeAll { $0.id == emission.id }
        }
    }

    /// Cuánto espera este latido antes de dispararse solo, o `nil` si no se
    /// dispara nunca.
    ///
    /// La puerta de test manda PRIMERO. Preguntando por Reduce Motion antes, un
    /// simulador con Reduce Motion prendido ignoraba `--uitest-chest-manual` en
    /// silencio: el smoke se ponía rojo igual, pero por accidente y no porque
    /// hubiera detectado nada.
    ///
    /// Con Reduce Motion **todo** cae al mismo 1,2 s porque todo lleva al mismo
    /// lugar: el reposo.
    private func autoAdvanceDelay(after beat: Beat) -> Double? {
        if Self.waitsForTapsOnly, beat.awaitsTap { return nil }
        if reduceMotion { return beat == .resting ? nil : 1.2 }
        return beat.autoAdvance
    }

    /// Espera. Devuelve `false` si el jugador tocó mientras tanto — el cambio de
    /// latido cancela la tarea del `.task(id:)` y con ella este sleep.
    private func pause(_ seconds: Double) async -> Bool {
        guard seconds > 0 else { return !Task.isCancelled }
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    /// Precalienta el retrato del premio en background, para que
    /// `UIArt.characterImage` lo sirva de caché cuando el marco lo pida.
    ///
    /// Calienta las DOS candidatas que `portraitImage` puede terminar
    /// mostrando —la textura de la pinta y la base del tipo— porque si la
    /// pinta no tiene arte todavía, el marco cae a la base, y una base fría
    /// sería la misma lectura de cientos de ms pero en medio del video.
    ///
    /// Con plata no hay nada que precalentar: `CoinIcon` sale del atlas `ui`, que
    /// el HUD ya dejó caliente antes de que el cofre existiera.
    private func warmPrizeArt() {
        guard case let .skin(id, characterType, _) = reward.outcome,
              let asset = gameState.content?.manifest.characters[characterType]
        else { return }
        let treatment = SkinResolver.treatment(
            for: id,
            characterType: characterType,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
        if case let .texture(key) = treatment {
            UIArt.warmCharacterImage(atlas: asset.atlas, key: key)
        }
        UIArt.warmCharacterImage(atlas: asset.atlas, key: asset.key)
    }

    private func play(_ pattern: HapticsManager.Pattern) {
        gameState.playHaptic(pattern)
    }
    // MARK: Los dos botones

    @ViewBuilder private var controls: some View {
        switch reward.outcome {
        case let .skin(id, characterType, _):
            VStack(spacing: Tokens.s4) {
                // Ponérsela desde acá: el premio se gana en medio del loop y
                // mandarlo a buscar la ficha para usarlo es fricción de más
                // (mismo criterio que `SkinAwardView`).
                GameButton("chest.equip", role: .free, medallion: .none, identifier: "chest.equip") {
                    guard !extraChestBusy else { return }
                    gameState.equipSkin(id: id, forCharacterType: characterType)
                    gameState.dismissChestReward()
                }
                anotherChestOffer
                laterButton(titleKey: "chest.dismiss")
            }
        case .coins:
            // Con plata no hay nada que ponerse: queda UN botón, y por eso va en
            // cápsula y no en el estilo mudo del "después". El mudo existe para
            // no competir con un premio al lado; solo, es el premio, y como texto
            // pelado quedaba flotando sobre el callejón (visto en el simulador).
            //
            // Conserva el identifier `chest.dismiss`: cerrar es siempre el mismo
            // control, cambie el premio que cambie.
            VStack(spacing: Tokens.s4) {
                GameButton("chest.coins.ok", role: .free, identifier: "chest.dismiss") {
                    guard !extraChestBusy else { return }
                    gameState.dismissChestReward()
                }
                anotherChestOffer
            }
        }
    }

    /// **La oferta del cofre extra**, en el momento de más dopamina del juego:
    /// el jugador acaba de ver qué le tocó y la pregunta "¿y si abro otro?" ya
    /// está hecha sola.
    ///
    /// ⚠️ El orden de las dos llamadas al cobrar **no es intercambiable**:
    /// `dismissChestReward()` va PRIMERO porque `openChest()` se autoprotege con
    /// `guard chestReward == nil` (un cofre por vez). Al revés, el cofre nuevo se
    /// descarta en silencio, el jugador miró un anuncio y no recibe nada — y el
    /// contador de pendientes se lo queda.
    @ViewBuilder private var anotherChestOffer: some View {
        if offersExtraChest {
            RewardedOfferButton(
                title: String(localized: "ads.offer.chest.again"),
                identifier: "chest.again.ad",
                placement: .chestExtra,
                isBusy: $extraChestBusy,
                gameRole: .video
            ) {
                gameState.dismissChestReward()
                gameState.grantExtraChestFromAd()
            }
        }
    }

    /// El botón que no hace nada más que cerrar va mudo, como el "ahora no" del
    /// premio de skin y el cancelar del prestigio: al lado del premio, el botón
    /// que no hace nada no compite.
    private func laterButton(titleKey: LocalizedStringKey) -> some View {
        Button {
            guard !extraChestBusy else { return }
            gameState.dismissChestReward()
        } label: {
            Text(titleKey)
                .font(Tokens.body)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.vertical, Tokens.s8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chest.dismiss")
    }

    // MARK: El premio, en palabras

    private var rarity: SkinsConfig.Rarity {
        switch reward.outcome {
        case let .skin(_, _, rarity): rarity
        case let .coins(rarity): rarity
        }
    }

    private var prizeName: String {
        switch reward.outcome {
        case let .skin(id, _, _):
            guard let entry = gameState.content?.skins.entry(id: id) else { return id }
            return gameState.skinDisplayName(for: entry)
        case .coins:
            return CoinFormatter.string(from: reward.coins ?? 0)
        }
    }

    private var subtitle: String {
        switch reward.outcome {
        case let .skin(_, characterType, _):
            let name = gameState.content?.tiers.type(id: characterType)?.localizedName ?? characterType
            return String(localized: "chest.skin.subtitle \(name)")
        case .coins:
            return String(localized: "chest.coins.subtitle")
        }
    }
}
