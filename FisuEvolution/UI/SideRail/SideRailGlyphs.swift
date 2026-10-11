import SwiftUI

/// El glifo de cada acceso: el arte del atlas `ui` si E8 lo entregó, si no el
/// dibujo por código que ya usan los chips y la ruleta (E5b).
struct SideRailGlyph: View {
    let kind: SideRailKind

    var body: some View {
        switch kind {
        case .wheel: GameIcon(artKey: "wheel_icon", size: SideRailLayout.glyph) { WheelGlyph() }
        case .mattress: GameIcon(artKey: "pickup_mattress", size: SideRailLayout.glyph) { MattressGlyph() }
        case .packages: GameIcon(artKey: "pickup_package", size: SideRailLayout.glyph) { PackageGlyph() }
        case .boost: GameIcon(artKey: "siderail_boost", size: SideRailLayout.glyph) { MergeAllGlyph() }
        }
    }
}

/// "Fusionar todo" dibujado, mientras no llegue `siderail_boost` (E8).
struct MergeAllGlyph: View {
    var body: some View {
        Image(systemName: "arrow.triangle.merge")
            .resizable()
            .scaledToFit()
            .fontWeight(.black)
            .foregroundStyle(Color("PaletteInk"))
            .padding(3)
            .background(Circle().fill(Color("PaletteYellow")))
            .accessibilityHidden(true)
    }
}

extension SideRailKind {
    /// El ancla del tutorial de cada botón de la persiana.
    var tutorialTarget: TutorialTarget {
        switch self {
        case .wheel: .sideWheel
        case .mattress: .sideMattress
        case .packages: .sidePackages
        case .boost: .sideBoost
        }
    }
}
