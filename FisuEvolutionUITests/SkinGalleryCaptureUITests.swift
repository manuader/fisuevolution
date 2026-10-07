import XCTest

/// Las fotos de la galería de efectos (PLAN-v2 E6, gate del dueño). No juzga
/// nada: deja una captura por efecto en el `.xcresult`, con su nombre, para que
/// el dueño elija cuáles entran. Se exportan con
/// `xcrun xcresulttool export attachments --path <xcresult> --output-path build/galeria-efectos`.
final class SkinGalleryCaptureUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureEveryEffect() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower"]
        app.launch()
        let debug = app.buttons["hud.debug"]
        XCTAssertTrue(debug.waitForExistence(timeout: 20))
        debug.tap()
        let gallery = app.buttons["debug.skinGallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 10))
        gallery.tap()
        XCTAssertTrue(app.descendants(matching: .any)["gallery.stage"].waitForExistence(timeout: 10))

        app.buttons["gallery.effect.all"].tap()
        attach(app, named: "efectos-todos")
        for id in ["neon", "holograma", "fantasma", "arcoiris", "glitch", "pixel", "oro_liquido", "sombra"] {
            let button = app.buttons["gallery.effect.\(id)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "falta \(id) en la galería")
            scrollToHittable(button, in: app)
            button.tap()
            attach(app, named: "efecto-\(id)")
        }
        // Un `Toggle` es un switch para XCUITest, no un botón.
        app.switches["gallery.animated"].tap()
        attach(app, named: "efecto-sombra-quieto")
    }

    /// La fila de efectos es una tira horizontal: los últimos botones quedan fuera de pantalla.
    @MainActor
    private func scrollToHittable(_ button: XCUIElement, in app: XCUIApplication) {
        let strip = app.scrollViews.firstMatch
        var swipes = 0
        while button.frame.maxX > app.frame.width && swipes < 6 {
            strip.swipeLeft()
            swipes += 1
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
