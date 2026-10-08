import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    // MARK: Internals

    /// El piso donde cae la contratación: el visible, salvo que la compuerta lo
    /// haya cerrado y haya que bajar (lo que haga falta, no un piso). `nil` si
    /// desde acá no se contrata en ningún lado (piso visible todavía cerrado).
    /// La llaman `+Actions` (contratar) y `+Debug` (cotizar el regalo de coins).
    func hireTargetOrdinal(player: PlayerState) -> Int? {
        guard let content else { return nil }
        return TowerActions.hireTargetFloor(
            visibleOrdinal: visibleFloorOrdinal,
            unlockedFloors: player.run.unlockedFloors,
            maxTierReached: player.run.maxTierReached,
            floorTable: content.floorTable,
            config: content.economy
        )
    }

    /// La llaman `+Actions` (contratar) y `+Debug`.
    func currentQuote(player: PlayerState, floorOrdinal: Int) -> HireQuote? {
        guard let content else { return nil }
        let prestigeDiscount = content.prestigeUnlocks.cumulativeSpawnDiscount(atPrestigeLevel: player.meta.prestigeLevel)
        return TowerActions.hireQuote(
            floorOrdinal: floorOrdinal,
            state: player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            costMultiplier: 1 - prestigeDiscount,
            now: Date().timeIntervalSince1970
        )
    }

    /// La llaman los seis dominios: cualquier cambio que la escena tenga que
    /// redibujar pasa por acá.
    func bumpBoard() {
        boardVersion += 1
        refreshProjections()
    }

    /// Updates observed properties, writing only on real change so SwiftUI never
    /// invalidates spuriously.
    /// La llaman `+Actions`, `+Upgrades`, `+Bonus` y `+Debug`.
    func refreshProjections() {
        guard let content, let player else { return }

        // Único enganche de la cola de celebraciones: acá pasa todo lo que puede
        // haber creado una. Colgarlo de una sola función es lo que hace que
        // ningún call site pueda olvidarse de encolar (mismo criterio que
        // `evaluateAchievements` con `phase`).
        syncCelebrations()

        refreshEconomyProjections(player: player)
        refreshTowerProjections(content: content, player: player)
        refreshPrestigeProjections(content: content, player: player)
        refreshCollectionProjections(content: content, player: player)
        refreshFTUEProjections(player: player)
        refreshBadgeProjections(content: content, player: player)

        refreshTutorialTip()
    }

    private func refreshEconomyProjections(player: PlayerState) {
        let newCoins = CoinFormatter.string(from: player.run.coins)
        if coinsText != newCoins { coinsText = newCoins }

        let frozenUntil = ModifierMath.spendingFrozenUntil(
            player.run.activeModifiers, now: Date().timeIntervalSince1970
        )
        if spendingFrozenUntil != frozenUntil { spendingFrozenUntil = frozenUntil }

        let target = hireTargetOrdinal(player: player)
        // Sin destino igual cotizamos el piso visible: el botón sigue mostrando
        // qué se vende acá aunque no se pueda comprar todavía.
        let quote = currentQuote(player: player, floorOrdinal: target ?? visibleFloorOrdinal)
        if spawnQuote != quote { spawnQuote = quote }

        let floorUnlocked = visibleFloorDef.map { player.run.unlockedFloors.contains($0.id) } ?? false
        if visibleFloorIsUnlocked != floorUnlocked { visibleFloorIsUnlocked = floorUnlocked }

        let targetFull = target.map { ordinal in
            let occupancy = floorOccupancy(ordinal: ordinal)
            return occupancy.occupied >= max(occupancy.capacity, 1)
        } ?? false
        let affordable = target != nil && !targetFull
            && (quote.map { !$0.blockedBySpendingFreeze && player.run.coins >= $0.cost } ?? false)
        if canAffordSpawn != affordable { canAffordSpawn = affordable }

        let newBestHire = computeBestHire()
        if bestHire != newBestHire { bestHire = newBestHire }

        let total = player.run.totalUnits
        if unitCount != total { unitCount = total }
        if revealedTierMarker != player.run.revealedTier { revealedTierMarker = player.run.revealedTier }
    }

    private func refreshTowerProjections(content: GameContent, player: PlayerState) {
        let navigation = makeTowerNavigation(content: content, player: player)
        if towerNavigation != navigation { towerNavigation = navigation }

        let towerIncome = IncomeTicker.passivePerSecond(
            state: player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            now: Date().timeIntervalSince1970
        )
        if towerIncomePerSecond != towerIncome { towerIncomePerSecond = towerIncome }
        // El formatter de monedas redondea los valores sub-unitarios a 0, pero
        // en una tasa eso escondería income real al comienzo de la partida.
        let incomeText = towerIncome > 0 && towerIncome < 1
            ? towerIncome.formatted(.number.precision(.fractionLength(1)))
            : CoinFormatter.string(from: towerIncome)
        if towerIncomePerSecondText != incomeText { towerIncomePerSecondText = incomeText }
    }

    private func refreshPrestigeProjections(content: GameContent, player: PlayerState) {
        let canReincarnate = economy.map { PrestigeCalculator.canReincarnate(state: player, economy: $0) } ?? false
        if prestigeAvailable != canReincarnate { prestigeAvailable = canReincarnate }

        let teaser = economy.map { eco -> Bool in
            guard let floorId = eco.config.oro.prestigeTeaserFloorId,
                  let ordinal = content.floorTable.floors.firstIndex(where: { $0.id == floorId })
            else { return false }
            return player.run.unlockedFloors.count > ordinal
        } ?? false
        if prestigeTeaser != teaser { prestigeTeaser = teaser }

        let oro = String(player.meta.oro)
        if oroText != oro { oroText = oro }

        refreshPrestigePreview()
    }

    private func refreshCollectionProjections(content: GameContent, player: PlayerState) {
        let skins = Array(player.meta.allOwnedSkins).sorted()
        if ownedSkins != skins { ownedSkins = skins }

        let bonuses = makeActiveBonuses(player: player, content: content)
        if activeBonuses != bonuses { activeBonuses = bonuses }
    }

    private func refreshFTUEProjections(player: PlayerState) {
        let tapHint = !ftueTapped
        if showTapHint != tapHint { showTapHint = tapHint }
        var pairExists = false
        if !ftueMerged && ftueSpawned {
            pairExists = player.run.units.values.contains { $0 >= 2 }
        }
        let mergeHint = ftueSpawned && !ftueMerged && pairExists
        if showMergeHint != mergeHint { showMergeHint = mergeHint }

        let milestones = FTUEMilestones(tapped: ftueTapped, spawned: ftueSpawned, merged: ftueMerged)
        if ftueMilestones != milestones { ftueMilestones = milestones }
    }

    private func refreshBadgeProjections(content: GameContent, player: PlayerState) {
        let affordsUpgrade = computeCanAffordAnyUpgrade(player: player, content: content)
        if canAffordAnyUpgrade != affordsUpgrade { canAffordAnyUpgrade = affordsUpgrade }

        let affordsOro = computeCanAffordAnyOroUpgrade(player: player, content: content)
        if canAffordAnyOroUpgrade != affordsOro { canAffordAnyOroUpgrade = affordsOro }

        let floors = player.run.unlockedFloors.count
        if unlockedFloorsCount != floors { unlockedFloorsCount = floors }

        let claimable = !player.meta.unlockedAchievements
            .subtracting(player.meta.claimedAchievements).isEmpty
        if hasClaimableAchievements != claimable { hasClaimableAchievements = claimable }

        // ⚠️ **`canOpenChest` y no `pendingChestCount > 0`**: desde la regla de
        // desbloqueo (2026-08-28) se puede tener cofres y no poder abrir ninguno,
        // y un puntito que el jugador NO puede apagar se queda prendido un piso
        // entero. Es el mismo punto que usan logros y daily: entrenarlo a que a
        // veces miente los apaga a los tres.
        //
        // El costo extra —armar el conjunto de personajes alcanzables— sólo se
        // paga cuando hay cofres esperando, porque `canOpenChest` cotiza primero
        // contra el contador. Sin cofres, esto sigue siendo la misma comparación
        // de antes.
        let cofres = canOpenChest
        if hasPendingChests != cofres { hasPendingChests = cofres }
    }

    private func makeTowerNavigation(content: GameContent, player: PlayerState) -> TowerNavigation {
        let floors = content.floorTable.floors
        guard floors.indices.contains(visibleFloorOrdinal) else { return .empty }
        let visible = floors[visibleFloorOrdinal]
        let occupancy = visibleFloorOccupancy
        let unlocked = Set(player.run.unlockedFloors)
        let maxUnlocked = floors.enumerated()
            .filter { unlocked.contains($0.element.id) }
            .map(\.offset)
            .max() ?? 0
        let maxVisible = min(maxUnlocked + 1, floors.count - 1)
        return TowerNavigation(
            floorID: visible.id,
            ordinal: visibleFloorOrdinal,
            totalFloors: floors.count,
            occupied: occupancy.occupied,
            capacity: occupancy.capacity,
            canNavigateUp: visibleFloorOrdinal < maxVisible,
            canNavigateDown: visibleFloorOrdinal > 0
        )
    }
}
