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
        // `max(1, ...)`: `floorsPerChest` es un dato sin validar al cargar y esto
        // corre en CADA merge — un 0 en el JSON sería una división por cero en el
        // embudo más caliente del juego, no un cofre mal contado.
        let cadaCuantos = max(1, content.chests.floorsPerChest)
        let debidos = player.run.unlockedFloors.count / cadaCuantos
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
    ///
    /// ⚠️ **El piso viaja en el CONTADOR, así que `.epica` está escrito dos veces
    /// y sin acoplamiento**: `confirmPrestige` lo pasa acá —que sólo mira si es
    /// `nil` para elegir contador— y `openChest` lo vuelve a nombrar al sortear.
    /// El día que `confirmPrestige` suba el piso a `.legendaria`, el cofre se
    /// guarda igual pero se abre con el viejo, y nada se pone rojo. Se acepta a
    /// sabiendas: guardar el piso por cofre pide un bump de schema por una sola
    /// fuente. Con una SEGUNDA fuente con piso, esto deja de alcanzar.
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

    /// Abre un cofre: gasta uno de los pendientes, sortea y deja el premio listo
    /// para que la cola lo muestre.
    ///
    /// **Gasta primero el de prestigio.** Los dos contadores son cofres, pero el de
    /// prestigio garantiza épica o mejor: si se gastara último, el jugador cobraría
    /// sus mejores cofres al final de una tanda y los peores primero.
    ///
    /// ⚠️ Quien escriba la vista: el dismiss tiene que limpiar `chestReward`
    /// **antes** de `celebrationFinished(.chestOpening)`. El porqué —y lo que
    /// pasa si no— está en el doc del campo, en `GameState.swift`.
    func openChest() {
        // Un cofre por vez: sin esto, dos toques seguidos pisan el payload y el
        // primer premio se pierde entre que la cola le da el turno y la vista lo lee.
        guard chestReward == nil, pendingChestCount > 0,
              let content, let economy, var player else { return }

        let dePrestigio = player.meta.prestigeChestsPending > 0
        if dePrestigio { player.meta.prestigeChestsPending -= 1 } else { player.meta.chestsPending -= 1 }

        let outcome = ChestRoller.roll(
            owned: player.meta.allOwnedSkins,
            skins: content.skins,
            config: content.chests,
            minRarity: dePrestigio ? .epica : nil,
            using: &rng
        )

        let detalle: String
        var pagado: Double?
        switch outcome {
        case let .skin(id, _, rarity):
            // ⚠️ **A `milestoneSkins`, NUNCA a `ownedSkins`.** StoreKit REESCRIBE
            // `ownedSkins` entera en cada sync (`PlayerState.swift`), así que una
            // pinta de cofre guardada ahí se borraría con un "restaurar compras" — y
            // de paso reabriría el gate del día 7, que lee `allOwnedSkins`.
            player.meta.milestoneSkins = Array(Set(player.meta.milestoneSkins).union([id])).sorted()
            detalle = "pinta \(id) (\(rarity.rawValue))"
        case let .coins(rarity):
            // La MISMA fórmula que el fallback del día 7, que es lo que hace que
            // los dos premios de plata del juego se sientan del mismo tamaño.
            let monto = economy.passiveUnlockCost(forTier: player.run.maxTierReached)
                * (dePrestigio ? content.chests.prestigePayoutFactor : content.chests.completedPayoutFactor)
            player.run.coins += monto
            player.meta.lifetimeEarnings += monto
            pagado = monto
            detalle = "plata \(monto) (\(rarity.rawValue))"
        }

        self.player = player
        // La única acción del jugador que muta `meta` sin un embudo detrás que
        // guarde: el botón de Regalos llama acá y nada más. Sin esto, el cofre
        // gastado y la pinta ganada viven sólo en memoria.
        scheduleSave()
        // Sólo si cambió la colección: con un premio de plata la ficha no tiene
        // nada nuevo que redibujar.
        if case .skin = outcome { skinSelectionVersion &+= 1 }
        chestReward = ChestReward(outcome: outcome, coins: pagado)
        syncCelebrations()
        let quedan = pendingChestCount
        Log.economy.info("cofre abierto\(dePrestigio ? " de prestigio" : ""): \(detalle); quedan \(quedan)")
    }

    /// Cierra la animación del cofre. **El orden de estas dos líneas es el
    /// contrato**, no un detalle de estilo.
    ///
    /// Con `celebrationFinished` primero, `syncCelebrations()` vuelve a ver el
    /// payload puesto y reencola `.chestOpening` en el mismo frame. Y como esa
    /// celebración no tiene `timeout` —el watchdog nunca la vence— ni es
    /// salteable —el tap nunca la saltea—, `showing` queda pegado para siempre
    /// con el HUD apagado y la cola entera congelada. Existe como método —y no
    /// como dos líneas en la vista— para que el orden se pueda testear sin
    /// levantar la UI.
    func dismissChestReward() {
        chestReward = nil
        celebrationFinished(.chestOpening)
    }

    /// Lo que muestran el puntito y la tarjeta de Regalos.
    var pendingChestCount: Int {
        (player?.meta.chestsPending ?? 0) + (player?.meta.prestigeChestsPending ?? 0)
    }
}
