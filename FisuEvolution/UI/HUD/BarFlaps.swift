import SwiftUI

/// Los dos botones de la barra de abajo (C18, rediseño E14b B28 «Etiqueta y
/// billete»): Contratar a la izquierda, hecho etiqueta de precio, y Reencarnar a
/// la derecha, hecho billete de dólar blue. Se montan sobre el borde de arriba de
/// la barra: miden `GameTabBar.flapHeight` y se meten `flapOverlap` en el panel.
///
/// Se apilan sobre `BottomMenuBar` desde arriba (`overlay(alignment: .top)`): el
/// alto de la pila lo manda `GameTabBar.barHeight`, que ya cuenta lo que sobresalen.
///
/// Cada uno ocupa SU mitad: el ancho máximo (`BarFlapLayout`) es la mitad de la
/// barra menos el hueco del plato de Contratar y un margen, así que nunca entran
/// al plato, que va arriba de todo. En el SE se achican antes que pisarlo.
struct BarFlaps: View {
    /// Abre el selector del atajo (mantener presionado, o la acción de VoiceOver).
    let onChooseHire: () -> Void
    let onPrestige: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let layout = BarFlapLayout.make(barWidth: proxy.size.width)
            HStack(alignment: .bottom, spacing: 0) {
                QuickHireButton(onChoose: onChooseHire)
                    .frame(width: layout.left.width, alignment: .leading)
                    .tutorialAnchor(.quickHire)
                Spacer(minLength: 0)
                PrestigeButton(action: onPrestige)
                    .frame(width: layout.right.width, alignment: .trailing)
                    .tutorialAnchor(.prestige)
            }
            .padding(.horizontal, BarFlapLayout.sideMargin)
            .playColumn()
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// La geometría de las dos solapas contra el plato del medio, en una función
/// pura para poder probarla sin dibujar nada.
struct BarFlapLayout: Equatable {
    /// El marco de cada solapa y el hueco del plato, en coordenadas de la barra
    /// (x desde el borde izquierdo de la pantalla).
    let left: CGRect
    let right: CGRect
    let plate: CGRect

    /// Margen con el borde de la barra.
    static let sideMargin: CGFloat = Tokens.s8
    /// Aire que cada solapa le deja al plato.
    static let plateGap: CGFloat = 6

    /// - Parameter barWidth: el ancho de la pantalla; la columna de juego lo topa.
    ///   El hueco es el del botón de Contratar (`GameTabBar.centerButtonWidth`),
    ///   así que sirve para cualquier cantidad de pestañas.
    static func make(barWidth: CGFloat) -> BarFlapLayout {
        let plateSide = GameTabBar.centerButtonWidth
        let usable = min(barWidth, PlayColumn.maxWidth)
        let origin = (barWidth - usable) / 2
        let lane = max(0, (usable - plateSide) / 2 - plateGap - sideMargin)
        let height = GameTabBar.flapHeight
        return BarFlapLayout(
            left: CGRect(x: origin + sideMargin, y: 0, width: lane, height: height),
            right: CGRect(x: origin + usable - sideMargin - lane, y: 0, width: lane, height: height),
            plate: CGRect(x: origin + (usable - plateSide) / 2, y: 0, width: plateSide, height: height)
        )
    }
}

/// El triángulo del "hay más": mantener presionado abre el selector. Dibujado, no
/// un SF Symbol.
struct FlapChevron: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 7))
            path.addLine(to: CGPoint(x: 4.5, y: 0))
            path.addLine(to: CGPoint(x: 9, y: 7))
            path.closeSubpath()
        }
        .fill(Color("PaletteBrown"))
        .frame(width: 9, height: 7)
        .accessibilityHidden(true)
    }
}
