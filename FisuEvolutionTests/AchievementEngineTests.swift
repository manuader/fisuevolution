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

    /// ⚠️ **Se mide contra los tipos ALCANZABLES, no contra los 43.** La carrera
    /// es excluyente y `run.seenTypes` muere al reencarnar: una run ve como
    /// máximo el tronco (35) más el junior y el senior de SU rama = 37. Medir
    /// contra 43 dejaba el logro —40 de ORO— matemáticamente inconseguible, con
    /// la barra clavada en 0,86 para siempre.
    @Test("seenAllTypes se cruza con los tipos alcanzables de tu carrera, no con los 43")
    func seenAllTypesTrigger() async throws {
        let branch = Self.doctorBranch
        let trunk = try Self.trunkTypeIDs()
        #expect(trunk.count == 35, "el tronco es lo que ve cualquier carrera")

        let todos = await makeState {
            $0.run.chosenCareerPath = "doctor"
            $0.run.seenTypes = Set(trunk + branch)
        }
        todos.evaluateAchievements()
        #expect(todos.isUnlocked("ach_seen_all"), "37 alcanzables tienen que alcanzar")

        // Y no hace falta haber visto las otras tres carreras: con las 6 ajenas
        // puestas el resultado es el mismo, no “más completo”.
        let row = try #require(todos.achievementRows.first { $0.id == "ach_seen_all" })
        #expect(row.state == .unlocked)
        #expect(row.progress == 1)
    }

    @Test("a seenAllTypes le falta uno si te falta uno de tu rama")
    func seenAllTypesStillNeedsTheWholeBranch() async throws {
        let trunk = try Self.trunkTypeIDs()
        // 36 de 37: está el junior de la rama, falta el senior.
        let state = await makeState {
            $0.run.chosenCareerPath = "doctor"
            $0.run.seenTypes = Set(trunk + ["junior_doctor"])
        }
        state.evaluateAchievements()
        #expect(!state.isUnlocked("ach_seen_all"))

        let row = try #require(state.achievementRows.first { $0.id == "ach_seen_all" })
        #expect(abs(row.progress - 36.0 / 37.0) < 1e-9, "el objetivo es 37, no 43")
    }

    /// Ver los tipos de OTRA carrera no acerca el logro: no son alcanzables en
    /// esta vida y contarlos volvería a hacerlo inconseguible por el otro lado.
    @Test("los tipos de las carreras ajenas no cuentan para seenAllTypes")
    func foreignCareerTypesDoNotCount() async throws {
        let trunk = try Self.trunkTypeIDs()
        let state = await makeState {
            $0.run.chosenCareerPath = "doctor"
            $0.run.seenTypes = Set(trunk + Self.foreignBranches)
        }
        state.evaluateAchievements()
        #expect(!state.isUnlocked("ach_seen_all"))
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

    /// El motor no puede apagarse por contar mal. La versión anterior cortaba
    /// con `unlockedAchievements.count < catalog.count`, que compara ids del
    /// SAVE contra el catálogo VIGENTE: con logros retirados, un save viejo
    /// supera la cuenta y el motor se apagaba entero, en silencio y para
    /// siempre.
    @Test("un save con ids de logros retirados no apaga el motor")
    func retiredAchievementIDsDoNotStallTheEngine() async {
        let state = await makeState {
            // Más ids que logros hay en el catálogo, y ninguno del catálogo.
            $0.meta.unlockedAchievements = Set((0..<40).map { "ach_retirado_\($0)" })
            $0.meta.stats.totalMergesEver = 1
        }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_merges_1"), "un logro alcanzable se desbloquea igual")
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

    /// El premio en monedas son **segundos de tu producción** (el molde del
    /// Aguinaldo), no un múltiplo de un costo: dos jugadores parados en el mismo
    /// tier pero con torres distintas cobran distinto, y en la proporción exacta
    /// de lo que cada torre produce.
    @Test("el premio en monedas escala con lo que produce la torre")
    func coinRewardScalesWithTowerProduction() async throws {
        let content = try GameContentLoader.load(from: .main)
        let producer = content.tiers.baseType.id

        func gain(units: Int) async -> Double {
            let state = await makeState {
                $0.meta.stats.totalMergesEver = 1
                // Tier de referencia 1: el piso mínimo del premio es un solo
                // personaje, así que lo que manda es la torre y no el piso.
                $0.run.maxTierReached = 1
                $0.meta.stats.maxFloorOrdinalEver = 0
                $0.run.units[producer] = units
                $0.run.passiveUnlocked[producer] = true
            }
            state.evaluateAchievements()
            let before = state.player?.run.coins ?? 0
            state.claimAchievement(id: "ach_merges_1")
            return (state.player?.run.coins ?? 0) - before
        }

        let small = await gain(units: 2)
        let big = await gain(units: 8)
        #expect(small > 0)
        #expect(abs(big - small * 4) < big * 1e-9, "cuatro veces la torre, cuatro veces el premio")
    }

    /// El caso que convierte el molde nuevo en un bug si no se lo atiende: al
    /// arrancar —o después de reencarnar, antes de comprar el primer pasivo— la
    /// producción es CERO, y `producción × segundos` sería un logro que no paga
    /// nada. El piso es un personaje del tier de referencia produciendo solo.
    @Test("con la torre sin producir, el premio sigue pagando")
    func coinRewardNeverPaysZero() async throws {
        let state = await makeState { $0.meta.stats.totalMergesEver = 1 }
        #expect(state.player?.run.passiveUnlocked.isEmpty == true, "arranque sin un solo pasivo comprado")
        state.evaluateAchievements()

        let before = state.player?.run.coins ?? 0
        state.claimAchievement(id: "ach_merges_1")
        let gain = (state.player?.run.coins ?? 0) - before

        let economy = try #require(state.economy)
        let lonelyWorker = economy.passiveYield(forTier: 1)
        #expect(abs(gain - lonelyWorker * (try Self.seconds(of: "ach_merges_1"))) < gain * 1e-9)
        #expect(gain > 0)
    }

    /// Cobrar es una decisión del jugador, no un tiro del reloj: si el premio
    /// cotizara los modificadores temporales, guardarse los 27 logros para el
    /// próximo Plan Platita pagaría ×5 por esperar. El Aguinaldo puede mirarlos
    /// porque el que elige el momento es el juego; acá no.
    @Test("un evento de income no infla el premio del logro")
    func coinRewardIgnoresTemporaryModifiers() async throws {
        func gain(withEvent: Bool) async -> Double {
            let state = await makeState { player in
                player.meta.stats.totalMergesEver = 1
                player.run.maxTierReached = 1
                player.run.units["homeless"] = 4
                player.run.passiveUnlocked["homeless"] = true
                if withEvent {
                    player.run.activeModifiers.append(ActiveModifier(
                        effect: .incomeMultiplier,
                        magnitude: 5,
                        expiresAt: .greatestFiniteMagnitude,
                        sourceKey: "event.plan_platita"
                    ))
                }
            }
            state.evaluateAchievements()
            let before = state.player?.run.coins ?? 0
            state.claimAchievement(id: "ach_merges_1")
            return (state.player?.run.coins ?? 0) - before
        }

        let plain = await gain(withEvent: false)
        let boosted = await gain(withEvent: true)
        #expect(plain > 0)
        #expect(abs(boosted - plain) < plain * 1e-9, "el banner de turno no cotiza el premio")
    }

    /// El PISO del premio (lo que paga con la torre sin producir) sale del tier
    /// de referencia, así que sigue creciendo con el progreso.
    ///
    /// ⚠️ Este test antes pineaba `passiveUnlockCost(maxTier) × factor`. Cambió
    /// de significado con el molde nuevo —el premio ya no cotiza un costo— y por
    /// eso se reescribe en vez de borrarse: lo que se conserva es la propiedad
    /// que le importaba al jugador (cobrarlo más arriba paga más).
    @Test("el piso del premio en monedas escala con el tier máximo alcanzado")
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
        // El número del catálogo, exacto: un trabajador del tier 12 produciendo
        // solo, por los segundos que paga el logro.
        let economy = try #require(high.economy)
        let expected = economy.passiveYield(forTier: 12) * (try Self.seconds(of: "ach_merges_1"))
        #expect(abs(highGain - expected) < expected * 1e-9)
    }

    /// Reencarnar antes de cobrar NO puede evaporar el premio: `run.maxTierReached`
    /// vuelve a 1 y `passiveYield` es exponencial, así que cobrar después
    /// pagaría órdenes de magnitud menos — y como `claimed` es de una sola vía,
    /// el premio quedaría quemado sin forma de recuperarlo.
    @Test("el premio en monedas conserva el suelo histórico al reencarnar")
    func coinRewardKeepsItsHistoricFloor() async throws {
        let content = try GameContentLoader.load(from: .main)
        // El piso más alto que tocó en su vida: galaxia (ordinal 8, tiers 33…36).
        let ordinal = 8
        let state = await makeState {
            $0.meta.stats.totalMergesEver = 1
            $0.run.maxTierReached = 33
            $0.meta.stats.maxFloorOrdinalEver = ordinal
        }
        state.evaluateAchievements()
        #expect(state.isUnlocked("ach_merges_1"))

        // Reencarnar es exactamente esto (ver el docstring de `RunState.fresh`).
        var player = try #require(state.player)
        player.run = .fresh(startTypeId: "homeless", startFloorId: "alley")
        state.player = player
        #expect(state.player?.run.maxTierReached == 1)

        let before = state.player?.run.coins ?? 0
        state.claimAchievement(id: "ach_merges_1")
        let gain = (state.player?.run.coins ?? 0) - before

        let economy = try #require(state.economy)
        let referenceTier = content.floorTable[ordinal].firstTier
        let expected = economy.passiveYield(forTier: referenceTier) * (try Self.seconds(of: "ach_merges_1"))
        #expect(abs(gain - expected) < expected * 1e-9, "el suelo es el primer tier del piso más alto de su vida")
        // Y no es una diferencia cosmética: cobrarlo como T1 pagaba ~1e13 veces menos.
        #expect(gain > economy.passiveYield(forTier: 1) * 1_000_000)
    }

    /// La fila cotiza con el MISMO tier con el que después paga el cobro: si no,
    /// la pantalla prometería un número y el botón daría otro.
    @Test("el texto del premio y lo que se acredita usan el mismo tier")
    func rewardTextAgreesWithWhatItPays() async throws {
        let state = await makeState {
            $0.meta.stats.totalMergesEver = 1
            $0.run.maxTierReached = 1
            $0.meta.stats.maxFloorOrdinalEver = 8
        }
        state.evaluateAchievements()
        let row = try #require(state.achievementRows.first { $0.id == "ach_merges_1" })

        let before = state.player?.run.coins ?? 0
        state.claimAchievement(id: "ach_merges_1")
        let gain = (state.player?.run.coins ?? 0) - before
        #expect(row.rewardText.contains(CoinFormatter.string(from: gain)))
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
        // 2 y no 25: el re-escalado de los doce logros de ORO
        // (`fixedOroAchievementsFundAFifthOfTheRun`).
        #expect(state.player?.meta.oro == oroBefore + 2)
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
        // `coins` sin `seconds`: pagaría cero para siempre, en silencio.
        let sinFactor = Self.config(reward: .init(kind: "coins", seconds: nil, amount: 30, boostId: nil))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: sinFactor, floorTable: content.floorTable, boosts: content.boosts)
        }
        // `oro` sin `amount`.
        let sinAmount = Self.config(reward: .init(kind: "oro", seconds: 2, amount: nil, boostId: nil))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: sinAmount, floorTable: content.floorTable, boosts: content.boosts)
        }
        // Un kind que no existe.
        let kindRaro = Self.config(reward: .init(kind: "chapita", seconds: nil, amount: 1, boostId: nil))
        #expect(throws: GameError.self) {
            try GameContentLoader.validate(achievements: kindRaro, floorTable: content.floorTable, boosts: content.boosts)
        }
        // `freeBoost` apuntando a un boost que no existe.
        let boostFantasma = Self.config(reward: .init(kind: "freeBoost", seconds: nil, amount: nil, boostId: "no_existe"))
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

    /// La rama que el test elige, y las tres que quedan cerradas por elegirla.
    /// Van escritas a mano a propósito: si el test derivara las ramas igual que
    /// el motor, los dos podrían estar equivocados juntos.
    private static let doctorBranch = ["junior_doctor", "senior_doctor"]
    private static let foreignBranches = [
        "junior_programmer", "senior_programmer",
        "junior_architect", "senior_architect",
        "junior_lawyer", "senior_lawyer",
    ]

    /// Los tipos concretos que ve CUALQUIER carrera: todo menos las ocho ramas.
    private static func trunkTypeIDs() throws -> [String] {
        let content = try GameContentLoader.load(from: .main)
        let branchTypes = Set(doctorBranch + foreignBranches)
        return content.tiers.concreteTypes.map(\.id).filter { !branchTypes.contains($0) }
    }

    /// El criterio que hace que el piso sea un PISO y no un premio: **nunca puede
    /// pagar más que el molde viejo** (`passiveUnlockCost(tier) × factor`), que
    /// es justo el que esta rama vino a bajar.
    ///
    /// Se mide en los DOS extremos de la torre porque el bug que esto pinea era
    /// exponencial en el tier: el piso llevaba puesto el multiplicador de piso
    /// (620 en el reino divino) y ahí pagaba 77× el molde viejo, mandando
    /// exactamente cuando `run` se resetea al reencarnar. Pelado a
    /// `passiveYield(tier)` la razón es `seconds / (120 × factor)`: constante en
    /// el tier, porque los dos lados escalan con `tapYield(tier)`.
    @Test("el piso nunca paga más que el molde viejo, ni en el tier 1 ni en el 37")
    func coinRewardFloorNeverBeatsTheOldMold() async throws {
        let content = try GameContentLoader.load(from: .main)
        // El `factor` que `ach_merges_1` tenía ANTES de la migración a segundos
        // (commit f2c5b37). Va escrito porque es una constante histórica: es
        // contra ese número que se promete no pasarse.
        let oldFactor = 2.0

        /// El premio con la torre SIN producir, o sea el piso puro.
        func floorPayout(referenceTier: Int, floorOrdinal: Int) async -> Double {
            let state = await makeState {
                $0.meta.stats.totalMergesEver = 1
                $0.run.maxTierReached = referenceTier
                $0.meta.stats.maxFloorOrdinalEver = floorOrdinal
            }
            state.evaluateAchievements()
            let before = state.player?.run.coins ?? 0
            state.claimAchievement(id: "ach_merges_1")
            return (state.player?.run.coins ?? 0) - before
        }

        let economy = StandardEconomy(config: content.economy)
        for (tier, ordinal) in [(1, 0), (37, content.floorTable.floors.count - 1)] {
            let paid = await floorPayout(referenceTier: tier, floorOrdinal: ordinal)
            let oldMold = economy.passiveUnlockCost(forTier: tier) * oldFactor
            #expect(paid > 0, "un logro que no paga nada es un bug (tier \(tier))")
            #expect(paid <= oldMold, "el piso se pasó del molde viejo en el tier \(tier): \(paid) > \(oldMold)")
        }
    }

    /// Los segundos que el catálogo REAL le paga a un logro: clavarlos en el
    /// test convertiría cada recalibración de `achievements.json` en un rojo.
    private static func seconds(of id: String) throws -> Double {
        let content = try GameContentLoader.load(from: .main)
        return try #require(content.achievements.achievements.first { $0.id == id }?.reward.seconds)
    }

    private static func achievement(
        id: String = "ach_test",
        trigger: AchievementsConfig.Trigger = .init(type: "totalMerges", value: 1, floorId: nil),
        reward: AchievementsConfig.Reward = .init(kind: "coins", seconds: 30, amount: nil, boostId: nil)
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
        reward: AchievementsConfig.Reward = .init(kind: "coins", seconds: 30, amount: nil, boostId: nil)
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
