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


/// La geometría del escenario del cofre: los clips (`cofre_espera`,
/// `cofre_sacude`, `cofre_abre`, 512 px de lado) en puntos, y dónde sale el
/// premio. Medida sobre los cuadros: el cofre cerrado ocupa ~310×230 px
/// centrado en el cuadro, y abierto la tapa sube hasta ~y 45 — por eso el
/// premio vive ARRIBA del cofre y no adentro (D14: cero superposición).
enum ChestStage {
    static let clipSide: CGFloat = 280
    static var scale: CGFloat { clipSide / 512 }
    /// El cofre cerrado en el cuadro del clip (px).
    static let closedChest = CGRect(x: 100, y: 140, width: 310, height: 230)
    /// La parte alta de la tapa abierta (px del cuadro).
    static let openLidTop: CGFloat = 45
    /// El centro del cuadro, en puntos desde el centro de la pantalla.
    static let clipY: CGFloat = 50
    /// El centro del premio, en puntos desde el centro de la pantalla.
    static let prizeY: CGFloat = -190
    /// El alto que ocupa el bloque del premio (tarjeta con su nombre y el detalle).
    static let prizeHeight: CGFloat = 220

    /// Y (puntos desde el centro de la pantalla) de la punta de la tapa abierta.
    static var lidTopY: CGFloat { clipY + (openLidTop - 256) * scale }
    /// Y del borde de abajo del bloque del premio.
    static var prizeBottomY: CGFloat { prizeY + prizeHeight / 2 }
}

/// Qué clip corre en cada momento del cofre. Pura: la vista sólo la consulta.
enum ChestClip {
    static func id(opening: Bool, shaking: Bool) -> String {
        if opening { return "cofre_abre" }
        return shaking ? "cofre_sacude" : "cofre_espera"
    }
}

/// Abrir un cofre (E14 C4/C26): tres momentos con los clips de Higgsfield.
/// `cofre_espera` (loop) → cada toque dispara `cofre_sacude` (1.º y 2.º) → el
/// 3.º dispara `cofre_abre` → del brillo sale el premio, con rayos y pop, y
/// los botones. El premio lo dibuja el código encima del clip, ARRIBA del
/// cofre abierto (D14: cero superposición): nunca va en el video.
///
/// Los tres toques son del candado y siguen forzándolo (cada uno con su
/// háptico y su sonido, con auto-avance de 1,2 s para el que no toca).
/// Con Reduce Motion el cofre queda en su póster y un solo toque hace la
/// apertura con fundidos.
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
    /// La entrada del escenario (fade + escala). Se prende en el `.task` del
    /// primer latido — que corre DESPUÉS del armado del overlay, así que el
    /// resorte no se pierde detrás del bloqueo de montaje (la lección de la
    /// caída del cofre, ronda 4 del cierre de cofres).
    @State private var entered = false
    @State private var breathing = false
    /// El premio sobre el cofre, con su fade del reposo.
    @State private var contentRevealed = false
    /// La sacudida de un toque está corriendo (`cofre_sacude`).
    @State private var shaking = false
    /// Cada toque remonta el clip de la sacudida para que arranque de cero.
    @State private var shakeSerial = 0
    /// `cofre_abre` terminó (o la política lo dejó en póster).
    @State private var openingEnded = false

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

    /// El centro del cofre, en puntos desde el centro de la pantalla.
    private static let chestY = ChestStage.clipY
    /// Los botones, debajo del cofre.
    private static let controlsY: CGFloat = 212
    /// Cuándo sale el premio del brillo: a mitad de `cofre_abre` (73 cuadros a
    /// 24 fps), con la cola de destellos todavía corriendo.
    private static let revealSecondsIntoOpening = 1.4
    /// Tope de la espera del fin del clip: el latido que espera no lo avanza
    /// nadie más, y un decoder trabado dejaría la cola de celebraciones muda.
    private static let openingSeconds = 73.0 / 24.0

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

            // El foco de la casa: oscurece el callejón hacia los bordes. Entra
            // en el PRIMER TOQUE: el callejón se apaga cuando el cofre EMPIEZA a
            // moverse.
            RadialGradient(
                colors: [.clear, .black.opacity(0.32)],
                center: .center,
                startRadius: 150,
                endRadius: 430
            )
            .offset(y: Self.chestY)
            .ignoresSafeArea()
            .opacity(beat >= .forced1 ? 1 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: beat >= .forced1)
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
            } else if beat >= .waiting, beat < .cinematic {
                // Antes y durante (E14 C4): lo que hay que hacer, a la vista.
                Text("chest.tap.hint")
                    .font(Tokens.title)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 0, y: 2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 250)
                    .offset(y: Self.controlsY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
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
        .task {
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
    }

    // MARK: El escenario

    private var isOpening: Bool { beat >= .cinematic }

    private var playback: ArtPlayback {
        if isOpening { return .once { openingEnded = true } }
        guard shaking else { return .loop }
        let serial = shakeSerial
        return .once { if shakeSerial == serial { shaking = false } }
    }

    /// El clip del momento. Cuando la política lo deja en póster (Reduce Motion,
    /// tests) se ve el cofre cerrado quieto; con video, el póster no se pinta
    /// porque asomaría por los bordes del clip.
    private var stageCanvas: some View {
        AnimatedArtView(
            clip: .object(ChestClip.id(opening: isOpening, shaking: shaking)),
            role: .popup,
            playback: playback
        ) {
            poster
        }
        .id(shakeSerial)
        .frame(width: ChestStage.clipSide, height: ChestStage.clipSide)
    }

    @ViewBuilder private var poster: some View {
        let side = ChestStage.clipSide
        let chest = ChestStage.closedChest
        ZStack {
            if !VideoPlayerPool.shared.policy.allowsLoops, let image = UIArt.image("ui_chest_closed") {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: chest.width * ChestStage.scale, height: chest.height * ChestStage.scale)
                    .offset(
                        x: (chest.midX - 256) * ChestStage.scale,
                        y: (chest.midY - 256) * ChestStage.scale
                    )
            }
        }
        .frame(width: side, height: side)
    }

    // MARK: El premio

    /// El premio, sobre el cofre abierto: sale del brillo (crece desde abajo),
    /// en una tarjeta de figurita (`ChestPrizeCard`), con sus rayos y el pop. El detalle va en
    /// blanco sobre el telón. Vive como capa hermana del escenario para que
    /// ninguna transformación del arte (el respiro, la entrada) rasterice el
    /// texto.
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
        .offset(y: ChestStage.prizeY)
        // La aparición la anima el `withAnimation` que prende
        // `contentRevealed`; con Reduce Motion entra con un fundido.
        .transition(
            reduceMotion
                ? .opacity
                : .scale(scale: 0.4, anchor: .bottom).combined(with: .opacity)
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
        /// termina el propio clip (con tope, en su coreografía).
        var autoAdvance: Double? {
            switch self {
            case .arriving: 0.25
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

    private func shake() {
        shaking = !reduceMotion
        shakeSerial += 1
    }

    /// La coreografía de un latido: su háptico, su sonido y su auto-avance. Con
    /// Reduce Motion el cofre queda en su póster: cada latido muestra su estado
    /// final quieto.
    private func choreograph(_ beat: Beat) async {
        switch beat {
        case .arriving:
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.3)) {
                entered = true
            }
            play(.merge)
            // ⚠️ El retrato se precalienta ACÁ, latidos antes de que se vea,
            // y EN BACKGROUND: la PRIMERA lectura del personaje premiado
            // cuesta 320–470 ms (la página del atlas), contra 0,1 ms cacheada.
            // Hacerla en línea en este mismo latido congelaba el resorte de
            // entrada: la "traba al principio" que reportó el dueño.
            warmPrizeArt()
        case .waiting:
            breathing = !reduceMotion
        case .forced1:
            breathing = false
            shake()
            gameState.audio?.play(.chestShakeA)
            play(.merge)                       // un golpe
        case .forced2:
            shake()
            gameState.audio?.play(.chestShakeA)
            play(.purchase)                    // dos golpes
        case .cinematic:
            shaking = false
            gameState.audio?.play(.chestShakeB)
            play(.evolution)                   // el más grande del juego
            // El premio sale del brillo con el clip todavía corriendo.
            guard await wait(until: Self.revealSecondsIntoOpening, { openingEnded }) else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.25)) {
                contentRevealed = true
            }
            play(.rarity)
            _ = await wait(until: Self.openingSeconds + 2.0, { openingEnded })
            guard !Task.isCancelled else { return }
            advance()
            return
        case .resting:
            withAnimation(.easeOut(duration: reduceMotion ? 0.25 : 0.4)) {
                contentRevealed = true
            }
            return
        }
        guard let delay = autoAdvanceDelay(after: beat) else { return }
        guard await pause(delay) else { return }
        advance()
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

    /// Espera hasta `seconds` o a que se cumpla la condición, lo que pase
    /// primero. `false` sólo si la tarea fue cancelada.
    private func wait(until seconds: Double, _ done: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !done(), ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(40))
        }
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
