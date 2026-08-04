import StoreKit
import SwiftUI

/// La tienda (bible §4.4): remove ads + skins cosméticas. Precios siempre desde
/// `product.displayPrice`; botón de restaurar obligatorio para App Review.
struct StoreView: View {
    @Environment(StoreManager.self) private var store
    @Environment(GameState.self) private var gameState
    @Environment(HapticsManager.self) private var haptics
    @Environment(AudioManager.self) private var audio
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var haptics = haptics
        @Bindable var audio = audio
        NavigationStack {
            List {
                Group {
                    switch store.loadState {
                    case .idle, .loading:
                        ProgressView("loading.title")
                    case .failed:
                        Label("store.error.load", systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.secondary)
                    case .loaded:
                        productSections
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("store.restore")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("store.restore")
                }
                .listRowBackground(Color.clear)

                if let message = store.lastErrorMessage {
                    Text(verbatim: message)
                        .font(.footnote)
                        .foregroundStyle(Color("PalettePink"))
                        .listRowBackground(Color.clear)
                }

                Section("settings.title") {
                    Toggle("settings.haptics", isOn: $haptics.isEnabled)
                    VStack(alignment: .leading) {
                        Text("settings.music")
                        Slider(value: $audio.musicVolume, in: 0...1)
                    }
                    VStack(alignment: .leading) {
                        Text("settings.sfx")
                        Slider(value: $audio.sfxVolume, in: 0...1)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 22, for: .scrollContent)
            .contentMargins(.top, 8, for: .scrollContent)
            .background { PanelBackground(art: "panel_store") }
            .safeAreaInset(edge: .top) {
                PanelTitleBanner(titleKey: "store.title").padding(.top, 6).padding(.bottom, 4)
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

    @ViewBuilder
    private var productSections: some View {
        // Sólo mostrar la sección si tiene productos: evita headers "UPGRADES"/
        // "SKINS" colgados sobre un hueco vacío cuando StoreKit no cargó productos.
        let general = store.products.filter { store.skinId(for: $0.id) == nil }
        let skins = store.products.filter { store.skinId(for: $0.id) != nil }
        if !general.isEmpty {
            Section("store.section.general") {
                ForEach(general) { product in
                    productRow(product)
                }
            }
        }
        if !skins.isEmpty {
            Section("store.section.skins") {
                ForEach(skins) { product in
                    skinRow(product)
                }
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(verbatim: product.displayName).font(.headline)
                Text(verbatim: product.description).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if store.isPurchased(product.id) {
                Label("store.purchased", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color("PaletteGreen"))
            } else {
                buyButton(product)
            }
        }
    }

    /// La tienda VENDE skins; equiparlas es potestad de la ficha de personaje
    /// (§3.10), que es la única superficie que sabe a qué tipo aplicarlas. Acá
    /// sólo se confirma la compra y se apunta a dónde se usa.
    private func skinRow(_ product: Product) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(verbatim: product.displayName).font(.headline)
                Text(verbatim: product.description).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if store.isPurchased(product.id) {
                VStack(alignment: .trailing, spacing: 2) {
                    Label("store.purchased", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color("PaletteGreen"))
                    Text("store.skin.equip-hint")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                buyButton(product)
            }
        }
    }

    private func buyButton(_ product: Product) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            Text(verbatim: product.displayPrice)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(Color("PaletteBlue"))
        .disabled(store.isPurchasing)
    }
}
