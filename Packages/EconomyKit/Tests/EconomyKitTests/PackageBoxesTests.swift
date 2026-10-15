import Foundation
import Testing
@testable import EconomyKit

/// E14b B18: cada caja pertenece a un piso y trae a alguien de ese piso. A quién trae se sortea
/// cuando aparece, y eso fija su piso y su lugar; abrirla da ese tipo, y el save viejo se migra.
@Suite("Paquete de la Aduana: la caja de cada piso")
struct PackageBoxesTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    /// Los dos pisos abiertos, todo visto y con lugar: pueden venir a, b, c_prog, c_law y d.
    private func open() throws -> (state: PlayerState, tower: TowerState, floorTable: FloorTable) {
        var fx = try fxStateAndTower(units: ["a": 1])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b", "c_prog", "c_law", "d"]
        return fx
    }

    private func occupancy(_ fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable)) -> [Int] {
        fx.tower.floors.map(\.occupiedCount)
    }

    @discardableResult
    private func assign(
        _ packages: inout PackagesState,
        _ fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable),
        seed: UInt64 = 7
    ) -> Int {
        var rng = SeededRNG(seed: seed)
        return PackageRoller.assignPending(
            &packages, state: fx.state, tiers: tiers, floorTable: fx.floorTable, config: fxConfig(),
            occupancy: occupancy(fx), windowTiers: 4, ratio: 2, using: &rng
        )
    }

    // MARK: El sorteo al aparecer

    @Test("el sorteo al aparecer fija el tipo y, con él, el piso de la caja; el lugar lo pone el piso")
    func theRollFixesTypeAndFloor() throws {
        let fx = try open()
        let eligible = PackageRoller.eligibleTypes(state: fx.state, tower: fx.tower, tiers: tiers,
                                                   floorTable: fx.floorTable, config: fxConfig())
        var rng = SeededRNG(seed: 20_261_015)
        var floors: Set<Int> = []
        for _ in 0..<400 {
            let box = try #require(PackageRoller.rollBox(eligible: eligible, windowTiers: 4, ratio: 2,
                                                         floorTable: fx.floorTable, using: &rng))
            let typeId = try #require(box.typeId)
            let type = try #require(tiers.type(id: typeId))
            #expect(eligible.contains { $0.id == type.id })
            let floor = try #require(box.floor)
            #expect(floor == fx.floorTable.ordinal(forTier: type.tier), "\(type.id) cayó en otro piso")
            #expect(box.spot == nil, "el lugar depende de las otras cajas del piso (PackagePlacer)")
            #expect(box.isAssigned)
            floors.insert(floor)
        }
        #expect(floors == [0, 1], "caen cajas en los dos pisos")
    }

    @Test("el tipo sale con las mismas chances de siempre")
    func theRollKeepsTheOdds() throws {
        let eligible = [fxType("a", tier: 1), fxType("b", tier: 2), fxType("d", tier: 4)]
        let floorTable = try fxFloorTable()
        let shown = PackageRoller.typeOdds(eligible: eligible, windowTiers: 4, ratio: 2)
        var rng = SeededRNG(seed: 99)
        var counts: [String: Int] = [:]
        let draws = 20_000
        for _ in 0..<draws {
            let box = try #require(PackageRoller.rollBox(eligible: eligible, windowTiers: 4, ratio: 2,
                                                         floorTable: floorTable, using: &rng))
            counts[box.typeId ?? "", default: 0] += 1
        }
        for row in shown {
            let share = Double(counts[row.typeId, default: 0]) / Double(draws)
            #expect(abs(share - row.probability) < 0.012, "\(row.typeId): sale \(share), la tabla dice \(row.probability)")
        }
    }

    @Test("sin nadie a quien traer no hay caja sorteada")
    func nothingEligibleRollsNoBox() throws {
        var rng = SeededRNG(seed: 1)
        let floorTable = try fxFloorTable()
        #expect(PackageRoller.rollBox(eligible: [], windowTiers: 4, ratio: 2,
                                      floorTable: floorTable, using: &rng) == nil)
    }

    @Test("el lugar de cada caja es al azar en los dos ejes: no caen todas en el mismo punto")
    func placesAreRandom() {
        var rng = SeededRNG(seed: 5)
        let spots = (0..<50).map { _ in PackagePlacer.place(among: [], in: .open, using: &rng) }
        let xs = spots.map(\.x)
        let ys = spots.map(\.y)
        #expect((xs.max() ?? 0) - (xs.min() ?? 0) > 0.5)
        #expect((ys.max() ?? 0) - (ys.min() ?? 0) > 0.5)
    }

    // MARK: Asentar las pendientes

    @Test("las que caen sin asignar se sortean al asentarse, y las ya sorteadas no se mueven")
    func pendingBoxesGetAssignedAndAssignedOnesStay() throws {
        let fx = try open()
        let kept = PackageBox(floor: 1, typeId: "d", x: 0.25, y: 0.6)
        var packages = PackagesState(boxes: [kept, .unassigned, .unassigned])
        #expect(assign(&packages, fx) == 2)
        #expect(packages.boxes.count == 3)
        #expect(packages.boxes[0] == kept, "la que ya estaba en su piso sigue igual, en su lugar")
        for box in packages.boxes {
            #expect(PackageRoller.belongs(box, state: fx.state, tiers: tiers, floorTable: fx.floorTable))
            #expect(box.spot != nil, "cada sorteada cae en un lugar")
        }
        let again = packages
        #expect(assign(&packages, fx, seed: 8) == 0, "asentar otra vez no vuelve a sortear")
        #expect(packages == again)
    }

    @Test("sin candidatos quedan sin asignar, y se sortean cuando hay lugar")
    func withoutCandidatesTheyWait() throws {
        var full = try fxStateAndTower(units: ["a": 5, "c_prog": 5])
        full.state.run.raiseFrontier(to: 4)
        full.state.run.seenTypes = ["a", "c_prog"]
        var packages = PackagesState(waiting: 2)
        #expect(assign(&packages, full) == 0)
        #expect(packages.boxes == [.unassigned, .unassigned])

        let roomy = try open()
        #expect(assign(&packages, roomy) == 2)
        #expect(packages.boxes.allSatisfy { $0.isAssigned })
    }

    @Test("una caja de un piso que se cerró (reencarnación) se vuelve a sortear entre los abiertos")
    func aLockedFloorRerollsItsBox() throws {
        var fx = try fxStateAndTower(units: ["a": 1], unlockedFloors: ["f1"])
        fx.state.run.raiseFrontier(to: 4)
        // `d` se vio (en otra vida): lo que la invalida es que su piso está cerrado.
        fx.state.run.seenTypes = ["a", "b", "d"]
        var packages = PackagesState(boxes: [PackageBox(floor: 1, typeId: "d", x: 0.5)])
        #expect(assign(&packages, fx) == 1)
        #expect(packages.boxes[0].floor == 0)
        #expect(["a", "b"].contains(packages.boxes[0].typeId ?? ""))
    }

    @Test("una caja vale si su tipo se vio, es de su piso y el piso está abierto; un piso lleno no la invalida")
    func belongsChecksTypeFloorAndRun() throws {
        let fx = try open()
        let belongs = { (box: PackageBox) in
            PackageRoller.belongs(box, state: fx.state, tiers: self.tiers, floorTable: fx.floorTable)
        }
        #expect(belongs(PackageBox(floor: 0, typeId: "a", x: 0.1)))
        #expect(belongs(PackageBox(floor: 1, typeId: "d", x: 0.1)))
        #expect(!belongs(PackageBox(floor: 0, typeId: "d", x: 0.1)), "d no es del primer piso")
        #expect(!belongs(PackageBox(floor: 1, typeId: "choice", x: 0.1)), "el nodo de carrera no es un empleado")
        #expect(!belongs(PackageBox(floor: 7, typeId: "a", x: 0.1)), "un piso que no existe")
        #expect(!belongs(PackageBox(floor: 0, typeId: "nadie", x: 0.1)))
        #expect(!belongs(.unassigned))

        var unseen = fx
        unseen.state.run.seenTypes = ["a"]
        #expect(!PackageRoller.belongs(PackageBox(floor: 0, typeId: "b", x: 0.1), state: unseen.state,
                                       tiers: tiers, floorTable: fx.floorTable), "no se vio en esta run")

        let full = try fxStateAndTower(units: ["a": 5])
        var fullState = full.state
        fullState.run.seenTypes = ["a"]
        #expect(PackageRoller.belongs(PackageBox(floor: 0, typeId: "a", x: 0.1), state: fullState,
                                      tiers: tiers, floorTable: full.floorTable), "lleno espera, no se resortea")
    }

    // MARK: Abrir y persistir

    @Test("abrir saca justo esa caja: las demás siguen con su piso, su tipo y su lugar")
    func openingRemovesThatBox() {
        let first = PackageBox(floor: 0, typeId: "a", x: 0.2)
        let second = PackageBox(floor: 1, typeId: "d", x: 0.7)
        let third = PackageBox(floor: 0, typeId: "b", x: 0.9)
        var packages = PackagesState(boxes: [first, second, third])
        let removed = packages.remove(second)
        #expect(removed)
        #expect(packages.boxes == [first, third])
        let again = packages.remove(second)
        #expect(!again, "ya no estaba")
        #expect(packages.boxes(onFloor: 0) == [first, third])
        #expect(packages.boxes(onFloor: 1).isEmpty)
    }

    @Test("cada piso tiene las suyas, la más vieja primero")
    func boxesByFloor() {
        let packages = PackagesState(boxes: [
            PackageBox(floor: 1, typeId: "d", x: 0.1), PackageBox(floor: 0, typeId: "a", x: 0.2),
            .unassigned, PackageBox(floor: 1, typeId: "c_prog", x: 0.3),
        ])
        #expect(packages.boxes(onFloor: 1).map(\.typeId) == ["d", "c_prog"])
        #expect(packages.boxes(onFloor: 0).map(\.typeId) == ["a"])
        #expect(packages.waiting == 4)
    }

    @Test("ida y vuelta por el save: piso, tipo, x e y intactos, y sigue escribiendo cuántas hay")
    func roundTrip() throws {
        let state = PackagesState(secondsUntilNext: 42, boxes: [
            PackageBox(floor: 1, typeId: "d", x: 0.25, y: 0.75), .unassigned, PackageBox(floor: 0, typeId: "a", x: 1, y: 0),
        ])
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(PackagesState.self, from: data) == state)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["waiting"] as? Int == 3, "una versión vieja de la app sigue viendo cuántas hay")
        let boxes = try #require(json["boxes"] as? [[String: Any]])
        #expect(boxes.first?["floor"] as? Int == 1)
        #expect(boxes.first?["typeId"] as? String == "d")
        #expect(boxes.first?["x"] as? Double == 0.25)
        #expect(boxes.first?["y"] as? Double == 0.75)
        #expect(boxes[1]["y"] == nil, "la sin asignar no escribe lugar")
    }

    @Test("un save viejo con waiting = N trae N cajas sin asignar, que se sortean al cargar")
    func anOldSaveMigrates() throws {
        let old = try JSONDecoder().decode(PackagesState.self, from: Data(#"{"secondsUntilNext": 30, "waiting": 3}"#.utf8))
        #expect(old.secondsUntilNext == 30)
        #expect(old.boxes == [.unassigned, .unassigned, .unassigned])
        var migrated = old
        let fx = try open()
        #expect(assign(&migrated, fx) == 3)
        #expect(migrated.waiting == 3)
        #expect(migrated.boxes.allSatisfy { $0.isAssigned })
    }

    @Test("un save con cajas manda sobre el contador viejo")
    func boxesWinOverTheLegacyCount() throws {
        let json = #"{"waiting": 5, "boxes": [{"floor": 0, "typeId": "a", "x": 0.5}]}"#
        let state = try JSONDecoder().decode(PackagesState.self, from: Data(json.utf8))
        #expect(state.boxes == [PackageBox(floor: 0, typeId: "a", x: 0.5)])
    }

    @Test("el contador suma cajas sin asignar y resta las más nuevas")
    func theCountSetter() {
        var state = PackagesState(boxes: [PackageBox(floor: 0, typeId: "a", x: 0.5)])
        state.waiting += 2
        #expect(state.boxes == [PackageBox(floor: 0, typeId: "a", x: 0.5), .unassigned, .unassigned])
        state.waiting -= 2
        #expect(state.boxes == [PackageBox(floor: 0, typeId: "a", x: 0.5)])
        state.waiting = -3
        #expect(state.boxes.isEmpty)
    }

    @Test("el reloj deja caer cajas sin asignar: a quién traen lo decide el estado de ese momento")
    func theClockDropsUnassignedBoxes() {
        var state = PackagesState(boxes: [PackageBox(floor: 0, typeId: "a", x: 0.5)])
        #expect(PackageScheduler.advance(&state, delta: 120, rateMultiplier: 1, config: fxPackages(maxWaiting: 3)) == 1)
        #expect(state.boxes == [PackageBox(floor: 0, typeId: "a", x: 0.5), .unassigned])
    }

    @Test("cambiar de piso no mueve nada: las cajas no dependen del piso que se mira")
    func boxesPersistAcrossFloorChanges() throws {
        let fx = try open()
        var packages = PackagesState(waiting: 4)
        assign(&packages, fx)
        let before = packages
        // Mirar otro piso no toca el estado; asentar de nuevo (cada tick) tampoco.
        assign(&packages, fx, seed: 1234)
        #expect(packages == before)
        let data = try JSONEncoder().encode(packages)
        #expect(try JSONDecoder().decode(PackagesState.self, from: data) == before)
    }

    // MARK: El lugar en el piso (E14b B22)

    /// La superficie de un teléfono: la caja ocupa un cuarto del ancho y medio fondo, y el visitante
    /// camina por el medio.
    private static let phoneArea = PackageFloorArea(
        gapX: 0.25, gapY: 0.4,
        keepOut: [PackageFloorArea.Zone(x: 0.35...0.65, y: 0.3...0.7), PackageFloorArea.Zone(x: 0.85...1, y: 0.8...1)]
    )

    @Test("el sorteo del lugar respeta la superficie, la separación entre cajas y las zonas prohibidas")
    func placementRespectsTheAreaAndTheGap() {
        var rng = SeededRNG(seed: 20_261_015)
        for _ in 0..<200 {
            var taken: [PackageSpot] = []
            for _ in 0..<3 {
                let spot = PackagePlacer.place(among: taken, in: Self.phoneArea, using: &rng)
                #expect((0...1).contains(spot.x) && (0...1).contains(spot.y), "fuera de la superficie: \(spot)")
                #expect(PackagePlacer.crowding(of: spot, among: taken, in: Self.phoneArea) == 0,
                        "con lugar libre cae separada y fuera de las zonas: \(spot) entre \(taken)")
                for zone in Self.phoneArea.keepOut { #expect(!zone.contains(spot)) }
                for other in taken {
                    let dx = (spot.x - other.x) / Self.phoneArea.gapX
                    let dy = (spot.y - other.y) / Self.phoneArea.gapY
                    #expect(dx * dx + dy * dy >= 1, "\(spot) pisa a \(other)")
                }
                taken.append(spot)
            }
        }
    }

    /// El mismo piso en un teléfono chico: menos fondo (la misma separación pesa más en fracciones)
    /// y la zona del visitante un poco más ancha.
    private static let smallPhoneArea = PackageFloorArea(
        gapX: 0.3, gapY: 0.6,
        keepOut: [PackageFloorArea.Zone(x: 0.3...0.7, y: 0.25...0.75), PackageFloorArea.Zone(x: 0.85...1, y: 0.7...1)]
    )

    @Test("con dos superficies, el lugar está libre en las dos: lo que en una separa el fondo no encima en la otra")
    func placementIsFreeOnEveryArea() {
        let areas = [Self.phoneArea, Self.smallPhoneArea]
        var rng = SeededRNG(seed: 20_261_016)
        for _ in 0..<200 {
            var taken: [PackageSpot] = []
            for _ in 0..<3 {
                let spot = PackagePlacer.place(among: taken, in: areas, using: &rng)
                for area in areas {
                    #expect(PackagePlacer.crowding(of: spot, among: taken, in: area) == 0, "\(spot) entre \(taken)")
                }
                taken.append(spot)
            }
        }
        // Dos cajas separadas sólo por el fondo en el teléfono grande se enciman en el chico.
        let front = PackageSpot(x: 0.1, y: 0.1)
        let behind = PackageSpot(x: 0.1, y: 0.55)
        #expect(PackagePlacer.crowding(of: behind, among: [front], in: Self.phoneArea) == 0)
        #expect(PackagePlacer.crowding(of: behind, among: [front], in: Self.smallPhoneArea) > 0)
        #expect(PackagePlacer.crowding(of: behind, among: [front], in: areas) > 0, "no vale: en el chico se pisan")
        #expect(PackagePlacer.crowding(of: behind, among: [front], in: []) == 0, "sin superficies, cualquier lugar")
    }

    @Test("asentar con dos superficies por piso ubica cada caja libre en las dos")
    func assigningUsesEveryArea() throws {
        let fx = try open()
        var packages = PackagesState(boxes: [.unassigned, .unassigned, .unassigned])
        var rng = SeededRNG(seed: 12)
        PackageRoller.assignPending(
            &packages, state: fx.state, tiers: tiers, floorTable: fx.floorTable, config: fxConfig(),
            occupancy: occupancy(fx), windowTiers: 4, ratio: 2,
            areas: { _ in [Self.phoneArea, Self.smallPhoneArea] }, using: &rng
        )
        for floor in Set(packages.boxes.compactMap(\.floor)) {
            let spots = packages.boxes(onFloor: floor).compactMap(\.spot)
            for (index, spot) in spots.enumerated() {
                let rest = spots.enumerated().filter { $0.offset != index }.map(\.element)
                #expect(PackagePlacer.crowding(of: spot, among: rest, in: Self.smallPhoneArea) == 0)
                #expect(PackagePlacer.crowding(of: spot, among: rest, in: Self.phoneArea) == 0)
            }
        }
    }

    @Test("con el piso lleno igual cae, en el lugar que menos se pisa")
    func aCrowdedFloorStillDrops() {
        let tight = PackageFloorArea(gapX: 0.9, gapY: 0.9, keepOut: [])
        let taken = [PackageSpot(x: 0, y: 0), PackageSpot(x: 1, y: 1), PackageSpot(x: 0, y: 1), PackageSpot(x: 1, y: 0)]
        var rng = SeededRNG(seed: 3)
        let spot = PackagePlacer.place(among: taken, in: tight, using: &rng)
        #expect((0...1).contains(spot.x) && (0...1).contains(spot.y))
        let crowding = PackagePlacer.crowding(of: spot, among: taken, in: tight)
        #expect(crowding > 0, "no hay lugar libre: se pisa con alguna")
        let corner = PackagePlacer.crowding(of: PackageSpot(x: 0.02, y: 0.02), among: taken, in: tight)
        #expect(crowding < corner, "prefiere el lugar con menos superposición: \(crowding) contra \(corner)")
    }

    @Test("asentar ubica cada caja nueva lejos de las de su piso; las de otro piso no cuentan")
    func assigningPlacesEachBoxOnItsFloor() throws {
        let fx = try open()
        let other = PackageBox(floor: 1, typeId: "d", x: 0.1, y: 0.1)
        var packages = PackagesState(boxes: [other, .unassigned, .unassigned, .unassigned])
        var rng = SeededRNG(seed: 11)
        PackageRoller.assignPending(
            &packages, state: fx.state, tiers: tiers, floorTable: fx.floorTable, config: fxConfig(),
            occupancy: occupancy(fx), windowTiers: 4, ratio: 2, areas: { _ in [Self.phoneArea] }, using: &rng
        )
        #expect(packages.boxes[0] == other)
        for floor in [0, 1] {
            let spots = packages.boxes(onFloor: floor).compactMap(\.spot)
            #expect(spots.count == packages.boxes(onFloor: floor).count, "todas las del piso \(floor) tienen lugar")
            for (index, spot) in spots.enumerated() {
                let rest = spots.enumerated().filter { $0.offset != index }.map(\.element)
                #expect(PackagePlacer.crowding(of: spot, among: rest, in: Self.phoneArea) == 0)
            }
        }
    }

    @Test("un save de B18 sin y carga bien: conserva piso y tipo, y su lugar se sortea al asentar")
    func aB18SaveWithoutYLoads() throws {
        let json = #"{"secondsUntilNext": 12, "waiting": 2, "boxes": [{"floor": 0, "typeId": "a", "x": 0.3}, {"floor": 1, "typeId": "d", "x": 0.9}]}"#
        var loaded = try JSONDecoder().decode(PackagesState.self, from: Data(json.utf8))
        #expect(loaded.secondsUntilNext == 12)
        #expect(loaded.boxes.map(\.typeId) == ["a", "d"])
        #expect(loaded.boxes.map(\.floor) == [0, 1])
        #expect(loaded.boxes.allSatisfy { $0.y == nil && $0.spot == nil })
        let fx = try open()
        #expect(assign(&loaded, fx) == 2, "las dos se ubican")
        #expect(loaded.boxes.map(\.typeId) == ["a", "d"], "no se vuelven a sortear: siguen trayendo al mismo")
        #expect(loaded.boxes.map(\.floor) == [0, 1])
        #expect(loaded.boxes.allSatisfy { $0.spot != nil })
        #expect(assign(&loaded, fx, seed: 99) == 0, "ya ubicadas, no se mueven")
        let data = try JSONEncoder().encode(loaded)
        #expect(try JSONDecoder().decode(PackagesState.self, from: data) == loaded)
    }
}
