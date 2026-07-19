import EconomyKit
import SwiftUI
import UIKit

/// Share card vertical (bible §8): "la sátira ES el marketing". Se renderiza con
/// ImageRenderer y se comparte con UIActivityViewController — su completion
/// dispara el bonus viral (`registerShareCompleted`), cosa que ShareLink no permite.
struct ShareCardSheet: View {
    @Environment(GameState.self) private var gameState
    let subject: CharacterType
    @State private var showActivity = false

    var body: some View {
        VStack(spacing: 20) {
            ShareCardContent(subject: subject)
                .frame(width: 270, height: 480)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(radius: 8)

            Button {
                showActivity = true
            } label: {
                Label("share.button", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("PaletteBlue"))
            .accessibilityIdentifier("share.button")

            Button {
                gameState.dismissShareCard()
            } label: {
                Text("share.skip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .presentationDetents([.large])
        .sheet(isPresented: $showActivity) {
            ActivityShareView(image: renderCard()) { completed in
                if completed {
                    gameState.registerShareCompleted()
                }
                gameState.dismissShareCard()
            }
        }
    }

    @MainActor
    private func renderCard() -> UIImage {
        let renderer = ImageRenderer(content: ShareCardContent(subject: subject).frame(width: 540, height: 960))
        renderer.scale = 2 // 1080×1920, formato video vertical
        return renderer.uiImage ?? UIImage()
    }
}

/// El diseño de la card (placeholder hasta el arte de F3; el layout ya es final).
private struct ShareCardContent: View {
    let subject: CharacterType

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("PaletteYellow"), Color("PaletteOrange")],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: symbolName)
                    .font(.system(size: 110, weight: .bold))
                    .foregroundStyle(Color("PaletteInk"))
                Text(verbatim: subject.displayName.uppercased())
                    .font(.system(size: 34, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color("PaletteInk"))
                Text("share.card.caption \(subject.displayName)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color("PaletteInk").opacity(0.8))
                Spacer()
                Text(verbatim: "FisuEvolution")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color("PaletteInk").opacity(0.6))
                    .padding(.bottom, 20)
            }
            .padding(24)
        }
    }

    private var symbolName: String {
        subject.spritePlaceholder.hasPrefix("sf:") ? String(subject.spritePlaceholder.dropFirst(3)) : "person.fill"
    }
}

/// UIActivityViewController con completion real (ShareLink no la expone).
private struct ActivityShareView: UIViewControllerRepresentable {
    let image: UIImage
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
