import SwiftUI

/// La columna del chrome en pantallas anchas (PLAN-v2 E3): el HUD, la barra de
/// pestañas, la fila del atajo y la barra de bonus no pasan de 592 pt y van
/// centrados; los fondos de los paneles siguen a sangre, así que en iPad no
/// queda ninguna barra. En iPhone la columna es más ancha que la pantalla y no
/// cambia nada.
enum PlayColumn {
    static let maxWidth: CGFloat = 592
    /// Las tarjetas del tutorial, que flotan solas y se leen mejor angostas.
    static let tutorialCardMaxWidth: CGFloat = 520
}

extension View {
    /// El contenido en la columna, centrado. El fondo que se le ponga DESPUÉS
    /// ocupa el ancho entero.
    func playColumn() -> some View {
        frame(maxWidth: PlayColumn.maxWidth)
            .frame(maxWidth: .infinity)
    }
}
