import EconomyKit
import SwiftUI

/// "Mis partidas": las llegadas a Dios de esta instalación, con sus dos tiempos y el estado del nombre.
/// Se empuja en el `NavigationStack` de la pestaña, como Ajustes en el Menú.
struct MyRunsView: View {
    let store: RankingStore

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.s12) {
                if store.myRuns.isEmpty {
                    Text("ranking.mine.empty")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk").opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, Tokens.s24)
                        .accessibilityIdentifier("ranking.mine.empty")
                }
                ForEach(store.myRuns, id: \.runId) { run in
                    MyRunCard(run: run)
                }
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.top, Tokens.s12)
            .padding(.bottom, Tokens.s24)
        }
        .panelSheet { PanelTitleBanner(titleKey: "ranking.mine.title") }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.refreshBoard(mine: true) }
    }
}

private struct MyRunCard: View {
    let run: MyRun

    private var statusKey: LocalizedStringKey? {
        if run.status == .review { return "ranking.mine.review" }
        switch run.nameStatus {
        case .ok: return nil
        case .pending: return "ranking.mine.pending"
        case .rejected: return "ranking.mine.rejected"
        case .missing: return "ranking.mine.missing"
        }
    }

    var body: some View {
        let date = Date(timeIntervalSince1970: run.finishedAt ?? run.startedAt)
        GameCard(style: .normal) {
            VStack(alignment: .leading, spacing: Tokens.s4) {
                HStack {
                    Text(verbatim: RankingCopy.displayName(run.name))
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: Tokens.s8)
                    Text(date, format: .dateTime.day().month().year())
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.65))
                }
                if let real = run.realSeconds {
                    HStack {
                        Text(verbatim: RankingCopy.duration(real))
                            .font(Tokens.body)
                            .monospacedDigit()
                            .foregroundStyle(Color("PaletteInk"))
                        if let played = run.playedSeconds {
                            Text(verbatim: RankingCopy.played(played))
                                .font(Tokens.caption)
                                .monospacedDigit()
                                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                        }
                    }
                } else {
                    Text("ranking.mine.running")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk").opacity(0.75))
                }
                if let statusKey {
                    Text(statusKey)
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.75))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ranking.mine.\(run.runId)")
    }
}
