import EconomyKit
import Foundation

/// Mejoras (F5 — las 7 líneas; pasan a ORO en F7.4) y mejoras por personaje.
/// Separado de `GameState.swift` para que el frente del menú de mejoras no
/// comparta archivo con los otros cinco dominios.
extension GameState {
    /// Todo lo que una fila del menú de personajes necesita para dibujarse, ya
    /// resuelto: la UI no vuelve a preguntarle nada al estado. Los textos vienen
    /// armados con el número de ESE personaje (RF-04), no con un nivel abstracto.
    struct CharacterUpgradeRow: Identifiable, Equatable {
        let id: String
        let displayName: String
        let tier: Int
        /// Clave del manifest para la carita (RF-05). Nil → el círculo "T7".
        let faceKey: String?
        /// "×4" — lo que rinde HOY.
        let multiplierText: String
        /// "×8" — lo que rinde si comprás.
        let nextMultiplierText: String
        let upgradeCost: Double
        let canAffordUpgrade: Bool
        let passiveUnlocked: Bool
        let passiveCost: Double
        let canAffordPassive: Bool
        /// "+2,5/s por cada Fisura" — qué hace el pasivo, con el número de ESTE
        /// personaje ya multiplicado por su mejora y por el piso donde vive.
        let passiveEffectText: String
    }

    func upgradeLevel(of lineId: String) -> Int {
        player?.meta.oroUpgradeLevels[lineId] ?? 0
    }

    func upgradeCost(of line: UpgradesConfig.Line) -> Double {
        UpgradeManager.cost(of: line, level: upgradeLevel(of: line.id))
    }

    /// Las filas de la pestaña Personajes, listas para dibujar.
    ///
    /// Es computada y no una proyección publicada a propósito: `UpgradesView` ya
    /// se re-evalúa contra `effectsVersion` y `coinsText`, que son las dos cosas
    /// que mueven una fila. Publicarla obligaría a difundir un array entero 8
    /// veces por segundo para una pantalla que casi nunca está abierta.
    var characterUpgradeRows: [CharacterUpgradeRow] {
        guard let content, let player else { return [] }
        let coins = player.run.coins
        let factor = content.economy.charUpgrades.effectFactorPerLevel
        return characterUpgradeTypes.map { type in
            let level = characterUpgradeLevel(of: type.id)
            let cost = characterUpgradeCost(of: type) ?? .infinity
            return CharacterUpgradeRow(
                id: type.id,
                displayName: type.displayName,
                tier: type.tier,
                faceKey: faceKey(for: type.id),
                multiplierText: multiplierText(pow(factor, Double(level))),
                nextMultiplierText: multiplierText(pow(factor, Double(level + 1))),
                upgradeCost: cost,
                canAffordUpgrade: coins >= cost,
                passiveUnlocked: player.run.passiveUnlocked[type.id] == true,
                passiveCost: type.passiveUnlockCost,
                canAffordPassive: coins >= type.passiveUnlockCost,
                passiveEffectText: passiveEffectText(for: type)
            )
        }
    }

    /// Compra el pasivo DESDE EL MENÚ (RF-04). Delega en la acción canónica y
    /// bumpea `effectsVersion` porque la fila se redibuja contra esa proyección:
    /// sin esto el botón se queda mostrando el precio de algo ya comprado.
    func buyPassiveFromMenu(typeId: String) {
        let wasUnlocked = player?.run.passiveUnlocked[typeId] == true
        unlockPassive(typeId: typeId)
        if !wasUnlocked, player?.run.passiveUnlocked[typeId] == true {
            effectsVersion += 1
        }
    }

    /// La carita del manifest (RF-05) o nil. Sin entrada, la fila cae al círculo
    /// "T7": la UI no espera al arte para poder construirse.
    private func faceKey(for typeId: String) -> String? {
        let key = "\(typeId)_face"
        return content?.manifest.ui[key] != nil ? key : nil
    }

    private func multiplierText(_ value: Double) -> String {
        EffectFormatter.text(EffectAmount(unit: .multiplier, value: value, isCapped: false))
    }

    /// Lo que rinde por segundo UNA instancia de este tipo con el pasivo puesto:
    /// misma fórmula que `IncomeTicker`, sin los multiplicadores globales (que
    /// aplican igual a todos y harían saltar el número con cada boost).
    private func passiveEffectText(for type: CharacterType) -> String {
        guard let content, let player else { return "" }
        let perInstance = type.passiveYieldPerInstance
            * CharUpgrades.multiplier(
                typeId: type.id, levels: player.run.charUpgradeLevels, config: content.economy
            )
            * content.floorTable.floor(forTier: type.tier).incomeMultiplier
        let rate = perInstance > 0 && perInstance < 1
            ? perInstance.formatted(.number.precision(.fractionLength(1)))
            : CoinFormatter.string(from: perInstance)
        return String(localized: "upgrades.character.passive_effect \(rate) \(type.displayName)")
    }

    /// Tipos que el jugador desbloqueó EN ESTA RUN para la pestaña Personajes.
    /// La UI recibe el catálogo filtrado, no inspecciona el save.
    ///
    /// Sale de `run.seenTypes` y no de las unidades vivas (RF-03): mergear tu
    /// último Fisura te borraba de la pantalla la mejora que le habías comprado
    /// y que te seguía rindiendo. El que nunca desbloqueaste sigue sin aparecer,
    /// así que las evoluciones no se espoilean.
    var characterUpgradeTypes: [CharacterType] {
        guard let content, let player else { return [] }
        return content.tiers.concreteTypes
            .filter { player.run.seenTypes.contains($0.id) }
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
