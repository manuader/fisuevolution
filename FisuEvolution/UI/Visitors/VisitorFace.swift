import SwiftUI

/// La cara de un visitante en un círculo: la dibujada (`<id>_face`) si existe;
/// si no, la cabeza recortada de su canónica; si tampoco, su respaldo (disco con
/// símbolo). Es la cara del chip, del popup y del chip de evento (T4).
struct VisitorFace: View {
    let visitorId: String
    var side: CGFloat = 40
    @Environment(GameState.self) private var gameState

    var body: some View {
        face
            .frame(width: side, height: side)
            .background(Color("PaletteCream"))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: max(1.5, side / 22)))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var face: some View {
        if let manifest = gameState.content?.manifest, VisitorArt.hasOwnFace(visitorId, manifest: manifest),
           let image = VisitorArt.image(for: visitorId, pose: .face, manifest: manifest) {
            image.resizable().scaledToFill()
        } else if let manifest = gameState.content?.manifest,
                  let image = VisitorArt.image(for: visitorId, pose: .canonical, manifest: manifest) {
            // Sin cara dibujada: el tercio de arriba de la canónica, agrandado.
            image.resizable().scaledToFit()
                .scaleEffect(1.9, anchor: .top)
                .offset(y: side * 0.04)
        } else {
            let visitor = gameState.content?.visitors.visitor(id: visitorId)
            Image(uiImage: VisitorArt.placeholderImage(symbol: visitor?.fallbackSymbol ?? "person.fill",
                                                      tint: visitor?.fallbackTint ?? "PaletteBlue", side: side))
                .resizable()
        }
    }
}
