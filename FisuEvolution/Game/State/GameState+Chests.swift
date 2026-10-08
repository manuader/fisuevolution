import EconomyKit
import Foundation

/// Los cofres de pintas: quién los reparte y cómo se cuentan. Separado de
/// `GameState.swift` para que el frente del cofre no comparta archivo con los
/// otros cinco dominios.
///
/// Acá viven las fuentes; el sorteo es de `ChestRoller` (EconomyKit) y pasa
/// recién al abrirlo. Un cofre pendiente es un número, no un premio guardado:
/// así el jugador no puede farmear tiradas mirando el save.
///
/// La excepción es el **cofre de bienvenida** (`grantWelcomeChest`), que no se
/// guarda ni se sortea: su premio lo nombra `chests.json` y nace abierto, porque
/// es una escena del tutorial y no plata que el jugador administra.
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
        // Un cofre nuevo vuelve a habilitar la oferta del "abrí otro con un
        // video" (`+AdOffers`). Vive acá y no en la vista porque TODA fuente de
        // cofres pasa por este método: si la bandera se rearmara en el popup, la
        // oferta dependería de qué pantalla abrió el cofre.
        extraChestClaimed = false
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
        guard chestReward == nil, pendingChestCount > 0, let content, let player else { return }

        let dePrestigio = player.meta.prestigeChestsPending > 0

        let sorteo = ChestRoller.roll(
            owned: player.meta.allOwnedSkins,
            unlocked: chestUnlockedCharacterTypes,
            skins: content.skins,
            config: content.chests,
            minRarity: dePrestigio ? .epica : nil,
            using: &rng
        )

        // ⚠️ **El cofre se sortea ANTES de gastarse, y ése es el orden nuevo.**
        // Con la regla de desbloqueo hay un resultado que NO es un premio: el
        // jugador tiene cofres pero todavía no llegó a ningún personaje cuya
        // pinta le falte. Ese cofre no se consume — se queda esperando a que
        // suba, que es la decisión del dueño (2026-08-28). Gastarlo primero y
        // devolverlo después sería lo mismo sólo si nada fallara en el medio.
        guard case let .prize(outcome) = sorteo else {
            Log.economy.info("cofre guardado: nada alcanzable todavía (hay \(self.pendingChestCount))")
            return
        }

        var gastado = player
        if dePrestigio { gastado.meta.prestigeChestsPending -= 1 } else { gastado.meta.chestsPending -= 1 }
        self.player = gastado

        presentChestReward(
            outcome,
            payoutMinutes: dePrestigio ? content.chests.prestigePayoutMinutes : content.chests.completedPayoutMinutes,
            origen: "cofre abierto\(dePrestigio ? " de prestigio" : "") (quedan \(pendingChestCount))"
        )
    }

    /// Los personajes cuya pinta un cofre **puede** dar: los del piso más alto
    /// que la cuenta alcanzó en su historia, y todos los de abajo.
    ///
    /// Regla del dueño (2026-08-28): *es imposible que te toque la pinta de un
    /// personaje que no desbloqueaste*, y cuenta la historia GLOBAL — lo que
    /// abriste en reencarnaciones anteriores sigue valiendo. Por eso sale de
    /// `meta.stats.maxFloorOrdinalEver`, que es monótono y a prueba de
    /// reencarnación, y no de `run.unlockedFloors` ni de `run.seenTypes`, que
    /// mueren al reencarnar: con esos, el veterano que acaba de reencarnar
    /// volvería al callejón, ya tendría las 7 comunes, y sus cofres pagarían
    /// plata hasta volver a subir.
    ///
    /// ⚠️ **La granularidad es el PISO y no el tier, y es a propósito.** Filtrar
    /// por tier exacto encerraría las pintas de la rama de carrera que el jugador
    /// no eligió —nunca hacés un `junior_doctor` si sos programador—, así que la
    /// colección quedaría inalcanzable dentro de una run. Por piso, entrar a
    /// corporate vuelve ganables a los diez corporativos. El residuo es que puede
    /// tocarte alguien de tu mismo piso a pocos tiers de distancia; el caso que
    /// la regla persigue —la pinta de la Deidad estando en el Oficinista— queda
    /// muerto igual, que es lo que se pedía.
    var chestUnlockedCharacterTypes: Set<String> {
        guard let content, let player else { return [] }
        // El clamp de los dos lados no es paranoia de más: `floors` nunca está
        // vacío (`FloorTable.init` tira si lo estuviera), pero el ordinal viene
        // del save y un índice negativo o pasado de largo acá es un crash, no un
        // cofre mal sorteado.
        let ordinal = min(max(0, player.meta.stats.maxFloorOrdinalEver), content.floorTable.floors.count - 1)
        let hastaTier = content.floorTable.floors[ordinal].lastTier
        return Set(content.tiers.concreteTypes.lazy.filter { $0.tier <= hastaTier }.map(\.id))
    }

    /// ¿El botón de Regalos tiene algo que hacer? Es la misma pregunta que
    /// `openChest()` contesta al sortear, pero sin gastar RNG.
    ///
    /// Existe para que la tarjeta no ofrezca un botón que no va a hacer nada: con
    /// cofres guardados y nada alcanzable, lo honesto es decir que hay que subir.
    var canOpenChest: Bool {
        guard pendingChestCount > 0, let content, let player else { return false }
        return ChestRoller.hasSomethingToGive(
            owned: player.meta.allOwnedSkins,
            unlocked: chestUnlockedCharacterTypes,
            skins: content.skins
        )
    }

    /// El **cofre de bienvenida**: el único cofre guionado del juego.
    ///
    /// Cae al cerrar la fase obligatoria del tutorial —tap → contratar →
    /// fusionar— y se abre solo, porque la cola lo promueve apenas esa
    /// restricción se levanta. Es la respuesta al pedido del dueño: con las 41
    /// pintas saliendo **sólo** de cofres, la primera llegaba tarde, y ésta llega
    /// guionada y adentro del tutorial, con el personaje recién fusionado todavía
    /// en pantalla.
    ///
    /// **No pasa por el contador de pendientes.** `chestsPending` es plata que el
    /// jugador gasta cuando quiere, y su único consumidor —`openChest()`—
    /// SORTEA. Sumar y restar ahí en la misma llamada sería un rodeo por un
    /// contador que nadie llega a ver, para terminar sin poder usar al que lo
    /// gasta. Este cofre nace abierto.
    ///
    /// ⚠️ **El id sale de `chests.json`, no de Swift.** Es la constraint global de
    /// contenido, y ésta es la única pinta que el código tendría motivo para
    /// nombrar: cambiar cuál regala el tutorial tiene que ser una línea de JSON.
    /// Que el id exista en la bolsa lo pinea `GameContentValidationTests`.
    func grantWelcomeChest() {
        // `chestReward == nil` por lo mismo que `openChest()`: un cofre por vez.
        // Sólo el panel de debug puede dejar uno abierto durante la fase, y
        // perder el guionado es preferible a pisarle el premio a un cofre que el
        // jugador ya está mirando.
        guard chestReward == nil, let content, var player,
              !player.meta.welcomeChestGiven else { return }
        // De la BOLSA del cofre y no del catálogo entero: el premio del tutorial
        // tiene que ser una pinta que los cofres reparten. Un id que apunte a una
        // de tienda o de milestone deja el cofre sin premio en vez de regalar por
        // una vía que no es la suya.
        guard let pinta = content.skins.chestPool.first(where: { $0.id == content.chests.welcomeSkinId }),
              let rareza = pinta.chestRarity else { return }

        // La bandera es del SAVE y no de la sesión: el "Resetear partida" del
        // panel de debug revive la fase, y sin esto cada resurrección pagaría.
        player.meta.welcomeChestGiven = true
        self.player = player
        presentChestReward(
            .skin(id: pinta.id, characterType: pinta.characterType, rarity: rareza),
            // La rama de plata no corre acá —el premio es una pinta fija— pero los
            // minutos del cofre común son los que le corresponderían.
            payoutMinutes: content.chests.completedPayoutMinutes,
            origen: "cofre de bienvenida"
        )
    }

    /// Acredita el premio de un cofre y lo deja listo para que la cola lo
    /// muestre. Lo comparten el cofre que el jugador abre y el de bienvenida.
    ///
    /// Está compartido y no duplicado porque acá adentro vive el **contrato de
    /// `milestoneSkins`**: un segundo camino que lo repitiera sería un segundo
    /// lugar donde equivocarse, y el modo de equivocarse borra la colección
    /// entera del jugador la primera vez que toca "restaurar compras".
    ///
    /// `payoutMinutes` sólo se usa en la rama de plata: los minutos de producción
    /// del cofre común o del de la reencarnación.
    ///
    /// `content` se arma en el mismo bootstrap que `player`, así que con un
    /// `content` ya validado por el llamador este guard no puede cortar: no hay
    /// camino que gaste un cofre y se quede sin premio.
    private func presentChestReward(
        _ outcome: ChestOutcome, payoutMinutes: Double, origen: String
    ) {
        guard let content, var player else { return }

        let detalle: String
        var pagado: Double?
        switch outcome {
        case let .skin(id, _, rarity):
            // ⚠️ **A `milestoneSkins`, NUNCA a `ownedSkins`.** StoreKit REESCRIBE
            // `ownedSkins` entera en cada sync (`PlayerState.swift`), así que una
            // pinta de cofre guardada ahí se borraría con un "restaurar compras" — y
            // de paso reabriría el gate del día 7, que lee `allOwnedSkins`.
            player.meta.milestoneSkins = Array(Set(player.meta.milestoneSkins).union([id])).sorted()
            // Sólo acá: con un premio de plata la ficha no tiene nada nuevo que
            // redibujar.
            skinSelectionVersion &+= 1
            detalle = "pinta \(id) (\(rarity.rawValue))"
        case let .coins(rarity):
            // Los mismos minutos de producción que todos los premios de plata
            // del juego (`RewardScale`).
            let monto = Self.coinPayout(minutes: payoutMinutes, player: player, content: content)
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
        chestReward = ChestReward(outcome: outcome, coins: pagado)
        syncCelebrations()
        Log.economy.info("\(origen): \(detalle)")
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

    /// Cuántos cofres esperan. Es la cuenta autoritativa —contra ella cotiza
    /// `openChest()`— y la que muestra la tarjeta de Regalos, que se recompone
    /// con el timer de 1 Hz de su pantalla.
    ///
    /// ⚠️ **No invalida SwiftUI**: sale de `player`, que es
    /// `@ObservationIgnored`. Lo que enciende el puntito de la pestaña es
    /// `hasPendingChests`, la proyección publicada a 8 Hz.
    var pendingChestCount: Int {
        (player?.meta.chestsPending ?? 0) + (player?.meta.prestigeChestsPending ?? 0)
    }
}
