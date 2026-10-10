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
