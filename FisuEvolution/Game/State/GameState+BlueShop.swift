import EconomyKit
import Foundation

/// Una fila de la tienda de blue, ya cotizada: la vista no le pregunta nada más al estado.
struct BlueShopRow: Identifiable, Equatable {
    let item: BlueShopCatalog.Item
    let quote: BlueShop.Quote

    var id: String { item.id }
}

enum BlueShopOutcome: Equatable {
    case bought
    case refused(BlueShop.Blocker)
    /// No se ofrece (tienda restringida, nada que entregar, sin contenido).
    case unavailable
}

/// La tienda de blue en la partida (PLAN-v2 E6): comprar, los ×3 comprados que
/// esperan su momento y el auto-tap.
extension GameState {
    /// El ícono animado de la tienda cambió de fila: un brillo, muy bajo.
    func shopIconFocused() {
        audio?.play(.shopShimmer, gain: .ambient)
    }

    /// Lo que la tienda necesita saber de la partida, resuelto acá. `chanceAllowed`
    /// lo pone quien llama (`LootBoxGate`), para que un test no dependa del país
    /// de la máquina.
    func blueShopContext(chanceAllowed: Bool, now: Date = Date()) -> BlueShop.Context? {
        guard let content, let player, let tower else { return nil }
        let reached = Set(content.floorTable.floors.prefix(player.meta.stats.maxFloorOrdinalEver + 1).map(\.id))
        let pairs = mergeAllIsQueued ? 0 : BoardChangePlanner.planMergeAll(
            floorOrdinal: visibleFloorOrdinal, state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy, origin: .blueShop
        ).count
        let seconds = now.timeIntervalSince1970
        let coolingDown = content.boosts.boosts.contains {
            BoostManager.cooldownRemaining(of: $0, state: player, now: seconds) > 0
        }
        var perks: Set<BlueShopCatalog.Perk> = [.extraSlots]
        if Self.grantableRewardKinds.contains(.package) { perks.insert(.bestSupplier) }
        if Self.grantableRewardKinds.contains(.wheelSpin) { perks.insert(.wheelDailySpins) }
        return BlueShop.Context(
            today: DailyRewardManager.dayString(for: now, calendar: Self.gregorianCalendar),
            grantableKinds: Self.grantableRewardKinds,
            chanceAllowed: chanceAllowed,
            reachedFloorIds: reached,
            mergeAllPairs: pairs,
            anyBoostCoolingDown: coolingDown,
            chestHasSomethingToGive: chestHasSomethingToGive(player: player, content: content),
            supportedPerks: perks
        )
    }

    /// ¿Un cofre más tiene qué dar? Los que ya esperan (`pendingChestCount`)
    /// van a quedarse con las pintas que hoy faltan: con una sola pinta alcanzable
    /// y un cofre guardado, otro cofre pagaría plata. Con la colección completa
    /// el cofre paga plata a propósito y sigue siendo comprable.
    private func chestHasSomethingToGive(player: PlayerState, content: GameContent) -> Bool {
        let owned = player.meta.allOwnedSkins
        let unlocked = chestUnlockedCharacterTypes
        guard ChestRoller.hasSomethingToGive(owned: owned, unlocked: unlocked, skins: content.skins) else { return false }
        let reachable = ChestRoller.reachableSkinCount(owned: owned, unlocked: unlocked, skins: content.skins)
        return reachable == 0 || reachable > pendingChestCount
    }

    /// Las probabilidades del cofre de pintas para ESTE jugador (Apple 3.1.1): la
    /// tabla que sortea `ChestRoller.roll`, con su colección y su desbloqueo de hoy.
    var chestOdds: ChestOddsTable {
        guard let content, let player else { return .nothingYet }
        return ChestRoller.effectiveOdds(
            owned: player.meta.allOwnedSkins, unlocked: chestUnlockedCharacterTypes,
            skins: content.skins, config: content.chests
        )
    }

    /// El día de los topes y de las ofertas, siempre en calendario gregoriano (nunca `Calendar.current`).
    static let gregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    /// Las filas de la tienda, en el orden del catálogo y ya cotizadas.
    func blueShopRows(chanceAllowed: Bool, now: Date = Date()) -> [BlueShopRow] {
        guard let content, let player, let context = blueShopContext(chanceAllowed: chanceAllowed, now: now) else { return [] }
        return BlueShop.visibleItems(catalog: content.blueShop, context: context).filter(Self.canDeliver).map {
            BlueShopRow(item: $0, quote: BlueShop.quote($0, state: player, context: context))
        }
    }

    /// Compra un ítem: cobra por `BlueShop.purchase` (`spendBlue`, la única salida
    /// de blue) y entrega en el mismo paso, sobre la misma partida en memoria: o
    /// quedan las dos cosas o ninguna. Lo que no se puede aplicar no se cobra, y
    /// una segunda llamada ve el tope, el nivel o el pendiente de la primera.
    @discardableResult
    func buyBlueShopItem(id: String, chanceAllowed: Bool, now: Date = Date()) -> BlueShopOutcome {
        guard let content, let before = player,
              let context = blueShopContext(chanceAllowed: chanceAllowed, now: now),
              let item = content.blueShop.item(id: id), Self.canDeliver(item)
        else { return .unavailable }
        var charged = before
        let purchase: BlueShop.Purchase
        do {
            purchase = try BlueShop.purchase(id, state: &charged, catalog: content.blueShop, context: context)
        } catch BlueShop.PurchaseError.blocked(let blocker) {
            return .refused(blocker)
        } catch {
            return .unavailable
        }
        player = charged
        if item.action == .mergeAll, enqueueMergeAll(onFloor: visibleFloorOrdinal, origin: .blueShop) == 0 {
            player = before
            return .refused(.nothingToDo)
        }
        if item.perk == .extraSlots { growTowerToTheExtraSlots() }
        if !item.rewards.isEmpty {
            let coins = grant(item.rewards, source: "shop.\(id)", now: now.timeIntervalSince1970)
            announceReward(item.rewards, coins: coins)
        }
        effectsVersion += 1
        audio?.play(.coin)
        refreshProjections()
        saveTask?.cancel()
        saveTask = nil
        Task { await persistNow() }
        Log.economy.info("blue shop: \(id) for \(purchase.price) blue")
        return .bought
    }

    /// Los lugares comprados agrandan la torre que está en pantalla SIN
    /// reconstruirla desde `run.units`: el reconciliador compacta los slots, y
    /// eso movería a la gente y dejaría inválido el cambio que la escena está
    /// jugando (un video ya visto se perdería). Cada piso conserva sus slots y
    /// suma los vacíos del final.
    private func growTowerToTheExtraSlots() {
        applyExtraSlots()
        guard let content, let current = tower else { return }
        var grown = TowerState(floorTable: content.floorTable)
        for index in current.floors.indices where grown.floors.indices.contains(index) {
            let slots = current.floors[index].slots.prefix(grown.floors[index].slots.count)
            grown.floors[index].slots.replaceSubrange(slots.indices, with: slots)
        }
        tower = grown
        boardVersion += 1
    }

    /// Un ítem con un premio mal formado (magnitud o duración que no rinden, un
    /// ×3 que no multiplica) no se vende: mejor que no se cobre a que no entregue.
    private static func canDeliver(_ item: BlueShopCatalog.Item) -> Bool {
        item.rewards.allSatisfy { reward in
            guard (try? reward.validate()) != nil else { return false }
            switch reward {
            case .modifier(_, let magnitude, _): return magnitude.isFinite && magnitude > 1
            case .nextOfflineMultiplier(let multiplier), .nextDailyMultiplier(let multiplier):
                return multiplier.isFinite && multiplier > 1
            default: return true
            }
        }
    }

    /// El nivel de "mejor proveedor" (0 sin comprar). El `r` de cada nivel es
    /// dato de E5 (`packages.json`); `openPackage()` lo lee de acá.
    var bestSupplierLevel: Int {
        guard let content, let player else { return 0 }
        return BlueShop.bestSupplierLevel(levels: player.meta.engagement.shop.levels, catalog: content.blueShop)
    }

    /// Los giros por video de más por día del "abono a la ruleta".
    var bonusDailyWheelSpins: Int {
        guard let content, let player else { return 0 }
        return BlueShop.bonusDailyWheelSpins(levels: player.meta.engagement.shop.levels, catalog: content.blueShop)
    }

    /// La ruleta con el abono aplicado: el ÚNICO lugar donde el cupo de giros por
    /// video crece. `wheelAvailability` y `spinWheel` cuentan contra ésta.
    var effectiveWheel: WheelConfig? {
        content.map { $0.wheel.withBonusVideoSpins(bonusDailyWheelSpins) }
    }

    /// El Offline ×3 comprado multiplica la vuelta que muestra el popup y se
    /// consume ahí. Una ausencia corta, que se acredita en silencio, no lo gasta:
    /// el jugador lo compró para ver el número grande.
    func applyPendingOfflineMultiplier(to amount: Double) -> Double {
        guard amount > 0, var player, let multiplier = player.meta.engagement.shop.pendingOfflineMultiplier else {
            return amount
        }
        let extra = amount * (multiplier - 1)
        player.run.coins += extra
        player.meta.lifetimeEarnings += extra
        player.meta.engagement.shop.pendingOfflineMultiplier = nil
        self.player = player
        Log.economy.info("offline ×\(multiplier) from the blue shop: +\(extra)")
        return amount + extra
    }

    /// El Diario ×3 multiplica la plata del próximo diario. Un día que da un
    /// especial o un cofre no lo gasta: espera al que pague plata.
    func applyPendingDailyMultiplier(to claim: DailyRewardManager.Claim) -> DailyRewardManager.Claim {
        guard claim.coinsGranted > 0, var player,
              let multiplier = player.meta.engagement.shop.pendingDailyMultiplier
        else { return claim }
        let extra = claim.coinsGranted * (multiplier - 1)
        player.run.coins += extra
        player.meta.lifetimeEarnings += extra
        player.meta.engagement.shop.pendingDailyMultiplier = nil
        self.player = player
        return DailyRewardManager.Claim(
            day: claim.day,
            coinsGranted: claim.coinsGranted + extra,
            specialGranted: claim.specialGranted,
            chestGranted: claim.chestGranted
        )
    }

    /// Los toques automáticos. Lo llama `advanceEngagement` con el delta del tick
    /// (juego activo, con tope de 2 s). No espera a `engagementAutorun`: es un
    /// efecto que el jugador compró, no un motor que aparece solo.
    func advanceAutoTap(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, let economy, var player else { return }
        let paid = AutoTapper.advance(
            state: &player, delta: delta, now: now,
            tiers: content.tiers, floorTable: content.floorTable, economy: economy
        )
        guard paid > 0 else { return }
        self.player = player
    }
}
