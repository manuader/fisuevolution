import SwiftUI

/// El sello de cada acceso: el arte `ui_rail_*` del atlas `ui` si está
/// integrado; si no, el dibujo por código que ya usan los chips y la ruleta.
struct SideRailGlyph: View {
    let kind: SideRailKind

    var body: some View {
        switch kind {
        case .wheel: GameIcon(artKey: "ui_rail_wheel", size: SideRailLayout.seal) { WheelGlyph() }
        case .mattress: GameIcon(artKey: "ui_rail_mattress", size: SideRailLayout.seal) { MattressGlyph() }
        case .packages: GameIcon(artKey: "ui_rail_package", size: SideRailLayout.seal) { PackageGlyph() }
        case .boost: GameIcon(artKey: "ui_rail_merge_all", size: SideRailLayout.seal) { MergeAllGlyph() }
        }
    }
}

/// "Fusionar todo" dibujado, mientras no llegue `ui_rail_merge_all`: dos
/// flechas que confluyen en una.
struct MergeAllGlyph: View {
    var body: some View {
        MergeArrows()
            .stroke(Color("PaletteInk"), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            .padding(14)
            .background(Circle().fill(Color("PaletteYellow")))
            .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
            .accessibilityHidden(true)
    }
}

private struct MergeArrows: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: midX, y: rect.midY), control: CGPoint(x: rect.minX, y: rect.midY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: midX, y: rect.midY), control: CGPoint(x: rect.maxX, y: rect.midY))
        path.move(to: CGPoint(x: midX, y: rect.midY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        path.move(to: CGPoint(x: midX - rect.width * 0.2, y: rect.maxY - rect.height * 0.22))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.2, y: rect.maxY - rect.height * 0.22))
        return path
    }
}

extension SideRailKind {
    /// El ancla del tutorial de cada sello.
    var tutorialTarget: TutorialTarget {
        switch self {
        case .wheel: .sideWheel
        case .mattress: .sideMattress
        case .packages: .sidePackages
        case .boost: .sideBoost
        }
    }
}
