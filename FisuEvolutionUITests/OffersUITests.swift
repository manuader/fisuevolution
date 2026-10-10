import XCTest

/// Las ofertas de 24 h (PLAN-v2 E6): se presentan solas una vez y después viven
/// en el chip, que reabre la hoja.
final class OffersUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAnOpenOfferPresentsOnceAndLivesInTheChip() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-offer=renacer"]
        app.launch()

        let sheet = app.descendants(matching: .any)["offer.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 20), "la oferta no se presentó sola")
        attach(app, named: "E6 la oferta Renacer")
        app.buttons["sheet.close"].firstMatch.tap()

        let chip = app.buttons["hud.offer.chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "la oferta no quedó en el chip")
        chip.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "el chip no reabre la hoja")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
