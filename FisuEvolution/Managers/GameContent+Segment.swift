import EconomyKit
import Foundation

/// Las palancas de reloj de un segmento (2.1 E15 F2 T7): el colchón gratis del tablero, los
/// visitantes y las pausas del costado, más seguidos. Se aplican transformando el contenido, con la
/// misma función en el juego y en el `PacingFixture`: el sim y el juego no pueden divergir.
extension GameContent {
    /// Los tres relojes que mueven las palancas, juntos: lo único que `applying` cambia.
    struct SegmentClocks: Sendable, Equatable {
        var treasures: TreasuresConfig
        var visitors: VisitorsConfig
        var rewardedAds: RewardedAdsConfig
    }

    var segmentClocks: SegmentClocks {
        SegmentClocks(treasures: treasures, visitors: visitors, rewardedAds: rewardedAds)
    }

    /// El contenido con los relojes de `levers`. Con la base, el mismo contenido.
    func applying(_ levers: SegmentLevers.Levers) -> GameContent {
        replacing(segmentClocks.applying(levers))
    }

    /// El contenido con estos relojes y todo lo demás igual.
    func replacing(_ clocks: SegmentClocks) -> GameContent {
        guard clocks != segmentClocks else { return self }
        return GameContent(
            economy: economy,
            tiers: tiers,
            floorTable: floorTable,
            baseFloorTable: baseFloorTable,
            manifest: manifest,
            flags: flags,
            prestigeUnlocks: prestigeUnlocks,
            rewardedAds: clocks.rewardedAds,
            events: events,
            specials: specials,
            skins: skins,
            chests: chests,
            upgradesConfig: upgradesConfig,
            dailyRewards: dailyRewards,
            boosts: boosts,
            careers: careers,
            viral: viral,
            gameCenter: gameCenter,
            achievements: achievements,
            tabs: tabs,
            notifications: notifications,
            visitors: clocks.visitors,
            packages: packages,
            treasures: clocks.treasures,
            wheel: wheel,
            offers: offers,
            blueShop: blueShop
        )
    }
}

extension GameContent.SegmentClocks {
    /// Cada escala, sólo sobre su reloj. Una escala de 1 no toca nada: la base es la 2.0 bit a bit.
    func applying(_ levers: SegmentLevers.Levers) -> Self {
        var clocks = self
        if levers.freeMattressIntervalScale != 1 {
            clocks.treasures = treasures.scalingFreeBoardInterval(by: levers.freeMattressIntervalScale)
        }
        if levers.visitorIntervalScale != 1 {
            clocks.visitors = visitors.scalingInterval(by: levers.visitorIntervalScale)
        }
        if levers.sideRailCooldownScale != 1 {
            clocks.rewardedAds.sideRail = rewardedAds.effectiveSideRail.scalingCooldowns(by: levers.sideRailCooldownScale)
        }
        return clocks
    }
}

private extension TreasuresConfig {
    func scalingFreeBoardInterval(by scale: Double) -> TreasuresConfig {
        TreasuresConfig(
            schemaVersion: schemaVersion, spawnIntervalSeconds: spawnIntervalSeconds,
            firstTreasureAfterSeconds: firstTreasureAfterSeconds, extraOpensPerTreasure: extraOpensPerTreasure,
            freeBoardIntervalSeconds: freeBoardIntervalSeconds * scale,
            prizes: prizes, freeBoardPrizes: freeBoardPrizes
        )
    }
}

private extension VisitorsConfig {
    func scalingInterval(by scale: Double) -> VisitorsConfig {
        VisitorsConfig(
            schemaVersion: schemaVersion, firstVisitAfterSeconds: firstVisitAfterSeconds,
            intervalMinSeconds: intervalMinSeconds * scale, intervalMaxSeconds: intervalMaxSeconds * scale,
            retryWhenNoneSeconds: retryWhenNoneSeconds, patienceSeconds: patienceSeconds,
            presenterTalkSeconds: presenterTalkSeconds, coinsSecondsScale: coinsSecondsScale,
            visitors: visitors, scripts: scripts
        )
    }
}

private extension RewardedAdsConfig.SideRail {
    func scalingCooldowns(by scale: Double) -> RewardedAdsConfig.SideRail {
        RewardedAdsConfig.SideRail(
            mergeAllCooldownSeconds: mergeAllCooldownSeconds * scale,
            packageRainCooldownSeconds: packageRainCooldownSeconds * scale,
            packageRain: packageRain
        )
    }
}
