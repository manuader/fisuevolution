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
    /// Llegó de regalo (D4): al cobrarlo ofrece su ×2 con video (E14b B29). El pagado y el «otro colchón», no.
    var isGift = false
}

/// El Colchón en la partida (PLAN-v2 E5): "tus empleados escondieron plata en
/// el colchón". El recorrido (E14b B6, D3/D4): aparece en la columna y se paga con un
/// video, o llega de regalo; en los dos casos cae al tablero, y ahí se abre.
extension GameState {
    private var mattressPhase: TreasuresState.Phase { player?.meta.engagement.treasures.phase ?? .none }

    /// En la columna, esperando su video.
    var mattressWaiting: Bool { mattressPhase == .waiting }

    /// Pagado o regalado: en el tablero, listo para abrir.
    var mattressOnBoard: Bool { mattressPhase == .onBoard }

    /// Hay uno en juego, en la columna o en el tablero: el reloj no corre.
    var mattressInPlay: Bool { mattressPhase != .none }

    var mattressExtraOpensLeft: Int { player?.meta.engagement.treasures.extraOpensLeft ?? 0 }

    /// El piso donde está el del tablero (E14b B24): el que se miraba cuando cayó.
    var mattressFloor: Int? { mattressOnBoard ? player?.meta.engagement.treasures.floor : nil }

    /// Su lugar sobre la superficie de ese piso, en las fracciones de una caja.
    var mattressSpot: PackageSpot? { mattressOnBoard ? player?.meta.engagement.treasures.spot : nil }

    /// El del tablero cae en el piso que se mira, en un lugar libre de la mitad de adelante (E14b
    /// B24): la regla de las cajas (B22), lejos de ellas y de la zona del visitante, y adelante para
    /// que quede delante de las hileras (B19). El recién pagado, el de regalo y el de un save
    /// anterior a B24; uno que ya tiene lugar no se mueve, salvo que su piso se haya cerrado (una
    /// reencarnación): ahí no se ve ni se toca, así que vuelve a caer en un piso abierto.
    func placeMattressIfNeeded() {
        placeMattressIfNeeded(using: &rng)
    }

    /// Lo mismo con el sorteo de afuera: los tests lo siembran.
    func placeMattressIfNeeded<R: RandomNumberGenerator>(using generator: inout R) {
        guard var player, player.meta.engagement.treasures.phase == .onBoard else { return }
        let open = unlockedFloorOrdinals
        let stranded = !open.isEmpty && player.meta.engagement.treasures.floor.map { !open.contains($0) } ?? false
        guard player.meta.engagement.treasures.needsPlacement || stranded else { return }
        // El que se mira puede ser el piso cerrado al que uno se asoma (`setVisibleFloor`): ahí no.
        let floor = open.isEmpty || open.contains(visibleFloorOrdinal) ? visibleFloorOrdinal : open.max() ?? 0
        player.meta.engagement.treasures.clearPlacement()
        let taken = player.meta.engagement.packages.boxes(onFloor: floor).compactMap(\.spot)
        // El colchón propio no cuenta: su piso viejo está cerrado y no es éste.
        let areas = packageAreas(onFloor: floor).map { $0.keepingToTheFront(Self.mattressBackDepth) }
        var spot = PackagePlacer.place(among: taken, in: areas, using: &generator)
        // Si el sorteo no encontró lugar libre se queda con el menos pisado: nunca atrás.
        spot.y = min(spot.y, Self.mattressBackDepth.lowerBound * 0.98)
        player.meta.engagement.treasures.land(onFloor: floor, at: spot)
        self.player = player
        if stranded { Log.economy.info("mattress left a closed floor") }
        Log.economy.info("mattress landed on floor \(floor)")
        scheduleSave()
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

    /// El reloj de juego activo. Lo llama `advanceEngagement` con el delta del tick.
    func advanceTreasures(delta: TimeInterval) {
        // El del tablero de un save anterior a B24 todavía no tiene lugar, y el de un piso que se
        // cerró al reencarnar no se ve: se ubican al cargar (y se guarda).
        placeMattressIfNeeded()
        guard engagementAutorun, !tutorialPhaseActive, mattressPopup == nil, let content, var player else { return }
        let arrival = TreasureScheduler.advance(&player.meta.engagement.treasures, delta: delta,
                                                config: content.treasures, using: &rng)
        self.player = player
        guard let arrival else { return }
        let kind = arrival == .gift ? "gift" : "column"
        Log.economy.info("mattress appeared: \(kind)")
        placeMattressIfNeeded()
        scheduleSave()
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

    /// Se abrió el del tablero: sortea, acredita y habilita "otro colchón".
    @discardableResult
    func openMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, mattressOnBoard,
              let prize = TreasureRoller.roll(content.treasures, using: &rng),
              var player
        else { return nil }
        let gifted = player.meta.engagement.treasures.gifted
        guard TreasureScheduler.markOpened(&player.meta.engagement.treasures, config: content.treasures) else { return nil }
        self.player = player
        return deliver(prize, now: now, gifted: gifted)
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

    /// El colchón ya quedó gastado: acredita su premio por el único punto de premios.
    private func deliver(_ prize: TreasuresConfig.Prize, now: TimeInterval, gifted: Bool = false) -> MattressOutcome {
        let coins = grant(prize.rewards, source: "treasure.\(prize.id)", now: now)
        announceReward(prize.rewards, coins: coins)
        Log.economy.info("mattress opened: \(prize.id)")
        return MattressOutcome(prizeId: prize.id, rewards: prize.rewards, coins: coins,
                               extraOpensLeft: mattressExtraOpensLeft, isGift: gifted)
    }

    #if DEBUG
    /// En la columna; `onBoard`: ya pagado o regalado, en el tablero (`gifted`: de regalo, D4);
    /// `extraSaved`: el colchón ya se abrió y le queda «otro colchón» guardado. El del tablero cae en
    /// un lugar libre del piso que se mira, como el de verdad (B24).
    func debugSpawnMattress(onBoard: Bool = false, extraSaved: Bool = false, gifted: Bool = false) {
        guard var player else { return }
        player.meta.engagement.treasures.phase = extraSaved ? .none : onBoard ? .onBoard : .waiting
        player.meta.engagement.treasures.extraOpensLeft = extraSaved ? 1 : 0
        player.meta.engagement.treasures.gifted = onBoard && gifted
        player.meta.engagement.treasures.floor = nil
        player.meta.engagement.treasures.x = nil
        player.meta.engagement.treasures.y = nil
        self.player = player
        placeMattressIfNeeded()
    }
    #endif
}
