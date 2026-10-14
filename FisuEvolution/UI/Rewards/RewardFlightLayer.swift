import SwiftUI

/// La capa de los vuelos de recompensa (E14b B13): un overlay a pantalla completa
/// sobre el juego que no come toques. Es un `ViewModifier` porque
/// `RootView.body` está al límite del type-checker.
struct RewardFlightLayer: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay { RewardFlightCanvas() }
    }
}

private struct RewardFlightCanvas: View {
    @Environment(GameState.self) private var gameState
    @Environment(AudioManager.self) private var audio
    private let center = RewardFlightCenter.shared

    var body: some View {
        GeometryReader { proxy in
            let geometry = RewardFlightGeometry(
                size: proxy.size,
                layerOrigin: proxy.frame(in: .global).origin,
                anchors: center.anchors
            )
            ZStack {
                ForEach(center.batches) { batch in
                    RewardFlightBatchView(batch: batch, geometry: geometry)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: center.landings) { _, landings in
            // Cada moneda que llega suena un poco más aguda; el haptic, uno de cada dos.
            audio.play(.coin, rate: 1 + Float(landings % 6) * 0.05)
            if landings.isMultiple(of: 2) { gameState.playHaptic(.tick) }
        }
    }
}

private struct RewardFlightBatchView: View {
    let batch: RewardFlightBatch
    let geometry: RewardFlightGeometry

    private static let slotStep: CGFloat = 50

    var body: some View {
        let start = geometry.point(for: batch.origin)
        ZStack {
            if !batch.labels.isEmpty {
                RewardFlightLabels(labels: batch.labels, delay: batch.delay)
                    .position(x: start.x, y: start.y - CGFloat(batch.slot) * Self.slotStep)
            }
            ForEach(batch.particles) { particle in
                RewardFlightParticleView(
                    particle: particle, start: start, end: geometry.target(for: particle.destination)
                )
            }
        }
    }
}

/// El rótulo grande con el monto: entra con un resorte, sube un poco y se va. Con
/// Reduce Motion sólo aparece y se desvanece, sin escala ni desplazamiento.
private struct RewardFlightLabels: View {
    let labels: [RewardFlightLabel]
    let delay: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var gone = false

    var body: some View {
        VStack(spacing: Tokens.s4) {
            ForEach(labels) { label in
                HStack(spacing: Tokens.s4) {
                    RewardArt(kind: label.kind).frame(width: 30, height: 30)
                    Text(verbatim: label.text)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(label.kind == .blue ? Color("PaletteBlue") : Color("PaletteYellow"))
                        .shadow(color: Color("PaletteInk"), radius: 0, x: 1.5, y: 1.5)
                        .shadow(color: Color("PaletteInk"), radius: 0, x: -1.5, y: -1.5)
                        .shadow(color: Color("PaletteInk"), radius: 0, x: 1.5, y: -1.5)
                        .shadow(color: Color("PaletteInk"), radius: 0, x: -1.5, y: 1.5)
                }
            }
        }
        .opacity(shown && !gone ? 1 : 0)
        .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.5))
        .offset(y: reduceMotion ? 0 : (gone ? -34 : 0))
        .task {
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.35, bounce: 0.45)) {
                shown = true
            }
            try? await Task.sleep(for: .seconds(RewardFlightTiming.labelSeconds - 0.4))
            withAnimation(.easeOut(duration: 0.35)) { gone = true }
        }
    }
}

/// Una moneda en el aire: sigue una curva desde el origen hasta el contador,
/// achicándose, y avisa al centro cuando llega.
private struct RewardFlightParticleView: View {
    let particle: RewardFlightParticle
    let start: CGPoint
    let end: CGPoint
    @State private var progress: CGFloat = 0

    var body: some View {
        RewardArt(kind: particle.kind)
            .frame(width: 30, height: 30)
            .modifier(FlightPath(progress: progress, start: start, control: control, end: end))
            .onAppear {
                withAnimation(
                    .easeIn(duration: RewardFlightTiming.flight).delay(particle.delay),
                    completionCriteria: .logicallyComplete
                ) {
                    progress = 1
                } completion: {
                    RewardFlightCenter.shared.land(particle.id)
                }
            }
    }

    /// El punto de control: a un costado del tramo, distinto por moneda, para que
    /// el chorro abanique en vez de ir en fila.
    private var control: CGPoint {
        let spread = CGFloat(particle.index) - CGFloat(particle.count - 1) / 2
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        return CGPoint(x: mid.x + spread * 34, y: mid.y + 40 - abs(spread) * 6)
    }
}

/// Posición, escala y opacidad a lo largo de una curva cuadrática, en función del progreso.
private struct FlightPath: ViewModifier, Animatable {
    var progress: CGFloat
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = progress
        let u = 1 - t
        let point = CGPoint(
            x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
            y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
        )
        return content
            .scaleEffect(1.15 - 0.5 * t)
            .opacity(t <= 0.001 ? 0 : 1)
            .position(point)
    }
}

// MARK: - Anclas de destino

extension View {
    /// Registra dónde está este control para que los premios vuelen hasta él.
    func rewardFlightAnchor(_ destination: RewardFlightDestination) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            RewardFlightCenter.shared.anchors[destination] = frame
        }
    }
}
