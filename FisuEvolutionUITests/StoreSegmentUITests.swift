import XCTest

/// El destaque «Elegido para vos» de la Tienda (2.1 E15 F5 T3): con `high` (partida nueva, sin
/// compras) se destaca el pack de inicio; con `base` la Tienda es la de la 2.0, sin destaque.
///
/// ⚠️ Por identifier, no por texto: el runner corre en inglés (trampa 6 del HANDOFF).
final class StoreSegmentUITests: XCTestCase {
    private static let starterChosen = "store.chosen.com.fisuevolution.iap.starter_pack"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openStore(segment: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-segment", segment]
        app.launch()

        let store = app.buttons["hud.coins.plus"]
        XCTAssertTrue(store.waitForExistence(timeout: 20), "el + de la moneda nunca apareció")
        store.tap()
        XCTAssertTrue(
            app.buttons["store.buy.com.fisuevolution.iap.starter_pack"].waitForExistence(timeout: 20),
            "la Tienda no cargó el pack de inicio"
        )
        return app
    }

    @MainActor
    func testHighSegmentHighlightsTheStarterPack() throws {
        let app = openStore(segment: "high")
        XCTAssertTrue(
            app.descendants(matching: .any)[Self.starterChosen].waitForExistence(timeout: 5),
            "con high y sin compras, el pack de inicio lleva «Elegido para vos»"
        )
        attach(app, named: "F5 la Tienda con el destaque")
    }

    @MainActor
    func testBaseSegmentHasNoHighlight() throws {
        let app = openStore(segment: "base")
        let chosen = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "store.chosen."))
        XCTAssertEqual(chosen.count, 0, "con base la Tienda es la de la 2.0: nada destacado")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
