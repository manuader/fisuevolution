import Foundation

/// "Resetear partida" (PLAN-v2 E9), puro: la pantalla muestra `summary` y el juego escribe
/// `result`, los dos salidos de la misma cuenta. Se conserva lo comprado con plata; el ORO
/// comprado sólo si no se gastó (`min(saldo, comprado)`). Lo demás es la partida nueva que
/// recibe. De las ofertas queda lo ya usado y lo pagado (no se vuelven a vender las de una
/// vez); las abiertas se cierran.
public struct ResetPlan: Sendable, Equatable {
    public struct Summary: Sendable, Equatable {
        public let oroBalance: Int
        public let oroPurchased: Int
        public let oroEarned: Int
        public let oroKept: Int
        public let prestigeLevel: Int
        public let unitsOnBoard: Int
        public let achievements: Int
        public let skinsLost: Int
        public let keepsRemoveAds: Bool
        public let keptSkins: Int
    }

    public let summary: Summary
    public let result: PlayerState

    public static func make(current: PlayerState, fresh: PlayerState) -> ResetPlan {
        let old = current.meta
        let kept = max(0, min(old.oro, old.oroPurchasedLifetime))
        var result = fresh
        result.meta.oro = kept
        result.meta.removedAds = old.removedAds
        result.meta.ownedSkins = old.ownedSkins
        result.meta.activeSkinByType = old.activeSkinByType.filter { old.ownedSkins.contains($0.value) }
        result.meta.creditedPurchases = old.creditedPurchases
        for (id, amount) in old.oroPurchases { result.meta.recordOroPurchase(transactionID: id, amount: amount) }
        for id in old.revokedPurchases { result.meta.revokePurchase(transactionID: id) }
        result.meta.purchasedOroReconstructed = old.purchasedOroReconstructed
        result.meta.engagement.seenCinematics = old.engagement.seenCinematics
        result.meta.engagement.offers.everOpened = old.engagement.offers.everOpened
        result.meta.engagement.offers.purchases = old.engagement.offers.purchases
        result.meta.engagement.offers.lastClosedAt = old.engagement.offers.lastClosedAt
        result.meta.engagement.firstLaunchDay = old.engagement.firstLaunchDay
        result.meta.resetEpoch = old.resetEpoch + 1

        let lostSkins = old.allOwnedSkins.subtracting(old.ownedSkins)
        let summary = Summary(
            oroBalance: old.oro,
            oroPurchased: old.oroPurchasedLifetime,
            oroEarned: max(0, old.oro - kept),
            oroKept: kept,
            prestigeLevel: old.prestigeLevel,
            unitsOnBoard: current.run.totalUnits,
            achievements: old.unlockedAchievements.count,
            skinsLost: lostSkins.count,
            keepsRemoveAds: old.removedAds,
            keptSkins: old.ownedSkins.count
        )
        return ResetPlan(summary: summary, result: result)
    }
}
