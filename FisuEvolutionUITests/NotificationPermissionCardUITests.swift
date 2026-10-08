import XCTest

/// La tarjeta del permiso completo (PLAN-v2 E11), adentro del popup offline.
///
/// ⚠️ Bajo `--uitest*` el juego no le habla a iOS, así que sin
/// `--uitest-notifications-provisional` la tarjeta no aparece nunca (el segundo
/// test lo pinea). Con el fixture, un centro en memoria contesta "provisional"
/// sin el diálogo del sistema, que en un runner es un muro.
final class NotificationPermissionCardUITests: XCTestCase {
    @MainActor
    func testLaTarjetaApareceEnElPopupOfflineYAhoraNoLaCierra() throws {
        let app = launch(extraArguments: ["--uitest-notifications-provisional"])
        let decline = app.buttons["notifications.card.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 20), "la tarjeta del permiso no apareció en el popup offline")
        attach(app, named: "E11 tarjeta del permiso")
        XCTAssertTrue(app.buttons["notifications.card.accept"].exists, "falta «Sí, avisame»")
        XCTAssertTrue(app.otherElements["notifications.card"].exists, "falta el marcador de la tarjeta")

        decline.tap()

        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons["notifications.card.accept"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "«Ahora no» no cerró la tarjeta")
        XCTAssertTrue(app.buttons["offline.collect"].exists, "«Ahora no» cierra la tarjeta, no el popup")
        attach(app, named: "E11 tarjeta cerrada")
    }

    @MainActor
    func testSinElFixtureBajoUITestNoSeOfreceNada() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["offline.collect"].waitForExistence(timeout: 20), "--uitest-offline no abrió el popup")
        XCTAssertFalse(app.buttons["notifications.card.accept"].waitForExistence(timeout: 3),
                       "bajo --uitest el juego ofreció el permiso sin que el test lo pidiera")
    }

    // MARK: Andamio

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-offline"] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
