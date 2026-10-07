import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    /// Reconstruye la torre desde `run.units` contra el mapeo vigente. Corre en
    /// cada carga: un remapeo tier→piso entre versiones reacomoda la partida en
    /// vez de romperla (spec §3.1). Arranca mirando el piso más alto desbloqueado.
    /// La llaman `+Prestige` (reencarnar) y `+Debug` (resetear el save).
    func reconcileTower() {
        guard let content, var player else { return }
        let before = player.run.units
        let outcome = TowerReconciler.reconcile(
            run: &player.run,
            floorTable: content.floorTable,
            tiers: content.tiers
        )
        self.player = player
        self.tower = outcome.tower
        if outcome.autoMerged > 0 || !outcome.discarded.isEmpty {
            Log.lifecycle.info("tower reconciled: autoMerged \(outcome.autoMerged), discarded \(outcome.discarded)")
            scheduleSave()
        } else if before != player.run.units {
            scheduleSave()
        }
        let unlockedOrdinals = content.floorTable.floors.enumerated()
            .filter { player.run.unlockedFloors.contains($0.element.id) }
            .map(\.offset)
        visibleFloorOrdinal = unlockedOrdinals.max() ?? 0
        updateMaxFloorStat()
    }

    /// Re-sincroniza la torre desde `run.units` SIN mover el piso visible
    /// (para mutaciones fuera de TowerActions, ej. instantEvolution).
    /// La llama `+Bonus`, que es donde vive el evento que muta `run.units`.
    func resyncTower() {
        guard let content, var player else { return }
        let outcome = TowerReconciler.reconcile(
            run: &player.run,
            floorTable: content.floorTable,
            tiers: content.tiers
        )
        self.player = player
        self.tower = outcome.tower
        updateMaxFloorStat()
    }

    /// La llaman `+Actions` (merge y carrera) y `+Bonus` (merge instantáneo y
    /// la unidad regalada por un evento).
    func updateMaxFloorStat() {
        guard let content, var player else { return }
        let maxUnlocked = content.floorTable.floors.enumerated()
            .filter { player.run.unlockedFloors.contains($0.element.id) }
            .map(\.offset).max() ?? 0
        if maxUnlocked > player.meta.stats.maxFloorOrdinalEver {
            player.meta.stats.maxFloorOrdinalEver = maxUnlocked
            self.player = player
        }
        awardEligibleMilestoneSkins()
        // El cofre de la torre se cuelga del mismo embudo por el mismo motivo, y
        // se defiende solo de correr en cada merge con su propio contador.
        awardFloorChestsIfDue()
        // Este método ya es el embudo de merges, ascensos y pisos nuevos: los
        // logros de fusión, tier, piso, skins y specials cuelgan de acá y no de
        // seis call sites que habría que mantener sincronizados.
        evaluateAchievements()
    }

    /// Milestones no dependen de la escena: cualquier unlock/reencarnación que
    /// actualice el estado de torre acredita una vez en MetaState. StoreKit usa
    /// `ownedSkins` aparte y por eso esta unión nunca borra una compra.
    private func awardEligibleMilestoneSkins() {
        guard let content, var player else { return }
        // Las skins de oro no se venden: la única vía es tener las siete líneas
        // de mejora permanente en su tope. El flag se calcula acá, que es donde
        // vive `upgradesConfig`; EconomyKit no conoce `upgrades.json` y pasárselo
        // ya resuelto lo deja puro.
        let lineasDeOro = content.upgradesConfig.upgrades.filter { $0.currency == .oro }
        // `>=` y no `==`, y hay que decir exactamente qué regala.
        //
        // Un save v3 llega acá con los niveles ya reescalados por
        // `SaveMigrator.rescaleUpgradeLevelsForRebalance`. Ese reescalado es
        // PROPORCIONAL Y REDONDEADO, no exacto, y en los dos bordes se nota:
        // redondea PARA ARRIBA hasta el tope (`income`/`tap` 19 → 10 y `crit`
        // 24 → 10 quedan maxeados sin haberlo estado) y redondea A CERO abajo
        // (`crit` 1 → 0 borra el único nivel que el jugador tenía). Los dos
        // casos son de un solo nivel de distancia y se aceptan: la alternativa
        // —guardar el nivel viejo para poder deshacer— pide un bump de schema.
        // Lo que el `>=` sí deja pasar, y es más grande, es un save **v4
        // anterior al rebalance de pacing**: uno con `crit` entre 10 y 24 no
        // había maxeado esa línea —con la curva vieja (3 × 2,5ⁿ) llegar a crit 10 costaba
        // ~19.100 ORO de los 1,776e10 que valía la línea, el 0,0001 %— y desde
        // el rebalance cuenta como tope y se lleva las skins doradas.
        //
        // Ese agujero lo cerró el bump a v5: `SaveMigrator.migrateV4toV5`
        // reconoce esos saves por su huella —algún nivel POR ENCIMA del tope de
        // hoy, imposible en uno post-rebalance— y reescala **sólo las líneas que
        // se pasan del tope**, no el save entero (decisión del dueño,
        // 2026-08-26: normalizar todo le borraba al jugador los niveles que
        // compró DESPUÉS del rebalance). O sea que un save pre-rebalance llega
        // acá con sus otras líneas intactas, y el `>=` de abajo las mira tal
        // como quedaron. Lo que sigue sin cubrir es la línea parada
        // EXACTAMENTE en el tope nuevo: `crit 10/25` (no maxeado) y `crit 10/10`
        // (maxeado) son idénticos en disco. De quince valores por línea quedó
        // uno, y taparlo pediría un campo que los saves viejos no tienen.
        // Lo que NO se regala es el efecto: las dos derivaciones clampean.
        let todoAlMaximo = !lineasDeOro.isEmpty && lineasDeOro.allSatisfy {
            (player.meta.oroUpgradeLevels[$0.id] ?? 0) >= $0.maxLevel
        }
        let newlyUnlocked = SkinMilestones.newlyUnlocked(
            state: player, config: content.skins, allUpgradesMaxed: todoAlMaximo
        )
        guard !newlyUnlocked.isEmpty else { return }
        player.meta.milestoneSkins = Array(Set(player.meta.milestoneSkins).union(newlyUnlocked)).sorted()
        self.player = player
        skinSelectionVersion &+= 1
        Log.economy.info("skin milestones awarded: \(newlyUnlocked)")

        // Se celebra UNA: encadenar popups interrumpe el loop, y el crédito ya
        // quedó hecho para todas. La ficha muestra el resto.
        //
        // Ya no hace falta preguntar si hay una cadena corriendo: se asigna el
        // payload y la cola decide cuándo le toca. `.skinAward` tiene menos
        // prioridad que `.boardCelebration`, así que el ascenso que la otorgó se
        // ve entero antes que el sheet.
        if let first = newlyUnlocked.sorted().first,
           let entry = content.skins.entry(id: first),
           let type = content.tiers.type(id: entry.characterType) {
            skinAward = SkinAward(id: first, characterType: type)
            syncCelebrations()
        }
    }
}
