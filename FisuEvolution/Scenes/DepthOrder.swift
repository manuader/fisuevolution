import CoreGraphics

/// La única regla de profundidad del escenario (E14b B19, D13): todo lo que está parado en el
/// piso —empleados, visitantes, cajas, el colchón y lo que se sume— se ordena por la y de sus
/// pies. **Más abajo en la pantalla, más adelante.**
///
/// La y es la de la pantalla del piso al que pertenece la pieza: 0 en el borde de abajo, con la
/// cámara quieta en ese piso. Cada capa la convierte desde sus coordenadas (el campo suma
/// `BoardScene.bottomInset`; la capa de la cámara resta el corrimiento del piso) y el z que sale
/// es el de la ESCENA: el que dibuja SpriteKit con `ignoresSiblingOrder` y el que compara el toque.
///
/// La banda entera (pies entre el borde de abajo y `deepestFeetY`) queda entre los fondos de los
/// pisos (`FloorNode.backgroundZ`, ≤ 0,1) y lo que va siempre arriba: el arrastrado
/// (`BoardScene.fieldBaseZ` + 50), los anillos, las partículas, las etiquetas y las celebraciones.
/// `DepthOrderTests` lo pinea.
enum DepthOrder {
    /// El z de unos pies apoyados en el borde de abajo de la pantalla: lo más adelante posible.
    static let frontZ: CGFloat = 30
    /// Cuánto se va hacia atrás por cada punto que suben los pies. Es la escala que la multitud
    /// usaba desde F7 (`depthZ`): un realce de candidato (`BoardScene.candidateZLift`) le sigue
    /// ganando a toda la franja.
    static let zPerPoint: CGFloat = 0.01
    /// Los pies más altos que la regla tiene que poder ordenar: la pantalla más alta que soporta
    /// la app (un iPad de 1376) con aire. Por encima de esto el z seguiría bajando hacia los fondos.
    static let deepestFeetY: CGFloat = 1600
    /// Dentro de una pila de cajas, cuánto más adelante va cada una sobre la de abajo: menos que un
    /// punto de profundidad, así que la pila entera se ordena como una sola pieza contra el resto.
    static let stackStep: CGFloat = 0.002
    /// Lo que le suma una pieza a sus propias capas internas (el video sobre el arte quieto, la
    /// apertura sobre la espera): tiene que ser mucho menor que `stackStep`, o el video de una caja
    /// se dibujaría encima de alguien parado delante.
    static let innerStep: CGFloat = 0.0003

    /// El z de la escena para algo cuyos pies están en `feetY`.
    static func z(forFeetY feetY: CGFloat) -> CGFloat {
        frontZ - feetY * zPerPoint
    }
}
