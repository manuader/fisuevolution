import EconomyKit
import Foundation

/// Lo que pasa al abrir un paquete.
enum PackageOpenResult: Equatable {
    /// Sorteó a quién trae y lo dejó en el embudo de E1: llega en su turno, a la vista,
    /// al piso `floorId`.
    case opened(typeId: String, floorId: String)
    /// No hay a quién traer con lugar: "LLENO", y el paquete se queda.
    case full
    /// No había ninguno esperando.
    case noneWaiting
}

/// Uno de los empleados posibles de un paquete, con su chance (E14 C28).
struct PackageChance: Identifiable, Equatable {
    let typeId: String
    let faceKey: String
    let name: String
    let probability: Double

    var id: String { typeId }
}

/// A quién le tocó y a qué piso llega.
struct PackageArrival: Identifiable, Equatable {
    let id = UUID()
    let typeId: String
    let floorId: String
}

/// La pantalla del Paquete de la Aduana (E14 C28); `arrivals` es lo que salió, cuando ya se abrió.
struct PackagePopup: Identifiable, Equatable {
    let id = UUID()
    var arrivals: [PackageArrival] = []
}

/// Lo que pasa al tocar la caja del tablero (E14b B5, D2).
enum BoardPackageTap: Equatable {
    /// La cuenta todavía no abrió ninguno: se abre la pantalla de C28.
    case popup
    /// Desde la segunda: la caja se sacude y se abre ahí mismo, sin pop-up.
    case openInPlace
    /// No entra nadie: la caja no se abre y avisa arriba (C20, C28 punto 4).
    case full
    /// No había nada que abrir o algo más ocupa la pantalla.
    case refused
}

/// Se ganó un paquete: lo que la vista usa para volarlo al sello.
struct PackageWin: Identifiable, Equatable {
    let id = UUID()
    let count: Int
}

/// El Paquete de la Aduana en la partida (PLAN-v2 E5).
extension GameState {
    var packagesWaiting: Int { player?.meta.engagement.packages.waiting ?? 0 }

    /// A quién podría traer un paquete ahora: lo que FisuJobs vende con lugar.
    var packageCandidates: [CharacterType] {
        guard let content, let player, let tower else { return [] }
        return PackageRoller.eligibleTypes(
            state: player, tiers: content.tiers, floorTable: content.floorTable, config: content.economy,
            occupancy: tower.floors.map(\.occupiedCount).enumerated().map { $0.element + queuedArrivals(onFloor: $0.offset) }
        )
    }

    /// «Adentro puede venir»: la tabla con la que se sortea, tipo por tipo. Sin lugar en ningún piso
    /// muestra a los que vendrían si lo hubiera (la pantalla dice que no hay lugar, con sus caras).
    var packageChances: [PackageChance] {
        guard let content, let player, let tower else { return [] }
        var eligible = packageCandidates
        if eligible.isEmpty {
            eligible = PackageRoller.eligibleTypes(
                state: player, tiers: content.tiers, floorTable: content.floorTable, config: content.economy,
                occupancy: Array(repeating: 0, count: tower.floors.count)
            )
        }
        let ratio = content.packages.tierRatio(bestSupplierLevel: bestSupplierLevel)
        return PackageRoller.typeOdds(eligible: eligible, windowTiers: content.packages.windowTiers, ratio: ratio)
            .compactMap { row in
                content.tiers.type(id: row.typeId).map {
                    PackageChance(typeId: $0.id, faceKey: "\($0.id)_face", name: $0.localizedName, probability: row.probability)
                }
            }
    }

    /// Las llegadas ya encoladas o en vuelo que van a ocupar un lugar del piso:
    /// sin contarlas, dos toques rápidos con un solo lugar libre traerían a dos
    /// al mismo lugar.
    private func queuedArrivals(onFloor ordinal: Int) -> Int {
        (pendingBoardChanges + [inFlightBoardChange].compactMap { $0 }).filter {
            if case .arrival = $0.kind { return floorOrdinal(of: $0) == ordinal }
            return false
        }.count
    }

    /// Hay paquetes esperando y ninguno entra: el cartel "LLENO".
    var packagesBlocked: Bool { packagesWaiting > 0 && packageCandidates.isEmpty }

    /// El reloj de juego activo. Lo llama `advanceEngagement` con el delta del tick.
    func advancePackages(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        let rate = ModifierMath.factor(player.run.activeModifiers, effect: .packageRateMultiplier, now: now)
        let dropped = PackageScheduler.advance(
            &player.meta.engagement.packages, delta: delta, rateMultiplier: rate, config: content.packages
        )
        self.player = player
        guard dropped > 0 else { return }
        Log.economy.info("package dropped: \(player.meta.engagement.packages.waiting) waiting")
        scheduleSave()
    }

    /// Abre uno: sortea a quién trae y deja su llegada en el embudo. El
    /// paquete se gasta sólo si alguien entra.
    @discardableResult
    func openPackage() -> PackageOpenResult {
        guard let content, var player, let tower, player.meta.engagement.packages.waiting > 0 else {
            return .noneWaiting
        }
        let ratio = content.packages.tierRatio(bestSupplierLevel: bestSupplierLevel)
        guard let type = PackageRoller.roll(
                  eligible: packageCandidates, windowTiers: content.packages.windowTiers, ratio: ratio, using: &rng
              ),
              let change = BoardChangePlanner.planArrival(
                  typeId: type.id, state: player, tower: tower, tiers: content.tiers,
                  floorTable: content.floorTable, origin: .package
              )
        else {
            haptics?.play(.error)
            audio?.play(.error)
            return .full
        }
        player.meta.engagement.packages.waiting -= 1
        self.player = player
        enqueueBoardChange(change)
        haptics?.play(.purchase)
        scheduleSave()
        Log.economy.info("package opened: \(type.id)")
        let floorId = floorOrdinal(of: change).map { content.floorTable[$0].id } ?? ""
        return .opened(typeId: type.id, floorId: floorId)
    }

    /// El sello o la caja del tablero: abre la pantalla del paquete. Sin lugar también abre, a
    /// explicarlo. `false` si no había nada que abrir o algo más ocupa la pantalla.
    @discardableResult
    func packageTapped() -> Bool {
        tutorialTipCompleted(.packages)
        guard packagesWaiting > 0, packagePopup == nil, mattressPopup == nil, wheelSheet == nil else { return false }
        packagePopup = PackagePopup()
        refreshPrizeAccess()
        return true
    }

    /// La caja del tablero (E14b B5, D2): la primera vez, la pantalla de C28; desde la segunda,
    /// `.openInPlace` y la escena la abre ahí mismo. Todavía no gasta nada: el paquete se gasta
    /// cuando la caja termina de abrirse (`openPackageOnBoard`). La columna y Regalos siguen
    /// por `packageTapped` (D5).
    @discardableResult
    func boardPackageTapped() -> BoardPackageTap {
        guard packageIntroSeen else { return packageTapped() ? .popup : .refused }
        tutorialTipCompleted(.packages)
        guard packagesWaiting > 0, packagePopup == nil, mattressPopup == nil, wheelSheet == nil else { return .refused }
        guard !packagesBlocked else {
            noteBoardPackageFull()
            return .full
        }
        return .openInPlace
    }

    /// La caja del tablero terminó de abrirse: se gasta y el empleado sale hacia su lugar, sin pop-up.
    /// Si en el medio se llenó todo, no se gasta y avisa arriba.
    @discardableResult
    func openPackageOnBoard() -> PackageOpenResult {
        let result = openPackage()
        if result == .full { noteBoardPackageFull() }
        refreshPrizeAccess()
        return result
    }

    var packageIntroSeen: Bool { player?.meta.engagement.packageIntroSeen ?? false }

    private func noteBoardPackageFull() {
        towerNotice = TowerNotice(kind: .packageFull)
    }

    /// Ya abrió uno desde la pantalla: la caja del tablero se abre sola de ahora en más.
    private func markPackageIntroSeen() {
        guard var player, !player.meta.engagement.packageIntroSeen else { return }
        player.meta.engagement.packageIntroSeen = true
        self.player = player
        scheduleSave()
    }

    /// «¡Abrir!»: el paquete se gasta y a quién trae ya está decidido (la animación sólo lo demora).
    func openPackageFromPopup() {
        guard packagePopup?.arrivals.isEmpty == true, case let .opened(typeId, floorId) = openPackage() else { return }
        packagePopup?.arrivals = [PackageArrival(typeId: typeId, floorId: floorId)]
        markPackageIntroSeen()
        refreshPrizeAccess()
    }

    /// «Abrir todos»: los que entren, de una vez.
    func openAllPackagesFromPopup() {
        guard packagePopup?.arrivals.isEmpty == true else { return }
        var arrivals: [PackageArrival] = []
        while case let .opened(typeId, floorId) = openPackage() {
            arrivals.append(PackageArrival(typeId: typeId, floorId: floorId))
        }
        guard !arrivals.isEmpty else { return }
        packagePopup?.arrivals = arrivals
        markPackageIntroSeen()
        refreshPrizeAccess()
    }

    /// «Abrir otro» desde lo que salió: vuelve a la caja cerrada.
    func packagePopupOpenAnother() {
        guard packagePopup?.arrivals.isEmpty == false, packagesWaiting > 0 else { return }
        packagePopup = PackagePopup()
    }

    func closePackagePopup() {
        packagePopup = nil
    }

    /// Se ganó un paquete (visitante, Ruleta, evento): vuela al sello y avisa arriba. Los que caen
    /// solos del reloj no pasan por acá.
    func notePackagesWon(_ count: Int) {
        guard count > 0 else { return }
        packageWin = PackageWin(count: count)
        towerNotice = TowerNotice(kind: .packagesWon(count: count))
    }

    /// Un paquete cuyo empleado ya no entra cuando le toca el turno vuelve al
    /// buzón, aunque pase el tope: ya estaba ganado.
    func refundPackage() {
        guard var player else { return }
        player.meta.engagement.packages.waiting += 1
        self.player = player
        scheduleSave()
    }

    #if DEBUG
    func debugAddPackages(_ count: Int) {
        guard var player, count > 0 else { return }
        player.meta.engagement.packages.waiting += count
        self.player = player
    }
    #endif
}
