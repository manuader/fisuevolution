import SwiftUI

/// La manito de "tocá acá": el SF Symbol del sistema con su latido, lista para
/// apoyarse por overlay sobre CUALQUIER control que una guía señale — la fase,
/// los coach-marks de lecciones, la fila recomendada de FisuJobs, la tarjeta de
/// Logros, el "Ponérsela" de Pintas. Una sola manito para toda la app (pedido
/// del dueño, 2026-08-21): donde haya que hacer click, se ve el click.
///
/// ⚠️ Hereda las dos reglas de la mano de la fase: el latido es un
/// `repeatForever` disparado por el CAMBIO de `up` en su propio `onAppear` (si
/// el cambio ocurre antes de existir la vista, la mano queda quieta para
/// siempre), y con Reduce Motion `up` no cambia nunca (un `repeatForever`
/// colapsado deja el display link corriendo toda la sesión).
struct TapHereHand: View {
    var size: CGFloat = 40

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    var body: some View {
        HandGlyph(size: size)
            .scaleEffect(up ? 1.14 : 0.92)
            .offset(x: up ? 5 : 0, y: up ? 7 : 0)
            .animation(
                up ? .easeInOut(duration: 0.62).repeatForever(autoreverses: true) : .default,
                value: up
            )
            .onAppear { up = !reduceMotion }
    }
}

/// El dibujo de la manito, sin latido: lo comparten las tres manos.
private struct HandGlyph: View {
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: size, weight: .black))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// "Mantené apretado": la mano baja, se queda mientras un anillo se completa, y suelta.
struct HoldHand: View {
    var size: CGFloat = 40

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = self.size
        if reduceMotion {
            HandGlyph(size: size)
                .background { HoldRing(progress: 1, side: size * 1.4) }
        } else {
            HandGlyph(size: size)
                .keyframeAnimator(initialValue: HoldPose(), repeating: true) { content, pose in
                    content
                        .scaleEffect(pose.scale)
                        .background { HoldRing(progress: pose.ring, side: size * 1.4) }
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(0.9, duration: 0.25)
                        LinearKeyframe(0.9, duration: 1.0)
                        SpringKeyframe(1.0, duration: 0.35)
                    }
                    KeyframeTrack(\.ring) {
                        LinearKeyframe(0, duration: 0.25)
                        LinearKeyframe(1, duration: 1.0)
                        LinearKeyframe(0, duration: 0.35)
                    }
                }
        }
    }

    private struct HoldPose {
        var scale: CGFloat = 1
        var ring: CGFloat = 0
    }
}

/// El anillo que se completa mientras la mano aprieta.
private struct HoldRing: View {
    let progress: CGFloat
    let side: CGFloat

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(Color("PaletteYellow"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: side, height: side)
    }
}

/// "Deslizá": la mano viaja en la dirección del gesto y vuelve a empezar.
struct SwipeHand: View {
    let direction: TutorialStep.SwipeDirection
    var size: CGFloat = 40
    var distance: CGFloat = 90

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            HStack(spacing: 6) {
                Image(systemName: arrow)
                    .font(.system(size: size * 0.6, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                HandGlyph(size: size)
            }
            .accessibilityHidden(true)
        } else {
            let vector = self.vector
            let distance = self.distance
            HandGlyph(size: size)
                .keyframeAnimator(initialValue: 0.0, repeating: true) { content, travel in
                    content
                        .offset(x: vector.dx * distance * travel, y: vector.dy * distance * travel)
                        .opacity(travel > 0.95 ? 0 : 1)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0, duration: 0.2)
                        CubicKeyframe(1, duration: 0.9)
                        LinearKeyframe(1, duration: 0.25)
                    }
                }
        }
    }

    private var vector: CGVector {
        switch direction {
        case .left: CGVector(dx: -1, dy: 0)
        case .right: CGVector(dx: 1, dy: 0)
        case .up: CGVector(dx: 0, dy: -1)
        case .down: CGVector(dx: 0, dy: 1)
        }
    }

    private var arrow: String {
        switch direction {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
    }
}

/// La mano del paso, acomodada al recorte. Tocar y mantener señalan un control: sin recorte no
/// hay nada que señalar y no se dibujan. Deslizar es un gesto sobre una superficie ("deslizá el
/// tablero"): sin recorte va al centro de la pantalla. `insistent` es la mano del vigilante del
/// núcleo (el paso lleva 3 min sin cumplirse): la misma, más grande.
struct TutorialHandView: View {
    let hand: TutorialStep.Hand
    let hole: CGRect
    let screen: CGSize
    var insistent = false

    private static let size: CGFloat = 46
    private static let insistentSize: CGFloat = 64

    private var size: CGFloat { insistent ? Self.insistentSize : Self.size }
    private var hasHole: Bool { SpotlightShape.isDrawable(hole) }

    var body: some View {
        switch hand {
        case .none:
            EmptyView()
        case .tap:
            if hasHole { TapHereHand(size: size).position(position) }
        case .hold:
            if hasHole { HoldHand(size: size).position(position) }
        case .swipe(let direction):
            SwipeHand(direction: direction, size: size).position(position)
        }
    }

    /// Nunca se sale de la pantalla: el botón de contratar vive pegado al borde de abajo.
    private var position: CGPoint {
        guard hasHole else { return CGPoint(x: screen.width / 2, y: screen.height * 0.55) }
        return CGPoint(
            x: min(max(hole.maxX - 6, size), screen.width - size / 2),
            y: min(max(hole.maxY - 2, size), screen.height - size)
        )
    }
}
