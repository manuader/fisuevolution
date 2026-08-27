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

/// Abrir un cofre: **cuatro toques del jugador**, no un video de 2,6 s.
///
/// Lo que engancha no es que sea larga, es que la maneja el jugador (pedido del
/// dueño: "es lo que más garpa del sistema de cofres", al estilo Clash Royale
/// pero con la estética de la casa). Tres toques fuerzan el candado y el cuarto
/// da vuelta la carta. Si el jugador no toca, cada latido se dispara solo a los
/// 1,2 s: nadie queda trabado, pero el que participa va más rápido.
///
/// **La rareza se anuncia ANTES que el premio.** En el segundo toque los rayos
/// de atrás se tiñen del color de la rareza, así que ver dorado antes de saber
/// qué salió es el mecanismo central de la anticipación. Por eso `.coins` lleva
/// la rareza SORTEADA y no una resuelta: con la colección completa el estallido
/// va a ser verde el ~55 % de las veces, y está bien — si el color delatara el
/// resultado, se perdería la sorpresa que es el punto de todo el sistema.
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
    /// Dispara la caída del latido 0. Nace en `false` y lo prende el `onAppear`
    /// del cofre: la transición tiene que ocurrir con la vista ya montada, o el
    /// cofre nace aterrizado (la misma historia que la manito del tutorial).
    @State private var dropped = false
    /// El cofre tocó el piso: dispara el aplaste, junto con el háptico.
    @State private var landed = false
    @State private var flashing = false
    @State private var flipDegrees: Double = 0
    /// La carta ya mostró su cara. Es `@State` y no `flipDegrees >= 90` porque el
    /// giro lo anima `withAnimation` y el valor presentado no se puede leer.
    @State private var flipRevealed = false
    @State private var cardLanded = false
    @State private var raysAngle: Double = 0
    @State private var breathing = false
    @State private var bursts: [Burst] = []

    /// Apaga el auto-avance de los cuatro latidos que esperan un toque, para que
    /// la animación avance **sólo con el dedo**.
    ///
    /// ⚠️ Existe por el defecto que en este proyecto ya apareció seis veces: un
    /// test que queda verde con la funcionalidad desenchufada. Como cada latido
    /// se dispara solo a los 1,2 s, un smoke que tapea cuatro veces y espera la
    /// carta **pasa igual con `tap()` muerta** — el reloj llega al mismo lugar.
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

    private static let chestSide: CGFloat = 210
    private static let raysSide: CGFloat = 360
    /// Las tres alturas, en puntos desde el centro de la pantalla. `stowedY` está
    /// calculado para que el cofre guardado no toque la carta ni se salga por
    /// abajo en la pantalla más corta que soporta el juego (SE: media pantalla
    /// son 333 pt, y 268 + 42 de medio cofre entran).
    private static let chestY: CGFloat = -20
    private static let cardY: CGFloat = -40
    private static let stowedY: CGFloat = 268
    private static let stowedScale: CGFloat = 0.4
    private static let portraitSide: CGFloat = 168
    private static let flipSeconds = 0.45
    /// Cuánto vive una ráfaga antes de que se le saquen las partículas del árbol.
    private static let burstLifetime = 1.5
    /// El plato del retrato: el mismo cuadrado redondeado de `SpecialDropView`.
    private static let plateShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        // Un `ZStack` pelado y offsets en PUNTOS desde el centro, no un
        // `GeometryReader` con fracciones: adentro del `ZStack` de `RootView` el
        // lector NO mide la pantalla —mide lo que le proponen— y el cofre
        // guardado terminaba a media altura, asomando por debajo de la carta.
        // Centrado + offsets no depende de qué le propongan.
        ZStack {
            // El telón al 55 %: el HUD ya está apagado por la cola
            // (`celebrationHidesUI`), esto apaga el tablero.
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // El foco: sin él los rayos crema caen sobre un callejón lleno de
            // ropa colgada y ladrillos, y se leen como astillas sueltas en vez
            // de como luz saliendo del cofre.
            RadialGradient(
                colors: [.black.opacity(0.55), .black.opacity(0.25), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
            .offset(y: beat >= .flying ? Self.cardY : Self.chestY)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            rays
                .offset(y: beat >= .flying ? Self.cardY : Self.chestY)

            chest
                .offset(y: beat >= .flying ? Self.stowedY : Self.chestY)

            if !reduceMotion {
                lid
            }

            // Las ráfagas viven en su propia capa y no adentro del cofre: el
            // cofre se achica y se va abajo cuando la carta toma el centro, y
            // las partículas del estallido todavía están en el aire.
            sparks(anchor: .chest, offsetY: Self.chestY)
            sparks(anchor: .card, offsetY: Self.cardY)

            if beat >= .flying {
                cardColumn
                    .offset(y: Self.cardY)
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

            // El flash de 80 ms del estallido, encima de todo: es lo que tapa
            // que `ui_chest_open` no calce exacto con el cerrado.
            Color.white
                .opacity(flashing ? 1 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.5), value: beat >= .flying)
        .ignoresSafeArea()
        // Sin esto VoiceOver se va al HUD apagado que quedó debajo.
        .accessibilityAddTraits(.isModal)
        .task(id: beat) { await choreograph(beat) }
    }

    // MARK: Los siete latidos

    /// El latido que está corriendo. Avanza **por completion y por tap**, nunca
    /// por `delay` encadenado: cada auto-avance es un `Task.sleep` cancelable que
    /// el `.task(id:)` mata solo cuando el jugador toca antes.
    private enum Beat: Int, Comparable {
        case arriving, waiting, forced1, forced2, forced3, bursting, flying, flipping, resting

        static func < (lhs: Beat, rhs: Beat) -> Bool { lhs.rawValue < rhs.rawValue }

        var next: Beat { Beat(rawValue: rawValue + 1) ?? .resting }

        /// Los cuatro latidos que ESPERAN un toque. Son los que
        /// `--uitest-chest-manual` deja sin reloj.
        var awaitsTap: Bool {
            switch self {
            case .waiting, .forced1, .forced2, .flying: true
            case .arriving, .forced3, .bursting, .flipping, .resting: false
            }
        }

        /// Segundos hasta el auto-avance, contados **después** de la coreografía
        /// propia del latido: la caída ya se comió 0,34 s de los 0,55, el flash
        /// 0,08 de los 0,5 y el giro la mitad de sus 0,45.
        var autoAdvance: Double? {
            switch self {
            case .arriving: 0.21
            case .waiting, .forced1, .forced2, .flying: 1.2
            case .forced3: 0.4
            case .bursting: 0.42
            case .flipping: 0.22
            case .resting: nil
            }
        }
    }

    /// A dónde lleva el dedo.
    ///
    /// Tocar durante la caída fuerza el candado igual en vez de gastar un toque
    /// en saltear el aterrizaje: es lo que hace que sean CUATRO toques y no cinco
    /// para el que llega apurado. Los latidos que no son del jugador —el
    /// estallido y el vuelo de la carta— no se saltean: son los que más garpan.
    private var beatForTap: Beat? {
        switch beat {
        case .arriving, .waiting: .forced1
        case .forced1: .forced2
        case .forced2: .forced3
        case .flying: .flipping
        case .forced3, .bursting, .flipping, .resting: nil
        }
    }

    private func tap() {
        // Con Reduce Motion **un solo toque** lleva al estado FINAL: la carta ya
        // dada vuelta, sin sacudidas y sin partículas.
        guard let target = reduceMotion ? .resting : beatForTap else { return }
        enter(target)
    }

    private func enter(_ target: Beat) {
        guard target != beat else { return }
        // Cualquier camino que salte al reposo —Reduce Motion, el auto-avance—
        // tiene que dejar la carta puesta y dada vuelta. Un estado final a medio
        // armar es el defecto que la regla del design system prohíbe.
        if target == .resting {
            flipDegrees = 180
            flipRevealed = true
            cardLanded = true
        }
        beat = target
    }

    private func advance() {
        enter(reduceMotion ? .resting : beat.next)
    }

    /// La coreografía de un latido: su háptico, su efecto y su auto-avance.
    private func choreograph(_ beat: Beat) async {
        switch beat {
        case .arriving:
            // El golpe va con el ATERRIZAJE, no con el nacimiento de la vista.
            guard await pause(reduceMotion ? 0 : 0.34) else { return }
            landed = true
            play(.merge)
            // ⚠️ El retrato se carga ACÁ, seis latidos antes de que se vea.
            // `cardFront` se monta recién en `.flying`, y con él la PRIMERA
            // lectura del personaje premiado: medida en el simulador, cuesta
            // ~320 ms de hilo principal —~215 realizando la página del atlas
            // (`texture.size()`) y ~100 en el `cgImage()`—, contra 0,1 ms una vez
            // cacheada. O sea que el latido en el que la carta sale volando
            // arrancaba comiéndose un cuarto de segundo de cuadros.
            //
            // La llegada es el lugar barato para pagarlo: es el latido en el que
            // el overlay se está construyendo igual, así que ya venía con ~500 ms
            // de bloqueos propios.
            //
            // Y va DESPUÉS del golpe, no antes: la caída ya arrancó —`dropped`
            // se prende en el `onAppear` del cofre, y su resorte de 0,5 s corre
            // por reloj de pared— así que ~320 ms clavados delante del
            // `pause(0,34)` se meten entre lo que se ve caer y el `landed` que
            // aplasta. Acá el aplaste y el golpe salen con el aterrizaje, y el
            // bloqueo cae después, donde lo único que espera es el auto-avance a
            // `.waiting` —un latido que no tiene nada temporizado contra él—.
            //
            // Medido con un vigía de hambre del hilo principal, dos corridas por
            // rama: `.flying` pasó de **247/279 ms a 101/71 ms**. En `.arriving`
            // el vigía marcó 525 → 542 ms, y eso NO significa que los 320 se
            // hayan evaporado: reporta el bloqueo **más largo** del latido, no la
            // suma, y 320 ms escondidos detrás de uno de ~500 no mueven el
            // máximo. Con n=2 y 390-661 ms de dispersión dentro de una misma
            // rama, ese número tampoco distingue "+320" de "+0" — lo único que
            // sostiene es que la llegada no estrenó un bloqueo más largo que el
            // que ya tenía.
            warmPrizeArt()
        case .waiting:
            breathing = !reduceMotion
        case .forced1:
            breathing = false
            play(.merge)                       // un golpe
            emit(Burst(count: 4, anchor: .chest, tinted: false, spread: 120, gravity: false))
        case .forced2:
            play(.purchase)                    // dos golpes
            emit(Burst(count: 8, anchor: .chest, tinted: true, spread: 150, gravity: false))
            // El anuncio de la rareza: los rayos toman su color y aceleran, ANTES
            // de que se sepa qué salió.
            spinRays(seconds: 4.5)
        case .forced3:
            play(.rarity)                      // tres que suben
        case .bursting:
            play(.evolution)                   // el más grande del juego
            emit(Burst(count: 30, anchor: .chest, tinted: true, spread: 320, gravity: true))
            flashing = true
            // El flash se apaga SIEMPRE, aunque la espera se cancele. Con un
            // `guard … else { return }` acá, cancelar el latido a mitad de esos
            // 80 ms dejaría la pantalla blanca para siempre. Hoy nadie puede
            // cancelarlo —el estallido no se saltea con el dedo— así que es un
            // seguro contra el día que alguien lo haga saltable.
            let siguió = await pause(0.08)
            withAnimation(.easeOut(duration: 0.12)) { flashing = false }
            guard siguió else { return }
        case .flying:
            withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.35)) {
                cardLanded = true
            }
        case .flipping:
            play(.rarity)
            withAnimation(.easeInOut(duration: Self.flipSeconds)) { flipDegrees = 180 }
            emit(Burst(count: 20, anchor: .card, tinted: true, spread: 260, gravity: true))
            guard await pause(Self.flipSeconds / 2) else { return }
            flipRevealed = true
        case .resting:
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
    /// lugar: el reposo. Los latidos que no esperan un toque conservan su reloj
    /// bajo la puerta de test —el estallido y el vuelo de la carta no los avanza
    /// nadie, así que sin reloj la animación quedaría trabada—, y la llegada es
    /// uno de ellos: es la que lleva al reposo con Reduce Motion.
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
    /// `UIArt.characterImage` la sirva de caché cuando la carta lo pida.
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

    // MARK: El cofre

    /// Un PNG del atlas, o nada. Los FX no tienen fallback vectorial a
    /// propósito: una estrella dibujada en código al lado de las del batch se
    /// ve de otra familia, y una ráfaga que no sale no rompe la animación.
    @ViewBuilder private func art(_ key: String) -> some View {
        if let image = UIArt.image(key) {
            image
                .resizable()
                .scaledToFit()
        }
    }

    @ViewBuilder private var chestArt: some View {
        switch beat {
        case .arriving, .waiting, .forced1:
            art("ui_chest_closed")
        case .forced2, .forced3:
            art("ui_chest_cracked")
        case .bursting, .flying, .flipping, .resting:
            // ⚠️ `ui_chest_open` no calza exacto con el cerrado: se dibuja unos
            // puntos más abajo dentro de su caja (base en 245/256 contra 231/256)
            // y con menos perspectiva. Se compensa levantándolo y ensanchándolo
            // apenas; el flash de 80 ms tapa lo que quede. **No se regenera arte.**
            art("ui_chest_open")
                .scaleEffect(x: 1.04, y: 1.0)
                .offset(y: -Self.chestSide * 0.055)
        }
    }

    private var chest: some View {
        chestArt
            .frame(width: Self.chestSide, height: Self.chestSide)
            // El respiro de la espera y el hinchado del tercer toque, en la misma
            // escala: son el mismo gesto a dos intensidades.
            .scaleEffect(chestScale)
            // El respiro es un `repeatForever` **atado a la bandera**: mientras
            // `breathing` está prendida el cofre late, y al apagarse el mismo
            // modificador pasa a ser un resorte común. Es la forma exacta de
            // `TapHereHand`, que es la que deja el display link vivo sólo
            // mientras el latido lo está.
            .animation(
                breathing
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .spring(duration: 0.28),
                value: chestScale
            )
            .modifier(ChestShake(degrees: shakeDegrees, enabled: !reduceMotion))
            .modifier(ChestDrop(dropped: dropped, landed: landed, enabled: !reduceMotion))
            // Achicarse y bajar es UN gesto: la transacción la abre el `ZStack`,
            // así el cofre se va al rincón por el mismo resorte con el que la
            // carta toma el centro.
            .scaleEffect(beat >= .flying ? Self.stowedScale : 1)
            .accessibilityHidden(true)
            .onAppear { dropped = true }
    }

    private var chestScale: CGFloat {
        if beat == .forced3 { return 1.12 }   // se hincha antes de reventar
        return breathing ? 1.04 : 1
    }

    private var shakeDegrees: Double {
        switch beat {
        case .forced1: 5
        case .forced2: 9
        case .forced3: 14
        default: 0
        }
    }

    /// La tapa saliendo volando. Nace en el estallido y **no se desmonta más**:
    /// el fling dura 0,85 s y el jugador puede dar vuelta la carta antes, así que
    /// con `== .bursting || == .flying` la tapa se cortaba a mitad de vuelo.
    /// Quedarse montada no cuesta nada —termina en opacidad 0, sin hit testing y
    /// muda para VoiceOver—. Con Reduce Motion no se dibuja nunca, porque su
    /// estado final es justamente no estar.
    @ViewBuilder private var lid: some View {
        if beat >= .bursting {
            FlyingLid(side: Self.chestSide * 0.8)
                .offset(y: Self.chestY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Los rayos

    private var rays: some View {
        Group {
            if let image = UIArt.image("fx_burst_rays") {
                image
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: Self.raysSide, height: Self.raysSide)
        .rotationEffect(.degrees(raysAngle))
        // El teñido por rareza: los tres FX son crema con contorno negro, así que
        // multiplicar deja el contorno intacto y sólo el relleno toma color.
        .colorMultiply(beat >= .forced2 ? ChestRarityStyle.color(rarity) : .white)
        // Apagado con Reduce Motion como todo el resto del pulido: sin el `nil`
        // los rayos eran la única animación que seguía corriendo. Apagada, el
        // color salta a su estado FINAL, que es el que la regla pide.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: beat >= .forced2)
        // 0,7 y no 0,85: al 85 % los rayos crema tapaban el callejón y se leían
        // como cartón recortado. Con el foco detrás, a 0,7 son luz.
        .opacity(0.7)
        .scaleEffect(beat >= .flying ? 1.15 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { spinRays(seconds: 13) }
    }

    /// El giro de los rayos. Es un `repeatForever`, pero **atado a esta vista**:
    /// nace en su `onAppear` y muere con el overlay, así que no deja el display
    /// link vivo toda la sesión (regla del design system). Con Reduce Motion no
    /// arranca, y los rayos quedan quietos en su estado final.
    ///
    /// El cambio de velocidad reinicia el ángulo a 0 sin animar: sin eso, el
    /// `repeatForever` nuevo repetiría el tramo "ángulo actual → +360" y pegaría
    /// un salto en cada vuelta, para siempre. El salto único que queda cae justo
    /// en el latido que tiñe, sacude y vibra.
    private func spinRays(seconds: Double) {
        guard !reduceMotion else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { raysAngle = 0 }
        withAnimation(.linear(duration: seconds).repeatForever(autoreverses: false)) {
            raysAngle = 360
        }
    }

    // MARK: Las ráfagas

    /// Dónde nace una ráfaga: el cofre o la carta.
    private enum BurstAnchor { case chest, card }

    /// Una ráfaga, con sus partículas **ya sorteadas**.
    ///
    /// El sorteo vive acá y no en el `init` de `SparkBurst` porque la vista se
    /// vuelve a construir en cada pase del `body`, y mientras la ráfaga de 30
    /// vuela sus 1,1 s el `body` corre varias veces: el flash que se prende y se
    /// apaga, el latido que cambia, cada ráfaga vieja que se retira. El
    /// `keyframeAnimator` conserva la animación en curso —su trigger no cambia—,
    /// pero el `.frame(width: spark.side…)` toma el valor nuevo en el acto, así
    /// que un sorteo por pase le cambiaría el tamaño a las 30 partículas EN
    /// PLENO ESTALLIDO. La `Burst` se arma una sola vez, en `emit`.
    private struct Burst: Identifiable {
        let id = UUID()
        let anchor: BurstAnchor
        let tinted: Bool
        let sparks: [Spark]

        init(count: Int, anchor: BurstAnchor, tinted: Bool, spread: CGFloat, gravity: Bool) {
            self.anchor = anchor
            self.tinted = tinted
            sparks = (0..<count).map { index in
                Spark(
                    id: index,
                    dx: .random(in: -spread...spread),
                    rise: .random(in: spread * 0.35...spread * 0.95),
                    fall: gravity ? .random(in: spread * 0.9...spread * 1.6) : 0,
                    side: .random(in: 26...52),
                    spin: .random(in: -260...260),
                    isStar: !index.isMultiple(of: 3)
                )
            }
        }
    }

    private func emit(_ burst: Burst) {
        guard !reduceMotion else { return }
        bursts.append(burst)
        // Las partículas se sacan del árbol cuando terminan de caer. No es un
        // `Timer` ni lógica de juego: es la vida de un adorno, y si el overlay se
        // cierra antes, la limpieza cae sobre un `@State` que ya no mira nadie.
        Task {
            try? await Task.sleep(for: .seconds(Self.burstLifetime))
            bursts.removeAll { $0.id == burst.id }
        }
    }

    @ViewBuilder private func sparks(anchor: BurstAnchor, offsetY: CGFloat) -> some View {
        ForEach(bursts.filter { $0.anchor == anchor }) { burst in
            SparkBurst(
                sparks: burst.sparks,
                tint: burst.tinted ? ChestRarityStyle.color(rarity) : nil
            )
            .offset(y: offsetY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: La carta

    /// La carta y, en el reposo, sus dos botones. Van juntos en una columna para
    /// que los botones queden siempre pegados abajo de la carta, sin medir nada.
    private var cardColumn: some View {
        VStack(spacing: Tokens.s16) {
            card
            if beat == .resting {
                controls
            }
        }
    }

    private var card: some View {
        cardFront
            .opacity(flipRevealed ? 1 : 0)
            // El contragiro de la cara. La carta entera termina el giro a 180°,
            // así que sin estos otros 180° la pinta y su nombre quedarían
            // ESPEJADOS justo en el latido del premio.
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            // El dorso va de overlay y no de hermano en un `ZStack` para que tome
            // la geometría de la cara: así los dos miden exactamente lo mismo y el
            // giro no cambia de tamaño a la mitad.
            .overlay { cardBack.opacity(flipRevealed ? 0 : 1) }
            .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(cardLanded ? 1 : 0.18)
            .rotationEffect(.degrees(cardLanded ? 0 : -150))
            .padding(.top, 26)
            // La parada de AX es el CONTENEDOR del giro y no la cara.
            //
            // ⚠️ La cara vive en `opacity 0` hasta que la carta se da vuelta, y
            // una vista con opacidad 0 **no está en el árbol** que ve XCUITest:
            // con el identifier ahí, `chest.card` no existía para nadie hasta el
            // cuarto toque. El contenedor está siempre opaco.
            //
            // `children: .ignore` la colapsa en UN elemento, que es el patrón de
            // `DailyRewardView.prizeCard` y es seguro acá: adentro no hay ningún
            // control que un contenedor pudiera pisar (los dos botones viven
            // afuera, en `controls`).
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("chest.card")
            .accessibilityLabel(flipRevealed ? Text(prizeName) : Text("chest.card.facedown"))
            .accessibilityValue(cardValue)
    }

    /// La rareza, para VoiceOver. Se canta por la misma regla que la cinta: es
    /// la etiqueta de la pinta, no del monto de plata.
    private var cardValue: Text {
        guard flipRevealed, case .skin = reward.outcome else { return Text(verbatim: "") }
        return Text(ChestRarityStyle.nameKey(rarity))
    }

    /// El dorso **no se genera**: es el tablón de madera de la casa con el moño,
    /// que sale más coherente que un PNG nuevo.
    private var cardBack: some View {
        PanelCard {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay { GiftBowOrnament(width: 130) }
        .accessibilityHidden(true)
    }

    /// La cara: la MISMA carta de `SpecialDropView` —`PanelCard` +
    /// `PanelTitleBanner` + `GameCard` amarilla con el retrato de 168 pt—, que es
    /// la que el dueño ya pidió que muestre la skin en grande.
    ///
    /// La cara está montada desde que la carta aparece (invisible, pero con su
    /// tamaño): es lo que le da al dorso su geometría. Muda para VoiceOver: la
    /// parada de AX la pone el contenedor del giro, que es el que sabe si el
    /// premio ya se puede cantar.
    private var cardFront: some View {
        PanelCard {
            VStack(spacing: Tokens.s12) {
                PanelTitleBanner(titleKey: titleKey)
                GameCard(style: .highlighted(Color("PaletteYellow"))) {
                    VStack(spacing: Tokens.s8) {
                        prizeArt
                        // La cinta SÓLO con pinta. Con plata el monto sale de
                        // `passiveUnlockCost(forTier:) × factor`: depende del piso
                        // al que llegó el jugador y de si el cofre era de
                        // prestigio, y NO de la rareza. Etiquetar el número con
                        // una cinta promete un ranking que no existe —dos cofres
                        // del mismo tier pagan lo mismo sean comunes o
                        // legendarios— y de paso deja el peor cartel posible:
                        // "me salió legendario y me dieron plata".
                        //
                        // La rareza ya cobró su sueldo antes de dar vuelta la
                        // carta: tiñó los rayos y las partículas en el segundo
                        // toque, que es el mecanismo que defiende el encabezado
                        // del archivo. Sacar la cinta no le quita nada al tinte.
                        if case .skin = reward.outcome {
                            rarityRibbon
                        }
                        Text(prizeName)
                            .font(Tokens.title)
                            .foregroundStyle(Color("PaletteInk"))
                            .multilineTextAlignment(.center)
                            // Envolver, nunca truncar: el nombre sale del catálogo
                            // y un nombre cortado no nombra a nadie.
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(Tokens.body)
                            .foregroundStyle(Color("PaletteInk").opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: 250)
        }
        .overlay(alignment: .top) {
            GiftBowOrnament(width: 110)
                .offset(y: -24)
                .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
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
                .padding(Tokens.s8)
                .colorMultiply(SkinResolver.swiftUITint(for: treatment) ?? .white)
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(28)
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

    private var titleKey: LocalizedStringKey {
        switch reward.outcome {
        case .skin: "chest.title.skin"
        case .coins: "chest.title.coins"
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

// MARK: - Los efectos del cofre

/// La sacudida de forzar el candado: ±5°, ±9° y ±14°, con los mismos
/// `SpringKeyframe(spring: .bouncy)` del bounce de las pestañas y del
/// `QuickHireButton`.
///
/// Es un `ViewModifier` y no dos ramas en el `body` para que el apagado por
/// Reduce Motion viva en UN solo lugar por efecto.
private struct ChestShake: ViewModifier {
    /// La amplitud ES el trigger: los tres toques valen 5, 9 y 14, y los latidos
    /// que no sacuden valen 0, así que la sacudida arranca exactamente cuando
    /// cambia de tamaño. Un trigger genérico no compila —capturar el tipo en el
    /// closure aislado del `keyframeAnimator` es error en Swift 6— y de paso
    /// esto deja un parámetro menos que mantener sincronizado.
    let degrees: Double
    let enabled: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: 0.0, trigger: degrees) { view, angle in
                view.rotationEffect(.degrees(angle))
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-degrees, duration: 0.06)
                    SpringKeyframe(degrees, duration: 0.10, spring: .bouncy)
                    SpringKeyframe(0, duration: 0.18, spring: .bouncy)
                }
            }
        } else {
            content
        }
    }
}

/// La llegada: el cofre cae, rebota y **aplasta** al aterrizar.
///
/// Con Reduce Motion el modificador no se aplica, así que el cofre nace donde
/// termina la caída — el estado FINAL, nunca el inicial.
///
/// ⚠️ **La caída NO es un `keyframeAnimator`, y esto costó una vuelta de
/// simulador**: con una pista que arrancaba en −520 pt el cofre se veía caer,
/// aterrizar… y desaparecer, y el estallido reventaba un cofre invisible.
///
/// ⚠️⚠️ Y **no es porque el animador vuelva a su `initialValue` al terminar**.
/// Eso es lo ÚNICO pineado de esta nota, y es una negación: la doc de Apple dice
/// lo contrario —"the animator will remain at the end value, which becomes the
/// initial value for the next animation"—, así que la regla general que este
/// comentario afirmaba no existe, y los otros cuatro `keyframeAnimator` del repo
/// no dependen de ella.
///
/// ⚠️ **La causa positiva sigue ABIERTA, y lo que sigue es una hipótesis con una
/// objeción conocida — no la tomes como hecho.** La hipótesis: lo que re-arma un
/// animador en su `initialValue` es que cambie la identidad del subárbol que
/// envuelve, y este cofre la cambia dos veces —`chestArt` es un `switch` de tres
/// artes (cerrado, rajado, abierto)— SEGUNDOS después de que la caída terminó,
/// que es lo que explicaría por qué el cofre reaparecía arriba justo en el
/// estallido y no al aterrizar.
///
/// **La objeción**: ese `switch` vive ADENTRO del `content` que este modificador
/// envuelve, o sea POR DEBAJO del `keyframeAnimator`. Cambiar de rama de un
/// `_ConditionalContent` re-arma el subárbol de adentro, no el estado del
/// modificador que está arriba — así que, por el modelo de identidad de SwiftUI,
/// el swap de arte **no debería** tocar al animador. La hipótesis explica el
/// síntoma pero no encaja con el modelo, y no hay medición que la sostenga: el
/// arreglo llegó antes que la autopsia.
///
/// La lección que sí se lleva el próximo: una pista que **no empieza en el
/// valor de reposo** es frágil arriba de una vista que cambia de arte. La caída
/// va con `offset` + `withAnimation`, que se queda donde la dejaron pase lo que
/// pase. El aplaste puede seguir siendo keyframes porque **empieza y termina en
/// 1** —igual que los otros cuatro del repo—: ahí re-armarse no se ve.
private struct ChestDrop: ViewModifier {
    /// Ya cayó. Lo prende el `onAppear`, un frame después del primero, que es lo
    /// que hace que la caída se vea en vez de nacer aterrizada.
    let dropped: Bool
    /// Ya tocó el piso: dispara el aplaste, en el mismo instante que el háptico.
    let landed: Bool
    let enabled: Bool

    private struct Squash {
        var wide: CGFloat = 1
        var tall: CGFloat = 1
    }

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content
                .keyframeAnimator(initialValue: Squash(), trigger: landed) { view, value in
                    view.scaleEffect(x: value.wide, y: value.tall, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack(\.tall) {
                        CubicKeyframe(0.76, duration: 0.07)
                        SpringKeyframe(1, duration: 0.30, spring: .bouncy)
                    }
                    KeyframeTrack(\.wide) {
                        CubicKeyframe(1.18, duration: 0.07)
                        SpringKeyframe(1, duration: 0.30, spring: .bouncy)
                    }
                }
                .offset(y: dropped ? 0 : -520)
                .animation(.spring(duration: 0.5, bounce: 0.45), value: dropped)
        } else {
            content
        }
    }
}

/// La tapa suelta saliendo volando y girando.
private struct FlyingLid: View {
    let side: CGFloat
    @State private var flung = false

    var body: some View {
        Group {
            if let image = UIArt.image("ui_chest_lid") {
                image.resizable().scaledToFit()
            }
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(flung ? -210 : 0))
        .offset(x: flung ? -110 : 0, y: flung ? -260 : -side * 0.25)
        .opacity(flung ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 0.85)) { flung = true }
        }
    }
}

/// Una partícula de una ráfaga. La gravedad no viaja como bandera: un `fall` en
/// cero ES la ráfaga que no cae.
private struct Spark: Identifiable {
    let id: Int
    let dx: CGFloat
    let rise: CGFloat
    let fall: CGFloat
    let side: CGFloat
    let spin: Double
    let isStar: Bool
}

/// Una ráfaga de estrellas y chispitas.
///
/// ⚠️ **No sale del `ParticlePool`**: ese es de SpriteKit (`emit(_:at:in
/// parent: SKNode)`, único cliente `BoardScene`) y esto es SwiftUI. Las
/// partículas son `fx_star` y `fx_sparkle` dibujadas como vistas, con offsets al
/// azar y caída.
///
/// ⚠️ **Acá no se sortea nada**: las partículas llegan hechas desde `emit`. El
/// porqué —y qué se veía cuando el sorteo estaba en este `init`— está en
/// `ChestOpeningView.Burst`.
private struct SparkBurst: View {
    private struct Flight {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var angle: Double = 0
        var scale: CGFloat = 0.4
        var opacity: Double = 1
    }

    let sparks: [Spark]
    let tint: Color?

    @State private var flung = false

    var body: some View {
        ZStack {
            ForEach(sparks) { spark in
                Group {
                    if let image = UIArt.image(spark.isStar ? "fx_star" : "fx_sparkle") {
                        image.resizable().scaledToFit()
                    }
                }
                .frame(width: spark.side, height: spark.side)
                .colorMultiply(tint ?? .white)
                .keyframeAnimator(initialValue: Flight(), trigger: flung) { view, value in
                    view
                        .scaleEffect(value.scale)
                        .rotationEffect(.degrees(value.angle))
                        .offset(x: value.x, y: value.y)
                        .opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.x) {
                        LinearKeyframe(spark.dx, duration: 1.1)
                    }
                    KeyframeTrack(\.y) {
                        CubicKeyframe(-spark.rise, duration: 0.38)
                        CubicKeyframe(-spark.rise + spark.fall, duration: 0.72)
                    }
                    KeyframeTrack(\.angle) {
                        LinearKeyframe(spark.spin, duration: 1.1)
                    }
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1, duration: 0.2, spring: .bouncy)
                        LinearKeyframe(1, duration: 0.5)
                        LinearKeyframe(0.5, duration: 0.4)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(1, duration: 0.7)
                        LinearKeyframe(0, duration: 0.4)
                    }
                }
            }
        }
        .onAppear { flung = true }
    }
}
