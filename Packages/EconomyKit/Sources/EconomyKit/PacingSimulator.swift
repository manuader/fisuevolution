import Foundation

/// Bot greedy headless que "juega" la economía completa a reloj simulado y
/// reporta tiempo-a-hito. Es el guardián del pacing (F7 §4): los targets
/// ("fase fisura ≥20-30 min, dios ≥30-50 h") se asserten en tests contra este
/// simulador — sin él es imposible saber si el juego dura 20 minutos o 50 horas.
///
/// Diseño:
/// - **Reloj por salto de evento**: entre decisiones el tiempo avanza de una
///   (`wait = (costo − coins) / rate`), así 50 h simuladas corren en milisegundos.
/// - **Modelo humano**: sesiones activas diarias (tap continuo a N taps/s) +
///   offline entre sesiones (fórmula de OfflineCalculator).
/// - **Política greedy** (prioridad): merges legales gratis → passive unlock con
///   payback corto → charUpgrade con payback corto → hire (piso 1 o backfill
///   rentable) → reencarnar cuando duplica el ORO ganado histórico → gastar el
///   ORO en mejoras permanentes.
/// - Determinístico: sin RNG (crit/golden apagados), carrera fija.
public struct PacingSimulator: Sendable {
    public struct HumanModel: Sendable {
        /// Toques por segundo sostenidos durante la sesión. **6**: el medio del
        /// rango 5-8 que un humano sostiene tapeando en ráfaga sobre el mismo
        /// personaje, que es como se juega (y el dueño tapea rápido). Los 3/s
        /// que había eran el techo conservador que F2 heredó de `balance-sim`
        /// y subestimaban el tap a la mitad, justo el verbo del que el dueño se
        /// queja. [TUNEABLE]
        public var tapsPerSecond: Double
        public var sessionSeconds: Double
        /// Offsets de inicio de sesión dentro del día (segundos desde las 0 hs).
        public var sessionStartOffsets: [Double]
        public var daySeconds: Double
        /// Cuántas veces el ORO por reencarnar tiene que superar al ORO ganado
        /// histórico para que el bot reencarne. **1 = duplicar**, la regla idle
        /// estándar y la conducta de siempre.
        ///
        /// Existe para MEDIR la pregunta del dueño ("casi nunca es worth
        /// reencarnar hasta estar muy avanzado"): con 1 el bot reencarna
        /// temprano y seguido, con un número grande se guarda hasta chocar la
        /// pared. Correr las dos y comparar el tiempo hasta maxear es el único
        /// modo honesto de contestar si reencarnar temprano CONVIENE, en vez de
        /// decidirlo por intuición. [TUNEABLE]
        public var reincarnationThresholdMultiple: Double

        public init(
            tapsPerSecond: Double = 6,
            sessionSeconds: Double = 1200,
            sessionStartOffsets: [Double] = [0, 4 * 3600, 9 * 3600, 14 * 3600],
            daySeconds: Double = 86_400,
            reincarnationThresholdMultiple: Double = 1
        ) {
            self.tapsPerSecond = tapsPerSecond
            self.sessionSeconds = sessionSeconds
            self.sessionStartOffsets = sessionStartOffsets
            self.daySeconds = daySeconds
            self.reincarnationThresholdMultiple = reincarnationThresholdMultiple
        }
    }

    public struct Report: Sendable {
        /// Tiempo ACTIVO acumulado (solo sesiones) al desbloquear cada piso.
        public var floorUnlockActiveSeconds: [String: Double] = [:]
        /// Tiempo de PARED (wall clock) al desbloquear cada piso.
        public var floorUnlockWallSeconds: [String: Double] = [:]
        /// Cuántos SEGUNDOS de income cuesta contratar el tier base de cada piso
        /// en el momento en que ese piso se abre.
        ///
        /// Es la evidencia de la divergencia costos-vs-ingresos
        /// (`Docs/PROMPT-rebalance-pacing.md` §2.3): los precios están anclados a
        /// `tapYield(tier)`, que es una constante, y el income pasa por el
        /// multiplicador global, que no tiene techo. Si la serie se desploma piso
        /// a piso, progresar es cada vez más gratis; si se mantiene, el costo
        /// sigue el ritmo del ingreso y el defecto está cerrado.
        public var floorUnlockHireSeconds: [String: Double] = [:]
        public var firstReincarnationWall: Double?
        /// Tiempo ACTIVO de CADA reencarnación, en orden. La métrica del dueño es
        /// la cadencia ("una reencarnación cada 2,5-4 h de juego activo"), y para
        /// leerla hace falta la serie entera, no sólo la primera y el total.
        public var reincarnationActiveSeconds: [Double] = []
        public var godWall: Double?
        public var reincarnations = 0
        /// Segundos ACTIVOS hasta tener las siete líneas permanentes al tope.
        public var maxedUpgradesActiveSeconds: Double?
        public var maxedUpgradesWall: Double?
        public var reincarnationsAtMaxedUpgrades: Int?
        public var finalPermanentUpgradeLevels: [String: Int] = [:]
        public var finalLifetimeEarnings: Double = 0
        public var finalMaxTier = 0

        /// Tiempo ACTIVO de la primera reencarnación (la de pared es
        /// `firstReincarnationWall`). El dueño mide en horas de dedo, no de
        /// calendario.
        public var firstReincarnationActive: Double? { reincarnationActiveSeconds.first }

        public init() {}
    }

    let config: EconomyConfig
    let tiers: TierRepository
    let floorTable: FloorTable
    let economy: StandardEconomy
    let human: HumanModel
    /// Payback máximo aceptado para compras de eficiencia (passive/charUpgrade).
    let maxPaybackSeconds: Double
    let careerPath: String
    /// Catálogo de mejoras permanentes que el bot puede comprar con ORO. Vacío
    /// = el bot no compra ninguna, que es el modelo viejo. [TUNEABLE]
    let permanentUpgrades: [PermanentUpgradeLine]

    public init(
        config: EconomyConfig,
        tiers: TierRepository,
        human: HumanModel = HumanModel(),
        maxPaybackSeconds: Double = 1800,
        careerPath: String = "programmer",
        upgrades: [PermanentUpgradeLine] = []
    ) throws {
        self.config = config
        self.tiers = tiers
        self.floorTable = try FloorTable(floors: config.floors, maxTier: tiers.maxTier)
        self.economy = StandardEconomy(config: config)
        self.human = human
        self.maxPaybackSeconds = maxPaybackSeconds
        self.careerPath = careerPath
        self.permanentUpgrades = upgrades
    }

    // MARK: - Run

    public func run(maxDays: Int = 90) -> Report {
        var report = Report()
        var state = PlayerState.newGame(
            startTypeId: tiers.baseType.id,
            startFloorId: floorTable[0].id,
            offlineEfficiencyBase: config.offlineEfficiencyBase,
            critChanceBase: config.critChanceBase,
            now: 0
        )
        var wall = 0.0
        var activeTotal = 0.0
        recordUnlocks(state: &state, report: &report, wall: wall, active: activeTotal)

        let horizon = Double(maxDays) * human.daySeconds
        while wall < horizon {
            let dayStart = (wall / human.daySeconds).rounded(.down) * human.daySeconds
            var sessionRan = false
            for offset in human.sessionStartOffsets.sorted() {
                let sessionStart = dayStart + offset
                guard sessionStart >= wall else { continue }
                // Offline hasta el inicio de la sesión.
                applyOffline(state: &state, elapsed: sessionStart - wall)
                wall = sessionStart
                // Sesión activa.
                let consumed = playSession(
                    state: &state,
                    report: &report,
                    wallStart: wall,
                    activeStart: activeTotal
                )
                wall += consumed.wall
                activeTotal += consumed.active
                sessionRan = true
                if report.godWall != nil { break }
            }
            if report.godWall != nil { break }
            if !sessionRan {
                // Ya pasaron todas las sesiones de hoy: dormir hasta mañana.
                let nextDay = dayStart + human.daySeconds + (human.sessionStartOffsets.min() ?? 0)
                applyOffline(state: &state, elapsed: nextDay - wall)
                wall = nextDay
            } else {
                // Gap final del día → primera sesión de mañana.
                let nextDay = dayStart + human.daySeconds + (human.sessionStartOffsets.min() ?? 0)
                if nextDay > wall {
                    applyOffline(state: &state, elapsed: nextDay - wall)
                    wall = nextDay
                }
            }
        }

        report.finalLifetimeEarnings = state.meta.lifetimeEarnings
        report.finalMaxTier = state.run.maxTierReached
        report.finalPermanentUpgradeLevels = state.meta.oroUpgradeLevels
        return report
    }

    // MARK: - Sesión activa

    /// Juega una sesión. Devuelve (wall consumido, activo consumido) — iguales
    /// salvo terminación temprana por dios.
    private func playSession(
        state: inout PlayerState,
        report: inout Report,
        wallStart: Double,
        activeStart: Double
    ) -> (wall: Double, active: Double) {
        var elapsed = 0.0
        while elapsed < human.sessionSeconds {
            doAllMerges(state: &state, report: &report, wall: wallStart + elapsed, active: activeStart + elapsed)
            if state.run.maxTierReached >= tiers.maxTier, report.godWall == nil {
                report.godWall = wallStart + elapsed
                return (elapsed, elapsed)
            }
            maybeReincarnate(
                state: &state, report: &report,
                wall: wallStart + elapsed, active: activeStart + elapsed
            )

            let rate = incomeRate(state: state, active: true)
            guard rate > 0 else {
                // Sin income (imposible en la práctica): quemar la sesión.
                elapsed = human.sessionSeconds
                break
            }

            guard let action = nextAction(state: state) else {
                // Nada que comprar: acumular hasta el fin de la sesión.
                let remaining = human.sessionSeconds - elapsed
                earn(state: &state, amount: rate * remaining)
                elapsed = human.sessionSeconds
                break
            }

            let wait = max(0, (action.cost - state.run.coins) / rate)
            if elapsed + wait >= human.sessionSeconds {
                let remaining = human.sessionSeconds - elapsed
                earn(state: &state, amount: rate * remaining)
                elapsed = human.sessionSeconds
                break
            }
            earn(state: &state, amount: rate * wait)
            elapsed += wait + 1  // +1 s de "manipulación"
            action.perform(&state)
            recordUnlocks(state: &state, report: &report, wall: wallStart + elapsed, active: activeStart + elapsed)
        }
        return (elapsed, elapsed)
    }

    // MARK: - Acciones

    private struct Action {
        let cost: Double
        let perform: (inout PlayerState) -> Void
    }

    /// La próxima compra deseable más barata (la espera la decide el caller).
    private func nextAction(state: PlayerState) -> Action? {
        var candidates: [Action] = []
        let passiveRate = passivePerSecond(state: state)

        // 1. Passive unlocks con payback corto (o el primero del tipo base, siempre).
        for (typeId, count) in state.run.units where count > 0 && state.run.passiveUnlocked[typeId] != true {
            guard let type = tiers.type(id: typeId) else { continue }
            let gain = type.passiveYieldPerInstance * Double(count)
                * CharUpgrades.multiplier(typeId: typeId, levels: state.run.charUpgradeLevels, config: config)
                * floorTable.floor(forTier: type.tier).incomeMultiplier
                * state.meta.globalMultiplier
            guard gain > 0 else { continue }
            if type.passiveUnlockCost / gain <= maxPaybackSeconds {
                candidates.append(Action(cost: type.passiveUnlockCost) { s in
                    s.run.coins -= type.passiveUnlockCost
                    s.run.passiveUnlocked[typeId] = true
                })
            }
        }

        // 2. CharUpgrade del tipo que más aporta, payback corto. El costo en
        // `nil` es el tipo al tope: el bot no tiene esa jugada, igual que el
        // jugador.
        if let best = state.run.units.keys
            .compactMap({ tiers.type(id: $0) })
            .filter({ state.run.passiveUnlocked[$0.id] == true })
            .max(by: { contribution(of: $0, state: state) < contribution(of: $1, state: state) }),
           let cost = CharUpgrades.nextLevelCost(type: best, levels: state.run.charUpgradeLevels, config: config, economy: economy) {
            let currentContribution = contribution(of: best, state: state)
            let gain = currentContribution * (config.charUpgrades.effectFactorPerLevel - 1)
            if gain > 0, cost / gain <= maxPaybackSeconds {
                candidates.append(Action(cost: cost) { s in
                    s.run.coins -= cost
                    s.run.charUpgradeLevels[best.id, default: 0] += 1
                })
            }
        }

        // 3. Hire piso 1 (motor del early game) si hay lugar.
        if let hire = hireAction(floorOrdinal: 0, state: state, requireProfit: false, passiveRate: passiveRate) {
            candidates.append(hire)
        }

        // 4. Backfill: hire en pisos superiores desbloqueados SOLO si es rentable
        //    (precio punitivo: recién conviene con la frontera pisos arriba).
        //    El gate del piso de arriba sale de `TowerActions.canHire`, la
        //    MISMA función que usa el juego: si acá se copiara la condición, el
        //    simulador podría modelar un jugador que hace algo que el juego no
        //    permite.
        for ordinal in 1..<floorTable.count
        where state.run.unlockedFloors.contains(floorTable[ordinal].id)
            && TowerActions.canHire(
                floorOrdinal: ordinal,
                unlockedFloors: state.run.unlockedFloors,
                floorTable: floorTable
            ) {
            if let hire = hireAction(floorOrdinal: ordinal, state: state, requireProfit: true, passiveRate: passiveRate) {
                candidates.append(hire)
            }
        }

        return candidates.min { $0.cost < $1.cost }
    }

    /// El bot compra SIEMPRE el tier base del piso —comprar más arriba nunca le
    /// conviene, que es justo lo que `tierPremium` garantiza (§5.2)— pero cotiza
    /// por el camino real: `TowerActions.hireQuote(typeId:)`, la misma función
    /// que la pantalla de laburos. Antes armaba el precio con `config.hireCost`
    /// por su cuenta, y ese es exactamente el modo en que el simulador y el juego
    /// se desincronizaron una vez.
    ///
    /// Lo que sí sigue haciendo a mano es la MUTACIÓN: `TowerActions.hire` pide
    /// un `TowerState` con slots, y el simulador no lo mantiene (deriva la
    /// ocupación de `run.units`). Por eso replica los dos contadores que la curva
    /// necesita —el del piso y el del TIPO—: si se olvidara del segundo, cotizaría
    /// siempre el precio de la primera compra.
    private func hireAction(floorOrdinal: Int, state: PlayerState, requireProfit: Bool, passiveRate: Double) -> Action? {
        let floor = floorTable[floorOrdinal]
        guard floorCount(floorOrdinal, state: state) < floor.capacity else { return nil }
        let candidates = tiers.concreteTypes.filter { $0.tier == floor.firstTier }
        guard let type = candidates.first(where: { $0.id.hasSuffix(careerPath) }) ?? candidates.sorted(by: { $0.id < $1.id }).first
        else { return nil }
        // `now: 0` alcanza: el bot no tiene modificadores temporales ni descuento
        // permanente de prestigio, así que los dos factores valen 1.
        guard let quote = TowerActions.hireQuote(
            typeId: type.id, state: state, config: config,
            floorTable: floorTable, tiers: tiers
        ) else { return nil }
        let cost = quote.cost

        if requireProfit {
            // Política del plan (§F7.1c): backfill si es BARATO relativo al wallet
            // (<25% — material de merge: empuja la frontera aunque su passive no
            // pague) O si su payback propio es corto.
            let cheapForWallet = cost <= state.run.coins * 0.25
            if !cheapForWallet {
                // Payback de la unidad nueva (con su passive ya desbloqueado o no).
                let unlocked = state.run.passiveUnlocked[type.id] == true
                let gain = (unlocked ? type.passiveYieldPerInstance : type.passiveYieldPerInstance * 0.5)
                    * CharUpgrades.multiplier(typeId: type.id, levels: state.run.charUpgradeLevels, config: config)
                    * floor.incomeMultiplier
                    * state.meta.globalMultiplier
                guard gain > 0, cost / gain <= maxPaybackSeconds else { return nil }
            }
        }

        let floorId = floor.id
        let typeId = type.id
        return Action(cost: cost) { s in
            s.run.coins -= cost
            s.run.hireCounts[floorId, default: 0] += 1
            s.run.hireCountsByType[typeId, default: 0] += 1
            s.run.units[typeId, default: 0] += 1
        }
    }

    // MARK: - Merges

    /// Aplica todos los merges legales (greedy, del tier más alto hacia abajo),
    /// respetando capacidad del piso destino. Elige carrera fija al primer fork.
    private func doAllMerges(state: inout PlayerState, report: inout Report, wall: Double, active: Double) {
        var merged = true
        while merged {
            merged = false
            let mergeables = state.run.units
                .filter { $0.value >= 2 }
                .compactMap { typeId, _ in tiers.type(id: typeId) }
                .sorted { $0.tier > $1.tier }
            for type in mergeables {
                var outcome = MergeRules.evaluate(
                    sourceTypeId: type.id, targetTypeId: type.id,
                    chosenCareerPath: state.run.chosenCareerPath, tiers: tiers
                )
                if case .requiresCareerChoice = outcome {
                    state.run.chosenCareerPath = careerPath
                    outcome = MergeRules.evaluate(
                        sourceTypeId: type.id, targetTypeId: type.id,
                        chosenCareerPath: careerPath, tiers: tiers
                    )
                }
                guard case .merged(let newTypeId) = outcome,
                      let newType = tiers.type(id: newTypeId) else { continue }
                // Capacidad del piso destino (si cruza de piso).
                let destOrdinal = floorTable.ordinal(forTier: newType.tier)
                let srcOrdinal = floorTable.ordinal(forTier: type.tier)
                if destOrdinal != srcOrdinal, floorCount(destOrdinal, state: state) >= floorTable[destOrdinal].capacity {
                    continue
                }
                state.run.units[type.id, default: 0] -= 2
                if state.run.units[type.id] == 0 { state.run.units[type.id] = nil }
                state.run.units[newTypeId, default: 0] += 1
                state.run.maxTierReached = max(state.run.maxTierReached, newType.tier)
                merged = true
                recordUnlocks(state: &state, report: &report, wall: wall, active: active)
                break
            }
        }
    }

    // MARK: - Reencarnación

    private func maybeReincarnate(state: inout PlayerState, report: inout Report, wall: Double, active: Double) {
        let gained = PrestigeCalculator.oroGained(state: state, economy: economy)
        // Regla idle estándar: reencarnar cuando al menos DUPLICA lo ganado
        // histórico (`reincarnationThresholdMultiple` = 1). La cuenta va en
        // Double a propósito: `oroEarnedLifetime` llega a órdenes en los que
        // multiplicarlo en Int desborda, y un desborde acá sería un crash en
        // mitad de una calibración.
        let threshold = max(1, Double(state.meta.oroEarnedLifetime) * human.reincarnationThresholdMultiple)
        guard Double(gained) >= threshold else { return }
        PrestigeCalculator.applyReincarnation(state: &state, economy: economy, tiers: tiers, floorTable: floorTable, now: wall)
        report.reincarnations += 1
        report.reincarnationActiveSeconds.append(active)
        if report.firstReincarnationWall == nil { report.firstReincarnationWall = wall }
        buyPermanentUpgrades(state: &state, report: &report, wall: wall, active: active)
    }

    // MARK: - Mejoras permanentes (ORO)

    /// Gasta el ORO en mejoras permanentes: **la más barata primero**, hasta que
    /// no alcance para ninguna.
    ///
    /// Es la política del jugador que va por las skins doradas, que es el
    /// objetivo que el dueño llama "ganarlo al máximo": para maxear las siete
    /// líneas hay que comprar TODOS los niveles igual, así que lo único que se
    /// elige es el orden — y comprar de menor a mayor precio es el que más
    /// niveles pone en juego por ORO gastado y el que menos tiempo deja el ORO
    /// quieto en el bolsillo. La alternativa ("la de mejor payback") sólo
    /// tendría sentido si el jugador pudiera saltearse líneas, y no puede.
    ///
    /// Se llama sólo al reencarnar porque es el único momento en que entra ORO:
    /// entre reencarnaciones el saldo no cambia y los precios tampoco, así que
    /// lo que no alcanzó acá no va a alcanzar después.
    ///
    /// ⚠️ El bot **paga** `crit` y `golden` pero no cobra su efecto: el
    /// simulador es determinístico y no tira dados. Como `crit` es hoy el
    /// 99,99 % del costo de maxear, eso lo vuelve un techo pesimista —el
    /// jugador real, con los mismos niveles, gana más—.
    private func buyPermanentUpgrades(state: inout PlayerState, report: inout Report, wall: Double, active: Double) {
        guard !permanentUpgrades.isEmpty else { return }
        var bought = false
        while let line = cheapestAffordableUpgrade(state: state) {
            let level = state.meta.oroUpgradeLevels[line.id] ?? 0
            state.meta.oro -= oroPrice(of: line, atLevel: level)
            state.meta.oroUpgradeLevels[line.id] = level + 1
            bought = true
        }
        guard bought else { return }
        // Recalcula efectos (y el multiplicador global, que depende del
        // `prestigeBonus` recién comprado) con la misma fórmula que la app.
        PermanentUpgrades.recomputeDerivedEffects(state: &state, lines: permanentUpgrades, economy: economy)
        guard report.maxedUpgradesActiveSeconds == nil,
              PermanentUpgrades.allMaxed(levels: state.meta.oroUpgradeLevels, lines: permanentUpgrades)
        else { return }
        report.maxedUpgradesActiveSeconds = active
        report.maxedUpgradesWall = wall
        report.reincarnationsAtMaxedUpgrades = report.reincarnations
    }

    /// La línea no-maxeada más barata que el ORO alcanza. Empates por `id`, para
    /// que la corrida siga siendo determinística.
    private func cheapestAffordableUpgrade(state: PlayerState) -> PermanentUpgradeLine? {
        permanentUpgrades
            .filter { line in
                let level = state.meta.oroUpgradeLevels[line.id] ?? 0
                guard level < line.maxLevel else { return false }
                return oroPrice(of: line, atLevel: level) <= state.meta.oro
            }
            .min { lhs, rhs in
                let lhsCost = lhs.cost(atLevel: state.meta.oroUpgradeLevels[lhs.id] ?? 0)
                let rhsCost = rhs.cost(atLevel: state.meta.oroUpgradeLevels[rhs.id] ?? 0)
                return lhsCost == rhsCost ? lhs.id < rhs.id : lhsCost < rhsCost
            }
    }

    /// Precio en ORO, entero y redondeado para arriba como en la app
    /// (`UpgradeManager.purchase`), pero **clampeado**: `Int(_:)` sobre un Double
    /// de 2^63 o más CRASHEA, y estos catálogos se calibran a mano. Una línea
    /// que se pase de ese orden queda simplemente impagable y el reporte la
    /// muestra trabada en su nivel, que es lo que hay que ver.
    private func oroPrice(of line: PermanentUpgradeLine, atLevel level: Int) -> Int {
        StandardEconomy.clampedFloor(line.cost(atLevel: level).rounded(.up))
    }

    // MARK: - Income

    private func passivePerSecond(state: PlayerState) -> Double {
        var total = 0.0
        for (typeId, count) in state.run.units where state.run.passiveUnlocked[typeId] == true {
            guard count > 0, let type = tiers.type(id: typeId) else { continue }
            total += type.passiveYieldPerInstance * Double(count)
                * CharUpgrades.multiplier(typeId: typeId, levels: state.run.charUpgradeLevels, config: config)
                * floorTable.floor(forTier: type.tier).incomeMultiplier
        }
        return total * state.meta.globalMultiplier * state.meta.derivedEffects.incomeMultiplier
    }

    /// Aporte de un tipo al passive (para elegir el mejor charUpgrade).
    private func contribution(of type: CharacterType, state: PlayerState) -> Double {
        let count = state.run.units[type.id] ?? 0
        guard count > 0 else { return 0 }
        return type.passiveYieldPerInstance * Double(count)
            * CharUpgrades.multiplier(typeId: type.id, levels: state.run.charUpgradeLevels, config: config)
            * floorTable.floor(forTier: type.tier).incomeMultiplier
            * state.meta.globalMultiplier
    }

    /// Income durante juego activo: passive + taps sobre la mejor unidad.
    private func incomeRate(state: PlayerState, active: Bool) -> Double {
        var rate = passivePerSecond(state: state)
        if active {
            let bestTap = state.run.units.keys
                .compactMap { tiers.type(id: $0) }
                .map { type in
                    type.tapYield
                        * CharUpgrades.multiplier(typeId: type.id, levels: state.run.charUpgradeLevels, config: config)
                        * config.tapFloorMultiplier(for: floorTable.floor(forTier: type.tier))
                }
                .max() ?? 0
            // Los mismos factores que `GameActions.applyTap`, incluido el
            // `incomeMultiplier` que al bot le faltaba: el tap del juego lo
            // lleva, así que sin él el simulador cobraba de menos cada toque. El
            // de piso pasa por `tapFloorMultiplier` por el mismo motivo: si acá
            // se leyera `incomeMultiplier` crudo, el bot cobraría un tap que el
            // juego ya no paga.
            rate += bestTap * human.tapsPerSecond
                * state.meta.derivedEffects.tapMultiplier
                * state.meta.derivedEffects.incomeMultiplier
                * state.meta.globalMultiplier
        }
        return rate
    }

    private func earn(state: inout PlayerState, amount: Double) {
        guard amount > 0 else { return }
        state.run.coins += amount
        state.meta.lifetimeEarnings += amount
    }

    private func applyOffline(state: inout PlayerState, elapsed: Double) {
        guard elapsed > 0 else { return }
        let capped = min(elapsed, config.offlineCapHours * 3600)
        let amount = capped * passivePerSecond(state: state) * state.meta.derivedEffects.offlineEfficiency
        earn(state: &state, amount: amount)
    }

    // MARK: - Helpers

    private func floorCount(_ ordinal: Int, state: PlayerState) -> Int {
        let floor = floorTable[ordinal]
        return state.run.units.reduce(0) { acc, entry in
            guard let type = tiers.type(id: entry.key), floor.contains(tier: type.tier) else { return acc }
            return acc + entry.value
        }
    }

    /// Cuántos segundos de income cuesta el PRIMER hire del tier base del piso.
    /// Cotiza por `config.hireCost` —sin descuentos ni modificadores, que el bot
    /// no tiene— y divide por el income de juego activo, que es el que el jugador
    /// tiene en la mano cuando abre el piso.
    private func hireSeconds(floor: FloorDef, state: PlayerState) -> Double {
        let rate = incomeRate(state: state, active: true)
        guard rate > 0 else { return .infinity }
        return config.hireCost(floor: floor, tier: floor.firstTier, purchases: 0) / rate
    }

    /// Registra pisos recién alcanzados (unlockTier ≤ maxTier) con sus tiempos.
    private func recordUnlocks(state: inout PlayerState, report: inout Report, wall: Double, active: Double) {
        for floor in floorTable.floors where state.run.maxTierReached >= floor.unlockTier {
            if !state.run.unlockedFloors.contains(floor.id) {
                state.run.unlockedFloors.append(floor.id)
            }
            if report.floorUnlockWallSeconds[floor.id] == nil {
                report.floorUnlockWallSeconds[floor.id] = wall
                report.floorUnlockActiveSeconds[floor.id] = active
                report.floorUnlockHireSeconds[floor.id] = hireSeconds(floor: floor, state: state)
            }
        }
    }
}
