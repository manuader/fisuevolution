import EconomyKit
import Foundation

/// Lo que salió de un colchón, ya acreditado.
struct MattressOutcome: Equatable {
    let prizeId: String
    let rewards: [RewardSpec]
    /// La plata acreditada (0 si el premio no era plata).
    let coins: Double
    /// Los "otro colchón" que le quedan.
    let extraOpensLeft: Int
    /// Es el gratis del tablero (E14b B31): al cobrarlo ofrece su ×2 con video (B29). El pagado y el
    /// «otro colchón», no.
    var isGift = false
}

/// Los dos colchones que pueden estar a la vez en el tablero: el de la columna, que se paga con un
/// video (E14b B6), y el gratis que cae cada 30 minutos de reloj real (B31). Cada uno es de un piso,
/// como una caja: cae en un lugar de ese piso y ahí se queda.
enum BoardMattress: CaseIterable {
    case column
    case free
}

/// El Colchón en la partida (PLAN-v2 E5): "tus empleados escondieron plata en
/// el colchón". El de la columna (E14b B6, D3) aparece ahí y se paga con un video; el gratis (B31,
/// D20) cae directo cada 30 minutos de reloj real. Los dos caen al tablero, y ahí se abren.
extension GameState {
    private var treasuresState: TreasuresState { player?.meta.engagement.treasures ?? .initial }

    private var mattressPhase: TreasuresState.Phase { treasuresState.phase }

    /// En la columna, esperando su video.
    var mattressWaiting: Bool { mattressPhase == .waiting }

    /// Pagado: en el tablero, listo para abrir.
    var mattressOnBoard: Bool { mattressPhase == .onBoard }

    /// El gratis (B31) está en el tablero, sin abrir.
    var freeMattressOnBoard: Bool { treasuresState.freeBoard.waiting }

    /// Hay uno de la columna en juego, en la columna o en el tablero: su reloj no corre.
    var mattressInPlay: Bool { mattressPhase != .none }

    var mattressExtraOpensLeft: Int { treasuresState.extraOpensLeft }

    /// Ése está en el tablero, listo para abrir.
    func isOnBoard(_ mattress: BoardMattress) -> Bool {
        switch mattress {
        case .column: mattressOnBoard
        case .free: freeMattressOnBoard
        }
    }

    /// El piso donde está ése (E14b B24): el que se miraba cuando cayó. `nil` fuera del tablero o
    /// sin ubicar todavía.
    func mattressFloor(_ mattress: BoardMattress) -> Int? {
        guard isOnBoard(mattress) else { return nil }
        return switch mattress {
        case .column: treasuresState.floor
        case .free: treasuresState.freeBoard.floor
        }
    }

    /// Su lugar sobre la superficie de ese piso, en las fracciones de una caja.
    func mattressSpot(_ mattress: BoardMattress) -> PackageSpot? {
        guard isOnBoard(mattress) else { return nil }
        return switch mattress {
        case .column: treasuresState.spot
        case .free: treasuresState.freeBoard.spot
        }
    }

    /// El del tablero de la columna: su piso y su lugar.
    var mattressFloor: Int? { mattressFloor(.column) }
    var mattressSpot: PackageSpot? { mattressSpot(.column) }

    /// Los colchones del tablero caen en el piso que se mira, en un lugar libre de la mitad de
    /// adelante (E14b B24): la regla de las cajas (B22), lejos de ellas, del otro colchón y de la
    /// zona del visitante, y adelante para que quede delante de las hileras (B19). Como una caja,
    /// cada uno es de su piso: uno que ya tiene lugar no se mueve al mirar otro piso, salvo que su
    /// piso se haya cerrado (una reencarnación): ahí no se ve ni se toca, así que vuelve a caer en
    /// un piso abierto. El recién pagado, el gratis recién caído y el de un save sin piso se ubican
    /// acá.
    func placeMattressIfNeeded() {
        placeMattressIfNeeded(using: &rng)
    }

    /// Lo mismo con el sorteo de afuera: los tests lo siembran.
    func placeMattressIfNeeded<R: RandomNumberGenerator>(using generator: inout R) {
        // De a uno y guardando en el medio: el segundo ve el lugar del primero y no cae encima.
        for mattress in BoardMattress.allCases where isOnBoard(mattress) {
            guard var player else { return }
            let floor: Int? = switch mattress {
            case .column: settle(&player.meta.engagement.treasures, using: &generator)
            case .free: settle(&player.meta.engagement.treasures.freeBoard, using: &generator)
            }
            guard let floor else { continue }
            self.player = player
            Log.economy.info("mattress landed on floor \(floor)")
            scheduleSave()
        }
    }

    /// Ubica un colchón del tablero si hace falta; devuelve el piso donde cayó, o `nil` si se quedó
    /// donde estaba.
    private func settle<P: MattressPlacement, R: RandomNumberGenerator>(
        _ placement: inout P, using generator: inout R
    ) -> Int? {
        let open = unlockedFloorOrdinals
        let stranded = !open.isEmpty && placement.floor.map { !open.contains($0) } ?? false
        guard placement.needsPlacement || stranded else { return nil }
        // El que se mira puede ser el piso cerrado al que uno se asoma (`setVisibleFloor`): ahí no.
        let floor = open.isEmpty || open.contains(visibleFloorOrdinal) ? visibleFloorOrdinal : open.max() ?? 0
        placement.clearPlacement()
        let taken = player?.meta.engagement.packages.boxes(onFloor: floor).compactMap(\.spot) ?? []
        // Él mismo no cuenta: o no tenía lugar, o su piso viejo está cerrado y no es éste.
        let areas = packageAreas(onFloor: floor).map { $0.keepingToTheFront(Self.mattressBackDepth) }
        var spot = PackagePlacer.place(among: taken, in: areas, using: &generator)
        // Si el sorteo no encontró lugar libre se queda con el menos pisado: nunca atrás.
        spot.y = min(spot.y, Self.mattressBackDepth.lowerBound * 0.98)
        placement.land(onFloor: floor, at: spot)
        if stranded { Log.economy.info("mattress left a closed floor") }
        return floor
    }

    /// Los ordinales de los pisos abiertos de esta run.
    private var unlockedFloorOrdinals: Set<Int> {
        guard let content, let player else { return [] }
        let unlocked = Set(player.run.unlockedFloors)
        return Set(content.floorTable.floors.indices.filter { unlocked.contains(content.floorTable[$0].id) })
    }

    /// La parte de atrás de la superficie, de 0 (el frente) a 1 (el horizonte), donde el colchón no
    /// cae: ahí lo taparía la hilera de adelante.
    static let mattressBackDepth: ClosedRange<Double> = 0.5...1

    /// El «otro colchón» de uno ya abierto sigue guardado: sobrevive a cerrar el
    /// popup y a matar la app, hasta que aparece un colchón nuevo.
    var mattressExtraPending: Bool { mattressPhase == .none && mattressExtraOpensLeft > 0 }

    /// Los dos relojes: el de la columna, de juego activo, con el delta del tick; el del gratis, de
    /// reloj real (E14b B31), con la hora de ahora. Lo llama `advanceEngagement`.
    func advanceTreasures(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        // El del tablero de un save sin piso todavía no tiene lugar, y el de un piso que se
        // cerró al reencarnar no se ve: se ubican al cargar (y se guarda).
        placeMattressIfNeeded()
        guard engagementAutorun || freeMattressAutorun, !tutorialPhaseActive, mattressPopup == nil,
              let content, var player else { return }
        let clockWasOff = player.meta.engagement.treasures.freeBoard.clockStartedAt == nil
        // El de la columna sólo con los motores prendidos; `freeMattressAutorun` prende sólo el gratis.
        var appeared = false
        if engagementAutorun {
            appeared = TreasureScheduler.advance(&player.meta.engagement.treasures, delta: delta, config: content.treasures)
        }
        let dropped = FreeMattressClock.advance(&player.meta.engagement.treasures, now: now, config: content.treasures)
        let clockStarted = clockWasOff && player.meta.engagement.treasures.freeBoard.clockStartedAt != nil
        self.player = player
        if appeared { Log.economy.info("mattress appeared in the column") }
        if dropped { Log.economy.info("free mattress dropped") }
        if dropped { placeMattressIfNeeded() }
        if appeared || dropped || clockStarted { scheduleSave() }
    }

    /// Se miró el video de la columna: el colchón cae al tablero, todavía cerrado.
    @discardableResult
    func payMattress() -> Bool {
        guard var player, TreasureScheduler.markPaid(&player.meta.engagement.treasures) else { return false }
        self.player = player
        Log.economy.info("mattress paid")
        placeMattressIfNeeded()
        scheduleSave()
        return true
    }

    /// Se abrió el de la columna en el tablero: sortea, acredita y habilita "otro colchón".
    @discardableResult
    func openMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, mattressOnBoard,
              let prize = TreasureRoller.roll(content.treasures, using: &rng),
              var player,
              TreasureScheduler.markOpened(&player.meta.engagement.treasures, config: content.treasures)
        else { return nil }
        self.player = player
        return deliver(prize, now: now)
    }

    /// Se abrió el gratis del tablero (E14b B31): sortea con su tabla, acredita y su reloj arranca
    /// de nuevo ahora. No da «otro colchón»; su cobro ofrece el ×2 con video (B29).
    @discardableResult
    func openFreeMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, freeMattressOnBoard,
              let prize = TreasureRoller.rollFree(content.treasures, using: &rng),
              var player,
              FreeMattressClock.markOpened(&player.meta.engagement.treasures, now: now)
        else { return nil }
        self.player = player
        return deliver(prize, now: now, gifted: true)
    }

    /// Después del segundo video: otro sorteo, una vez por colchón.
    @discardableResult
    func openExtraMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, player?.meta.engagement.treasures.extraOpensLeft ?? 0 > 0,
              let prize = TreasureRoller.roll(content.treasures, using: &rng),
              var player
        else { return nil }
        player.meta.engagement.treasures.extraOpensLeft -= 1
        self.player = player
        return deliver(prize, now: now)
    }

    /// El colchón ya quedó gastado: acredita su premio por el único punto de premios. El gratis no
    /// tiene «otro colchón» propio: su pop-up no lo ofrece.
    private func deliver(_ prize: TreasuresConfig.Prize, now: TimeInterval, gifted: Bool = false) -> MattressOutcome {
        let coins = grant(prize.rewards, source: "treasure.\(prize.id)", now: now)
        announceReward(prize.rewards, coins: coins)
        Log.economy.info("mattress opened: \(prize.id)")
        return MattressOutcome(prizeId: prize.id, rewards: prize.rewards, coins: coins,
                               extraOpensLeft: gifted ? 0 : mattressExtraOpensLeft, isGift: gifted)
    }

    #if DEBUG
    /// En la columna; `onBoard`: ya pagado, en el tablero; `extraSaved`: el colchón ya se abrió y le
    /// queda «otro colchón» guardado. El del tablero cae en un lugar libre del piso que se mira, como
    /// el de verdad (B24).
    func debugSpawnMattress(onBoard: Bool = false, extraSaved: Bool = false) {
        guard var player else { return }
        player.meta.engagement.treasures.phase = extraSaved ? .none : onBoard ? .onBoard : .waiting
        player.meta.engagement.treasures.extraOpensLeft = extraSaved ? 1 : 0
        player.meta.engagement.treasures.clearPlacement()
        self.player = player
        placeMattressIfNeeded()
    }

    /// El gratis (B31) ya cayó: en el tablero, en un lugar libre del piso que se mira.
    func debugDropFreeMattress() {
        guard var player else { return }
        player.meta.engagement.treasures.freeBoard.waiting = true
        player.meta.engagement.treasures.freeBoard.clearPlacement()
        self.player = player
        placeMattressIfNeeded()
    }

    /// El reloj del gratis cada `seconds` en vez de 30 minutos, y prendido aunque los demás motores
    /// estén apagados (`--uitest-free-mattress-every=<s>`): el UI test lo ve caer.
    func debugFreeMattressEvery(_ seconds: TimeInterval) {
        guard var content else { return }
        let treasures = content.treasures
        content.treasures = TreasuresConfig(
            schemaVersion: treasures.schemaVersion, spawnIntervalSeconds: treasures.spawnIntervalSeconds,
            firstTreasureAfterSeconds: treasures.firstTreasureAfterSeconds,
            extraOpensPerTreasure: treasures.extraOpensPerTreasure, freeBoardIntervalSeconds: seconds,
            prizes: treasures.prizes, freeBoardPrizes: treasures.freeBoardPrizes
        )
        self.content = content
        freeMattressAutorun = true
        player?.meta.engagement.treasures.freeBoard = FreeBoardMattress()
    }
    #endif
}
