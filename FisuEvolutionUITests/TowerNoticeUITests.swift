import XCTest

/// Los avisos pasajeros salen arriba, entre las columnas, y se van solos (PLAN-v2 E14 C20).
/// El aviso sale del Corralito (`--uitest-corralito`): tocar el atajo de contratar rebota y
/// avisa, sin pasar por el panel de debug.
final class TowerNoticeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElAvisoSaleArribaEntreLasColumnasYSeVaSolo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins", "--uitest-corralito"]
        app.launch()
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(quickHire.waitForExistence(timeout: 20))
        let hudBottom = app.buttons["hud.map"].frame.maxY
        quickHire.tap()

        let notice = app.descendants(matching: .any)["tower.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "el rebote no avisa")
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(notice.frame.minY, hudBottom, "el aviso pisa el HUD")
        XCTAssertLessThan(notice.frame.maxY, screen.height * 0.4, "el aviso no está arriba")
        XCTAssertGreaterThan(notice.frame.minX, screen.width * 0.15, "el aviso tapa la columna de la izquierda")
        XCTAssertLessThan(notice.frame.maxX, screen.width * 0.85, "el aviso tapa la columna de la derecha")
        attach(app, named: "E14 T14 aviso arriba")

        // Un segundo toque renueva el aviso: no apila otro.
        quickHire.tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "tower.notice").count, 1)
        XCTAssertTrue(notice.waitForNonExistence(timeout: 8), "el aviso no se fue solo")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
