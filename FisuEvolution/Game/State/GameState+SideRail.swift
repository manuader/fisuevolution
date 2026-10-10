import EconomyKit
import Foundation

/// La columna lateral en la partida (PLAN-v2 §2, "Accesos en pantalla"): qué
/// dice cada botón, publicado en `sideRail`, y el estado de sus dos videos.
extension GameState {
    /// Las claves de `meta.rewardedActivations` de los dos videos de la columna.
    static let mergeAllVideoKey = "siderail.mergeAll"
    static let packageRainVideoKey = "siderail.packageRain"

    func refreshSideRail(now: TimeInterval = Date().timeIntervalSince1970) {
        let pairs = mergeAllPairsOnVisibleFloor()
        let input = SideRailInput(
            shown: phase == .ready && !tutorialPhaseActive,
            access: prizeAccess,
            packageSecondsUntilNext: player?.meta.engagement.packages.secondsUntilNext,
            mattressSecondsUntilNext: player?.meta.engagement.treasures.secondsUntilNext,
            wheelSecondsUntilReset: Self.secondsUntilNextWheelDay(now: Date(timeIntervalSince1970: now)),
            mergeAllPairs: pairs,
            mergeAll: mergeAllVideoStatus(pairs: pairs, now: now),
            packageRain: packageRainStatus(now: now)
        )
        let state = SideRailModel.state(input)
        if sideRail != state { sideRail = state }
    }

    /// Hay un "Fusionar todo" (por video, por ORO o en cadena) encolado o en
    /// vuelo. El plan mira el tablero sin lo ya encolado: con una fusión
    /// pendiente volvería a ver los mismos pares y los cobraría de nuevo.
    var mergeAllIsQueued: Bool {
        (pendingBoardChanges + [inFlightBoardChange].compactMap { $0 })
            .contains { $0.origin == .oroShop || $0.origin == .rewardedMergeAll || $0.chain != nil }
    }

    /// Cuántas fusiones encolaría "Fusionar todo" ahora: el mismo plan que se
    /// ejecuta (lo que se muestra es lo que se aplica).
    func mergeAllPairsOnVisibleFloor() -> Int {
        guard !mergeAllIsQueued, let content, let player, let tower else { return 0 }
        return BoardChangePlanner.planMergeAll(
            floorOrdinal: visibleFloorOrdinal, state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy, origin: .rewardedMergeAll
        ).count
    }

    func mergeAllVideoStatus(pairs: Int, now: TimeInterval) -> RailVideoStatus {
        guard let content else { return .notApplicable }
        let remaining = cooldownRemaining(
            key: Self.mergeAllVideoKey, seconds: content.rewardedAds.effectiveSideRail.mergeAllCooldownSeconds, now: now
        )
        if remaining > 0 { return .coolingDown(seconds: remaining) }
        return pairs > 0 ? .available : .notApplicable
    }

    /// La lluvia se ofrece si puede hacer algo: hay lugar en el buzón, el
    /// paquete entra y ningún evento cortó los paquetes (el piquete).
    func packageRainStatus(now: TimeInterval) -> RailVideoStatus {
        guard let content, let player else { return .notApplicable }
        let remaining = cooldownRemaining(
            key: Self.packageRainVideoKey, seconds: content.rewardedAds.effectiveSideRail.packageRainCooldownSeconds, now: now
        )
        if remaining > 0 { return .coolingDown(seconds: remaining) }
        let rate = ModifierMath.factor(player.run.activeModifiers, effect: .packageRateMultiplier, now: now)
        let room = player.meta.engagement.packages.waiting < content.packages.maxWaiting
        return rate > 0 && room && !packagesBlocked ? .available : .notApplicable
    }

    /// Hasta la medianoche del día de los cupos de la ruleta, que es el del
    /// diario en calendario gregoriano fijo (`wheelDay`).
    static func secondsUntilNextWheelDay(now: Date, calendar: Calendar = wheelCalendar) -> TimeInterval {
        let start = calendar.startOfDay(for: now)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
        return max(0, next.timeIntervalSince(now))
    }

    private static var wheelCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func cooldownRemaining(key: String, seconds: Double, now: TimeInterval) -> Double {
        let last = player?.meta.rewardedActivations[key] ?? -.infinity
        return max(0, seconds - (now - last))
    }
}
