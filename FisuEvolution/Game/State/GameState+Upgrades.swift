import EconomyKit
import Foundation

/// Mejoras (F5 — las 7 líneas; pasan a ORO en F7.4) y mejoras por personaje.
/// Separado de `GameState.swift` para que el frente del menú de mejoras no
/// comparta archivo con los otros cinco dominios.
extension GameState {
    func upgradeLevel(of lineId: String) -> Int {
        player?.meta.oroUpgradeLevels[lineId] ?? 0
    }

    func upgradeCost(of line: UpgradesConfig.Line) -> Double {
        UpgradeManager.cost(of: line, level: upgradeLevel(of: line.id))
    }

    /// Tipos que el jugador conoce en esta vida (o ya mejoró) para la pestaña
    /// Personajes. La UI recibe el catálogo filtrado, no inspecciona el save.
    var characterUpgradeTypes: [CharacterType] {
        guard let content, let player else { return [] }
        return content.tiers.concreteTypes
            .filter { (player.run.units[$0.id] ?? 0) > 0 || (player.run.charUpgradeLevels[$0.id] ?? 0) > 0 }
            .sorted { $0.tier < $1.tier }
    }

    func characterUpgradeLevel(of typeID: String) -> Int {
        player?.run.charUpgradeLevels[typeID] ?? 0
    }

    func characterUpgradeCost(of type: CharacterType) -> Double? {
        guard let economy, let player, let content else { return nil }
        return CharUpgrades.nextLevelCost(type: type, levels: player.run.charUpgradeLevels, config: content.economy, economy: economy)
    }

    func buyCharacterUpgrade(typeID: String) {
        guard let economy, let content, var player,
              let type = content.tiers.type(id: typeID)
        else { return }
        do {
            try CharUpgrades.purchase(type: type, state: &player, config: content.economy, economy: economy)
            self.player = player
            haptics?.play(.purchase)
            effectsVersion += 1
            refreshProjections()
            scheduleSave()
        } catch {
            haptics?.play(.error)
            audio?.play(.error)
            Log.economy.info("character upgrade rejected: \(error)")
        }
    }

    func buyUpgrade(lineId: String) {
        guard let economy, let content, var player = player else { return }
        do {
            try UpgradeManager.purchase(
                lineId: lineId,
                state: &player,
                config: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                economy: economy
            )
            self.player = player
            haptics?.play(.purchase)
            effectsVersion += 1
            refreshProjections()
            scheduleSave()
        } catch {
            haptics?.play(.error)
            audio?.play(.error)
            Log.economy.info("upgrade rejected: \(error)")
        }
    }
}
