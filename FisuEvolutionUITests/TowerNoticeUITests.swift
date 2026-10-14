import XCTest

/// Los avisos pasajeros salen arriba, entre las columnas, y se van solos (PLAN-v2 E14 C20).
/// El aviso sale del Corralito (`--uitest-corralito`): tocar el atajo de contratar rebota y
/// avisa, sin pasar por el panel de debug. `--uitest-notices-slow` estira el aviso a 9,6 s:
/// con la máquina cargada cada consulta tarda más de un segundo y los 2,4 s de siempre se iban
/// antes de la primera (relevo 56).
final class TowerNoticeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElAvisoSaleArribaEntreLasColumnasYSeVaSolo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins", "--uitest-corralito",
                                "--uitest-notices-slow"]
        app.launch()
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(quickHire.waitForExistence(timeout: 20))
        let hudBottom = app.buttons["hud.map"].frame.maxY
        quickHire.tap()

        let notice = app.descendants(matching: .any)["tower.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "el rebote no avisa")
        // Un solo snapshot del marco: cada consulta puede tardar más de un segundo.
        let frame = notice.frame
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(frame.minY, hudBottom, "el aviso pisa el HUD")
        XCTAssertLessThan(frame.maxY, screen.height * 0.4, "el aviso no está arriba")
        XCTAssertGreaterThan(frame.minX, screen.width * 0.15, "el aviso tapa la columna de la izquierda")
        XCTAssertLessThan(frame.maxX, screen.width * 0.85, "el aviso tapa la columna de la derecha")
        attach(app, named: "E14 T14 aviso arriba")

        // Un segundo toque, con el aviso todavía arriba, lo renueva: no apila otro.
        quickHire.tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "tower.notice").count, 1)
        XCTAssertTrue(notice.waitForNonExistence(timeout: 20), "el aviso no se fue solo")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
