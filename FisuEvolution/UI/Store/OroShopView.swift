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

/// "Gastar ORO" (PLAN-v2 E6): el saldo y los estantes de `oro_shop.json`. Vive
/// ADENTRO de la hoja de la Tienda, debajo de su selector: misma columna, mismas
/// `GameCard` y el mismo `PricePill` que FisuJobs y Mejoras.
///
/// La vista no decide nada: dibuja `oroShopRows` y llama a `buyOroShopItem`.
/// Ninguna animación es condición para cobrar ni para entregar.
struct OroShopShelves: View {
    @Environment(GameState.self) private var gameState
    /// El azar pagado se vende acá (`LootBoxGate` de E5a); lo resuelve la hoja y,
    /// hasta que conteste, está cerrado.
    let chanceAllowed: Bool

    @State private var latch = PurchaseLatch()

    /// Lo que tarda la pantalla en reflejar la compra antes de aceptar otra.
    private static let latchSeconds = 0.6

    var body: some View {
        let _ = gameState.effectsVersion
        let _ = gameState.oroText
        let odds = gameState.chestOdds
        let rows = gameState.oroShopRows(chanceAllowed: chanceAllowed)
            .map { ($0, ChestOddsDisplay.make(for: $0.item, odds: odds)) }
            .filter { $0.1.isDrawn }
        VStack(spacing: Tokens.s12) {
            OroBalancePill(text: gameState.oroText)
            ForEach(OroShopCatalog.Shelf.allCases, id: \.self) { shelf in
                let shelfRows = rows.filter { $0.0.item.shelf == shelf }
                if !shelfRows.isEmpty {
                    SectionHeader(LocalizedStringKey(OroShopCopy.shelfKey(shelf)))
                        .frame(maxWidth: .infinity)
                        .padding(.top, Tokens.s8)
                    ForEach(Array(shelfRows.enumerated()), id: \.element.0.id) { offset, entry in
                        OroShopItemRow(row: entry.0, odds: entry.1, pendingNote: pendingNote(for: entry.0.item)) {
                            purchase(entry.0)
                        }
                        .staggeredAppearance(index: offset)
                    }
                    if shelf == .boosts {
                        Text("oroShop.footer.reincarnate")
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PaletteInk").opacity(0.65))
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("oroShop.footer.reincarnate")
                    }
                }
            }
        }
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
private struct OroBalancePill: View {
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

/// Una fila: ícono, nombre, qué da, cuántas van hoy (o el nivel) y el precio. La
/// tarjeta informa, el botón cobra (el patrón de FisuJobs).
private struct OroShopItemRow: View {
    let row: OroShopRow
    let odds: ChestOddsDisplay
    let pendingNote: String?
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
        case .collectionComplete:
            Text("oroShop.chest.coins")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("oroShop.odds.coins")
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
            StateBadge(text: String(localized: "upgrades.maxed"), systemImage: "star.circle.fill",
                       textAlignment: .center, muted: false)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("oroShop.maxed.\(row.id)")
        case .dailyLimitReached?, .alreadyPending?, .nothingToDo?:
            StateBadge(text: blockedText, systemImage: "clock.fill", textAlignment: .center, muted: true)
                .frame(maxWidth: 110)
                .accessibilityElement(children: .combine)
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
                        art.resizable().scaledToFit()
                    } else {
                        Image(systemName: row.item.symbol)
                            .resizable().scaledToFit()
                            .foregroundStyle(Color("PaletteOrange"))
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
