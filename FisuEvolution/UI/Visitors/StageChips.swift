import EconomyKit
import SwiftUI

/// La tarjeta del personaje especial (PLAN-v2 E14 C3): el primer lugar de la
/// columna de la derecha, compacta, el objetivo de toque determinista y
/// accesible de quien está en escena. La escena también se toca, pero un nodo de
/// SpriteKit que camina no es un control para VoiceOver.
struct StageChips: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let visit = gameState.stageVisit, visit.phase == .waiting,
               visit.offer != nil, gameState.stageChallenge == nil {
                VisitorChip(visit: visit) { gameState.openVisitorPopup() }
                    .transition(.scale(scale: 0.7, anchor: .topTrailing).combined(with: .opacity))
            }
            if let challenge = gameState.stageChallenge, let visit = gameState.stageVisit {
                ChallengeChip(challenge: challenge, visitorId: visit.actorId)
                    .transition(.scale(scale: 0.7, anchor: .topTrailing).combined(with: .opacity))
            }
            // La lista sólo cambia al cambiar de piso, que sube `boardVersion`.
            let _ = gameState.boardVersion
            let waiting = gameState.visitorsWaitingElsewhere
            if let first = waiting.first {
                WaitingVisitorsChip(first: first, count: waiting.count) {
                    gameState.attendWaitingVisitor(onFloor: first.floorOrdinal)
                }
                .transition(.scale(scale: 0.7, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: gameState.stageVisit?.offer != nil)
        .animation(.spring(duration: 0.3), value: gameState.visibleFloorOrdinal)
    }
}

enum SpecialCardLayout {
    static let face: CGFloat = 52
    static let touch: CGFloat = 62
}

/// La cara de quien espera con un "!" que late, en la esquina de arriba a la
/// derecha. Sin nombre en pantalla: la cara es la tarjeta y VoiceOver lo lee.
struct VisitorChip: View {
    let visit: StageVisit
    let action: () -> Void
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var name: String {
        gameState.content?.visitors.visitor(id: visit.actorId).map { VisitCopy.name(of: $0) } ?? ""
    }

    var body: some View {
        Button(action: action) {
            VisitorFace(visitorId: visit.actorId, side: SpecialCardLayout.face)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .overlay(alignment: .topLeading) {
                    SideRailBadge(text: "!")
                        .scaleEffect(pulse ? 1.15 : 0.95)
                        .offset(x: -6, y: -4)
                }
                .frame(width: SpecialCardLayout.touch, height: SpecialCardLayout.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stage.chip.visitor")
        .accessibilityLabel(Text("visit.chip.ax \(name)"))
        .tutorialAnchor(.visitor)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// Los que esperan congelados en otros pisos (E14b B7, D6): una sola tarjeta,
/// la cara del de más arriba con «×N» si son varios, y no una por piso. Tocarla
/// lleva a su piso y abre su popup: desde acá se lo despacha.
struct WaitingVisitorsChip: View {
    let first: FloorVisitor
    let count: Int
    let action: () -> Void
    @Environment(GameState.self) private var gameState

    private var name: String {
        gameState.content?.visitors.visitor(id: first.visitorId).map { VisitCopy.name(of: $0) } ?? ""
    }

    var body: some View {
        Button(action: action) {
            VisitorFace(visitorId: first.visitorId, side: SpecialCardLayout.face - 8)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .overlay(alignment: .topLeading) {
                    SideRailBadge(text: count > 1 ? "×\(count)" : "!")
                        .offset(x: -6, y: -4)
                }
                .overlay(alignment: .bottom) {
                    Text(verbatim: String(first.floorOrdinal + 1))
                        .font(.system(size: 12, design: .rounded).weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, Tokens.s4)
                        .frame(minWidth: 22, minHeight: 18)
                        .background(PillBackground(fill: Color("PaletteBlue"), lip: 2))
                        .offset(y: 8)
                        .accessibilityHidden(true)
                }
                .frame(width: SpecialCardLayout.touch, height: SpecialCardLayout.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stage.chip.waiting")
        .accessibilityLabel(Text("visit.waiting.ax \(name) \(String(first.floorOrdinal + 1))"))
        .accessibilityValue(Text(verbatim: String(count)))
    }
}

/// El reto en curso: la cara de quien lo propuso con un aro del tiempo que
/// queda (el del reloj del juego, no el de pared) y, debajo, "12/15". No es un
/// botón: los toques van a los empleados.
struct ChallengeChip: View {
    let challenge: StageChallenge
    let visitorId: String
    @Environment(GameState.self) private var gameState
    @State private var clock: TimeInterval?

    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        let remaining = challenge.remaining(at: clock ?? gameState.stageRuntime.challengeClock)
        VStack(spacing: -6) {
            ZStack {
                Circle()
                    .trim(from: 0, to: remaining / max(challenge.terms.windowSeconds, 1))
                    .stroke(Color("PaletteOrange"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VisitorFace(visitorId: visitorId, side: SpecialCardLayout.face - 10)
            }
            .frame(width: SpecialCardLayout.face, height: SpecialCardLayout.face)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            Text(verbatim: "\(challenge.taps)/\(challenge.terms.taps)")
                .font(.system(size: 13, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, Tokens.s4)
                .frame(minWidth: SpecialCardLayout.face, minHeight: SideRailLayout.ribbonHeight)
                .background(PillBackground(fill: Color("PaletteOrange"), lip: 2))
        }
        .frame(width: SpecialCardLayout.touch)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("stage.chip.challenge")
        .accessibilityLabel(Text("visit.challenge.ax \(challenge.taps) \(challenge.terms.taps)"))
        .accessibilityValue(Text(verbatim: "\(Int(remaining.rounded(.up)))s"))
        .onReceive(timer) { _ in clock = gameState.stageRuntime.challengeClock }
    }
}
