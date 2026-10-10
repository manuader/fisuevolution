import SwiftUI

/// Las probabilidades a la vista (Apple 3.1.1): la ruleta, el colchón y —en E6—
/// el cofre por ORO las muestran con esto, y siempre es la tabla con la que se
/// sortea.
struct OddsDisclosureView: View {
    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let symbol: String
        let probability: Double
    }

    let titleKey: LocalizedStringKey
    let rows: [Row]
    let identifier: String

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(titleKey)
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                ForEach(rows) { row in
                    HStack(spacing: Tokens.s8) {
                        Image(systemName: row.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 22)
                        Text(verbatim: row.title)
                            .font(Tokens.body)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: Tokens.s8)
                        Text(verbatim: Self.percent(row.probability))
                            .font(Tokens.body)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color("PaletteInk"))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("\(identifier).\(row.id)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "18 %", "2,5 %": sin decimales de más.
    nonisolated static func percent(_ probability: Double) -> String {
        probability.formatted(.percent.precision(.fractionLength(0...1)))
    }
}
