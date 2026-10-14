import CoreGraphics

/// La geometría del escenario (PLAN-v2 E4, E14 C2): x ∈ [28 %, 72 %] del ancho, para
/// no quedar bajo los botones flotantes de los costados, y parado en el horizonte
/// del fondo de su piso: donde el fondo corta con el suelo, lejos de la barra de
/// abajo. Coordenadas de la capa de la cámara (origen abajo a la izquierda, del
/// tamaño de la escena).
struct StageLayout: Equatable {
    static let leftEdge: CGFloat = 0.28
    static let rightEdge: CGFloat = 0.72
    /// Lo que camina un visitante, en pt/s.
    static let walkSpeed: CGFloat = 90
    /// Un visitante es algo más alto que un empleado: viene de afuera.
    static let actorScale: CGFloat = 1.35
    static let bubbleMargin: CGFloat = 12
    /// Cuánto agranda `FloorNode` el fondo para llenar la pantalla.
    static let backgroundOverscan: CGFloat = 1.18
    /// El horizonte de cada fondo: dónde corta con el suelo, como fracción de la altura de
    /// la foto contada desde abajo. Calibrado a ojo mirando las diez fotos.
    static let horizons: [String: CGFloat] = [
        "alley": 0.38, "urban": 0.40, "corporate": 0.42, "luxury": 0.44, "island": 0.39,
        "moon": 0.50, "mars": 0.50, "solar": 0.36, "galaxy": 0.48, "god_realm": 0.46,
    ]
    static let defaultHorizon: CGFloat = 0.42
    /// Los pies, un poco debajo de la línea, para que pise suelo y no cuelgue del fondo.
    static let footDrop: CGFloat = 0.1

    let sceneSize: CGSize
    let bottomInset: CGFloat
    let cellSize: CGFloat

    var actorSide: CGFloat { cellSize * Self.actorScale }
    /// La línea de abajo, la de antes del horizonte: la siguen los paquetes y el colchón del
    /// tablero (`PickupLayout`) hasta que E14 T16 los suba. Un visitante ya no la pisa: `standY`.
    var baselineY: CGFloat { bottomInset + cellSize * 0.25 }
    var stageRange: ClosedRange<CGFloat> { sceneSize.width * Self.leftEdge...sceneSize.width * Self.rightEdge }
    var standX: CGFloat { (stageRange.lowerBound + stageRange.upperBound) / 2 }
    var bubbleMaxWidth: CGFloat { min(sceneSize.width - Self.bubbleMargin * 2, (stageRange.upperBound - stageRange.lowerBound) + 80) }

    /// Dónde apoya los pies en un piso con ese fondo (y el desplazamiento del fondo
    /// que `FloorNode` aplica: una fracción de la altura de la escena).
    func standY(background: String?, backgroundOffset: Double = 0) -> CGFloat {
        let fraction = background.flatMap { Self.horizons[$0] } ?? Self.defaultHorizon
        let spriteHeight = max(sceneSize.width, sceneSize.height) * Self.backgroundOverscan
        let slack = max(0, spriteHeight - sceneSize.height)
        let lift = min(CGFloat(backgroundOffset) * sceneSize.height, slack)
        return max(bottomInset + cellSize, fraction * spriteHeight - lift - actorSide * Self.footDrop)
    }

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
