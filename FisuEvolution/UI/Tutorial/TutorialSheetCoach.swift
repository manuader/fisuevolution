import SwiftUI

/// El tutorial adentro de una hoja (PLAN-v2 E9). Una hoja es otra presentación: sus anclas no
/// llegan al overlay de la raíz, así que cada hoja monta el suyo. Sin scrim —la hoja sigue
/// siendo usable, y así nunca hay dos scrims— y con el mismo arbitraje que el overlay:
/// `tutorialStepIsVisible` exige el turno (`nil` en el núcleo, `.tutorialTip` en lo demás) y la
/// página o la ficha abierta del paso. Si el jugador cierra la hoja sin hacerlo, el director
/// vuelve al paso que la abre.
private struct TutorialSheetCoach: ViewModifier {
    let surface: TutorialStep.Surface

    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let run = gameState.tutorialRun, gameState.tutorialStepIsVisible,
                   let step = run.step, step.surface == surface {
                    coach(run, step, hole: hole(for: step, anchors: anchors, in: proxy), screen: proxy.size)
                }
            }
        }
    }

    private func hole(for step: TutorialStep, anchors: [TutorialTarget: Anchor<CGRect>], in proxy: GeometryProxy) -> CGRect {
        guard let target = step.target, let anchor = anchors[target] else { return .null }
        let rect = proxy[anchor]
        return SpotlightShape.isDrawable(rect) ? rect.insetBy(dx: -8, dy: -8) : .null
    }

    private func coach(_ run: TutorialRun, _ step: TutorialStep, hole: CGRect, screen: CGSize) -> some View {
        let hasHole = SpotlightShape.isDrawable(hole)
        let insistent = run.nudges > 0
        // La tarjeta va del lado opuesto al recorte: nunca tapa lo que pide tocar.
        let cardOnTop = hasHole && hole.midY > screen.height / 2
        return ZStack {
            if hasHole { ring(hole, insistent: insistent) }
            TutorialHandView(hand: step.hand, hole: hole, screen: screen, insistent: insistent)
            VStack(spacing: 0) {
                if !cardOnTop { Spacer(minLength: 0) }
                TutorialCard(
                    step: step, index: run.index, total: run.steps.count, unlocked: run.unlocked,
                    lockProgress: { gameState.tutorialLockProgress },
                    confirmKey: "tutorial.confirm", onConfirm: gameState.confirmTutorialStep,
                    compact: true
                )
                .frame(maxWidth: PlayColumn.tutorialCardMaxWidth)
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
                // Un paso de acción no tiene botón: la tarjeta no puede comerse el toque de la hoja.
                .allowsHitTesting(step.clockKind == .explain)
                if cardOnTop { Spacer(minLength: 0) }
            }
        }
        .background(marker(step))
    }

    private func ring(_ hole: CGRect, insistent: Bool) -> some View {
        RoundedRectangle(cornerRadius: min(24, min(hole.width, hole.height) / 2), style: .continuous)
            .strokeBorder(Color("PaletteYellow"), lineWidth: insistent ? 6 : 3)
            .shadow(color: Color("PaletteYellow").opacity(insistent ? 1 : 0.75), radius: insistent ? 14 : 8)
            .frame(width: hole.width, height: hole.height)
            .position(x: hole.midX, y: hole.midY)
            .allowsHitTesting(false)
    }

    /// El marcador para los tests de UI (valor: el id del paso, sin traducir). Va de fondo y de 1×1
    /// por la misma razón que los del overlay: uno a pantalla completa taparía los controles de
    /// la hoja en el árbol de accesibilidad.
    private func marker(_ step: TutorialStep) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityIdentifier("tutorial.coach")
            .accessibilityValue(Text(verbatim: step.id))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Monta el coach del tutorial para los pasos cuya superficie es `surface`.
    func tutorialSheetCoach(_ surface: TutorialStep.Surface) -> some View {
        modifier(TutorialSheetCoach(surface: surface))
    }
}
