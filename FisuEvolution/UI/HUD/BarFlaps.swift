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
/// barra menos el hueco del plato de Contratar y un margen, y se achica si el plato
/// —que no siempre cae al medio— le come lugar. Nunca entran al plato, que va
/// arriba de todo. En el SE se achican antes que pisarlo.
struct BarFlaps: View {
    /// Abre el selector del atajo (mantener presionado, o la acción de VoiceOver).
    let onChooseHire: () -> Void
    let onPrestige: () -> Void

    /// Las pestañas abiertas mandan dónde cae el plato (ver `BarFlapLayout`).
    @Environment(GameState.self) private var gameState

    var body: some View {
        GeometryReader { proxy in
            let layout = BarFlapLayout.make(
                barWidth: proxy.size.width,
                tabs: gameState.unlockedTabsInBarOrder.map { $0 == GameScreen.centerTab }
            )
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
@MainActor
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

    /// - Parameters:
    ///   - barWidth: el ancho de la pantalla; la columna de juego lo topa.
    ///   - tabs: las pestañas de la barra en orden, `true` en Contratar. El plato
    ///     cae donde lo pone `GameTabBar` y no siempre al medio: con las seis de
    ///     `barOrder` hay tres pestañas a la izquierda y dos a la derecha, y el
    ///     plato queda corrido a la derecha. Cada solapa tiene, como mucho, su
    ///     mitad de una barra simétrica, y se achica si el plato le come lugar.
    ///     Vacío (o sin Contratar): el plato al medio.
    static func make(barWidth: CGFloat, tabs: [Bool] = []) -> BarFlapLayout {
        let plateSide = GameTabBar.centerButtonWidth
        let usable = min(barWidth, PlayColumn.maxWidth)
        let origin = (barWidth - usable) / 2
        let plateX = (GameTabBar.prominentCenterX(prominent: tabs, barWidth: barWidth) ?? barWidth / 2)
            - plateSide / 2
        let leftEdge = origin + sideMargin
        let rightEdge = origin + usable - sideMargin
        let half = max(0, (usable - plateSide) / 2 - plateGap - sideMargin)
        let leftLane = min(half, max(0, plateX - plateGap - leftEdge))
        let rightLane = min(half, max(0, rightEdge - (plateX + plateSide + plateGap)))
        let height = GameTabBar.flapHeight
        return BarFlapLayout(
            left: CGRect(x: leftEdge, y: 0, width: leftLane, height: height),
            right: CGRect(x: rightEdge - rightLane, y: 0, width: rightLane, height: height),
            plate: CGRect(x: plateX, y: 0, width: plateSide, height: height)
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
