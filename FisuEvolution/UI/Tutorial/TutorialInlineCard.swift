import SwiftUI

/// La primera vez, adentro de su popup (PLAN-v2 E9): un velo sobre el contenido y la tarjeta
/// del tutorial con su candado. Hasta "Entendido", lo de abajo no se toca.
struct TutorialInlineCard: View {
    let lesson: TutorialInlineLesson
    @Environment(GameState.self) private var gameState

    var body: some View {
        if let run = gameState.tutorialRun, run.lessonID == lesson.rawValue, let step = run.step {
            ZStack {
                Color("PaletteInk").opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture {}
                    .accessibilityHidden(true)
                TutorialCard(step: step, index: run.index, total: run.steps.count, unlocked: run.unlocked,
                             lockProgress: { gameState.tutorialLockProgress }, confirmKey: "tutorial.confirm",
                             onConfirm: gameState.confirmTutorialStep, onEnd: nil, compact: true)
                    .padding(.horizontal, 12)
            }
            .background(
                Color.clear.frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("tutorial.inline")
                    .accessibilityValue(Text(verbatim: lesson.rawValue))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
            )
            .transition(.opacity)
        }
    }
}

private struct InlineLessonModifier: ViewModifier {
    let lesson: TutorialInlineLesson
    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content
            .overlay { TutorialInlineCard(lesson: lesson) }
            .onAppear { gameState.beginInlineLesson(lesson) }
            .onDisappear { gameState.endInlineLesson(lesson) }
    }
}

extension View {
    /// Aloja la primera vez de `lesson` adentro de este popup.
    func inlineLesson(_ lesson: TutorialInlineLesson) -> some View {
        modifier(InlineLessonModifier(lesson: lesson))
    }
}
