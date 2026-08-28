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
}

/// Abrir un cofre: **el video del animador, entero**, con los tres toques del
/// candado por delante.
///
/// Pedido del dueño (2026-08-28, segunda ronda): la animación ES el video —
/// murieron los rayos, las ráfagas, el flash y la carta de la casa que
/// acompañaban a los frames — y el contenido del premio se renderiza al final
/// **dentro del marco vacío de la carta del video**. Cuarta ronda, mismo día
/// (el master definitivo): video **2D vertical con la estética del juego y
/// CON SONIDO** — la pista del cinemático viaja dentro del mov y las
/// sacudidas suenan como clips SFX junto a sus frames. El cofre se desvanece
/// solo después de soltar la carta, y la carta del video ya hace su propio
/// push-in, así que el zoom de la casa murió con esta ronda. Lo que queda de
/// coreografía propia: los tres toques que fuerzan el candado (cada uno con
/// su sacudida, su sonido y su háptico, con auto-avance de 1,2 s para el que
/// no toca) y el escenario a sangre completa: el lienzo vertical cubre la
/// pantalla de lado a lado y hasta arriba.
///
/// El reparto de formatos es medido, no estético: los latidos que responden
/// al dedo reproducen frames PNG (`ChestAnimationFeed`, swap en el mismo
/// cuadro), y del estallido al marco corre `chest_open.mov` (HEVC con alfa,
/// hardware, 8 s lineales que en frames pesarían 4×). La geometría de los dos
/// mundos sale del mismo manifest y comparten el ancla del cofre, así que el
/// empalme es invisible.
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

    let reward: GameState.ChestReward

    @State private var beat: Beat = .arriving
    /// La entrada del escenario (fade + escala). Se prende en el `.task` del
    /// primer latido — que corre DESPUÉS del armado del overlay, así que el
    /// resorte no se pierde detrás del bloqueo de montaje (la lección de la
    /// caída del cofre, ronda 4 del cierre de cofres).
    @State private var entered = false
    @State private var breathing = false
    /// El contenido del premio dentro del marco, con su fade del reposo.
    @State private var contentRevealed = false
    /// Los frames PNG de respaldo, retirados. En este video **el cofre se
    /// desvanece a mitad del tramo cinemático** (~f114): el PNG quieto que
    /// tapa el arranque del decoder tiene que salir de escena apenas el video
    /// rinde, o el cofre "desaparecido" seguiría asomando por detrás. Lo mismo
    /// con el still de Reduce Motion, que ya no trae cofre.
    @State private var stageRetired = false
    /// Los frames interactivos (idle y sacudidas) y su playhead.
    @State private var feed = ChestAnimationFeed(animation: ChestAnimation.shared)
    /// El tramo cinemático. Nace en la llegada (preroll con latidos de
    /// margen) y sólo si no hay Reduce Motion.
    @State private var cinematic: ChestCinematicPlayer?
    /// El estado final para Reduce Motion o si el video no está.
    @State private var cardStill: UIImage?

    /// Apaga el auto-avance de los latidos que esperan un toque, para que la
    /// animación avance **sólo con el dedo** — y acelera el tramo cinemático,
    /// que no espera a nadie pero a 1× le sumaría 8 s a cada smoke.
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

    /// El cofre a 274 pt hace que el lienzo vertical del video (720×1280,
    /// cofre de 448 px) cubra la pantalla completa a lo ancho —Pro Max
    /// incluido— y hasta arriba; sólo queda un tramo de adoquines abajo,
    /// donde los destellos son ralos y el feather del borde no se nota.
    private static let chestSide: CGFloat = 274
    /// El centro del cofre, en puntos desde el centro de la pantalla.
    private static let chestY: CGFloat = -20
    /// Los botones, debajo del marco final de la carta (~98 pt de aire
    /// medidos; a 178 el primero rozaba el marco dorado del master viejo).
    private static let controlsY: CGFloat = 212
    /// Cuánto video corrido hace falta para jubilar el PNG de respaldo: a los
    /// 0,6 s el decoder lleva ~14 frames rendidos y el cofre del video sigue
    /// opaco ~1,5 s más (empieza a fundirse a los 2,1 s del tramo) — margen
    /// en las dos puntas.
    private static let stageHandoffSeconds = 0.6
    /// El flip de la carta va en ~f192–f200 del video (6,1 s del tramo): su
    /// háptico se dispara por reloj —apenas antes del giro—, no por observer
    /// del player.
    private static let flipSecondsIntoCinematic = 6.0
    /// Cuándo entran los DATOS del premio: la cara vacía ya está derecha a
    /// los 6,5 s (f206) y del video sólo queda la cola de destellos.
    /// Esperar el final dejaba ~1,5 s de marco vacío mirándote (pedido del
    /// dueño: que los datos tarden menos en aparecer).
    private static let revealSecondsIntoCinematic = 6.5
    /// El video dura 7,92 s (190 frames); el tope del await es el seguro
    /// contra un decoder trabado, porque este latido no lo avanza nadie más.
    private static let cinematicSeconds = 190.0 / 24.0
    private static let portraitSide: CGFloat = 96
    private static let plateShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        // Un `ZStack` pelado y offsets en PUNTOS desde el centro, no un
        // `GeometryReader` con fracciones: adentro del `ZStack` de `RootView` el
        // lector NO mide la pantalla —mide lo que le proponen— y el layout
        // terminaba a media altura. Centrado + offsets no depende de qué le
        // propongan.
        ZStack {
            // El telón al 55 %: el HUD ya está apagado por la cola
            // (`celebrationHidesUI`), esto apaga el tablero.
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // El foco de la casa: oscurece el callejón hacia los bordes
            // mientras corre el espectáculo. El video vigente es un sprite
            // puro (verde plano, sin viñeta horneada), así que este scrim ya
            // no continúa nada — es la única viñeta, toda nuestra, y por eso
            // no puede tener costura. Aparece con el video y se queda.
            RadialGradient(
                colors: [.clear, .black.opacity(0.32)],
                center: .center,
                startRadius: 150,
                endRadius: 430
            )
            .offset(y: Self.chestY)
            .ignoresSafeArea()
            .opacity(beat >= .cinematic ? 1 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: beat >= .cinematic)
            .allowsHitTesting(false)

            stageCanvas
                .scaleEffect(breathing ? 1.04 : 1)
                .animation(
                    // El respiro de la espera es un `repeatForever` **atado a
                    // la bandera**: al apagarse, el mismo modificador pasa a
                    // ser un resorte común (la forma de `TapHereHand`).
                    breathing
                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        : .spring(duration: 0.28),
                    value: breathing
                )
                .scaleEffect(entered ? 1 : 0.9)
                .opacity(entered ? 1 : 0)
                .offset(y: Self.chestY)
                .accessibilityHidden(true)

            if contentRevealed {
                cardContent
            }

            if beat == .resting {
                controls
                    .frame(maxWidth: 250)
                    .offset(y: Self.controlsY)
            }

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
        }
        .ignoresSafeArea()
        // Sin esto VoiceOver se va al HUD apagado que quedó debajo.
        .accessibilityAddTraits(.isModal)
        .task(id: beat) { await choreograph(beat) }
    }

    // MARK: El escenario

    /// El lienzo del video, fijo al encuadre cinemático para que el layout no
    /// salte al cambiar de formato: los frames interactivos, el video y el
    /// still comparten el ancla del cofre, así que se apilan y se empalman
    /// sin moverse.
    @ViewBuilder private var stageCanvas: some View {
        if let animation = feed.animation {
            let stage = animation.cinematicStage(chestWidth: Self.chestSide)
            ZStack {
                // Los frames del dedo. Quedan montados debajo del video —el
                // primer cuadro del cinemático es el mismo cofre quieto, y el
                // PNG de atrás tapa cualquier hueco del arranque del decoder—
                // pero SOLO hasta que el video rinde: el cofre del video se
                // desvanece a mitad del tramo, y el PNG quieto lo resucitaría.
                if !stageRetired {
                    ChestStage(feed: feed, chestWidth: Self.chestSide)
                }

                if beat >= .cinematic {
                    if let cinematic {
                        ChestCinematicView(player: cinematic.player)
                            .frame(width: stage.size.width, height: stage.size.height)
                            .offset(stage.offset)
                    } else if let cardStill {
                        // Reduce Motion (o un video ausente): el estado final,
                        // quieto — el marco vacío listo para el contenido.
                        Image(uiImage: cardStill)
                            .resizable()
                            .frame(width: stage.size.width, height: stage.size.height)
                            .offset(stage.offset)
                    }
                }
            }
            .frame(width: stage.size.width, height: stage.size.height)
        } else if let image = UIArt.image("ui_chest_closed") {
            // Sin manifest (bundle roto): el cofre estático de siempre, feo
            // pero funcional — `ChestAnimationTests` pina que no pasa.
            image
                .resizable()
                .scaledToFit()
                .frame(width: Self.chestSide, height: Self.chestSide)
        }
    }

    // MARK: El contenido del marco

    /// El premio, renderizado dentro del pergamino vacío de la carta del
    /// video, en el tamaño y el punto que dicta el manifest. Vive como capa
    /// hermana del escenario —no adentro— para que ninguna transformación del
    /// arte (el respiro, la entrada) rasterice el texto.
    private var cardContent: some View {
        let animation = feed.animation
        let parch = animation?.parchmentStage(chestWidth: Self.chestSide)
        let size = CGSize(
            width: parch?.size.width ?? 214,
            height: parch?.size.height ?? 308
        )
        let offset = CGSize(
            width: parch?.offset.width ?? 0,
            height: (parch?.offset.height ?? -62) + Self.chestY
        )
        return VStack(spacing: Tokens.s8) {
            prizeArt
            if case .skin = reward.outcome {
                rarityRibbon
            }
            Text(prizeName)
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                // Envolver, nunca truncar: el nombre sale del catálogo y un
                // nombre cortado no nombra a nadie.
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.s8)
        .frame(width: size.width, height: size.height)
        .offset(offset)
        // La aparición la anima el `withAnimation` que prende
        // `contentRevealed` en el reposo; con Reduce Motion entra seca.
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        // La parada de AX es el contenido del premio. `children: .ignore` la
        // colapsa en UN elemento (patrón de `DailyRewardView.prizeCard`); los
        // dos botones viven afuera, en `controls`.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("chest.card")
        .accessibilityLabel(Text(prizeName))
        .accessibilityValue(cardValue)
    }

    /// La rareza, para VoiceOver. Se canta por la misma regla que la cinta: es
    /// la etiqueta de la pinta, no del monto de plata.
    private var cardValue: Text {
        guard case .skin = reward.outcome else { return Text(verbatim: "") }
        return Text(ChestRarityStyle.nameKey(rarity))
    }

    /// El retrato del premio, por el mismo camino que lo dibuja el tablero. Con
    /// plata, la moneda gigante en su lugar.
    @ViewBuilder private var prizeArt: some View {
        Group {
            switch reward.outcome {
            case let .skin(id, characterType, _):
                skinPortrait(skinID: id, typeID: characterType)
            case .coins:
                CoinIcon(size: Self.portraitSide * 0.8)
            }
        }
        .frame(width: Self.portraitSide, height: Self.portraitSide)
        .background(Color("PaletteYellow").opacity(0.3))
        .clipShape(Self.plateShape)
        .overlay(Self.plateShape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
        .accessibilityHidden(true)
    }

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
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(20)
                .foregroundStyle(Color("PaletteInk"))
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

    private var rarityRibbon: some View {
        Text(ChestRarityStyle.nameKey(rarity))
            .font(Tokens.caption)
            .foregroundStyle(Color("PaletteInk"))
            .padding(.horizontal, Tokens.s12)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(ChestRarityStyle.color(rarity))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk").opacity(0.85), lineWidth: 2))
            }
    }

    // MARK: Los latidos

    /// El latido que está corriendo. Avanza **por completion y por tap**, nunca
    /// por `delay` encadenado: cada auto-avance es un `Task.sleep` cancelable que
    /// el `.task(id:)` mata solo cuando el jugador toca antes.
    private enum Beat: Int, Comparable {
        case arriving, waiting, forced1, forced2, forced3, cinematic, resting

        static func < (lhs: Beat, rhs: Beat) -> Bool { lhs.rawValue < rhs.rawValue }

        var next: Beat { Beat(rawValue: rawValue + 1) ?? .resting }

        /// Los tres latidos que ESPERAN un toque. Son los que
        /// `--uitest-chest-manual` deja sin reloj.
        var awaitsTap: Bool {
            switch self {
            case .waiting, .forced1, .forced2: true
            case .arriving, .forced3, .cinematic, .resting: false
            }
        }

        /// Segundos hasta el auto-avance. El cinemático no lleva reloj: lo
        /// termina el propio video (con tope, en su coreografía). El tercer
        /// forzado dura lo que su temblor (11 frames, 0,46 s): el video
        /// arranca justo donde ese segmento termina.
        var autoAdvance: Double? {
            switch self {
            case .arriving: 0.25
            case .waiting, .forced1, .forced2: 1.2
            case .forced3: 0.5
            case .cinematic, .resting: nil
            }
        }
    }

    /// A dónde lleva el dedo. Tocar durante la llegada fuerza el candado igual
    /// en vez de gastar un toque: tres toques y el video hace el resto. El
    /// tramo cinemático no se saltea — es el espectáculo que el dueño pidió
    /// entero.
    private var beatForTap: Beat? {
        switch beat {
        case .arriving, .waiting: .forced1
        case .forced1: .forced2
        case .forced2: .forced3
        case .forced3, .cinematic, .resting: nil
        }
    }

    private func tap() {
        // Con Reduce Motion **un solo toque** lleva al estado FINAL: el marco
        // con su contenido, sin sacudidas ni video.
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

    /// La coreografía de un latido: su háptico, su tramo de video y su
    /// auto-avance. Con Reduce Motion el feed nunca REPRODUCE y el video ni se
    /// crea: cada latido muestra su estado final quieto.
    private func choreograph(_ beat: Beat) async {
        switch beat {
        case .arriving:
            feed.show(.idle)
            if !reduceMotion, cinematic == nil, let animation = feed.animation {
                // El player nace acá, latidos antes de reproducir: el preroll
                // del decoder se paga en el hueco muerto de los toques.
                cinematic = ChestCinematicPlayer(url: animation.cinematicURL)
            }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.3)) {
                entered = true
            }
            play(.merge)
            // ⚠️ El retrato se carga ACÁ, latidos antes de que se vea: la
            // PRIMERA lectura del personaje premiado cuesta ~320 ms de hilo
            // principal (la página del atlas + `cgImage()`), contra 0,1 ms
            // cacheada. La llegada es el lugar barato: el overlay se está
            // construyendo igual.
            warmPrizeArt()
            feed.warm(.shakeA)
            feed.warm(.shakeB)
        case .waiting:
            breathing = !reduceMotion
        case .forced1:
            breathing = false
            if !reduceMotion { feed.play(.shakeA) }
            gameState.audio?.play(.chestShakeA)
            play(.merge)                       // un golpe
        case .forced2:
            // La segunda sacudida repite la primera: la B de este master es
            // el temblor final que desemboca en el estallido, y ésa es del
            // tercer toque.
            if !reduceMotion { feed.play(.shakeA) }
            gameState.audio?.play(.chestShakeA)
            play(.purchase)                    // dos golpes
        case .forced3:
            // El temblor agachado: termina en f49 y el video arranca en f50 —
            // el tercer toque desemboca en el estallido sin costura.
            if !reduceMotion { feed.play(.shakeB) }
            gameState.audio?.play(.chestShakeB)
            play(.rarity)                      // tres que suben
        case .cinematic:
            play(.evolution)                   // el más grande del juego
            guard !reduceMotion, let cinematic else {
                await showFinalStill()
                advance()
                return
            }
            let rate: Float = Self.waitsForTapsOnly ? 4 : 1
            cinematic.play(rate: rate, volume: Float(gameState.audio?.sfxVolume ?? 1))
            // El PNG de respaldo se jubila con el video ya rindiendo, mucho
            // antes de que el cofre del video empiece a desvanecerse.
            guard await pause(Self.stageHandoffSeconds / Double(rate)) else { return }
            stageRetired = true
            // El flip de la carta en el video: su háptico, por reloj.
            let untilFlip = Self.flipSecondsIntoCinematic - Self.stageHandoffSeconds
            if await pause(untilFlip / Double(rate)) {
                play(.rarity)
            } else {
                return
            }
            // Los datos, con el video todavía corriendo su cola de destellos.
            let untilReveal = Self.revealSecondsIntoCinematic - Self.flipSecondsIntoCinematic
            guard await pause(untilReveal / Double(rate)) else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.25)) {
                contentRevealed = true
            }
            let remaining = (Self.cinematicSeconds - Self.revealSecondsIntoCinematic) / Double(rate)
            await cinematic.awaitEnd(timeout: remaining + 2.0)
            advance()
            return
        case .resting:
            // Idempotente en el camino del video (ya se jubiló durante el
            // cinemático); imprescindible en los caminos sin video, donde el
            // still que entra ya no trae cofre.
            stageRetired = true
            if reduceMotion || cinematic == nil {
                await showFinalStill()
            }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.25)) {
                contentRevealed = true
            }
            return
        }
        guard let delay = autoAdvanceDelay(after: beat) else { return }
        guard await pause(delay) else { return }
        advance()
    }

    /// El estado final sin video: decodifica el still del marco (una vez) y
    /// lo deja puesto.
    private func showFinalStill() async {
        guard cardStill == nil, let animation = feed.animation else { return }
        let url = animation.cardStillURL
        let image = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: url.path)?.preparingForDisplay()
        }.value
        cardStill = image
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
    /// lugar: el reposo. Los latidos que no esperan un toque conservan su reloj
    /// bajo la puerta de test — al cinemático no lo avanza nadie más que su
    /// propio video, y la llegada es la que lleva al reposo con Reduce Motion.
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

    /// Fuerza la primera lectura del retrato del premio, para que
    /// `UIArt.characterImage` la sirva de caché cuando el marco lo pida.
    ///
    /// Con plata no hay nada que precalentar: `CoinIcon` sale del atlas `ui`, que
    /// el HUD ya dejó caliente antes de que el cofre existiera.
    private func warmPrizeArt() {
        guard case let .skin(id, characterType, _) = reward.outcome else { return }
        let treatment = SkinResolver.treatment(
            for: id,
            characterType: characterType,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
        _ = portraitImage(typeID: characterType, treatment: treatment)
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
                ActionPill(
                    titleKey: "chest.equip",
                    systemImage: "tshirt.fill",
                    identifier: "chest.equip"
                ) {
                    gameState.equipSkin(id: id, forCharacterType: characterType)
                    gameState.dismissChestReward()
                }
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
            ActionPill(
                titleKey: "chest.coins.ok",
                systemImage: "checkmark",
                tint: Color("PaletteGreen"),
                identifier: "chest.dismiss"
            ) {
                gameState.dismissChestReward()
            }
        }
    }

    /// El botón que no hace nada más que cerrar va mudo, como el "ahora no" del
    /// premio de skin y el cancelar del prestigio: al lado del premio, el botón
    /// que no hace nada no compite.
    private func laterButton(titleKey: LocalizedStringKey) -> some View {
        Button {
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

// MARK: - El escenario de frames

/// El escenario de los latidos interactivos: el frame vigente del feed,
/// dibujado con el cofre anclado al centro del contenedor.
///
/// El reloj es el del `TimelineView`, que muere solo: `paused` se prende cuando
/// el playhead mostró el último frame, así que fuera de una reproducción no hay
/// display link vivo (la regla del design system). El índice sale de la FECHA,
/// no de contar ticks — un cuadro que el hilo se comió se saltea sin deriva.
///
/// La `transaction` sin animación es deliberada: al cambiar de segmento el
/// escenario SALTA de tamaño (la sacudida B recorta más lienzo que la A) y
/// cualquier animación implícita heredada —el respiro— lo convertiría en un
/// morph. Los frames de un video se cambian secos, siempre.
private struct ChestStage: View {
    let feed: ChestAnimationFeed
    let chestWidth: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: feed.isPaused)) { timeline in
            stage
                .onChange(of: timeline.date) { _, date in
                    feed.advance(to: date)
                }
        }
    }

    @ViewBuilder private var stage: some View {
        if let animation = feed.animation, let image = feed.displayed {
            let layout = animation.stage(feed.segment, chestWidth: chestWidth)
            Image(uiImage: image)
                .resizable()
                .frame(width: layout.size.width, height: layout.size.height)
                .offset(layout.offset)
                .transaction { $0.animation = nil }
        }
    }
}
