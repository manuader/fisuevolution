import EconomyKit
import Foundation

/// Una mejora permanente que se paga con blue y todavía se puede comprar: del
/// catálogo de `blue_shop.json` (lugares extra, proveedor, ruleta) o de las siete
/// líneas globales de `upgrades.json`.
struct PermanentOffer: Identifiable, Equatable {
    enum Source: Equatable {
        case shop(id: String)
        case line(id: String)
    }

    let source: Source
    /// Blue del próximo nivel.
    let price: Int

    var id: String {
        switch source {
        case .shop(let id), .line(let id): id
        }
    }
}

/// «Tu meta» (E14 C29): la próxima permanente a la que apunta el ahorro.
struct SavingsGoal: Equatable {
    let offer: PermanentOffer
    let balance: Int

    var saved: Int { min(max(balance, 0), offer.price) }
    var isReady: Bool { balance >= offer.price }
    var progress: Double { offer.price > 0 ? Double(saved) / Double(offer.price) : 1 }

    /// La que el jugador fijó, si todavía se puede comprar; si no, la de mayor
    /// impacto que falta (las ofertas llegan ya en ese orden).
    static func pick(from offers: [PermanentOffer], pinned: String?) -> PermanentOffer? {
        offers.first { $0.id == pinned } ?? offers.first
    }

    /// La que sigue a `current` en la lista, dando la vuelta.
    static func next(after current: PermanentOffer?, in offers: [PermanentOffer]) -> PermanentOffer? {
        guard let current, let index = offers.firstIndex(where: { $0.id == current.id }) else { return offers.first }
        return offers[(index + 1) % offers.count]
    }
}

extension GameState {
    private static let pinnedGoalKey = "upgrades.goal.pinned"

    /// Las permanentes por comprar, de mayor a menor impacto: lugares extra y lo
    /// demás del catálogo primero, después las siete globales en el orden del dato.
    var permanentOffers: [PermanentOffer] {
        let shop = blueShopRows(chanceAllowed: false).compactMap { row -> PermanentOffer? in
            guard row.item.isPermanent, row.quote.blocker != .maxed, let price = row.quote.price else { return nil }
            return PermanentOffer(source: .shop(id: row.id), price: price)
        }
        let lines = (content?.upgradesConfig.upgrades ?? []).compactMap { line -> PermanentOffer? in
            guard upgradeLevel(of: line.id) < line.maxLevel else { return nil }
            return PermanentOffer(source: .line(id: line.id), price: Int(upgradeCost(of: line).rounded(.up)))
        }
        return shop + lines
    }

    var savingsGoal: SavingsGoal? {
        let offers = permanentOffers
        guard let offer = SavingsGoal.pick(from: offers, pinned: flagDefaults.string(forKey: Self.pinnedGoalKey))
        else { return nil }
        return SavingsGoal(offer: offer, balance: player?.meta.blue ?? 0)
    }

    /// El jugador elige otra meta: pasa a la siguiente y queda fijada.
    func cycleSavingsGoal() {
        let offers = permanentOffers
        guard let current = savingsGoal?.offer, let next = SavingsGoal.next(after: current, in: offers) else { return }
        flagDefaults.set(next.id, forKey: Self.pinnedGoalKey)
        effectsVersion += 1
    }

    /// Cobra la meta por el mismo camino que la fila de su estante.
    func buyPermanentOffer(_ offer: PermanentOffer) {
        switch offer.source {
        case .shop(let id): buyBlueShopItem(id: id, chanceAllowed: false)
        case .line(let id): buyUpgrade(lineId: id)
        }
    }

    /// Nombre, efecto y arte de una oferta, resueltos para la tarjeta de la meta.
    func permanentOfferCopy(_ offer: PermanentOffer) -> (name: String, effect: String, iconKey: String)? {
        switch offer.source {
        case .shop(let id):
            guard let item = content?.blueShop.item(id: id) else { return nil }
            let level = player?.meta.engagement.shop.levels[id] ?? 0
            return (BlueShopCopy.name(for: item), BlueShopCopy.detail(for: item, level: level), item.iconKey)
        case .line(let id):
            guard let line = content?.upgradesConfig.upgrades.first(where: { $0.id == id }) else { return nil }
            return (Self.localized(line.titleKey), upgradeEffectText(for: line), line.iconKey)
        }
    }
}
