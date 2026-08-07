import EconomyKit
import SwiftUI

/// The T9 career fork (bible §1): "Te recibiste en la UBA. ¿Ahora qué?".
/// Selection completes the deferred merge; the choice lasts until reincarnation.
struct CareerChoiceView: View {
    @Environment(GameState.self) private var gameState
    let prompt: GameState.CareerPrompt

    var body: some View {
        GamePanel(art: "panel_career", insets: EdgeInsets(top: 74, leading: 24, bottom: 26, trailing: 24)) {
            VStack(spacing: 20) {
                Text("career.title")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                Text("career.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // La recompensa se muestra ANTES de tocar (RF-15): una elección a
                // ciegas entre cuatro botones idénticos no es una elección.
                let rewards = gameState.careerRewards
                ForEach(prompt.options) { option in
                    Button {
                        gameState.chooseCareer(optionId: option.id)
                    } label: {
                        VStack(spacing: 3) {
                            Text(verbatim: option.displayName)
                                .font(.headline)
                            if let reward = rewards[option.id] {
                                Text(verbatim: reward.previewText)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .opacity(0.85)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("PaletteBlue"))
                    .accessibilityIdentifier("career.option.\(option.id)")
                }
            }
        }
        .padding(16)
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}
