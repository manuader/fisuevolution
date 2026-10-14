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
    /// ⚠️ Esto es el arreglo de la trampa 9 del HANDOFF. `tutorial.v2.completed` y
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
            TutorialFlags.wipeGameFlags(in: defaults)
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
            wipeTutorialLessonProgress()
            defaults.removeObject(forKey: Self.economyKnobsDefaultsKey)
        }
        // `--uitest-open-sheet` presenta una hoja modal: el tutorial no puede
        // estar adelante, así que implica saltearlo.
        if arguments.contains("--uitest-skip-tutorial") || arguments.contains("--uitest-open-sheet") {
            TutorialFlags.setCoreCompleted(true, in: defaults)
            TutorialFlags.markCurrent(in: defaults)
        }
        // `--uitest-veteran`: el veterano de la v1 recién actualizado —núcleo hecho, las lecciones
        // que la v1 ya enseñaba dadas y el Tour pendiente—. Va después del reset.
        let veteran = arguments.contains("--uitest-veteran")
        if veteran {
            TutorialFlags.setCoreCompleted(true, in: defaults)
            TutorialFlags.setTourPending(true, in: defaults)
            for id in TutorialLesson.veteranKnownLessons { TutorialFlags.markLessonDone(id, in: defaults) }
            TutorialFlags.markCurrent(in: defaults)
        }
        // `--uitest-lessons-done=<id>,<id>`: esas lecciones quedan dadas, para que el
        // test de una lección no dependa de las que el orden pone antes.
        if let done = arguments.first(where: { $0.hasPrefix("--uitest-lessons-done=") }) {
            for id in done.dropFirst("--uitest-lessons-done=".count).split(separator: ",") {
                TutorialFlags.markLessonDone(String(id), in: defaults)
            }
        }
        // `--uitest-tutorial-at-finish`: el núcleo retoma en su cierre (los tres
        // milestones hechos, como quien cerró la app ahí). Sin "Saltar", es la
        // forma de llegar al cofre de bienvenida sin jugar el guion entero.
        if arguments.contains("--uitest-tutorial-at-finish") {
            for key in TutorialFlags.milestoneKeys { defaults.set(true, forKey: key) }
            ftueTapped = true
            ftueSpawned = true
            ftueMerged = true
        }
        // En una corrida de UI tests las lecciones contextuales arrancan
        // APAGADAS salvo que el test las pida (`--uitest-lessons`): un coach
        // nacido en medio de un test ajeno tapa coordenadas que ese test toca
        // — medido con `AscentRenderingUITests`, cuyo tap a `hud.debug` se lo
        // comió el globo de la lección de Mejoras (nacida por el fixture de
        // monedas). Mismo criterio que el resto de los fixtures: el estado
        // del tutorial lo decide cada test, nunca el azar del gating.
        // `--uitest-lesson=<id>` fuerza una lección mientras no esté dada: gana
        // sobre el orden y saltea su señal de gating y `needsCalmBoard`. Implica
        // `--uitest-lessons`.
        let forcedLesson = arguments.first { $0.hasPrefix("--uitest-lesson=") }
            .map { String($0.dropFirst("--uitest-lesson=".count)) }
        if let forcedLesson, TutorialLesson(rawValue: forcedLesson) == nil {
            Log.lifecycle.error("--uitest-lesson: no hay lección \(forcedLesson, privacy: .public)")
        }
        tutorialEngine.forcedLesson = forcedLesson
        if arguments.contains(where: { $0.hasPrefix("--uitest") }),
           !arguments.contains("--uitest-lessons"), forcedLesson == nil, !veteran {
            tutorialLessonsAutorun = false
        }
        // `--uitest-tutorial-lock=<s>` cambia los 5 s del candado (fixtures de UI).
        if let lock = arguments.first(where: { $0.hasPrefix("--uitest-tutorial-lock=") })
            .flatMap({ TimeInterval($0.dropFirst("--uitest-tutorial-lock=".count)) }) {
            tutorialEngine.lockSeconds = lock
        }
        // Los motores de engagement, lo mismo: nada nace solo bajo `--uitest*`
        // salvo que el test lo pida (`--uitest-engagement`).
        if arguments.contains(where: { $0.hasPrefix("--uitest") }), !arguments.contains("--uitest-engagement") {
            engagementAutorun = false
        }
        // Las cinemáticas, lo mismo: bajo `--uitest*` no corren salvo que el test
        // las pida (`--uitest-cinematics` o `--uitest-cinematic=<id>`).
        if arguments.contains(where: { $0.hasPrefix("--uitest") }) {
            cinematicsAutorun = arguments.contains("--uitest-cinematics")
                || arguments.contains(where: { $0.hasPrefix("--uitest-cinematic=") })
        }
        // La barra progresiva es nueva de la 2.0: bajo `--uitest*` arranca
        // entera salvo que el test la pida, porque los tests de la v1 tocan las
        // seis pestañas (`testCadaTabAbreSuPantallaYSeCierra`, sin cambios).
        if arguments.contains(where: { $0.hasPrefix("--uitest") }),
           !arguments.contains("--uitest-progressive-tabs") {
            progressiveTabsEnabled = false
        }
        // Compartir es nuevo de la 2.0: bajo `--uitest*` no se ofrece nada salvo
        // que el test lo pida, o el botón aparecería encima de cualquier test.
        if arguments.contains(where: { $0.hasPrefix("--uitest") }),
           !arguments.contains("--uitest-share") {
            shareOffersEnabled = false
        }
        // Las perillas que el dueño dejó puestas en el panel (PLAN-v2 E2a).
        let knobs = Self.storedEconomyKnobs(in: defaults)
        if knobs != EconomyKnobs() {
            debugApplyEconomyKnobs(knobs, defaults: defaults)
        }
    }

    /// Las perillas de E2a que el dueño eligió en el panel. Viven en
    /// `UserDefaults` y no en el save: son de este dispositivo, no de la partida.
    static let economyKnobsDefaultsKey = "debug.economyKnobs"

    static func storedEconomyKnobs(in defaults: UserDefaults) -> EconomyKnobs {
        defaults.data(forKey: economyKnobsDefaultsKey)
            .flatMap { try? JSONDecoder().decode(EconomyKnobs.self, from: $0) } ?? EconomyKnobs()
    }

    /// Aplica las perillas sobre el `economy.json` del BUNDLE (no sobre el que
    /// está puesto: si no, apagar una no volvería a la v1) y las guarda.
    func debugApplyEconomyKnobs(_ knobs: EconomyKnobs, defaults: UserDefaults) {
        guard let bundled = try? GameContentLoader.load(from: .main).economy,
              let tuned = try? bundled.tuned(knobs)
        else { return }
        defaults.set(try? JSONEncoder().encode(knobs), forKey: Self.economyKnobsDefaultsKey)
        replaceEconomy(tuned)
    }

    @discardableResult
    func debugMergeAllOnVisibleFloor() -> Int {
        enqueueMergeAll(onFloor: visibleFloorOrdinal, origin: .debug)
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

    /// La pinta de cofre de un personaje que el jugador NUNCA vio.
    ///
    /// Es el premio que el sorteo reparte casi siempre —el Fisura no tiene pinta
    /// de cofre, así que el primer cofre de una partida nueva ya premia a un
    /// desconocido— y es justo el que ningún otro fixture arma: `--uitest-skins`
    /// reparte entre los VISTOS, que es el único estado donde Pintas y Mejoras
    /// listan lo mismo y por lo tanto el único donde el bug no se ve.
    ///
    /// Elige el de tier más ALTO sin ver, que es el borde: el más lejos que una
    /// run puede quedar de su propia colección. Acredita por la misma vía que el
    /// cofre real (`meta.milestoneSkins`) y sin celebración: lo que hace falta
    /// mirar es el carrusel, no la animación.
    func debugGrantUnseenChestSkin() {
        guard let content, let player else { return }
        let masAlta = content.skins.chestPool
            .filter { !player.run.seenTypes.contains($0.characterType) }
            .max { izquierda, derecha in
                (content.tiers.type(id: izquierda.characterType)?.tier ?? 0)
                    < (content.tiers.type(id: derecha.characterType)?.tier ?? 0)
            }
        guard let masAlta else { return }
        grantMilestoneSkinsForTests([masAlta.id])
    }

    /// El blue de reencarnar sale de `meta.lifetimeEarnings`, que es monótono y no
    /// se puede acumular en un test sin jugar la partida entera. Esta puerta la
    /// mueve directo para poder ejercitar el prestigio (RF-16).
    func giveLifetimeEarningsForTesting(_ amount: Double) {
        guard var player else { return }
        player.meta.lifetimeEarnings += amount
        self.player = player
        refreshProjections()
    }

    /// Empuja `lifetimeEarnings` hasta que reencarnar rinda al menos `blue` blue.
    ///
    /// Los tests piden blue y no monedas A PROPÓSITO: cuántas monedas hacen falta
    /// sale de `blue.divisor` y `blue.exponent`, que son knobs de balance. Un
    /// literal calibrado contra el divisor de ayer deja de significar lo mismo
    /// mañana — el rebalance de pacing lo movió de 3e6 a 3e12 (pasó por 3e11 en
    /// la ronda anterior) y dejó en rojo nueve tests que creían estar pidiendo
    /// "suficiente para reencarnar".
    ///
    /// El margen es por el `floor()` de `blueTotal`: sin él, el error de punto
    /// flotante puede dejar el resultado un blue por debajo del pedido.
    func giveEarningsForPrestigeTesting(blue: Int = 1) {
        guard let content, let player else { return }
        let curve = content.economy.blue
        let target = Double(player.meta.blueEarnedLifetime + max(1, blue))
        let needed = curve.divisor * pow(target, 1 / curve.exponent) * 1.000_001
        giveLifetimeEarningsForTesting(max(0, needed - player.meta.lifetimeEarnings))
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

    /// El callejón con `homeless` Homeless y "Fusionar todo" encolado: la cadena
    /// entera, con tres tiers nuevos, sin salir del piso. Devuelve los eslabones.
    @discardableResult
    func debugSeedMergeAll(homeless count: Int) -> Int {
        guard var player, var tower else { return 0 }
        let present = tower.placements(onFloor: 0).filter { $0.typeId == "homeless" }.count
        for _ in present..<max(present, count) {
            guard let slot = tower.floors[0].firstFreeSlot() else { break }
            tower.floors[0].slots[slot] = "homeless"
            player.run.units["homeless", default: 0] += 1
        }
        player.run.markSeen("homeless")
        self.player = player
        self.tower = tower
        bumpBoard()
        setVisibleFloor(0)
        return enqueueMergeAll(onFloor: 0, origin: .debug)
    }

    /// Un par planeado como lo planearía un video, para ver el embudo entero.
    func debugPlanBoardChange() {
        debugGrantPair()
        guard let content, let player, let tower,
              let change = BoardChangePlanner.planAutoMerge(
                  state: player, tower: tower, tiers: content.tiers,
                  floorTable: content.floorTable, origin: .debug
              )
        else { return }
        enqueueBoardChange(change)
    }

    /// Salta la escalera para playtesting (ej. probar la elección de carrera en T9).
    /// Sólo sube: la frontera tiene un único mutador (`raiseFrontier`) y ése no
    /// baja, así que pedir un tier por debajo del actual no hace nada.
    func debugSetMaxTier(_ tier: Int) {
        guard var player, let content else { return }
        player.run.raiseFrontier(to: min(max(1, tier), content.tiers.maxTier))
        player.run.revealedTier = player.run.maxTierReached
        self.player = player
        refreshProjections()
    }

    /// Fixture de UI test: desbloquea pisos por la tabla data-driven, sin tocar
    /// el binario Release ni depender de un save preexistente en el simulador.
    ///
    /// ⚠️ **Sube también la frontera**, porque un piso abierto sin frontera es
    /// un estado que el juego no produce: los pisos se abren creando el tier que
    /// los estrena, así que llegar al piso del tier T implica `maxTierReached ==
    /// T`. Antes daba igual —la compuerta de contratación se medía en pisos—,
    /// y desde que se mide en tiers un fixture que abriera pisos sin frontera
    /// dejaría la torre abierta y **nada contratable salvo el Fisura**, que no
    /// es lo que ningún test que lo usa quiere decir.
    /// El tier se recorta a Dios: más arriba no hay frontera posible, y la escalada
    /// por bandas la recorre tier por tier (con `.max` colgaba el arranque).
    func debugUnlockFloors(throughTier requestedTier: Int) {
        guard var player, let content else { return }
        let tier = min(max(1, requestedTier), content.tiers.maxTier)
        let highestOrdinal = content.floorTable.ordinal(forTier: tier)
        player.run.unlockedFloors = content.floorTable.floors.prefix(highestOrdinal + 1).map(\.id)
        player.run.raiseFrontier(to: tier)
        player.run.revealedTier = player.run.maxTierReached
        self.player = player
        visibleFloorOrdinal = 0
        refreshProjections()
    }

    /// Una partida rankeada ya registrada (con un `runId` de mentira) y la frontera a un tier del tope.
    func debugStartRankedRunNearGod(now: TimeInterval = Date().timeIntervalSince1970) {
        guard let godTier else { return }
        updateRanking {
            $0.phase = .running(runId: "simulated-run", serverStartedAt: now - 3_600)
            $0.playedSeconds = 1_800
        }
        debugUnlockFloors(throughTier: godTier - 1)
    }

    /// El especial abierto sobre el piso visible y la sonda de fps corriendo: los videos del estrés
    /// los pone el manifest de `--uitest-anim-stress`.
    func debugStartAnimStress() {
        debugDropFirstSpecial()
        FrameRateProbe.shared.start()
    }

    /// Llega a Dios como si se hubiera revelado el tier tope.
    func debugReachGod() {
        guard let godTier, var player else { return }
        player.run.raiseFrontier(to: godTier)
        self.player = player
        markRevealed(tier: godTier)
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
        // El sheet está gateado por `tutorial.v2.completed`, y `--uitest-reset` la
        // deja en false (`wipeGameFlags`): sin esto el fixture abre el prompt y la vista no lo muestra, que
        // es la forma más confusa de fallar. Mismo criterio que
        // `--uitest-daily-popup`, que también existe para saltear una puerta.
        TutorialFlags.setCoreCompleted(true)
        let slots = visiblePlacements.map(\.slot).sorted()
        careerPrompt = CareerPrompt(
            options: types,
            floorOrdinal: visibleFloorOrdinal,
            sourceCell: slots.first ?? 0,
            targetCell: slots.dropFirst().first ?? 1
        )
        syncCelebrations()
    }

    /// Alguien en escena ya mismo, sin guion: para mirar la entrada, el globo y la
    /// salida en el simulador.
    func debugPresentStageDemo() {
        presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
    }

    /// Un visitante en escena ya mismo, con su guion real y salteando el sorteo
    /// (no el tope ni el tier: eso lo decide el que lo llama). Los visitantes
    /// vienen cada 4–6 min de juego: sin esta puerta no se pueden ni fotografiar
    /// ni probar.
    func debugPresentVisitor(scriptId: String) {
        guard let script = content?.visitors.script(id: scriptId) else { return }
        debugClearStage()
        presentVisitor(script)
    }

    /// Saca a quien esté en escena, sin despedida (es una puerta de debug, no una
    /// regla del juego). Si estaba entrando, su turno de la cola se cierra.
    func debugClearStage() {
        guard stageVisit != nil else { return }
        stageVisit = nil
        visitorPopup = nil
        stageChallenge = nil
        celebrationFinished(.visitorEncounter)
    }

    /// Un evento arrancado ya mismo, con su efecto real. Los eventos salen cada
    /// 15–20 min de juego: sin esta puerta no se pueden ni fotografiar ni probar.
    func debugStartEvent(id: String) {
        guard let event = content?.events.event(id: id) else { return }
        startEvent(event, now: Date().timeIntervalSince1970)
    }

    /// Un evento con su presentador, ya mismo: lo que ve el jugador. Si hay alguien
    /// en escena, el evento espera a que se vaya, como en el juego.
    func debugPresentEvent(id: String) {
        guard let event = content?.events.event(id: id) else { return }
        presentEvent(event)
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

    /// Presenta el popup de ganancias offline con un monto dado, SIN pasar por
    /// el cálculo.
    ///
    /// Existe porque `debugSimulateOffline(hours:)` —que sí es el camino real—
    /// **no sirve para mirar la hoja**: el offline paga en proporción a la
    /// producción pasiva, y una partida nueva produce 0/s, así que acredita cero
    /// y el popup no aparece. Armar producción de verdad pide contratar,
    /// desbloquear el pasivo por tipo y esperar; para fotografiar o ejercitar
    /// la hoja —y su oferta de duplicar por video— eso es todo ruido.
    ///
    /// Mismo criterio que `debugDropFirstSpecial()`: cuando el camino real
    /// depende del azar o de una partida avanzada, el fixture entrega el estado
    /// final y el test mide la PANTALLA.
    func debugPresentOfflineReward(amount: Double) {
        offlineRewardDoubled = false
        offlineReward = OfflineReward(amount: amount)
        syncCelebrations()
    }

    func debugSimulateOffline(hours: Double) {
        guard var player else { return }
        player.meta.lastSeenTimestamp -= hours * 3600
        self.player = player
        applyOfflineProgressIfNeeded()
        refreshProjections()
    }

    /// El primer especial del catálogo, caído ya mismo: deja la carta del drop
    /// abierta (vía la cola, como el drop real) y al especial en el Álbum.
    func debugDropFirstSpecial() {
        guard let content, var player,
              let special = content.specials.specials.first else { return }
        if !player.meta.ownedSpecials.contains(special.id) {
            player.meta.ownedSpecials.append(special.id)
        }
        self.player = player
        specialDrop = special
        refreshProjections()
        bumpBoard()
    }

    /// Pide la cinemática sin mirar si le toca: el dueño las quiere ver cuantas veces
    /// haga falta. Igual se anotan al cerrar.
    func debugPlayCinematic(_ id: CinematicID) {
        cinematic = id
        syncCelebrations()
    }

    /// Un cofre regalado y abierto en el acto, para poder mirar la animación.
    ///
    /// Existe por lo mismo que `debugDropFirstSpecial`: la vía real es cada dos
    /// pisos desbloqueados —o un video, o el día 7—, o sea media hora de partida
    /// por cofre. La animación es lo que más garpa del sistema y sin esta puerta
    /// no se puede ni ejercitar ni fotografiar.
    ///
    /// Regala y abre en la misma llamada: `openChest` gasta uno de los
    /// pendientes, así que sin el `awardChest` de arriba no haría nada en una
    /// partida sin cofres guardados.
    ///
    /// ⚠️ **Y sube un piso si hace falta**, que no es capricho de la puerta: con
    /// la regla de desbloqueo (2026-08-28) un cofre no se abre si el jugador ya
    /// tiene las pintas de todos los personajes a los que llegó, y en una partida
    /// nueva eso pasa al CUARTO toque —el primer piso reparte tres—. Sin esto,
    /// el botón que existe para poder mirar la animación cuantas veces haga falta
    /// se moriría justo a la tercera.
    ///
    /// Sube el progreso en vez de saltear el filtro **a propósito**: saltearlo
    /// acreditaría una pinta que el save no puede tener, y una puerta de debug
    /// que fabrica estados imposibles es una fábrica de bugs fantasma. Esto hace
    /// lo que haría el jugador —subir— y deja la partida coherente.
    func debugOpenChest() {
        // ⚠️ El `awardChest()` va PRIMERO, y no es estilo: `canOpenChest` cotiza
        // contra el contador de pendientes, así que preguntarle antes de sumar el
        // cofre devuelve `false` SIEMPRE — y el piso simulado se subiría en cada
        // llamada, la necesite o no. Se cazó cuando la puerta empezó a mover el
        // progreso de partidas que no lo pedían.
        awardChest()
        if !canOpenChest, var player, let content {
            let tope = content.floorTable.floors.count - 1
            if player.meta.stats.maxFloorOrdinalEver < tope {
                player.meta.stats.maxFloorOrdinalEver += 1
                self.player = player
                Log.economy.info("debug: piso simulado \(player.meta.stats.maxFloorOrdinalEver) para destrabar el cofre")
            }
        }
        openChest()
    }

    /// Un cofre regalado y **sin abrir**: el que hace falta para recorrer el
    /// camino del jugador —el puntito de la pestaña, la tarjeta de Regalos, el
    /// botón— en vez de aterrizar directo en la animación.
    ///
    /// Publica en el acto, como las otras puertas: la proyección del puntito se
    /// refresca a 8 Hz contra el frame counter de la escena, y este botón vive
    /// adentro de una hoja que la tapa.
    func debugAwardChest() {
        awardChest()
        refreshProjections()
    }

    /// "Resetear partida" del panel = el reset real (`+Reset`) sin sus tres pasos: una
    /// instalación fresca DE VERDAD, no sólo un save nuevo (pedido del dueño, 2026-08-21) —
    /// el tutorial, las lecciones y el puntito viven en `UserDefaults`—, que desde la 2.0
    /// conserva lo comprado, `seenCinematics` y la época igual que el de Ajustes (la intro no se
    /// repite). Síncrono: los tests de las épicas lo
    /// leen en la línea de abajo. Para un borrado total, `--uitest-reset`.
    func debugResetSave() {
        guard let plan = resetPlan(), let player else { return }
        debugTimeScale = 1
        _ = repository?.keepBeforeReset(player)
        applyReset(plan)
        Task { await persistNow() }
    }
    #endif
}
