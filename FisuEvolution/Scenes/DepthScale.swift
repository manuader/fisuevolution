import CoreGraphics

/// El tamaño según la distancia (E14b B30, D13; EXPERIMENTO en una rama aparte): lo que está más
/// atrás se ve un poco más chico, y lo de adelante, un poco más grande. Es el hermano de
/// `DepthOrder`: la misma y de los pies, pero en vez de un z devuelve una escala.
///
/// Un solo punto de verdad. Empleados, visitantes, cajas y colchón piden su escala acá. **Para
/// apagarlo, `isEnabled = false`**: todo devuelve 1,0 y el escenario queda como antes.
///
/// Sólo achica lo que se VE. El área de toque nunca baja de `minTouchSide`.
enum DepthScale {
    /// El interruptor del experimento. Apagado, `scale` es 1,0 en todos lados.
    static let isEnabled = true
    /// La escala de unos pies parados en el horizonte (lo más atrás).
    static let backScale: CGFloat = 0.85
    /// La escala de unos pies parados en el frente (lo más adelante).
    static let frontScale: CGFloat = 1.0
    /// El área de toque nunca baja de esto, en puntos (HIG).
    static let minTouchSide: CGFloat = 44

    /// El tramo de profundidad de un piso, en la y de la pantalla: de la línea de atrás (los pies en
    /// el horizonte) a la de adelante (arriba de la barra).
    struct Span: Equatable {
        let backY: CGFloat
        let frontY: CGFloat
    }

    /// La escala de algo con los pies en `feetY`: `backScale` en `span.backY`, `frontScale` en
    /// `span.frontY`, con un smoothstep entre los dos (sin saltos mientras deambulan) y quieta
    /// fuera del tramo.
    static func scale(forFeetY feetY: CGFloat, in span: Span) -> CGFloat {
        guard isEnabled else { return 1 }
        let length = span.backY - span.frontY
        guard length > 0, feetY.isFinite else { return frontScale }
        // 0 al frente, 1 en el horizonte.
        let t = min(1, max(0, (feetY - span.frontY) / length))
        let eased = t * t * (3 - 2 * t)
        return frontScale + (backScale - frontScale) * eased
    }

    /// `rect` con al menos `minTouchSide` de ancho y de alto, crecido alrededor de su centro.
    static func enforcingMinimumTouch(_ rect: CGRect) -> CGRect {
        let missingWidth = max(0, minTouchSide - rect.width)
        let missingHeight = max(0, minTouchSide - rect.height)
        return rect.insetBy(dx: -missingWidth / 2, dy: -missingHeight / 2)
    }
}

extension StageLayout {
    /// El tramo de `DepthScale` de un piso con ese fondo: de la línea del suelo (el horizonte, donde
    /// apoya la fila de atrás) al frente de la pantalla (`groundFloorY`).
    func depthSpan(background: String?, backgroundOffset: Double = 0) -> DepthScale.Span {
        DepthScale.Span(backY: groundY(background: background, backgroundOffset: backgroundOffset),
                        frontY: groundFloorY)
    }
}
