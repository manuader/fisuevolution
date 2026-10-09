import XCTest

/// El selector del atajo (PLAN-v2 E3): mantener presionado abre las caras,
/// tocar una la fija, "Mejor disponible" la suelta y tocar afuera cierra. Con el
/// piso lleno el atajo sigue y avisa.
final class QuickHireUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMantenerPresionadoAbreElSelectorYFija() throws {
        let app = launch()
        openDebug("debug.quickhire.many", in: app)
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(waitUntilHittable(quickHire))
        let before = try XCTUnwrap(quickHire.value as? String)
        let currentID = String(before.split(separator: ":")[1].split(separator: ";")[0])

        quickHire.press(forDuration: 0.9)
        let best = app.buttons["quickhire.picker.best"]
        XCTAssertTrue(best.waitForExistence(timeout: 3), "mantener presionado no abrió el selector")
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quickhire.picker.option.'"))
        XCTAssertGreaterThanOrEqual(options.count, 2, "el escenario tiene varios contratables")
        attach(app, named: "E3 selector del atajo")

        let other = try XCTUnwrap((0..<options.count).map { options.element(boundBy: $0) }
            .first { !$0.identifier.hasSuffix(".\(currentID)") })
        let pinnedID = String(other.identifier.dropFirst("quickhire.picker.option.".count))
        other.tap()
        XCTAssertTrue(best.waitForNonExistence(timeout: 3), "elegir cierra el selector")
        XCTAssertTrue(waitForValue(of: quickHire) { $0.contains(":\(pinnedID);pinned") },
                      "el atajo no quedó fijado en \(pinnedID)")

        quickHire.press(forDuration: 0.9)
        XCTAssertTrue(best.waitForExistence(timeout: 3))
        best.tap()
        XCTAssertTrue(waitForValue(of: quickHire) { !$0.contains(";pinned") }, "Mejor disponible suelta el pin")
    }

    @MainActor
    func testTocarAfueraCierraElSelector() throws {
        let app = launch()
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(waitUntilHittable(quickHire))
        quickHire.press(forDuration: 0.9)
        let best = app.buttons["quickhire.picker.best"]
        XCTAssertTrue(best.waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        XCTAssertTrue(best.waitForNonExistence(timeout: 3), "tocar afuera cierra")
    }

    @MainActor
    func testConElPisoLlenoElAtajoSigueYAvisa() throws {
        let app = launch()
        openDebug("debug.floor.fill", in: app)
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(waitForValue(of: quickHire) { $0.hasPrefix("floorFull:") }, "el atajo no dice piso lleno")
        XCTAssertTrue(waitUntilHittable(quickHire))
        quickHire.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tower.notice"].waitForExistence(timeout: 3),
                      "tocar con el piso lleno avisa")
    }

    // MARK: - Utilidades

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func openDebug(_ identifier: String, in app: XCUIApplication) {
        let debugKey = app.buttons["hud.debug"]
        XCTAssertTrue(debugKey.waitForExistence(timeout: 6))
        debugKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 6), "el panel de debug no ofrece \(identifier)")
        button.tap()
        XCTAssertTrue(button.waitForNonExistence(timeout: 6))
    }

    @MainActor
    private func waitForValue(of element: XCUIElement, timeout: TimeInterval = 5,
                              _ matches: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = element.value as? String, matches(value) { return true }
            usleep(200_000)
        }
        return false
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable { return true }
            usleep(200_000)
        }
        return false
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
