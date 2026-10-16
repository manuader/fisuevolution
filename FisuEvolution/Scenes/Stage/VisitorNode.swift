import SpriteKit

/// Quien está en escena. Lo mueve `StageController` por frame.
final class VisitorNode: SKSpriteNode {
    let visitId: UUID
    let actorId: String
    private var clock: TimeInterval = 0
    private let loops: LoopsManifest
    private let pool: VideoPlayerPool
    private let packs: ArtPacks
    private var videoNode: LoopingVideoNode?

    private(set) var videoClip: ArtClip?
    /// El arte de `npcs.atlas` mira apenas hacia la izquierda de la pantalla: caminando a la derecha
    /// se lo da vuelta (B20), como a los empleados.
    static let drawnHeading: CGFloat = -1
    /// −1 dado vuelta, 1 como está dibujado.
    private(set) var facing: CGFloat = 1

    init(visitId: UUID, actorId: String, texture: SKTexture, side: CGFloat,
         loops: LoopsManifest = .main, pool: VideoPlayerPool = .shared, packs: ArtPacks = .shared) {
        self.visitId = visitId
        self.actorId = actorId
        self.loops = loops
        self.pool = pool
        self.packs = packs
        super.init(texture: texture, color: .clear, size: CGSize(width: side, height: side))
        anchorPoint = CGPoint(x: 0.5, y: 0)
        name = "stage.actor"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("VisitorNode is never decoded")
    }

    func resize(side: CGFloat) {
        size = CGSize(width: side, height: side)
        videoNode?.position = CGPoint(x: 0, y: side / 2)
    }

    /// Monta, cambia o saca el clip del actor. El póster es el primer cuadro de la pose del clip: lo
    /// dibuja el `LoopingVideoNode` y el actor suelta su textura mientras tanto, para no doblar el alfa.
    /// El mismo clip no se vuelve a montar.
    func showClip(_ clip: ArtClip?, poster: SKTexture) {
        guard let clip else {
            removeClip()
            if texture !== poster { texture = poster }
            return
        }
        guard clip != videoClip else { return }
        removeClip()
        videoClip = clip
        texture = nil
        let node = LoopingVideoNode(clip: clip, poster: poster, size: size, role: .popup,
                                    manifest: loops, pool: pool, packs: packs)
        node.position = CGPoint(x: 0, y: size.height / 2)
        addChild(node)
        node.setVisible(!isHidden)
        videoNode = node
    }

    /// Suelta el cupo del pool y saca el nodo de video.
    func removeClip() {
        videoNode?.stop()
        videoNode?.removeFromParent()
        videoNode = nil
        videoClip = nil
    }

    /// El bamboleo al caminar: unos puntos arriba y abajo, tres pasos por segundo. Pisando fuerte
    /// (`stomp`, el vendedor ofendido): pasos más rápidos y más altos.
    func walkBob(delta: TimeInterval, stomp: Bool = false) -> CGFloat {
        clock += delta
        return stomp ? CGFloat(abs(sin(clock * .pi * 5))) * 8 : CGFloat(abs(sin(clock * .pi * 3))) * 4
    }

    /// Fuera de la pantalla (su piso no se ve) el video suelta su cupo.
    func setOnScreen(_ onScreen: Bool) {
        guard isHidden == onScreen else { return }
        isHidden = !onScreen
        videoNode?.setVisible(onScreen)
    }

    /// El pulso de espera: respira.
    func breathe(delta: TimeInterval) {
        clock += delta
        scaleKeepingFacing(1 + 0.03 * CGFloat(sin(clock * .pi * 1.6)))
    }

    /// Mira hacia donde camina: `heading` 1 a la derecha, −1 a la izquierda.
    func face(_ heading: CGFloat) {
        facing = (heading < 0) == (Self.drawnHeading < 0) ? 1 : -1
        xScale = abs(xScale) * facing
    }

    /// La escala por distancia (`DepthScale`, E14b B30): se multiplica a la que piden la respiración
    /// y el resto. Los pies quedan en su sitio porque el ancla del nodo está abajo.
    private(set) var depthScale: CGFloat = 1
    /// La última escala pedida, sin la de la distancia.
    private(set) var baseScale: CGFloat = 1

    func setDepthScale(_ scale: CGFloat) {
        guard scale.isFinite, scale > 0, abs(scale - depthScale) > 0.0005 else { return }
        depthScale = scale
        scaleKeepingFacing(baseScale)
    }

    /// La escala, sin perder hacia dónde mira.
    func scaleKeepingFacing(_ scale: CGFloat) {
        baseScale = scale
        xScale = scale * depthScale * facing
        yScale = scale * depthScale
    }

    /// ¿Cae `point` (coordenadas del padre) sobre el visitante? El área nunca baja de
    /// `DepthScale.minTouchSide`, aunque la distancia lo achique. Parte del `frame` propio (lo mismo que
    /// `contains`): el acumulado agrandaría el área con el badge y el video.
    func isHit(by point: CGPoint) -> Bool {
        DepthScale.enforcingMinimumTouch(frame).contains(point)
    }
}
