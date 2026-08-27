import XCTest

/// La animación del cofre, de punta a punta: **cuatro toques del jugador**.
///
/// El gesto fino —las sacudidas, el flash de 80 ms, el giro 3D de la carta—
/// queda smoke-manual, como el del special: un UI test no puede juzgar 80 ms.
/// Lo que sí se pinea acá es que la máquina de latidos **avanza con el dedo** y
/// que termina ofreciendo el premio y devolviendo la cola.
final class ChestOpeningUITests: XCTestCase {
    /// El fixture abre un cofre y **apaga el reloj** de los cuatro latidos que
    /// esperan un toque.
    ///
    /// ⚠️ Lo segundo es la mitad importante. Cada latido se dispara solo a los
    /// 1,2 s para que nadie quede trabado, así que un smoke que tapea cuatro
    /// veces y espera la carta **queda verde con `tap()` desenchufada**: el
    /// reloj llega igual al reposo. Con `--uitest-chest-manual` la animación no
    /// se mueve si el dedo no la mueve, y un toque muerto la deja parada.
    private static let fixture = [
        "--uitest-reset", "--uitest-skip-tutorial", "--uitest-chest", "--uitest-chest-manual",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLosCuatroToquesAbrenElCofreYOfrecenLaPinta() throws {
        let app = XCUIApplication()
        app.launchArguments = Self.fixture
        app.launch()

        let area = app.buttons["chest.tap"]
        XCTAssertTrue(area.waitForExistence(timeout: 15),
                      "el fixture tiene que dejar la animación del cofre abierta")
        XCTAssertFalse(tarjeta(app).exists,
                       "la carta no sale del cofre antes de forzar el candado")
        XCTAssertFalse(app.buttons["chest.equip"].exists,
                       "y la pinta no se ofrece hasta que la carta se da vuelta")

        let llegada = XCTAttachment(screenshot: app.screenshot())
        llegada.name = "cofre: la llegada"
        llegada.lifetime = .keepAlways
        add(llegada)

        // Los tres toques del candado.
        area.tap()
        area.tap()
        area.tap()

        // La carta saliendo del cofre es la prueba de que los tres toques
        // hicieron el trabajo: `chest.card` no existe sin haber pasado por el
        // estallido, y al estallido no se llega sin los tres toques.
        let carta = tarjeta(app)
        XCTAssertTrue(carta.waitForExistence(timeout: 8),
                      "los tres toques tienen que reventar el cofre y sacar la carta")
        XCTAssertFalse(app.buttons["chest.equip"].exists,
                       "boca abajo la carta todavía no ofrece nada")

        let vuelo = XCTAttachment(screenshot: app.screenshot())
        vuelo.name = "cofre: la carta boca abajo"
        vuelo.lifetime = .keepAlways
        add(vuelo)

        // El cuarto toque: darla vuelta.
        area.tap()

        let equipar = app.buttons["chest.equip"]
        XCTAssertTrue(equipar.waitForExistence(timeout: 8),
                      "el cuarto toque tiene que dar vuelta la carta y ofrecer la pinta")
        XCTAssertTrue(app.buttons["chest.dismiss"].exists, "y la salida sin equipar")

        let reposo = XCTAttachment(screenshot: app.screenshot())
        reposo.name = "cofre: el premio"
        reposo.lifetime = .keepAlways
        add(reposo)

        // El área tappable se retira en el reposo: si siguiera puesta se comería
        // los toques de los dos botones que tiene encima.
        XCTAssertFalse(area.exists, "el área del cofre no sobrevive al reposo")
    }

    /// Cerrar la animación **destraba la cola**, que es el contrato que roto deja
    /// el juego mudo: `.chestOpening` no tiene timeout ni es salteable, así que
    /// si el payload sobrevive a su turno no hay nada que lo destrabe.
    ///
    /// El testigo es el HUD: la animación lo apaga (`celebrationHidesUI`) y que
    /// vuelva es la prueba, desde afuera, de que el turno terminó de verdad.
    @MainActor
    func testCerrarLaAnimacionDevuelveElHUD() throws {
        let app = XCUIApplication()
        app.launchArguments = Self.fixture
        app.launch()

        let area = app.buttons["chest.tap"]
        XCTAssertTrue(area.waitForExistence(timeout: 15))
        // Con el HUD apagado, la barra de abajo está en pantalla pero no se toca.
        let regalos = app.buttons["hud.bonus"]
        XCTAssertFalse(regalos.isHittable, "la animación del cofre tiene que apagar el HUD")

        area.tap()
        area.tap()
        area.tap()
        XCTAssertTrue(tarjeta(app).waitForExistence(timeout: 8))
        area.tap()

        let salir = app.buttons["chest.dismiss"]
        XCTAssertTrue(salir.waitForExistence(timeout: 8))
        salir.tap()

        // Si el dismiss cerrara el turno ANTES de soltar el payload, la cola lo
        // reencolaría en el mismo frame y el HUD no volvería nunca.
        let vuelve = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == 1"), object: regalos
        )
        XCTAssertEqual(XCTWaiter().wait(for: [vuelve], timeout: 10), .completed,
                       "cerrar el cofre tiene que devolver el HUD: la cola quedó trabada")
    }

    /// La carta del premio.
    ///
    /// ⚠️ **`app.otherElements["chest.card"]` no la encuentra**, y no es que no
    /// exista. El overlay declara `.accessibilityAddTraits(.isModal)` —para que
    /// VoiceOver no se vaya al HUD apagado— y con ese trait XCUITest clasifica el
    /// contenedor como **Alert** ("Automation type mismatch: computed Other from
    /// legacy attributes vs Alert from modern attribute"). Una consulta por tipo
    /// no baja adentro; `descendants(matching: .any)` sí.
    ///
    /// Los botones (`chest.tap`, `chest.equip`, `chest.dismiss`) **no** tienen el
    /// problema: `app.buttons` los encuentra igual. La asimetría es del motor de
    /// consultas, no del árbol.
    @MainActor
    private func tarjeta(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["chest.card"]
    }
}
