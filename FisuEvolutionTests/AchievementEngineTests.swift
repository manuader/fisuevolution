import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El motor de logros (spec §10.3): catálogo data-driven, desbloqueo por
/// trigger, cobro de la recompensa y la proyección que dibuja la pantalla.
///
/// ⚠️ **Los estados se arman mutando `player` directo.** Cruzar un trigger
/// jugando —10.000 fusiones, 8 reencarnaciones, las 45 pintas— no es
/// automatizable, y lo que este suite prueba es el MOTOR, no el camino que
/// llena el contador (eso ya lo pinean `StatsCountersAppTests` y compañía).
@Suite("Motor de logros")
@MainActor
struct AchievementEngineTests {
    // MARK: Catálogo

    @Test("el catálogo real trae los 39 logros con ids únicos y claves derivadas")
    func realCatalogLoads() throws {
        let content = try GameContentLoader.load(from: .main)
        let achievements = content.achievements.achievements
        #expect(content.achievements.schemaVersion == 1)
        #expect(achievements.count == 39)
        #expect(Set(achievements.map(\.id)).count == 39)
        for achievement in achievements {
            // La convención del spec: `ach_merges_100` → `ach.merges_100.title`.
            let suffix = String(achievement.id.dropFirst("ach_".count))
            #expect(achievement.titleKey == "ach.\(suffix).title")
            #expect(achievement.descKey == "ach.\(suffix).desc")
            #expect(!achievement.icon.isEmpty)
            #expect(achievement.trigger.kind != nil, "trigger desconocido en \(achievement.id)")
            #expect(achievement.reward.rewardKind != nil, "reward desconocida en \(achievement.id)")
        }
    }

    /// Los 15 trigger types del catálogo tienen que estar TODOS ejercidos abajo:
    /// un type nuevo sin su caso en el switch se desbloquearía nunca o siempre,
    /// y las dos formas son silenciosas.
    @Test("el suite cubre todos los trigger types del catálogo real")
    func everyTriggerTypeIsCovered() throws {
        let content = try GameContentLoader.load(from: .main)
        let used = Set(content.achievements.achievements.compactMap { $0.trigger.kind })
        #expect(used == Set(AchievementsConfig.TriggerKind.allCases))
    }

    // MARK: Un estado por trigger type

    @Test("floorUnlocked se cruza al abrir el piso")
    func floorUnlockedTrigger() async {
        let state = await makeState { $0.run.unlockedFloors.append("urban") }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_floor_urban"))
        #expect(!state.isUnlocked("ach_floor_corporate"))
    }

    /// El piso alcanzado ALGUNA VEZ también cuenta: reencarnar re-bloquea
    /// `run.unlockedFloors`, y un logro conseguido no se devuelve.
    @Test("floorUnlocked también se cruza por el máximo histórico")
    func floorUnlockedByHistoricMax() async {
        let state = await makeState { $0.meta.stats.maxFloorOrdinalEver = 2 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_floor_urban"))
        #expect(state.isUnlocked("ach_floor_corporate"))
        #expect(!state.isUnlocked("ach_floor_luxury"))
    }

    @Test("tierReached se cruza con el tier máximo de la run")
    func tierReachedTrigger() async {
        let state = await makeState { $0.run.maxTierReached = 24 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_tier_11"))
        #expect(state.isUnlocked("ach_tier_24"))
        #expect(!state.isUnlocked("ach_tier_37"))
    }

    @Test("totalMerges se cruza con el contador de cuenta")
    func totalMergesTrigger() async {
        let state = await makeState { $0.meta.stats.totalMergesEver = 100 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_merges_1"))
        #expect(state.isUnlocked("ach_merges_100"))
        #expect(!state.isUnlocked("ach_merges_1000"))
    }

    @Test("totalHires se cruza con el contador de cuenta")
    func totalHiresTrigger() async {
        let state = await makeState { $0.meta.stats.totalHiresEver = 10 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_hires_10"))
        #expect(!state.isUnlocked("ach_hires_100"))
    }

    @Test("totalTaps se cruza con el contador de cuenta")
    func totalTapsTrigger() async {
        let state = await makeState { $0.meta.stats.totalTapsEver = 1000 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_taps_1000"))
        #expect(!state.isUnlocked("ach_taps_100000"))
    }

    @Test("prestigeLevel se cruza con las reencarnaciones")
    func prestigeLevelTrigger() async {
        let state = await makeState { $0.meta.prestigeLevel = 3 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_prestige_1"))
        #expect(state.isUnlocked("ach_prestige_3"))
        #expect(!state.isUnlocked("ach_prestige_8"))
    }

    /// Las dos fuentes de skins cuentan juntas (`allOwnedSkins`): las de IAP y
    /// las de milestone. Contar sólo una dejaría el logro inalcanzable para
    /// quien no compra.
    @Test("skinsOwned suma las skins de IAP y las de milestone")
    func skinsOwnedTrigger() async {
        let state = await makeState {
            $0.meta.ownedSkins = ["a", "b", "c"]
            $0.meta.milestoneSkins = ["d", "e"]
        }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_skins_5"))
        #expect(!state.isUnlocked("ach_skins_20"))
        #expect(!state.isUnlocked("ach_skins_all"))
    }

    /// `skinsAll` NO lleva `value`: el objetivo es el tamaño del catálogo. Así,
    /// sumar la skin 46 mueve el logro sin tocar el JSON.
    @Test("skinsAll se mide contra el catálogo entero, no contra un número escrito")
    func skinsAllTrigger() async throws {
        let content = try GameContentLoader.load(from: .main)
        let state = await makeState { $0.meta.ownedSkins = content.skins.skins.map(\.id) }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_skins_all"))
    }

    @Test("specialsOwned se cruza con los personajes especiales conseguidos")
    func specialsOwnedTrigger() async {
        let state = await makeState { $0.meta.ownedSpecials = ["uno"] }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_specials_1"))
        #expect(!state.isUnlocked("ach_specials_10"))
    }

    @Test("videosWatched se cruza con el contador de cuenta")
    func videosWatchedTrigger() async {
        let state = await makeState { $0.meta.stats.videosWatchedEver = 1 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_videos_1"))
        #expect(!state.isUnlocked("ach_videos_20"))
    }

    @Test("boostsActivated se cruza con el contador de cuenta")
    func boostsActivatedTrigger() async {
        let state = await makeState { $0.meta.stats.boostsActivatedEver = 50 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_boosts_1"))
        #expect(state.isUnlocked("ach_boosts_50"))
    }

    @Test("lifetimeEarnings se cruza con la plata de toda la historia")
    func lifetimeEarningsTrigger() async {
        let state = await makeState { $0.meta.lifetimeEarnings = 1_000_000 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_wealth_1m"))
        #expect(!state.isUnlocked("ach_wealth_1b"))
    }

    /// El nodo de elección `junior` NO cuenta: es una bifurcación, no un
    /// personaje, y exigirlo dejaría el logro imposible.
    @Test("seenAllTypes se cruza al ver los 43 tipos concretos")
    func seenAllTypesTrigger() async throws {
        let content = try GameContentLoader.load(from: .main)
        let state = await makeState {
            $0.run.seenTypes = Set(content.tiers.concreteTypes.map(\.id))
        }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_seen_all"))
    }

    @Test("dailyDay7 se cruza al llegar al día 7 del ciclo")
    func dailyDay7Trigger() async {
        let state = await makeState { $0.meta.daily.cycleDay = 7 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_daily_7"))
    }

    @Test("sharesCompleted se cruza al compartir")
    func sharesCompletedTrigger() async {
        let state = await makeState { $0.meta.sharesCompleted = 1 }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_share_1"))
    }

    @Test("una partida nueva no desbloquea nada")
    func freshGameUnlocksNothing() async {
        let state = await makeGameState()
        state.evaluateAchievements()
        #expect(state.player?.meta.unlockedAchievements.isEmpty == true)
    }

    // MARK: Idempotencia

    @Test("evaluar dos veces no duplica el desbloqueo ni vuelve a avisar")
    func evaluationIsIdempotent() async {
        let state = await makeState { $0.meta.stats.totalMergesEver = 1 }
        state.evaluateAchievements()
        let first = state.player?.meta.unlockedAchievements
        state.achievementToast = nil
        state.evaluateAchievements()
        #expect(state.player?.meta.unlockedAchievements == first)
        #expect(state.achievementToast == nil, "un logro ya desbloqueado no vuelve a toastear")
    }

    @Test("el desbloqueo avisa una vez, con el título ya resuelto")
    func unlockRaisesOneToast() async {
        let state = await makeState { $0.meta.stats.totalMergesEver = 1 }
        state.evaluateAchievements()
        let toast = state.achievementToast
        #expect(toast?.id == "ach_merges_1")
        #expect(toast?.titleText.isEmpty == false)
        // El título viene RESUELTO, no como clave (trampa 5 del HANDOFF).
        #expect(toast?.titleText != "ach.merges_1.title")
    }

    /// Varios logros que caen juntos no se pisan: el primero se muestra y el
    /// resto espera turno.
    @Test("varios logros a la vez hacen cola")
    func simultaneousUnlocksQueue() async {
        let state = await makeState {
            $0.meta.stats.totalMergesEver = 1
            $0.meta.stats.totalHiresEver = 10
            $0.meta.sharesCompleted = 1
        }
        state.evaluateAchievements()
        #expect(state.player?.meta.unlockedAchievements.count == 3)
        let first = state.achievementToast
        #expect(first != nil)
        state.dismissAchievementToast(id: first!.id)
        #expect(state.achievementToast != nil, "el segundo de la cola toma el lugar del primero")
        #expect(state.achievementToast?.id != first?.id)
    }

    // MARK: Cobro

    @Test("cobrar acredita monedas y no se puede cobrar dos veces")
    func claimCreditsCoinsOnce() async {
        let state = await makeState { $0.meta.stats.totalMergesEver = 1 }
        state.evaluateAchievements()
        let before = state.player?.run.coins ?? 0
        let lifetimeBefore = state.player?.meta.lifetimeEarnings ?? 0

        state.claimAchievement(id: "ach_merges_1")
        let after = state.player?.run.coins ?? 0
        #expect(after > before)
        #expect(state.player?.meta.claimedAchievements.contains("ach_merges_1") == true)
        // La plata de un logro es plata ganada: cuenta para el ORO.
        #expect((state.player?.meta.lifetimeEarnings ?? 0) - lifetimeBefore == after - before)

        state.claimAchievement(id: "ach_merges_1")
        #expect(state.player?.run.coins == after, "cobrar dos veces no paga dos veces")
    }

    @Test("un logro que no se consiguió no se puede cobrar")
    func claimingALockedAchievementPaysNothing() async {
        let state = await makeGameState()
        let before = state.player?.run.coins ?? 0
        state.claimAchievement(id: "ach_merges_1")
        #expect(state.player?.run.coins == before)
        #expect(state.player?.meta.claimedAchievements.isEmpty == true)
    }

    @Test("un id que no existe en el catálogo no hace nada")
    func claimingAnUnknownIdIsANoOp() async {
        let state = await makeState { $0.meta.unlockedAchievements.insert("ach_inventado") }
        let before = state.player?.run.coins ?? 0
        state.claimAchievement(id: "ach_inventado")
        #expect(state.player?.run.coins == before)
        #expect(state.player?.meta.claimedAchievements.isEmpty == true)
    }

    /// El premio en monedas es un FACTOR sobre `passiveUnlockCost(maxTier)`, no
    /// un número escrito: cobrarlo tarde paga más, igual que el cofre del Asado.
    @Test("el premio en monedas escala con el tier máximo alcanzado")
    func coinRewardScalesWithMaxTier() async throws {
        let low = await makeState {
            $0.meta.stats.totalMergesEver = 1
            $0.run.maxTierReached = 1
        }
        low.evaluateAchievements()
        let lowBefore = low.player?.run.coins ?? 0
        low.claimAchievement(id: "ach_merges_1")
        let lowGain = (low.player?.run.coins ?? 0) - lowBefore

        let high = await makeState {
            $0.meta.stats.totalMergesEver = 1
            $0.run.maxTierReached = 12
        }
        high.evaluateAchievements()
        let highBefore = high.player?.run.coins ?? 0
        high.claimAchievement(id: "ach_merges_1")
        let highGain = (high.player?.run.coins ?? 0) - highBefore

        #expect(highGain > lowGain)
        // El factor del catálogo, exacto: 2× el costo de pasivo del tier máximo.
        let economy = try #require(high.economy)
        let expected = economy.passiveUnlockCost(forTier: 12) * 2.0
        #expect(abs(highGain - expected) < expected * 1e-9)
    }

    /// El multiplicador global se computa sobre `oroEarnedLifetime`, que SOLO
    /// sube al reencarnar. Un logro que lo tocara regalaría multiplicador
    /// permanente por fuera del prestigio (mismo criterio que los packs de ORO).
    @Test("el premio en oro suma al balance y NO al oro histórico")
    func oroRewardNeverTouchesLifetimeOro() async {
        let state = await makeState { $0.meta.prestigeLevel = 3 }
        state.evaluateAchievements()
        let oroBefore = state.player?.meta.oro ?? 0
        let lifetimeBefore = state.player?.meta.oroEarnedLifetime ?? 0

        state.claimAchievement(id: "ach_prestige_3")
        #expect(state.player?.meta.oro == oroBefore + 25)
        #expect(state.player?.meta.oroEarnedLifetime == lifetimeBefore)
        #expect(state.player?.meta.lifetimeEarnings == 0, "el oro no es plata: no toca lifetimeEarnings")
    }

    // MARK: Proyección

    @Test("las filas resuelven textos, estado y progreso")
    func rowsResolveEverything() async throws {
        let state = await makeState { $0.meta.stats.totalMergesEver = 50 }
        state.evaluateAchievements()
        let rows = state.achievementRows
        #expect(rows.count == 39)

        let merges1 = try #require(rows.first { $0.id == "ach_merges_1" })
        #expect(merges1.state == .unlocked)
        #expect(merges1.progress == 1)
        #expect(!merges1.titleText.isEmpty)
        #expect(!merges1.descText.isEmpty)
        #expect(!merges1.rewardText.isEmpty)
        // Textos RESUELTOS, no claves crudas (trampa 5 del HANDOFF).
        #expect(merges1.titleText != "ach.merges_1.title")
        #expect(merges1.descText != "ach.merges_1.desc")

        // 50 de 100 fusiones: medio camino.
        let merges100 = try #require(rows.first { $0.id == "ach_merges_100" })
        #expect(merges100.state == .locked)
        #expect(abs(merges100.progress - 0.5) < 1e-9)

        // Un trigger booleano no tiene medias tintas.
        let floor = try #require(rows.first { $0.id == "ach_floor_urban" })
        #expect(floor.progress == 0)

        state.claimAchievement(id: "ach_merges_1")
        let claimed = try #require(state.achievementRows.first { $0.id == "ach_merges_1" })
        #expect(claimed.state == .claimed)
    }

    /// Un logro conseguido en una vida anterior sigue mostrando la barra llena
    /// aunque la run actual haya vuelto a cero.
    @Test("un logro ya conseguido muestra el progreso completo")
    func unlockedRowsAlwaysShowFullProgress() async throws {
        let state = await makeState { $0.meta.unlockedAchievements.insert("ach_tier_37") }
        let row = try #require(state.achievementRows.first { $0.id == "ach_tier_37" })
        #expect(row.state == .unlocked)
        #expect(row.progress == 1)
    }

    // MARK: Validación del loader

    @Test("un floorId inexistente rompe la carga")
    func validationRejectsUnknownFloor() throws {
        let content = try GameContentLoader.load(from: .main)
        let config = Self.config(trigger: .init(type: "floorUnlocked", value: nil, floorId: "sotano"))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(
                achievements: config,
                floorTable: content.floorTable,
                boosts: content.boosts
            )
        }
    }

    @Test("un trigger fuera del set conocido rompe la carga")
    func validationRejectsUnknownTrigger() throws {
        let content = try GameContentLoader.load(from: .main)
        let config = Self.config(trigger: .init(type: "alineacionPlanetaria", value: 3, floorId: nil))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(
                achievements: config,
                floorTable: content.floorTable,
                boosts: content.boosts
            )
        }
    }

    @Test("una recompensa mal formada rompe la carga")
    func validationRejectsMalformedReward() throws {
        let content = try GameContentLoader.load(from: .main)
        // `coins` sin `factor`: pagaría cero para siempre, en silencio.
        let sinFactor = Self.config(reward: .init(kind: "coins", factor: nil, amount: 30, boostId: nil))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: sinFactor, floorTable: content.floorTable, boosts: content.boosts)
        }
        // `oro` sin `amount`.
        let sinAmount = Self.config(reward: .init(kind: "oro", factor: 2, amount: nil, boostId: nil))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: sinAmount, floorTable: content.floorTable, boosts: content.boosts)
        }
        // Un kind que no existe.
        let kindRaro = Self.config(reward: .init(kind: "chapita", factor: nil, amount: 1, boostId: nil))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: kindRaro, floorTable: content.floorTable, boosts: content.boosts)
        }
        // `freeBoost` apuntando a un boost que no existe.
        let boostFantasma = Self.config(reward: .init(kind: "freeBoost", factor: nil, amount: nil, boostId: "no_existe"))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: boostFantasma, floorTable: content.floorTable, boosts: content.boosts)
        }
    }

    @Test("dos logros con el mismo id rompen la carga")
    func validationRejectsDuplicateIDs() throws {
        let content = try GameContentLoader.load(from: .main)
        let one = Self.achievement()
        let config = AchievementsConfig(schemaVersion: 1, achievements: [one, one])
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: config, floorTable: content.floorTable, boosts: content.boosts)
        }
    }

    @Test("un trigger numérico sin value rompe la carga")
    func validationRejectsNumericTriggerWithoutValue() throws {
        let content = try GameContentLoader.load(from: .main)
        let config = Self.config(trigger: .init(type: "totalMerges", value: nil, floorId: nil))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: config, floorTable: content.floorTable, boosts: content.boosts)
        }
    }

    @Test("el catálogo real pasa su propia validación")
    func realCatalogValidates() throws {
        let content = try GameContentLoader.load(from: .main)
        try GameContentLoader.validate(
            achievements: content.achievements,
            floorTable: content.floorTable,
            boosts: content.boosts
        )
    }

    // MARK: Helpers

    private static func achievement(
        id: String = "ach_test",
        trigger: AchievementsConfig.Trigger = .init(type: "totalMerges", value: 1, floorId: nil),
        reward: AchievementsConfig.Reward = .init(kind: "coins", factor: 2, amount: nil, boostId: nil)
    ) -> AchievementsConfig.Achievement {
        AchievementsConfig.Achievement(
            id: id,
            titleKey: "ach.test.title",
            descKey: "ach.test.desc",
            icon: "trophy_bronze",
            trigger: trigger,
            reward: reward
        )
    }

    private static func config(
        trigger: AchievementsConfig.Trigger = .init(type: "totalMerges", value: 1, floorId: nil),
        reward: AchievementsConfig.Reward = .init(kind: "coins", factor: 2, amount: nil, boostId: nil)
    ) -> AchievementsConfig {
        AchievementsConfig(schemaVersion: 1, achievements: [achievement(trigger: trigger, reward: reward)])
    }
}

@MainActor
private func makeState(_ mutate: (inout PlayerState) -> Void) async -> GameState {
    let state = await makeGameState()
    guard var player = state.player else { return state }
    mutate(&player)
    state.player = player
    return state
}

private extension GameState {
    func isUnlocked(_ id: String) -> Bool {
        player?.meta.unlockedAchievements.contains(id) == true
    }
}
