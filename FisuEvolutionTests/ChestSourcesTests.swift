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

    @Test("abrir gasta primero el de prestigio, y ése garantiza épica o mejor")
    func openingSpendsThePrestigeChestFirst() async throws {
        let state = await makeGameState()
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
        state.openChest()

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
        state.awardChest()
        state.openChest()

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
}
