import SwiftUI

/// Las dos solapas de la barra de abajo (C18): Contratar a la izquierda y
/// Reencarnar a la derecha, montadas sobre el borde de arriba de la barra. No son
/// una franja aparte: miden `GameTabBar.flapHeight`, se meten `flapOverlap` en el
/// panel y comparten su material, así que se leen como la barra que crece en esos
/// dos lugares.
///
/// Se apilan sobre `BottomMenuBar` desde arriba (`overlay(alignment: .top)`): el
/// alto de la pila lo manda `GameTabBar.barHeight`, que ya cuenta lo que sobresalen.
///
/// El hueco del medio es el plato de Contratar, que sobresale entre las dos: las
/// solapas se achican antes que pisarlo.
struct BarFlaps: View {
    /// Abre el selector del atajo (mantener presionado, o la acción de VoiceOver).
    let onChooseHire: () -> Void
    let onPrestige: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: Tokens.s8) {
            QuickHireButton(onChoose: onChooseHire)
                .tutorialAnchor(.quickHire)
            Spacer(minLength: GameTabBar.centerPlateSide + Tokens.s8)
            PrestigeButton(action: onPrestige)
                .tutorialAnchor(.prestige)
        }
        .padding(.horizontal, Tokens.s8)
        .playColumn()
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// La forma de una solapa: esquinas redondas arriba y recta abajo, donde se funde
/// con el panel de la barra.
struct BarFlapShape: InsettableShape {
    var inset: CGFloat = 0
    static let radius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: Self.radius, topTrailingRadius: Self.radius, style: .continuous
        ).path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> BarFlapShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

/// El contorno ink de 3 pt de la solapa: sólo los tres lados que dan al tablero.
/// Abajo no hay línea —sería una raya adentro del panel—.
private struct BarFlapOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let line: CGFloat = 1.5
        let box = rect.insetBy(dx: line, dy: line)
        let r = BarFlapShape.radius
        var path = Path()
        path.move(to: CGPoint(x: box.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: box.minX, y: box.minY + r))
        path.addQuadCurve(to: CGPoint(x: box.minX + r, y: box.minY),
                          control: CGPoint(x: box.minX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - r, y: box.minY))
        path.addQuadCurve(to: CGPoint(x: box.maxX, y: box.minY + r),
                          control: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: rect.maxY))
        return path
    }
}

extension View {
    /// El material de una solapa: crema con el contorno de la barra y un tinte
    /// suave según lo que hace. El contenido queda centrado en la parte que se ve
    /// (arriba de lo que se mete en el panel).
    func barFlapSurface(tint: Color?) -> some View {
        padding(.horizontal, Tokens.s8)
            .padding(.top, 3)
            .padding(.bottom, GameTabBar.flapOverlap)
            .frame(height: GameTabBar.flapHeight)
            .background {
                BarFlapShape().fill(Color("PaletteCream"))
                if let tint {
                    BarFlapShape().fill(tint.opacity(0.24))
                }
            }
            .overlay(BarFlapOutline().stroke(Color("PaletteInk"), style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
            .contentShape(BarFlapShape())
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
