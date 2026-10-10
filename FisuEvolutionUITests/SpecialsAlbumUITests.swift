import XCTest

/// El especial que cae queda en el Álbum de la Oficina central (PLAN-v2 E4),
/// con lo que te da. El drop sale de `--uitest-special` (es RNG sobre merges).
final class SpecialsAlbumUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElEspecialConseguidoApareceEnElAlbum() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-special"]
        app.launch()
        let claim = app.buttons["special.drop.claim"]
        XCTAssertTrue(claim.waitForExistence(timeout: 12))
        claim.tap()
        XCTAssertTrue(claim.waitForNonExistence(timeout: 8))

        let tab = app.buttons["hud.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: tab)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed)
        tab.tap()

        let albumCard = app.buttons["menu.card.specials"]
        XCTAssertTrue(albumCard.waitForExistence(timeout: 10), "la Oficina tiene la tarjeta del Álbum")
        XCTAssertTrue(app.buttons["menu.card.orgchart"].exists, "y las cuatro de siempre")
        albumCard.tap()

        let owned = app.descendants(matching: .any)["album.card.sp_cryptobro.owned"]
        XCTAssertTrue(owned.waitForExistence(timeout: 8), "el que cayó está en el Álbum")
        XCTAssertTrue(app.descendants(matching: .any)["album.card.sp_lizard.locked"].exists, "y los que faltan, en silueta")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "álbum: uno conseguido y nueve por conseguir"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
