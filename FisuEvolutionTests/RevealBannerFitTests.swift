import SpriteKit
import Testing
@testable import FisuEvolution

/// El reveal del ascenso muestra el nombre del personaje nuevo en un
/// `SKLabelNode` a 38 pt, centrado y a pantalla completa. Un `SKLabelNode` no
/// encoge ni envuelve solo, así que los nombres largos se salían de la pantalla:
/// "MAGNATE DEL SISTEMA SOLAR" son 25 caracteres, más de 600 pt de ancho en una
/// pantalla de 402.
///
/// Se testea acá y no con una captura porque el reveal dura ~2 s y aparece en el
/// tier 24 —a 23 merges del arranque—, mientras que este test cubre **todos** los
/// nombres del catálogo de una, incluidos los que no se pueden alcanzar a mano.
@Suite("Reveal: el nombre entra en pantalla")
@MainActor
struct RevealBannerFitTests {
    /// El ancho más angosto que soporta la app: iPhone SE / mini.
    private let narrowestScreen: CGFloat = 320
    private let revealFontSize: CGFloat = 38
    /// La entrada del banner lo agranda un 15% en su pico.
    private let peakScale: CGFloat = 1.15

    private func banner(_ text: String) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text.uppercased()
        label.fontSize = revealFontSize
        return label
    }

    @Test("ningún nombre del catálogo se sale de la pantalla")
    func everyCharacterNameFits() throws {
        let content = try GameContentLoader.load(from: .main)
        let maxWidth = (narrowestScreen - BoardScene.revealMargin * 2) / peakScale

        for type in content.tiers.concreteTypes {
            let label = banner(type.displayName)
            BoardScene.shrinkToFit(label, maxWidth: maxWidth)
            #expect(
                label.frame.width <= maxWidth + 0.5,
                "\(type.id) (\(type.displayName)) mide \(label.frame.width) y el tope es \(maxWidth)"
            )
            #expect(label.fontSize > 0, "\(type.id): la fuente no puede colapsar a 0")
        }
    }

    @Test("un nombre que ya entra no se toca")
    func shortNamesKeepTheirSize() {
        let label = banner("Fisura")
        let before = label.fontSize
        BoardScene.shrinkToFit(label, maxWidth: 1_000)
        #expect(label.fontSize == before, "achicar un texto que entra sería una regresión visual")
    }
}
