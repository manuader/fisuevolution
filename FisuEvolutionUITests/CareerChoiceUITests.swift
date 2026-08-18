import XCTest

/// El fork de carrera de T9.
///
/// ⚠️ **Era la única pantalla del juego sin un solo test de UI**, y no por
/// descuido: es la más cara de alcanzar —hay que llegar a T9 y fusionar el par, o
/// sea horas de partida— y una vez elegida no vuelve hasta la próxima
/// reencarnación. Por eso se hizo vieja (cuatro botones azules del sistema, sin
/// retratos) sin que nadie lo notara. El fixture `--uitest-career` la abre en el
/// arranque y es lo que hace posible este archivo.
final class CareerChoiceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-career"]
        app.launch()
        return app
    }

    /// Las cuatro carreras del catálogo, con su premio a la vista.
    ///
    /// Se asserta que estén las CUATRO y no una: el fork es data-driven
    /// (`choiceOptions` del tier que bifurca), así que si alguna vez se cae una
    /// rama del catálogo esto lo dice en vez de dejar una pantalla con tres.
    @MainActor
    func testLasCuatroCarrerasSeOfrecenConSuPremio() throws {
        let app = launch()
        let options = ["junior_programmer", "junior_architect", "junior_doctor", "junior_lawyer"]

        for id in options {
            let card = app.buttons["career.option.\(id)"]
            XCTAssertTrue(card.waitForExistence(timeout: 15), "no apareció la opción \(id)")
            // El premio va en el `value` de la tarjeta (patrón T8: una sola
            // parada de VoiceOver por fila, con el detalle adentro). Vacío
            // significa que `careerRewards` dejó de resolver, que es
            // exactamente la elección a ciegas que RF-15 prohíbe.
            let reward = card.value as? String ?? ""
            XCTAssertFalse(reward.isEmpty, "\(id) se ofrece sin decir qué premio da")
        }
    }

    /// Elegir cierra la pantalla y no la vuelve a abrir: la elección dura hasta
    /// la próxima reencarnación.
    @MainActor
    func testElegirUnaCarreraCierraLaPantalla() throws {
        let app = launch()
        let pick = app.buttons["career.option.junior_doctor"]
        XCTAssertTrue(pick.waitForExistence(timeout: 15))
        pick.tap()

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: pick)
        waitForExpectations(timeout: 10)

        // Y el juego sigue: el HUD vivo (el ascensor es su control fijo) es lo
        // que prueba que volvimos al tablero y no quedamos en un sheet vacío.
        // (La píldora de piso se retiró el 2026-08-18.)
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 10),
                      "tras elegir hay que volver al tablero")
    }
}
