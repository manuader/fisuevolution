import EconomyKit
import SwiftUI

/// El campo del nombre del ranking: lo que se escribe pasa por `NameRules.filterTyping`, así que
/// los caracteres que el servidor rechazaría directamente no se pueden tipear.
struct RankingNameField: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: Tokens.s4) {
            TextField(text: $text) {
                Text("ranking.entry.placeholder")
            }
            .font(Tokens.title)
            .foregroundStyle(Color("PaletteInk"))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit(onSubmit)
            .onChange(of: text) { _, typed in
                let allowed = NameRules.filterTyping(typed)
                if allowed != typed { text = allowed }
            }
            .padding(.horizontal, Tokens.s12)
            .padding(.vertical, Tokens.s8 + 2)
            .background(
                RoundedRectangle(cornerRadius: CardMaterials.cornerRadius - 4, style: .continuous)
                    .fill(Color("PaletteCream"))
                    .overlay(
                        RoundedRectangle(cornerRadius: CardMaterials.cornerRadius - 4, style: .continuous)
                            .strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 2)
                    )
            )
            .accessibilityIdentifier("ranking.entry.name")
            .accessibilityLabel(Text("ranking.entry.name.ax"))
            let count = "\(text.unicodeScalars.count)/\(NameRules.maxLength)"
            Text(verbatim: count)
                .font(Tokens.caption)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                .accessibilityIdentifier("ranking.entry.counter")
                .accessibilityLabel(Text("ranking.entry.counter.ax"))
                .accessibilityValue(Text(verbatim: count))
        }
    }
}
