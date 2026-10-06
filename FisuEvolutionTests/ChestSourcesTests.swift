import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// De dónde salen los cofres de pintas. Las cuatro fuentes del spec: la torre
/// cada dos pisos, el video con cooldown, el día 7 del calendario (ese vive en
/// `ContentSystemsTests`, con el resto del daily) y la reencarnación.
///
/// Los casos negativos son el corazón de la suite y no decoración: los dos bugs
/// que este sistema puede tener son "paga de más" —el contador de la torre
/// cuelga de `updateMaxFloorStat()`, que corre en CADA merge— y "le pisa el
/// premio a otro".
@Suite("Las fuentes del cofre de pintas")
@MainActor
struct ChestSourcesTests {
    @Test("la torre da un cofre cada dos pisos, y no lo repite al re-desbloquear el mismo")
    func towerGivesOneChestEveryTwoFloors() async {
        let state = await makeGameState()
        let pisos = state.content!.floorTable.floors.map(\.id)

        // Piso 1: todavía nada (1 / 2 == 0).
        state.player!.run.unlockedFloors = Array(pisos.prefix(1))
        state.awardFloorChestsIfDue()
        #expect(state.pendingChestCount == 0)

        // Piso 2: el primer cofre.
        state.player!.run.unlockedFloors = Array(pisos.prefix(2))
        state.awardFloorChestsIfDue()
        #expect(state.pendingChestCount == 1)

        // El caso que importa: llamar de nuevo con los MISMOS pisos no puede
        // pagar otra vez. Sin el contador esto regalaría un cofre por fusión.
        state.awardFloorChestsIfDue()
        state.awardFloorChestsIfDue()
        #expect(state.pendingChestCount == 1)

        // La torre entera: 10 pisos / 2 == 5.
        state.player!.run.unlockedFloors = pisos
        state.awardFloorChestsIfDue()
        #expect(state.pendingChestCount == 5)
    }

    /// El contador cuelga del embudo, no de un call site suelto. Sin esta línea
    /// el sistema compila, la fuente de la torre queda muerta y los tests que
    /// llaman al método a mano siguen verdes.
    @Test("el cofre de la torre llega por el embudo que corre en cada merge")
    func towerChestArrivesThroughTheMergeFunnel() async {
        let state = await makeGameState()
        state.player!.run.unlockedFloors = Array(state.content!.floorTable.floors.map(\.id).prefix(2))
        state.updateMaxFloorStat()
        #expect(state.pendingChestCount == 1)

        // Y el segundo merge —el embudo corre en cada uno— no regala otro.
        state.updateMaxFloorStat()
        #expect(state.pendingChestCount == 1)
    }

    @Test("reencarnar reinicia el contador de la torre pero conserva los cofres sin abrir")
    func prestigeResetsTheCounterAndKeepsPendingChests() async throws {
        let state = await makeGameState()
        state.player!.run.unlockedFloors = state.content!.floorTable.floors.map(\.id)
        state.awardFloorChestsIfDue()
        #expect(state.pendingChestCount == 5)

        state.giveEarningsForPrestigeTesting(oro: 3)
        state.confirmPrestige()
        let player = try #require(state.player)

        // Los 5 de la partida anterior siguen ahí (viven en `meta`), más el de la
        // reencarnación, que es el que garantiza épica.
        #expect(player.run.floorChestsAwarded == 0)
        #expect(player.meta.chestsPending == 5)
        #expect(player.meta.prestigeChestsPending == 1)

        // Y volver a subir vuelve a pagar los cinco.
        state.player!.run.unlockedFloors = state.content!.floorTable.floors.map(\.id)
        state.awardFloorChestsIfDue()
        #expect(state.player!.meta.chestsPending == 10)
    }

    @Test("el video paga un cofre y recién vuelve a ofrecerse pasado el cooldown")
    func rewardedVideoGrantsAChestOncePerCooldown() async throws {
        let state = await makeGameState()
        // El id sale del catálogo, no de un literal: lo que se pinea es que
        // `rewarded_ads.json` tiene una fila que paga cofre.
        let reward = try #require(
            state.content?.rewardedAds.rewards.first { $0.effectType == .skinChest },
            "el quinto video del catálogo es el que paga el cofre"
        )
        let ahora = 10_000.0
        state.applyRewardedReward(rewardId: reward.id, now: ahora)
        #expect(state.pendingChestCount == 1)

        // En cooldown no paga: el video es la fuente con freno y sin él se
        // vacía la colección en una tarde.
        state.applyRewardedReward(rewardId: reward.id, now: ahora + reward.cooldownSeconds - 1)
        #expect(state.pendingChestCount == 1)

        state.applyRewardedReward(rewardId: reward.id, now: ahora + reward.cooldownSeconds)
        #expect(state.pendingChestCount == 2)
    }
}

/// Abrir un cofre: gastar uno de los pendientes, sortear y dejar el premio listo
/// para que la cola lo muestre.
///
/// El caso que manda la suite es `chestSkinsSurviveAStoreKitSync`. StoreKit
/// REESCRIBE `ownedSkins` entera en cada sync, así que una pinta de cofre
/// guardada ahí se borraría con un "restaurar compras" —el jugador perdería la
/// colección— y de paso reabriría el gate del día 7, que lee `allOwnedSkins`.
@Suite("Abrir un cofre")
@MainActor
struct ChestOpeningTests {
    /// Los dos resultados del sorteo llevan rareza: la plata también, porque la
    /// animación pinta su color antes de saber qué salió.
    private func rareza(de outcome: ChestOutcome) -> SkinsConfig.Rarity {
        switch outcome {
        case let .skin(_, _, rarity): rarity
        case let .coins(rarity): rarity
        }
    }

    /// ⚠️ **El progreso se siembra, y no es decoración del fixture.** Desde la
    /// regla de desbloqueo (2026-08-28) el mínimo de épica sólo se puede cumplir
    /// si el jugador LLEGÓ a algún personaje épico: si el desbloqueo y el mínimo
    /// chocan, el que cede es el mínimo. Sin sembrar, este test mediría a alguien
    /// parado en el callejón cobrando un cofre de reencarnación — que no es una
    /// partida posible, y encima pediría lo único que la regla nueva prohíbe.
    @Test("abrir gasta primero el de prestigio, y ése garantiza épica o mejor")
    func openingSpendsThePrestigeChestFirst() async throws {
        let state = await makeGameState()
        state.player?.meta.stats.maxFloorOrdinalEver = todaLaTorre(state)
        state.awardChest()                     // uno normal
        state.awardChest(minRarity: .epica)    // y el de la reencarnación
        #expect(state.pendingChestCount == 2)

        state.openChest()

        #expect(state.player?.meta.prestigeChestsPending == 0, "el de prestigio se gasta primero")
        #expect(state.player?.meta.chestsPending == 1, "el normal sigue esperando su turno")
        let premio = try #require(state.chestReward?.outcome)
        #expect(rareza(de: premio) >= .epica)

        // Una sola tirada no pinea el mínimo: con los pesos que se shippean, una
        // épica o mejor sale sola el 17 % de las veces, así que un mínimo roto
        // pasaría cinco de cada seis corridas. Doce seguidas es una en 2e9.
        for _ in 0..<12 {
            state.chestReward = nil
            state.awardChest(minRarity: .epica)
            state.openChest()
            let otro = try #require(state.chestReward?.outcome)
            #expect(rareza(de: otro) >= .epica,
                    "el cofre de la reencarnación no puede pagar por debajo de épica")
        }
    }

    @Test("la pinta del cofre va a milestoneSkins y sobrevive un sync de StoreKit")
    func chestSkinsSurviveAStoreKitSync() async throws {
        let state = await makeGameState()
        state.awardChest()
        let versionAntes = state.skinSelectionVersion
        state.openChest()

        #expect(state.skinSelectionVersion != versionAntes, "la ficha tiene una pinta nueva que mostrar")
        guard case let .skin(pinta, _, _) = try #require(state.chestReward?.outcome) else {
            Issue.record("con la bolsa entera sin tocar, el cofre da pinta y no plata")
            return
        }
        #expect(state.player?.meta.milestoneSkins.contains(pinta) == true)
        #expect(state.player?.meta.ownedSkins.contains(pinta) == false,
                "`ownedSkins` es el cache de la tienda: nada que no se haya comprado vive ahí")

        // El "restaurar compras". La lista NO puede venir vacía: con el jugador
        // en cero, el guard de `applyStoreEntitlements` cortaría antes de
        // escribir y el sync quedaría sin probarse.
        let deLaTienda = try #require(
            state.content?.skins.skins.first { $0.chestRarity == nil }?.id,
            "el catálogo tiene skins fuera de la bolsa del cofre"
        )
        state.applyStoreEntitlements(removedAds: false, ownedSkins: [deLaTienda])

        #expect(state.player?.meta.milestoneSkins.contains(pinta) == true,
                "un restaurar compras se llevó la pinta que había pagado el cofre")
        #expect(state.player?.meta.allOwnedSkins.contains(pinta) == true)
    }

    @Test("dos toques seguidos abren UN cofre, no dos")
    func openingTwiceInARowSpendsOnlyOne() async throws {
        let state = await makeGameState()
        state.awardChest()
        state.awardChest()

        state.openChest()
        let primero = try #require(state.chestReward)
        state.openChest()

        #expect(state.pendingChestCount == 1, "el segundo toque no gastó nada")
        #expect(state.chestReward?.id == primero.id,
                "y el premio del primero sigue en pantalla, sin pisarse")
    }

    @Test("sin cofres pendientes no pasa nada")
    func openingWithNothingPendingIsANoop() async throws {
        let state = await makeGameState()
        #expect(state.pendingChestCount == 0)

        state.openChest()

        #expect(state.chestReward == nil, "sin cofre no hay premio que mostrar")
        #expect(state.showing == nil, "ni turno que pedir en la cola")
        #expect(state.player?.meta.milestoneSkins.isEmpty == true, "ni pinta que acreditar")
        #expect(state.player?.meta.chestsPending == 0, "y el contador no queda en −1")
        #expect(state.player?.meta.prestigeChestsPending == 0)
    }

    /// La otra mitad de `openChest`, que con el catálogo sin tocar no se ejecuta
    /// nunca: agotada la bolsa, el cofre paga plata. El monto sale de la MISMA
    /// fórmula que el fallback del día 7, que es lo que hace que los dos premios
    /// de plata del juego se sientan del mismo tamaño.
    @Test("con la bolsa agotada el cofre paga plata, y el de prestigio paga el doble")
    func anEmptyPoolPaysCoins() async throws {
        let state = await makeGameState()
        let content = try #require(state.content)
        let economy = try #require(state.economy)
        state.player?.meta.milestoneSkins = content.skins.chestPool.map(\.id).sorted()
        let base = economy.passiveUnlockCost(forTier: state.player!.run.maxTierReached)

        let antesDelNormal = state.player!.run.coins
        let lifetimeAntes = state.player!.meta.lifetimeEarnings
        let versionAntes = state.skinSelectionVersion
        state.awardChest()
        state.openChest()

        #expect(state.skinSelectionVersion == versionAntes,
                "un premio de plata no cambia la colección: redibujar la ficha es al pedo")
        guard case .coins = try #require(state.chestReward?.outcome) else {
            Issue.record("sin pinta que dar, el cofre tiene que pagar plata")
            return
        }
        let pagoNormal = base * content.chests.completedPayoutFactor
        #expect(state.player!.run.coins == antesDelNormal + pagoNormal)
        #expect(state.player!.meta.lifetimeEarnings == lifetimeAntes + pagoNormal,
                "la plata del cofre cuenta para el ORO, como cualquier ingreso")

        state.chestReward = nil
        let antesDelDePrestigio = state.player!.run.coins
        state.awardChest(minRarity: .epica)
        state.openChest()
        #expect(
            state.player!.run.coins == antesDelDePrestigio + base * content.chests.prestigePayoutFactor,
            "el de la reencarnación paga el doble"
        )
    }

    // MARK: - La regla del dueño: sólo personajes desbloqueados (2026-08-28)

    /// El ordinal del último piso de la torre. Se calcula del contenido y no se
    /// escribe a mano: hardcodear un 8 acá lo deja mintiendo el día que la torre
    /// crezca, y el test seguiría verde midiendo otra cosa.
    private func todaLaTorre(_ state: GameState) -> Int {
        (state.content?.floorTable.floors.count ?? 1) - 1
    }

    /// **El cofre que no se puede abrir no se gasta.**
    ///
    /// Es la mitad de la regla que EconomyKit no puede probar: el sorteo sabe
    /// devolver "todavía no", pero que el contador NO baje es del llamador. Roto,
    /// el jugador ve bajar sus cofres sin recibir nada — que es peor que el bug
    /// que la regla vino a arreglar.
    @Test("con nada alcanzable, abrir no gasta el cofre ni muestra premio")
    func openingWithNothingReachableKeepsTheChest() async throws {
        let state = await makeGameState()
        // Parado en el primer piso, y ya con las pintas de todos los personajes
        // que ese piso alcanza: no queda nada que un cofre pueda darle.
        state.player?.meta.stats.maxFloorOrdinalEver = 0
        let alcanzables = state.chestUnlockedCharacterTypes
        state.player?.meta.milestoneSkins = (state.content?.skins.chestPool ?? [])
            .filter { alcanzables.contains($0.characterType) }
            .map(\.id).sorted()
        #expect(state.player?.meta.milestoneSkins.isEmpty == false,
                "el fixture tiene que dejarlo con algo ganado, o el test no mide nada")
        state.awardChest()

        state.openChest()

        #expect(state.pendingChestCount == 1, "el cofre se guarda: no se gasta ni se pierde")
        #expect(state.chestReward == nil, "y no hay premio que mostrar")
        #expect(state.showing == nil, "ni turno que pedirle a la cola")
        #expect(state.canOpenChest == false, "y la tarjeta de Regalos tiene que decirlo")
    }

    @Test("con nada alcanzable, el cofre no ofrece un video por otro")
    func theExtraChestOfferNeedsSomethingReachable() async throws {
        let state = await makeGameState()
        state.player?.meta.stats.maxFloorOrdinalEver = 0
        let alcanzables = state.chestUnlockedCharacterTypes
        state.player?.meta.milestoneSkins = (state.content?.skins.chestPool ?? [])
            .filter { alcanzables.contains($0.characterType) }
            .map(\.id).sorted()

        #expect(state.canOfferExtraChest == false)
    }

    @Test("con algo alcanzable el video se ofrece, y una sola vez por cofre")
    func theExtraChestOfferIsOncePerChest() async throws {
        let state = await makeGameState()
        state.player?.meta.stats.maxFloorOrdinalEver = todaLaTorre(state)
        #expect(state.canOfferExtraChest)

        state.grantExtraChestFromAd()

        #expect(state.chestReward != nil, "el cofre del video se abre en el acto")
        #expect(state.canOfferExtraChest == false, "y no ofrece otro")
    }

    /// Y en cuanto sube un piso, el MISMO cofre se abre. Es la otra mitad: sin
    /// esto, un `openChest()` que nunca gastara nada pasaría el test de arriba.
    @Test("subir un piso destraba el cofre que estaba esperando")
    func climbingAFloorUnlocksTheWaitingChest() async throws {
        let state = await makeGameState()
        state.player?.meta.stats.maxFloorOrdinalEver = 0
        let delPrimerPiso = state.chestUnlockedCharacterTypes
        state.player?.meta.milestoneSkins = (state.content?.skins.chestPool ?? [])
            .filter { delPrimerPiso.contains($0.characterType) }
            .map(\.id).sorted()
        state.awardChest()
        state.openChest()
        #expect(state.pendingChestCount == 1, "precondición: el cofre quedó esperando")

        state.player?.meta.stats.maxFloorOrdinalEver = todaLaTorre(state)

        #expect(state.canOpenChest, "con la torre abierta hay pintas que darle")
        state.openChest()
        #expect(state.pendingChestCount == 0, "ahora sí se gasta")
        let premio = try #require(state.chestReward?.outcome)
        guard case let .skin(_, characterType, _) = premio else {
            Issue.record("con la bolsa a medio llenar tenía que salir pinta")
            return
        }
        #expect(!delPrimerPiso.contains(characterType),
                "las del primer piso ya las tenía: la que salió es de lo que acaba de abrir")
    }

    /// La regla, contra el catálogo REAL y no contra un fixture sintético: con la
    /// cuenta parada en el primer piso, mil cofres no pueden traer jamás a nadie
    /// de más arriba. Es el caso que el dueño nombró —la pinta de la Deidad
    /// estando en el Oficinista— medido sobre `skins.json`.
    @Test("mil cofres desde el primer piso nunca traen a un personaje de más arriba")
    func aThousandChestsNeverReachAboveYourProgress() async throws {
        let state = await makeGameState()
        state.player?.meta.stats.maxFloorOrdinalEver = 0
        let alcanzables = state.chestUnlockedCharacterTypes

        for n in 0..<1000 {
            state.chestReward = nil
            state.awardChest()
            state.openChest()
            guard let premio = state.chestReward?.outcome else { break }
            if case let .skin(id, characterType, _) = premio {
                #expect(alcanzables.contains(characterType),
                        "cofre \(n) repartió \(id), de \(characterType), que la cuenta no desbloqueó")
            }
        }
    }
}

/// Lo que la pantalla de Regalos necesita para ofrecer el cofre: la señal
/// **publicada** del puntito y las tres copys de la tarjeta.
///
/// ⚠️ La señal existe aparte de `pendingChestCount` porque `player` es
/// `@ObservationIgnored`: la cuenta se computa al leerse y **no invalida
/// SwiftUI**, así que la barra de abajo —que no tiene timer ni nada más que la
/// haga recomponerse— se quedaría sin puntito hasta que otra cosa la despertara.
/// Es el mismo trato que `hasClaimableAchievements`, y por eso vive al lado.
@Suite("El puntito de Regalos")
@MainActor
struct PendingChestBadgeTests {
    @Test("la señal del puntito sigue a los dos contadores, y se apaga al abrir el último")
    func theBadgeSignalFollowsBothCounters() async {
        let state = await makeGameState()
        #expect(state.hasPendingChests == false, "una partida nueva no tiene nada que cobrar")

        state.awardChest()
        state.flushHUD()
        #expect(state.hasPendingChests, "un cofre de la torre tiene que encender el puntito")

        state.openChest()
        state.flushHUD()
        #expect(state.hasPendingChests == false, "gastado el último, el puntito se apaga")
    }

    /// El de prestigio es el OTRO contador: un puntito que sólo mirara
    /// `chestsPending` dejaría invisible al cofre de la reencarnación, que es
    /// justo el que garantiza épica.
    @Test("el cofre de la reencarnación también enciende el puntito")
    func thePrestigeCounterAlsoLightsTheBadge() async {
        let state = await makeGameState()

        state.awardChest(minRarity: .epica)
        state.flushHUD()

        #expect(state.player?.meta.chestsPending == 0)
        #expect(state.hasPendingChests, "el contador de prestigio cuenta igual")
    }

    /// **Un puntito que no se puede apagar es peor que ninguno.**
    ///
    /// Desde la regla de desbloqueo (2026-08-28) se puede tener cofres y no poder
    /// abrir ninguno. Si el puntito siguiera al contador a secas, se quedaría
    /// prendido un piso entero sin que el jugador tenga forma de bajarlo — y es
    /// el mismo puntito que usan logros y daily, así que se lo entrena a mentir a
    /// los tres.
    @Test("con cofres que todavía no se pueden abrir, el puntito NO se enciende")
    func theBadgeStaysOffWhileNothingIsReachable() async {
        let state = await makeGameState()
        state.player?.meta.stats.maxFloorOrdinalEver = 0
        let alcanzables = state.chestUnlockedCharacterTypes
        state.player?.meta.milestoneSkins = (state.content?.skins.chestPool ?? [])
            .filter { alcanzables.contains($0.characterType) }
            .map(\.id).sorted()

        state.awardChest()
        state.flushHUD()

        #expect(state.pendingChestCount == 1, "el cofre está: lo que no está es qué darle")
        #expect(state.hasPendingChests == false, "y el puntito no puede prometer lo que no se puede cobrar")

        // Y al subir, se enciende solo: es la otra mitad, sin la cual un puntito
        // clavado en `false` pasaría el `#expect` de arriba.
        state.player?.meta.stats.maxFloorOrdinalEver = (state.content?.floorTable.floors.count ?? 1) - 1
        state.flushHUD()
        #expect(state.hasPendingChests, "con la torre abierta el cofre ya tiene qué darle")
    }

    @Test("la tarjeta del cofre no muestra ninguna clave cruda")
    func theChestCardCopyIsResolved() {
        let seccion = String(localized: "gifts.section.chests")
        let boton = String(localized: "gifts.chest.open")
        let bloqueado = String(localized: "gifts.chest.locked")
        let cuenta = String(localized: "gifts.chest.count \(3)")

        #expect(!bloqueado.contains("gifts."), "el badge dejó una clave cruda: '\(bloqueado)'")

        #expect(!seccion.contains("gifts."), "la cinta dejó una clave cruda: '\(seccion)'")
        #expect(!boton.contains("gifts."), "el botón dejó una clave cruda: '\(boton)'")
        #expect(!cuenta.contains("gifts."), "el contador dejó una clave cruda: '\(cuenta)'")
        #expect(cuenta.contains("3"), "y el contador tiene que decir cuántos son: '\(cuenta)'")
    }
}

/// El **cofre de bienvenida**: el único cofre guionado del juego. Cae al cerrar
/// la fase obligatoria del tutorial —tap → contratar → fusionar— y se abre solo,
/// porque la cola lo promueve apenas esa restricción se levanta.
///
/// Los dos casos que mandan la suite son los mismos que los de `openChest()` más
/// uno propio:
/// 1. la pinta va a `milestoneSkins` —un "restaurar compras" borraría
///    `ownedSkins` entera—,
/// 2. cerrar la animación destraba la cola,
/// 3. y el premio **no sale del sorteo**: sale de `chests.json`.
@Suite("El cofre de bienvenida")
@MainActor
struct WelcomeChestTests {
    /// Una partida nueva con la fase obligatoria viva: el único estado desde el
    /// que el cofre puede caer. Bajo XCTest el bootstrap no arranca la fase
    /// (cada test arma su escenario), así que se pide explícita.
    private func stateInTutorial() async -> GameState {
        let state = await makeGameState()
        state.beginTutorialPhase()
        return state
    }

    private func skinID(of state: GameState) -> String? {
        guard case let .skin(id, _, _) = state.chestReward?.outcome else { return nil }
        return id
    }

    @Test("cerrar la fase obligatoria hace caer el cofre, y la cola lo abre sola")
    func theWelcomeChestFallsWhenTheMandatoryPhaseEnds() async throws {
        let state = await stateInTutorial()
        #expect(state.chestReward == nil, "durante la fase no cae ningún cofre")

        state.tutorialPhaseFinished()

        let esperado = try #require(state.content?.chests.welcomeSkinId)
        #expect(skinID(of: state) == esperado, "el premio es la pinta que nombra `chests.json`")
        #expect(state.showing == .chestOpening,
                "se abre solo: nadie tuvo que ir a Regalos a tocar el botón")
        #expect(state.celebrationHidesUI, "y apaga el HUD, como cualquier cofre")
        #expect(state.player?.meta.welcomeChestGiven == true)
        #expect(state.pendingChestCount == 0,
                "no pasa por el contador: es una escena, no plata que se guarda")
    }

    /// El discriminador entre "sale del config" y "sale de una tirada".
    ///
    /// ⚠️ El fixture es imposible en una partida real —las 41 pintas salen sólo
    /// de cofres y éste es el primero—, y es a propósito: `ChestRoller` **nunca**
    /// devuelve una pinta que el jugador ya tiene (filtra por stock), así que con
    /// la de bienvenida ya acreditada un premio que SIGA siendo la de bienvenida
    /// sólo puede venir del config. La alternativa —abrir doce cofres y mirar si
    /// alguno se desvía— es estadística: una tirada acierta `welcomeSkinId` el
    /// 8 % de las veces, y un test así pasaría rotas cinco de cada seis corridas.
    @Test("el premio es fijo: sale del config aunque el sorteo no pudiera darlo")
    func theWelcomePrizeComesFromTheConfigAndNotFromARoll() async throws {
        let state = await stateInTutorial()
        let esperado = try #require(state.content?.chests.welcomeSkinId)
        state.player?.meta.milestoneSkins = [esperado]

        state.tutorialPhaseFinished()

        #expect(skinID(of: state) == esperado,
                "una tirada habría tenido que dar cualquier OTRA pinta: ésta ya estaba en la bolsa del jugador")
    }

    /// ⚠️ **A `milestoneSkins`, NUNCA a `ownedSkins`.** StoreKit reescribe
    /// `ownedSkins` entera en cada sync: una pinta guardada ahí se borraría con
    /// un "restaurar compras".
    @Test("la pinta de bienvenida va a milestoneSkins y sobrevive un sync de StoreKit")
    func theWelcomeSkinSurvivesAStoreKitSync() async throws {
        let state = await stateInTutorial()
        let versionAntes = state.skinSelectionVersion

        state.tutorialPhaseFinished()

        let pinta = try #require(state.content?.chests.welcomeSkinId)
        #expect(state.player?.meta.milestoneSkins.contains(pinta) == true)
        #expect(state.player?.meta.ownedSkins.contains(pinta) == false,
                "`ownedSkins` es el cache de la tienda: nada que no se haya comprado vive ahí")
        #expect(state.skinSelectionVersion != versionAntes,
                "la ficha tiene una pinta nueva que mostrar")

        let deLaTienda = try #require(
            state.content?.skins.skins.first { $0.chestRarity == nil }?.id,
            "el catálogo tiene skins fuera de la bolsa del cofre"
        )
        state.applyStoreEntitlements(removedAds: false, ownedSkins: [deLaTienda])

        #expect(state.player?.meta.milestoneSkins.contains(pinta) == true,
                "un restaurar compras se llevó la pinta del cofre de bienvenida")
        #expect(state.player?.meta.allOwnedSkins.contains(pinta) == true)
    }

    /// La bandera es por save y no por sesión: el panel de debug puede revivir
    /// la fase, y un jugador que la reviva no cobra dos veces.
    @Test("un save paga un solo cofre de bienvenida")
    func theWelcomeChestIsGrantedOnlyOncePerSave() async throws {
        let state = await stateInTutorial()
        state.tutorialPhaseFinished()
        #expect(state.chestReward != nil)
        state.dismissChestReward()

        state.beginTutorialPhase()
        state.tutorialPhaseFinished()

        #expect(state.chestReward == nil, "el segundo cierre no puede pagar otro cofre")
        #expect(state.showing == nil)
        #expect(state.pendingChestCount == 0)
    }

    /// El contrato que roto deja el juego mudo: `.chestOpening` no tiene timeout
    /// ni es salteable, así que si el payload sobrevive a su turno la cola queda
    /// congelada con el HUD apagado y sin watchdog que la destrabe.
    @Test("cerrar el cofre de bienvenida destraba la cola")
    func closingTheWelcomeChestReleasesTheQueue() async throws {
        let state = await stateInTutorial()
        state.tutorialPhaseFinished()
        #expect(state.showing == .chestOpening)

        state.dismissChestReward()

        #expect(state.chestReward == nil)
        #expect(state.showing != .chestOpening, "la cola quedó trabada en el cofre")
        #expect(state.celebrationHidesUI == false, "y el HUD tiene que volver")
    }

    /// El cofre entra a la cola como uno más y **detrás** de lo que ya estaba
    /// esperando a que la fase terminara: si se otorgara ANTES de levantar la
    /// restricción, su prioridad (4) le pasaría por encima al aviso de torre (6)
    /// que el jugador se ganó primero. El "de a una" y el orden salen del
    /// árbitro que ya existe, no de un segundo tutorial paralelo.
    @Test("el cofre se suma al final de la fila, no la saltea")
    func theWelcomeChestQueuesBehindWhatWasAlreadyWaiting() async throws {
        let state = await stateInTutorial()
        state.towerNotice = GameState.TowerNotice(kind: .floorFull)
        state.syncCelebrations()
        #expect(state.showing == nil, "la fase lo tiene esperando")

        state.tutorialPhaseFinished()
        #expect(state.showing == .towerNotice, "lo que esperó su turno desfila primero")

        state.celebrationFinished(.towerNotice)
        #expect(state.showing == .chestOpening, "y el cofre atrás, sin perderse")
    }
}
