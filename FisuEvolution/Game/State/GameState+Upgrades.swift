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
        /// Clave del manifest para el retrato (RF-05). Nil → el bloque "T7".
        let faceKey: String?
        /// "×4" — lo que rinde HOY.
        let multiplierText: String
        /// En qué mejora va (clampeado al tope: un save tocado no muestra 33/20).
        let upgradeLevel: Int
        /// El tope del config (20: máximo = base × 2^20, o el exponencial
        /// termina en overflow — decisión del dueño, 2026-08-19).
        let upgradeMaxLevel: Int
        /// Al tope: la fila deja de vender el multiplicador e informa.
        let upgradeMaxed: Bool
        let upgradeCost: Double
        let canAffordUpgrade: Bool
        let passiveUnlocked: Bool
        let passiveCost: Double
        let canAffordPassive: Bool
        /// "+2,5/s cada uno" — qué rinde el pasivo, con el número de ESTE
        /// personaje ya multiplicado por su mejora y por el piso donde vive.
        let passiveEffectText: String
    }

    /// Nivel comprado de una línea, CLAMPEADO al tope vigente del catálogo.
    ///
    /// Un save anterior al rebalance de pacing trae `income: 20` contra un tope
    /// que hoy es 10; sin el clamp la fila diría "20/10" y el precio del
    /// "próximo nivel" saldría de una potencia que no existe. Es la misma regla
    /// que `CharUpgrades.multiplier` y que las dos derivaciones de efectos.
    func upgradeLevel(of lineId: String) -> Int {
        let stored = player?.meta.oroUpgradeLevels[lineId] ?? 0
        guard let line = content?.upgradesConfig.upgrades.first(where: { $0.id == lineId }) else { return stored }
        return min(stored, line.maxLevel)
    }

    func upgradeCost(of line: UpgradesConfig.Line) -> Double {
        UpgradeManager.cost(of: line, level: upgradeLevel(of: line.id))
    }

    /// Qué hace una mejora permanente, en números que salen del JSON (RF-06):
    /// "+30% → +40%". Al calcularse desde el config no se puede desincronizar de
    /// un cambio de balance, y la traducción la hace la pieza única
    /// `EffectDescriptor` que comparten mejoras, boosts y prestigio.
    func upgradeEffectText(for line: UpgradesConfig.Line) -> String {
        let level = upgradeLevel(of: line.id)
        let current = EffectDescriptor.amount(
            for: line.effectType, level: level, magnitudePerLevel: line.magnitudePerLevel
        )
        let next = level >= line.maxLevel
            ? nil
            : EffectDescriptor.amount(
                for: line.effectType, level: level + 1, magnitudePerLevel: line.magnitudePerLevel
            )
        let progression = EffectFormatter.progression(current: current, next: next)
        guard current.isCapped || next?.isCapped == true else { return progression }
        return "\(progression) (\(EffectFormatter.cappedNote))"
    }

    /// El chiste de la mejora, la segunda línea de la fila (RF-06).
    ///
    /// La búsqueda vive acá y no en la vista porque `LocalizedStringKey` es
    /// `ExpressibleByStringInterpolation`: `LocalizedStringKey("upgrades.flavor.\(id)")`
    /// NO busca la clave armada, arma la clave `upgrades.flavor.%@` y, al no
    /// encontrarla, imprime el formato con el id sustituido —o sea, la clave
    /// cruda en pantalla (trampa 5 del HANDOFF, tercera vez)—. Con la clave en
    /// una `String` aparte, `String(localized:)` hace el lookup de verdad, y el
    /// test la ejerce por el mismo camino que la vista.
    func upgradeFlavorText(for line: UpgradesConfig.Line) -> String {
        let key = "upgrades.flavor.\(line.id)"
        return String(localized: String.LocalizationValue(key))
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
        let maxLevel = content.economy.charUpgrades.maxLevel
        return characterUpgradeTypes.map { type in
            let level = min(characterUpgradeLevel(of: type.id), maxLevel)
            // `nil` = al tope: no hay próximo nivel que cotizar.
            let cost = characterUpgradeCost(of: type)
            return CharacterUpgradeRow(
                id: type.id,
                displayName: type.displayName,
                tier: type.tier,
                faceKey: faceKey(for: type.id),
                multiplierText: multiplierText(pow(factor, Double(level))),
                upgradeLevel: level,
                upgradeMaxLevel: maxLevel,
                upgradeMaxed: cost == nil,
                upgradeCost: cost ?? .infinity,
                canAffordUpgrade: cost.map { coins >= $0 } ?? false,
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

    /// Qué rinde HOY este personaje y en qué mejora va: "Plata ×8 · Nivel
    /// 3 / 20". El contador es el pedido del dueño (2026-08-19): con tope de
    /// 20, la fila tiene que decir cuánto camino queda — la misma clave
    /// `upgrades.level` que ya usan las barras de las permanentes, para que
    /// las dos pestañas cuenten los niveles con las mismas palabras.
    ///
    /// ⚠️ Los dos `Int` van por `String(_:)` ANTES de entrar en la clave
    /// (trampa 5: interpolarlos armaría `upgrades.level %lld %lld`, que no
    /// existe en el catálogo).
    func characterIncomeText(for row: CharacterUpgradeRow) -> String {
        let income = String(localized: "upgrades.character.income_now \(row.multiplierText)")
        let level = String(localized: "upgrades.level \(String(row.upgradeLevel)) \(String(row.upgradeMaxLevel))")
        return "\(income) · \(level)"
    }

    /// Lo que rinde por segundo UNA instancia de este tipo con el pasivo puesto:
    /// misma fórmula que `IncomeTicker`, sin los multiplicadores globales (que
    /// aplican igual a todos y harían saltar el número con cada boost).
    ///
    /// Dejó de ser `private` porque FisuJobs muestra el mismo número en su
    /// tarjeta (`JobRow.incomeText`, §5.1: "produce X /s"). Es la MISMA fórmula
    /// y el MISMO texto, así que se comparte en vez de copiarse: dos copias de
    /// una fórmula de economía es lo que ya hizo que el simulador cotizara
    /// distinto que el juego (`balance-log`).
    func passiveEffectText(for type: CharacterType) -> String {
        guard let content, let player else { return "" }
        let perInstance = type.passiveYieldPerInstance
            * CharUpgrades.multiplier(
                typeId: type.id, levels: player.run.charUpgradeLevels, config: content.economy
            )
            * content.floorTable.floor(forTier: type.tier).incomeMultiplier
        let rate = perInstance > 0 && perInstance < 1
            ? perInstance.formatted(.number.precision(.fractionLength(1)))
            : CoinFormatter.string(from: perInstance)
        // Sin el nombre del personaje: ya está escrito arriba, en la card.
        return String(localized: "upgrades.character.passive_now \(rate)")
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
        // Del más NUEVO al más viejo (decisión del dueño, 2026-08-17). La lista
        // sólo crece: con veinte tipos desbloqueados, el que acabás de conseguir
        // —el único cuya mejora todavía podés pagar— quedaba al fondo, detrás de
        // veinte filas que ya no vas a tocar. La pantalla abre en lo último que
        // hiciste. Pineado por `rowsAreOrderedNewestFirst`.
        return content.tiers.concreteTypes
            .filter { player.run.seenTypes.contains($0.id) }
            .sorted { $0.tier > $1.tier }
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
