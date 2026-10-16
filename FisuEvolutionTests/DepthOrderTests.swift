import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

/// E14b B19 (D13): una sola regla de profundidad para todo lo que está parado en el piso. El z sale
/// de la y de los pies: más abajo en la pantalla, más adelante. Se prueba la regla pura y, con los
/// nodos reales, cada combinación de empleado, visitante, caja y colchón.
@Suite("Capas por profundidad: más abajo en la pantalla, más adelante")
@MainActor
struct DepthOrderTests {
    private let size = CGSize(width: 393, height: 852)
    private let bottomInset: CGFloat = 118
    private let cellSize: CGFloat = 72
    /// SpriteKit guarda `zPosition` en un `Float`: se compara con tolerancia.
    private let tolerance: CGFloat = 0.0005

    /// Una pieza del escenario: dónde apoya los pies (y de la pantalla, desde abajo) y su z de la escena.
    private struct Piece {
        let name: String
        let feetY: CGFloat
        let z: CGFloat
    }

    /// El z de la escena de un empleado con los pies en `screenY`: el que le pone `BoardScene`.
    private func employeeZ(feetY screenY: CGFloat) -> CGFloat {
        BoardScene.fieldBaseZ + BoardScene.depthZ(fieldY: screenY - BoardScene.bottomInset)
    }

    // MARK: - La regla

    @Test("entre dos pies con distinta y, el de más abajo tiene z mayor")
    func lowerFeetAreInFront() {
        var previous = DepthOrder.z(forFeetY: 0)
        for y in stride(from: CGFloat(3), through: DepthOrder.deepestFeetY, by: 3) {
            let z = DepthOrder.z(forFeetY: y)
            #expect(z < previous, "pies en \(y): z \(z) no queda detrás de \(previous)")
            previous = z
        }
    }

    @Test("un empleado va con la misma regla: su z del campo, sumado a la base, es el de DepthOrder")
    func employeesFollowTheSameRule() {
        for screenY in stride(from: CGFloat(100), through: 900, by: 50) {
            #expect(abs(employeeZ(feetY: screenY) - DepthOrder.z(forFeetY: screenY)) < tolerance)
        }
    }

    @Test("la banda entera queda sobre los fondos y debajo de lo que va siempre arriba")
    func theBandSitsBetweenBackgroundsAndOverlays() throws {
        let content = try GameContentLoader.load(from: .main)
        let highestFloor = FloorNode.backgroundZ(ordinal: content.floorTable.floors.count - 1)
        #expect(DepthOrder.z(forFeetY: DepthOrder.deepestFeetY) > highestFloor, "lo de más atrás, delante de su fondo")
        // Lo más adelante posible: pies en el borde, la pila llena y la apertura de la caja de arriba.
        let frontMost = DepthOrder.z(forFeetY: 0) + 2 * DepthOrder.stackStep + 4 * DepthOrder.innerStep
        #expect(frontMost < BoardScene.fieldBaseZ + 50, "el que se arrastra (50 en el campo) va encima de todos")
        #expect(frontMost < StageController.requestZ, "el globo del pedido es una etiqueta: arriba")
        #expect(frontMost < StageEffects.layerZ, "los efectos del escenario, arriba")
        #expect(frontMost < PickupNode.labelZ + DepthOrder.z(forFeetY: DepthOrder.deepestFeetY), "el cartel LLENO, arriba")
    }

    @Test("una caja, con sus videos, se ordena como una sola pieza: sus capas ocupan menos de un punto")
    func aBoxIsOnePiece() {
        #expect(4 * DepthOrder.innerStep < DepthOrder.zPerPoint)
    }

    // MARK: - Los nodos reales

    /// Un visitante parado en su lugar (sin trato abierto, para que no haya pedido) en el callejón.
    private func waitingVisitor(_ gameState: GameState) throws -> (StageController, VisitorNode) {
        let stage = StageController(gameState: gameState)
        stage.attach(to: SKNode())
        stage.layout(sceneSize: size, bottomInset: bottomInset, cellSize: cellSize)
        #expect(gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme")))
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.stageVisit?.offer = nil
        stage.update(delta: 1.0 / 60, reduceMotion: true)
        return (stage, try #require(stage.actor))
    }

    private func pickups(_ gameState: GameState) -> PickupController {
        let controller = PickupController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: size, bottomInset: bottomInset, cellSize: cellSize)
        gameState.debugAddPackages(2)
        gameState.debugSpawnMattress(onBoard: true)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        return controller
    }

    /// Dónde apoya una caja del tablero (E14b B22: cada una en su y): medio lado debajo de su centro,
    /// con el lado achicado por la distancia (B30).
    private func feetY(of box: PickupNode) -> CGFloat {
        box.position.y - cellSize * PickupLayout.sideRatio / 2 * box.depthScale
    }

    /// Dónde apoya el colchón del tablero (E14b B24: en su lugar, como una caja): medio alto de su
    /// arte debajo de su centro (con Reduce Motion no salta), con el alto achicado por la distancia (B30).
    private func feetY(ofMattress mattress: PickupNode) -> CGFloat {
        mattress.position.y - mattress.boxSize.height / 2 * mattress.depthScale
    }

    /// La línea de atrás del piso que se mira: ni el colchón ni una caja apoyan más atrás.
    private func pickupBaseline(_ gameState: GameState) throws -> CGFloat {
        let floor = try #require(gameState.visibleFloorDef)
        return PickupLayout(sceneSize: size, bottomInset: bottomInset, cellSize: cellSize,
                            background: floor.background, backgroundOffset: floor.backgroundOffset).baselineY
    }

    @Test("el visitante va con el z de sus pies, no en una capa fija delante de todos")
    func theVisitorUsesItsFeet() async throws {
        let gameState = await makeGameState()
        let (stage, actor) = try waitingVisitor(gameState)
        #expect(stage.layer.zPosition == 0)
        #expect(abs(actor.zPosition - DepthOrder.z(forFeetY: actor.position.y)) < tolerance)
    }

    @Test("cada caja y el colchón van con el z de sus pies")
    func pickupsUseTheirFeet() async throws {
        let gameState = await makeGameState()
        let controller = pickups(gameState)
        let boxes = controller.boxes
        #expect(boxes.count == 2)
        for box in boxes {
            #expect(abs(box.zPosition - DepthOrder.z(forFeetY: feetY(of: box))) < tolerance)
        }
        let mattress = try #require(controller.mattress)
        #expect(abs(mattress.zPosition - DepthOrder.z(forFeetY: feetY(ofMattress: mattress))) < tolerance)
        let baseline = try pickupBaseline(gameState)
        #expect(feetY(ofMattress: mattress) <= baseline + tolerance, "nunca detrás de la línea de atrás")
    }

    /// Las combinaciones de empleado, visitante, caja y colchón: entre dos con distinta y, el de más
    /// abajo va adelante. Cada pieza real se compara con las otras y con un empleado parado 12 pt
    /// más abajo y otro 12 pt más arriba.
    @Test("empleado, visitante, caja y colchón: entre dos con distinta y, el de más abajo va adelante")
    func everyCombination() async throws {
        let gameState = await makeGameState()
        let (stage, actor) = try waitingVisitor(gameState)
        let controller = pickups(gameState)
        let box = try #require(controller.boxes.first)
        let mattress = try #require(controller.mattress)
        let real = [
            Piece(name: "visitante", feetY: actor.position.y, z: stage.layer.zPosition + actor.zPosition),
            Piece(name: "caja", feetY: feetY(of: box), z: controller.layer.zPosition + box.zPosition),
            Piece(name: "colchón", feetY: feetY(ofMattress: mattress), z: controller.layer.zPosition + mattress.zPosition),
        ]
        var pieces = real
        for piece in real {
            pieces.append(Piece(name: "empleado delante de \(piece.name)", feetY: piece.feetY - 12,
                                z: employeeZ(feetY: piece.feetY - 12)))
            pieces.append(Piece(name: "empleado detrás de \(piece.name)", feetY: piece.feetY + 12,
                                z: employeeZ(feetY: piece.feetY + 12)))
        }
        for a in pieces {
            for b in pieces where a.feetY < b.feetY - 0.5 {
                #expect(a.z > b.z, "\(a.name) (pies en \(a.feetY)) tiene que ir delante de \(b.name) (\(b.feetY))")
            }
        }
    }

    @Test("el video de una caja no se asoma delante de quien está parado un punto más adelante")
    func aBoxVideoStaysInItsDepth() async throws {
        let gameState = await makeGameState()
        let controller = pickups(gameState)
        let top = try #require(controller.boxes.last)
        let video = try #require(top.waitingVideoNode)
        let videoZ = controller.layer.zPosition + top.zPosition + video.zPosition + DepthOrder.innerStep / 3
        #expect(videoZ < employeeZ(feetY: feetY(of: top) - 1))
    }
}

/// D13: los toques los recibe lo que se ve adelante. Una caja detrás de un empleado se toca en la
/// parte que se ve; lo que no está debajo del dedo no entra en la cuenta.
@Suite("El toque es de lo que se ve adelante")
@MainActor
struct DepthTouchTests {
    private let size = CGSize(width: 393, height: 852)

    @Test("el de z más alto recibe el toque primero")
    func frontmostFirst() {
        #expect(BoardScene.touchOrder(stage: 20, pickups: 21, character: 22) == [.character, .pickups, .stage])
        #expect(BoardScene.touchOrder(stage: 191, pickups: 21, character: 22) == [.stage, .character, .pickups])
        #expect(BoardScene.touchOrder(stage: 20, pickups: 23, character: 22) == [.pickups, .character, .stage])
    }

    @Test("lo que no está bajo el dedo no recibe nada")
    func onlyWhatIsUnderTheFinger() {
        #expect(BoardScene.touchOrder(stage: nil, pickups: 21, character: nil) == [.pickups])
        #expect(BoardScene.touchOrder(stage: nil, pickups: nil, character: 22) == [.character])
        #expect(BoardScene.touchOrder(stage: nil, pickups: nil, character: nil).isEmpty)
    }

    @Test("ante un empate, el orden de siempre: escenario, cajas y empleados")
    func tiesKeepTheOldOrder() {
        #expect(BoardScene.touchOrder(stage: 20, pickups: 20, character: 20) == [.stage, .pickups, .character])
    }

    @Test("una caja detrás de un empleado: donde se tapan, el empleado; en la parte que se ve, la caja")
    func aBoxBehindAnEmployee() async throws {
        let gameState = await makeGameState()
        let controller = PickupController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: size, bottomInset: 118, cellSize: 72)
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let box = try #require(controller.boxes.first)
        let boxZ = try #require(controller.hitDepth(at: box.position), "el centro de la caja es de la caja")
        #expect(controller.hitDepth(at: CGPoint(x: 5, y: 5)) == nil)
        // Los pies de la caja (E14b B22: cada una en su y), medio lado debajo de su centro.
        let baseline = box.position.y - 72 * PickupLayout.sideRatio / 2
        let infront = BoardScene.fieldBaseZ + BoardScene.depthZ(fieldY: baseline - 15 - BoardScene.bottomInset)
        let behind = BoardScene.fieldBaseZ + BoardScene.depthZ(fieldY: baseline + 15 - BoardScene.bottomInset)
        #expect(BoardScene.touchOrder(stage: nil, pickups: boxZ, character: infront).first == .character,
                "el empleado parado delante se lleva el toque donde tapa a la caja")
        #expect(BoardScene.touchOrder(stage: nil, pickups: boxZ, character: behind).first == .pickups,
                "con el empleado detrás, la caja que lo tapa")
        #expect(BoardScene.touchOrder(stage: nil, pickups: boxZ, character: nil) == [.pickups],
                "la parte de la caja que se ve se toca")
    }

    /// Un empleado con arte real (2,2 celdas) parado en `feet`, como lo arma el tablero.
    private func employee(at feet: CGPoint, cellSize: CGFloat) throws -> BoardScene.CharacterHit {
        let content = try GameContentLoader.load(from: .main)
        let type = try #require(content.tiers.type(id: "homeless"))
        let node = CharacterNodePool().obtain()
        node.configure(type: type, texture: nil, cellIndex: 0, cellSize: cellSize, hasRealArt: true)
        node.position = feet
        return BoardScene.CharacterHit(feet: feet, z: node.zPosition, body: node.visibleBody)
    }

    @Test("la forma del toque: sola, la zona generosa; con algo detrás bajo el dedo, sólo el cuerpo")
    func theEmployeeHitShape() throws {
        let cell: CGFloat = 72
        let feet = CGPoint(x: 200, y: 300)
        let hit = try employee(at: feet, cellSize: cell)
        let chest = CGPoint(x: feet.x, y: feet.y + cell * 0.9)
        let beside = CGPoint(x: feet.x + cell * 0.7, y: chest.y)
        let overHead = CGPoint(x: feet.x, y: feet.y + cell * 1.9)
        #expect(hit.body.contains(chest))
        #expect(!hit.body.contains(beside), "al costado del cuerpo es aire transparente del sprite")
        #expect(!hit.body.contains(overHead), "por encima de la cabeza no hay cuerpo")
        for point in [chest, beside, overHead] {
            #expect(BoardScene.characterHit(at: point, among: [hit], cellSize: cell, bodyOnly: false) == 0,
                    "sin nada detrás, la elipse generosa lo toma — \(point)")
        }
        #expect(BoardScene.characterHit(at: chest, among: [hit], cellSize: cell, bodyOnly: true) == 0)
        #expect(BoardScene.characterHit(at: beside, among: [hit], cellSize: cell, bodyOnly: true) == nil,
                "con una caja detrás, el costado del empleado es de la caja")
        #expect(BoardScene.characterHit(at: overHead, among: [hit], cellSize: cell, bodyOnly: true) == nil)
    }

    @Test("con algo detrás, el de adelante sin cuerpo bajo el dedo no le roba el toque al de atrás")
    func theFrontEmployeeOnlyWinsOnItsBody() throws {
        let cell: CGFloat = 72
        let back = try employee(at: CGPoint(x: 200, y: 320), cellSize: cell)
        let frontFeet = CGPoint(x: 200 + cell * 0.7, y: 300)
        let frontNode = try employee(at: frontFeet, cellSize: cell)
        let front = BoardScene.CharacterHit(feet: frontFeet, z: back.z + 1, body: frontNode.body)
        let onBackBody = CGPoint(x: 200, y: 320 + cell * 0.9)
        #expect(BoardScene.characterHit(at: onBackBody, among: [back, front], cellSize: cell, bodyOnly: false) == 1,
                "sólo empleados: gana el de adelante, como siempre")
        #expect(BoardScene.characterHit(at: onBackBody, among: [back, front], cellSize: cell, bodyOnly: true) == 0)
        let onFrontBody = CGPoint(x: frontFeet.x, y: frontFeet.y + cell * 0.9)
        #expect(BoardScene.characterHit(at: onFrontBody, among: [back, front], cellSize: cell, bodyOnly: true) == 1)
    }

    @Test("una caja detrás del costado de un empleado: el toque es de la caja")
    func aBoxBesideAnEmployeeBody() throws {
        let cell: CGFloat = 72
        let hit = try employee(at: CGPoint(x: 200, y: 300), cellSize: cell)
        let beside = CGPoint(x: 200 + cell * 0.7, y: 300 + cell * 0.9)
        let boxZ = hit.z - 0.1
        let character = BoardScene.characterHit(at: beside, among: [hit], cellSize: cell, bodyOnly: true)
        #expect(BoardScene.touchOrder(stage: nil, pickups: boxZ, character: character.map { _ in hit.z }) == [.pickups])
    }

    @Test("el visitante: su cuerpo va con sus pies; el globo del pedido, siempre arriba")
    func theStageHitDepth() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.debugGrantCoins()
        gameState.debugGrantPair()
        gameState.debugGrantPair()
        let stage = StageController(gameState: gameState)
        stage.attach(to: SKNode())
        stage.layout(sceneSize: size, bottomInset: 118, cellSize: 72)
        let script = try #require(gameState.content?.visitors.script(id: "comisario_arresto"))
        gameState.presentVisitor(script)
        var elapsed = 0.0
        while gameState.stageVisit?.phase != .waiting, elapsed < 10 {
            stage.update(delta: 1.0 / 60, reduceMotion: false)
            elapsed += 1.0 / 60
        }
        gameState.closeVisitorPopup()
        for _ in 0..<3 { stage.update(delta: 1.0 / 60, reduceMotion: false) }
        let actor = try #require(stage.actor)
        let request = try #require(stage.request)
        let onBody = CGPoint(x: actor.position.x, y: actor.position.y + 10)
        let bodyZ = try #require(stage.hitDepth(at: onBody))
        #expect(abs(bodyZ - actor.zPosition) < 0.0005)
        let onRequest = CGPoint(x: request.position.x, y: request.position.y + request.height / 2)
        #expect(stage.hitDepth(at: onRequest) == StageController.requestZ)
        #expect(stage.hitDepth(at: CGPoint(x: 5, y: 5)) == nil)
        // Un empleado parado delante del visitante se lleva el toque donde lo tapa; el pedido no.
        let infront = DepthOrder.z(forFeetY: actor.position.y - 15)
        #expect(BoardScene.touchOrder(stage: bodyZ, pickups: nil, character: infront).first == .character)
        #expect(BoardScene.touchOrder(stage: StageController.requestZ, pickups: nil, character: infront).first == .stage)
    }
}
