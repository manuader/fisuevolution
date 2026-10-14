import EconomyKit
import SwiftUI

/// Lo que la fila del cofre dice de su azar (Apple 3.1.1). La tabla es la que
/// sortea `ChestRoller.roll`: `GameState.chestOdds`.
enum ChestOddsDisplay: Equatable {
    /// La fila no es de azar.
    case notChance
    case table([OddsDisclosureView.Row])
    /// La colección está completa: el cofre paga monedas.
    case collectionComplete
    /// No hay nada que mostrar, así que la fila no se dibuja.
    case hidden

    static func make(for odds: ChestOddsTable) -> ChestOddsDisplay {
        switch odds {
        case .skins(let odds):
            let rows = odds.compactMap { odds in
                SkinsConfig.Rarity(rawValue: odds.id).map {
                    OddsDisclosureView.Row(id: odds.id, title: ChestRarityStyle.name($0),
                                           symbol: ChestRarityStyle.symbol($0), probability: odds.probability)
                }
            }
            return rows.isEmpty ? .hidden : .table(rows)
        case .coins: return .collectionComplete
        case .nothingYet: return .hidden
        }
    }

    /// El único azar de este estante es el cofre de pintas; el giro extra lo
    /// vende la ruleta (E5a T8).
    static func make(for item: OroShopCatalog.Item, odds: ChestOddsTable) -> ChestOddsDisplay {
        guard item.isChance else { return .notChance }
        guard case .skinChest? = item.rewards.first else { return .hidden }
        return make(for: odds)
    }

    var isDrawn: Bool { self != .hidden }
}

/// Un toque a la vez: el cobro es instantáneo, así que un segundo toque antes de
/// que la pantalla se entere cobraría de nuevo los ítems sin tope (el cofre).
struct PurchaseLatch: Equatable {
    private(set) var isLocked = false

    mutating func claim() -> Bool {
        guard !isLocked else { return false }
        isLocked = true
        return true
    }

    mutating func release() {
        isLocked = false
    }
}

/// Los estantes de `oro_shop.json` que se pagan con blue (PLAN-v2 E6, E14 C11):
/// la Tienda quedó para la plata de verdad y esto vive en Mejoras —los boosts y
/// los permanentes del catálogo— y en Pintas —el cofre—. Cada hoja pide los
/// estantes que le tocan; misma columna, mismas `GameCard` y el mismo `PricePill`
/// que FisuJobs y Mejoras.
///
/// La vista no decide nada: dibuja `oroShopRows` y llama a `buyOroShopItem`.
/// Ninguna animación es condición para cobrar ni para entregar.
struct OroShopShelves: View {
    @Environment(GameState.self) private var gameState
    let shelves: [OroShopCatalog.Shelf]
    /// El azar pagado se vende en Pintas (`LootBoxGate` de E5a); lo resuelve la
    /// hoja y, hasta que conteste, está cerrado.
    let chanceAllowed: Bool
    /// Cada estante con su cinta; Mejoras los agrupa bajo el sello de su pestaña
    /// («Para siempre», «Por un rato») y no la repite.
    var titled = true

    @Environment(\.loopsManifest) private var loops
    @State private var latch = PurchaseLatch()
    @State private var visibleRows: Set<String> = []

    /// Lo que tarda la pantalla en reflejar la compra antes de aceptar otra.
    private static let latchSeconds = 0.6

    var body: some View {
        let _ = gameState.effectsVersion
        let _ = gameState.oroText
        let odds = gameState.chestOdds
        let rows = gameState.oroShopRows(chanceAllowed: chanceAllowed)
            .map { ($0, ChestOddsDisplay.make(for: $0.item, odds: odds)) }
            .filter { $0.1.isDrawn }
        let focused = focusedRow(in: rows.map(\.0))
        VStack(spacing: Tokens.s12) {
            ForEach(shelves, id: \.self) { shelf in
                let shelfRows = Self.displayOrder(rows.filter { $0.0.item.shelf == shelf }, shelf: shelf)
                if !shelfRows.isEmpty {
                    if titled {
                        SectionHeader(LocalizedStringKey(OroShopCopy.shelfKey(shelf)))
                            .frame(maxWidth: .infinity)
                            .padding(.top, Tokens.s8)
                    }
                    ForEach(Array(shelfRows.enumerated()), id: \.element.0.id) { offset, entry in
                        OroShopItemRow(
                            row: entry.0, odds: entry.1, pendingNote: pendingNote(for: entry.0.item),
                            clip: entry.0.id == focused ? ArtClips.shopIcon(item: entry.0.id, in: loops) : nil
                        ) {
                            purchase(entry.0)
                        }
                        .onScrollVisibilityChange(threshold: 0.8) { isVisible in
                            if isVisible { visibleRows.insert(entry.0.id) } else { visibleRows.remove(entry.0.id) }
                        }
                        .staggeredAppearance(index: offset)
                    }
                }
            }
        }
        .onChange(of: focused) { _, new in
            if new != nil { gameState.shopIconFocused() }
        }
        .onAppear { packTags.forEach { ArtPacks.shared.prefetch($0) } }
        .onDisappear { packTags.forEach { ArtPacks.shared.release($0) } }
    }

    /// Lo que se compra y se usa va arriba, por precio (el más barato primero); lo
    /// comprado al máximo se va al fondo con su tilde. Los permanentes conservan el
    /// orden del catálogo: lugares extra primero.
    static func displayOrder<Entry>(
        _ entries: [(OroShopRow, Entry)], shelf: OroShopCatalog.Shelf
    ) -> [(OroShopRow, Entry)] {
        let ordered = shelf == .permanents
            ? entries
            : entries.sorted { ($0.0.quote.price ?? $0.0.item.price ?? 0) < ($1.0.quote.price ?? $1.0.item.price ?? 0) }
        let open = ordered.filter { $0.0.quote.blocker != .maxed }
        return open + ordered.filter { $0.0.quote.blocker == .maxed }
    }

    /// Los packs ODR de los íconos de la tienda: se precargan al abrirla.
    private var packTags: Set<String> {
        Set(ArtClips.shopIconKeys.keys.compactMap { ArtClips.shopIcon(item: $0, in: loops) }
            .compactMap { loops.odrTag(for: $0) })
    }

    /// La fila que anima su ícono: la del medio de las visibles, en el orden en que se dibujan.
    private func focusedRow(in rows: [OroShopRow]) -> String? {
        let ordered = OroShopCatalog.Shelf.allCases.flatMap { shelf in rows.filter { $0.item.shelf == shelf } }
        let animatable = Set(ordered.map(\.id).filter { ArtClips.shopIcon(item: $0, in: loops) != nil })
        return ShopIconFocus.pick(visibleInOrder: ordered.map(\.id).filter(visibleRows.contains), animatable: animatable)
    }

    private func purchase(_ row: OroShopRow) {
        // Sin saldo o con tope no se cobra nada: no hace falta cerrojo.
        guard row.quote.blocker == nil else {
            gameState.buyOroShopItem(id: row.id, chanceAllowed: chanceAllowed)
            return
        }
        guard latch.claim() else { return }
        gameState.buyOroShopItem(id: row.id, chanceAllowed: chanceAllowed)
        Task {
            try? await Task.sleep(for: .seconds(Self.latchSeconds))
            latch.release()
        }
    }

    /// Los ×3 comprados esperan su momento: la fila dice a qué popup le toca.
    private func pendingNote(for item: OroShopCatalog.Item) -> String? {
        guard let shop = gameState.player?.meta.engagement.shop else { return nil }
        for reward in item.rewards {
            switch reward {
            case .nextOfflineMultiplier:
                if let multiplier = shop.pendingOfflineMultiplier {
                    return String(localized: "oroShop.pending.offline \(Self.format(multiplier))")
                }
            case .nextDailyMultiplier:
                if let multiplier = shop.pendingDailyMultiplier {
                    return String(localized: "oroShop.pending.daily \(Self.format(multiplier))")
                }
            default: break
            }
        }
        return nil
    }

    private static func format(_ multiplier: Double) -> String {
        multiplier.formatted(.number.precision(.fractionLength(0...1)))
    }
}

/// El saldo de ORO, con el número como valor de accesibilidad para los tests.
struct OroBalancePill: View {
    let text: String

    var body: some View {
        HStack(spacing: Tokens.s4) {
            OroIcon(size: 18)
                .accessibilityHidden(true)
            Text("upgrades.oro_balance \(text)")
                .font(Tokens.body)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Tokens.s16)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color("PaletteYellow").opacity(0.35))
                .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.6), lineWidth: 2))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("oroShop.balance")
        .accessibilityValue(Text(verbatim: text))
    }
}

/// Lo cosmético que se paga con blue (C11, D3), en la hoja de Pintas: el cofre de
/// pintas con sus probabilidades y las pintas y familias de `skins.json`, a color
/// siempre —acá el arte es el argumento de venta—.
struct BlueCosmeticsShelf: View {
    @Environment(GameState.self) private var gameState
    let chanceAllowed: Bool

    @State private var latch = PurchaseLatch()

    private static let latchSeconds = 0.6

    var body: some View {
        let _ = gameState.effectsVersion
        let _ = gameState.skinSelectionVersion
        let cosmetics = gameState.cosmeticRows
        VStack(spacing: Tokens.s12) {
            SectionHeader("skins.blue.title")
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.s8)
            OroBalancePill(text: gameState.oroText)
            OroShopShelves(shelves: [.luck], chanceAllowed: chanceAllowed, titled: false)
            ForEach(cosmetics) { row in
                CosmeticItemRow(row: row, preview: preview(for: row)) { purchaseSkin(row.id) }
                    .tutorialAnchor(.storeCosmetics, when: row.id == cosmetics.first?.id)
            }
        }
    }

    private func preview(for row: CosmeticRow) -> Image? {
        guard let content = gameState.content else { return nil }
        let type: CharacterType? = switch row.kind {
        case .outfit(let typeID): content.tiers.type(id: typeID)
        case .family: gameState.cosmeticPreviewType
        }
        guard let type else { return nil }
        return SkinArt.image(type: type, skinID: row.id, skins: content.skins, manifest: content.manifest)
    }

    private func purchaseSkin(_ skinID: String) {
        guard latch.claim() else { return }
        gameState.buySkinWithOro(skinID: skinID)
        Task {
            try? await Task.sleep(for: .seconds(Self.latchSeconds))
            latch.release()
        }
    }
}

/// Una fila: ícono, nombre, qué da, cuántas van hoy (o el nivel) y el precio. La
/// tarjeta informa, el botón cobra (el patrón de FisuJobs).
struct OroShopItemRow: View {
    let row: OroShopRow
    let odds: ChestOddsDisplay
    let pendingNote: String?
    /// El clip del ícono si esta es la fila enfocada; `nil`, póster quieto.
    let clip: ArtClip?
    let buy: () -> Void

    private var name: String { OroShopCopy.name(for: row.item) }

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                HStack(spacing: Tokens.s12) {
                    icon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: name)
                            .font(Tokens.title)
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(verbatim: OroShopCopy.detail(for: row.item, level: row.quote.level))
                            .font(Tokens.body)
                            .foregroundStyle(Color("PaletteBlue"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        if let status {
                            Text(verbatim: status)
                                .font(Tokens.caption)
                                .monospacedDigit()
                                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                                .accessibilityIdentifier("oroShop.status.\(row.id)")
                        }
                        if let pendingNote {
                            Text(verbatim: pendingNote)
                                .font(Tokens.caption)
                                .foregroundStyle(Color("PaletteOrange"))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("oroShop.pending.\(row.id)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    rail
                        .layoutPriority(1)
                }
                disclosure
            }
        }
    }

    @ViewBuilder private var disclosure: some View {
        switch odds {
        case .table(let rows):
            OddsDisclosureView(titleKey: "oroShop.chest.odds", rows: rows, identifier: "oroShop.odds")
                .tutorialAnchor(.storeOdds)
        case .collectionComplete:
            Text("oroShop.chest.coins")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("oroShop.odds.coins")
                .tutorialAnchor(.storeOdds)
        case .notChance, .hidden:
            EmptyView()
        }
    }

    /// "Hoy: 1 de 3" en los que tienen tope; "Nivel 1/3" en los permanentes.
    private var status: String? {
        if row.item.isPermanent {
            return String(localized: "upgrades.level \(String(row.quote.level)) \(String(row.item.levels.count))")
        }
        guard let limit = row.item.dailyLimit else { return nil }
        return String(localized: "oroShop.today \(String(row.quote.boughtToday)) \(String(limit))")
    }

    @ViewBuilder private var rail: some View {
        switch row.quote.blocker {
        case .maxed?:
            StateTag(state: .done, text: String(localized: "upgrades.maxed"))
                .accessibilityIdentifier("oroShop.maxed.\(row.id)")
        case .dailyLimitReached?, .alreadyPending?, .nothingToDo?:
            StateTag(state: .running, text: blockedText)
                .frame(maxWidth: 130)
                .accessibilityIdentifier("oroShop.blocked.\(row.id)")
        case .cantAfford?, nil:
            PricePill(
                text: String(row.quote.price ?? 0),
                currency: .oro,
                affordable: row.quote.blocker == nil,
                identifier: "oroShop.buy.\(row.id)",
                accessibilityPurpose: Text("oroShop.buy.ax \(name)")
            ) {
                buy()
            }
        }
    }

    private var blockedText: String {
        switch row.quote.blocker {
        case .dailyLimitReached?: String(localized: "oroShop.blocked.daily")
        case .alreadyPending?: String(localized: "oroShop.blocked.pending")
        default: String(localized: "oroShop.blocked.nothing")
        }
    }

    /// El ícono de E8 si ya llegó; si no, el SF Symbol del dato, en el mismo marco
    /// que las filas de Mejoras.
    private var icon: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Color.clear
            .frame(width: 48, height: 48)
            .overlay {
                Group {
                    if let art = UIArt.image(row.item.iconKey) {
                        if let clip {
                            AnimatedArtView(clip: clip, role: .icon) { art.resizable().scaledToFit() }
                        } else {
                            art.resizable().scaledToFit()
                        }
                    } else {
                        GameGlyphView(glyph: .art(row.item.iconKey), size: 32)
                    }
                }
                .padding(8)
            }
            .background(Color("PaletteYellow").opacity(0.3))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
            .accessibilityHidden(true)
    }
}

/// Una pinta de ORO del estante de Cosméticos. La tarjeta informa, el botón cobra.
private struct CosmeticItemRow: View {
    @Environment(GameState.self) private var gameState
    let row: CosmeticRow
    let preview: Image?
    let buy: () -> Void

    private var name: String {
        gameState.content?.skins.entry(id: row.id).map(gameState.skinDisplayName(for:)) ?? row.id
    }

    private var detail: String {
        switch row.kind {
        case .family: String(localized: "oroShop.cosmetic.family")
        case .outfit(let typeID):
            String(localized: "oroShop.cosmetic.outfit \(gameState.content?.tiers.type(id: typeID)?.localizedName ?? typeID)")
        }
    }

    var body: some View {
        GameCard {
            HStack(spacing: Tokens.s12) {
                Group {
                    if let preview { preview.resizable().scaledToFit() } else { GameGlyphView(glyph: .gift, size: 40) }
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name)
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(verbatim: detail)
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteBlue"))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if row.owned {
                    StateTag(state: .done, text: String(localized: "oroShop.cosmetic.owned"))
                        .frame(maxWidth: 130)
                        .accessibilityIdentifier("oroShop.cosmetic.owned.\(row.id)")
                } else {
                    PricePill(
                        text: String(row.price),
                        currency: .oro,
                        affordable: (gameState.player?.meta.oro ?? 0) >= row.price,
                        identifier: "oroShop.cosmetic.buy.\(row.id)",
                        accessibilityPurpose: Text("oroShop.buy.ax \(name)"),
                        action: buy
                    )
                    .layoutPriority(1)
                }
            }
        }
    }
}
