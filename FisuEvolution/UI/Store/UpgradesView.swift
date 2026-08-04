import EconomyKit
import SwiftUI

/// Dos bolsillos explícitos: mejoras efímeras por personaje con plata y las
/// siete mejoras globales que sobreviven en ORO.
struct UpgradesView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case characters
        case permanent
        var id: Self { self }
    }

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .characters

    var body: some View {
        let _ = gameState.effectsVersion
        let _ = gameState.coinsText
        let _ = gameState.oroText

        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    tabPicker
                    if selectedTab == .characters {
                        characterRows
                    } else {
                        permanentRows
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
            }
            .background { PanelBackground(art: "panel_upgrades") }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 7) {
                    PanelTitleBanner(titleKey: "upgrades.title")
                    if selectedTab == .permanent {
                        HStack(spacing: 5) {
                            OroIcon(size: 18)
                            Text("upgrades.oro_balance \(gameState.oroText)")
                                .font(.subheadline.weight(.heavy))
                        }
                        .foregroundStyle(Color("PaletteInk"))
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            tabButton(.characters, key: "upgrades.tab.characters", identifier: "upgrades.tab.characters")
            tabButton(.permanent, key: "upgrades.tab.permanent", identifier: "upgrades.tab.permanent")
        }
        .padding(4)
        .background(Capsule().fill(Color("PaletteCream")).overlay(Capsule().stroke(Color("PaletteInk"), lineWidth: 2)))
    }

    private func tabButton(_ tab: Tab, key: LocalizedStringKey, identifier: String) -> some View {
        Button { selectedTab = tab } label: {
            Text(key)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(selectedTab == tab ? Color.white : Color("PaletteInk"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(selectedTab == tab ? Color("PaletteBlue") : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var characterRows: some View {
        if gameState.characterUpgradeTypes.isEmpty {
            Text("upgrades.characters.empty")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color("PaletteInk"))
                .padding(.top, 36)
        } else {
            ForEach(gameState.characterUpgradeTypes) { type in
                characterRow(type)
            }
        }
    }

    private func characterRow(_ type: CharacterType) -> some View {
        let level = gameState.characterUpgradeLevel(of: type.id)
        let cost = gameState.characterUpgradeCost(of: type) ?? .infinity
        let canAfford = (gameState.player?.run.coins ?? 0) >= cost
        return upgradeCard(leading: {
            Circle().fill(Color("PaletteYellow")).overlay(Circle().stroke(Color("PaletteInk"), lineWidth: 2))
                .overlay(Text("T\(type.tier)").font(.caption.weight(.heavy)).foregroundStyle(Color("PaletteInk")))
                .frame(width: 38, height: 38)
        }, center: {
            Text(type.displayName).font(.headline)
            Text("upgrades.character_multiplier \(String(level))")
                .font(.footnote.weight(.semibold)).foregroundStyle(Color("PaletteInk"))
        }, action: {
            gameState.buyCharacterUpgrade(typeID: type.id)
        }, cost: {
            CoinIcon(size: 16)
            Text(verbatim: CoinFormatter.string(from: cost)).monospacedDigit()
        }, identifier: "upgrades.character.\(type.id)", enabled: canAfford)
    }

    @ViewBuilder private var permanentRows: some View {
        ForEach(gameState.content?.upgradesConfig.upgrades ?? []) { line in
            permanentRow(line)
        }
    }

    private func permanentRow(_ line: UpgradesConfig.Line) -> some View {
        let level = gameState.upgradeLevel(of: line.id)
        let cost = gameState.upgradeCost(of: line)
        let maxed = level >= line.maxLevel
        let canAfford = (gameState.player?.meta.oro ?? 0) >= Int(cost.rounded(.up))
        return upgradeCard(leading: {
            if let icon = UIArt.image(line.iconKey) { icon.resizable().scaledToFit().frame(width: 38, height: 38) }
        }, center: {
            Text(LocalizedStringKey(line.titleKey)).font(.headline)
            Text("upgrades.level \(String(level)) \(String(line.maxLevel))")
                .font(.footnote).foregroundStyle(Color("PaletteInk"))
        }, action: {
            gameState.buyUpgrade(lineId: line.id)
        }, cost: {
            OroIcon(size: 16)
            Text(verbatim: String(Int(cost.rounded(.up)))).monospacedDigit()
        }, identifier: "upgrades.permanent.\(line.id)", enabled: canAfford && !maxed)
    }

    private func upgradeCard<Leading: View, Center: View, Cost: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        action: @escaping () -> Void,
        @ViewBuilder cost: () -> Cost,
        identifier: String,
        enabled: Bool
    ) -> some View {
        HStack(spacing: 10) {
            leading().frame(width: 40)
            VStack(alignment: .leading, spacing: 3) { center() }
            Spacer(minLength: 4)
            Button(action: action) {
                HStack(spacing: 4) { cost() }
                    .font(.subheadline.weight(.heavy))
                    .padding(.horizontal, 9).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent).tint(Color("PaletteBlue")).disabled(!enabled)
            .accessibilityIdentifier(identifier)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color("PaletteCream")).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color("PaletteInk"), lineWidth: 2)))
    }
}
