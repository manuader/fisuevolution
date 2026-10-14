import XCTest

/// Comprar con blue una pinta exclusiva de la v1, en Pintas (PLAN-v2 E6b T8, E14 C11).
/// Por identifier: el runner corre en inglés (trampa 6).
final class CosmeticsUITests: XCTestCase {
    /// La primera exclusiva del catálogo (150 blue): `BlueSkinsContentTests` pinea la lista.
    private static let exclusive = "corona_solar"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBuyAnExclusiveWithBlueAndItIsYours() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-blue=500"]
        app.launch()
        let skins = app.buttons["hud.skins"]
        XCTAssertTrue(skins.waitForExistence(timeout: 20), "la pestaña Pintas nunca apareció")
        skins.tap()
        let balance = app.descendants(matching: .any)["blueShop.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        XCTAssertEqual(balance.value as? String, "500")

        let buy = app.buttons["blueShop.cosmetic.buy.\(Self.exclusive)"]
        for _ in 0..<8 where !buy.exists { app.swipeUp() }
        XCTAssertTrue(buy.exists, "la exclusiva no se vende")
        buy.tap()

        XCTAssertTrue(app.descendants(matching: .any)["blueShop.cosmetic.owned.\(Self.exclusive)"].waitForExistence(timeout: 5))
        XCTAssertFalse(buy.exists, "comprada, deja de ofrecerse")
        expectation(for: NSPredicate(format: "value == %@", "350"), evaluatedWith: balance)
        waitForExpectations(timeout: 5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "E6b T8 una exclusiva comprada"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
