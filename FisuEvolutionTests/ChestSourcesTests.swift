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
