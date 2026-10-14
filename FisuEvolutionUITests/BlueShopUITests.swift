import XCTest

/// Gastar blue (PLAN-v2 E6, E14 C11): vive en Mejoras —Permanentes y Boosts—, no en
/// la Tienda. Todo por identifier: el runner corre en inglés (trampa 6).
final class BlueShopUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openUpgrades(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extra
        app.launch()
        let upgrades = app.buttons["hud.upgrades"]
        XCTAssertTrue(upgrades.waitForExistence(timeout: 20), "la pestaña Mejoras nunca apareció")
        upgrades.tap()
        return app
    }

    @MainActor
    private func openTab(_ tab: String, _ extra: [String] = []) -> (app: XCUIApplication, balance: XCUIElement) {
        let app = openUpgrades(["--uitest-blue=500"] + extra)
        let button = app.buttons["upgrades.tab.\(tab)"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        // `descendants(.any)`: la píldora combina ícono y texto, y el tipo del
        // elemento combinado no está garantizado.
        let balance = app.descendants(matching: .any)["blueShop.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        return (app, balance)
    }

    @MainActor
    private func openSpendSide(_ extra: [String] = []) -> (app: XCUIApplication, balance: XCUIElement) {
        openTab("boosts", extra)
    }

    @MainActor
    private func waitForBalance(_ balance: XCUIElement, _ value: String) {
        expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: balance)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testUpgradesHasThreeTabsAndThePermanentOnesLeadWithTheGoal() throws {
        let (app, _) = openTab("permanent")
        for tab in ["characters", "permanent", "boosts"] {
            XCTAssertTrue(app.buttons["upgrades.tab.\(tab)"].exists, "falta la pestaña \(tab)")
        }
        XCTAssertTrue(
            app.buttons["blueShop.buy.extra_slots"].waitForExistence(timeout: 5),
            "los lugares extra de la torre viven en Permanentes"
        )
        XCTAssertTrue(app.buttons["upgrades.permanent.income"].exists, "y las siete globales, debajo")
        XCTAssertTrue(
            app.descendants(matching: .any)["upgrades.goal.bar"].exists,
            "con 500 blue falta para los 600 de la meta: la barra de ahorro"
        )
        XCTAssertFalse(app.buttons["blueShop.buy.income_x2"].exists, "los boosts no se mezclan con los permanentes")
        attach(app, named: "E14 T19 Permanentes")
    }

    @MainActor
    func testTheGoalBecomesTheBuyButtonAndChargesOnce() throws {
        let app = openUpgrades(["--uitest-blue=700"])
        app.buttons["upgrades.tab.permanent"].tap()
        let balance = app.descendants(matching: .any)["blueShop.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        let buy = app.buttons["upgrades.goal.buy"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5), "con 700 blue la meta alcanza: el botón reemplaza a la barra")
        XCTAssertFalse(app.descendants(matching: .any)["upgrades.goal.bar"].exists)
        buy.tap()
        waitForBalance(balance, "100")
        sleep(1)
        XCTAssertEqual(balance.value as? String, "100")
    }

    @MainActor
    func testBoostsTabHoldsBoostsAndShortcutsAndNoTheShop() throws {
        let (app, _) = openSpendSide()
        XCTAssertTrue(app.buttons["blueShop.buy.income_x2"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["blueShop.buy.extra_slots"].exists)
        XCTAssertFalse(app.buttons["store.restore"].exists, "la Tienda es otra hoja")
    }

    @MainActor
    func testThePlusLeadsToTheStoreForMoreBlue() throws {
        let (app, _) = openTab("permanent")
        let plus = app.buttons["upgrades.blue.plus"]
        XCTAssertTrue(plus.exists)
        plus.tap()
        XCTAssertTrue(app.buttons["store.restore"].waitForExistence(timeout: 10), "el + abre la Tienda de plata real")
    }

    @MainActor
    func testTheBlueShopChargesAndCountsTheDay() throws {
        let (app, balance) = openSpendSide()
        XCTAssertEqual(balance.value as? String, "500")

        let buy = app.buttons["blueShop.buy.income_x2"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        attach(app, named: "E6 la tienda de blue")
        buy.tap()

        waitForBalance(balance, "470")
        XCTAssertTrue(app.staticTexts["blueShop.status.income_x2"].exists, "la fila dice cuántos van hoy")
        attach(app, named: "E6 después de comprar")
    }

    @MainActor
    func testEveryShelfIsThere() throws {
        let (app, _) = openSpendSide()
        for id in ["income_x2", "time_jump_1h", "offline_x3"] {
            XCTAssertTrue(app.buttons["blueShop.buy.\(id)"].waitForExistence(timeout: 5), "\(id) no se ofrece")
        }
        XCTAssertTrue(app.staticTexts["blueShop.footer.reincarnate"].exists, "los boosts avisan que se pierden al reencarnar")
    }

    /// Un toque cobra una vez, con el saldo esperado. El cerrojo contra el doble
    /// toque se prueba sin reloj en `BlueShopScreenTests.latch`: dos `tap()` de
    /// XCUITest esperan a que la app quede quieta y pueden caer fuera de su ventana.
    @MainActor
    func testOneTapChargesOnce() throws {
        let (app, balance) = openSpendSide()
        let buy = app.buttons["blueShop.buy.income_x2"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        buy.tap()
        waitForBalance(balance, "470")
        sleep(1)
        XCTAssertEqual(balance.value as? String, "470")
    }

    @MainActor
    func testAPendingTripleSaysItComesTripled() throws {
        let (app, balance) = openSpendSide()
        let buy = app.buttons["blueShop.buy.offline_x3"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        buy.tap()
        waitForBalance(balance, "380")
        XCTAssertTrue(app.staticTexts["blueShop.pending.offline_x3"].waitForExistence(timeout: 5), "la fila avisa que el popup viene ×3")
        XCTAssertTrue(app.descendants(matching: .any)["blueShop.blocked.offline_x3"].exists, "no se vende otro mientras hay uno esperando")
    }

    @MainActor
    func testReduceMotionStillCharges() throws {
        let (app, balance) = openSpendSide(["-UIAccessibilityReduceMotionEnabled", "YES"])
        let buy = app.buttons["blueShop.buy.income_x2"]
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
