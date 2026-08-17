import SpriteKit
import Testing
@testable import FisuEvolution

/// El reveal del personaje nuevo va **centrado en la pantalla entera**.
///
/// Puede ocupar el medio porque durante la celebración el resto de la UI se va a
/// opacidad 0. Antes tenía que meterse en la franja libre entre el HUD y la barra
/// de abajo, y ahí estaba el bug reportado: medido en iPhone 16 Pro, el `¡NUEVO!`
/// caía a 157 pt del borde superior y la pill de piso —cápsula crema OPACA—
/// termina en ~162, así que lo tapaba entero. El `SpriteView` está en el fondo
/// del `ZStack`, de modo que todo lo de SpriteKit queda debajo de todo lo de
/// SwiftUI, siempre.
///
/// Se testea acá y no con una captura porque el veredicto es numérico y cubre
/// todos los tamaños de pantalla de una: el reveal aparece recién al evolucionar,
/// así que verificarlo a mano en cada una no es realista.
@Suite("El reveal va centrado en la pantalla")
@MainActor
struct RevealLayoutTests {
    /// De la más chica que soporta la app a la más grande.
    private let screens: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 375, height: 667),
        CGSize(width: 390, height: 844),
        CGSize(width: 402, height: 874),
        CGSize(width: 430, height: 932),
        CGSize(width: 440, height: 956),
    ]

    /// Alto del bloque de texto que `revealLayout` reserva sobre la foto.
    private let textBlock: CGFloat = 96

    @Test("el bloque queda centrado verticalmente")
    func blockIsVerticallyCentered() {
        for screen in screens {
            let layout = BoardScene.revealLayout(size: screen)
            let bottom = layout.photoY - layout.photoSide / 2
            let top = bottom + layout.photoSide + textBlock
            let center = (bottom + top) / 2
            #expect(
                abs(center - screen.height / 2) < 0.5,
                "en \(screen.width)×\(screen.height) el bloque quedó centrado en \(center) y la pantalla en \(screen.height / 2)"
            )
        }
    }

    @Test("no se sale de la pantalla por ningún borde")
    func blockFitsOnScreen() {
        for screen in screens {
            let layout = BoardScene.revealLayout(size: screen)
            #expect(layout.photoY - layout.photoSide / 2 >= 0, "la foto se sale por abajo")
            #expect(layout.tagY <= screen.height, "el «¡NUEVO!» se sale por arriba")
            #expect(layout.photoSide <= screen.width * 0.82 + 0.001, "la foto se pasa del ancho")
        }
    }

    /// El orden de lectura: la etiqueta arriba, el nombre abajo, la foto al pie.
    @Test("el bloque se lee de arriba abajo sin solaparse")
    func blockReadsTopToBottom() {
        for screen in screens {
            let layout = BoardScene.revealLayout(size: screen)
            #expect(layout.tagY > layout.bannerY, "«¡NUEVO!» va sobre el nombre")
            #expect(
                layout.bannerY > layout.photoY + layout.photoSide / 2 - 1,
                "y el nombre sobre la foto, no encima de ella"
            )
        }
    }

    /// En una pantalla corta la foto tiene que ceder: `0.52 × alto` más el bloque
    /// de texto no entra, y el texto no puede quedar fuera de la pantalla.
    @Test("en pantallas cortas la foto cede el lugar al texto")
    func photoShrinksOnShortScreens() {
        let short = CGSize(width: 320, height: 568)
        let tall = CGSize(width: 440, height: 956)
        #expect(BoardScene.revealLayout(size: short).photoSide < BoardScene.revealLayout(size: tall).photoSide)
        #expect(BoardScene.revealLayout(size: short).photoSide >= 120, "pero sigue siendo reconocible")
    }
}
