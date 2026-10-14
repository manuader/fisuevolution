import CoreGraphics

/// La geometría del escenario (PLAN-v2 E4, E14 C2, E14b B3): x ∈ [28 %, 72 %] del ancho,
/// para no quedar bajo los botones flotantes de los costados, y parado en el horizonte
/// del fondo de su piso: donde el fondo corta con el suelo, lejos de la barra de
/// abajo. Coordenadas de la capa de la cámara (origen abajo a la izquierda, del
/// tamaño de la escena).
///
/// El horizonte de cada escenario es UN dato (`horizons`) y de él sale todo lo que se
/// apoya en el suelo: los pies del visitante (`standY`), la caja y el colchón
/// (`PickupLayout`) y el techo de las hileras (`BoardScene.crowdBand`).
struct StageLayout: Equatable {
    static let leftEdge: CGFloat = 0.28
    static let rightEdge: CGFloat = 0.72
    /// Lo que camina un visitante, en pt/s.
    static let walkSpeed: CGFloat = 90
    /// El lado del arte de un empleado, en celdas: el plato de `CharacterNode` (0,92) por su
    /// `realArtScale` (2,2). Es un espejo a mano; `StageLayoutTests` lo pinea contra el nodo.
    static let employeeSideRatio: CGFloat = 0.92 * 2.2
    /// Cuánto del lienzo del PNG ocupa el CUERPO dibujado (alto del alfa > 40 sobre el alto del
    /// archivo), promediado sobre los 43 empleados `_idle` y los 9 visitantes de `npcs.atlas`.
    /// El lienzo trae márgenes distintos en cada uno: escalar por lienzo no iguala figuras.
    static let employeeCanvasBodyRatio: CGFloat = 0.894
    static let visitorCanvasBodyRatio: CGFloat = 0.874
    /// Qué alto de cuerpo tiene un visitante frente a un empleado parado en la misma hilera.
    /// Es la ÚNICA constante de escala de los visitantes. Con 0,82 el lado sale 1,70 celdas
    /// contra las 1,35 de antes: +26 % (el dueño pidió entre +20 % y +30 %, D10).
    static let visitorHeightRatio: CGFloat = 0.82
    static let actorScale: CGFloat = employeeSideRatio * employeeCanvasBodyRatio / visitorCanvasBodyRatio * visitorHeightRatio
    static let bubbleMargin: CGFloat = 12
    /// Cuánto agranda `FloorNode` el fondo para llenar la pantalla.
    static let backgroundOverscan: CGFloat = 1.18
    /// El horizonte de cada fondo: dónde corta con el suelo, como fracción de la altura de
    /// la foto contada desde abajo. Calibrado a ojo mirando las diez fotos. El fondo apoya su
    /// borde de abajo en `floorBase` (arriba de la barra, B3), así que la línea cae
    /// `floorBase + fracción × alto de la foto` sobre el borde de abajo de la pantalla.
    static let horizons: [String: CGFloat] = [
        "alley": 0.38, "urban": 0.40, "corporate": 0.42, "luxury": 0.44, "island": 0.39,
        "moon": 0.50, "mars": 0.50, "solar": 0.36, "galaxy": 0.48, "god_realm": 0.46,
    ]
    static let defaultHorizon: CGFloat = 0.42
    /// Los pies, un poco debajo de la línea, para que pise suelo y no cuelgue del fondo.
    static let footDrop: CGFloat = 0.1
    /// La cabeza del visitante nunca pasa de esta fracción del alto: más arriba queda bajo el HUD.
    static let maxHeadRatio: CGFloat = 0.85

    let sceneSize: CGSize
    let bottomInset: CGFloat
    let cellSize: CGFloat
    /// Dónde apoya su borde de abajo el fondo del piso: el borde de arriba de la barra. Sin
    /// él (los tests puros) es `bottomInset`.
    var floorBottom: CGFloat?

    var floorBase: CGFloat { floorBottom ?? bottomInset }

    var actorSide: CGFloat { cellSize * Self.actorScale }
    /// La línea de abajo, la de antes del horizonte: la siguen los paquetes y el colchón del
    /// tablero (`PickupLayout`) hasta que E14 T16 los suba. Un visitante ya no la pisa: `standY`.
    var baselineY: CGFloat { bottomInset + cellSize * 0.25 }
    var stageRange: ClosedRange<CGFloat> { sceneSize.width * Self.leftEdge...sceneSize.width * Self.rightEdge }
    var standX: CGFloat { (stageRange.lowerBound + stageRange.upperBound) / 2 }
    var bubbleMaxWidth: CGFloat { min(sceneSize.width - Self.bubbleMargin * 2, (stageRange.upperBound - stageRange.lowerBound) + 80) }

    /// El alto de la foto ya agrandada para llenar la pantalla (las diez son cuadradas).
    static func spriteHeight(sceneSize: CGSize) -> CGFloat {
        max(sceneSize.width, sceneSize.height) * backgroundOverscan
    }

    /// Cuánto se baja el fondo (`backgroundOffset`, fracción del alto de la escena), con el tope
    /// del sobrante: el borde de arriba de la foto nunca se despega del techo. Lo usan
    /// `FloorNode`, que dibuja el fondo, y `horizonY`, que lo mide: la misma cuenta.
    static func backgroundLift(offset: Double, sceneSize: CGSize, floorBase: CGFloat) -> CGFloat {
        let slack = max(0, spriteHeight(sceneSize: sceneSize) - (sceneSize.height - floorBase))
        return min(CGFloat(offset) * sceneSize.height, slack)
    }

    static func horizon(of background: String?) -> CGFloat {
        background.flatMap { horizons[$0] } ?? defaultHorizon
    }

    /// La línea del horizonte de un fondo, en la escena: donde corta con el suelo.
    func horizonY(background: String?, backgroundOffset: Double = 0) -> CGFloat {
        let lift = Self.backgroundLift(offset: backgroundOffset, sceneSize: sceneSize, floorBase: floorBase)
        return floorBase - lift + Self.horizon(of: background) * Self.spriteHeight(sceneSize: sceneSize)
    }

    /// Dónde apoya los pies en un piso con ese fondo: el horizonte, con los pies un poco abajo.
    /// Nunca baja de la barra ni sube hasta que la cabeza quede bajo el HUD.
    func standY(background: String?, backgroundOffset: Double = 0) -> CGFloat {
        let feet = horizonY(background: background, backgroundOffset: backgroundOffset) - actorSide * Self.footDrop
        let ceiling = sceneSize.height * Self.maxHeadRatio - actorSide - 1
        return max(bottomInset + cellSize, min(feet, ceiling))
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
