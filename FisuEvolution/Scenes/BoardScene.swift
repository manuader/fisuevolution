import EconomyKit
import SpriteKit
import UIKit

/// The merge board. Owns the entire per-frame world (bible §4.1): the income tick
/// and all gestures run here; SwiftUI only sees throttled projections. Reads state
/// from `GameState` and renders the grid + character nodes.
final class BoardScene: SKScene {
    private unowned let gameState: GameState
    private let renderer = PlaceholderRenderer()
    private let pool = CharacterNodePool()
    private let particles = ParticlePool()
    private let cameraNode = SKCameraNode()
    /// Overlay fijo a la cámara: reveal, flash y textos no se quedan atrás al
    /// cambiar de piso.
    private let cameraOverlay = SKNode()

    /// Campo de juego (estilo Cow Evolution): fondo de escena + personajes
    /// parados en anclas orgánicas — sin grilla visible.
    private let backgroundLayer = SKNode()
    private let fieldNode = SKNode()
    private var floorNodes: [Int: FloorNode] = [:]
    private var characterNodes: [Int: CharacterNode] = [:]
    /// Qué está mostrando cada slot, para reconciliar en vez de reconstruir.
    /// Se mantiene en paralelo a `characterNodes` y sólo `renderPlacements`
    /// escribe en los dos.
    private var renderedUnits: [Int: RenderedUnit] = [:]
    private var lastLayoutSize: CGSize = .zero
    private var renderedBoardVersion = -1
    private var displayedFloorOrdinal = -1
    /// Piso alrededor del cual están montados los fondos vivos. Durante un vuelo
    /// largo lo manda la CÁMARA y no el piso de destino.
    private var liveFloorCenter = -1
    /// Hay un vuelo entre pisos no vecinos en curso (RF-08).
    private var isFlying = false
    /// Fondos del recorrido, retenidos SÓLO mientras dura el vuelo.
    ///
    /// Sin esto la cámara llega a cada piso antes que su textura: montar el
    /// `FloorNode` es instantáneo pero subir un PNG de 1536×1536 a la GPU no, y
    /// a velocidad de crucero el vuelo se adelanta medio piso (~20 ms), así que
    /// entre fondo y fondo aparecía el crema del `backgroundColor`. Se ve como
    /// un parpadeo, que es exactamente el tirón que el vuelo no puede tener.
    private var flightTextures: [SKTexture] = []

    // Geometría del campo, cacheada por layoutBoard.
    private var boardColumns = 0
    private var boardRows = 0
    /// La franja de la multitud vigente. La recalcula `rebuildAnchors`; la leen
    /// el deambular y el z de los specials.
    private var band = CrowdBand(frontY: 0, rowDepth: 0, wanderRange: 0, topY: 0)
    private var cellSize: CGFloat = 0
    /// Punto de anclaje por cellIndex: grilla lógica + jitter determinístico.
    private var anchorPoints: [CGPoint] = []

    // Drag state
    private var dragNode: CharacterNode?
    private var dragOriginCell = -1
    private var isDragging = false
    private var emptyTouchStart: CGPoint?
    private static let dragThreshold: CGFloat = 10
    private static let longPressKey = "longPress"
    private static let ascentDuration: TimeInterval = 0.7
    private static let ascentDistanceRatio: CGFloat = 0.78
    private static let specialNodePrefix = "special."
    private static let floorCameraKey = "floorCamera"
    /// Cambiar de piso con las flechas o el deslizamiento: un salto corto.
    private static let floorHopDuration: TimeInterval = 0.35
    /// Presupuesto del vuelo del mapa (RF-08): tiene que dejar ver la torre que
    /// se recorre sin dejar de ser un atajo.
    private static let flightMinDuration: TimeInterval = 0.6
    private static let flightMaxDuration: TimeInterval = 0.9

    // MARK: Fusión asistida

    /// Slots destacados por un gesto de fusión en curso: los hermanos del que
    /// estás arrastrando, o el que viaja hacia su par en el doble toque.
    /// Mientras están acá suben por encima de la multitud y no deambulan.
    ///
    /// Un `Set` y no una propiedad del nodo porque lo consulta
    /// `refreshCrowdDepth`, que corre todos los frames: un `contains` sobre ≤10
    /// slots no aloca nada.
    private var mergeCandidates: Set<Int> = []
    /// Último tap sobre un personaje, para reconocer el doble toque.
    private var lastTapSlot = -1
    private var lastTapTime: TimeInterval = 0
    private var lastAssistedMergeTime: TimeInterval = 0
    /// Cuánto sube un candidato por encima de su profundidad de multitud. El
    /// `depthZ` de la franja va de ~−0,3 a ~2,0 y el arrastrado está en 50: con
    /// 5 el candidato le gana a toda la multitud, pierde contra el que llevás en
    /// la mano y conserva la profundidad relativa **entre** candidatos, así que
    /// un par no se dibuja plano.
    ///
    /// Interno, no privado: `BoardGestureTests` lo pinea, igual que `fieldBaseZ`.
    static let candidateZLift: CGFloat = 5
    static let candidateScale: CGFloat = 1.12
    private static let candidatePopDuration: TimeInterval = 0.1
    /// Ventana del doble toque. La de iOS, para que el gesto se sienta como el
    /// del sistema.
    static let doubleTapWindow: TimeInterval = 0.3
    /// Gracia entre dos fusiones por doble toque.
    ///
    /// Tocar rápido **es** un doble toque: sin esta gracia, una ráfaga de taps
    /// para ganar monedas encadena el piso entero en dos segundos. No se puede
    /// evitar del todo el disparo accidental —los dos primeros toques de una
    /// ráfaga son indistinguibles de un doble toque deliberado— y tampoco hace
    /// falta: fusionar nunca es una pérdida. Lo que hay que evitar es la
    /// cascada.
    static let assistedMergeCooldown: TimeInterval = 0.8
    /// Lo que tarda el compañero en llegar hasta el que tocaste.
    private static let assistedMergeSlide: TimeInterval = 0.18

    // FTUE hint
    private var hintNode: SKShapeNode?
    private var hintTargetCell = -1
    /// Personaje congelado por el recorte del tutorial (RF-01): mientras el paso
    /// lo señala no deambula, para que el blanco no se mueva.
    private weak var spotlitNode: CharacterNode?

    // Tick state
    private var lastUpdateTime: TimeInterval = 0
    private var frameCounter = 0
    /// 60 fps / 8 ≈ 8 Hz HUD flush (Docs/concurrency-conventions.md regla 2).
    private static let hudFlushEveryNFrames = 8

    /// Vertical insets leaving room for the SwiftUI HUD above and controls below.
    private static let topInset: CGFloat = 130
    /// Origen vertical del campo dentro de la escena: el borde de arriba de la
    /// barra inferior, para que la multitud no camine detrás de ella.
    ///
    /// Sale de sumar la barra, no de tantear: `GameTabBar` mide 56 (el tab
    /// destacado) + 8 de padding vertical arriba y abajo = **72**, la franja le
    /// agrega **8** de aire abajo y la safe area de un teléfono con notch pone
    /// **34**. Medido en el simulador sobre la captura (iPhone 16 Pro): el borde
    /// ink de la barra arranca a 114 pt del borde inferior de la pantalla.
    ///
    /// ⚠️ Es UNA constante para todos los tamaños, así que en un teléfono sin
    /// notch la barra queda 34 pt más abajo y sobra ese margen — el error va
    /// hacia el lado seguro (nadie queda tapado). `CrowdBandTests` y
    /// `CrowdDepthTests` asertan contra este knob, no contra el número.
    static let bottomInset: CGFloat = 114
    private static let horizontalInset: CGFloat = 16
    /// Margen a cada lado para los textos del reveal, que van centrados y a
    /// pantalla completa.
    static let revealMargin: CGFloat = 24

    /// Piso de la franja: pies de la fila delantera en su punto más bajo, en
    /// fracciones de `cellSize` sobre el borde inferior del campo. Va en
    /// `cellSize` porque depende del tamaño del personaje, no de la pantalla.
    static let frontRowRatio: CGFloat = 0.55
    /// Techo de la franja por la que se mueve la multitud, en fracción del ALTO
    /// de la pantalla.
    ///
    /// Va en alto de pantalla y no en `cellSize` porque `cellSize` sale del
    /// ANCHO: atarlo ahí hace que la franja encoja en un teléfono angosto y
    /// alto, justo donde sobra lugar.
    ///
    /// **Éste es EL knob del alto de la multitud.** 0,5 los lleva a la mitad
    /// exacta de la pantalla; 0,4 los deja apenas arriba del tercio inferior,
    /// que es la zona que los fondos tienen autorada como transitable.
    static let crowdTopRatio: CGFloat = 0.44
    /// Amplitud horizontal del deambular, centrada en el ancla (±la mitad).
    static let wanderHorizontalRange: CGFloat = 34
    /// Velocidad del deambular, en puntos por segundo. La duración de cada paso
    /// sale de la distancia: con duración fija, agrandar la franja los haría
    /// caminar más rápido en vez de recorrer más.
    static let wanderSpeed: CGFloat = 44

    /// Cada cuánto se da vuelta solo un personaje, y cuánto se sortea alrededor
    /// de ese período: `withRange` reparte ±la mitad, así que el volteo cae
    /// entre 5 y 10 s. Más seguido se lee como un tic nervioso; más espaciado y
    /// la multitud vuelve a parecer un cuadro.
    private static let facingFlipPeriod: TimeInterval = 7.5
    private static let facingFlipJitter: TimeInterval = 5

    /// Base de profundidad del campo de personajes.
    ///
    /// **Existe para que la multitud y los fondos NO compartan espacio de z.**
    /// Los `FloorNode` viven en `ordinal × 0.01` (0 … 0.10 con once pisos) y
    /// `depthZ` puede dar negativo en cuanto una fila se ubica por encima de
    /// `rows × cellSize`. Cuando las dos bandas se tocan, un personaje queda
    /// detrás del fondo de su propio piso: invisible pero clickeable, porque el
    /// hit-testing es geométrico y no mira el z. Ya pasó una vez —subir la franja
    /// de piso mandó la fila trasera a y≈156 con el cruce en 148— y la única
    /// forma de que no vuelva a pasar con el próximo cambio de layout es que las
    /// bandas no puedan tocarse.
    static let fieldBaseZ: CGFloat = 10

    // MARK: - Reduce Motion

    #if DEBUG
    /// Simula Reduce Motion desde un test. `nil` = lo que diga el sistema.
    ///
    /// Existe porque `UIAccessibility.isReduceMotionEnabled` es del proceso y no
    /// se puede cambiar desde un test unitario, y sin poder prenderlo la mitad
    /// del comportamiento accesible de la escena sólo se verifica a ojo en el
    /// simulador —que es exactamente la trampa 9 del HANDOFF: una verificación
    /// que no corre en los dos sentidos no verifica nada—.
    ///
    /// ⚠️ Es estado global del proceso: el test lo pone y lo saca **sin `await`
    /// en el medio**, o el flag se le filtra a otra prueba.
    static var reduceMotionOverride: Bool?
    #endif

    /// El único lugar de la escena donde se pregunta por Reduce Motion, para que
    /// el override valga para TODO lo que se mueve y no sólo para lo último que
    /// alguien se acordó de enchufarle.
    private static var prefersReducedMotion: Bool {
        #if DEBUG
        if let reduceMotionOverride { return reduceMotionOverride }
        #endif
        return UIAccessibility.isReduceMotionEnabled
    }

    /// Achica la fuente de un label hasta que entre en `maxWidth`.
    ///
    /// Un `SKLabelNode` no encoge ni envuelve solo: a 38 pt los nombres largos
    /// del reveal se salían de la pantalla —"MAGNATE DEL SISTEMA SOLAR" son 25
    /// caracteres, más de 600 pt en una pantalla de 402—. Se escala la fuente en
    /// proporción a lo que sobra, que preserva el tipo y el peso; recortar el
    /// texto o envolverlo en dos renglones queda peor en un banner.
    /// Una sola regla de tres NO alcanza: el ancho de un `SKLabelNode` no escala
    /// lineal con `fontSize` porque las métricas de la fuente se cuantizan, y el
    /// resultado queda 2-3 pt por encima del tope. Se hace el ajuste proporcional
    /// —que llega cerca de una— y después se baja de a medio punto hasta entrar.
    static func shrinkToFit(_ label: SKLabelNode, maxWidth: CGFloat) {
        guard maxWidth > 0, label.frame.width > maxWidth, label.frame.width > 0 else { return }
        label.fontSize *= maxWidth / label.frame.width
        var guardrail = 0
        while label.frame.width > maxWidth, label.fontSize > 8, guardrail < 40 {
            label.fontSize -= 0.5
            guardrail += 1
        }
    }

    init(gameState: GameState) {
        self.gameState = gameState
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = Palette.cream
        addChild(backgroundLayer)
        // Todo el campo va montado por encima de la banda de los fondos, así que
        // `depthZ` puede dar negativo sin hundir a nadie detrás de su piso. Los
        // hijos del campo (arrastre 50, labels 100, ring 80, specials por debajo
        // de la multitud) suben con él y conservan su orden relativo.
        fieldNode.zPosition = Self.fieldBaseZ
        addChild(fieldNode)
        cameraNode.addChild(cameraOverlay)
        addChild(cameraNode)
        camera = cameraNode
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BoardScene is never decoded")
    }

    override func didMove(to view: SKView) {
        layoutBoard()
        particles.preheat()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // Called during init too, before children exist — only relayout when live.
        guard scene?.view != nil, size != lastLayoutSize else { return }
        layoutBoard()
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        // El primer frame (o el primero tras resume) trae un delta gigante;
        // IncomeTicker lo clampa (el offline ya cubrió ese tiempo).
        let delta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        gameState.tick(delta: delta)

        frameCounter += 1
        if frameCounter >= Self.hudFlushEveryNFrames {
            frameCounter = 0
            gameState.flushHUD()
        }

        if gameState.boardVersion != renderedBoardVersion {
            layoutBoard()
        }

        if isFlying { streamFloorsAlongFlight() }
        refreshCrowdDepth()
        updateFTUEHint()
        publishTutorialSpotlight()
    }

    /// La profundidad se recalcula con el personaje ya movido, no una sola vez
    /// desde su ancla.
    ///
    /// El deambular cubre toda la franja, así que dos personajes pueden cruzarse
    /// de fila: con el z congelado en el ancla, el que quedó adelante se dibuja
    /// detrás. Son ≤10 nodos por frame. El que se está arrastrando queda afuera
    /// porque tiene su propio z mientras dura el gesto.
    ///
    /// El realce de los candidatos se aplica **acá y no una sola vez al
    /// agarrar**: este método corre todos los frames y pisaría cualquier z que
    /// se hubiera asignado afuera.
    private func refreshCrowdDepth() {
        for (slot, node) in characterNodes where node !== dragNode {
            let z = depthZ(for: node.position)
                + (mergeCandidates.contains(slot) ? Self.candidateZLift : 0)
            if node.zPosition != z { node.zPosition = z }
        }
    }

    /// Anillo pulsante sobre la unidad a tapear (hint 1) o sobre una del par
    /// mergeable (hint 3). El hint del botón de spawn vive en SwiftUI.
    private func updateFTUEHint() {
        var targetCell = -1
        // `visiblePlacements` construye un array nuevo: pedirlo antes de saber si
        // hay hint activo era una allocation por frame para siempre, incluso con
        // el tutorial terminado.
        //
        // Con el tutorial en un paso de tablero el anillo se calla: el recorte
        // iluminado ya está señalando esa misma unidad y dos señales sobre el
        // mismo personaje se leen como dos cosas distintas.
        if gameState.tutorialBoardTarget != nil {
            targetCell = -1
        } else if gameState.showTapHint {
            targetCell = firstUnitCell()
        } else if gameState.showMergeHint {
            targetCell = mergePairCell() ?? -1
        }

        guard targetCell != hintTargetCell else { return }
        hintTargetCell = targetCell
        hintNode?.removeFromParent()
        hintNode = nil
        guard targetCell >= 0 else { return }

        let ring = SKShapeNode(circleOfRadius: cellSize * 0.55)
        ring.strokeColor = SKColor(named: "PaletteBlue") ?? .systemBlue
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.position = position(ofCell: targetCell)
        ring.zPosition = 80
        fieldNode.addChild(ring)
        if !Self.prefersReducedMotion {
            ring.run(.repeatForever(.sequence([
                .group([.scale(to: 1.15, duration: 0.5), .fadeAlpha(to: 0.5, duration: 0.5)]),
                .group([.scale(to: 1.0, duration: 0.5), .fadeAlpha(to: 1.0, duration: 0.5)]),
            ])))
        }
        hintNode = ring
    }

    // MARK: - Recorte del tutorial sobre el tablero (RF-01)

    /// Primera unidad del piso visible.
    private func firstUnitCell() -> Int {
        gameState.visiblePlacements.first?.slot ?? -1
    }

    /// Una unidad de un par mergeable del piso visible, si lo hay.
    private func mergePairCell() -> Int? {
        mergePairCells()?.first
    }

    /// Las DOS unidades de un par mergeable.
    ///
    /// El tutorial ilumina las dos, no una: el paso pide arrastrar una SOBRE la
    /// otra, y con la otra debajo del scrim el jugador no ve adónde tiene que
    /// soltar. Un recorte que no incluye el destino de su propia acción es un
    /// recorte mal puesto.
    private func mergePairCells() -> [Int]? {
        var byType: [String: Int] = [:]
        for placement in gameState.visiblePlacements {
            if let first = byType[placement.typeId] { return [first, placement.slot] }
            byType[placement.typeId] = placement.slot
        }
        return nil
    }

    /// Publica en `GameState` el rectángulo del personaje que el tutorial pide
    /// iluminar, en puntos de la VISTA (que es donde vive el overlay SwiftUI).
    ///
    /// El rect sale de la posición REAL del nodo y no del ancla del slot: desde
    /// que el reconciliador conserva la posición deambulada, el ancla y el
    /// personaje pueden estar a medio `cellSize` de distancia (es la misma
    /// trampa 3 que hace fallar los drags por coordenadas fijas). Se usa la
    /// MISMA elipse que el hit-testing de `characterNode(at:)`, así que el
    /// agujero cae exactamente sobre lo que responde al toque.
    ///
    /// Sólo escribe cuando el recorte se movió más que `spotlightEpsilon`: el
    /// deambular es continuo y publicar por frame invalidaría SwiftUI a 60 Hz.
    private func publishTutorialSpotlight() {
        guard let target = gameState.tutorialBoardTarget, view != nil else {
            releaseSpotlitNode()
            if gameState.boardSpotlight != nil { gameState.boardSpotlight = nil }
            return
        }
        let cells = switch target {
        case .anyUnit: [firstUnitCell()]
        case .mergePair: mergePairCells() ?? [firstUnitCell()]
        }
        let nodes = cells.compactMap { $0 >= 0 ? characterNodes[$0] : nil }
        guard let first = nodes.first else {
            releaseSpotlitNode()
            if gameState.boardSpotlight != nil { gameState.boardSpotlight = nil }
            return
        }
        // El personaje iluminado deja de deambular mientras dura el paso.
        //
        // No es un detalle: a 44 pt/s se corre más de medio cuerpo por segundo, y
        // el tutorial le está pidiendo al jugador que le apunte. Un blanco que se
        // mueve mientras el globo dice "tocame" es exactamente lo que hace que un
        // tutorial se sienta roto — y en el runner, donde consultar la posición
        // cuesta ~2 s, hacía que el toque llegara siempre tarde.
        if spotlitNode !== first {
            releaseSpotlitNode()
            spotlitNode = first
        }
        // Se re-chequea por frame y no una sola vez al entrar: un arrastre que se
        // cancela vuelve a llamar a `startWander`, y ahí el blanco del paso del
        // merge se pondría a caminar justo después de un intento fallido.
        for node in nodes where node.action(forKey: "wander") != nil {
            node.removeAction(forKey: "wander")
        }

        // Unión de los cuerpos: con el par, el recorte tiene que incluir al
        // destino del arrastre y no sólo al que se agarra.
        var rect = CGRect.null
        for node in nodes {
            rect = rect.union(bodyRect(of: node))
        }
        guard SpotlightShape.isDrawable(rect) else { return }
        if let current = gameState.boardSpotlight,
           abs(current.midX - rect.midX) < Self.spotlightEpsilon,
           abs(current.midY - rect.midY) < Self.spotlightEpsilon,
           abs(current.width - rect.width) < Self.spotlightEpsilon {
            return
        }
        gameState.boardSpotlight = rect
    }

    /// Caja del cuerpo de un personaje en puntos de la VISTA. Es la misma elipse
    /// que usa el hit-testing de `characterNode(at:)`, así que el recorte cae
    /// exactamente sobre lo que responde al toque.
    private func bodyRect(of node: CharacterNode) -> CGRect {
        let halfWidth = cellSize * 0.82
        let halfHeight = cellSize * 1.15
        let bodyCenter = CGPoint(x: node.position.x, y: node.position.y + cellSize * 0.9)
        let center = convertPoint(toView: fieldNode.convert(bodyCenter, to: self))
        guard center.x.isFinite, center.y.isFinite else { return .null }
        return CGRect(x: center.x - halfWidth, y: center.y - halfHeight,
                      width: halfWidth * 2, height: halfHeight * 2)
    }

    /// Le devuelve el deambular a lo que el recorte había congelado.
    ///
    /// Se recorre el campo entero en vez de guardar referencias: entre que se
    /// congela y que se suelta puede haber pasado un merge, y esos nodos ya
    /// volvieron al pool. Lo único que hay que respetar es lo que congeló otro
    /// gesto: el que se está arrastrando —que maneja su propio paseo en
    /// `touchesEnded`/`cancelDrag`— y los candidatos a fusión, que si no
    /// recuperarían el paseo en medio de un arrastre.
    private func releaseSpotlitNode() {
        guard spotlitNode != nil else { return }
        spotlitNode = nil
        for (slot, node) in characterNodes
        where node !== dragNode && !mergeCandidates.contains(slot)
            && node.action(forKey: "wander") == nil {
            startWander(node)
        }
    }

    /// Cuánto se tiene que mover el personaje para republicar el recorte. A la
    /// velocidad del deambular (44 pt/s) esto da ~7 Hz, el mismo presupuesto que
    /// el flush del HUD.
    private static let spotlightEpsilon: CGFloat = 6

    // MARK: - Gestos: tap, drag-and-drop (§2.3 regla 2), long-press (pasivo)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragNode == nil, let touch = touches.first else { return }
        guard let node = characterNode(at: touch.location(in: self)) else {
            emptyTouchStart = touch.location(in: self)
            return
        }
        dragNode = node
        dragOriginCell = node.cellIndex
        isDragging = false
        node.removeAction(forKey: "wander")

        // Long-press: si en 0.45s sigue apretando sin arrastrar → popup de pasivo.
        run(.sequence([
            .wait(forDuration: 0.45),
            .run { [weak self] in
                guard let self, let held = self.dragNode, !self.isDragging else { return }
                self.cancelDrag(snapBack: false)
                self.gameState.presentCharacterSheet(cellIndex: held.cellIndex)
            },
        ]), withKey: Self.longPressKey)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if emptyTouchStart != nil { return }
        guard let node = dragNode, let touch = touches.first else { return }
        let location = touch.location(in: fieldNode)
        let origin = position(ofCell: dragOriginCell)

        if !isDragging, hypot(location.x - origin.x, location.y - origin.y) > Self.dragThreshold {
            isDragging = true
            removeAction(forKey: Self.longPressKey)
            node.zPosition = 50
            node.run(.scale(to: 1.08, duration: 0.08))
            highlightMergeCandidates(of: node)
        }
        if isDragging {
            node.position = location
        }
    }

    /// Decide a qué piso lleva un deslizamiento sobre el campo vacío. Extraída de
    /// `touchesEnded` para que el test pruebe la regla y no una copia de la regla.
    ///
    /// Metáfora de scroll de iOS: se agarra la torre y se la mueve, igual que
    /// cualquier lista. El dedo hacia ABAJO (que en coordenadas de escena es
    /// `deltaY < 0`, porque la y crece hacia arriba) SUBE un piso.
    func floorDelta(deltaX: CGFloat, deltaY: CGFloat) -> Int? {
        guard abs(deltaY) > 48, abs(deltaY) > abs(deltaX) * 1.5 else { return nil }
        return deltaY > 0 ? -1 : 1
    }

    #if DEBUG
    /// Punto de entrada del test: ejecuta la MISMA decisión que el gesto.
    func simulateSwipe(deltaY: CGFloat) {
        if let delta = floorDelta(deltaX: 0, deltaY: deltaY) {
            _ = gameState.moveVisibleFloor(by: delta)
        }
    }
    #endif

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeAction(forKey: Self.longPressKey)
        if let start = emptyTouchStart, let touch = touches.first {
            emptyTouchStart = nil
            let end = touch.location(in: self)
            let deltaY = end.y - start.y
            let deltaX = end.x - start.x
            if let delta = floorDelta(deltaX: deltaX, deltaY: deltaY) {
                _ = gameState.moveVisibleFloor(by: delta)
            }
            return
        }
        guard let node = dragNode, let touch = touches.first else { return }

        guard isDragging else {
            // Tap corto: §2.3 regla 1.
            dragNode = nil
            handleTap(on: node, at: touch.timestamp)
            return
        }

        let dropPoint = touch.location(in: fieldNode)
        guard let targetCell = dropTarget(at: dropPoint, dragging: node) else {
            cancelDrag(snapBack: true)
            return
        }
        resolveDrop(from: dragOriginCell, to: targetCell, at: dropPoint, sourceNode: node)
    }

    /// Resuelve un drop ya decidido y corre su feedback.
    ///
    /// Es el **único** camino de fusión de la escena: el arrastre y el doble
    /// toque entran los dos por acá, así que no pueden divergir. Por eso el
    /// doble toque hereda gratis el prompt de carrera, el aviso de piso de
    /// destino lleno, el ascenso, el reveal y la cadena de celebraciones.
    private func resolveDrop(
        from originCell: Int,
        to targetCell: Int,
        at dropPoint: CGPoint,
        sourceNode node: CharacterNode
    ) {
        dragNode = nil
        isDragging = false
        clearMergeCandidates()

        switch gameState.handleDrop(fromCell: originCell, toCell: targetCell) {
        case .merged(let cell, let evolvedTo, let promotedType, let promotedToFloor, let unlockedFloorID):
            // `layoutBoard()` recicla los nodos del campo. Tomamos la coordenada
            // mundial antes de reconstruirlo para animar una copia independiente.
            let promotionStart = promotedToFloor == nil
                ? nil
                : fieldNode.convert(node.position, to: backgroundLayer)
            layoutBoard()
            // Si el resultado ascendió de piso (F7 §3.4), ya no está en este piso:
            // feedback en el punto del drop. F7.2 agrega la animación de vuelo.
            let mergedNode = promotedToFloor == nil ? characterNodes[cell] : nil
            let feedbackPoint = mergedNode?.position ?? dropPoint
            particles.emit(.merge, at: feedbackPoint, in: fieldNode)
            if let mergedNode {
                mergedNode.run(.sequence([
                    .scale(to: 1.25, duration: 0.1),
                    .scale(to: 1.0, duration: 0.12),
                ]))
            }
            // Cadena: vuelo → reveal del personaje → piso nuevo → avisarle a
            // GameState, que recién ahí suelta el sheet de skin y el toast.
            // Antes los tres arrancaban juntos en t=0 y el sheet aparecía encima,
            // así que no se apreciaba ninguno — y es el momento más importante
            // del juego. Encadena por completion y no por delays fijos: con
            // Reduce Motion las duraciones colapsan y un offset quedaría
            // desalineado.
            let finish: () -> Void = { [weak self] in
                self?.gameState.celebrationsDidFinish()
            }
            let celebrateFloor: () -> Void = { [weak self] in
                guard let self, let unlockedFloorID, let promotedToFloor else {
                    finish()
                    return
                }
                self.runFloorUnlockCelebration(
                    floorID: unlockedFloorID,
                    destinationOrdinal: promotedToFloor,
                    completion: finish
                )
            }
            let revealEvolution: () -> Void = { [weak self] in
                guard let self, let evolvedTo else {
                    celebrateFloor()
                    return
                }
                self.gameState.playHaptic(.evolution)
                self.runEvolutionReveal(
                    for: evolvedTo,
                    at: mergedNode?.position,
                    completion: celebrateFloor
                )
            }
            if let promotedType, let promotionStart {
                runAscentAnimation(type: promotedType, from: promotionStart, completion: revealEvolution)
            } else {
                if evolvedTo == nil { gameState.playHaptic(.merge) }
                revealEvolution()
            }
        case .moved:
            layoutBoard()
        case .careerPending, .snapBack:
            // No pasa por `cancelDrag`: el arrastre ya se dio por terminado
            // arriba, y el doble toque nunca tuvo uno. Lo que hay que deshacer
            // es el desplazamiento del personaje, que es lo mismo en los dos.
            returnToAnchor(node)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeAction(forKey: Self.longPressKey)
        emptyTouchStart = nil
        cancelDrag(snapBack: true)
    }

    private func cancelDrag(snapBack: Bool) {
        guard let node = dragNode else { return }
        dragNode = nil
        isDragging = false
        clearMergeCandidates()
        returnToAnchor(node, animated: snapBack)
    }

    /// Devuelve un personaje a su ancla y le retoma el paseo.
    ///
    /// Es la parte de `cancelDrag` que no habla del estado del arrastre: el
    /// doble toque también tiene que poder deshacer su deslizamiento cuando la
    /// fusión se rechaza (piso de destino lleno) o queda pendiente (elección de
    /// carrera).
    ///
    /// El z lo retoma `refreshCrowdDepth` en el frame siguiente, ya con el nodo
    /// fuera del gesto. Antes se lo dejaba en 0 durante la vuelta, y ese 0 caía
    /// por debajo del fondo en cualquier piso que no fuera el primero: el
    /// personaje desaparecía los 0,15 s del snap-back.
    private func returnToAnchor(_ node: CharacterNode, animated: Bool = true) {
        // Un paseo a medio correr le pelearía el movimiento a la vuelta durante
        // los 0,15 s del snap-back: al candidato de una fusión rechazada
        // `clearMergeCandidates` ya se lo devolvió.
        node.removeAction(forKey: "wander")
        guard animated else {
            node.position = position(ofCell: node.cellIndex)
            node.setScale(1.0)
            startWander(node)
            return
        }
        node.run(.sequence([
            .group([
                .move(to: position(ofCell: node.cellIndex), duration: 0.15),
                .scale(to: 1.0, duration: 0.15),
            ]),
            .run { [weak self, weak node] in
                guard let node else { return }
                self?.startWander(node)
            },
        ]))
    }

    // MARK: - Fusión asistida

    /// Instantánea de la multitud para `MergeTargeting`, con las posiciones
    /// REALES. Se arma por gesto, nunca por frame.
    private func targetingUnits() -> [MergeTargeting.Unit] {
        characterNodes.map {
            MergeTargeting.Unit(slot: $0.key, typeId: $0.value.typeId, position: $0.value.position)
        }
    }

    /// Al levantar un personaje, sus hermanos del mismo tipo se destacan: suben
    /// por encima de la multitud, pegan un pop y **dejan de deambular**.
    ///
    /// Lo de dejar de deambular es la mitad del valor y no estaba en el pedido:
    /// a 44 pt/s el blanco se te corre más de medio cuerpo por segundo mientras
    /// apuntás. Es el mismo mecanismo con el que el recorte del tutorial congela
    /// a su personaje iluminado.
    ///
    /// Se llama al ARRANCAR el arrastre y no en el `touchesBegan`: un tap para
    /// ganar monedas dura ~100 ms y es la acción más repetida del juego, así que
    /// prender y apagar el realce en cada toque sería un parpadeo permanente.
    private func highlightMergeCandidates(of node: CharacterNode) {
        let dragged = MergeTargeting.Unit(
            slot: node.cellIndex, typeId: node.typeId, position: node.position
        )
        mergeCandidates = MergeTargeting.partnerSlots(of: dragged, among: targetingUnits())
        for slot in mergeCandidates {
            guard let candidate = characterNodes[slot] else { continue }
            candidate.removeAction(forKey: "wander")
            candidate.run(
                .scale(to: Self.candidateScale, duration: Self.candidatePopDuration),
                withKey: "candidate"
            )
        }
    }

    /// Devuelve a los destacados a la multitud. Idempotente: la llaman los dos
    /// finales del arrastre y también `resolveDrop`.
    private func clearMergeCandidates() {
        guard !mergeCandidates.isEmpty else { return }
        let slots = mergeCandidates
        mergeCandidates = []
        for slot in slots {
            guard let candidate = characterNodes[slot] else { continue }
            candidate.removeAction(forKey: "candidate")
            candidate.run(.scale(to: 1.0, duration: Self.candidatePopDuration))
            startWander(candidate)
        }
    }

    /// Punto del campo → slot destino. La regla vive en `MergeTargeting`.
    private func dropTarget(at point: CGPoint, dragging node: CharacterNode) -> Int? {
        MergeTargeting.dropTarget(
            at: point,
            dragging: MergeTargeting.Unit(
                slot: node.cellIndex, typeId: node.typeId, position: node.position
            ),
            units: targetingUnits(),
            anchors: anchorPoints,
            cellSize: cellSize
        )
    }

    /// Tap corto (§2.3 regla 1) y, si es el segundo sobre el mismo personaje, la
    /// fusión asistida.
    ///
    /// El tap **cobra siempre y primero**: el loop principal del juego no puede
    /// pagar los 0,3 s de latencia que costaría esperar a ver si viene un
    /// segundo toque. La fusión es un efecto adicional del segundo toque, no un
    /// modo distinto — y así el jugador tampoco pierde monedas por fusionar.
    private func handleTap(on node: CharacterNode, at timestamp: TimeInterval) {
        let slot = node.cellIndex
        if let result = gameState.registerTap(cellIndex: slot) {
            runTapFeedback(on: node, result: result)
        }

        let isDoubleTap = slot == lastTapSlot && timestamp - lastTapTime <= Self.doubleTapWindow
        lastTapSlot = slot
        lastTapTime = timestamp
        guard isDoubleTap,
              timestamp - lastAssistedMergeTime > Self.assistedMergeCooldown,
              let partner = nearestMergePartner(of: node)
        else { return }

        lastAssistedMergeTime = timestamp
        // Sin esto, tres toques seguidos serían dos fusiones: el tercero forma
        // par con el segundo.
        lastTapSlot = -1
        runAssistedMerge(partner: partner, into: node)
    }

    private func nearestMergePartner(of node: CharacterNode) -> CharacterNode? {
        let tapped = MergeTargeting.Unit(
            slot: node.cellIndex, typeId: node.typeId, position: node.position
        )
        guard let partner = MergeTargeting.nearestPartner(
            of: tapped,
            among: targetingUnits(),
            within: cellSize * MergeTargeting.doubleTapReachRatio
        ) else { return nil }
        return characterNodes[partner.slot]
    }

    /// El compañero se acerca y se funde con el que tocaste. La fusión en sí la
    /// resuelve `resolveDrop`, el mismo camino que el arrastre.
    ///
    /// El que viaja entra a `mergeCandidates` mientras dura el viaje: es lo que
    /// lo mantiene por encima de la multitud, porque `refreshCrowdDepth` le
    /// pisaría cualquier z asignado a mano en el frame siguiente.
    ///
    /// No lleva haptic propio: la fusión ya trae el suyo 0,18 s después y dos
    /// vibraciones seguidas se leen como un error, no como un gesto que enganchó.
    /// El deslizamiento arranca en el frame siguiente al toque, así que la
    /// confirmación es visual e inmediata igual.
    private func runAssistedMerge(partner: CharacterNode, into target: CharacterNode) {
        let originCell = partner.cellIndex
        let targetCell = target.cellIndex
        // El destino sigue deambulando durante el viaje, pero a 44 pt/s son 8 pt
        // en 0,18 s: invisible contra un cuerpo de ~117 pt de ancho. Congelarlo
        // costaría tener que descongelarlo en los caminos de rechazo.
        let meetingPoint = target.position

        partner.removeAction(forKey: "wander")
        mergeCandidates.insert(originCell)

        let reduceMotion = Self.prefersReducedMotion
        let approach = SKAction.move(to: meetingPoint, duration: Self.assistedMergeSlide)
        approach.timingMode = .easeIn
        let slide: SKAction = reduceMotion
            ? .move(to: meetingPoint, duration: 0.01)
            : .group([
                approach,
                .sequence([
                    .scale(to: 1.16, duration: Self.assistedMergeSlide * 0.5),
                    .scale(to: 0.94, duration: Self.assistedMergeSlide * 0.5),
                ]),
            ])

        partner.run(.sequence([
            slide,
            .run { [weak self, weak partner] in
                guard let self, let partner else { return }
                self.resolveDrop(
                    from: originCell, to: targetCell, at: meetingPoint, sourceNode: partner
                )
            },
        ]), withKey: "assistedMerge")
    }

    #if DEBUG
    /// Puntos de entrada del test: ejecutan las MISMAS funciones que los gestos,
    /// para que lo que se fija sea el comportamiento y no una copia suya. Sin
    /// `SKView` no hay quien evalúe las acciones, así que el test observa el
    /// estado que dejan (z, escala, paseo) y no el final de la animación.
    func simulateGrab(slot: Int) {
        guard let node = characterNodes[slot] else { return }
        highlightMergeCandidates(of: node)
        refreshCrowdDepth()
    }

    func simulateRelease() {
        clearMergeCandidates()
        refreshCrowdDepth()
    }

    func simulateTap(slot: Int, at timestamp: TimeInterval) {
        guard let node = characterNodes[slot] else { return }
        handleTap(on: node, at: timestamp)
    }

    func debugNode(atSlot slot: Int) -> CharacterNode? { characterNodes[slot] }
    #endif

    /// Hit-testing returns the deepest node (sprite/label); climb to the unit.
    private func characterNode(at point: CGPoint) -> CharacterNode? {
        // Entre los personajes cuyo cuerpo contiene el toque, elegir el de
        // ADELANTE (mayor zPosition); ante empate, el de centro más cercano. Es
        // más fiable que `nodes(at:)` cuando están amontonados y sus cajas
        // transparentes se solapan.
        //
        // La zona es una ELIPSE, no un círculo. El sprite mide ~2× `cellSize` de
        // alto desde los pies, así que el círculo viejo —centrado a 0.25 con
        // radio 0.82— llegaba hasta 1.07 y dejaba LA CABEZA AFUERA: tocarla no
        // seleccionaba nada. Se estira sólo en vertical; agrandar también el
        // ancho haría que un toque se coma al vecino de al lado, que están a
        // menos de un `cellSize` de distancia.
        let local = fieldNode.convert(point, from: self)
        let halfWidth = cellSize * 0.82
        let halfHeight = cellSize * 1.15
        var best: (node: CharacterNode, z: CGFloat, dist: CGFloat)?
        for (_, node) in characterNodes {
            let dx = (local.x - node.position.x) / halfWidth
            // Centro del cuerpo: el ancla son los PIES y la figura crece hacia
            // arriba, así que el óvalo se centra bien alto.
            let dy = (local.y - (node.position.y + cellSize * 0.9)) / halfHeight
            let dist = hypot(dx, dy)
            guard dist <= 1 else { continue }
            if best == nil || node.zPosition > best!.z
                || (node.zPosition == best!.z && dist < best!.dist) {
                best = (node, node.zPosition, dist)
            }
        }
        return best?.node
    }

    /// Bounce + "+N" flotante; crit y golden gritan más fuerte. F5.2 suma
    /// partículas, SFX y haptics ricos.
    private func runTapFeedback(on node: CharacterNode, result: GameState.TapResult) {
        node.removeAction(forKey: "tapBounce")
        let punch: CGFloat = result.isCrit || result.isGolden ? 1.22 : 1.12
        node.run(
            .sequence([.scale(to: punch, duration: 0.06), .scale(to: 1.0, duration: 0.1)]),
            withKey: "tapBounce"
        )

        particles.emit(result.isCrit || result.isGolden ? .coins : .tap, at: node.position, in: fieldNode)
        if result.isGolden || result.isCrit {
            gameState.playHaptic(.rarity)
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+\(CoinFormatter.string(from: result.gain))"
        label.fontSize = result.isCrit || result.isGolden ? 24 : 17
        label.fontColor = result.isGolden ? Palette.yellow : (result.isCrit ? SKColor(named: "PalettePink") ?? .red : Palette.ink)
        label.position = CGPoint(x: node.position.x, y: node.position.y + 34)
        label.zPosition = 100
        fieldNode.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: result.isCrit || result.isGolden ? 44 : 30, duration: 0.55), .fadeOut(withDuration: 0.55)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Reveal de evolución (bible §8: el momento de video vertical)

    private func runEvolutionReveal(
        for type: CharacterType,
        at position: CGPoint?,
        completion: @escaping () -> Void = {}
    ) {
        let reduceMotion = Self.prefersReducedMotion
        let hold: TimeInterval = 1.5

        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 200
        cameraOverlay.addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: reduceMotion ? 0.35 : 0.75, duration: 0.08),
            .fadeOut(withDuration: 0.35),
            .removeFromParent(),
        ]))

        if let position, !reduceMotion {
            particles.emit(.evolution, at: position, in: fieldNode)
        }

        // Scrim para enfocar la atención en el personaje recién desbloqueado.
        let scrim = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.72), size: size)
        scrim.anchorPoint = .zero
        scrim.position = .zero
        scrim.zPosition = 195
        scrim.alpha = 0
        cameraOverlay.addChild(scrim)
        scrim.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.2),
            .wait(forDuration: hold),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]), completion: completion)

        // Foto del personaje: el arte real (o el placeholder) en grande y centrado.
        if let content = gameState.content,
           let texture = renderer.texture(for: type, manifest: content.manifest) {
            let side = min(size.width * 0.82, size.height * 0.52)
            let photo = SKSpriteNode(texture: texture)
            photo.size = CGSize(width: side, height: side)
            photo.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
            photo.zPosition = 208
            photo.alpha = 0
            photo.setScale(reduceMotion ? 1.0 : 0.5)
            cameraOverlay.addChild(photo)
            let photoIn: SKAction = reduceMotion
                ? .fadeIn(withDuration: 0.25)
                : .group([.fadeIn(withDuration: 0.18), .sequence([.scale(to: 1.1, duration: 0.24), .scale(to: 1.0, duration: 0.12)])])
            photo.run(.sequence([
                photoIn,
                .wait(forDuration: hold - 0.2),
                .fadeOut(withDuration: 0.3),
                .removeFromParent(),
            ]))
        }

        // Etiqueta "¡NUEVO!" arriba de todo.
        let tag = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        tag.text = "¡NUEVO!"
        tag.fontSize = 24
        tag.fontColor = Palette.yellow
        tag.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        tag.zPosition = 210
        tag.alpha = 0
        tag.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: hold + 0.1),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
        cameraOverlay.addChild(tag)

        // Nombre del personaje ARRIBA de la foto.
        let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        banner.text = type.displayName.uppercased()
        banner.fontSize = 38
        // La entrada agranda el banner un 15% en su pico, así que el ancho útil
        // se descuenta: si no, un nombre que entra justo se corta al aparecer.
        let peakScale: CGFloat = reduceMotion ? 1.0 : 1.15
        BoardScene.shrinkToFit(banner, maxWidth: (size.width - Self.revealMargin * 2) / peakScale)
        banner.fontColor = SKColor(named: "PalettePink") ?? .magenta
        banner.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        banner.zPosition = 210
        banner.alpha = 0
        banner.setScale(reduceMotion ? 1.0 : 0.4)
        cameraOverlay.addChild(banner)

        let entrance: SKAction = reduceMotion
            ? .fadeIn(withDuration: 0.25)
            : .group([.fadeIn(withDuration: 0.15), .sequence([.scale(to: 1.15, duration: 0.2), .scale(to: 1.0, duration: 0.1)])])
        // El reveal cierra solo; ya no se ofrece el share card (interrumpía el
        // ritmo del juego). offerShareCard sigue disponible por si se dispara
        // desde otro lado en el futuro.
        banner.run(.sequence([
            entrance,
            .wait(forDuration: hold),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
    }

    // MARK: - Layout (campo, no grilla)

    /// Reconstruye el campo: fondo del PISO VISIBLE (F7 La Torre), anclas
    /// orgánicas y personajes parados con orden de profundidad por Y.
    func layoutBoard() {
        guard let content = gameState.content, gameState.player != nil,
              let floorDef = gameState.visibleFloorDef else { return }
        lastLayoutSize = size
        renderedBoardVersion = gameState.boardVersion

        let floorOffset = CGFloat(gameState.visibleFloorOrdinal) * size.height
        backgroundLayer.position = .zero

        // Grilla del piso: 2 filas (franja de multitud), columnas según capacidad.
        boardRows = 2
        boardColumns = max(1, (floorDef.capacity + boardRows - 1) / boardRows)

        // Los personajes conviven en la franja de piso (parte inferior de la
        // pantalla, donde el fondo generado tiene el suelo). La celda se ajusta al
        // ancho para que entren las columnas; las filas se apilan cerca y hacia
        // arriba (profundidad de multitud, no una grilla que llena la pantalla).
        let availableWidth = size.width - Self.horizontalInset * 2
        cellSize = availableWidth / CGFloat(max(boardColumns, 1))
        fieldNode.position = CGPoint(x: Self.horizontalInset, y: Self.bottomInset + floorOffset)

        cameraOverlay.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
        moveCameraIfNeeded(to: floorOffset)

        rebuildAnchors(capacity: floorDef.capacity)
        // `moveCameraIfNeeded` ya decidió si esto es un vuelo. Si lo es, los
        // fondos arrancan donde ESTÁ la cámara (el piso de salida) y el vuelo se
        // encarga de ir trayendo el resto; centrarlos en el destino cargaría un
        // fondo que se descarga en el frame siguiente.
        renderLiveFloorNodes(content: content, centeredOn: isFlying ? cameraFloorOrdinal : gameState.visibleFloorOrdinal)
        renderPlacements(content: content)
        renderAnchoredSpecials(content: content)
        renderLockedFloorOverlay()
    }

    /// Los specials no ocupan slot (⚠️5): se anclan al borde del piso donde
    /// cayeron, detrás de la multitud, como parte del decorado. No son
    /// interactivos — `cellIndex(at:)` sólo mira `characterNodes`.
    private func renderAnchoredSpecials(content: GameContent) {
        fieldNode.children
            .filter { $0.name?.hasPrefix(Self.specialNodePrefix) == true }
            .forEach { $0.removeFromParent() }

        let specials = gameState.visibleFloorSpecials
        guard !specials.isEmpty else { return }

        let side = cellSize * 0.62
        for (index, special) in specials.enumerated() {
            guard let asset = content.manifest.characters[special.id] else { continue }
            guard let texture = AtlasCache.texture(named: asset.key, inAtlas: asset.atlas) else { continue }

            let node = SKSpriteNode(texture: texture)
            node.name = Self.specialNodePrefix + special.id
            node.size = CGSize(width: side, height: side)
            // Alternan izquierda/derecha y suben por el fondo del campo, para no
            // taparse entre sí ni pisar las anclas de personajes.
            let isLeft = index.isMultiple(of: 2)
            let row = CGFloat(index / 2)
            node.position = CGPoint(
                x: isLeft ? side * 0.55 : size.width - Self.horizontalInset * 2 - side * 0.55,
                y: cellSize * 1.65 + row * side * 0.9
            )
            node.zPosition = Self.specialZ(band: band, rows: boardRows, cellSize: cellSize)
            node.alpha = 0.95
            fieldNode.addChild(node)
        }
    }

    /// Mantiene sólo un piso y sus vecinos inmediatos. El resto de los fondos se
    /// descarga; al volver a entrar se reconstruyen desde el manifest.
    ///
    /// El centro es un parámetro y no `visibleFloorOrdinal` porque durante un
    /// vuelo del mapa lo manda la cámara, que va pasando por los pisos del medio.
    private func renderLiveFloorNodes(content: GameContent, centeredOn center: Int) {
        liveFloorCenter = center
        let visible = gameState.visibleFloorOrdinal
        // Un piso a cada lado alcanza cuando la cámara se mueve de a uno. En
        // pleno vuelo cruza más de un piso por cuadro, así que el de adelante
        // tiene que estar montado ANTES de asomarse o se ve el crema del fondo
        // de escena entre medio.
        let radius = isFlying ? 2 : 1
        let lower = max(0, center - radius)
        let upper = min(content.floorTable.floors.count - 1, center + radius)
        let liveOrdinals = Set(lower...upper)

        // Primero materializamos las claves: mutar un Dictionary mientras se lo
        // enumera puede invalidar su iterador al desalojar un piso lejano.
        let staleOrdinals = floorNodes.keys.filter { !liveOrdinals.contains($0) }
        for ordinal in staleOrdinals {
            floorNodes.removeValue(forKey: ordinal)?.removeFromParent()
        }

        for ordinal in liveOrdinals {
            let definition = content.floorTable[ordinal]
            let node = floorNodes[ordinal] ?? FloorNode(ordinal: ordinal, definition: definition)
            node.position = CGPoint(x: 0, y: CGFloat(ordinal) * size.height)
            node.render(content: content, size: size)
            node.isPaused = ordinal != visible
            if floorNodes[ordinal] == nil {
                backgroundLayer.addChild(node)
                floorNodes[ordinal] = node
            }
        }
    }

    /// Lleva la cámara al piso visible. Un piso de distancia es un salto corto;
    /// más de uno es el **vuelo** del mapa (RF-08): la cámara recorre los pisos
    /// del medio en vez de teletransportarse, así el jugador ve qué se saltea.
    private func moveCameraIfNeeded(to floorOffset: CGFloat) {
        let destination = gameState.visibleFloorOrdinal
        let target = CGPoint(x: size.width / 2, y: size.height / 2 + floorOffset)
        // Con un vuelo en curso la cámara todavía NO está en el target: sin el
        // `!isFlying` cualquier relayout lo cortaría en el aire y lo reiniciaría
        // como salto corto desde donde hubiera quedado.
        guard displayedFloorOrdinal != destination || (cameraNode.position != target && !isFlying) else { return }
        // El primer layout no viene de ningún piso: arrancar la partida en el
        // piso 6 no es un vuelo de seis pisos.
        let origin = displayedFloorOrdinal
        let distance = origin < 0 ? 0 : abs(destination - origin)
        displayedFloorOrdinal = destination
        cameraNode.removeAction(forKey: Self.floorCameraKey)
        isFlying = false
        guard !Self.prefersReducedMotion else {
            cameraNode.position = target
            return
        }
        guard distance > 1, let totalFloors = gameState.floorTable?.floors.count else {
            cameraNode.run(.move(to: target, duration: Self.floorHopDuration), withKey: Self.floorCameraKey)
            return
        }
        let flight = SKAction.move(to: target, duration: Self.flightDuration(floors: distance, totalFloors: totalFloors))
        // Arranca y frena suave: sin esto el vuelo largo parece un corte, que es
        // justo lo que el mapa vino a reemplazar.
        flight.timingMode = .easeInEaseOut
        isFlying = true
        preloadFlightBackgrounds(from: origin, to: destination)
        cameraNode.run(
            .sequence([flight, .run { [weak self] in self?.finishFlight() }]),
            withKey: Self.floorCameraKey
        )
    }

    /// Cuánto dura el vuelo entre dos pisos que no son vecinos.
    ///
    /// Crece con la distancia pero se **aplana contra el alto de la torre**: dos
    /// pisos ya tienen que leerse como vuelo y el salto más largo posible no
    /// puede durar diez veces más. El techo sale de `floors[]`, así que el
    /// presupuesto sigue siendo el mismo cuando la torre pase de once pisos a
    /// diez.
    static func flightDuration(floors: Int, totalFloors: Int) -> TimeInterval {
        let longest = max(3, totalFloors - 1)
        let span = Double(min(max(floors, 2), longest) - 2) / Double(longest - 2)
        // Interpolación en los dos extremos (y no `min + delta * span`) para que
        // los bordes den 0,6 y 0,9 exactos y no 0,8999999999999999.
        return flightMinDuration * (1 - span) + flightMaxDuration * span
    }

    /// El piso sobre el que está la cámara AHORA, que durante un vuelo no es el
    /// de destino.
    private var cameraFloorOrdinal: Int {
        guard size.height > 0, let count = gameState.floorTable?.floors.count else {
            return gameState.visibleFloorOrdinal
        }
        let raw = Int(((cameraNode.position.y - size.height / 2) / size.height).rounded())
        return min(max(0, raw), count - 1)
    }

    /// Durante el vuelo los fondos los manda la cámara y no el destino: si no,
    /// ir del callejón a la Luna sería un tubo vacío con los dos extremos
    /// pintados. Sigue siendo el rango visible ±1 — nunca están los once pisos
    /// cargados a la vez.
    private func streamFloorsAlongFlight() {
        guard let content = gameState.content else { return }
        let center = cameraFloorOrdinal
        guard center != liveFloorCenter else { return }
        renderLiveFloorNodes(content: content, centeredOn: center)
    }

    /// Manda las texturas del recorrido a la GPU **antes** de que la cámara pase
    /// por ellas. Los `FloorNode` se siguen montando y desmontando sobre la
    /// marcha: lo que se adelanta es la subida de la textura, que es lo único
    /// que no llega a tiempo.
    ///
    /// Medido sobre el salto más largo (callejón → Dios): sin esto, once
    /// cuadros seguidos con ~60% de la pantalla en crema; con esto, uno solo.
    ///
    /// El costo es tener los fondos del camino residentes durante los 0,9 s del
    /// vuelo (≈9 MB cada uno a 3×). Las referencias se sueltan al aterrizar,
    /// así que el pico no sobrevive a la animación.
    private func preloadFlightBackgrounds(from origin: Int, to destination: Int) {
        guard let content = gameState.content else { return }
        let range = min(origin, destination)...max(origin, destination)
        flightTextures = range.compactMap { ordinal -> SKTexture? in
            guard content.floorTable.floors.indices.contains(ordinal),
                  let asset = content.manifest.backgrounds[content.floorTable[ordinal].background],
                  !asset.isEmpty, UIImage(named: asset) != nil else { return nil }
            return SKTexture(imageNamed: asset)
        }
        // ⚠️ El handler tiene que ser `@Sendable`. SpriteKit lo llama desde una
        // cola de fondo y `BoardScene` es `@MainActor` (SKScene lo es en el
        // SDK), así que un `{}` pelado hereda el aislamiento y el runtime de
        // concurrencia mata el proceso con SIGTRAP apenas termina la precarga.
        SKTexture.preload(flightTextures) { @Sendable in }
    }

    private func finishFlight() {
        isFlying = false
        flightTextures = []
        guard let content = gameState.content else { return }
        renderLiveFloorNodes(content: content, centeredOn: gameState.visibleFloorOrdinal)
    }

    /// Una promoción ya fue aplicada por EconomyKit antes de llegar acá. SpriteKit
    /// sólo presenta un clon temporal: vuela hacia el piso superior y vuelve al
    /// pool al finalizar, por lo que no deja un nodo interactivo duplicado.
    private func runAscentAnimation(
        type: CharacterType,
        from start: CGPoint,
        completion: @escaping () -> Void = {}
    ) {
        guard let content = gameState.content else { completion(); return }
        let skinTreatment = SkinResolver.treatment(
            for: gameState.activeSkinID(forCharacterType: type.id),
            characterType: type.id,
            config: content.skins
        )
        let flight = pool.obtain()
        let hasRealArt = content.manifest.characters[type.id] != nil
        flight.configure(
            type: type,
            texture: renderer.texture(
                for: type,
                manifest: content.manifest,
                skinTextureKey: {
                    if case let .texture(key) = skinTreatment { return key }
                    return nil
                }()
            ),
            cellIndex: -1,
            cellSize: cellSize,
            skinTint: SkinResolver.tintColor(for: skinTreatment),
            hasRealArt: hasRealArt
        )
        flight.position = start
        flight.zPosition = 120
        flight.setScale(0.92)
        backgroundLayer.addChild(flight)
        gameState.playAscentFeedback()

        let destination = CGPoint(x: start.x, y: start.y + size.height * Self.ascentDistanceRatio)
        let flightAction: SKAction = Self.prefersReducedMotion
            ? .move(to: destination, duration: 0.01)
            : .group([
                .move(to: destination, duration: Self.ascentDuration),
                .sequence([
                    .scale(to: 1.12, duration: Self.ascentDuration * 0.45),
                    .scale(to: 0.72, duration: Self.ascentDuration * 0.55),
                ]),
                .sequence([
                    .wait(forDuration: Self.ascentDuration * 0.7),
                    .fadeOut(withDuration: Self.ascentDuration * 0.3),
                ]),
            ])
        // El completion va acá y no al final del método: más abajo hay un
        // `guard` por el asset del flash que puede cortar, y la cadena no puede
        // depender de que ese asset exista.
        flight.run(.sequence([
            flightAction,
            .run { [weak self, weak flight] in
                if let flight { self?.pool.recycle(flight) }
                completion()
            },
        ]))

        particles.emit(.evolution, at: start, in: backgroundLayer)
        guard let flashAsset = content.manifest.ui["fx_evolution_flash"] else { return }
        let flash = SKSpriteNode(texture: AtlasCache.atlas(named: "ui").textureNamed(flashAsset))
        let flashSide = cellSize * 2.1
        flash.size = CGSize(width: flashSide, height: flashSide)
        flash.position = start
        flash.zPosition = 121
        backgroundLayer.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1.35, duration: 0.16), .fadeOut(withDuration: 0.24)]),
            .removeFromParent(),
        ]))
    }

    /// El primer ascenso que abre un piso conserva el vuelo en pantalla y, al
    /// terminar, lleva la cámara a la nueva escena. En promociones posteriores
    /// la cámara no roba el foco: queda un indicador de ascenso en F7.2.
    private func runFloorUnlockCelebration(
        floorID: String,
        destinationOrdinal: Int,
        completion: @escaping () -> Void = {}
    ) {
        let reduceMotion = Self.prefersReducedMotion
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = String(localized: "tower.unlock.title")
        title.fontSize = 29
        title.fontColor = Palette.yellow
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.63)
        title.zPosition = 220
        title.alpha = 0
        cameraOverlay.addChild(title)
        let titleEntrance: SKAction = reduceMotion
            ? .fadeIn(withDuration: 0.01)
            : .group([.fadeIn(withDuration: 0.15), .sequence([.scale(to: 1.12, duration: 0.18), .scale(to: 1, duration: 0.1)])])
        title.run(.sequence([
            titleEntrance,
            .wait(forDuration: 0.9),
            .fadeOut(withDuration: 0.22),
            .removeFromParent(),
        ]), completion: completion)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hint.text = String(localized: "tower.unlock.hint")
        hint.fontSize = 18
        hint.fontColor = Palette.cream
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.56)
        hint.zPosition = 220
        hint.alpha = 0
        cameraOverlay.addChild(hint)
        hint.run(.sequence([
            .fadeIn(withDuration: reduceMotion ? 0.01 : 0.15),
            .wait(forDuration: 0.9),
            .fadeOut(withDuration: 0.22),
            .removeFromParent(),
        ]))

        gameState.playFloorUnlockFeedback()
        run(.sequence([
            .wait(forDuration: reduceMotion ? 0.01 : Self.ascentDuration),
            .run { [weak self] in self?.gameState.setVisibleFloor(destinationOrdinal) },
        ]), withKey: "unlockCamera")
        Log.board.info("floor unlocked: \(floorID)")
    }

    /// Ancla por slot: punto de grilla lógica + jitter determinístico
    /// (hash del índice), para que el campo se vea orgánico pero estable entre
    /// launches y consistente con el modelo de slots del piso.
    private func rebuildAnchors(capacity: Int) {
        let cols = max(boardColumns, 1)
        // Margen lateral para que los personajes grandes de las puntas no se corten
        // contra el borde de la pantalla; las columnas se centran dentro del campo.
        let edgeInset = cellSize * 0.68
        let colSpacing = (cellSize * CGFloat(cols) - 2 * edgeInset) / CGFloat(cols)
        band = Self.crowdBand(sceneHeight: size.height, cellSize: cellSize, rows: boardRows)
        let frontY = band.frontY
        let rowDepth = band.rowDepth
        anchorPoints = (0..<capacity).map { index in
            let column = index % cols
            let row = index / cols
            // Filas alternadas corridas un poco (centrado) para asomar entre sí.
            let rowStagger = (row % 2 == 0 ? -1.0 : 1.0) * colSpacing * 0.1
            var hash = UInt64(index &* 2654435761)
            hash = (hash ^ (hash >> 13)) &* 0x9E3779B97F4A7C15
            let jitterX = (CGFloat(hash % 1000) / 1000 - 0.5) * cellSize * 0.08
            let jitterY = (CGFloat((hash >> 10) % 1000) / 1000 - 0.5) * cellSize * 0.06
            return CGPoint(
                x: edgeInset + CGFloat(column) * colSpacing + colSpacing / 2 + rowStagger + jitterX,
                y: frontY + CGFloat(row) * rowDepth + jitterY
            )
        }
    }

    /// Reconcilia en vez de reconstruir: sólo se rearman los slots que de verdad
    /// cambiaron (ver `BoardReconciliation`). Un personaje que sigue igual
    /// conserva su nodo, su posición deambulada y sus acciones a medio correr.
    private func renderPlacements(content: GameContent) {
        var wanted: [Int: RenderedUnit] = [:]
        var types: [Int: CharacterType] = [:]
        for placement in gameState.visiblePlacements {
            guard let type = content.tiers.type(id: placement.typeId) else {
                Log.board.error("placement references unknown type '\(placement.typeId)'")
                continue
            }
            types[placement.slot] = type
            wanted[placement.slot] = RenderedUnit(
                typeId: type.id,
                skinID: gameState.activeSkinID(forCharacterType: type.id),
                cellSize: cellSize,
                columns: boardColumns
            )
        }

        let plan = BoardReconciliation(rendered: renderedUnits, wanted: wanted)

        // Devolver al pool ANTES de pedir: así `obtain()` reutiliza los nodos que
        // se acaban de liberar en vez de alocar de más en cada merge.
        for slot in plan.discarded {
            guard let node = characterNodes.removeValue(forKey: slot) else { continue }
            pool.recycle(node)
        }

        for slot in plan.rebuilt {
            guard let type = types[slot] else { continue }
            let skinTreatment = SkinResolver.treatment(
                for: wanted[slot]?.skinID,
                characterType: type.id,
                config: content.skins
            )
            let hasRealArt = content.manifest.characters[type.id] != nil
            let node = pool.obtain()
            node.configure(
                type: type,
                texture: renderer.texture(
                    for: type,
                    manifest: content.manifest,
                    skinTextureKey: {
                        if case let .texture(key) = skinTreatment { return key }
                        return nil
                    }()
                ),
                cellIndex: slot,
                cellSize: cellSize,
                skinTint: SkinResolver.tintColor(for: skinTreatment),
                hasRealArt: hasRealArt
            )
            node.position = position(ofCell: slot)
            node.zPosition = depthZ(for: node.position)
            node.setScale(1.0)
            fieldNode.addChild(node)
            characterNodes[slot] = node
            startWander(node)
            startFacingFlip(node)
        }

        renderedUnits = wanted
    }

    /// Un único vistazo al siguiente piso bloqueado hace visible la meta sin
    /// convertirlo en un tablero jugable. El scrim vive bajo la cámara, por lo
    /// que acompaña cualquier cambio de piso y no tapa el HUD de SwiftUI.
    private func renderLockedFloorOverlay() {
        cameraOverlay.childNode(withName: "lockedFloorOverlay")?.removeFromParent()
        guard !gameState.visibleFloorIsUnlocked else { return }

        let overlay = SKNode()
        overlay.name = "lockedFloorOverlay"
        overlay.zPosition = 210

        let veil = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        veil.fillColor = .black.withAlphaComponent(0.36)
        veil.strokeColor = .clear
        overlay.addChild(veil)

        let lock = SKNode()
        lock.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        let shackle = SKShapeNode(rectOf: CGSize(width: 38, height: 42), cornerRadius: 18)
        shackle.position.y = 17
        shackle.strokeColor = Palette.cream
        shackle.lineWidth = 5
        shackle.fillColor = .clear
        lock.addChild(shackle)
        let body = SKShapeNode(rectOf: CGSize(width: 62, height: 48), cornerRadius: 8)
        body.position.y = -18
        body.fillColor = Palette.yellow
        body.strokeColor = Palette.ink
        body.lineWidth = 3
        lock.addChild(body)
        overlay.addChild(lock)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = String(localized: "tower.locked.title")
        title.fontSize = 25
        title.fontColor = Palette.cream
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.40)
        overlay.addChild(title)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hint.text = String(localized: "tower.locked.hint")
        hint.fontSize = 17
        hint.fontColor = Palette.cream
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        overlay.addChild(hint)
        cameraOverlay.addChild(overlay)
    }

    /// Los de abajo (más "cerca") tapan a los de arriba — profundidad de campo.
    ///
    /// Es RELATIVA a `fieldNode`, que va montado en `fieldBaseZ`: acá el valor
    /// puede ser negativo sin que eso hunda a nadie detrás del fondo.
    static func depthZ(y: CGFloat, rows: Int, cellSize: CGFloat) -> CGFloat {
        (CGFloat(rows) * cellSize - y) * 0.01
    }

    /// La franja vertical por la que se mueve la multitud, resuelta para una
    /// pantalla y un tamaño de celda concretos.
    struct CrowdBand: Equatable {
        /// Ancla de la fila delantera.
        let frontY: CGFloat
        /// Separación entre anclas de filas consecutivas.
        let rowDepth: CGFloat
        /// Amplitud vertical del deambular, centrada en el ancla (±la mitad).
        let wanderRange: CGFloat
        /// El `y` más alto que puede alcanzar un personaje. Define el z más bajo
        /// de la multitud, que es lo que no puede chocar con los fondos.
        let topY: CGFloat
    }

    /// Reparte las filas dentro de la franja y **deriva el deambular de ella**.
    ///
    /// Que el deambular salga de acá y no sea una constante aparte es lo que
    /// hace imposible que un personaje se vaya por arriba de la franja: cada
    /// fila recorre exactamente `1/rows` del total, así que las filas cubren la
    /// franja entera sin huecos y sin pasarse. Cuando el deambular era un número
    /// independiente sumado encima del ancla, la fila trasera terminó fuera de
    /// rango y detrás del fondo.
    static func crowdBand(sceneHeight: CGFloat, cellSize: CGFloat, rows: Int) -> CrowdBand {
        let rows = max(1, rows)
        let floorY = cellSize * frontRowRatio
        let topY = max(floorY, sceneHeight * crowdTopRatio - bottomInset)
        let usable = topY - floorY
        let halfWander = usable / CGFloat(2 * rows)
        return CrowdBand(
            frontY: floorY + halfWander,
            rowDepth: rows > 1 ? (usable - 2 * halfWander) / CGFloat(rows - 1) : 0,
            wanderRange: halfWander * 2,
            topY: topY
        )
    }

    /// Profundidad de un special: detrás de TODA la multitud, incluido el
    /// personaje que más arriba pueda llegar. Sale de la franja y no de una
    /// constante porque un valor fijo se queda corto en cuanto la franja se
    /// agranda — el techo ya da un `depthZ` de −2 en las pantallas grandes.
    static func specialZ(band: CrowdBand, rows: Int, cellSize: CGFloat) -> CGFloat {
        depthZ(y: band.topY, rows: rows, cellSize: cellSize) - 1
    }

    private func depthZ(for point: CGPoint) -> CGFloat {
        Self.depthZ(y: point.y, rows: boardRows, cellSize: cellSize)
    }

    /// Deambulación idle alrededor del ancla (estilo Cow Evolution). Se corta al
    /// agarrar el nodo y se reinicia al soltarlo/relayout.
    private func startWander(_ node: CharacterNode) {
        node.removeAction(forKey: "wander")
        guard !Self.prefersReducedMotion else { return }
        let anchor = position(ofCell: node.cellIndex)
        var hash = UInt64(node.cellIndex &* 40503 &+ 7)
        // Se generan los tres destinos primero para poder darle a cada paso una
        // duración proporcional a lo que recorre: con una duración fija, una
        // franja más alta no los haría pasear más lejos sino correr más rápido.
        let stops: [(point: CGPoint, pause: TimeInterval)] = (0..<3).map { _ in
            hash = (hash ^ (hash >> 13)) &* 0x9E3779B97F4A7C15
            let dx = (CGFloat(hash % 100) / 100 - 0.5) * Self.wanderHorizontalRange
            let dy = (CGFloat((hash >> 8) % 100) / 100 - 0.5) * band.wanderRange
            return (CGPoint(x: anchor.x + dx, y: anchor.y + dy), 0.6 + Double(hash % 140) / 100)
        }
        let steps = stops.indices.map { index -> SKAction in
            let previous = stops[(index + stops.count - 1) % stops.count].point
            let stop = stops[index]
            let distance = hypot(stop.point.x - previous.x, stop.point.y - previous.y)
            // Mira hacia donde camina. El `dx` ya está calculado y el espejado es
            // una multiplicación: el rumbo sale gratis, y sin él un personaje que
            // se va para la izquierda camina de espaldas.
            let facesLeft = stop.point.x < previous.x
            return .sequence([
                .wait(forDuration: stop.pause),
                .run { [weak node] in node?.setFacing(left: facesLeft) },
                .move(to: stop.point, duration: max(0.8, Double(distance / Self.wanderSpeed))),
            ])
        }
        node.run(.repeatForever(.sequence(steps)), withKey: "wander")
    }

    /// Cada tanto un personaje se da vuelta solo, camine o no.
    ///
    /// Es lo que mantiene viva a la multitud cuando NO camina: el rumbo del
    /// paseo sólo espeja al que se está moviendo, y los que están congelados —el
    /// candidato de una fusión, el blanco del recorte del tutorial— se quedarían
    /// mirando fijo hacia el mismo lado. Por eso NO comparte clave ni ciclo de
    /// vida con `"wander"`: no se apaga con él, no se re-arranca con él. Lo
    /// encarga `renderPlacements` y lo borra el pool al reciclar.
    private func startFacingFlip(_ node: CharacterNode) {
        node.removeAction(forKey: CharacterNode.facingActionKey)
        // Un volteo es movimiento: va detrás del mismo guard que el paseo.
        guard !Self.prefersReducedMotion else { return }
        // La fase inicial sale del `cellIndex` —el mismo hash del paseo— y no del
        // azar de SpriteKit: los diez arrancan en el mismo instante, así que con
        // una espera común se darían vuelta todos juntos, como un cardumen.
        var hash = UInt64(bitPattern: Int64(node.cellIndex &* 40503 &+ 7))
        hash = (hash ^ (hash >> 13)) &* 0x9E3779B97F4A7C15
        let phase = Double(hash % 100) / 100 * Self.facingFlipPeriod
        node.run(.sequence([
            .wait(forDuration: phase),
            .repeatForever(.sequence([
                .wait(forDuration: Self.facingFlipPeriod, withRange: Self.facingFlipJitter),
                .run { [weak node] in
                    guard let node else { return }
                    node.setFacing(left: !node.isFacingLeft)
                },
            ])),
        ]), withKey: CharacterNode.facingActionKey)
    }

    /// Ancla del cellIndex (campo orgánico).
    private func position(ofCell index: Int) -> CGPoint {
        guard index >= 0, index < anchorPoints.count else { return .zero }
        return anchorPoints[index]
    }

}
