import XCTest

/// La tienda de ORO (PLAN-v2 E6): el selector en la cabecera de la Tienda, las
/// filas que cobran y el saldo que baja. Todo por identifier: el runner corre en
/// inglés (trampa 6).
final class OroShopUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openStore(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extra
        app.launch()
        let store = app.buttons["hud.coins.plus"]
        XCTAssertTrue(store.waitForExistence(timeout: 20), "el + de la moneda nunca apareció")
        store.tap()
        return app
    }

    @MainActor
    private func openSpendSide(_ extra: [String] = []) -> (app: XCUIApplication, balance: XCUIElement) {
        let app = openStore(["--uitest-oro=500"] + extra)
        let spend = app.buttons["store.segment.spend"]
        XCTAssertTrue(spend.waitForExistence(timeout: 10))
        spend.tap()
        // `descendants(.any)`: la píldora combina ícono y texto, y el tipo del
        // elemento combinado no está garantizado.
        let balance = app.descendants(matching: .any)["oroShop.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        return (app, balance)
    }

    @MainActor
    private func waitForBalance(_ balance: XCUIElement, _ value: String) {
        expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: balance)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testTheStoreStillOpensOnTheMoneySide() throws {
        let app = openStore()
        XCTAssertTrue(app.buttons["store.segment.buy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["store.segment.spend"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["oroShop.balance"].exists, "abre en Comprar ORO: App Review ve primero los IAP")
    }

    /// La bajada de la cabecera acompaña a la mitad elegida: en Gastar ORO ya no
    /// habla de plata de verdad, y al volver a Comprar ORO vuelve la de los packs.
    @MainActor
    func testTheStoreSubtitleFollowsTheSelectedSide() throws {
        let app = openStore()
        let buySubtitle = app.staticTexts["store.subtitle.buy"]
        let spendSubtitle = app.staticTexts["store.subtitle.spend"]
        XCTAssertTrue(buySubtitle.waitForExistence(timeout: 10), "abre en Comprar ORO con su bajada")
        XCTAssertFalse(spendSubtitle.exists)

        app.buttons["store.segment.spend"].tap()
        XCTAssertTrue(spendSubtitle.waitForExistence(timeout: 5), "Gastar ORO tiene su bajada")
        XCTAssertFalse(buySubtitle.exists, "la bajada de la plata no queda en Gastar ORO")
        XCTAssertTrue(app.buttons["store.restore"].exists, "restaurar compras se ve en las dos mitades")

        app.buttons["store.segment.buy"].tap()
        XCTAssertTrue(buySubtitle.waitForExistence(timeout: 5))
        XCTAssertFalse(spendSubtitle.exists)
    }

    @MainActor
    func testTheOroShopChargesAndCountsTheDay() throws {
        let (app, balance) = openSpendSide()
        XCTAssertEqual(balance.value as? String, "500")

        let buy = app.buttons["oroShop.buy.income_x2"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        attach(app, named: "E6 la tienda de ORO")
        buy.tap()

        waitForBalance(balance, "470")
        XCTAssertTrue(app.staticTexts["oroShop.status.income_x2"].exists, "la fila dice cuántos van hoy")
        attach(app, named: "E6 después de comprar")
    }

    @MainActor
    func testEveryShelfIsThere() throws {
        let (app, _) = openSpendSide()
        for id in ["income_x2", "time_jump_1h", "offline_x3"] {
            XCTAssertTrue(app.buttons["oroShop.buy.\(id)"].waitForExistence(timeout: 5), "\(id) no se ofrece")
        }
        XCTAssertTrue(app.staticTexts["oroShop.footer.reincarnate"].exists, "los boosts avisan que se pierden al reencarnar")
    }

    /// Un toque cobra una vez, con el saldo esperado. El cerrojo contra el doble
    /// toque se prueba sin reloj en `OroShopScreenTests.latch`: dos `tap()` de
    /// XCUITest esperan a que la app quede quieta y pueden caer fuera de su ventana.
    @MainActor
    func testOneTapChargesOnce() throws {
        let (app, balance) = openSpendSide()
        let buy = app.buttons["oroShop.buy.income_x2"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        buy.tap()
        waitForBalance(balance, "470")
        sleep(1)
        XCTAssertEqual(balance.value as? String, "470")
    }

    @MainActor
    func testAPendingTripleSaysItComesTripled() throws {
        let (app, balance) = openSpendSide()
        let buy = app.buttons["oroShop.buy.offline_x3"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        buy.tap()
        waitForBalance(balance, "380")
        XCTAssertTrue(app.staticTexts["oroShop.pending.offline_x3"].waitForExistence(timeout: 5), "la fila avisa que el popup viene ×3")
        XCTAssertTrue(app.descendants(matching: .any)["oroShop.blocked.offline_x3"].exists, "no se vende otro mientras hay uno esperando")
    }

    @MainActor
    func testReduceMotionStillCharges() throws {
        let (app, balance) = openSpendSide(["-UIAccessibilityReduceMotionEnabled", "YES"])
        let buy = app.buttons["oroShop.buy.income_x2"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        buy.tap()
        waitForBalance(balance, "470")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
