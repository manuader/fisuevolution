import XCTest

/// Las 4 filas (el permanente de lugares extra) en la pantalla más chica que
/// soporta la app. No juzga el arte: deja la captura y pinea que el tablero
/// tenga la capacidad agrandada y el piso lleno.
final class ExtraSlotsLayoutUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTheFullFloorWithExtraSlots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-extra-slots"]
        app.launch()
        let layout = app.descendants(matching: .any)["board.layout"]
        XCTAssertTrue(layout.waitForExistence(timeout: 20))
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 10))
        let marker = try XCTUnwrap(layout.value as? String)
        let rows = try XCTUnwrap(Int(marker.split(separator: "x")[1].split(separator: "@")[0]))
        let count = try XCTUnwrap(Int(units.value as? String ?? ""))
        XCTAssertEqual(rows, (count + 4) / 5, "las filas son las de la capacidad agrandada")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "E6 lugares extra, piso lleno (\(marker))"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
