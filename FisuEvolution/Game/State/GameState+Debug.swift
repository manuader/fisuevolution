import EconomyKit
import Foundation

/// Fixtures de DEBUG: el panel de herramientas del HUD y los launch arguments de
/// los tests de UI. Separado de `GameState.swift` para que ningún frente tenga
/// que abrir el archivo del dominio ajeno sólo para tocar una puerta de test.
extension GameState {
    #if DEBUG
    /// Deja el estado que vive en `UserDefaults` —tutorial y ajustes— DECLARADO
    /// por el test en vez de heredado del simulador.
    ///
    /// ⚠️ Esto es el arreglo de la trampa 9 del HANDOFF. `fisuTutorialDone` y
    /// las tres banderas `ftue.*` viven en `UserDefaults`, que sobrevive a
    /// `--uitest-reset` porque ese fixture sólo rehacía la PARTIDA. El resultado
    /// era que `LaunchSmokeTests` y `EconomyLoopUITests` pasaban únicamente si
    /// antes había corrido el test que abre la ficha (que seteaba
    /// `fisuTutorialDone` de rebote): en un simulador limpio el tutorial les
    /// tapaba los controles. Ahora `--uitest-reset` también resetea el tutorial,
    /// y el que no quiere verlo lo dice con `--uitest-skip-tutorial`.
    ///
    /// ⚠️ **Los ajustes (T16) son exactamente la misma trampa**: partículas,
    /// notificaciones e idioma también viven en `UserDefaults`. Un test que
    /// apaga las partículas dejaba el simulador con el toggle apagado para el
    /// test siguiente, que arrancaría midiendo otra cosa.
    func applyLaunchArgumentDefaults(forceNewGame: Bool) {
        let arguments = ProcessInfo.processInfo.arguments
        let defaults = UserDefaults.standard
        if forceNewGame {
            defaults.set(false, forKey: "fisuTutorialDone")
            defaults.set(false, forKey: "ftue.tapped")
            defaults.set(false, forKey: "ftue.spawned")
            defaults.set(false, forKey: "ftue.merged")
            ftueTapped = false
            ftueSpawned = false
            ftueMerged = false
            defaults.removeObject(forKey: ParticlePool.particlesDefaultsKey)
            defaults.removeObject(forKey: NotificationsManager.defaultsKey)
            defaults.removeObject(forKey: LanguagePreference.defaultsKey)
            defaults.removeObject(forKey: LanguagePreference.systemKey)
            // Las lecciones contextuales son la misma trampa que el tutorial y
            // los ajustes: viven en UserDefaults y sobrevivirían al reset — un
            // test que dispara la lección de Mejoras se la dejaría "dada" al
            // siguiente.
            for lesson in TutorialLesson.allCases {
                defaults.removeObject(forKey: lesson.defaultsKey)
            }
            defaults.removeObject(forKey: Self.sessionsAfterPhaseKey)
        }
        // `--uitest-open-sheet` presenta una hoja modal: el tutorial no puede
        // estar adelante, así que implica saltearlo.
        if arguments.contains("--uitest-skip-tutorial") || arguments.contains("--uitest-open-sheet") {
            defaults.set(true, forKey: "fisuTutorialDone")
        }
        // En una corrida de UI tests las lecciones contextuales arrancan
        // APAGADAS salvo que el test las pida (`--uitest-lessons`): un coach
        // nacido en medio de un test ajeno tapa coordenadas que ese test toca
        // — medido con `AscentRenderingUITests`, cuyo tap a `hud.debug` se lo
        // comió el globo de la lección de Mejoras (nacida por el fixture de
        // monedas). Mismo criterio que el resto de los fixtures: el estado
        // del tutorial lo decide cada test, nunca el azar del gating.
        if arguments.contains(where: { $0.hasPrefix("--uitest") }),
           !arguments.contains("--uitest-lessons") {
            tutorialLessonsAutorun = false
        }
    }

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

    /// Marca como vistos los tipos concretos hasta cierto tier.
    ///
    /// `--uitest-unlock-tower` abre PISOS y no toca `run.seenTypes`, que es de
    /// donde sale la lista de la pestaña Personajes (RF-03): con ese fixture solo
    /// el menú de mejoras se ve siempre con UNA fila. Sin esta puerta no hay forma
    /// de mirar varias tarjetas juntas, que es lo único que deja juzgar el layout.
    func debugMarkTypesSeen(throughTier tier: Int) {
        guard var player, let content else { return }
        for type in content.tiers.concreteTypes where type.tier <= tier {
            player.run.markSeen(type.id)
        }
        self.player = player
    }

    /// Adelanta el ciclo del daily sin esperar días reales.
    ///
    /// Existe por lo mismo que `debugMarkTypesSeen`: la tira del calendario de
    /// `GiftsView` tiene cuatro estados —cobrado, en juego, por venir y el cofre—
    /// y una partida nueva sólo muestra tres, porque el día 1 es el que está en
    /// juego y atrás no hay nada. El único camino a un día con tilde es **volver
    /// mañana**, así que sin esta puerta no hay forma de mirar la tira poblada ni
    /// de juzgar si el tilde se lee. No cobra nada: mueve el contador y ya.
    func debugSetDailyCycleDay(_ day: Int) {
        guard var player, let content else { return }
        player.meta.daily.cycleDay = min(max(day, 1), content.dailyRewards.days.count)
        self.player = player
    }

    /// Deja el premio del día **sin cobrar** y lo cobra de verdad, para que el
    /// popup se abra.
    ///
    /// Retrocede `lastClaimDay` a AYER y no lo borra a propósito: un día
    /// salteado resetea el ciclo a 1 (`DailyRewardManager.claimIfAvailable`),
    /// así que con "ayer" el fixture respeta el `cycleDay` que haya —el de
    /// `--uitest-daily-streak`, si vino— en vez de pisarlo. El claim que corre
    /// después es el REAL: el mismo que acredita la plata al volver a foreground.
    func debugClaimDailyAgain() {
        guard var player else { return }
        player.meta.daily.lastClaimDay = DailyRewardManager.dayString(
            for: Date().addingTimeInterval(-86_400)
        )
        self.player = player
        claimDailyIfAvailable()
    }

    /// Deja tres logros **conseguidos y sin cobrar** para poder fotografiar y
    /// ejercitar la pantalla de Logros.
    ///
    /// Existe por lo mismo que `debugMarkTypesSeen` y `debugSetDailyCycleDay`:
    /// una partida nueva muestra los 39 logros en gris y **ninguno cobrable**,
    /// así que sin esta puerta la sección "Para cobrar" no se puede ver ni
    /// apretar. Conseguir uno jugando pide fusionar, mirar un video con el
    /// proveedor real o dar mil toques sobre un personaje que deambula: nada de
    /// eso es automatizable.
    ///
    /// Los tres contadores están elegidos para cruzar **un** gatillo cada uno
    /// (`ach_merges_1`, `ach_taps_1000`, `ach_videos_1`) y ninguno más. Se usa
    /// `max` para no PISAR un save que ya tuviera más: el fixture agrega, no
    /// retrocede.
    ///
    /// Abre el fork de carrera sin haber llegado a T9.
    ///
    /// Toma las opciones del catálogo —el `choiceOptions` del tier que bifurca—
    /// en vez de nombrarlas acá: la elección de carrera es data-driven, así que
    /// una quinta rama tiene que aparecer sola en el fixture igual que aparece
    /// en el juego.
    ///
    /// Los slots son los dos primeros del piso visible. No importan para lo que
    /// el fixture habilita —mirar la pantalla y elegir— porque `chooseCareer`
    /// resuelve el merge diferido contra lo que haya ahí; si no hay par, la
    /// elección se acredita igual (RF-15: elegiste, cobrás).
    func debugPresentCareerChoice() {
        guard let content else { return }
        guard let fork = content.tiers.types.first(where: { ($0.choiceOptions?.count ?? 0) > 1 }),
              let options = fork.choiceOptions
        else { return }
        let types = options.compactMap { content.tiers.type(id: $0) }
        guard types.count > 1 else { return }
        // El sheet está gateado por `fisuTutorialDone`, y `--uitest-reset` NO lo
        // toca: sin esto el fixture abre el prompt y la vista no lo muestra, que
        // es la forma más confusa de fallar. Mismo criterio que
        // `--uitest-daily-popup`, que también existe para saltear una puerta.
        UserDefaults.standard.set(true, forKey: "fisuTutorialDone")
        let slots = visiblePlacements.map(\.slot).sorted()
        careerPrompt = CareerPrompt(
            options: types,
            sourceCell: slots.first ?? 0,
            targetCell: slots.dropFirst().first ?? 1
        )
        syncCelebrations()
    }

    /// ⚠️ Deja los logros desbloqueados y **sin cobrar** a propósito: cobrarlos
    /// es lo que el test ejerce. Corre en `bootstrap` con `phase == .loading`,
    /// así que `evaluateAchievements` acredita sin desfilar tres banners.
    func debugSeedAchievements() {
        guard var player else { return }
        player.meta.stats.totalMergesEver = max(player.meta.stats.totalMergesEver, 1)
        player.meta.stats.totalTapsEver = max(player.meta.stats.totalTapsEver, 1000)
        player.meta.stats.videosWatchedEver = max(player.meta.stats.videosWatchedEver, 1)
        self.player = player
        evaluateAchievements()
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
