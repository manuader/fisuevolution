import EconomyKit
import Foundation

/// Una fila de la pantalla de Logros (spec §10.3), ya resuelta: la vista la
/// dibuja sin volver a preguntarle nada al estado ni conocer `PlayerState`.
///
/// ⚠️ **`titleText`/`descText`/`rewardText` vienen RESUELTOS, no como claves.**
/// Las claves del catálogo se arman por id (`ach.<id>.title`) y armar un
/// `LocalizedStringKey` con eso desde la vista es la trampa 5 del HANDOFF: la
/// interpolación construye la clave `ach.%@.title`, que no existe, y en pantalla
/// se lee el id crudo. La resolución vive acá, y el test ejerce esta misma
/// función.
struct AchievementRow: Identifiable, Equatable {
    /// Un logro pasa por tres estados y sólo avanza: conseguirlo y cobrarlo son
    /// dos actos distintos, y el segundo es del jugador.
    enum State: Equatable {
        case locked
        case unlocked
        case claimed
    }

    let id: String
    let titleText: String
    let descText: String
    /// `trophy_bronze` / `trophy_silver` / `trophy_gold`, tal cual el catálogo.
    let icon: String
    let state: State
    /// 0…1. Los gatillos numéricos van por proporción; los booleanos
    /// (abrir un piso) sólo tienen 0 y 1. Un logro ya conseguido muestra 1
    /// aunque la run haya vuelto a cero al reencarnar.
    let progress: Double
    /// "12.500 monedas" / "25 de ORO" — con el número del catálogo puesto.
    let rewardText: String
}

/// El aviso de un logro recién conseguido. Se muestra de a uno: ver
/// `GameState.pendingAchievementToasts`.
///
/// Es top-level y no anidado en `GameState` por lo mismo que `JobRow`: el
/// `@Observable` de la clase no resuelve un tipo declarado en la extensión de
/// OTRO archivo, y la propiedad publicada lo necesita en scope.
struct AchievementToast: Identifiable, Equatable {
    /// El id del logro: estable, y lo que usa el banner para su `task(id:)`.
    let id: String
    let titleText: String
    let icon: String
}

/// Los logros (spec §10.3): motor de desbloqueo, cobro de la recompensa y la
/// proyección que dibuja la pantalla. Separado de `GameState.swift` para que el
/// frente de logros no comparta archivo con los otros dominios.
///
/// **Mapeo con Game Center** (`Config/gamecenter.json`, hoy apagado por
/// `flags.gameCenterEnabled`). Cuando se encienda, los cinco achievements de GC
/// se reportan desde acá con esta correspondencia — los ids NO colisionan, así
/// que conviven sin tocar `GameCenterManager` ni el JSON:
///
/// | Game Center | Logro del catálogo |
/// |---|---|
/// | `ach_first_merge` (`firstMerge`) | `ach_merges_1` |
/// | `ach_tier9_uba` (`reachTier` 11) | `ach_tier_11` |
/// | `ach_tier21` (`reachTier` 24) | `ach_tier_24` |
/// | `ach_tier30_god` (`reachTier` 37) | `ach_tier_37` |
/// | `ach_first_prestige` (`firstPrestige`) | `ach_prestige_1` |
extension GameState {
    // MARK: Motor

    /// Recorre los logros **todavía no conseguidos** y desbloquea los que el
    /// estado ya cruzó. Idempotente: volver a llamarla no duplica nada ni vuelve
    /// a avisar.
    ///
    /// Es barata a propósito —un `Set.contains` y una comparación por logro
    /// pendiente, con un portero que corta de una cuando ya están todos— porque
    /// cuelga de los diez choke points del juego, incluido el tap. Al lado de lo
    /// que hace `refreshProjections` en la misma acción, es ruido.
    ///
    /// **Durante el arranque no avisa** (`phase != .ready`): un save de antes de
    /// que existieran los logros cruza diez gatillos de una, y desfilar diez
    /// banners por algo que el jugador no acaba de hacer no es una celebración,
    /// es una cortina. El crédito se hace igual; la pantalla de Logros los
    /// muestra conseguidos y sin cobrar. Colgarlo de `phase` y no de un
    /// parámetro es lo que hace que ningún call site pueda equivocarse: los
    /// hooks que corren dentro de `bootstrap` (`reconcileTower`,
    /// `claimDailyIfAvailable`) quedan callados sin saberlo.
    func evaluateAchievements() {
        guard let content, let player else { return }
        let catalog = content.achievements.achievements
        guard player.meta.unlockedAchievements.count < catalog.count else { return }

        var newlyUnlocked: [AchievementsConfig.Achievement] = []
        for achievement in catalog where !player.meta.unlockedAchievements.contains(achievement.id) {
            let progress = measure(achievement.trigger, player: player, content: content)
            guard progress.current >= progress.target else { continue }
            newlyUnlocked.append(achievement)
        }
        guard !newlyUnlocked.isEmpty else { return }

        var updated = player
        for achievement in newlyUnlocked {
            updated.meta.unlockedAchievements.insert(achievement.id)
        }
        self.player = updated
        if phase == .ready {
            enqueueAchievementToasts(newlyUnlocked)
            // El mismo acento que un ascenso: es un premio, no una compra.
            audio?.play(.rare)
        }
        scheduleSave()
        Log.economy.info("achievements unlocked: \(newlyUnlocked.map(\.id))")
    }

    /// Dónde vas y adónde hay que llegar, para UN gatillo.
    ///
    /// Es la única fuente de las dos cosas: el desbloqueo es `current >= target`
    /// y la barra es `current / target`. Calculados por separado podrían
    /// discrepar —una barra llena con el logro todavía cerrado— y esa es
    /// exactamente la clase de bug que nadie reporta.
    ///
    /// El switch es exhaustivo sobre `TriggerKind` (sin `default`): un gatillo
    /// nuevo no compila hasta que alguien decida cómo se mide.
    private func measure(
        _ trigger: AchievementsConfig.Trigger,
        player: PlayerState,
        content: GameContent
    ) -> (current: Double, target: Double) {
        // Un `type` fuera del enum ya lo rechazó `GameContentLoader.validate` al
        // arrancar, así que acá es inalcanzable: si igual llegara, no se cruza.
        guard let kind = trigger.kind else { return (0, .infinity) }
        let value = trigger.value ?? 0

        switch kind {
        case .floorUnlocked:
            // Booleano: el piso abierto AHORA, o el máximo histórico, que es lo
            // que sobrevive a la reencarnación. Un logro no se devuelve.
            guard let floorID = trigger.floorId else { return (0, 1) }
            let openNow = player.run.unlockedFloors.contains(floorID)
            let everReached = content.floorTable.ordinal(of: floorID)
                .map { player.meta.stats.maxFloorOrdinalEver >= $0 } ?? false
            return (openNow || everReached ? 1 : 0, 1)
        case .tierReached:
            return (Double(player.run.maxTierReached), value)
        case .totalMerges:
            return (Double(player.meta.stats.totalMergesEver), value)
        case .totalHires:
            return (Double(player.meta.stats.totalHiresEver), value)
        case .totalTaps:
            return (Double(player.meta.stats.totalTapsEver), value)
        case .prestigeLevel:
            return (Double(player.meta.prestigeLevel), value)
        case .skinsOwned:
            return (Double(player.meta.allOwnedSkins.count), value)
        case .skinsAll:
            // Se cuentan las del CATÁLOGO que tenés, no el tamaño de tu lista:
            // un save con una skin retirada entre versiones (pasó con `kiosco`)
            // llegaría al número sin tenerlas todas.
            let owned = player.meta.allOwnedSkins
            let have = content.skins.skins.filter { owned.contains($0.id) }.count
            return (Double(have), Double(content.skins.skins.count))
        case .specialsOwned:
            return (Double(player.meta.ownedSpecials.count), value)
        case .videosWatched:
            return (Double(player.meta.stats.videosWatchedEver), value)
        case .boostsActivated:
            return (Double(player.meta.stats.boostsActivatedEver), value)
        case .lifetimeEarnings:
            return (player.meta.lifetimeEarnings, value)
        case .seenAllTypes:
            let concrete = content.tiers.concreteTypes
            let seen = concrete.filter { player.run.seenTypes.contains($0.id) }.count
            return (Double(seen), Double(concrete.count))
        case .dailyDay7:
            // `cycleDay` apunta al día que el ciclo VA A PAGAR y vuelve a 1 al
            // cobrar el último, así que llegar a 7 es el único momento
            // observable de la semana completa (ver `dailyCalendar`).
            return (Double(player.meta.daily.cycleDay), value)
        case .sharesCompleted:
            return (Double(player.meta.sharesCompleted), value)
        }
    }

    // MARK: Cobro

    /// Acredita el premio de un logro conseguido. Sólo una vez: conseguirlo y
    /// cobrarlo son actos distintos y `claimedAchievements` es el recibo.
    func claimAchievement(id: String, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, let economy, var player,
              let achievement = content.achievements.achievements.first(where: { $0.id == id }),
              player.meta.unlockedAchievements.contains(id),
              !player.meta.claimedAchievements.contains(id),
              let kind = achievement.reward.rewardKind
        else { return }

        switch kind {
        case .coins:
            // Mismo cálculo que el cofre del Asado y el premio de la carrera: un
            // factor sobre lo que cuesta el pasivo del tier máximo, así el
            // premio nunca queda ridículo por cobrarlo tarde.
            let chest = economy.passiveUnlockCost(forTier: player.run.maxTierReached)
                * (achievement.reward.factor ?? 0)
            player.run.coins += chest
            player.meta.lifetimeEarnings += chest
            audio?.play(.coin)
        case .oro:
            // ⚠️ SÓLO el balance. `oroEarnedLifetime` es de donde sale el
            // multiplicador global y sube ÚNICAMENTE al reencarnar; tocarlo acá
            // regalaría multiplicador permanente por fuera del prestigio (mismo
            // criterio que los packs de ORO de la tienda).
            player.meta.oro += achievement.reward.amount ?? 0
            audio?.play(.coin)
        case .freeBoost:
            grantFreeBoost(id: achievement.reward.boostId, player: &player, content: content, economy: economy, now: now)
        }

        player.meta.claimedAchievements.insert(id)
        self.player = player
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
        Log.economy.info("achievement claimed: \(id) (\(kind.rawValue))")
    }

    /// "Gratis" es literal: se activa por el MISMO camino que el botón de
    /// Regalos —así el regalo no reimplementa los cinco efectos— pero ignorando
    /// el cooldown vigente y sin consumirlo después. Es el premio del Médico
    /// (`grantCareerReward`), palabra por palabra.
    private func grantFreeBoost(
        id boostID: String?,
        player: inout PlayerState,
        content: GameContent,
        economy: StandardEconomy,
        now: TimeInterval
    ) {
        guard let boostID else { return }
        let previous = player.meta.boostActivations[boostID]
        player.meta.boostActivations[boostID] = nil
        do {
            _ = try BoostManager.activate(
                boostId: boostID,
                state: &player,
                config: content.boosts,
                upgrades: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                tiers: content.tiers,
                economy: economy,
                now: now
            )
            audio?.play(.buy)
        } catch {
            Log.economy.info("achievement free boost rejected: \(error)")
        }
        player.meta.boostActivations[boostID] = previous
    }

    // MARK: Toast

    /// Un piso nuevo puede cerrar tres logros de un saque. Se muestra el primero
    /// y el resto espera turno en vez de pisarse: el banner dura 2,4 s y sin cola
    /// el jugador vería uno solo y nunca sabría de los otros dos.
    private func enqueueAchievementToasts(_ achievements: [AchievementsConfig.Achievement]) {
        let toasts = achievements.map {
            AchievementToast(id: $0.id, titleText: Self.achievementText($0.titleKey), icon: $0.icon)
        }
        guard achievementToast == nil, let first = toasts.first else {
            pendingAchievementToasts.append(contentsOf: toasts)
            return
        }
        achievementToast = first
        pendingAchievementToasts.append(contentsOf: toasts.dropFirst())
    }

    /// El banner en pantalla se cerró (por toque o por vencimiento): pasa el
    /// siguiente de la cola.
    func dismissAchievementToast(id: String) {
        guard achievementToast?.id == id else { return }
        achievementToast = pendingAchievementToasts.isEmpty ? nil : pendingAchievementToasts.removeFirst()
    }

    // MARK: Proyección

    /// Los 39 logros tal como se ven, en el orden del catálogo.
    var achievementRows: [AchievementRow] {
        guard let content, let economy, let player else { return [] }
        return content.achievements.achievements.map { achievement in
            let state: AchievementRow.State
            if player.meta.claimedAchievements.contains(achievement.id) {
                state = .claimed
            } else if player.meta.unlockedAchievements.contains(achievement.id) {
                state = .unlocked
            } else {
                state = .locked
            }
            let measured = measure(achievement.trigger, player: player, content: content)
            // Conseguido es conseguido: reencarnar vacía `run` y la barra de un
            // logro de tier volvería a cero, que se leería como perdido.
            let progress = state == .locked
                ? min(1, measured.current / max(measured.target, 1))
                : 1
            return AchievementRow(
                id: achievement.id,
                titleText: Self.achievementText(achievement.titleKey),
                descText: Self.achievementText(achievement.descKey),
                icon: achievement.icon,
                state: state,
                progress: progress,
                rewardText: Self.rewardText(for: achievement.reward, player: player, content: content, economy: economy)
            )
        }
    }

    /// Qué se lleva ESTE logro, con el número puesto. La plata depende de dónde
    /// estás parado, así que no se puede escribir en la copy: sale calculada acá
    /// y la fila la muestra tal cual.
    ///
    /// ⚠️ El ORO va como `String` a propósito: una clave con `%@` interpolada con
    /// un `Int` sale en pantalla como la clave cruda (trampa 5 del HANDOFF).
    private static func rewardText(
        for reward: AchievementsConfig.Reward,
        player: PlayerState,
        content: GameContent,
        economy: StandardEconomy
    ) -> String {
        switch reward.rewardKind {
        case .coins:
            let chest = economy.passiveUnlockCost(forTier: player.run.maxTierReached) * (reward.factor ?? 0)
            return String(localized: "ach.reward.coins \(CoinFormatter.string(from: chest))")
        case .oro:
            return String(localized: "ach.reward.oro \(String(reward.amount ?? 0))")
        case .freeBoost:
            guard let boost = content.boosts.boosts.first(where: { $0.id == reward.boostId }) else { return "" }
            let name = localized(boost.displayNameKey(buildVariant: content.flags.buildVariant))
            return String(localized: "ach.reward.boost \(name)")
        case nil:
            // Inalcanzable: `validate` no deja arrancar con una reward rara.
            return ""
        }
    }

    /// Lookup de una clave del catálogo de logros. Va por `String(localized:)`
    /// con `LocalizationValue` —y no por interpolación en la vista— por la
    /// trampa 5 del HANDOFF, igual que `upgradeFlavorText`.
    private static func achievementText(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
