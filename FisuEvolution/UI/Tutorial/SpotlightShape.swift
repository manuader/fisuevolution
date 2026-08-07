import SwiftUI

/// La pantalla entera MENOS uno o más agujeros: el recorte iluminado del
/// tutorial (patrón Clash of Clans).
///
/// Se dibuja con `FillStyle(eoFill: true)`: cada sub-path que cae dentro del
/// rectángulo exterior invierte el relleno y queda transparente. La MISMA forma
/// se usa de `contentShape`, así que lo que no se pinta tampoco recibe el toque
/// — y eso es lo que hace que un paso no se pueda saltear sin ejecutar su
/// acción.
///
/// `primary` es el único agujero animable (`CGRect` ya conforma `Animatable`):
/// es el que se mueve de un control a otro entre pasos. Los `extras` son
/// ventanas de sólo-lectura sobre el HUD —el contador de monedas, por ejemplo—
/// que no se mueven y no necesitan interpolarse.
struct SpotlightShape: Shape {
    /// Agujero principal, en coordenadas de la propia vista. `.null` = sin
    /// recorte (paso final: el scrim va entero).
    var primary: CGRect
    var primaryCornerRadius: CGFloat = 28
    var extras: [CGRect] = []
    var extraCornerRadius: CGFloat = 22

    var animatableData: CGRect.AnimatableData {
        get { primary.animatableData }
        set { primary.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        add(primary, radius: primaryCornerRadius, to: &path)
        for hole in extras {
            add(hole, radius: extraCornerRadius, to: &path)
        }
        return path
    }

    private func add(_ hole: CGRect, radius: CGFloat, to path: inout Path) {
        guard Self.isDrawable(hole) else { return }
        // El radio no puede pasar la mitad del lado menor: más que eso deforma
        // la esquina y en un agujero angosto (la cápsula del mapa) la cierra.
        let clamped = min(radius, min(hole.width, hole.height) / 2)
        path.addPath(Path(roundedRect: hole, cornerRadius: clamped, style: .continuous))
    }

    /// Un rect vacío, infinito o con NaN dibuja un sub-path degenerado que, con
    /// `evenOdd`, invierte TODO el scrim y deja la pantalla sin oscurecer.
    static func isDrawable(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isEmpty && !rect.isInfinite
            && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
    }
}
