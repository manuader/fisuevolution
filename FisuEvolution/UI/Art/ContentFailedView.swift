import SwiftUI

/// La pantalla de "el contenido del juego no cargó" (RootView, fase `.failed`):
/// el glifo de aviso de la casa, el título y el motivo. Reemplaza al
/// `ContentUnavailableView` del sistema, que llevaba un SF Symbol (E14 C19).
struct ContentFailedView: View {
    let message: String

    var body: some View {
        VStack(spacing: Tokens.s12) {
            GameGlyphView(glyph: .warning, size: 56)
            Text("error.content.title")
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
            Text(verbatim: message)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("PaletteParchment").ignoresSafeArea())
        .accessibilityElement(children: .combine)
    }
}
