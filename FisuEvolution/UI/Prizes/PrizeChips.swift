import SwiftUI

/// La caja de la Aduana dibujada, mientras no llegue `pickup_package` (E8).
struct PackageGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color("PaletteBrown"))
            Rectangle().fill(Color("PaletteYellow")).frame(width: 5)
            Rectangle().fill(Color("PaletteYellow")).frame(height: 5)
            RoundedRectangle(cornerRadius: 4).strokeBorder(Color("PaletteInk"), lineWidth: 1.5)
        }
        .padding(3)
        .accessibilityHidden(true)
    }
}

/// El colchón dibujado, mientras no llegue `pickup_mattress` (E8).
struct MattressGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color("PaletteBlue").opacity(0.8))
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color("PaletteCream")).frame(width: 4, height: 4)
                }
            }
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color("PaletteInk"), lineWidth: 1.5)
        }
        .aspectRatio(1.6, contentMode: .fit)
        .padding(2)
        .accessibilityHidden(true)
    }
}
