import XCTest

/// El veterano de la v1 recién actualizado recibe el Tour de novedades (PLAN-v2 E9b T4).
@MainActor
final class WhatsNewTourUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testElVeteranoRecorreLasNovedadesYTermina() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-veteran", "--uitest-tutorial-lock=0.3"]
        app.launch()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 15))
        XCTAssertEqual(step.value as? String, "tour.intro")
        XCTAssertEqual(app.descendants(matching: .any)["tutorial.tip"].value as? String, "tour")
        XCTAssertFalse(app.buttons["tutorial.replay.end"].exists, "el Tour no se termina antes")
        var seen: [String] = []
        let confirm = app.buttons["tutorial.confirm"]
        var guardRail = 0
        while step.exists, guardRail < 25 {
            if let id = step.value as? String, seen.last != id { seen.append(id) }
            let unlocked = NSPredicate(format: "value == 'unlocked'")
            if confirm.waitForExistence(timeout: 5),
               XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: unlocked, object: confirm)],
                                timeout: 5) == .completed {
                confirm.tap()
            }
            guardRail += 1
        }
        XCTAssertTrue(step.waitForNonExistence(timeout: 5))
        XCTAssertEqual(seen.first, "tour.intro")
        XCTAssertEqual(seen.last, "tour.done", "recorrió el Tour entero: \(seen)")
        XCTAssertEqual(seen.count, 12, "los doce pasos, en orden: \(seen)")
    }
}
