import EconomyKit
import Foundation

/// Los cofres de pintas: quién los reparte y cómo se cuentan. Separado de
/// `GameState.swift` para que el frente del cofre no comparta archivo con los
/// otros cinco dominios.
///
/// Acá viven las fuentes; el sorteo es de `ChestRoller` (EconomyKit) y pasa
/// recién al abrirlo. Un cofre pendiente es un número, no un premio guardado:
/// así el jugador no puede farmear tiradas mirando el save.
extension GameState {
    /// La torre paga cada `floorsPerChest` pisos. El contador vive en `run` y
    /// cuenta CUÁNTOS pagó, no cuáles: así re-desbloquear un piso que ya viste
    /// no vuelve a pagar, y volver a subir la torre después de reencarnar sí.
    ///
    /// ⚠️ Cuelga de `updateMaxFloorStat()`, que corre en CADA merge: sin el
    /// contador esto sería un cofre por fusión.
    func awardFloorChestsIfDue() {
        guard let content, var player else { return }
        let debidos = player.run.unlockedFloors.count / content.chests.floorsPerChest
        guard debidos > player.run.floorChestsAwarded else { return }
        let nuevos = debidos - player.run.floorChestsAwarded
        player.run.floorChestsAwarded = debidos
        player.meta.chestsPending += nuevos
        self.player = player
        Log.economy.info("cofres de torre: +\(nuevos) (pisos \(player.run.unlockedFloors.count))")
        syncCelebrations()
    }

    /// Suma un cofre. `minRarity` no se guarda por cofre: hay una sola fuente
    /// con piso —la reencarnación— así que alcanza con el segundo contador, y
    /// los dos se gastan de a uno con el de prestigio primero (el mejor premio
    /// se cobra antes).
    func awardChest(minRarity: SkinsConfig.Rarity? = nil) {
        guard var player else { return }
        if minRarity == nil {
            player.meta.chestsPending += 1
        } else {
            player.meta.prestigeChestsPending += 1
        }
        self.player = player
        syncCelebrations()
    }

    /// Lo que muestran el puntito y la tarjeta de Regalos.
    var pendingChestCount: Int {
        (player?.meta.chestsPending ?? 0) + (player?.meta.prestigeChestsPending ?? 0)
    }
}
