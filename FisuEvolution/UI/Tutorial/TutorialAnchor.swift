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
    // Los destinos de las lecciones contextuales: los cuatro tabs restantes y
    // los dos botones flotantes de la franja de abajo. La fase obligatoria no
    // los usa; los señalan las lecciones (`TutorialOverlay`).
    case skins
    case gifts
    case store
    /// La mitad "Gastar ORO" de la tienda (E6): la lección de la tienda de ORO (E9).
    case oroShop
    /// El chip de la oferta abierta (E6): la lección de las ofertas (E9).
    case offerChip
    case menu
    case quickHire
    case prestige
    /// El chip de quien está en escena (`StageChips`).
    case visitor
    /// El chip de un evento corriendo, en la barra de bonus.
    case eventChip
    /// El botón de compartir un momento viral.
    case share
    /// Los accesos de E5 (los nombres son los de la columna lateral de E9/E7b:
    /// el ancla viaja con el botón cuando se mude).
    case sidePackages
    case sideMattress
    /// La columna plegable (E7b): el botón "Premios" en reposo y los otros dos
    /// botones de su persiana.
    case sideRail
    case sideWheel
    case sideBoost
    /// La fila de FisuJobs que el atajo contrataría hoy (la recomendada): el paso de adentro
    /// del núcleo la ilumina desde el coach de la hoja.
    case jobsRecommended
    /// La cara del selector del atajo (la fijada, o la primera). El selector vive en la raíz,
    /// fuera de la hoja.
    case pickerFace
    /// Los puntos del paginador del menú: lo que señala un "deslizá".
    case menuPager
    /// El precio del primer pasivo pagable de Mejoras.
    case upgradesPassive
    /// El precio del primer multiplicador pagable de Mejoras.
    case upgradesRow
    /// La tarjeta del Organigrama en el Menú.
    case menuOrgChart
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
    ///
    /// `when` es para el control que sólo a veces es el destino (la fila recomendada): publicar
    /// condicionalmente, y no armar la vista con un `if`, conserva la identidad y el estado de
    /// la vista cuando la condición cambia.
    func tutorialAnchor(_ target: TutorialTarget, when condition: Bool = true) -> some View {
        transformAnchorPreference(key: TutorialAnchorKey.self, value: .bounds) { value, anchor in
            if condition { value[target] = anchor }
        }
    }
}
