import CoreGraphics

/// La geometría del escenario (PLAN-v2 E4): x ∈ [28 %, 72 %] del ancho, para no
/// quedar bajo los botones flotantes de los costados, y parado delante de la
/// multitud, arriba de la franja de abajo. Coordenadas de la capa de la cámara
/// (origen abajo a la izquierda, del tamaño de la escena).
struct StageLayout: Equatable {
    static let leftEdge: CGFloat = 0.28
    static let rightEdge: CGFloat = 0.72
    /// Lo que camina un visitante, en pt/s.
    static let walkSpeed: CGFloat = 90
    /// Un visitante es algo más alto que un empleado: viene de afuera.
    static let actorScale: CGFloat = 1.35
    static let bubbleMargin: CGFloat = 12

    let sceneSize: CGSize
    let bottomInset: CGFloat
    let cellSize: CGFloat

    var actorSide: CGFloat { cellSize * Self.actorScale }
    var baselineY: CGFloat { bottomInset + cellSize * 0.25 }
    var stageRange: ClosedRange<CGFloat> { sceneSize.width * Self.leftEdge...sceneSize.width * Self.rightEdge }
    var standX: CGFloat { (stageRange.lowerBound + stageRange.upperBound) / 2 }
    var bubbleMaxWidth: CGFloat { min(sceneSize.width - Self.bubbleMargin * 2, (stageRange.upperBound - stageRange.lowerBound) + 80) }

    func offstageX(left: Bool) -> CGFloat {
        left ? -actorSide / 2 : sceneSize.width + actorSide / 2
    }

    func walkSeconds(fromLeft: Bool) -> Double {
        Double(abs(standX - offstageX(left: fromLeft)) / Self.walkSpeed)
    }

    /// El borde izquierdo del globo centrado sobre la cabeza, adentro de la pantalla.
    func bubbleLeft(width: CGFloat, tipX: CGFloat) -> CGFloat {
        min(max(tipX - width / 2, Self.bubbleMargin), sceneSize.width - Self.bubbleMargin - width)
    }
}
