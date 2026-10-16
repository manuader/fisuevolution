import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

/// E14b B19 (D13): el globo de texto del visitante sale de SpriteKit y va en SwiftUI, arriba de
/// todo. La escena publica qué dice y a qué cabeza apunta; `StageBubbleLayout` lo mete entero en
/// la pantalla y, cuando se puede, sin tapar el HUD. Se recorre en los diez escenarios, en el SE
/// y en el Pro Max, con la frase larga de `capturas-e14b/20.jpg`.
@Suite("El globo del visitante: arriba de todo y entero en la pantalla")
@MainActor
struct StageBubbleTests {
    /// Un teléfono: la escena, lo que tapa la isla y el borde de abajo del panel del HUD (medidos
    /// en captura; ver `GameBoardView.debugButton`: SE 90, con notch 140).
    private struct Phone {
        let name: String
        let size: CGSize
        let safeTop: CGFloat
        let hudBottom: CGFloat
    }

    private let phones = [
        Phone(name: "SE", size: CGSize(width: 375, height: 667), safeTop: 0, hudBottom: 90),
        Phone(name: "Pro Max", size: CGSize(width: 440, height: 956), safeTop: 62, hudBottom: 140),
    ]

    /// La frase de `20.jpg` (el presentador de «Lluvia de paquetes») y una más larga todavía.
    private let texts = [
        "¡Llegaron los bolsones! Lluvia de paquetes: andá recogiendo, muchachos.",
        "¡Che, vecino! ¿Viste lo que pasó en el piso de arriba? Dicen que el de la oficina central se llevó todo, hasta las sillas.",
    ]

    /// El globo que publicaría la escena para un visitante parado en ese escenario.
    private func bubble(_ text: String, phone: Phone, background: String) -> StageBubble {
        let layout = PlayLayout(size: phone.size, capacity: 10)
        let stage = StageLayout(sceneSize: phone.size, bottomInset: BoardScene.bottomInset,
                                cellSize: layout.cellSize, floorBottom: BoardScene.floorBottom)
        let head = stage.visitorY(background: background) + stage.actorSide + 4
        return StageBubble(visitId: UUID(), text: text,
                           tip: CGPoint(x: stage.standX, y: phone.size.height - head),
                           sceneSize: phone.size, preferredWidth: stage.bubbleMaxWidth,
                           maxDrop: stage.actorSide * StageController.bubbleMaxDropRatio, tappable: true)
    }

    @Test("los diez escenarios, en el SE y el Pro Max: el globo entra entero en la pantalla")
    func fitsOnScreen() {
        #expect(StageLayout.horizons.count == 10)
        for phone in phones {
            for background in StageLayout.horizons.keys.sorted() {
                for text in texts {
                    let bubble = bubble(text, phone: phone, background: background)
                    let placement = StageBubbleLayout.place(bubble, screen: phone.size, safeTop: phone.safeTop,
                                                            hudBottom: phone.hudBottom)
                    let frame = placement.frame
                    let label = "\(phone.name) en \(background): \(frame)"
                    #expect(frame.minX >= StageBubbleLayout.margin - 0.5, "se sale por la izquierda — \(label)")
                    #expect(frame.maxX <= phone.size.width - StageBubbleLayout.margin + 0.5, "se sale por la derecha — \(label)")
                    #expect(frame.minY >= max(phone.safeTop, StageBubbleLayout.margin) - 0.5, "se sale por arriba — \(label)")
                    #expect(frame.maxY <= phone.size.height, "se sale por abajo — \(label)")
                    #expect(placement.tailX >= 0 && placement.tailX <= frame.width, "la cola fuera del globo — \(label)")
                    #expect(placement.textWidth > 0)
                }
            }
        }
    }

    /// «Cuando se puede, sin tapar el HUD»: si el globo más bajo posible (todo el ancho, bajando lo
    /// permitido sobre la cabeza) entra debajo del HUD, el elegido no lo tapa.
    @Test("los diez escenarios, en el SE y el Pro Max: cuando se puede, no tapa el HUD")
    func avoidsTheHUDWhenItCan() {
        for phone in phones {
            for background in StageLayout.horizons.keys.sorted() {
                for text in texts {
                    let bubble = bubble(text, phone: phone, background: background)
                    let placement = StageBubbleLayout.place(bubble, screen: phone.size, safeTop: phone.safeTop,
                                                            hudBottom: phone.hudBottom)
                    let widest = StageBubbleLayout.bubbleSize(of: text, maxWidth: phone.size.width - StageBubbleLayout.margin * 2)
                    let lowestTop = bubble.tip.y - widest.height + bubble.maxDrop
                    let clear = phone.hudBottom + StageBubbleLayout.hudGap
                    if lowestTop >= clear {
                        #expect(placement.frame.minY >= clear - 0.5,
                                "\(phone.name) en \(background): podía quedar debajo del HUD y lo tapa (\(placement.frame))")
                    }
                    // Apunta a la cabeza: no baja más de lo permitido, salvo que el tope de arriba lo empuje.
                    let pushedByTop = abs(placement.frame.minY - max(phone.safeTop, StageBubbleLayout.margin)) < 0.5
                    #expect(placement.frame.maxY <= bubble.tip.y + bubble.maxDrop + 0.5 || pushedByTop,
                            "\(phone.name) en \(background): el globo se despega de la cabeza")
                }
            }
        }
    }

    @Test("una frase corta, con lugar de sobra, va centrada sobre la cabeza con la cola en ella")
    func aShortPhraseSitsOnTheHead() {
        let bubble = StageBubble(visitId: UUID(), text: "¡Hola!", tip: CGPoint(x: 200, y: 500),
                                 sceneSize: CGSize(width: 393, height: 852), preferredWidth: 250, maxDrop: 20, tappable: true)
        let placement = StageBubbleLayout.place(bubble, screen: CGSize(width: 393, height: 852), safeTop: 59, hudBottom: 140)
        #expect(abs(placement.frame.maxY - 500) < 0.5)
        #expect(abs(placement.frame.midX - 200) < 0.5)
        #expect(abs(placement.tailX - placement.frame.width / 2) < 0.5)
    }

    @Test("si el ancho de siempre tapa el HUD, prueba con todo el ancho de la pantalla")
    func triesWiderThenLower() {
        let screen = CGSize(width: 393, height: 852)
        let text = texts[1]
        let narrow = StageBubbleLayout.bubbleSize(of: text, maxWidth: 200)
        let wide = StageBubbleLayout.bubbleSize(of: text, maxWidth: screen.width - StageBubbleLayout.margin * 2)
        #expect(wide.height < narrow.height, "más ancho, menos renglones")
        // La cabeza justo donde el globo angosto taparía el HUD y el ancho no.
        let hud: CGFloat = 140
        let tipY = hud + StageBubbleLayout.hudGap + wide.height + 1
        let bubble = StageBubble(visitId: UUID(), text: text, tip: CGPoint(x: 196, y: tipY), sceneSize: screen,
                                 preferredWidth: 200, maxDrop: 0, tappable: true)
        let placement = StageBubbleLayout.place(bubble, screen: screen, safeTop: 59, hudBottom: hud)
        #expect(placement.frame.minY >= hud + StageBubbleLayout.hudGap - 0.5)
        #expect(abs(placement.frame.height - wide.height) < 0.5)
    }

    // MARK: - E14b B20: las esquinas

    @Test("el globo no se encima con las esquinas que le quedan a la altura: se angosta al carril libre")
    func bubbleAvoidsTheCorners() {
        for phone in phones {
            let right = CGRect(x: phone.size.width - 154, y: phone.hudBottom, width: 150, height: 360)
            let left = CGRect(x: 4, y: phone.hudBottom, width: 62, height: 330)
            for background in StageLayout.horizons.keys.sorted() {
                for text in texts {
                    var bubble = bubble(text, phone: phone, background: background)
                    // El visitante, en el borde derecho de su caminata: el globo centrado pisaría la columna.
                    bubble = StageBubble(visitId: bubble.visitId, text: text,
                                         tip: CGPoint(x: phone.size.width * 0.6, y: bubble.tip.y),
                                         sceneSize: bubble.sceneSize, preferredWidth: bubble.preferredWidth,
                                         maxDrop: bubble.maxDrop, tappable: true)
                    let free = StageBubbleLayout.place(bubble, screen: phone.size, safeTop: phone.safeTop,
                                                       hudBottom: phone.hudBottom)
                    let placed = StageBubbleLayout.place(bubble, screen: phone.size, safeTop: phone.safeTop,
                                                         hudBottom: phone.hudBottom, corners: [left, right])
                    let label = "\(phone.name) en \(background): \(placed.frame)"
                    guard free.frame.intersects(right) || free.frame.intersects(left) else {
                        #expect(placed == free, "sin choque no se mueve — \(label)")
                        continue
                    }
                    #expect(!placed.frame.intersects(right), "pisa la columna derecha — \(label)")
                    #expect(!placed.frame.intersects(left), "pisa la columna izquierda — \(label)")
                    #expect(placed.frame.minX >= StageBubbleLayout.margin - 0.5, "\(label)")
                }
            }
        }
    }

    @Test("sin esquinas, el globo va donde iba")
    func noCornersNoChange() {
        let bubble = StageBubble(visitId: UUID(), text: "¡Hola!", tip: CGPoint(x: 200, y: 500),
                                 sceneSize: CGSize(width: 393, height: 852), preferredWidth: 250, maxDrop: 20, tappable: true)
        let screen = CGSize(width: 393, height: 852)
        #expect(StageBubbleLayout.place(bubble, screen: screen, safeTop: 59, hudBottom: 140, corners: [])
            == StageBubbleLayout.place(bubble, screen: screen, safeTop: 59, hudBottom: 140))
    }

    // MARK: - Lo que publica la escena

    private func stage() async throws -> (GameState, StageController) {
        let gameState = await makeGameState()
        let controller = StageController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.stageVisit?.offer = nil
        gameState.stageVisit?.bubble = "¡Hola, vecino!"
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        return (gameState, controller)
    }

    @Test("la escena publica la frase y la cabeza, con el origen arriba como SwiftUI; no hay globo en SpriteKit")
    func theScenePublishesTheHead() async throws {
        let (_, controller) = try await stage()
        let actor = try #require(controller.actor)
        let bubble = try #require(controller.bubble)
        let layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        #expect(bubble.text == "¡Hola, vecino!")
        #expect(abs(bubble.tip.x - actor.position.x) <= 0.5)
        // La cabeza, con el visitante achicado por la distancia (B30).
        #expect(abs(bubble.tip.y - (852 - (actor.position.y + layout.actorSide * actor.depthScale + 4))) <= 0.5)
        #expect(bubble.tappable)
        #expect(!controller.layer.children.contains { $0.name == "stage.bubble" })
    }

    @Test("con una celebración encima, o sin frase, no hay globo")
    func hiddenWhileCoveredOrSilent() async throws {
        let (gameState, controller) = try await stage()
        controller.bubbleSuppressed = true
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        #expect(controller.bubble == nil)
        controller.bubbleSuppressed = false
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        #expect(controller.bubble != nil)
        gameState.stageVisit?.bubble = nil
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        #expect(controller.bubble == nil)
        #expect(!controller.tapBubble(), "sin globo no hay nada que tocar")
    }

    @Test("tocar el globo es tocar al visitante")
    func tappingTheBubble() async throws {
        let (gameState, controller) = try await stage()
        var tapped = false
        controller.bubbleFeed.onTap = { tapped = controller.tapBubble() }
        controller.bubbleFeed.tap()
        #expect(tapped)
        #expect(gameState.stageVisit?.phase == .waiting)
    }

    @Test("el feed sólo cambia cuando cambia lo que se ve")
    func theFeedOnlyChangesWhenNeeded() async throws {
        let (gameState, controller) = try await stage()
        let first = try #require(controller.bubble)
        // El controlador mira el estado con una referencia débil (lo dueña la escena): soltado, el
        // próximo cuadro lo daría por terminado y limpiaría el globo.
        withExtendedLifetime(gameState) {
            controller.update(delta: 1.0 / 60, reduceMotion: true)
        }
        #expect(controller.bubble == first)
    }
}
