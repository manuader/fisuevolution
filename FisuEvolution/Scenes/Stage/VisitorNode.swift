import SpriteKit

/// Quien está en escena. Lo mueve `StageController` por frame.
final class VisitorNode: SKSpriteNode {
    let visitId: UUID
    let actorId: String
    private var clock: TimeInterval = 0

    init(visitId: UUID, actorId: String, texture: SKTexture, side: CGFloat) {
        self.visitId = visitId
        self.actorId = actorId
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
