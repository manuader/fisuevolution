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
///   rentable) → reencarnar según `HumanModel.reincarnation` (por defecto, al
///   duplicar el ORO ganado histórico) → gastar el ORO en mejoras permanentes.
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
        /// Segundos que le cuesta al jugador **una compra**: buscar la fila,
        /// tocarla, ver la confirmación. Era un `+ 1` literal adentro del loop de
        /// sesión y ahora es un knob, porque la cuarta ronda midió que este
        /// número es la MITAD del tiempo activo de la partida y un número así no
        /// puede estar escondido. [TUNEABLE]
        public var hireSeconds: Double
        /// Segundos que le cuesta al jugador **una fusión**.
        ///
        /// ⚠️ **Valía CERO hasta el 2026-08-23, y era un sesgo, no una
        /// simplificación.** Fusionar es el verbo central del juego —se arrastra
        /// o se toca dos veces, una acción por fusión— y para subir un tier de
        /// frontera hacen falta `2^N − 1` fusiones. Con el merge gratis el
        /// instrumento medía a un jugador que compra con el dedo y fusiona con la
        /// mente, y todo lo que dependiera de la proporción compras/fusiones
        /// —cualquier cambio en la compuerta, y cualquier idea de comprar de a
        /// varias— salía medido mal.
        ///
        /// ⚠️⚠️ **Acá se corta la comparación con las bandas históricas de esta
        /// rama.** Todo número anterior al 2026-08-23 se midió con esto en cero.
        /// [TUNEABLE]
        public var mergeSeconds: Double
        /// Offsets de inicio de sesión dentro del día (segundos desde las 0 hs).
        public var sessionStartOffsets: [Double]
        public var daySeconds: Double
        /// Cuándo reencarna el bot. [TUNEABLE]
        public var reincarnation: ReincarnationPolicy

        public init(
            tapsPerSecond: Double = 6,
            sessionSeconds: Double = 1200,
            hireSeconds: Double = 1,
            mergeSeconds: Double = 1,
            sessionStartOffsets: [Double] = [0, 4 * 3600, 9 * 3600, 14 * 3600],
            daySeconds: Double = 86_400,
            reincarnation: ReincarnationPolicy = .whenOroMultiplies(1)
        ) {
            self.tapsPerSecond = tapsPerSecond
            self.sessionSeconds = sessionSeconds
            self.hireSeconds = hireSeconds
            self.mergeSeconds = mergeSeconds
            self.sessionStartOffsets = sessionStartOffsets
            self.daySeconds = daySeconds
            self.reincarnation = reincarnation
        }
    }

    /// Cuándo reencarna el bot: las dos políticas que la calibración necesita
    /// poder correr.
    ///
    /// Es un enum y no un Double con valores mágicos porque las dos preguntas
    /// del dueño **no viven en la misma escala**. "¿Conviene guardarse las
    /// reencarnaciones?" se contesta subiendo el múltiplo; "¿cuánto tarda el que
    /// NO reencarna nunca?" no se puede contestar con ningún múltiplo, por chico
    /// o grande que sea: el umbral se calcula sobre el ORO ganado histórico, que
    /// arranca en CERO, y `N × 0 = 0` para cualquier `N`. Con un Double la
    /// política "nunca" quedaba inexpresable y el bug era silencioso —parecía
    /// que un umbral gigante alcanzaba—.
    public enum ReincarnationPolicy: Sendable, Equatable {
        /// Reencarnar cuando el ORO por reencarnar supere `multiple` veces el
        /// ORO ganado histórico. **1 = duplicar**, la regla idle estándar y la
        /// conducta de siempre.
        case whenOroMultiplies(Double)
        /// No reencarnar nunca. Es el jugador de la queja del dueño del
        /// 2026-08-22 ("llegué de fisura a dios sin reiniciar"): sin ORO no
        /// compra ninguna mejora permanente y sube la torre sólo con la plata de
        /// la run.
        case never
    }

    public struct Report: Sendable {
        /// Tiempo ACTIVO acumulado (solo sesiones) al desbloquear cada piso.
        public var floorUnlockActiveSeconds: [String: Double] = [:]
        /// Tiempo de PARED (wall clock) al desbloquear cada piso.
        public var floorUnlockWallSeconds: [String: Double] = [:]
        /// Cuántos SEGUNDOS de income cuesta ENTRAR a cada piso: el próximo hire
        /// de su tier base, al contador de compras que el bot tiene de ese tipo,
        /// en el momento en que el piso se abre.
        ///
        /// Es la evidencia de la divergencia costos-vs-ingresos
        /// (`Docs/PROMPT-rebalance-pacing.md` §2.3): los precios están anclados a
        /// `tapYield(tier)`, que es una constante, y el income pasa por el
        /// multiplicador global, que no tiene techo. Si la serie se desploma piso
        /// a piso, progresar es cada vez más gratis.
        ///
        /// ⚠️ **Lo que esta serie NO puede medir es `hireCostGrowth`**: un piso
        /// se abre mergeando hacia arriba, no comprando, así que el contador de
        /// su tier base suele valer 0 al abrirlo y `growth^0 = 1`. Para el
        /// compounding están las dos series de abajo.
        public var floorUnlockHireSeconds: [String: Double] = [:]
        /// El tipo MÁS COMPRADO de la run cuando cada piso se abrió, su contador
        /// y lo que cuesta el próximo de ESE tipo en segundos de income.
        ///
        /// Éstas sí ven `hireCostGrowth`: el factor que se paga es
        /// `growth^compras`, y dicen cuántas compras llega a acumular el bot de
        /// verdad — el número con el que hay que discutir la curva, no uno
        /// supuesto.
        ///
        /// ⚠️ El tipo NO es el del piso de la clave: con la política del bot es
        /// casi siempre el tier base del callejón. La clave es el piso sólo
        /// porque es el momento en que se tomó la foto; el tipo va en
        /// `floorUnlockPeakHireType` para que no se lea mal.
        public var floorUnlockPeakHireType: [String: String] = [:]
        public var floorUnlockPeakHirePurchases: [String: Int] = [:]
        public var floorUnlockPeakHireSeconds: [String: Double] = [:]
        public var firstReincarnationWall: Double?
        /// Tiempo ACTIVO de CADA reencarnación, en orden. La métrica del dueño es
        /// la cadencia ("una reencarnación cada 2,5-4 h de juego activo"), y para
        /// leerla hace falta la serie entera, no sólo la primera y el total.
        public var reincarnationActiveSeconds: [Double] = []
        public var godWall: Double?
        /// Tiempo ACTIVO acumulado al llegar a dios (el de pared es `godWall`).
        ///
        /// El dueño mide en horas de dedo, no de calendario, y hasta el
        /// 2026-08-22 este número había que sacarlo de `floorUnlockActiveSeconds`
        /// del último piso. Eso funciona **sólo** porque `god_realm` va del tier
        /// 37 al 37 y abre justo en el tier máximo: un piso final con varios
        /// tiers abre ANTES de que se llegue a dios y los dos números se separan.
        public var godActive: Double?
        public var reincarnations = 0

        // MARK: La FORMA de la curva (2026-08-23, decisión del dueño)
        //
        // El contrato dejó de ser un total de horas y pasó a ser una forma: la
        // run se traba, el prestigio corre esa pared, y volver a ella cuesta una
        // fracción de lo que costó la primera vez. Sin estas tres series no se
        // puede medir una pared, y por lo tanto no se puede calibrar una.

        /// **Dónde se traba cada run**: el primer tier cuyo paso al siguiente
        /// costó más de una sesión ENTERA de juego activo (`wallSeconds`, que se
        /// deriva de `human.sessionSeconds` y no es un número inventado: si un
        /// solo tier te come una sesión completa, estás trabado).
        ///
        /// `0` significa "esa run no se trabó", y el cero importa: una partida
        /// entera sin ningún cero en esta serie es una partida que nunca pide
        /// reencarnar, que es exactamente el defecto que esta ronda vino a
        /// arreglar.
        public var wallTierPerRun: [Int] = []
        /// Lo que tardó la run que se está cerrando en llegar a SU propia pared.
        /// Es el puente entre dos runs consecutivas —el denominador de
        /// `prestigePayoffPerRun`— y por eso vive en el reporte y no en el
        /// tracker, que se recicla en cada reencarnación. `nil` = la run
        /// anterior no se trabó, así que no hay contra qué comparar.
        public var secondsToOwnWallCandidate: Double?
        /// Segundos ACTIVOS que tardó cada run en llegar **a la pared de la run
        /// anterior**. Es el contrato 5 medido de frente: si reencarnar paga,
        /// este número tiene que ser una fracción chica del de abajo.
        ///
        /// Arranca en la segunda run (la primera no tiene pared anterior), así
        /// que el índice `i` es la run `i + 2`.
        public var secondsBackToPreviousWall: [Double] = []
        /// Segundos ACTIVOS que le costó a la run ANTERIOR llegar por primera vez
        /// a esa misma pared. Es el denominador de la comparación de arriba y va
        /// alineado índice a índice.
        public var secondsToOwnWallFirstTime: [Double] = []

        /// Cuánto paga reencarnar, por run: `1 − vuelta/primera`. 0,75 quiere
        /// decir "volver a tu pared costó un cuarto de lo que costó llegar".
        /// El contrato del dueño pide **≥ 0,67** (menos de un tercio).
        public var prestigePayoffPerRun: [Double] {
            zip(secondsBackToPreviousWall, secondsToOwnWallFirstTime).map { vuelta, primera in
                primera > 0 ? 1 - vuelta / primera : 0
            }
        }
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
        var tracker = RunTracker()
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
                    tracker: &tracker,
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
        // La run que quedó abierta (la que llega a dios, o la que corta el
        // horizonte) también tiene forma y también se publica.
        closeRun(tracker: &tracker, report: &report, active: activeTotal)
        report.finalMaxTier = state.run.maxTierReached
        report.finalPermanentUpgradeLevels = state.meta.oroUpgradeLevels
        return report
    }

    /// Lo que hay que recordar DENTRO de una run para poder decir dónde se
    /// trabó. Vive acá y no en `PlayerState` a propósito: es instrumental del
    /// simulador, no estado de juego, y meterlo en el save sería contaminar el
    /// modelo con la medición.
    struct RunTracker {
        /// Segundos ACTIVOS acumulados cuando arrancó esta run.
        var startActive: Double = 0
        /// Tier de frontera → segundos activos DESDE el inicio de la run en que
        /// se alcanzó por primera vez. El tier 1 está desde el segundo cero.
        var tierReached: [Int: Double] = [1: 0]
    }

    /// Cuándo se considera que la run se TRABÓ: cuando un solo tier de frontera
    /// se come una sesión entera de juego activo. No es un número inventado —
    /// sale del modelo humano—, y es el que hace medible la palabra "pared".
    var wallSeconds: Double { human.sessionSeconds }

    /// El primer tier de `tracker` cuyo paso al siguiente pasó de `wallSeconds`.
    /// `0` = esta run no se trabó.
    func wallTier(in tracker: RunTracker) -> Int {
        for tier in tracker.tierReached.keys.sorted() {
            guard let acá = tracker.tierReached[tier],
                  let arriba = tracker.tierReached[tier + 1] else { continue }
            if arriba - acá > wallSeconds { return tier }
        }
        return 0
    }

    /// Cierra la run que termina: publica dónde se trabó y, si había una pared
    /// anterior, cuánto costó volver a ella contra lo que costó la primera vez.
    private func closeRun(tracker: inout RunTracker, report: inout Report, active: Double) {
        let pared = wallTier(in: tracker)
        if let anterior = report.wallTierPerRun.last, anterior > 0,
           let vuelta = tracker.tierReached[anterior],
           let primera = report.secondsToOwnWallCandidate {
            report.secondsBackToPreviousWall.append(vuelta)
            report.secondsToOwnWallFirstTime.append(primera)
        }
        report.wallTierPerRun.append(pared)
        report.secondsToOwnWallCandidate = pared > 0 ? tracker.tierReached[pared] : nil
        tracker = RunTracker(startActive: active, tierReached: [1: 0])
    }

    // MARK: - Sesión activa

    /// Juega una sesión. Devuelve (wall consumido, activo consumido) — iguales
    /// salvo terminación temprana por dios.
    private func playSession(
        state: inout PlayerState,
        report: inout Report,
        tracker: inout RunTracker,
        wallStart: Double,
        activeStart: Double
    ) -> (wall: Double, active: Double) {
        var elapsed = 0.0
        while elapsed < human.sessionSeconds {
            doAllMerges(
                state: &state, report: &report, tracker: &tracker,
                wallStart: wallStart, activeStart: activeStart, elapsed: &elapsed
            )
            if state.run.maxTierReached >= tiers.maxTier, report.godWall == nil {
                report.godWall = wallStart + elapsed
                report.godActive = activeStart + elapsed
                return (elapsed, elapsed)
            }
            maybeReincarnate(
                state: &state, report: &report, tracker: &tracker,
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
            elapsed += wait + human.hireSeconds
            action.perform(&state)
            recordUnlocks(state: &state, report: &report, wall: wallStart + elapsed, active: activeStart + elapsed)
        }
        return (elapsed, elapsed)
    }

    // MARK: - Acciones

    struct Action {
        let cost: Double
        let perform: (inout PlayerState) -> Void
    }

    /// Una contratación candidata: lo que sale, y lo que sale **por unidad de tu
    /// frontera**, que es la moneda en la que el jugador compara dos filas de
    /// FisuJobs. Un tipo `d` tiers por debajo de tu frontera necesita `2^d`
    /// compras para convertirse en una unidad de arriba, así que el número que
    /// decide es `precio × 2^d` y no el precio.
    ///
    /// El desempate va por `typeId` para que la corrida siga siendo
    /// determinística: el orden de iteración de un `Dictionary` cambia por
    /// proceso.
    struct HireCandidate {
        let typeId: String
        let action: Action
        let frontierUnitCost: Double
    }

    /// La mejora por personaje elegida: qué tipo, qué cuesta y cuánto income por
    /// segundo agrega. `internal` porque su regla de selección es lo único que
    /// decide en qué se gasta la plata de la run, y ya se desincronizó una vez
    /// de la fórmula del efecto sin que ningún test lo viera.
    struct CharUpgradeChoice: Equatable, Sendable {
        let typeId: String
        let cost: Double
        /// Income por segundo que suma el próximo nivel, con todos los
        /// multiplicadores que el jugador tiene puestos.
        let gain: Double
    }

    /// La próxima compra deseable más barata (la espera la decide el caller).
    ///
    /// ⚠️ **Entre CONTRATACIONES no gana la más barata, gana la más barata POR
    /// UNIDAD DE FRONTERA**, y la distinción nació el 2026-08-23 con el precio
    /// anclado a la frontera. Hasta entonces las dos preguntas tenían la misma
    /// respuesta —el precio seguía a `tapYield(tier)`, que crece 2,8 por tier
    /// contra el 2 del merge, así que lo más barato era también lo más eficiente
    /// y bastaba con un `min` por precio—. Con la pendiente del precio por
    /// debajo del factor de merge las dos respuestas se dan vuelta: el Fisura
    /// sigue siendo lo más barato del catálogo y pasa a ser lo MENOS eficiente,
    /// y un bot que compre por precio se queda mergeando fisuras mientras el
    /// jugador compra arriba. Medido: con la compuerta en 7 tiers, el bot por
    /// precio tardaba 188,33 h en maxear y el bot por eficiencia 25,33 h.
    ///
    /// Las otras dos categorías siguen compitiendo por PRECIO, y también está
    /// bien: un passive unlock o un nivel de mejora no producen frontera, así
    /// que su moneda es la de siempre.
    private func nextAction(state: PlayerState) -> Action? {
        var candidates: [Action] = []

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

        // 2. CharUpgrade: la de mejor relación ganancia/precio, con payback corto.
        if let best = bestCharUpgrade(state: state), best.cost / best.gain <= maxPaybackSeconds {
            candidates.append(Action(cost: best.cost) { s in
                s.run.coins -= best.cost
                s.run.charUpgradeLevels[best.typeId, default: 0] += 1
            })
        }

        // 3. Hire en el piso 1 (motor del early game) si hay lugar. Su tier base
        //    es el exento de la compuerta, así que siempre está disponible — que
        //    es justo el rol que el diseño le da al Fisura.
        //    Y 4. el backfill de los pisos superiores: los dos compiten en
        //    `bestHire`, que elige por unidad de frontera.
        if let mejor = bestHire(state: state) {
            candidates.append(mejor.action)
        }

        return candidates.min { $0.cost < $1.cost }
    }

    /// La contratación que el bot elige: **la más barata por unidad de tu
    /// frontera**, entre el piso 1 (siempre disponible) y el backfill rentable
    /// de los pisos abiertos.
    ///
    /// `internal` por lo mismo que `bestCharUpgrade`: es una regla de selección
    /// del bot, o sea de las pocas cosas que deciden en qué se gasta la plata de
    /// la run, y ya se demostró dos veces que una regla de selección sin test
    /// propio se queda vieja en silencio cuando cambia la economía.
    func bestHire(state: PlayerState) -> HireCandidate? {
        var hires = hireActions(floorOrdinal: 0, state: state, requireProfit: false)
        for ordinal in 1..<floorTable.count where state.run.unlockedFloors.contains(floorTable[ordinal].id) {
            hires += hireActions(floorOrdinal: ordinal, state: state, requireProfit: true)
        }
        return hires.min {
            $0.frontierUnitCost == $1.frontierUnitCost
                ? $0.typeId < $1.typeId
                : $0.frontierUnitCost < $1.frontierUnitCost
        }
    }

    /// Las contrataciones que este piso ofrece: **TODOS sus tiers habilitados**,
    /// no sólo el base.
    ///
    /// ⚠️ **El bot compraba sólo el tier base de cada piso, y eso dejó de ser
    /// una aproximación aceptable el 2026-08-22.** El argumento era que comprar
    /// más arriba nunca conviene —lo garantizaba el `tierPremium` de entonces— y
    /// valía mientras la compuerta se midiera en PISOS: habilitado un piso, su
    /// base era la compra más barata y punto. Con la compuerta medida en tiers,
    /// el tier más alto que podés comprar es `frontera − N`, que **casi nunca es
    /// un tier base**: un bot que sólo compra bases redondea su distancia hacia
    /// arriba hasta el próximo borde de piso, y con la distancia real se queda
    /// mergeando fisuras hasta que la partida no se termina (medido: con N=5 el
    /// bot no pasaba del tier 9 en 90 días). El jugador, mientras tanto, tiene
    /// esa fila en FisuJobs.
    ///
    /// Quién gana entre todas sigue decidiéndolo la regla de siempre —la compra
    /// deseable MÁS BARATA, en `nextAction`—, y desde el precio anclado a la
    /// frontera (2026-08-23) esa regla apunta al tier **más alto** que la
    /// compuerta habilita: bajar uno abarata el precio 1,5× pero duplica cuántas
    /// unidades hacen falta. La excepción medida es el callejón, 24× barato por
    /// el ancla del Fisura, y el bot la aprovecha igual que el jugador hasta que
    /// su propia curva (`growth^compras`, por TIPO) la apaga.
    ///
    /// No hace falta filtrar por "visto": la compuerta ya lo garantiza (exige
    /// `maxTierReached ≥ tier + N`, así que el tipo se creó alguna vez) y el
    /// exento es el tier con el que arranca la partida.
    ///
    /// Cotiza por el camino real —`TowerActions.hireQuote(typeId:)`, la misma
    /// función que la pantalla de laburos—. Antes armaba el precio con
    /// `config.hireCost` por su cuenta, y ese es exactamente el modo en que el
    /// simulador y el juego se desincronizaron una vez.
    ///
    /// Lo que sí sigue haciendo a mano es la MUTACIÓN: `TowerActions.hire` pide
    /// un `TowerState` con slots, y el simulador no lo mantiene (deriva la
    /// ocupación de `run.units`). Por eso replica los dos contadores que la curva
    /// necesita —el del piso y el del TIPO—: si se olvidara del segundo, cotizaría
    /// siempre el precio de la primera compra.
    private func hireActions(floorOrdinal: Int, state: PlayerState, requireProfit: Bool) -> [HireCandidate] {
        let floor = floorTable[floorOrdinal]
        guard floorCount(floorOrdinal, state: state) < floor.capacity else { return [] }
        return (floor.firstTier...floor.lastTier).compactMap { tier in
            guard TowerActions.canHire(
                tier: tier, maxTierReached: state.run.maxTierReached,
                floorTable: floorTable, config: config
            ) else { return nil }
            return hireAction(tier: tier, floor: floor, state: state, requireProfit: requireProfit)
        }
    }

    /// Una contratación concreta: el tipo de este tier (respetando la carrera
    /// elegida cuando el tier se bifurca), cotizado y con su regla de payback.
    private func hireAction(
        tier: Int, floor: FloorDef, state: PlayerState, requireProfit: Bool
    ) -> HireCandidate? {
        let candidates = tiers.concreteTypes.filter { $0.tier == tier }
        guard let type = candidates.first(where: { $0.id.hasSuffix(careerPath) }) ?? candidates.sorted(by: { $0.id < $1.id }).first
        else { return nil }
        // `now: 0` alcanza porque el bot no tiene modificadores temporales: el
        // factor de `ModifierMath` vale 1 y no mira el reloj.
        //
        // ⚠️ El TERCER factor del quote —`1 − derivedEffects.spawnDiscount`— SÍ
        // varía desde que el bot compra mejoras permanentes: la línea `spawn`
        // llega a 0,30 y le abarata las contrataciones un 30 %. Que entre está
        // bien (el jugador la tiene igual), pero ya no es un factor neutro, y
        // darlo por 1 es leer el precio del bot como si fuera el de catálogo.
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
        let action = Action(cost: cost) { s in
            s.run.coins -= cost
            s.run.registerHire(floorId: floorId, typeId: typeId)
            s.run.units[typeId, default: 0] += 1
        }
        // Cuántas de éstas hacen falta para una unidad de tu frontera: `2^d`.
        // Con la frontera POR DEBAJO del tier —imposible con la compuerta puesta,
        // posible con la compuerta apagada— el exponente es negativo y el número
        // sigue significando lo mismo: comprar arriba te ahorra merges.
        let profundidad = Double(state.run.maxTierReached - tier)
        return HireCandidate(typeId: typeId, action: action, frontierUnitCost: cost * pow(2, profundidad))
    }

    // MARK: - Merges

    /// Aplica todos los merges legales (greedy, del tier más alto hacia abajo),
    /// respetando capacidad del piso destino. Elige carrera fija al primer fork.
    ///
    /// ⚠️ **Cada fusión CUESTA TIEMPO desde el 2026-08-23** (`human.mergeSeconds`),
    /// y el reloj avanza fusión por fusión y no al final de la tanda: los hitos
    /// se registran con el `elapsed` que corresponde, que es lo que hace que una
    /// cadena larga de merges no aparezca como instantánea en la tabla de pisos.
    /// Por eso `elapsed` entra `inout` y los tiempos base llegan por separado.
    private func doAllMerges(
        state: inout PlayerState,
        report: inout Report,
        tracker: inout RunTracker,
        wallStart: Double,
        activeStart: Double,
        elapsed: inout Double
    ) {
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
                if state.run.raiseFrontier(to: newType.tier) {
                    // El reloj de la pared es ACTIVO y relativo al inicio de la
                    // run: reencarnar reinicia la cuenta, que es lo que permite
                    // comparar "volver a la pared" contra "llegar la primera vez".
                    tracker.tierReached[newType.tier] =
                        activeStart + elapsed + human.mergeSeconds - tracker.startActive
                }
                merged = true
                elapsed += human.mergeSeconds
                recordUnlocks(
                    state: &state, report: &report,
                    wall: wallStart + elapsed, active: activeStart + elapsed
                )
                break
            }
        }
    }

    // MARK: - Reencarnación

    private func maybeReincarnate(
        state: inout PlayerState, report: inout Report,
        tracker: inout RunTracker, wall: Double, active: Double
    ) {
        guard case .whenOroMultiplies(let multiple) = human.reincarnation else { return }
        let gained = PrestigeCalculator.oroGained(state: state, economy: economy)
        // Regla idle estándar: reencarnar cuando al menos DUPLICA lo ganado
        // histórico (`multiple` = 1). La cuenta va en Double a propósito:
        // `oroEarnedLifetime` llega a órdenes en los que multiplicarlo en Int
        // desborda, y un desborde acá sería un crash en mitad de una calibración.
        let threshold = max(1, Double(state.meta.oroEarnedLifetime) * multiple)
        guard Double(gained) >= threshold else { return }
        PrestigeCalculator.applyReincarnation(state: &state, economy: economy, tiers: tiers, floorTable: floorTable, now: wall)
        closeRun(tracker: &tracker, report: &report, active: active)
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
            state.meta.spendOro(oroPrice(of: line, atLevel: level))
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
    /// La más barata que el bot puede pagar AHORA.
    ///
    /// ⚠️ **El filtro y el orden no miran el mismo número, y es deuda declarada.**
    /// El filtro usa `oroPrice` —el entero redondeado para arriba que la app
    /// cobra de verdad— y el `min` ordena por el `Double` crudo, así que entre
    /// dos líneas que la app cobra IGUAL (dos precios distintos que redondean al
    /// mismo entero) el bot prefiere la de fracción más chica, una diferencia
    /// que el juego nunca cobra.
    ///
    /// Se deja como está a propósito: unificar los dos en `oroPrice` está
    /// medido y **no mueve ninguna de las cuatro métricas** (maxear 24,00 h · 8
    /// reencarnaciones · dios 470,26 h de pared · la cadencia entera), pero SÍ
    /// mueve la conducta —el `lifetimeEarnings` final pasa de 2,440e26 a
    /// 2,349e26—, o sea que es un cambio de comportamiento del bot y le
    /// corresponde su propio test, no un arreglo de paso en la tarea de cierre.
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

    /// Qué mejora por personaje comprar: la de mejor **income por moneda**.
    ///
    /// ⚠️ **Esta regla la invalidó el efecto secuencial del 2026-08-22 y hay que
    /// leer por qué antes de volver a tocarla.** El bot elegía
    /// `max(by: contribution)` —el tipo que más aporta—, y eso alcanzaba **sólo
    /// mientras la ganancia fuera un factor CONSTANTE**: con `2^nivel`, subirle
    /// un nivel a cualquiera duplicaba su aporte, así que el que más aportaba
    /// era también el que más ganaba. Con la recta la ganancia marginal es
    /// `aporte × 1/(1+nivel)` y `contribution` **ya incluye** el multiplicador
    /// comprado, o sea que el tipo más mejorado encabezaba el ranking justo
    /// cuando su próximo nivel es la peor compra del tablero: ganancia plana
    /// contra un precio que va por `costGrowth^nivel`.
    ///
    /// Y como el bot toma UN candidato de mejora por tick, si ése no pasaba el
    /// payback se quedaba **sin comprar ninguna** aunque al lado hubiera un tipo
    /// en nivel 0 que duplica por `50 × tapYield`. El sesgo iba para el lado
    /// peligroso: el bot subestimaba la línea, así que el juego medido tardaba
    /// MÁS que el real y los barridos de calibración estaban midiendo dónde
    /// tropieza el bot en vez de dónde está el óptimo.
    ///
    /// La ganancia sale de `CharUpgrades.nextLevelGainFactor` y el precio de
    /// `CharUpgrades.nextLevelCost`: las dos, del mismo lugar que cobra el juego.
    /// `nil` = nadie tiene un nivel que comprar (todos al tope o sin pasivo).
    func bestCharUpgrade(state: PlayerState) -> CharUpgradeChoice? {
        state.run.units.keys
            .compactMap { tiers.type(id: $0) }
            .filter { state.run.passiveUnlocked[$0.id] == true }
            .compactMap { type -> CharUpgradeChoice? in
                guard let cost = CharUpgrades.nextLevelCost(
                    type: type, levels: state.run.charUpgradeLevels, config: config, economy: economy
                ), cost > 0 else { return nil }
                let gain = contribution(of: type, state: state) * CharUpgrades.nextLevelGainFactor(
                    typeId: type.id, levels: state.run.charUpgradeLevels, config: config
                )
                guard gain > 0 else { return nil }
                return CharUpgradeChoice(typeId: type.id, cost: cost, gain: gain)
            }
            // Empate por `id` ASCENDENTE (de ahí el `>`): el orden de iteración
            // de un `Dictionary` cambia por proceso y esta corrida promete ser
            // determinística.
            .max { lhs, rhs in
                let left = lhs.gain / lhs.cost
                let right = rhs.gain / rhs.cost
                return left == right ? lhs.typeId > rhs.typeId : left < right
            }
    }

    /// Lo que un tipo aporta HOY al passive, con su multiplicador comprado ya
    /// puesto. Es el punto de partida de la ganancia del próximo nivel
    /// (`aporte × nextLevelGainFactor`), **no** un criterio para elegir a quién
    /// mejorar: justamente porque incluye lo ya comprado, ordenar por este
    /// número pone primero al tipo cuyo próximo nivel es la PEOR compra. Quién
    /// se mejora lo decide `bestCharUpgrade`.
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

    /// Cuántos segundos de income cuesta el PRÓXIMO hire del tier base del piso,
    /// al contador de compras que el bot tiene de ese tipo. Cotiza por
    /// `config.hireCost` —sin descuentos ni modificadores, que el bot no tiene—
    /// y divide por el income de juego activo, que es el que el jugador tiene en
    /// la mano cuando abre el piso.
    ///
    /// El contador sale de `hireCountsByType`, el mismo que alimenta la curva en
    /// `TowerActions.hireQuote(typeId:)`: cotizar siempre con `purchases: 0`
    /// —como hacía la primera versión de esta métrica— la volvía
    /// matemáticamente ciega a `hireCostGrowth`, porque `growth^0 = 1`.
    private func hireSeconds(floor: FloorDef, state: PlayerState) -> Double {
        let rate = incomeRate(state: state, active: true)
        guard rate > 0 else { return .infinity }
        let typeId = baseTypeId(of: floor)
        let purchases = typeId.map { state.run.hireCountsByType[$0] ?? 0 } ?? 0
        return config.hireCost(
            floor: floor, tier: floor.firstTier,
            frontierTier: state.run.maxTierReached, purchases: purchases
        ) / rate
    }

    /// El tipo del tier base del piso, elegido igual que en `hireAction` (misma
    /// carrera, mismo desempate) para que la métrica cotice lo que el bot compra.
    private func baseTypeId(of floor: FloorDef) -> String? {
        let candidates = tiers.concreteTypes.filter { $0.tier == floor.firstTier }
        return (candidates.first(where: { $0.id.hasSuffix(careerPath) })
            ?? candidates.sorted(by: { $0.id < $1.id }).first)?.id
    }

    /// El tipo con MÁS compras acumuladas y lo que cuesta el próximo, en
    /// segundos de income. Es donde vive el compounding de `hireCostGrowth`: el
    /// bot compra una y otra vez sobre el mismo tier base y su precio sube
    /// `growth` por compra.
    ///
    /// **No es el tier base del piso de la fila**: es el tipo más comprado de
    /// toda la run, que con la política del bot es casi siempre el Fisura del
    /// callejón. La fila lo etiqueta con su `typeId` justamente para que no se
    /// lea como "lo que cuesta este piso".
    ///
    /// Empata por `id`, como `cheapestAffordableUpgrade`: el orden de iteración
    /// de un `Dictionary` cambia por proceso, y este simulador promete ser
    /// determinístico.
    ///
    /// Devuelve `nil` si el bot todavía no compró nada. El centinela importa: en
    /// este reporte `0,0 s` significa "contratar es gratis", que es el hallazgo
    /// central del documento, y usarlo también para "no hay dato" los confundía.
    private func peakHire(state: PlayerState) -> (typeId: String, purchases: Double, seconds: Double)? {
        let ordered = state.run.hireCountsByType
            .filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        guard let (typeId, purchases) = ordered.first, let type = tiers.type(id: typeId) else { return nil }
        let rate = incomeRate(state: state, active: true)
        guard rate > 0 else { return (typeId, purchases, .infinity) }
        let floor = floorTable.floor(forTier: type.tier)
        let cost = config.hireCost(
            floor: floor, tier: type.tier,
            frontierTier: state.run.maxTierReached, purchases: purchases
        )
        return (typeId, purchases, cost / rate)
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
                if let peak = peakHire(state: state) {
                    report.floorUnlockPeakHireType[floor.id] = peak.typeId
                    report.floorUnlockPeakHirePurchases[floor.id] = Int(peak.purchases.rounded(.down))
                    report.floorUnlockPeakHireSeconds[floor.id] = peak.seconds
                }
            }
        }
    }
}
