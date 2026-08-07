import EconomyKit
import Foundation

/// Fixtures de DEBUG: el panel de herramientas del HUD y los launch arguments de
/// los tests de UI. Separado de `GameState.swift` para que ningún frente tenga
/// que abrir el archivo del dominio ajeno sólo para tocar una puerta de test.
extension GameState {
    #if DEBUG
    /// Acredita skins de milestone sin recorrer su condición. Desde que se
    /// retiraron los tintes IAP, los milestones son la única fuente de skins,
    /// así que los tests que ejercitan equipar necesitan esta puerta.
    func grantMilestoneSkinsForTests(_ ids: [String]) {
        guard var player else { return }
        player.meta.milestoneSkins = Array(Set(player.meta.milestoneSkins).union(ids)).sorted()
        self.player = player
        skinSelectionVersion &+= 1
    }

    /// El ORO de reencarnar sale de `meta.lifetimeEarnings`, que es monótono y no
    /// se puede acumular en un test sin jugar la partida entera. Esta puerta la
    /// mueve directo para poder ejercitar el prestigio (RF-16).
    func giveLifetimeEarningsForTesting(_ amount: Double) {
        guard var player else { return }
        player.meta.lifetimeEarnings += amount
        self.player = player
        refreshProjections()
    }

    func debugGrantCoins() {
        guard var player else { return }
        let quoted = currentQuote(player: player, floorOrdinal: hireTargetOrdinal(player: player) ?? visibleFloorOrdinal)
        let grant = max(1_000_000, (quoted?.cost ?? 0) * 100)
        player.run.coins += grant
        player.meta.lifetimeEarnings += grant
        self.player = player
        refreshProjections()
    }

    /// Coloca un par del tier máximo alcanzado para poder testear la escalera.
    func debugGrantPair() {
        guard let content, var player, var tower else { return }
        let tier = player.run.maxTierReached
        guard let type = content.tiers.concreteTypes.first(where: { candidate in
            candidate.tier == tier && (player.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        }) ?? content.tiers.concreteTypes.first(where: { $0.tier == tier }) else { return }

        let ordinal = content.floorTable.ordinal(forTier: type.tier)
        guard let slotA = tower.floors[ordinal].firstFreeSlot() else { return }
        tower.floors[ordinal].slots[slotA] = type.id
        guard let slotB = tower.floors[ordinal].firstFreeSlot() else {
            tower.floors[ordinal].slots[slotA] = nil
            return
        }
        tower.floors[ordinal].slots[slotB] = type.id
        player.run.units[type.id, default: 0] += 2
        player.run.markSeen(type.id)
        if !player.run.unlockedFloors.contains(content.floorTable[ordinal].id) {
            player.run.unlockedFloors.append(content.floorTable[ordinal].id)
        }
        self.player = player
        self.tower = tower
        bumpBoard()
    }

    /// Salta la escalera para playtesting (ej. probar la elección de carrera en T9).
    func debugSetMaxTier(_ tier: Int) {
        guard var player, let content else { return }
        player.run.maxTierReached = min(max(1, tier), content.tiers.maxTier)
        self.player = player
        refreshProjections()
    }

    /// Fixture de UI test: desbloquea pisos por la tabla data-driven, sin tocar
    /// el binario Release ni depender de un save preexistente en el simulador.
    func debugUnlockFloors(throughTier tier: Int) {
        guard var player, let content else { return }
        let highestOrdinal = content.floorTable.ordinal(forTier: tier)
        player.run.unlockedFloors = content.floorTable.floors.prefix(highestOrdinal + 1).map(\.id)
        self.player = player
        visibleFloorOrdinal = 0
        refreshProjections()
    }

    func debugSimulateOffline(hours: Double) {
        guard var player else { return }
        player.meta.lastSeenTimestamp -= hours * 3600
        self.player = player
        applyOfflineProgressIfNeeded()
        refreshProjections()
    }

    func debugResetSave() {
        guard let content else { return }
        player = PlayerState.newGame(
            startTypeId: content.tiers.baseType.id,
            startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: Date().timeIntervalSince1970
        )
        debugTimeScale = 1
        reconcileTower()
        bumpBoard()
        Task { await persistNow() }
    }
    #endif
}
