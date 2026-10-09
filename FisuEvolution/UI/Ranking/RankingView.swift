import EconomyKit
import SwiftUI

/// La pestaña "Ranking": el top, la fila propia siempre a la vista, el gancho hacia la Tienda, "Mis
/// partidas" y "Reportar". Lee del `RankingStore` y del `RankingState` que le pasa quien la monta; el
/// cierre `onStore` lo cablea el menú deslizable.
struct RankingView: View {
    let store: RankingStore
    let state: RankingState?
    var now: TimeInterval = Date().timeIntervalSince1970
    let onStore: () -> Void

    @State private var path = NavigationPath()
    @State private var reporting: LeaderboardRow?
    @State private var isNaming = false

    private enum Destination: Hashable { case mine }

    private var model: RankingBoardModel {
        RankingBoardModel(board: store.board, state: state, isEnabled: store.isEnabled, now: now)
    }

    var body: some View {
        let model = model
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Tokens.s12) {
                    if model.isEnabled {
                        content(model)
                    } else {
                        message("ranking.disabled", identifier: "ranking.disabled")
                    }
                }
                .padding(.horizontal, MenuView.panelInset)
                .padding(.top, Tokens.s12)
                .padding(.bottom, Tokens.s24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let pinned = model.pinned {
                    GameCard(style: .highlighted(Color("PaletteOrange"))) {
                        RankingRow(row: pinned, placement: .pinned, onReport: { _ in })
                    }
                    .padding(.horizontal, MenuView.panelInset)
                    .padding(.bottom, Tokens.s8)
                }
            }
            .panelSheet { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Destination.self) { _ in
                MyRunsView(store: store).clearNavigationBackdrop()
            }
            .task { await store.refreshBoard(mine: false) }
        }
        .overlay { overlays(model) }
        .tint(Color("PaletteInk"))
    }

    // MARK: Contenido

    @ViewBuilder private func content(_ model: RankingBoardModel) -> some View {
        if model.pendingEntry != nil {
            pendingCard
        }
        RankingHookHeader(hook: model.hook, onStore: onStore)
        if model.isStale, let fetchedAt = model.fetchedAt {
            Text(verbatim: RankingCopy.stale(fetchedAt: fetchedAt))
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("ranking.stale")
        }
        if store.board == nil {
            message("ranking.loading", identifier: "ranking.loading")
        } else if model.isEmpty {
            message("ranking.empty", identifier: "ranking.empty")
        } else {
            GameCard(style: .normal) {
                VStack(spacing: 0) {
                    ForEach(Array(model.top.enumerated()), id: \.element.runId) { offset, row in
                        if offset > 0 { RowDivider() }
                        RankingRow(row: row) { reporting = $0 }
                    }
                }
            }
        }
        NavigationLink(value: Destination.mine) {
            GameCard(style: .normal) {
                HStack {
                    Text("ranking.mine.open")
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color("PaletteInk").opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ranking.mine.open")
    }

    private func message(_ key: LocalizedStringKey, identifier: String) -> some View {
        Text(key)
            .font(Tokens.body)
            .foregroundStyle(Color("PaletteInk").opacity(0.75))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, Tokens.s24)
            .accessibilityIdentifier(identifier)
    }

    private var pendingCard: some View {
        GameCard(style: .highlighted(Color("PaletteGreen"))) {
            VStack(spacing: Tokens.s8) {
                Text("ranking.pending")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("ranking.pending")
                ActionPill(
                    titleKey: "ranking.pending.name", systemImage: "pencil",
                    identifier: "ranking.pending.name") { isNaming = true }
            }
        }
    }

    private var header: some View {
        VStack(spacing: Tokens.s4) {
            PanelTitleBanner(titleKey: "ranking.title")
            Text("ranking.subtitle")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Tokens.s24)
        }
    }

    // MARK: Tarjetas encima

    @ViewBuilder private func overlays(_ model: RankingBoardModel) -> some View {
        if let target = reporting {
            GameConfirmCard(
                titleKey: "ranking.report.confirm.title",
                message: Text("ranking.report.confirm"),
                confirmTitleKey: "ranking.report", confirmSystemImage: "flag.fill",
                cancelTitleKey: "ranking.report.cancel",
                acceptIdentifier: "ranking.report.confirm.yes", cancelIdentifier: "ranking.report.confirm.no",
                onConfirm: {
                    reporting = nil
                    Task { await store.report(runId: target.runId) }
                },
                onCancel: { reporting = nil })
        } else if isNaming, let pending = model.pendingEntry {
            RankingEntryCard(
                prompt: pending, nameError: store.nameError, isSubmitting: store.isSubmitting,
                onSubmit: { name in
                    Task {
                        await store.submit(name: name)
                        if store.nameError == nil { isNaming = false }
                    }
                },
                onLater: { isNaming = false })
        }
    }
}

#if DEBUG
@MainActor private enum RankingPreviews {
    static func row(_ rank: Int, name: String?, real: Int, isMe: Bool = false) -> LeaderboardRow {
        LeaderboardRow(
            runId: "run-\(rank)", rank: rank, name: name, realSeconds: real, playedSeconds: real * 6 / 10, isMe: isMe)
    }

    static func store(top: [LeaderboardRow], me: LeaderboardRow? = nil, myRank: Int? = nil) -> RankingStore {
        let cache = URL.temporaryDirectory.appending(path: "ranking-preview-\(UUID().uuidString).json")
        let snapshot = BoardSnapshot(top: top, me: me, myRank: myRank, fetchedAt: 4_000_000_000, isStale: false)
        try? JSONEncoder().encode(snapshot).write(to: cache)
        let config = RankingConfig(
            schemaVersion: RankingConfig.supportedSchemaVersion, enabled: true,
            baseURL: URL(string: "https://preview.invalid"), anonKey: "preview")
        return RankingStore(client: SimulatedRankingClient(), config: config, cacheURL: cache)
    }

    static let running = RankingState(phase: .running(runId: "mine", serverStartedAt: 1_759_900_000))

    static var top: [LeaderboardRow] {
        (1...12).map { row($0, name: $0 == 4 ? nil : "Jugador \($0)", real: 90_000 + $0 * 4_000, isMe: $0 == 7) }
    }
}

#Preview("Top con la propia") {
    RankingView(
        store: RankingPreviews.store(top: RankingPreviews.top), state: RankingPreviews.running,
        now: 1_760_000_000, onStore: {})
}

#Preview("Fuera del top") {
    RankingView(
        store: RankingPreviews.store(
            top: RankingPreviews.top.map { $0.isMe ? RankingPreviews.row($0.rank, name: $0.name, real: $0.realSeconds) : $0 },
            me: RankingPreviews.row(214, name: "Yo", real: 400_000, isMe: true), myRank: 214),
        state: RankingPreviews.running, now: 1_760_000_000, onStore: {})
}

#Preview("Sin red") {
    RankingView(
        store: RankingPreviews.store(top: Array(RankingPreviews.top.prefix(5))), state: RankingPreviews.running,
        now: 1_760_000_000, onStore: {})
}

#Preview("Partida anterior a la 2.0") {
    RankingView(store: RankingPreviews.store(top: []), state: .legacy, onStore: {})
}
#endif
