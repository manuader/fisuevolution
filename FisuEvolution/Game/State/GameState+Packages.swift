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
/// `box` es la caja que abre (E14b B18): la del piso que se mira o la más vieja.
struct PackagePopup: Identifiable, Equatable {
    let id = UUID()
    var box: PackageBox?
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

/// El Paquete de la Aduana en la partida (PLAN-v2 E5). Desde E14b B18 cada caja es de un piso:
/// a quién trae se sortea cuando aparece, y eso fija en qué piso cae y dónde se para.
extension GameState {
    var packagesWaiting: Int { player?.meta.engagement.packages.waiting ?? 0 }

    /// Las cajas que esperan, la más vieja primero.
    var packageBoxes: [PackageBox] { player?.meta.engagement.packages.boxes ?? [] }

    /// A quién podría traer un paquete ahora: lo que FisuJobs vende con lugar.
    var packageCandidates: [CharacterType] {
        guard let content, let player else { return [] }
        return PackageRoller.eligibleTypes(
            state: player, tiers: content.tiers, floorTable: content.floorTable, config: content.economy,
            occupancy: packageOccupancy
        )
    }

    /// Cuántos hay en cada piso, contando las llegadas ya encoladas.
    private var packageOccupancy: [Int] {
        guard let tower else { return [] }
        return tower.floors.map(\.occupiedCount).enumerated().map { $0.element + queuedArrivals(onFloor: $0.offset) }
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

    // MARK: - La caja de cada piso (E14b B18)

    /// El piso de una caja, si ya está sorteada y sigue valiendo en esta run. `nil` = sin asignar:
    /// se dibuja en el piso que se mira y se sortea al abrirla.
    func packageFloor(of box: PackageBox) -> Int? {
        guard let content, let player,
              PackageRoller.belongs(box, state: player, tiers: content.tiers, floorTable: content.floorTable)
        else { return nil }
        return box.floor
    }

    /// Las cajas que se ven en el piso `ordinal`: las suyas y, en el que se mira, las sin asignar.
    func visiblePackageBoxes(onFloor ordinal: Int) -> [PackageBox] {
        packageBoxes.filter { box in
            packageFloor(of: box).map { $0 == ordinal } ?? (ordinal == visibleFloorOrdinal)
        }
    }

    /// Los pisos que tienen alguna caja sorteada (la marca del ascensor).
    var packageFloorOrdinals: Set<Int> {
        Set(packageBoxes.compactMap { packageFloor(of: $0) })
    }

    /// Si abrirla ahora trae a alguien: la sorteada, si su piso tiene lugar; la sin asignar, si
    /// hay a quién traer.
    func packageBoxOpenable(_ box: PackageBox) -> Bool {
        guard let content else { return false }
        guard let floor = packageFloor(of: box) else { return !packageCandidates.isEmpty }
        let occupancy = packageOccupancy
        return occupancy.indices.contains(floor) && occupancy[floor] < content.floorTable[floor].capacity
    }

    /// La caja que abren la columna y Regalos (D5): la del piso que se mira y, si en ese piso no hay
    /// una que entre, la más vieja de la torre que sí entra (la pantalla lleva a su piso). Si ninguna
    /// entra, la de este piso o la más vieja, para explicar el LLENO.
    var packageTarget: PackageBox? {
        let here = visiblePackageBoxes(onFloor: visibleFloorOrdinal)
        return here.first(where: packageBoxOpenable) ?? packageBoxes.first(where: packageBoxOpenable)
            ?? here.first ?? packageBoxes.first
    }

    /// Hay paquetes esperando y ninguno entra: el cartel "LLENO".
    var packagesBlocked: Bool { packagesWaiting > 0 && !packageBoxes.contains(where: packageBoxOpenable) }

    /// La caja de la pantalla no entra: la pantalla dice LLENO.
    var packagePopupBlocked: Bool {
        guard let box = packagePopup.flatMap({ popupBox($0) }) else { return packagesBlocked }
        return !packageBoxOpenable(box)
    }

    /// A quién trae la caja de la pantalla y a qué piso llega (B18: ya está decidido). `nil` si la
    /// caja todavía no se sorteó: la pantalla muestra la tabla de lo que puede venir.
    var packagePopupArrival: PackageArrival? {
        guard let content, let popup = packagePopup, let box = popupBox(popup),
              let floor = packageFloor(of: box), let typeId = box.typeId
        else { return nil }
        return PackageArrival(typeId: typeId, floorId: content.floorTable[floor].id)
    }

    /// La caja de la pantalla, si sigue esperando; si no, la que abriría la columna.
    private func popupBox(_ popup: PackagePopup) -> PackageBox? {
        if let box = popup.box, packageBoxes.contains(box) { return box }
        return packageTarget
    }

    /// Las reglas de la caída en el piso `ordinal` (E14b B22): las superficies del teléfono de
    /// referencia y del SE con el fondo de ese piso. El lugar se guarda en fracciones y tiene que
    /// quedar libre en las dos: así vale en cualquier pantalla. El colchón de ese piso (B24) ocupa
    /// su lugar como una caja más.
    func packageAreas(onFloor ordinal: Int) -> [PackageFloorArea] {
        guard let floors = content?.floorTable.floors, floors.indices.contains(ordinal) else { return [] }
        let floor = floors[ordinal]
        let areas = PickupLayout.placementAreas(background: floor.background, backgroundOffset: floor.backgroundOffset)
        guard mattressFloor == ordinal, let mattress = mattressSpot else { return areas }
        return areas.map { $0.keepingClear(of: mattress) }
    }

    /// Sortea las cajas que cayeron sin asignar y las que dejaron de valer (una reencarnación
    /// cierra los pisos), con el estado de ahora, y ubica en su piso las que no tienen lugar (las
    /// de un save de B18 vienen sin y). Devuelve cuántas cayeron en un lugar nuevo.
    @discardableResult
    func settlePackageBoxes() -> Int {
        guard let content, var player else { return 0 }
        var packages = player.meta.engagement.packages
        guard packages.boxes.contains(where: {
            !PackageRoller.belongs($0, state: player, tiers: content.tiers, floorTable: content.floorTable)
                || ($0.isAssigned && $0.spot == nil)
        }) else { return 0 }
        let assigned = PackageRoller.assignPending(
            &packages, state: player, tiers: content.tiers, floorTable: content.floorTable, config: content.economy,
            occupancy: packageOccupancy, windowTiers: content.packages.windowTiers,
            ratio: content.packages.tierRatio(bestSupplierLevel: bestSupplierLevel),
            areas: { self.packageAreas(onFloor: $0) }, using: &rng
        )
        // Una que dejó de valer y no tiene a quién traer queda sin asignar: también se guarda.
        guard packages != player.meta.engagement.packages else { return 0 }
        player.meta.engagement.packages = packages
        self.player = player
        if assigned > 0 { Log.economy.info("packages assigned: \(assigned)") }
        return assigned
    }

    /// El reloj de juego activo. Lo llama `advanceEngagement` con el delta del tick. Lo que cae se
    /// sortea en el acto: su piso, su tipo y su lugar quedan fijos hasta que se abre.
    func advancePackages(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        let rate = ModifierMath.factor(player.run.activeModifiers, effect: .packageRateMultiplier, now: now)
        let dropped = PackageScheduler.advance(
            &player.meta.engagement.packages, delta: delta, rateMultiplier: rate, config: content.packages
        )
        self.player = player
        let assigned = settlePackageBoxes()
        guard dropped > 0 || assigned > 0 else { return }
        if dropped > 0 { Log.economy.info("package dropped: \(player.meta.engagement.packages.waiting) waiting") }
        scheduleSave()
    }

    /// Abre una caja (la de `packageTarget` sin `box`): trae al que se sorteó cuando apareció y deja
    /// su llegada en el embudo. Una sin asignar se sortea ahora. El paquete se gasta sólo si
    /// alguien entra; si su piso está lleno, LLENO y la caja se queda.
    @discardableResult
    func openPackage(_ box: PackageBox? = nil) -> PackageOpenResult {
        guard let content, var player, let tower, let box = box ?? packageTarget,
              player.meta.engagement.packages.boxes.contains(box)
        else { return .noneWaiting }
        let typeId: String?
        if packageFloor(of: box) != nil {
            typeId = packageBoxOpenable(box) ? box.typeId : nil
        } else {
            let ratio = content.packages.tierRatio(bestSupplierLevel: bestSupplierLevel)
            typeId = PackageRoller.roll(
                eligible: packageCandidates, windowTiers: content.packages.windowTiers, ratio: ratio, using: &rng
            )?.id
        }
        guard let typeId,
              let change = BoardChangePlanner.planArrival(
                  typeId: typeId, state: player, tower: tower, tiers: content.tiers,
                  floorTable: content.floorTable, origin: .package
              )
        else {
            haptics?.play(.error)
            audio?.play(.error)
            return .full
        }
        player.meta.engagement.packages.remove(box)
        self.player = player
        enqueueBoardChange(change)
        haptics?.play(.purchase)
        scheduleSave()
        Log.economy.info("package opened: \(typeId)")
        let floorId = floorOrdinal(of: change).map { content.floorTable[$0].id } ?? ""
        return .opened(typeId: typeId, floorId: floorId)
    }

    /// El sello o Regalos (`box` nil) o la caja del tablero: abre la pantalla del paquete con su caja.
    /// La de la columna es la del piso que se mira; si ahí no hay, la cámara viaja al piso de la más
    /// vieja (D5, B18). Sin lugar también abre, a explicarlo. `false` si no había nada que abrir o
    /// algo más ocupa la pantalla.
    @discardableResult
    func packageTapped(box: PackageBox? = nil) -> Bool {
        tutorialTipCompleted(.packages)
        guard packagesWaiting > 0, packagePopup == nil, mattressPopup == nil, wheelSheet == nil else { return false }
        presentPackagePopup(box: box)
        refreshPrizeAccess()
        return true
    }

    /// La pantalla con su caja, en su piso.
    private func presentPackagePopup(box: PackageBox?) {
        let target = box.flatMap { packageBoxes.contains($0) ? $0 : nil } ?? packageTarget
        if let target, let floor = packageFloor(of: target), floor != visibleFloorOrdinal {
            setVisibleFloor(floor)
        }
        packagePopup = PackagePopup(box: target)
    }

    /// La caja del tablero (E14b B5, D2): la primera vez, la pantalla de C28; desde la segunda,
    /// `.openInPlace` y la escena la abre ahí mismo. Todavía no gasta nada: el paquete se gasta
    /// cuando la caja termina de abrirse (`openPackageOnBoard`). La columna y Regalos siguen
    /// por `packageTapped` (D5).
    /// `box` es la caja tocada (B18: cada una trae a alguien de su piso); sin ella, `packageTarget`.
    @discardableResult
    func boardPackageTapped(box: PackageBox? = nil) -> BoardPackageTap {
        guard packageIntroSeen else { return packageTapped(box: box) ? .popup : .refused }
        tutorialTipCompleted(.packages)
        guard packagesWaiting > 0, packagePopup == nil, mattressPopup == nil, wheelSheet == nil,
              let box = box ?? packageTarget, packageBoxes.contains(box)
        else { return .refused }
        guard packageBoxOpenable(box) else {
            noteBoardPackageFull()
            return .full
        }
        return .openInPlace
    }

    /// La caja del tablero terminó de abrirse: se gasta y el empleado sale hacia su lugar, sin pop-up.
    /// Si en el medio se llenó su piso, no se gasta y avisa arriba.
    @discardableResult
    func openPackageOnBoard(box: PackageBox? = nil) -> PackageOpenResult {
        let result = openPackage(box)
        if result == .full { noteBoardPackageFull() }
        refreshPrizeAccess()
        return result
    }

    /// El empleado asoma de la caja del tablero (E14b B23): el resorte.
    func packageExitPoppedOut() {
        audio?.play(.packagePopOut)
    }

    /// Y aterriza a su lado: el golpe y un toque en la mano.
    func packageExitLanded() {
        audio?.play(.packageLand)
        haptics?.play(.tick)
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
        guard let popup = packagePopup, popup.arrivals.isEmpty,
              case let .opened(typeId, floorId) = openPackage(popupBox(popup))
        else { return }
        packagePopup?.arrivals = [PackageArrival(typeId: typeId, floorId: floorId)]
        markPackageIntroSeen()
        refreshPrizeAccess()
    }

    /// «Abrir todos»: los que entren, de una vez, cada uno a su piso.
    func openAllPackagesFromPopup() {
        guard packagePopup?.arrivals.isEmpty == true else { return }
        var arrivals: [PackageArrival] = []
        while let box = packageBoxes.first(where: packageBoxOpenable),
              case let .opened(typeId, floorId) = openPackage(box) {
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
        presentPackagePopup(box: nil)
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
    /// buzón, aunque pase el tope: ya estaba ganado. Vuelve con el mismo empleado, a su piso, y
    /// cae en un lugar libre de ese piso (`settlePackageBoxes`).
    func refundPackage(_ change: BoardChange? = nil) {
        guard var player else { return }
        var box = PackageBox.unassigned
        if case let .arrival(typeId)? = change?.kind, let content, let type = content.tiers.type(id: typeId) {
            box = PackageBox(floor: content.floorTable.ordinal(forTier: type.tier), typeId: typeId)
        }
        player.meta.engagement.packages.boxes.append(box)
        self.player = player
        settlePackageBoxes()
        scheduleSave()
    }

    #if DEBUG
    func debugAddPackages(_ count: Int) {
        guard var player, count > 0 else { return }
        player.meta.engagement.packages.waiting += count
        self.player = player
        settlePackageBoxes()
    }

    /// `count` cajas que traen a alguien del piso `floorId` (`--uitest-package-floor=urban` o
    /// `=alley:3`): el de tier más bajo de ese piso, marcado como visto para que la caja valga. Cada
    /// una cae en un lugar libre de ese piso, como las del reloj (B22).
    func debugDropPackage(onFloor floorId: String, count: Int = 1) {
        guard let content, var player, count > 0,
              let ordinal = content.floorTable.floors.firstIndex(where: { $0.id == floorId }),
              let type = content.tiers.concreteTypes
                  .filter({ content.floorTable.ordinal(forTier: $0.tier) == ordinal })
                  .min(by: { $0.tier < $1.tier })
        else { return }
        player.run.markSeen(type.id)
        for _ in 0..<count {
            player.meta.engagement.packages.boxes.append(PackageBox(floor: ordinal, typeId: type.id))
            PackagePlacer.placeMissing(&player.meta.engagement.packages,
                                       areas: { self.packageAreas(onFloor: $0) }, using: &rng)
        }
        self.player = player
    }

    /// La fixture `--uitest-package-floor=<piso>[:<cuántas>]`.
    func debugDropPackages(fixture: String) {
        let parts = fixture.split(separator: ":")
        guard let floorId = parts.first else { return }
        debugDropPackage(onFloor: String(floorId), count: parts.count > 1 ? Int(parts[1]) ?? 1 : 1)
    }
    #endif
}
