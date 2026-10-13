import EconomyKit
import Foundation

/// Las **ofertas de video**: los momentos en que el juego propone mirar un
/// anuncio a cambio de algo (pedido del dueño, 2026-09-02).
///
/// Son distintas de los videos de Regalos, y la diferencia es la que ordena
/// todo el archivo: **la lista de Regalos es un catálogo al que el jugador va;
/// una oferta lo encuentra a él, en el momento en que el premio vale más.**
/// Duplicar lo que ganaste anoche importa cuando estás mirando cuánto ganaste;
/// otro cofre importa cuando acabás de abrir uno.
///
/// ## Las tres reglas que las tres ofertas comparten
///
/// 1. **Opt-in explícito, siempre.** Es política de AdMob —"Rewarded ads must
///    always be an opt-in experience"— y por eso ninguna de estas funciones
///    muestra un anuncio: cada una es lo que pasa DESPUÉS de que el jugador
///    tocó un botón que decía qué iba a recibir. El video lo presenta la vista.
/// 2. **Se cobra sólo si el premio se ganó.** El `false` de
///    `showRewarded(for:)` —jugador que cierra el anuncio a la mitad— no llega
///    nunca acá.
/// 3. **Una vez por evento.** Las tres se apagan solas después de cobrarse
///    (`offlineRewardDoubled`, `extraChestClaimed`), o el jugador podría
///    duplicar el mismo offline diez veces seguidas.
extension GameState {

    // MARK: - Duplicar el offline

    /// Paga otra vez lo que el offline ya acreditó.
    ///
    /// El premio de offline **ya está cobrado** cuando el popup aparece
    /// (`applyOfflineProgressIfNeeded` lo acredita y recién después publica
    /// `offlineReward`), así que "duplicar" es sumar el MISMO monto una segunda
    /// vez, y no recalcular nada. Recalcular sería peor que redundante: el
    /// tiempo offline ya se consumió del save, así que un segundo cálculo
    /// daría cero.
    ///
    /// ⚠️ El monto sale del `reward` que la vista tiene en la mano y no de
    /// `offlineReward`, que para cuando el video termina puede haber sido
    /// limpiado por el dismiss de la hoja.
    func doubleOfflineReward(_ reward: OfflineReward) {
        guard !offlineRewardDoubled, var player else { return }
        offlineRewardDoubled = true
        player.run.coins += reward.amount
        player.meta.lifetimeEarnings += reward.amount
        self.player = player
        audio?.play(.coin)
        Log.economy.info("offline reward doubled by ad: \(reward.amount)")
        refreshProjections()
        scheduleSave()
    }

    // MARK: - Un cofre más

    /// Regala un cofre extra y lo abre.
    ///
    /// Va por `awardChest()` + `openChest()` —los mismos dos métodos que usa
    /// todo el resto del juego— en vez de sortear una skin por su cuenta: el
    /// sorteo, la promoción de rareza y la animación de los cuatro toques son
    /// de ahí, y una segunda vía de premio sería la clase de duplicación que
    /// `SkinMilestones` ya evita por construcción.
    ///
    /// Sin `minRarity`: el cofre del video es un cofre común. El piso de
    /// épica es del cofre de reencarnación, que cuesta mucho más que un video.
    /// ⚠️ El orden de las tres líneas es el contrato: `awardChest()` **rearma**
    /// la bandera (todo cofre nuevo vuelve a ofrecer), así que marcarla antes no
    /// serviría de nada. Se cierra al final, y eso es lo que corta la cadena:
    /// el cofre que salió de un video no ofrece otro.
    func grantExtraChestFromAd() {
        guard !extraChestClaimed else { return }
        awardChest()
        openChest()
        extraChestClaimed = true
        Log.economy.info("extra chest granted by ad")
    }

    /// Si el cofre del video tendría algo que dar. Sin esto, con todo lo
    /// alcanzable ya ganado, `openChest()` guardaría el cofre en silencio y el
    /// jugador habría mirado un anuncio sin ver nada abrirse.
    var canOfferExtraChest: Bool {
        guard !extraChestClaimed, let content, let player else { return false }
        return ChestRoller.hasSomethingToGive(
            owned: player.meta.allOwnedSkins,
            unlocked: chestUnlockedCharacterTypes,
            skins: content.skins
        )
    }

    // MARK: - El boost en cooldown

    /// Activa por video un boost en cooldown: **una vez por ciclo**.
    ///
    /// El video reemplaza la activación anterior y el boost entra en un cooldown
    /// **completo desde ahora**; la oferta no vuelve hasta la próxima activación
    /// gratis (C32). Antes se restauraba el cooldown previo y la tarjeta seguía
    /// ofreciendo el video: se podía repetir sin fin, y como el mismo boost se
    /// apilaba, el Turbo se multiplicaba con cada video.
    ///
    /// La activación y la marca del video se escriben en el mismo `PlayerState`
    /// y se guardan juntas: matar la app a mitad pierde las dos o ninguna.
    @discardableResult
    func activateBoostFromAd(id: String, now: TimeInterval = Date().timeIntervalSince1970) -> Double? {
        guard let economy, let content, var player else { return nil }
        guard let boost = content.boosts.boosts.first(where: { $0.id == id }),
              isBoostUnlocked(boost) else {
            Log.economy.info("ad boost locked: \(id)")
            return nil
        }
        guard !BoostManager.adUsedThisCycle(boostId: id, state: player) else {
            Log.economy.info("ad boost already used this cycle: \(id)")
            return nil
        }
        player.meta.boostActivations[id] = nil
        do {
            let payout = try BoostManager.activate(
                boostId: id,
                state: &player,
                config: content.boosts,
                upgrades: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                tiers: content.tiers,
                floorTable: content.floorTable,
                economy: economy,
                now: now
            )
            player.meta.rewardedActivations[BoostManager.adUsageKey(id)] = now
            player.meta.stats.boostsActivatedEver += 1
            self.player = player
            effectsVersion += 1
            if payout != nil { audio?.play(.coin) }
            evaluateAchievements()
            refreshProjections()
            scheduleSave()
            Log.economy.info("boost activated by ad: \(id)")
            return payout
        } catch {
            Log.economy.info("ad boost rejected: \(error)")
            return nil
        }
    }
}
