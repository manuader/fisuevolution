import XCTest

/// Comprar con ORO una pinta exclusiva de la v1 en la tienda (PLAN-v2 E6b T8).
/// Por identifier: el runner corre en inglés (trampa 6).
final class CosmeticsUITests: XCTestCase {
    /// La primera exclusiva del catálogo (150 ORO): `OroSkinsContentTests` pinea la lista.
    private static let exclusive = "corona_solar"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBuyAnExclusiveWithOroAndItIsYours() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-oro=500"]
        app.launch()
        let plus = app.buttons["hud.coins.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 20), "el + de la moneda nunca apareció")
        plus.tap()
        let spend = app.buttons["store.segment.spend"]
        XCTAssertTrue(spend.waitForExistence(timeout: 10))
        spend.tap()
        let balance = app.descendants(matching: .any)["oroShop.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        XCTAssertEqual(balance.value as? String, "500")

        let buy = app.buttons["oroShop.cosmetic.buy.\(Self.exclusive)"]
        for _ in 0..<8 where !buy.exists { app.swipeUp() }
        XCTAssertTrue(buy.exists, "la exclusiva no se vende")
        buy.tap()

        XCTAssertTrue(app.descendants(matching: .any)["oroShop.cosmetic.owned.\(Self.exclusive)"].waitForExistence(timeout: 5))
        XCTAssertFalse(buy.exists, "comprada, deja de ofrecerse")
        expectation(for: NSPredicate(format: "value == %@", "350"), evaluatedWith: balance)
        waitForExpectations(timeout: 5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "E6b T8 una exclusiva comprada"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
