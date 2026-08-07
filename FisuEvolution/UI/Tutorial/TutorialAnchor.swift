import SwiftUI

/// Los controles que el tutorial puede iluminar.
///
/// `boardUnit` es el único que NO es una vista SwiftUI: su recorte lo publica
/// `BoardScene` en `GameState.boardSpotlight`, porque después del deambular la
/// única que sabe dónde quedó parado el personaje es la escena.
enum TutorialTarget: String, Hashable, CaseIterable {
    case boardUnit
    case hire
    case upgrades
    case map
    case coins
    /// No se ilumina: es la franja que el globo tiene que ESQUIVAR. Sin esto el
    /// globo se apoyaba encima del HUD y lo tapaba entero — y como el HUD es
    /// justamente lo que los pasos siguientes iluminan, el tutorial terminaba
    /// escondiendo lo que quería enseñar.
    case hudBar
    /// Ídem, para la franja de abajo (reencarnar + contratar).
    case bottomBar
}

/// Recolecta el frame REAL de cada control candidato.
///
/// Se usa `Anchor<CGRect>` y no un frame en `.global` a propósito: el anchor lo
/// resuelve el `GeometryProxy` que lo consume, así que el recorte cae bien sin
/// que nadie tenga que restar insets de safe area a mano.
struct TutorialAnchorKey: PreferenceKey {
    typealias Value = [TutorialTarget: Anchor<CGRect>]
    static var defaultValue: Value { [:] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Publica el frame de este control para el tutorial.
    ///
    /// ⚠️ Es la ÚNICA forma admitida de decirle al tutorial dónde está un
    /// control. Con coordenadas escritas a mano, mover un botón —cosa que ya
    /// pasó con el menú de mejoras, el botón de mapa y el indicador de
    /// prestigio— deja el recorte apuntando al vacío y nadie se entera.
    ///
    /// ⚠️ Es `transformAnchorPreference` y **no** `anchorPreference`: el segundo
    /// PISA el valor que trae el subárbol en vez de sumarse a él. Con
    /// `anchorPreference`, marcar la franja del HUD borraba de un saque los
    /// anclas del contador de monedas, de mejoras y del mapa —que viven adentro—
    /// y el recorte quedaba en la nada sin que nada fallara a la vista: el
    /// tutorial dibujaba el scrim entero y el paso no se podía completar.
    func tutorialAnchor(_ target: TutorialTarget) -> some View {
        transformAnchorPreference(key: TutorialAnchorKey.self, value: .bounds) { value, anchor in
            value[target] = anchor
        }
    }
}
