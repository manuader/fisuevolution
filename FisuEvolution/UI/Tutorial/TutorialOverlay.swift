import SwiftUI

/// Eventos de la propia UI que completan un paso y no se pueden leer de una
/// proyección de `GameState` (abrir una hoja no cambia la economía).
struct TutorialEvents: OptionSet, Equatable {
    let rawValue: Int
    static let openedUpgrades = TutorialEvents(rawValue: 1 << 0)
    static let openedMap = TutorialEvents(rawValue: 1 << 1)
}

/// Tutorial interactivo (RF-01), patrón Clash of Clans.
///
/// Cada paso recorta un agujero sobre el control **real** —resuelto por
/// `TutorialAnchorKey` para los controles de SwiftUI y por `BoardScene` para el
/// personaje del tablero— con una mano que late encima. El resto de la pantalla
/// queda oscurecido y **no responde al toque**, así que el paso sólo avanza
/// cuando el jugador ejecuta la acción que se le pide. Tocar en cualquier lado
/// ya no hace nada: era eso lo que hacía que el tutorial no enseñara nada.
///
/// Se conservan el botón de saltear y el `AppStorage` de "ya lo vi".
struct TutorialOverlay: View {
    /// Frames reales de los controles, ya resueltos por el `GeometryProxy` que
    /// monta el overlay. Nunca coordenadas escritas a mano.
    let anchors: [TutorialTarget: CGRect]
    let events: TutorialEvents

    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("fisuTutorialDone") private var done = false
    @State private var step = 0

    // MARK: - El guion

    /// Qué completa un paso. Es un enum y no un closure guardado para que el
    /// guion siga siendo un valor puro y la condición viva en un solo `switch`
    /// que se puede leer entero de una.
    private enum Completion: Equatable {
        /// Tocó al Fisura Y ya junta para contratar. Las dos cosas: con sólo el
        /// primer toque, el paso siguiente iluminaría un botón que no se puede
        /// pagar hasta dentro de cincuenta toques, y con el resto de la pantalla
        /// bloqueada eso es un callejón sin salida.
        case earnedEnoughToHire
        case hired
        case merged
        case ui(TutorialEvents)
        /// Lo cierra el botón del paso final.
        case explicitButton
    }

    private struct Step {
        let id: String
        let target: TutorialTarget?
        /// Recortes de sólo mirar: no llevan mano y no son la acción del paso,
        /// pero dejan ver el marcador que el jugador necesita seguir.
        var windows: [TutorialTarget] = []
        var boardTarget: GameState.TutorialBoardTarget?
        let text: LocalizedStringKey
        let pose: String
        let completion: Completion
    }

    /// ⚠️ Los controles que se iluminan son los de HOY: los **tabs** de FisuJobs
    /// (`hud.hire`) y de mejoras (`hud.upgrades`) en la barra inferior, y el
    /// botón de mapa (`hud.map`, que vive en la cápsula de la torre). El paso
    /// viejo que explicaba las flechas de la torre lo reemplaza el mapa, que es
    /// lo que las reemplazó a ellas.
    ///
    /// ⚠️ El paso de contratar ya no ilumina un botón que compra: ilumina el tab
    /// que abre una PANTALLA. La hoja se presenta **por encima** del overlay
    /// —que es lo correcto: el scrim sólo tiene que gobernar el tablero—, el
    /// jugador contrata adentro y `hireCharacter` marca `ftue.spawned`, así que
    /// el paso se completa aunque el globo esté tapado y el tutorial ya está en
    /// "fusioná" cuando la hoja se cierra.
    private var steps: [Step] {
        [
            Step(id: "tap", target: .boardUnit, windows: [.coins], boardTarget: .anyUnit,
                 text: "tutorial.step.tap", pose: "fisura_wave", completion: .earnedEnoughToHire),
            Step(id: "hire", target: .hire, windows: [.coins],
                 text: "tutorial.step.hire", pose: "fisura_point", completion: .hired),
            // Enseña los DOS gestos de fusión y se completa con cualquiera de
            // los dos. No son dos pasos porque después de contratar hay un solo
            // par mergeable: darle un paso propio al doble toque deja al del
            // arrastre sin par, y conseguirle otro cuesta tres pasos más —ganar
            // plata, contratar, fusionar— porque el paso de contratar tiene el
            // tablero bajo el scrim y no se puede tapear para ganar.
            Step(id: "merge", target: .boardUnit, boardTarget: .mergePair,
                 text: "tutorial.step.merge", pose: "fisura_explain", completion: .merged),
            Step(id: "upgrades", target: .upgrades,
                 text: "tutorial.step.upgrades", pose: "fisura_explain", completion: .ui(.openedUpgrades)),
            Step(id: "map", target: .map,
                 text: "tutorial.step.map", pose: "fisura_point", completion: .ui(.openedMap)),
            Step(id: "finish", target: nil,
                 text: "tutorial.step.finish", pose: "fisura_celebrate", completion: .explicitButton),
        ]
    }

    // MARK: - Cuerpo

    var body: some View {
        // Mientras una celebración tiene el turno, el overlay ENTERO se esconde
        // —scrim, recorte, mano y globo—. Durante la fase la única que puede
        // tomarlo es el reveal del tablero (`beginTutorialPhase` restringe la
        // cola), y ése es EL momento del primer merge: se reproduce limpio, a
        // pantalla completa y sin un segundo scrim encima, y el paso siguiente
        // aparece recién cuando la escena avisa `celebrationFinished`. Regla
        // dura: nunca dos scrims a la vez.
        if !done, step < steps.count, gameState.showing == nil {
            overlay(steps[step])
        }
    }

    @ViewBuilder
    private func overlay(_ current: Step) -> some View {
        let hole = holeRect(for: current)
        let windows = current.windows.compactMap { anchors[$0] }
        GeometryReader { proxy in
            ZStack {
                scrim(hole: hole, windows: windows, screen: proxy.size)
                if SpotlightShape.isDrawable(hole) {
                    spotlightRing(hole)
                    hand(hole, screen: proxy.size)
                }
                card(current, hole: hole, screen: proxy.size)
            }
            .background(markers(current, hole: hole))
        }
        .ignoresSafeArea()
        .animation(motion(.easeInOut(duration: 0.32)), value: hole)
        .animation(motion(.easeInOut(duration: 0.32)), value: step)
        .onAppear {
            gameState.tutorialBoardTarget = current.boardTarget
        }
        .onDisappear {
            gameState.tutorialBoardTarget = nil
        }
        .onChange(of: current.boardTarget) { _, target in
            gameState.tutorialBoardTarget = target
        }
        .onChange(of: progress, initial: true) { _, _ in
            advanceWhileSatisfied()
        }
    }

    // MARK: - El recorte

    /// El agujero del paso. `.null` = sin recorte (el paso final va con el scrim
    /// entero, que es lo correcto: no pide tocar nada del juego).
    private func holeRect(for current: Step) -> CGRect {
        guard let target = current.target else { return .null }
        let rect: CGRect? = target == .boardUnit ? gameState.boardSpotlight : anchors[target]
        guard let rect, SpotlightShape.isDrawable(rect) else { return .null }
        // Un poco de aire alrededor: pegado al borde del control el recorte se
        // lee como un error de alineación.
        return rect.insetBy(dx: -10, dy: -10)
    }

    private func scrim(hole: CGRect, windows: [CGRect], screen: CGSize) -> some View {
        let shape = SpotlightShape(primary: hole, extras: windows)
        return shape
            .fill(Color.black.opacity(0.68), style: FillStyle(eoFill: true))
            // La MISMA forma de hit-testing: fuera del agujero el toque se lo
            // come el scrim y no llega ni al HUD ni a la escena. Es lo único que
            // impide saltear un paso sin hacer lo que pide.
            .contentShape(shape, eoFill: true)
            .accessibilityIdentifier("tutorial.scrim")
            .accessibilityHidden(true)
    }

    /// Borde luminoso del agujero: sin esto el recorte se lee como un bache en
    /// el scrim en vez de como algo que hay que tocar.
    private func spotlightRing(_ hole: CGRect) -> some View {
        RoundedRectangle(cornerRadius: min(28, min(hole.width, hole.height) / 2), style: .continuous)
            .strokeBorder(Color("PaletteYellow"), lineWidth: 3)
            .shadow(color: Color("PaletteYellow").opacity(0.75), radius: 10)
            .frame(width: hole.width, height: hole.height)
            .position(x: hole.midX, y: hole.midY)
            .allowsHitTesting(false)
    }

    private func hand(_ hole: CGRect, screen: CGSize) -> some View {
        TutorialHand(hole: hole, screen: screen, reduceMotion: reduceMotion)
    }

    // MARK: - El globo

    /// El globo va del lado OPUESTO al recorte, así nunca tapa el control que
    /// está pidiendo que toques, y **esquiva las dos barras de controles** con
    /// sus frames reales: apoyado sin ese margen se comía el HUD entero.
    private func card(_ current: Step, hole: CGRect, screen: CGSize) -> some View {
        // Sin recorte —el paso final— no hay nada que esquivar: va centrado, que
        // es donde se lee un cierre.
        let hasHole = SpotlightShape.isDrawable(hole)
        let holeIsLow = hasHole ? hole.midY > screen.height / 2 : false
        let topInset = (anchors[.hudBar]?.maxY ?? 0) + 14
        let bottomInset = anchors[.bottomBar].map { screen.height - $0.minY + 14 } ?? 40
        return VStack(spacing: 0) {
            if !holeIsLow { Spacer(minLength: 0) }
            TutorialCard(
                text: current.text,
                pose: current.pose,
                index: step,
                total: steps.count,
                showsDoneButton: current.completion == .explicitButton,
                onDone: finish,
                onSkip: finish
            )
            .padding(.horizontal, 14)
            .padding(.top, holeIsLow ? topInset : 0)
            .padding(.bottom, hasHole && !holeIsLow ? bottomInset : 0)
            if holeIsLow || !hasHole { Spacer(minLength: 0) }
        }
        .transition(.opacity)
        .id(step)
    }

    // MARK: - Marcadores para los tests de UI

    /// Invisibles para el jugador, medibles para los tests.
    ///
    /// ⚠️ Van por **identifier** y con el valor sin traducir: el runner corre la
    /// app en inglés aunque el idioma de desarrollo sea `es` (trampa 6), así que
    /// un assert sobre el texto del globo pasaría por no encontrar nunca nada.
    /// `tutorial.spotlight` publica el recorte para poder comprobar que cae
    /// sobre el frame del control de verdad y no sobre el vacío.
    ///
    /// ⚠️⚠️ Van de FONDO y de 1×1, igual que `board.units` en `RootView`. Puestos
    /// arriba del `ZStack` y a pantalla completa —que es lo natural— son dos
    /// elementos de accesibilidad que TAPAN a todos los controles de abajo en el
    /// árbol de AX: XCUITest deja de considerarlos "hittable" y cada `.tap()`
    /// falla con "Failed to scroll to visible", incluido el botón de saltear del
    /// propio tutorial. Es la trampa 4 del HANDOFF con un disfraz nuevo: nunca
    /// es el botón, siempre es algo tapándolo. Los toques por coordenada seguían
    /// funcionando, así que el bug sólo se ve en los tests que usan `.tap()`
    /// sobre un elemento.
    private func markers(_ current: Step, hole: CGRect) -> some View {
        VStack(spacing: 2) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("tutorial.step")
                .accessibilityValue(Text(verbatim: current.id))
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("tutorial.spotlight")
                // Distingue "este paso no ilumina nada" de "el control que este
                // paso ilumina no publicó su ancla": lo segundo es un bug que
                // deja el scrim entero y el paso sin salida, y sin este valor se
                // ve exactamente igual que lo primero.
                .accessibilityValue(Text(verbatim: SpotlightShape.isDrawable(hole)
                    ? Self.describe(hole)
                    : (current.target.map { "missing:\($0.rawValue)" } ?? "none")))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    static func describe(_ rect: CGRect) -> String {
        guard SpotlightShape.isDrawable(rect) else { return "none" }
        return "\(Int(rect.minX.rounded())),\(Int(rect.minY.rounded()))," +
            "\(Int(rect.width.rounded())),\(Int(rect.height.rounded()))"
    }

    // MARK: - Avanzar POR ACCIÓN

    /// Todo lo que puede completar un paso, en un valor `Equatable`: es lo que
    /// hace que un `onChange` alcance para reevaluar el guion entero.
    private var progress: Progress {
        Progress(
            milestones: gameState.ftueMilestones,
            canAffordSpawn: gameState.canAffordSpawn,
            events: events
        )
    }

    private struct Progress: Equatable {
        let milestones: GameState.FTUEMilestones
        let canAffordSpawn: Bool
        let events: TutorialEvents
    }

    private func isSatisfied(_ completion: Completion) -> Bool {
        switch completion {
        case .earnedEnoughToHire: gameState.ftueMilestones.tapped && gameState.canAffordSpawn
        case .hired: gameState.ftueMilestones.spawned
        case .merged: gameState.ftueMilestones.merged
        case .ui(let event): events.contains(event)
        case .explicitButton: false
        }
    }

    /// Avanza en bucle y no de a un paso: al reanudar una partida a medio
    /// tutorial puede haber varios pasos ya cumplidos, y un `onChange` sobre el
    /// booleano "el paso actual está cumplido" no vuelve a disparar cuando el
    /// siguiente también lo está (true → true no es un cambio).
    private func advanceWhileSatisfied() {
        let script = steps
        var next = step
        while next < script.count, isSatisfied(script[next].completion) {
            next += 1
        }
        guard next != step else { return }
        withAnimation(motion(.easeInOut(duration: 0.3))) {
            step = next
            if step >= script.count { done = true }
        }
        // Fuera del `withAnimation`: soltar la cola no es un cambio visual de
        // esta vista. Con el guion actual no se llega acá (el último paso lo
        // cierra su botón), pero si un guion futuro vuelve a terminar por
        // acción, la cola no puede quedarse restringida para siempre.
        if done { gameState.tutorialPhaseFinished() }
    }

    private func finish() {
        gameState.tutorialBoardTarget = nil
        withAnimation(motion(.easeInOut(duration: 0.3))) { done = true }
        // Las dos salidas —"¡Vamos!" y "Saltar"— terminan la fase: la cola
        // levanta la restricción y lo que esperó su turno (el daily del día 2,
        // la skin, los toasts) desfila recién ahora, de a uno.
        gameState.tutorialPhaseFinished()
    }

    /// ⚠️ Con Reduce Motion las transiciones **colapsan**: se devuelve `nil`, que
    /// aplica el cambio sin animación. Es la misma regla por la que la secuencia
    /// de celebraciones encadena por completion y no por delays.
    private func motion(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// La mano que late sobre el recorte.
///
/// ⚠️ Tiene su propio `@State` y su propio `onAppear` por un motivo concreto:
/// el latido es un `repeatForever` disparado por el CAMBIO de `up`, y si ese
/// cambio ocurre antes de que la vista exista, no hay cambio que animar y la
/// mano se queda quieta para siempre. Es lo que pasaba con la bandera en el
/// overlay: el `onAppear` del overlay corría mientras el recorte del tablero
/// todavía no había llegado desde la escena, así que la mano nacía ya "arriba" y
/// nunca latía. **No se veía en una captura** —la mano estaba, y en su pose
/// grande— y sólo apareció comparando cuatro capturas seguidas CON y SIN Reduce
/// Motion: las dos daban imágenes idénticas entre sí.
///
/// ⚠️ Con Reduce Motion `up` se queda en falso, así que el `repeatForever` no se
/// registra nunca. No alcanza con darle duración cero: un `repeatForever`
/// colapsado sigue corriendo el display link de SwiftUI toda la sesión, que es
/// el bug que ya tuvo el botón de contratar.
private struct TutorialHand: View {
    let hole: CGRect
    let screen: CGSize
    let reduceMotion: Bool
    @State private var up = false

    private static let size: CGFloat = 46

    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: Self.size, weight: .black))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
            .scaleEffect(up ? 1.14 : 0.92)
            .offset(x: up ? 5 : 0, y: up ? 7 : 0)
            .animation(
                up ? .easeInOut(duration: 0.62).repeatForever(autoreverses: true) : .default,
                value: up
            )
            // La mano se acomoda al borde del agujero, pero nunca se sale de la
            // pantalla: el botón de contratar vive pegado al borde de abajo.
            .position(
                x: min(max(hole.maxX - 6, Self.size), screen.width - Self.size / 2),
                y: min(max(hole.maxY - 2, Self.size), screen.height - Self.size)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { up = !reduceMotion }
    }
}

/// El globo del tutorial: pose del Fisura + texto + progreso, al nivel del resto
/// del juego (tarjeta crema con los materiales v3: borde marrón cálido, el radio
/// de todas las tarjetas, tipografía redondeada).
///
/// Es horizontal y compacto —y no el Fisura de 300×380 con el globo arriba que
/// había antes— porque tiene que convivir con el recorte sin taparlo.
private struct TutorialCard: View {
    let text: LocalizedStringKey
    let pose: String
    let index: Int
    let total: Int
    let showsDoneButton: Bool
    let onDone: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                portrait
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 10) {
                        dots
                        Spacer(minLength: 8)
                        // En el último paso no: "Saltar" y "¡Vamos!" harían lo
                        // mismo, uno al lado del otro.
                        if !showsDoneButton { skipButton }
                    }
                }
            }
            if showsDoneButton {
                ArtButton(art: "ui_btn_buy", tint: Color("PaletteGreen"), minHeight: 52, action: onDone) {
                    Text("tutorial.done")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                }
                .accessibilityIdentifier("tutorial.done")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            // Materiales v3: el globo es una tarjeta más del juego — el radio de
            // TODAS las tarjetas y borde marrón cálido en vez de tinta. Conserva
            // los 3 pt de trazo (y su sombra grande) porque flota sobre el scrim
            // oscuro, donde el peso de tarjeta destacada es lo que lo despega.
            RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                .fill(Color("PaletteCream"))
                .overlay(RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
        )
    }

    @ViewBuilder private var portrait: some View {
        let art = UIArt.image(pose) ?? UIArt.image("fisura_point") ?? UIArt.image("fisura_explain")
        Group {
            if let art {
                art.resizable().scaledToFit()
            } else {
                Image(systemName: "person.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(Color("PaletteInk"))
            }
        }
        .frame(width: 76, height: 92)
        .accessibilityHidden(true)
    }

    /// Vive DENTRO del globo: suelto arriba a la derecha se apoyaba sobre el
    /// carrito y el contador de monedas, que son controles que el tutorial
    /// ilumina dos pasos después.
    private var skipButton: some View {
        Button(action: onSkip) {
            Text("tutorial.skip")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color("PaletteInk").opacity(0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color("PaletteInk").opacity(0.09)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tutorial.skip")
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color("PaletteOrange") : Color("PaletteInk").opacity(0.22))
                    .frame(width: i == index ? 18 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("tutorial.progress.label"))
        .accessibilityValue(Text(verbatim: "\(index + 1)/\(total)"))
    }
}
