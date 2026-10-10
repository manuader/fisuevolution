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
        node.setVisible(true)
        videoNode = node
    }

    /// Suelta el cupo del pool y saca el nodo de video.
    func removeClip() {
        videoNode?.stop()
        videoNode?.removeFromParent()
        videoNode = nil
        videoClip = nil
    }

    /// El bamboleo al caminar: unos puntos arriba y abajo, tres pasos por segundo.
    func walkBob(delta: TimeInterval) -> CGFloat {
        clock += delta
        return CGFloat(abs(sin(clock * .pi * 3))) * 4
    }

    /// El pulso de espera: respira.
    func breathe(delta: TimeInterval) {
        clock += delta
        setScale(1 + 0.03 * CGFloat(sin(clock * .pi * 1.6)))
    }
}
