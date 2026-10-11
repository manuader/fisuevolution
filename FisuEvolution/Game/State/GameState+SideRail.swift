import EconomyKit
import Foundation

/// La columna lateral en la partida (PLAN-v2 §2, "Accesos en pantalla"): qué
/// dice cada botón, publicado en `sideRail`, y el estado de sus dos videos.
extension GameState {
    /// Las claves de `meta.rewardedActivations` de los dos videos de la columna.
    /// Fusionar todo por video tiene UNA sola clave de enfriamiento: la fila
    /// `merge_all` de Regalos ya no existe. Un save viejo con
    /// `rewardedActivations["merge_all"]` la conserva sin que nadie la lea.
    static let mergeAllVideoKey = "siderail.mergeAll"
    static let packageRainVideoKey = "siderail.packageRain"

    func refreshSideRail(now: TimeInterval = Date().timeIntervalSince1970) {
        let pairs = mergeAllPairsOnVisibleFloor()
        let input = SideRailInput(
            shown: phase == .ready && !tutorialPhaseActive,
            access: prizeAccess,
            packageSecondsUntilNext: player?.meta.engagement.packages.secondsUntilNext,
            packagesPaused: packageRate(now: now) <= 0,
            mattressSecondsUntilNext: player?.meta.engagement.treasures.secondsUntilNext,
            wheelSecondsUntilReset: wheelSecondsUntilReset(now: now),
            mergeAllPairs: pairs,
            mergeAll: mergeAllVideoStatus(pairs: pairs, now: now),
            packageRain: packageRainStatus(now: now)
        )
        let state = SideRailModel.state(input)
        if sideRail != state { sideRail = state }
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

    /// La lluvia se ofrece si puede hacer algo: hay lugar en el buzón y ningún
    /// evento cortó los paquetes (el piquete). Si no puede hacer nada no se
    /// ofrece ni muestra reloj: un enfriamiento ahí prometería un video que
    /// tampoco serviría.
    func packageRainStatus(now: TimeInterval) -> RailVideoStatus {
        guard let content, let player else { return .notApplicable }
        let room = player.meta.engagement.packages.waiting < content.packages.maxWaiting
        guard packageRate(now: now) > 0, room, !packagesBlocked else { return .notApplicable }
        let remaining = cooldownRemaining(
            key: Self.packageRainVideoKey, seconds: content.rewardedAds.effectiveSideRail.packageRainCooldownSeconds, now: now
        )
        return remaining > 0 ? .coolingDown(seconds: remaining) : .available
    }

    private func packageRate(now: TimeInterval) -> Double {
        ModifierMath.factor(player?.run.activeModifiers ?? [], effect: .packageRateMultiplier, now: now)
    }

    /// Hasta que vuelven los giros por video de la ruleta. `nil` si no hay
    /// ruleta o no hay nada que esperar (los giros regalados no vencen): el
    /// botón queda apagado en vez de contar hasta una medianoche que no
    /// devuelve nada.
    private func wheelSecondsUntilReset(now: TimeInterval) -> TimeInterval? {
        guard effectiveWheel != nil, let readyAt = wheelSpinsReadyAt(now: now) else { return nil }
        return max(0, readyAt - now)
    }

    private func cooldownRemaining(key: String, seconds: Double, now: TimeInterval) -> Double {
        let last = player?.meta.rewardedActivations[key] ?? -.infinity
        return min(seconds, max(0, seconds - (now - last)))
    }
}

// MARK: - Los videos

/// Cuántos eslabones de una cadena de Fusionar todo por video ya se jugaron o
/// se descartaron, y cuántos de ésos se aplicaron.
private struct VideoChainTally {
    var resolved = 0
    var applied = 0
}

extension GameState {
    @MainActor private static var videoChains: [UUID: VideoChainTally] = [:]

    /// ¿Se puede ofrecer el video de Fusionar todo ahora? Relee el piso en
    /// vivo (no la proyección, que llega a lo sumo una vez por segundo) y pide
    /// el tablero libre: el anuncio no tapa una hoja ni una celebración.
    func canOfferMergeAllVideo(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        !isBoardBusy && mergeAllVideoStatus(pairs: mergeAllPairsOnVisibleFloor(), now: now) == .available
    }

    /// Lo mismo para la lluvia de paquetes.
    func canOfferPackageRainVideo(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        !isBoardBusy && packageRainStatus(now: now) == .available
    }

    /// Terminó el video de "Fusionar todo": se encolan todos los pares del piso
    /// a la vista (E2a) y cada uno se juega en su turno del tablero. El efecto
    /// se aplica ANTES de marcar el enfriamiento; si ya no hay nada que fusionar
    /// (o ya hay una cadena en la cola) el video no gasta el enfriamiento y
    /// compensa (E1 T14: un video nunca es en vano). Acá no se mira
    /// `isBoardBusy`: el anuncio pudo dejar la escena inactiva, y lo encolado
    /// espera su turno a la vista.
    func mergeAllVideoWatched(now: TimeInterval = Date().timeIntervalSince1970) {
        countRailVideo()
        guard mergeAllVideoStatus(pairs: mergeAllPairsOnVisibleFloor(), now: now) == .available,
              enqueueMergeAll(onFloor: visibleFloorOrdinal, origin: .rewardedMergeAll) > 0
        else {
            compensateRewardedVideo()
            return
        }
        player?.meta.rewardedActivations[Self.mergeAllVideoKey] = now
        Log.ads.info("fusionar todo por video")
        refreshSideRail(now: now)
        scheduleSave()
    }

    /// Terminó el video de la lluvia: ×10 paquetes por un minuto (el dato de
    /// `rewarded_ads.json`). Si ya no podía hacer nada, compensa sin gastar.
    func packageRainVideoWatched(now: TimeInterval = Date().timeIntervalSince1970) {
        countRailVideo()
        guard let content, packageRainStatus(now: now) == .available else {
            compensateRewardedVideo()
            return
        }
        grant(content.rewardedAds.effectiveSideRail.packageRain, source: "siderail.packageRain", now: now)
        player?.meta.rewardedActivations[Self.packageRainVideoKey] = now
        refreshSideRail(now: now)
        scheduleSave()
    }

    /// El contador de videos va donde va el video, con o sin efecto (el mismo
    /// criterio que `applyRewardedReward`).
    private func countRailVideo() {
        player?.meta.stats.videosWatchedEver += 1
        effectsVersion += 1
        evaluateAchievements()
    }

    /// Un eslabón de una cadena de video se jugó o se descartó. Si TODOS los de
    /// la cadena se descartaron, el jugador no vio ningún efecto de un video
    /// que ya se miró: compensa, una sola vez. Con uno solo aplicado, el video
    /// ya pagó. Lo llama el embudo (`+BoardChanges`).
    func noteVideoChainLink(_ change: BoardChange, applied: Bool) {
        guard change.origin == .rewardedMergeAll, let chain = change.chain else { return }
        var tally = Self.videoChains[chain.id] ?? VideoChainTally()
        tally.resolved += 1
        if applied { tally.applied += 1 }
        guard tally.resolved >= chain.count else {
            Self.videoChains[chain.id] = tally
            return
        }
        Self.videoChains[chain.id] = nil
        if tally.applied == 0 { compensateRewardedVideo() }
    }
}
