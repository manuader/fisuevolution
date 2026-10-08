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

    /// Activa un boost **ignorando su cooldown y sin consumirlo**.
    ///
    /// Es exactamente lo que ya hace el premio de carrera `freeBoost`, y a
    /// propósito comparte el mecanismo: se borra la activación previa, se
    /// activa por el camino normal, y se restaura. Así el jugador **no pierde
    /// el cooldown que ya tenía corriendo** —mirar el video le adelanta ESTE
    /// uso, no le reinicia el reloj— y los cinco efectos no se reimplementan.
    ///
    /// ⚠️ Restaurar la activación previa es lo que hace que la oferta sea un
    /// regalo y no un castigo: sin eso, mirar un video a los 10 minutos de un
    /// cooldown de 4 h te dejaba el reloj arrancando de cero.
    @discardableResult
    func activateBoostFromAd(id: String) -> Double? {
        guard let economy, let content, var player else { return nil }
        guard let boost = content.boosts.boosts.first(where: { $0.id == id }),
              isBoostUnlocked(boost) else {
            Log.economy.info("ad boost locked: \(id)")
            return nil
        }
        let previous = player.meta.boostActivations[id]
        player.meta.boostActivations[id] = nil
        defer {
            // El cooldown que ya corría sigue corriendo desde donde estaba.
            var restored = self.player
            restored?.meta.boostActivations[id] = previous
            if let restored { self.player = restored }
            effectsVersion += 1
            refreshProjections()
            scheduleSave()
        }
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
                now: Date().timeIntervalSince1970
            )
            player.meta.stats.boostsActivatedEver += 1
            self.player = player
            if payout != nil { audio?.play(.coin) }
            evaluateAchievements()
            Log.economy.info("boost activated by ad: \(id)")
            return payout
        } catch {
            Log.economy.info("ad boost rejected: \(error)")
            return nil
        }
    }
}
