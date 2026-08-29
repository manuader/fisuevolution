import XCTest

/// La animación del cofre, de punta a punta: **tres toques del jugador** y el
/// video del animador hace el resto, hasta el marco con el premio adentro.
///
/// El gesto fino —las sacudidas, el push-in, el alfa del HEVC— queda
/// smoke-manual, como el del special: un UI test no puede juzgar un chroma.
/// Lo que sí se pinea acá es que la máquina de latidos **avanza con el dedo**,
/// que el tramo cinemático desemboca solo en el premio, y que cerrar devuelve
/// la cola.
final class ChestOpeningUITests: XCTestCase {
    /// El fixture abre un cofre y **apaga el reloj** de los tres latidos que
    /// esperan un toque (además acelera el video a 4× — sin eso cada smoke
    /// pagaría los 5,3 s del tramo cinemático).
    ///
    /// ⚠️ Lo primero es la mitad importante. Cada latido se dispara solo a los
    /// 1,2 s para que nadie quede trabado, así que un smoke que tapea tres
    /// veces y espera el premio **queda verde con `tap()` desenchufada**: el
    /// reloj llega igual al reposo. Con `--uitest-chest-manual` la animación no
    /// se mueve si el dedo no la mueve, y un toque muerto la deja parada.
    private static let fixture = [
        "--uitest-reset", "--uitest-skip-tutorial", "--uitest-chest", "--uitest-chest-manual",
    ]

    /// El video a 4× dura 1,3 s (ya viene retimeado a 1,5×); el resto es
    /// margen de simulador cargado.
    private static let cinematicTimeout: TimeInterval = 12

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLosTresToquesAbrenElCofreYOfrecenLaPinta() throws {
        let app = XCUIApplication()
        app.launchArguments = Self.fixture
        app.launch()

        let area = app.buttons["chest.tap"]
        XCTAssertTrue(area.waitForExistence(timeout: 15),
                      "el fixture tiene que dejar la animación del cofre abierta")
        XCTAssertFalse(tarjeta(app).exists,
                       "el premio no existe antes de forzar el candado")
        XCTAssertFalse(app.buttons["chest.equip"].exists,
                       "y la pinta no se ofrece hasta el marco final")

        let llegada = XCTAttachment(screenshot: app.screenshot())
        llegada.name = "cofre: la llegada"
        llegada.lifetime = .keepAlways
        add(llegada)

        // Los tres toques del candado; el video corre solo después del tercero.
        area.tap()
        area.tap()
        area.tap()

        // El premio dentro del marco es la prueba de que los tres toques
        // hicieron el trabajo Y de que el tramo cinemático desembocó solo:
        // `chest.card` no existe sin haber pasado por los dos.
        let carta = tarjeta(app)
        XCTAssertTrue(carta.waitForExistence(timeout: Self.cinematicTimeout),
                      "los tres toques tienen que reventar el cofre y el video terminar en el premio")

        let equipar = app.buttons["chest.equip"]
        XCTAssertTrue(equipar.waitForExistence(timeout: 4),
                      "el marco final tiene que ofrecer la pinta")
        XCTAssertTrue(app.buttons["chest.dismiss"].exists, "y la salida sin equipar")

        let reposo = XCTAttachment(screenshot: app.screenshot())
        reposo.name = "cofre: el premio en el marco"
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

        let salir = app.buttons["chest.dismiss"]
        XCTAssertTrue(salir.waitForExistence(timeout: Self.cinematicTimeout))
        salir.tap()

        // Si el dismiss cerrara el turno ANTES de soltar el payload, la cola lo
        // reencolaría en el mismo frame y el HUD no volvería nunca.
        let vuelve = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == 1"), object: regalos
        )
        XCTAssertEqual(XCTWaiter().wait(for: [vuelve], timeout: 10), .completed,
                       "cerrar el cofre tiene que devolver el HUD: la cola quedó trabada")
    }

    /// El premio dentro del marco.
    ///
    /// ⚠️ **`app.otherElements["chest.card"]` no lo encuentra**, y no es que no
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
