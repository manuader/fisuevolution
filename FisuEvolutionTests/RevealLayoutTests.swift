import SpriteKit
import Testing
@testable import FisuEvolution

/// El reveal del personaje nuevo se dibuja **dentro de SpriteKit**, y el
/// `SpriteView` está en el fondo del `ZStack` de `GameBoardView`: todo lo de
/// SpriteKit queda debajo de todo lo de SwiftUI, siempre.
///
/// Por eso el texto tenía que salir de la banda del HUD y no alcanzaba con
/// atenuarlo. Medido en iPhone 16 Pro cuando se reportó: el `¡NUEVO!` caía a 157
/// pt del borde superior y la pill de piso —cápsula crema OPACA— termina en
/// ~162, así que lo tapaba entero.
///
/// Se testea acá y no con una captura porque el veredicto es numérico y cubre
/// todos los tamaños de pantalla de una. El reveal aparece recién al evolucionar,
/// así que verificarlo a mano en cada pantalla no es realista.
@Suite("El reveal no se mete debajo del HUD")
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

    @Test("todo el bloque del reveal queda por debajo de la banda del HUD")
    func revealStaysBelowTheHUD() {
        for screen in screens {
            let layout = BoardScene.revealLayout(size: screen)
            let ceiling = screen.height - BoardScene.topInset
            #expect(
                layout.tagY <= ceiling,
                "en \(screen.width)×\(screen.height) el «¡NUEVO!» quedó en \(layout.tagY) y el techo libre es \(ceiling)"
            )
            #expect(layout.bannerY <= ceiling, "el nombre del personaje también")
            #expect(
                layout.photoY + layout.photoSide / 2 <= ceiling,
                "y la foto, que es lo más alto del bloque"
            )
        }
    }

    /// La barra de abajo (contratar, tabs) es igual de opaca que el HUD.
    @Test("y por encima de la barra de abajo")
    func revealStaysAboveTheBottomBar() {
        for screen in screens {
            let layout = BoardScene.revealLayout(size: screen)
            #expect(
                layout.photoY - layout.photoSide / 2 >= BoardScene.bottomInset - 0.001,
                "en \(screen.width)×\(screen.height) la foto se mete en la barra de abajo"
            )
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

    /// En una pantalla corta la foto de antes (`0.52 × alto`) dejaba 5 pt libres
    /// arriba: el texto no tenía dónde ir. Ahora la foto cede.
    @Test("en pantallas cortas la foto cede el lugar al texto")
    func photoShrinksOnShortScreens() {
        let short = CGSize(width: 320, height: 568)
        let tall = CGSize(width: 440, height: 956)
        #expect(BoardScene.revealLayout(size: short).photoSide < BoardScene.revealLayout(size: tall).photoSide)
        #expect(BoardScene.revealLayout(size: short).photoSide >= 120, "pero sigue siendo reconocible")
    }
}
