import SwiftUI

/// El coach-mark de las lecciones contextuales: un globo compacto del Fisura y
/// un anillo latiendo sobre el control que señala. **Sin scrim y sin bloquear
/// un solo toque**: una lección nunca congela el juego — el jugador puede
/// ignorarla, saltearla con un tap al tablero, o hacer lo que señala (que es la
/// salida buena: abrir el destino la da por cumplida, `tutorialTipHandled`).
///
/// Se muestra cuando la cola le da el turno a `.tutorialTip` — nunca compite
/// con un reveal, un premio ni un toast, y nunca convive con la fase
/// obligatoria (el director no dispara lecciones hasta que la fase termina).
struct TutorialTipView: View {
    /// Los mismos frames reales que usa `TutorialOverlay`, resueltos por el
    /// `GeometryProxy` de `RootView`. Nunca coordenadas escritas a mano.
    let anchors: [TutorialTarget: CGRect]

    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // El `ZStack` montado SIEMPRE + `.animation(value:)` en el padre es lo
        // que hace correr la `.transition` de la inserción (la lección que los
        // dos toasts de `RootView` ya pagaron: declarada adentro, está muerta).
        ZStack {
            if let tip = visibleTip {
                marks(tip)
                    .transition(reduceMotion
                        ? .opacity
                        : .scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(motion(.spring(duration: 0.38, bounce: 0.25)), value: visibleTip?.lesson)
    }

    /// La lección en pantalla: tiene el turno en la cola y nada la tapa. El
    /// director ya no dispara con una hoja abierta; este segundo chequeo cubre
    /// la carrera de "el turno llegó justo mientras una hoja subía".
    private var visibleTip: GameState.TutorialTip? {
        guard gameState.showing == .tutorialTip, !gameState.uiCoversBoard else { return nil }
        return gameState.tutorialTip
    }

    @ViewBuilder
    private func marks(_ tip: GameState.TutorialTip) -> some View {
        let anchor = anchors[tip.lesson.anchorTarget]
        GeometryReader { proxy in
            ZStack {
                if let anchor {
                    TipRing(rect: anchor.insetBy(dx: -8, dy: -8), reduceMotion: reduceMotion)
                }
                balloon(tip, anchor: anchor, screen: proxy.size)
            }
            .background(marker(tip))
        }
    }

    // MARK: El globo

    /// Del lado opuesto al control (los destinos viven en las dos barras), con
    /// el margen de las barras reales — el mismo criterio que el globo de la
    /// fase: nunca tapar lo que se está señalando.
    private func balloon(_ tip: GameState.TutorialTip, anchor: CGRect?, screen: CGSize) -> some View {
        let anchorIsLow = (anchor?.midY ?? screen.height) > screen.height / 2
        let topInset = (anchors[.hudBar]?.maxY ?? 0) + 12
        let bottomInset = anchors[.bottomBar].map { screen.height - $0.minY + 12 } ?? 40
        return VStack(spacing: 0) {
            if anchorIsLow { Spacer(minLength: 0) }
            TipBalloon(
                text: LocalizedStringKey(tip.lesson.textKey),
                onDismiss: { gameState.dismissTutorialTip() }
            )
            .padding(.horizontal, 16)
            .padding(.top, anchorIsLow ? 0 : topInset)
            .padding(.bottom, anchorIsLow ? bottomInset : 0)
            if !anchorIsLow { Spacer(minLength: 0) }
        }
    }

    /// Invisible para el jugador, medible para los tests (mismas reglas que los
    /// markers del overlay: de FONDO y de 1×1, o taparía todos los controles en
    /// el árbol de AX — trampa 9).
    private func marker(_ tip: GameState.TutorialTip) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityIdentifier("tutorial.tip")
            .accessibilityValue(Text(verbatim: tip.lesson.rawValue))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
    }

    private func motion(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// El anillo que late sobre el control señalado. Es el pariente liviano del
/// spotlight de la fase: mismo amarillo, mismo glow, pero sin scrim alrededor.
///
/// ⚠️ El pulso sigue las reglas de `TutorialHand`: es un `repeatForever`
/// disparado por el CAMBIO de `up` en `onAppear`, y con Reduce Motion `up` no
/// cambia nunca — un `repeatForever` colapsado seguiría corriendo el display
/// link toda la sesión.
private struct TipRing: View {
    let rect: CGRect
    let reduceMotion: Bool
    @State private var up = false

    var body: some View {
        RoundedRectangle(cornerRadius: min(24, min(rect.width, rect.height) / 2), style: .continuous)
            .strokeBorder(Color("PaletteYellow"), lineWidth: 3)
            .shadow(color: Color("PaletteYellow").opacity(0.75), radius: 8)
            .frame(width: rect.width, height: rect.height)
            .scaleEffect(up ? 1.07 : 1.0)
            .position(x: rect.midX, y: rect.midY)
            .animation(
                up ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
                value: up
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { up = !reduceMotion }
    }
}

/// La tarjeta del globo, en la gramática v3 a escala de coach-mark: pergamino
/// con su luz, borde tono-sobre-tono y el botón caramelo de la casa. La pose
/// pisa el borde superior de la tarjeta, como en las referencias.
private struct TipBalloon: View {
    let text: LocalizedStringKey
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            portrait
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color("PaletteInk"))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                dismissButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            shape
                .fill(Color("PaletteParchment"))
                .overlay {
                    // La luz del pergamino (v3): claridad arriba, sombra cálida
                    // abajo — la misma receta de `PanelCard`, a esta escala.
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                .clear,
                                Color("PaletteBrown").opacity(0.10),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 2.5))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
    }

    /// Sólo poses del Fisura: la sana mientras `point` no se regenere, y sin
    /// caer jamás a un SF Symbol — sin atlas no hay retrato y el globo sigue
    /// hablando solo.
    @ViewBuilder private var portrait: some View {
        if let art = UIArt.image("fisura_wave") ?? UIArt.image("fisura_celebrate") {
            art.resizable()
                .scaledToFit()
                .frame(width: 54, height: 66)
                .accessibilityHidden(true)
        }
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text("tutorial.tip.gotit")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color("PaletteInk"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(PillBackground(fill: Color("PaletteYellow")))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tutorial.tip.dismiss")
    }
}
