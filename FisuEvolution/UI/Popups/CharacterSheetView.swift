import EconomyKit
import StoreKit
import SwiftUI

/// Ficha por tipo de personaje. Es el único entry point del pasivo, la
/// apariencia y despedir; evita que el juego interrumpa el loop con popups.
struct CharacterSheetView: View {
    @Environment(GameState.self) private var gameState
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    let sheet: GameState.CharacterSheet
    @State private var selectedIndex = 0
    @State private var confirmingDismissal = false

    private struct SkinOption: Identifiable {
        let skin: SkinsConfig.Entry?
        var id: String { skin?.id ?? "base" }
    }

    private var options: [SkinOption] {
        [SkinOption(skin: nil)] + gameState.skinOptions(forCharacterType: sheet.type.id).map(SkinOption.init)
    }

    private var selected: SkinOption {
        options.indices.contains(selectedIndex) ? options[selectedIndex] : options[0]
    }

    private var selectedTreatment: SkinResolver.Treatment {
        SkinResolver.treatment(
            for: selected.skin?.id,
            characterType: sheet.type.id,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
    }

    private var isSelectedOwned: Bool {
        selected.skin.map { gameState.ownsSkin($0.id) } ?? true
    }

    var body: some View {
        // Proyección observada: entitlements/milestones/equipar refrescan el
        // estado del botón sin observar PlayerState (que cambia 8 veces/s).
        let _ = gameState.skinSelectionVersion
        GamePanel(art: "panel_dialog", insets: EdgeInsets(top: 58, leading: 24, bottom: 26, trailing: 24)) {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    skinPager
                    passiveSection
                    dismissalSection
                }
            }
        }
        .padding(16)
        .presentationDetents([.medium, .large])
        .alert("character.dismiss.title", isPresented: $confirmingDismissal) {
            Button("character.dismiss.confirm", role: .destructive) {
                gameState.dismissCharacter(atCell: sheet.cellIndex)
                dismiss()
            }
            Button("character.dismiss.cancel", role: .cancel) {}
        } message: {
            Text("character.dismiss.message")
        }
        .onAppear { selectActiveSkin() }
    }

    private var header: some View {
        VStack(spacing: 5) {
            CharacterPortrait(type: sheet.type, treatment: selectedTreatment)
                .frame(width: 118, height: 118)
            Text(sheet.type.displayName)
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(Color("PaletteInk"))
            Text("character.count \(sheet.instanceCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var skinPager: some View {
        VStack(spacing: 9) {
            HStack(spacing: 14) {
                Button { moveSelection(by: -1) } label: {
                    Image(systemName: "chevron.left.circle.fill").font(.title2)
                }
                .disabled(selectedIndex == 0)
                .accessibilityIdentifier("character.skin.previous")

                VStack(spacing: 3) {
                    Text(skinName)
                        .font(.headline)
                    Text("character.skin.index \(selectedIndex + 1) \(options.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Button { moveSelection(by: 1) } label: {
                    Image(systemName: "chevron.right.circle.fill").font(.title2)
                }
                .disabled(selectedIndex == options.count - 1)
                .accessibilityIdentifier("character.skin.next")
            }

            if isSelectedOwned {
                Button(isSelectedActive ? "character.skin.equipped" : "character.skin.equip") {
                    gameState.equipSkin(id: selected.skin?.id, forCharacterType: sheet.type.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteBlue"))
                .disabled(isSelectedActive)
                .accessibilityIdentifier("character.skin.equip")
            } else {
                lockedSkinDetails
            }
        }
        .padding(12)
        .background(Color("PaletteCream").opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private var lockedSkinDetails: some View {
        Label("character.skin.locked", systemImage: "lock.fill")
            .foregroundStyle(Color("PaletteInk"))
        Text(unlockDescription)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        if let product = selected.skin.flatMap(product(for:)) {
            Button(product.displayPrice) { Task { await store.purchase(product) } }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteGreen"))
        }
    }

    private var passiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("passive.title \(sheet.type.displayName)")
                .font(.headline)
            Text("passive.explainer \(String(sheet.instanceCount)) \(CoinFormatter.string(from: sheet.type.passiveYieldPerInstance))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if sheet.isUnlocked {
                Label("passive.unlocked", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color("PaletteGreen"))
            } else {
                Button {
                    gameState.unlockPassive(typeId: sheet.type.id)
                } label: {
                    HStack(spacing: 6) {
                        Text("passive.unlock")
                        CoinIcon(size: 18)
                        Text(verbatim: CoinFormatter.string(from: sheet.type.passiveUnlockCost))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteGreen"))
                .disabled(!sheet.canAfford)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color("PaletteCream").opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private var dismissalSection: some View {
        if sheet.canDismiss {
            Button(role: .destructive) { confirmingDismissal = true } label: {
                Label("character.dismiss", systemImage: "person.fill.xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color("PalettePink"))
            .accessibilityIdentifier("character.dismiss")
        }
    }

    private var skinName: String {
        guard let skin = selected.skin else { return String(localized: "character.skin.base") }
        return skin.id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var isSelectedActive: Bool {
        gameState.activeSkinID(forCharacterType: sheet.type.id) == selected.skin?.id
    }

    private var unlockDescription: String {
        guard let skin = selected.skin else { return "" }
        if let floor = skin.floorReached { return String(localized: "character.skin.reach-floor \(floor)") }
        if let lives = skin.reincarnations { return String(localized: "character.skin.reincarnations \(lives)") }
        return String(localized: "character.skin.store")
    }

    private func product(for skin: SkinsConfig.Entry) -> Product? {
        store.products.first { store.skinId(for: $0.id) == skin.id }
    }

    private func selectActiveSkin() {
        let active = gameState.activeSkinID(forCharacterType: sheet.type.id)
        selectedIndex = options.firstIndex { $0.skin?.id == active } ?? 0
    }

    private func moveSelection(by delta: Int) {
        selectedIndex = min(max(selectedIndex + delta, 0), options.count - 1)
    }
}

private struct CharacterPortrait: View {
    let type: CharacterType
    let treatment: SkinResolver.Treatment
    @Environment(GameState.self) private var gameState

    var body: some View {
        Group {
            if let asset = gameState.content?.manifest.characters[type.id],
               let image = UIArt.characterImage(
                   atlas: asset.atlas,
                   key: textureKey ?? asset.key
               ) {
                image
                    .resizable()
                    .scaledToFit()
                    .colorMultiply(tintColor ?? .white)
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .foregroundStyle(tintColor ?? Color("PaletteInk"))
            }
        }
        .accessibilityHidden(true)
    }

    private var textureKey: String? {
        guard case let .texture(key) = treatment else { return nil }
        return key
    }

    private var tintColor: Color? {
        guard case let .tint(hex) = treatment else { return nil }
        return Color(hex: hex)
    }
}

private extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let raw = Int(value, radix: 16) else { return nil }
        self.init(
            red: Double((raw >> 16) & 0xFF) / 255,
            green: Double((raw >> 8) & 0xFF) / 255,
            blue: Double(raw & 0xFF) / 255
        )
    }
}
