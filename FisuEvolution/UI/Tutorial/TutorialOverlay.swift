import SwiftUI

/// Tutorial narrado por El Fisura (estilo Clash of Clans): scrim oscuro + una
/// pose del Fisura abajo-izquierda + burbuja de diálogo con el texto del paso.
/// Se toca para avanzar. Aparece una sola vez (AppStorage) y se puede saltear.
/// Es un overlay autónomo: no toca la economía ni el GameState.
struct TutorialOverlay: View {
    @AppStorage("fisuTutorialDone") private var done = false
    @State private var step = 0

    private struct Step { let pose: String; let text: String }
    private let steps: [Step] = [
        .init(pose: "fisura_wave",
              text: "¡Hola! Soy El Fisura. Tocame para juntar plata. 💰"),
        .init(pose: "fisura_explain",
              text: "¿Ves dos iguales? Arrastrá uno sobre el otro y evolucionan a algo mejor."),
        .init(pose: "fisura_point",
              text: "Con el botón verde de abajo contratás más changos para el barrio."),
        .init(pose: "fisura_explain",
              text: "En Tienda y Mejoras potenciás tus ganancias. ¡No seas amarrete!"),
        .init(pose: "fisura_celebrate",
              text: "¡Listo, capo! El barrio cuenta con vos. A hacerse millonario. 🚀"),
    ]

    var body: some View {
        if !done, step < steps.count {
            overlay(steps[step])
                .transition(.opacity)
        }
    }

    private func overlay(_ current: Step) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { advance() }

            VStack(spacing: 0) {
                Spacer()
                SpeechBubble(text: current.text)
                    .padding(.bottom, 4)
                HStack(alignment: .bottom, spacing: 0) {
                    fisura(current.pose)
                    Spacer()
                    VStack(spacing: 10) {
                        progressDots
                        Text(verbatim: "tocá para seguir ▸")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 48)
                }
            }
            .padding(.bottom, 6)

            skipButton
        }
        .id(step)  // reinicia la transición por paso
    }

    /// El Fisura grande y protagonista (bottom-left).
    @ViewBuilder private func fisura(_ pose: String) -> some View {
        let art = UIArt.image(pose)
            ?? UIArt.image("fisura_point")
            ?? UIArt.image("fisura_explain")
        Group {
            if let art {
                art.resizable().scaledToFit()
            } else {
                Image(systemName: "person.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 300, height: 380)
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color("PaletteYellow") : Color.white.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    finish()
                } label: {
                    Text(verbatim: "Saltar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.18), in: .capsule)
                }
                .accessibilityIdentifier("tutorial.skip")
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if step + 1 >= steps.count { finish() } else { step += 1 }
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.3)) { done = true }
    }
}
