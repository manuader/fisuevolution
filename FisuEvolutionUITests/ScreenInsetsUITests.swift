import XCTest

/// Las safe areas observables (PLAN-v2 E3, `ScreenInsets`).
///
/// ⚠️ Pin de una carrera que sólo se ve en un **iPhone SE (3ª gen.)**, donde la
/// barra de estado oculta (`RootView.statusBarHidden`) desploma el inset
/// superior de 20 a 0 DESPUÉS de que el HUD aparece. Con la sonda de fondo del
/// HUD publicando desde su propio layout, el aviso nunca llegaba y la fila se
/// quedaba pegada al bezel en 5 de 9 arranques (spike S4: el contador de
/// monedas a 7,5 pt del borde). En los demás dispositivos la cota se cumple de
/// todos modos, así que ahí el test pasa sin discriminar nada.
final class ScreenInsetsUITests: XCTestCase {
    /// `HUDView.minimumTopGap`: el aire mínimo entre el bezel y la fila.
    private static let minimumTopGap: CGFloat = 14
    private static let launches = 3
    /// Lo que tarda el inset en asentarse (spike S4: cambia en las primeras
    /// décimas de segundo; la carrera lo dejaba mal para siempre).
    private static let settle: TimeInterval = 3

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElHUDRespetaElAireContraElBezelEnTresArranques() throws {
        for run in 1...Self.launches {
            let app = XCUIApplication()
            app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
            app.launch()

            let coins = app.otherElements["hud.coins"]
            XCTAssertTrue(coins.waitForExistence(timeout: 60), "arranque \(run): el HUD no apareció")
            Thread.sleep(forTimeInterval: Self.settle)

            let minY = coins.frame.minY
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "arranque \(run): hud.coins a \(minY) pt del borde"
            attachment.lifetime = .keepAlways
            add(attachment)

            XCTAssertGreaterThanOrEqual(
                minY, Self.minimumTopGap,
                "arranque \(run): el contador quedó a \(minY) pt del borde (la carrera de la sonda lo dejaba en 7,5)"
            )
            app.terminate()
        }
    }
}
