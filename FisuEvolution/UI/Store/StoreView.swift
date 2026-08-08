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
                        unavailableLabel
                    case .loaded:
                        // `Product.products(for:)` no falla cuando un id no
                        // resuelve: lo omite. Con StoreKit caído devuelve la
                        // lista vacía y `loadState` queda en `.loaded`, así que
                        // el hueco hay que nombrarlo acá o no lo nombra nadie.
                        if store.products.isEmpty {
                            unavailableLabel
                        } else {
                            productSections
                        }
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

    /// Lo que ve el jugador cuando la tienda no tiene nada que ofrecerle, sea
    /// porque la carga falló o porque volvió vacía. Lleva el reintento adentro:
    /// `start()` es idempotente y no vuelve a pedir los productos, así que cerrar
    /// y reabrir el carrito no arregla nada por sí solo.
    private var unavailableLabel: some View {
        VStack(spacing: 8) {
            Label("store.error.load", systemImage: "wifi.exclamationmark")
                .foregroundStyle(.secondary)
            Button {
                Task { await store.loadProducts() }
            } label: {
                Text("store.retry")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("store.retry")
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("store.unavailable")
    }

    /// Las filas se agrupan por lo que ENTREGAN, no por el tipo de StoreKit: el
    /// combo es `nonConsumable` igual que quitar los ads, y va con él.
    private func products(_ kinds: Set<ProductCatalog.Entry.Entitlement>) -> [Product] {
        store.products.filter { product in
            guard let entitlement = store.entry(for: product.id)?.entitlement else { return false }
            return kinds.contains(entitlement)
        }
    }

    @ViewBuilder
    private var productSections: some View {
        // Sólo se dibuja la sección que tiene productos: evita headers colgados
        // sobre un hueco cuando StoreKit devolvió menos de los declarados.
        section("store.section.general", products([.starterPack, .removeAds]))
        section("store.section.coins", products([.coins]))
        section("store.section.oro", products([.oro]))
        let skins = products([.skin])
        if !skins.isEmpty {
            Section("store.section.skins") {
                ForEach(skins) { product in
                    skinRow(product)
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ titleKey: LocalizedStringKey, _ products: [Product]) -> some View {
        if !products.isEmpty {
            Section(titleKey) {
                ForEach(products) { product in
                    productRow(product)
                }
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: product.displayName).font(.headline)
                // La línea de arriba es el número concreto y sale calculado
                // contra la partida (la plata de un pack depende de dónde estás
                // parado); la de abajo es el color, que lo pone el `.storekit`.
                if let reward = store.entry(for: product.id).flatMap(gameState.packRewardText) {
                    Text(verbatim: reward)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("PaletteGreen"))
                        .accessibilityIdentifier("store.reward.\(product.id)")
                }
                Text(verbatim: product.description).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            // Un consumible nunca queda "comprado", así que siempre cae en el
            // botón: se vuelve a vender.
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
        // El identificador lleva el id del producto porque con tres filas los
        // botones se leen todos "USD 2.99": sin esto no hay test de UI que
        // pueda apretar UNO. Es un String, no una clave de localización, así
        // que interpolarlo acá es correcto (trampa 5 es de `LocalizedStringKey`).
        .accessibilityIdentifier("store.buy.\(product.id)")
    }
}
