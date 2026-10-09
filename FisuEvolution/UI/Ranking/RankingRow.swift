import EconomyKit
import SwiftUI

/// Una fila del ranking: puesto, nombre, tiempo real y tiempo jugado. La propia va resaltada; las
/// ajenas se pueden reportar (menú contextual y acción de accesibilidad).
struct RankingRow: View {
    enum Placement {
        case top
        case pinned
    }

    let row: LeaderboardRow
    var placement: Placement = .top
    let onReport: (LeaderboardRow) -> Void

    private var identifier: String {
        if placement == .pinned { return "ranking.row.pinned" }
        return row.isMe ? "ranking.row.me" : "ranking.row.\(row.rank)"
    }

    var body: some View {
        let name = RankingCopy.displayName(row.name)
        let real = RankingCopy.duration(row.realSeconds)
        let played = RankingCopy.played(row.playedSeconds)
        HStack(spacing: Tokens.s12) {
            Text(verbatim: "#\(row.rank)")
                .font(Tokens.title)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 46, alignment: .leading)
            Text(verbatim: name)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 0) {
                Text(verbatim: real)
                    .font(Tokens.body)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk"))
                Text(verbatim: played)
                    .font(Tokens.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk").opacity(0.65))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, row.isMe ? Tokens.s8 : 0)
        .background {
            if row.isMe {
                RoundedRectangle(cornerRadius: CardMaterials.cornerRadius - 6, style: .continuous)
                    .fill(Color("PaletteOrange").opacity(0.22))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(verbatim: "#\(row.rank) \(name)"))
        .accessibilityValue(Text(verbatim: "\(real), \(played)"))
        .contextMenu {
            if !row.isMe {
                Button { onReport(row) } label: { Label("ranking.report", systemImage: "flag") }
            }
        }
        .accessibilityActions {
            if !row.isMe {
                Button("ranking.report") { onReport(row) }
            }
        }
    }
}
