import XCTest

/// Los eventos que llevan a una tienda (E14 C25): el presentador anuncia, el popup ofrece «¡Vamos!» y
/// «Ahora no», y «¡Vamos!» abre la pantalla del producto. La entrada sale de `--uitest-event=<id>`.
final class ShopEventUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(event: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-blue=500", "--uitest-event=\(event)"]
        app.launch()
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let foto = XCTAttachment(screenshot: app.screenshot())
        foto.name = name
        foto.lifetime = .keepAlways
        add(foto)
    }

    @MainActor
    func testVamosAbreMejorasEnBoostsConElProductoALaVista() throws {
        let app = launch(event: "llego_el_blue")
        let go = app.buttons["event.shop.go"]
        XCTAssertTrue(go.waitForExistence(timeout: 20), "el popup de la oferta se abre solo")
        XCTAssertTrue(app.buttons["event.shop.later"].exists, "«Ahora no» está siempre")
        attach(app, "1-popup-llego-el-blue")
        go.tap()
        let boosts = app.buttons["upgrades.tab.boosts"]
        XCTAssertTrue(boosts.waitForExistence(timeout: 10), "se abrió Mejoras")
        XCTAssertTrue(boosts.isSelected, "en la pestaña de los boosts")
        XCTAssertTrue(app.buttons["blueShop.buy.income_x2"].waitForExistence(timeout: 10), "el ×2 de ingresos a la vista")
        sleep(1)
        attach(app, "2-mejoras-boosts-en-foco")
    }

    @MainActor
    func testVamosAbreLaTienda() throws {
        let app = launch(event: "cyber_monday")
        let go = app.buttons["event.shop.go"]
        XCTAssertTrue(go.waitForExistence(timeout: 20))
        attach(app, "3-popup-cyber-monday")
        go.tap()
        XCTAssertTrue(app.buttons["store.restore"].waitForExistence(timeout: 10), "se abrió la Tienda")
        sleep(1)
        attach(app, "4-tienda-pack-en-foco")
    }

    @MainActor
    func testAhoraNoCierraSinAbrirNada() throws {
        let app = launch(event: "cuevita_abierta")
        let later = app.buttons["event.shop.later"]
        XCTAssertTrue(later.waitForExistence(timeout: 20))
        later.tap()
        XCTAssertTrue(later.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["store.restore"].exists)
        XCTAssertFalse(app.buttons["upgrades.tab.boosts"].exists)
    }
}
