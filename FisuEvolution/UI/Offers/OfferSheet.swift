import EconomyKit
import StoreKit
import SwiftUI

/// Qué oferta está en pantalla. `Identifiable` para `.sheet(item:)`.
struct OfferPresentation: Identifiable, Equatable {
    let id: String
}

/// Las hojas de las ofertas. Vive en un `ViewModifier` por la misma razón que
/// `PrizeSheets`: el `body` de `RootView` está al límite del type-checker.
///
/// Una oferta se presenta sola en su turno de la cola (su única vez) o la abre
/// el jugador desde el chip. La hoja que mira el jugador es estado de esta vista
/// y no un cálculo sobre `GameState`: marcar la oferta como presentada no puede
/// hacerla desaparecer en medio de la animación de cierre.
struct OfferSheets: ViewModifier {
    @Environment(GameState.self) private var gameState
    @Binding var selection: OfferPresentation?
    /// Re-publica `uiCoversBoard`: la hoja abierta tapa el tablero.
    let syncCover: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: gameState.showing, initial: true) {
                guard gameState.showing == .offer, let offer = gameState.offerToPresent else { return }
                gameState.offerPresentationStarted(offer.id)
                selection = OfferPresentation(id: offer.id)
            }
            .onChange(of: selection) { syncCover() }
            .gamePopup(item: $selection, onDismiss: {
                if gameState.showing == .offer { gameState.celebrationFinished(.offer) }
            }) { presentation in
                OfferSheet(offerId: presentation.id, onClose: { selection = nil })
            }
    }
}

/// El popup de una oferta de 24 h: qué trae (con los números del dato), cuánto
/// falta, el precio de StoreKit y —si trae azar— las probabilidades ANTES del
/// botón (Apple 3.1.1). "No, gracias" está siempre a la vista: rechazarla no
/// cuesta nada.
struct OfferSheet: View {
    @Environment(GameState.self) private var gameState
    @Environment(StoreManager.self) private var store
    let offerId: String
    /// Cierra el popup (lo pone quien lo presenta).
    let onClose: () -> Void

    /// La puerta del azar de esta hoja: arranca con la última respuesta y se
    /// renueva al abrir y cada vez que cambia la tienda del jugador.
    @State private var chanceAllowed = LootBoxGate.lastKnown
    @State private var latch = PurchaseLatch()

    private var offer: OffersCatalog.Offer? { gameState.content?.offers.offer(id: offerId) }
    private var product: Product? { offer.flatMap { definition in store.products.first { $0.id == definition.productId } } }
    /// Abierta, sin vencer y vendible en esta tienda.
    private var isAvailable: Bool {
        gameState.visibleOffers(chanceAllowed: chanceAllowed).contains { $0.id == offerId }
    }

    var body: some View {
        let _ = gameState.effectsVersion
        PopupContainer(LocalizedStringKey(IAPCopy.nameKey(for: offer?.productId ?? "")),
                       ribbonTint: Color("PaletteYellow"), onClose: onClose) {
            if let offer {
                contents(offer)
            }
        } actions: {
            if let offer {
                VStack(spacing: Tokens.s8) {
                    buyButton(offer)
                    GameButton("offer.decline", role: .neutral, identifier: "offer.decline", action: onClose)
                }
            }
        }
        .background {
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("offer.sheet")
                .allowsHitTesting(false)
        }
        .task {
            chanceAllowed = await LootBoxGate.current()
            for await _ in Storefront.updates {
                chanceAllowed = await LootBoxGate.current()
            }
        }
        .onChange(of: isAvailable) {
            if !isAvailable { onClose() }
        }
    }

    /// Lo que trae el pack: su imagen principal grande y, debajo, cada premio con
    /// su dibujo y los números del dato.
    @ViewBuilder private func contents(_ offer: OffersCatalog.Offer) -> some View {
        PopupHero(artKey: OfferHeroArt.key(forOfferId: offer.id, iconKey: offer.iconKey), fallback: .blue)
        VStack(alignment: .leading, spacing: Tokens.s8) {
            ForEach(Array(offer.rewards.enumerated()), id: \.offset) { _, reward in
                HStack(spacing: Tokens.s8) {
                    offerLineArt(reward)
                        .frame(width: 28, height: 28)
                    Text(verbatim: RewardCopy.title(reward))
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
            if let active = gameState.activeOffers().first(where: { $0.id == offer.id }) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("offer.endsIn \(OfferCopy.countdown(until: active.expiresAt, now: context.date))")
                        .font(Tokens.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color("PaletteInk").opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if offer.isChance {
            chestOdds
        }
    }

    @ViewBuilder private func offerLineArt(_ reward: RewardSpec) -> some View {
        if let kind = RewardKind(reward) {
            RewardArt(kind: kind)
        } else {
            GameGlyphView(glyph: .check, size: 24)
        }
    }

    /// Las probabilidades del cofre, en la misma pantalla del botón. Con la
    /// colección completa el cofre paga monedas, y lo dice.
    @ViewBuilder private var chestOdds: some View {
        switch ChestOddsDisplay.make(for: gameState.chestOdds) {
        case .table(let rows):
            OddsDisclosureView(titleKey: "oroShop.chest.odds", rows: rows, identifier: "offer.odds")
        case .collectionComplete:
            Text("oroShop.chest.coins")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("offer.odds.coins")
        case .notChance, .hidden:
            EmptyView()
        }
    }

    /// El cerrojo corta el segundo toque (no se apaga el botón): termina cuando
    /// StoreKit contesta, también si el jugador cancela.
    @ViewBuilder private func buyButton(_ offer: OffersCatalog.Offer) -> some View {
        if let product, isAvailable {
            PricePill(
                text: product.displayPrice,
                currency: .money,
                affordable: true,
                identifier: "offer.buy",
                accessibilityPurpose: Text("offer.buy.ax \(IAPCopy.name(for: offer.productId, fallback: product.displayName))")
            ) {
                guard gameState.beginOfferPurchase(offerId, latch: &latch, chanceAllowed: chanceAllowed) else { return }
                Task {
                    await store.purchase(product)
                    latch.release()
                }
            }
        } else if product == nil {
            Text("skins.price.unavailable")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        }
    }
}
