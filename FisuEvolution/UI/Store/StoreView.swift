import StoreKit
import SwiftUI

/// La tienda (bible §4.4): remove ads + skins cosméticas. Precios siempre desde
/// `product.displayPrice`; botón de restaurar obligatorio para App Review.
struct StoreView: View {
    @Environment(StoreManager.self) private var store
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                switch store.loadState {
                case .idle, .loading:
                    ProgressView("loading.title")
                case .failed:
                    Label("store.error.load", systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.secondary)
                case .loaded:
                    productSections
                }

                Section {
                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("store.restore")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("store.restore")
                }

                if let message = store.lastErrorMessage {
                    Text(verbatim: message)
                        .font(.footnote)
                        .foregroundStyle(Color("PalettePink"))
                }
            }
            .navigationTitle(Text("store.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("store.close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var productSections: some View {
        Section("store.section.general") {
            ForEach(store.products.filter { store.skinId(for: $0.id) == nil }) { product in
                productRow(product)
            }
        }
        Section("store.section.skins") {
            ForEach(store.products.filter { store.skinId(for: $0.id) != nil }) { product in
                skinRow(product)
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

    private func skinRow(_ product: Product) -> some View {
        let skinId = store.skinId(for: product.id)
        return HStack {
            VStack(alignment: .leading) {
                Text(verbatim: product.displayName).font(.headline)
                Text(verbatim: product.description).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if let skinId, store.isPurchased(product.id) {
                if gameState.activeSkin == skinId {
                    Button {
                        gameState.setActiveSkin(nil)
                    } label: {
                        Label("store.skin.active", systemImage: "checkmark.seal.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("PaletteGreen"))
                } else {
                    Button("store.skin.activate") {
                        gameState.setActiveSkin(skinId)
                    }
                    .buttonStyle(.bordered)
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
