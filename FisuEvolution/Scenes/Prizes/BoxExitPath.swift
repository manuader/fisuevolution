import CoreGraphics
import Foundation

/// La salida de un empleado de su caja (E14b B23), en coordenadas del campo: asoma desde adentro
/// tapado por el frente de la caja, se estira, salta en arco al costado, aterriza aplastándose y
/// camina a su lugar en la hilera. Es una cuenta pura para que los tests la midan sin `SKView`;
/// `BoardScene.walkOutOfTheBox` la convierte en acciones.
///
/// El frente tapa al empleado sin máscara: mientras sus pies están un poco más arriba que la línea
/// de la caja, la regla de profundidad (B19) lo dibuja detrás.
struct BoxExitPath: Equatable {
    static let riseSeconds: TimeInterval = 0.3
    static let jumpSeconds: TimeInterval = 0.38
    static let squashSeconds: TimeInterval = 0.18
    /// Lo que camina hasta su lugar, en pt/s, con un mínimo para que no llegue de golpe.
    static let walkSpeed: CGFloat = 150
    static let minWalkSeconds: TimeInterval = 0.25
    /// Cuánto más atrás que la línea de la caja arrancan sus pies: lo justo para ir detrás.
    static let behindBox: CGFloat = 1
    /// Hasta dónde suben los pies adentro de la caja, en fracción de su alto: el cuerpo asoma
    /// entero por arriba del borde y los pies siguen tapados.
    static let riseRatio: CGFloat = 0.5
    /// El alto con que arranca (escondido debajo del borde) y el estirón al salir.
    static let hiddenYScale: CGFloat = 0.35
    static let stretchYScale: CGFloat = 1.15
    static let stretchXScale: CGFloat = 0.9
    /// El aplaste al aterrizar.
    static let squashXScale: CGFloat = 1.2
    static let squashYScale: CGFloat = 0.8
    /// Lo que sube el arco sobre la recta del salto, en anchos de caja.
    static let jumpHeightRatio: CGFloat = 0.6
    /// Dónde aterriza: al costado de la caja, en anchos de caja desde su centro, y un poco
    /// delante de su línea.
    static let landingOffsetRatio: CGFloat = 0.95
    static let landingInFront: CGFloat = 2

    /// Con Reduce Motion: aparece al lado de la caja con un fundido y después en su lugar.
    static let fadeSeconds: TimeInterval = 0.3
    static let holdSeconds: TimeInterval = 0.35

    /// Los pies adentro de la caja, detrás de su frente.
    let start: CGPoint
    /// Los pies cuando terminó de asomar: listo para saltar.
    let peek: CGPoint
    /// Donde aterriza, al lado de la caja.
    let landing: CGPoint
    /// Su lugar en la hilera.
    let target: CGPoint
    let boxWidth: CGFloat

    /// `boxFeet`: la línea de profundidad de la caja; `rimY`: su borde de arriba; `boxWidth`: su
    /// ancho. Salta hacia el lado de su lugar.
    init(boxFeet: CGPoint, rimY: CGFloat, boxWidth: CGFloat, target: CGPoint) {
        start = CGPoint(x: boxFeet.x, y: boxFeet.y + Self.behindBox)
        peek = CGPoint(x: boxFeet.x, y: start.y + max(0, rimY - boxFeet.y) * Self.riseRatio)
        let side: CGFloat = target.x >= boxFeet.x ? 1 : -1
        landing = CGPoint(x: boxFeet.x + side * boxWidth * Self.landingOffsetRatio,
                          y: boxFeet.y - Self.landingInFront)
        self.target = target
        self.boxWidth = boxWidth
    }

    var jumpHeight: CGFloat { boxWidth * Self.jumpHeightRatio }

    var walkSeconds: TimeInterval {
        max(Self.minWalkSeconds, Double(hypot(target.x - landing.x, target.y - landing.y) / Self.walkSpeed))
    }

    /// Cuándo salta afuera: ahí la caja vacía empieza a irse.
    var jumpStart: TimeInterval { Self.riseSeconds }
    var landingTime: TimeInterval { Self.riseSeconds + Self.jumpSeconds }
    var totalSeconds: TimeInterval { landingTime + Self.squashSeconds + walkSeconds }

    /// La altura de los pies en la cima del arco: el medio de la recta del salto más `jumpHeight`.
    var apexY: CGFloat { (peek.y + landing.y) / 2 + jumpHeight }

    /// Los pies en el arco, con `progress` de 0 (asomado) a 1 (aterrizó): la x va pareja y la y sube
    /// frenando hasta la cima y baja acelerando, como la arman las acciones de la escena.
    func jumpPoint(at progress: CGFloat) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let x = peek.x + (landing.x - peek.x) * t
        if t <= 0.5 {
            let up = t / 0.5
            return CGPoint(x: x, y: peek.y + (apexY - peek.y) * (1 - (1 - up) * (1 - up)))
        }
        let down = (t - 0.5) / 0.5
        return CGPoint(x: x, y: apexY + (landing.y - apexY) * down * down)
    }
}
