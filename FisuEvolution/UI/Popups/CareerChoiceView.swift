import EconomyKit
import SwiftUI

/// The T9 career fork (bible §1): "Te recibiste en la UBA. ¿Ahora qué?".
/// Selection completes the deferred merge; the choice lasts until reincarnation.
struct CareerChoiceView: View {
    @Environment(GameState.self) private var gameState
    let prompt: GameState.CareerPrompt

    var body: some View {
        VStack(spacing: 20) {
            Text("career.title")
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
            Text("career.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ForEach(prompt.options) { option in
                Button {
                    gameState.chooseCareer(optionId: option.id)
                } label: {
                    Text(verbatim: option.displayName)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteBlue"))
            }
        }
        .padding(24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
