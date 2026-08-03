import SwiftUI

/// Las 7 líneas de upgrades (matchean los íconos ui_up_* del pipeline de arte).
struct UpgradesView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // effectsVersion + coinsText observados → la lista se refresca al comprar.
        let _ = gameState.effectsVersion
        let _ = gameState.coinsText

        NavigationStack {
            List {
                ForEach(gameState.content?.upgradesConfig.upgrades ?? []) { line in
                    upgradeRow(line)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 22, for: .scrollContent)
            .contentMargins(.top, 8, for: .scrollContent)
            .background { PanelBackground(art: "panel_upgrades") }
            .safeAreaInset(edge: .top) {
                PanelTitleBanner(titleKey: "upgrades.title").padding(.top, 6).padding(.bottom, 4)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ArtCloseButton { dismiss() }
                }
            }
        }
    }

    private func upgradeRow(_ line: UpgradesConfig.Line) -> some View {
        let level = gameState.upgradeLevel(of: line.id)
        let cost = gameState.upgradeCost(of: line)
        let maxed = level >= line.maxLevel
        let canAfford = (gameState.player?.run.coins ?? 0) >= cost

        return HStack {
            if let icon = UIArt.image("ui_up_\(line.id)") {
                icon.resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(line.titleKey))
                    .font(.headline)
                Text("upgrades.level \(String(level)) \(String(line.maxLevel))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if maxed {
                Label("upgrades.maxed", systemImage: "checkmark.seal.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color("PaletteGreen"))
            } else {
                Button {
                    gameState.buyUpgrade(lineId: line.id)
                } label: {
                    HStack(spacing: 4) {
                        CoinIcon(size: 16)
                        Text(verbatim: CoinFormatter.string(from: cost))
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteBlue"))
                .disabled(!canAfford)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
