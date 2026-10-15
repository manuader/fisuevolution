import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

/// E14b B18: cada caja pertenece a un piso y trae a alguien de ese piso. Se dibuja sólo en el suyo,
/// en su lugar, se va con su piso en el viaje del ascensor, y abrirla trae a quien se sorteó al caer.
@Suite("La caja de cada piso (E14b B18)")
@MainActor
struct PackageFloorsTests {
    private static let scene = CGSize(width: 393, height: 852)

    /// La torre abierta y vista hasta el tier 12: varios pisos con lugar.
    private func tower() async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        gameState.debugMarkTypesSeen(throughTier: 12)
        return gameState
    }

    private func pickups() async -> (GameState, PickupController) {
        let gameState = await tower()
        let controller = PickupController(gameState: gameState, pool: VideoPlayerPool(policy: .allowAll.with(.reduceMotion)))
        controller.attach(to: SKNode())
        controller.layout(sceneSize: Self.scene, bottomInset: 118, cellSize: 72)
        return (gameState, controller)
    }

    private func ordinal(of floorId: String, in gameState: GameState) throws -> Int {
        try #require(gameState.content?.floorTable.floors.firstIndex { $0.id == floorId })
    }

    /// La superficie de un piso con el fondo de ese piso.
    private func layout(onFloor ordinal: Int, in gameState: GameState) throws -> PickupLayout {
        let floor = try #require(gameState.content?.floorTable[ordinal])
        return PickupLayout(sceneSize: Self.scene, bottomInset: 118, cellSize: 72,
                            background: floor.background, backgroundOffset: floor.backgroundOffset)
    }

    /// Donde se para una caja de un piso con el fondo de ese piso (E14b B22: su x y su y).
    private func spot(onFloor ordinal: Int, of box: PackageBox, in gameState: GameState) throws -> CGPoint {
        try layout(onFloor: ordinal, in: gameState).packagePosition(at: box.spot)
    }

    // MARK: Dónde se dibuja

    @Test("la caja de otro piso no se ve en el callejón; en su piso está, en su lugar")
    func aBoxIsDrawnOnlyOnItsFloor() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugDropPackage(onFloor: "urban")
        let urban = try ordinal(of: "urban", in: gameState)
        let box = try #require(gameState.packageBoxes.first)
        #expect(box.floor == urban)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.isEmpty, "en el callejón no hay ninguna")
        #expect(controller.boxes(onFloor: urban).isEmpty, "la del urbano no se dibuja con la cámara en el callejón")
        #expect(gameState.boardPackageMarker.isEmpty)

        gameState.setVisibleFloor(urban)
        controller.update(delta: 1, reduceMotion: true)
        let node = try #require(controller.boxes.first)
        #expect(node.packageBox == box)
        let expected = try spot(onFloor: urban, of: box, in: gameState)
        #expect(abs(node.position.x - expected.x) < 0.01, "en su x")
        #expect(abs(node.position.y - expected.y) < 0.01, "en su y, sobre la superficie de su piso")
        #expect(gameState.boardPackageMarker.contains(","))
    }

    @Test("en el viaje del ascensor la caja se va con su piso: no flota entre pisos")
    func aBoxTravelsWithItsFloor() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugDropPackage(onFloor: "urban")
        let urban = try ordinal(of: "urban", in: gameState)
        let box = try #require(gameState.packageBoxes.first)
        let rest = try spot(onFloor: urban, of: box, in: gameState)
        gameState.setVisibleFloor(urban)
        let height = Self.scene.height
        // La cámara todavía en el piso de abajo, a mitad de camino, y llegada.
        for progress in [0.0, 0.25, 0.5, 1.0] {
            let camera = (CGFloat(urban) - 1 + CGFloat(progress)) * height
            controller.update(delta: 1.0 / 60, reduceMotion: true, cameraOffsetY: camera)
            let node = try #require(controller.boxes(onFloor: urban).first, "a \(progress) del viaje")
            #expect(abs(node.position.y - (rest.y + CGFloat(urban) * height - camera)) < 0.01,
                    "a \(progress) del viaje la caja se corre igual que su piso")
            #expect(abs(node.position.x - rest.x) < 0.01)
        }
        #expect(controller.boxes(onFloor: urban - 1).isEmpty, "en el piso de abajo no se dibujó ninguna")
    }

    @Test("lejos del piso de la caja (la cámara en otro piso) no se dibuja")
    func farFloorsAreNotDrawn() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugDropPackage(onFloor: "corporate")
        let corporate = try ordinal(of: "corporate", in: gameState)
        controller.update(delta: 1, reduceMotion: true, cameraOffsetY: 0)
        #expect(controller.boxes(onFloor: corporate).isEmpty)
    }

    @Test("cada piso con las suyas, cada una en su lugar y separadas de las otras del piso (E14b B22)")
    func eachFloorHasItsBoxesApart() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugDropPackage(onFloor: "alley")
        gameState.debugDropPackage(onFloor: "urban", count: 3)
        let urban = try ordinal(of: "urban", in: gameState)
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.count == 1, "en el callejón, sólo la suya")
        gameState.setVisibleFloor(urban)
        controller.update(delta: 1, reduceMotion: true)
        let nodes = controller.boxes
        #expect(nodes.count == 3)
        #expect(nodes.allSatisfy { $0.packageBox?.floor == urban })
        let areas = gameState.packageAreas(onFloor: urban)
        let spots = nodes.compactMap { $0.packageBox?.spot }
        #expect(spots.count == 3)
        for (index, spot) in spots.enumerated() {
            let others = spots.enumerated().filter { $0.offset != index }.map(\.element)
            #expect(PackagePlacer.crowding(of: spot, among: others, in: areas) == 0, "\(spot) pisa a otra o a una zona prohibida")
        }
    }

    @Test("el lugar de las cajas del save: GameState las ubica con la superficie de su piso, en la referencia y en el SE")
    func gameStatePlacesWithTheFloorArea() async throws {
        let gameState = await tower()
        let urban = try ordinal(of: "urban", in: gameState)
        let floor = try #require(gameState.content?.floorTable[urban])
        let reference = PickupLayout.reference(background: floor.background, backgroundOffset: floor.backgroundOffset)
        let smallest = PickupLayout.smallest(background: floor.background, backgroundOffset: floor.backgroundOffset)
        #expect(gameState.packageAreas(onFloor: urban) == [reference.packageArea, smallest.packageArea])
        #expect(gameState.packageAreas(onFloor: 999).isEmpty)
    }

    @Test("tres cajas de cada piso quedan separadas también en el SE: ni encimadas, ni sobre el visitante o el colchón")
    func boxesStayApartOnTheSE() async throws {
        let gameState = await tower()
        let floors = try #require(gameState.content?.floorTable.floors)
        var rng = SystemRandomNumberGenerator()
        for (ordinal, floor) in floors.enumerated() {
            let areas = gameState.packageAreas(onFloor: ordinal)
            let smallest = PickupLayout.smallest(background: floor.background, backgroundOffset: floor.backgroundOffset)
            let depth = smallest.packageFeetRange.upperBound - smallest.packageFeetRange.lowerBound
            #expect(depth > 0, "\(floor.id): el SE tiene fondo, así que las zonas se esquivan por y")
            for _ in 0..<20 {
                var taken: [PackageSpot] = []
                for _ in 0..<PickupLayout.maxVisibleBoxes {
                    let spot = PackagePlacer.place(among: taken, in: areas, using: &rng)
                    #expect(PackagePlacer.crowding(of: spot, among: taken, in: smallest.packageArea) == 0,
                            "\(floor.id) \(spot): en el SE se pisa con \(taken) o con una zona prohibida")
                    // En puntos del SE: ninguna se mete en la elipse de otra (un lado de costado, medio de fondo).
                    let feet = smallest.packageFeet(at: spot)
                    for other in taken.map({ smallest.packageFeet(at: $0) }) {
                        let dx = (feet.x - other.x) / (smallest.side * PickupLayout.boxGapSides)
                        let dy = (feet.y - other.y) / (smallest.side * PickupLayout.boxDepthGapSides)
                        #expect(dx * dx + dy * dy >= 0.999, "\(floor.id): dos cajas encimadas en el SE")
                    }
                    taken.append(spot)
                }
            }
        }
    }

    @Test("un save de B18 sin y: al asentar cada caja conserva su piso y a quién trae, y cae en un lugar")
    func aB18SaveIsPlacedOnLoad() async throws {
        let gameState = await tower()
        let content = try #require(gameState.content)
        let urban = try ordinal(of: "urban", in: gameState)
        let type = try #require(content.tiers.concreteTypes.first { content.floorTable.ordinal(forTier: $0.tier) == urban })
        gameState.player?.run.markSeen(type.id)
        gameState.player?.meta.engagement.packages = PackagesState(boxes: [
            PackageBox(floor: urban, typeId: type.id, x: 0.5), PackageBox(floor: urban, typeId: type.id, x: 0.5),
        ])
        #expect(gameState.settlePackageBoxes() == 2)
        #expect(gameState.packageBoxes.allSatisfy { $0.floor == urban && $0.typeId == type.id && $0.spot != nil })
        #expect(gameState.settlePackageBoxes() == 0, "ya ubicadas no se mueven")
    }

    @Test("abrir la del tablero de otro piso trae a ese, y la caja se va")
    func openingTheBoardBoxOfAFloor() async throws {
        let (gameState, controller) = await pickups()
        gameState.player?.meta.engagement.packageIntroSeen = true
        gameState.debugDropPackage(onFloor: "urban")
        let urban = try ordinal(of: "urban", in: gameState)
        let box = try #require(gameState.packageBoxes.first)
        gameState.setVisibleFloor(urban)
        controller.update(delta: 1, reduceMotion: true)
        let node = try #require(controller.boxes.first)
        #expect(controller.handleTap(at: node.position))
        #expect(controller.boxes.isEmpty)
        let arrival = try #require(gameState.pendingBoardChanges.first { $0.origin == .package })
        #expect(arrival.kind == .arrival(typeId: box.typeId ?? ""))
        #expect(gameState.floorOrdinal(of: arrival) == urban)
    }

    // MARK: Abrir

    @Test("abrir una caja de un piso da sí o sí al que se sorteó, en ese piso")
    func openingGivesThatType() async throws {
        let gameState = await tower()
        gameState.debugAddPackages(6)
        for box in gameState.packageBoxes {
            let floor = try #require(box.floor)
            let typeId = try #require(box.typeId)
            guard case let .opened(opened, floorId) = gameState.openPackage(box) else {
                Issue.record("la caja de \(typeId) no se abrió")
                continue
            }
            #expect(opened == typeId)
            #expect(floorId == gameState.content?.floorTable[floor].id)
        }
        #expect(gameState.packagesWaiting == 0)
    }

    @Test("el sorteo al caer fija el tipo entre los candidatos y el piso es el del tipo")
    func droppedBoxesAreDecided() async throws {
        let gameState = await tower()
        let candidates = Set(gameState.packageCandidates.map(\.id))
        gameState.debugAddPackages(8)
        let content = try #require(gameState.content)
        for box in gameState.packageBoxes {
            let typeId = try #require(box.typeId)
            #expect(candidates.contains(typeId))
            let type = try #require(content.tiers.type(id: typeId))
            #expect(box.floor == content.floorTable.ordinal(forTier: type.tier))
        }
    }

    @Test("con su piso lleno no se abre, aunque otro piso tenga lugar")
    func aFullFloorKeepsItsBox() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        let box = try #require(gameState.packageBoxes.first)
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        #expect(gameState.openPackage(box) == .full)
        #expect(gameState.packageBoxes == [box], "la caja se queda, con su tipo")
    }

    @Test("si al llegar su turno ya no entra, vuelve la misma caja: el mismo empleado, a su piso")
    func aStaleArrivalRefundsTheSameBox() async throws {
        let gameState = await tower()
        gameState.debugDropPackage(onFloor: "urban")
        let box = try #require(gameState.packageBoxes.first)
        _ = gameState.openPackage(box)
        let change = try #require(gameState.pendingBoardChanges.last)
        gameState.discardBoardChange(change)
        let back = try #require(gameState.packageBoxes.first)
        #expect(back.typeId == box.typeId)
        #expect(back.floor == box.floor)
    }

    // MARK: La columna y Regalos (D5)

    @Test("la columna abre la del piso que mirás; si ahí no hay, te lleva al piso de la más vieja")
    func theRailTakesYouToTheBox() async throws {
        let gameState = await tower()
        gameState.debugDropPackage(onFloor: "urban")
        let urban = try ordinal(of: "urban", in: gameState)
        let box = try #require(gameState.packageBoxes.first)
        #expect(gameState.visibleFloorOrdinal == 0)
        #expect(gameState.packageTapped())
        #expect(gameState.visibleFloorOrdinal == urban, "viajó al piso de la caja")
        #expect(gameState.packagePopup?.box == box)
        #expect(gameState.packagePopupArrival?.typeId == box.typeId)
        #expect(gameState.packagePopupArrival?.floorId == "urban")
        gameState.openPackageFromPopup()
        #expect(gameState.packagePopup?.arrivals.first?.typeId == box.typeId)
        gameState.closePackagePopup()

        gameState.debugDropPackage(onFloor: "urban")
        gameState.debugDropPackage(onFloor: "alley")
        gameState.setVisibleFloor(0)
        let alleyBox = try #require(gameState.packageBoxes.last)
        #expect(gameState.packageTarget == alleyBox, "con una en el piso que mirás, abre esa")
        #expect(gameState.packageTapped())
        #expect(gameState.visibleFloorOrdinal == 0)
        #expect(gameState.packagePopup?.box == alleyBox)
    }

    // MARK: Asentar

    @Test("un save viejo con cajas sin asignar las sortea con la regla nueva")
    func legacyBoxesGetAssigned() async throws {
        let gameState = await tower()
        gameState.player?.meta.engagement.packages = PackagesState(waiting: 3)
        #expect(gameState.settlePackageBoxes() == 3)
        #expect(gameState.packageBoxes.allSatisfy { $0.isAssigned })
        #expect(gameState.packageFloorOrdinals.isSubset(of: Set(0..<(gameState.content?.floorTable.count ?? 0))))
    }

    @Test("una caja de un piso que se cerró (reencarnación) se vuelve a sortear entre los abiertos")
    func lockedFloorsReroll() async throws {
        let gameState = await tower()
        gameState.debugDropPackage(onFloor: "urban")
        let alley = try #require(gameState.content?.floorTable[0].id)
        gameState.player?.run.unlockedFloors = [alley]
        #expect(gameState.packageFloorOrdinals.isEmpty, "la del urbano ya no vale")
        gameState.settlePackageBoxes()
        let box = try #require(gameState.packageBoxes.first)
        #expect(box.floor == 0)
    }

    @Test("ganar cajas (Lluvia, visitante, Ruleta): cada una se sortea y cae en su piso")
    func wonBoxesAreDecided() async throws {
        let gameState = await tower()
        gameState.grant(.package(3), source: "visit.puntero_bolson")
        #expect(gameState.packagesWaiting == 3)
        #expect(gameState.packageBoxes.allSatisfy { $0.isAssigned })
    }

    @Test("el ascensor marca los pisos con cajas")
    func theElevatorMarksBoxFloors() async throws {
        let gameState = await tower()
        gameState.debugDropPackage(onFloor: "urban")
        let urban = try ordinal(of: "urban", in: gameState)
        #expect(gameState.packageFloorOrdinals == [urban])
        let model = ElevatorKeypadModel(map: gameState.floorMap, visibleOrdinal: 0,
                                        packageOrdinals: gameState.packageFloorOrdinals)
        #expect(model.floors.filter { $0.hasPackage }.map(\.ordinal) == [urban])
    }
}
