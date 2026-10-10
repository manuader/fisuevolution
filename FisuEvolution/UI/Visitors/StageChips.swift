import SwiftUI

/// Los chips del escenario, bajo el HUD (PLAN-v2 E4): el objetivo de toque
/// determinista y accesible de quien está en escena. La escena también se toca,
/// pero un nodo de SpriteKit que camina no es un control para VoiceOver.
struct StageChips: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        Group {
            if let visit = gameState.stageVisit, visit.phase == .waiting,
               visit.offer != nil, gameState.stageChallenge == nil {
                VisitorChip(visit: visit) { gameState.openVisitorPopup() }
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
            if let challenge = gameState.stageChallenge, let visit = gameState.stageVisit {
                ChallengeChip(challenge: challenge, visitorId: visit.actorId)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: gameState.stageVisit?.offer != nil)
    }
}

/// La cara de quien espera, su nombre y un "!" que late.
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
            HStack(spacing: 8) {
                VisitorFace(visitorId: visit.actorId, side: 38)
                Text(verbatim: name)
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color("PaletteOrange"))
                    .scaleEffect(pulse ? 1.15 : 1)
            }
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            )
            .contentShape(Capsule())
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

/// El reto en curso: la cara de quien lo propuso, la consigna, "12/15" y un aro
/// con el tiempo que queda (el del reloj del juego, no el de pared). No es un
/// botón: los toques van a los empleados.
struct ChallengeChip: View {
    let challenge: StageChallenge
    let visitorId: String
    @Environment(GameState.self) private var gameState
    @State private var clock: TimeInterval?

    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        let remaining = challenge.remaining(at: clock ?? gameState.stageRuntime.challengeClock)
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .trim(from: 0, to: remaining / max(challenge.terms.windowSeconds, 1))
                    .stroke(Color("PaletteOrange"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VisitorFace(visitorId: visitorId, side: 32)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("visit.challenge.hint")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.75))
                Text(verbatim: "\(challenge.taps)/\(challenge.terms.taps)")
                    .font(.system(size: 20, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk"))
            }
            Text(verbatim: "\(Int(remaining.rounded(.up)))s")
                .font(.system(size: 13, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color("PaletteOrange"))
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color("PaletteCream"))
                .overlay(Capsule().strokeBorder(Color("PaletteOrange"), lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("stage.chip.challenge")
        .accessibilityLabel(Text("visit.challenge.ax \(challenge.taps) \(challenge.terms.taps)"))
        .onReceive(timer) { _ in clock = gameState.stageRuntime.challengeClock }
    }
}
