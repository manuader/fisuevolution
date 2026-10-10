import EconomyKit
import Foundation

/// Lo que trae una oferta, renglón por renglón, con los números del dato. Cada
/// renglón lo dice `RewardCopy` (E5b T1): la ruleta, el colchón, la tienda y las
/// ofertas nombran un premio de una sola manera.
enum OfferCopy {
    static func lines(for offer: OffersCatalog.Offer) -> [String] {
        offer.rewards.map(RewardCopy.title)
    }

    /// "23:59:58": lo que falta para que venza.
    static func countdown(until expiresAt: TimeInterval, now: Date) -> String {
        let left = max(0, expiresAt - now.timeIntervalSince1970)
        return Duration.seconds(left.rounded(.down)).formatted(.time(pattern: .hourMinuteSecond))
    }
}
