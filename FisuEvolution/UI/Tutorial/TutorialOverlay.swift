import EconomyKit
import SwiftUI

/// Tutorial interactivo (RF-01), patrón Clash of Clans: el renderer ÚNICO del
/// tutorial sobre el tablero —el núcleo, las lecciones, el Tour y el repaso—.
///
/// Cada paso recorta un agujero sobre el control **real** —resuelto por
/// `TutorialAnchorKey` para los controles de SwiftUI y por `BoardScene` para el
/// personaje del tablero— con una mano que late encima. El resto de la pantalla
/// queda oscurecido y **no responde al toque**, así que el paso sólo avanza
/// cuando el jugador ejecuta la acción que se le pide. Una lección pone un
/// scrim más liviano que el del núcleo, pero igual de firme: no se saltea
/// (PLAN-v2 §2).
///
/// El guion, el paso y el candado son del director (`GameState+Tutorial`,
/// `TutorialCurriculum.core`): esta vista sólo lee `gameState.tutorialRun`. No
/// hay "Saltar" (PLAN-v2 §2).
struct TutorialOverlay: View {
    /// Frames reales de los controles, ya resueltos por el `GeometryProxy` que
    /// monta el overlay. Nunca coordenadas escritas a mano.
    let anchors: [TutorialTarget: CGRect]

    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Cuerpo

    var body: some View {
        // El `ZStack` montado SIEMPRE + `.animation(value:)` acá es lo que hace
        // correr la transición de la entrada (declarada adentro, está muerta).
        // Sólo las lecciones entran y salen con fundido: el núcleo aparece y se
        // esconde en el acto, como siempre, alrededor del reveal del tablero.
        ZStack {
            if let run = visibleRun, let step = run.step {
                overlay(run, step)
                    .transition(.opacity)
            }
        }
        .animation(motion(.easeInOut(duration: 0.25)), value: visibleLesson)
    }

    private var visibleLesson: TutorialRun.Script? {
        visibleRun.flatMap { $0.script == .core ? nil : $0.script }
    }

    /// La corrida que se dibuja, o `nil`.
    ///
    /// Mientras una celebración tiene el turno, el overlay ENTERO se esconde
    /// —scrim, recorte, mano y globo—. Durante el núcleo la única que puede
    /// tomarlo es el reveal del tablero (`beginTutorialPhase` restringe la
    /// cola), y ése es EL momento del primer merge: se reproduce limpio, a
    /// pantalla completa y sin un segundo scrim encima. Una lección, el Tour y
    /// el repaso viajan por la cola: se dibujan sólo con SU turno
    /// (`.tutorialTip`). Regla dura: nunca dos scrims a la vez.
    ///
    /// ⚠️ Lee `showing` y no `tutorialStepIsVisible`: éste mira además
    /// `uiCoversBoard`, que no se observa. Con una hoja abierta (FisuJobs en el
    /// paso de contratar, Mejoras al cumplir su lección) la hoja se presenta
    /// por encima del overlay, que es lo correcto; esconderlo por la hoja lo
    /// dejaba escondido al cerrarla. Las tarjetas embebidas (`.embedded`) y los
    /// pasos de hoja no se dibujan acá: tienen su propio renderer.
    private var visibleRun: TutorialRun? {
        guard let run = gameState.tutorialRun, run.step?.surface == .board else { return nil }
        let turn: CelebrationKind? = run.script == .core ? nil : .tutorialTip
        return gameState.showing == turn ? run : nil
    }

    @ViewBuilder
    private func overlay(_ run: TutorialRun, _ step: TutorialStep) -> some View {
        let hole = holeRect(for: step)
        let windows = step.windows.compactMap { anchors[$0] }
        GeometryReader { proxy in
            ZStack {
                scrim(run, step, hole: hole, windows: windows)
                if SpotlightShape.isDrawable(hole) { spotlightRing(hole, insistent: run.nudges > 0) }
                TutorialHandView(hand: step.hand, hole: hole, screen: proxy.size, insistent: run.nudges > 0)
                card(run, step, hole: hole, screen: proxy.size)
            }
            .background(markers(run, step, hole: hole))
        }
        .ignoresSafeArea()
        .animation(motion(.easeInOut(duration: 0.32)), value: hole)
        // El cambio de paso entra con pop de spring (la familia del
        // `keyframeAnimator` de los tabs), no con el fundido de formulario.
        .animation(motion(.spring(duration: 0.42, bounce: 0.24)), value: run.index)
    }

    // MARK: - El recorte

    /// El agujero del paso. `.null` = sin recorte (el cierre va con el scrim
    /// entero, que es lo correcto: no pide tocar nada del juego).
    private func holeRect(for step: TutorialStep) -> CGRect {
        guard let target = step.target else { return .null }
        let rect: CGRect? = target == .boardUnit ? gameState.boardSpotlight : anchors[target]
        guard let rect, SpotlightShape.isDrawable(rect) else { return .null }
        // Un poco de aire alrededor: pegado al borde del control el recorte se
        // lee como un error de alineación.
        return rect.insetBy(dx: -10, dy: -10)
    }

    /// El scrim: el del núcleo es el más oscuro; el de una lección, más
    /// liviano, pero bloquea igual —sólo se puede hacer lo que pide—.
    @ViewBuilder
    private func scrim(_ run: TutorialRun, _ step: TutorialStep, hole: CGRect, windows: [CGRect]) -> some View {
        let shape = SpotlightShape(primary: hole, extras: windows)
        let fill = shape.fill(Color.black.opacity(Self.scrimOpacity(run)), style: FillStyle(eoFill: true))
        if run.isDemo {
            // Una demostración (Tour, repaso) sólo se mira: el agujero ilumina
            // pero no deja pasar el toque.
            fill
                .contentShape(Rectangle())
                .accessibilityIdentifier("tutorial.scrim")
                .accessibilityHidden(true)
        } else if Self.passesTouches(run, step, hole: hole) {
            // Una lección cuyo control no publicó su ancla no puede trabar el
            // juego 3 minutos detrás de un scrim sin agujero: se ve, no bloquea.
            fill
                .allowsHitTesting(false)
                .accessibilityIdentifier("tutorial.scrim")
                .accessibilityHidden(true)
        } else {
            fill
                // La MISMA forma de hit-testing: fuera del agujero el toque se lo
                // come el scrim y no llega ni al HUD ni a la escena. Es lo único que
                // impide saltear un paso sin hacer lo que pide.
                .contentShape(shape, eoFill: true)
                .accessibilityIdentifier("tutorial.scrim")
                .accessibilityHidden(true)
        }
    }

    static func scrimOpacity(_ run: TutorialRun) -> Double {
        run.script == .core ? 0.68 : 0.55
    }

    /// Una lección con un paso de acción sin recorte deja pasar el toque. El
    /// núcleo no: su cierre va sin recorte a propósito y espera su botón.
    static func passesTouches(_ run: TutorialRun, _ step: TutorialStep, hole: CGRect) -> Bool {
        run.script != .core && step.clockKind == .action && !SpotlightShape.isDrawable(hole)
    }

    /// Borde luminoso del agujero: sin esto el recorte se lee como un bache en
    /// el scrim en vez de como algo que hay que tocar.
    ///
    /// `insistent` es el paso que el vigilante del núcleo vuelve a mostrar: el mismo anillo, más
    /// grueso y con más brillo.
    private func spotlightRing(_ hole: CGRect, insistent: Bool) -> some View {
        RoundedRectangle(cornerRadius: min(28, min(hole.width, hole.height) / 2), style: .continuous)
            .strokeBorder(Color("PaletteYellow"), lineWidth: insistent ? 6 : 3)
            .shadow(color: Color("PaletteYellow").opacity(insistent ? 1 : 0.75), radius: insistent ? 18 : 10)
            .frame(width: hole.width, height: hole.height)
            .position(x: hole.midX, y: hole.midY)
            .allowsHitTesting(false)
    }

    // MARK: - El globo

    /// El globo va del lado OPUESTO al recorte, así nunca tapa el control que
    /// está pidiendo que toques, y **esquiva las dos barras de controles** con
    /// sus frames reales: apoyado sin ese margen se comía el HUD entero.
    private func card(_ run: TutorialRun, _ step: TutorialStep, hole: CGRect, screen: CGSize) -> some View {
        // Sin recorte —el cierre— no hay nada que esquivar: va centrado, que
        // es donde se lee un cierre.
        let hasHole = SpotlightShape.isDrawable(hole)
        let holeIsLow = hasHole ? hole.midY > screen.height / 2 : false
        let topInset = (anchors[.hudBar]?.maxY ?? 0) + 14
        let bottomInset = anchors[.bottomBar].map { screen.height - $0.minY + 14 } ?? 40
        // "¡Vamos!" es el cierre del núcleo; todo otro paso de explicar dice "Entendido".
        let isCoreClose = run.script == .core && run.index == run.steps.count - 1
        return VStack(spacing: 0) {
            if !holeIsLow { Spacer(minLength: 0) }
            TutorialCard(
                step: step,
                index: run.index,
                total: run.steps.count,
                unlocked: run.unlocked,
                lockProgress: { gameState.tutorialLockProgress },
                confirmKey: isCoreClose ? "tutorial.done" : "tutorial.confirm",
                onConfirm: gameState.confirmTutorialStep,
                onEnd: endAction(run),
                onClose: gameState.tutorialTipIsClosable(run) ? { gameState.closeTutorialTip() } : nil
            )
            .frame(maxWidth: PlayColumn.tutorialCardMaxWidth)
            .padding(.horizontal, 14)
            .padding(.top, holeIsLow ? topInset : 0)
            .padding(.bottom, hasHole && !holeIsLow ? bottomInset : 0)
            if holeIsLow || !hasHole { Spacer(minLength: 0) }
        }
        .transition(reduceMotion
            ? .opacity
            : .scale(scale: 0.92).combined(with: .opacity))
        .id(run.index)
    }

    /// «Terminar repaso» sólo en el repaso; el Tour y las lecciones no se terminan antes.
    private func endAction(_ run: TutorialRun) -> (() -> Void)? {
        guard run.script == .replay else { return nil }
        return { gameState.endReplay() }
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
    /// falla con "Failed to scroll to visible", incluido el botón del propio
    /// tutorial. Es la trampa 4 del HANDOFF con un disfraz nuevo: nunca es el
    /// botón, siempre es algo tapándolo. Los toques por coordenada seguían
    /// funcionando, así que el bug sólo se ve en los tests que usan `.tap()`
    /// sobre un elemento.
    ///
    /// `tutorial.tip` (valor: el id de la lección, o `tour`/`replay`) es el de
    /// las lecciones: lo leen los tests de E4b/E5b/E7b-b desde que el globo de
    /// la v1 se fue (E9a T6). El núcleo no lo publica.
    private func markers(_ run: TutorialRun, _ step: TutorialStep, hole: CGRect) -> some View {
        VStack(spacing: 2) {
            if let tip = Self.tipMarkerValue(run) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("tutorial.tip")
                    .accessibilityValue(Text(verbatim: tip))
            }
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("tutorial.step")
                .accessibilityValue(Text(verbatim: step.id))
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
                    : (step.target.map { "missing:\($0.rawValue)" } ?? "none")))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    static func tipMarkerValue(_ run: TutorialRun) -> String? {
        switch run.script {
        case .core: nil
        case .lesson(let id): id
        case .tour: "tour"
        case .replay: "replay"
        }
    }

    static func describe(_ rect: CGRect) -> String {
        guard SpotlightShape.isDrawable(rect) else { return "none" }
        return "\(Int(rect.minX.rounded())),\(Int(rect.minY.rounded()))," +
            "\(Int(rect.width.rounded())),\(Int(rect.height.rounded()))"
    }

    /// ⚠️ Con Reduce Motion las transiciones **colapsan**: se devuelve `nil`, que
    /// aplica el cambio sin animación. Es la misma regla por la que la secuencia
    /// de celebraciones encadena por completion y no por delays.
    private func motion(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}
