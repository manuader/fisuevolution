import XCTest

/// RF-05 · que el arte de la carita se APRECIE.
///
/// El pedido del dueño fue textual: *"en la pestaña de upgrades hace que la foto
/// de cada personaje sea el doble de grande (…) debe apreciarse bien el arte del
/// juego"*. El círculo medía 38 pt de lado; el doble son 76.
///
/// El tamaño se mide **en pantalla y no en el código**: una constante puede decir
/// 76 y la fila apretar el círculo igual (el header comparte el ancho con el
/// nombre). Por eso el círculo expone un accessibility identifier y lo que se
/// asserta es su `frame`.
///
/// ⚠️ Se asserta por identifier y **nunca** por texto: el runner corre la app en
/// inglés aunque el idioma de desarrollo del proyecto sea `es` (trampa 6 del
/// HANDOFF).
final class UpgradesFaceUITests: XCTestCase {
    /// 38 pt era el tamaño viejo. El pedido es exactamente el doble.
    private static let expectedSide: CGFloat = 76

    /// La captura va antes de los asserts a propósito: en rojo también quiero la
    /// foto, porque el criterio de este pedido es estético y se juzga mirando.
    @MainActor
    func testEveryCharacterRowShowsItsFaceAtDoubleSize() throws {
        continueAfterFailure = true

        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-reset",
            "--uitest-skip-tutorial",
            "--uitest-unlock-tower",
            // Sin esto la lista tiene UNA fila: sale de `run.seenTypes` (RF-03) y
            // `--uitest-unlock-tower` abre pisos pero no marca tipos vistos.
            "--uitest-seen-types",
        ]
        app.launch()

        let upgrades = app.buttons["hud.upgrades"]
        XCTAssertTrue(upgrades.waitForExistence(timeout: 30), "no apareció la acción de mejoras del HUD")
        upgrades.tap()

        XCTAssertTrue(
            app.buttons["upgrades.tab.characters"].waitForExistence(timeout: 15),
            "no abrió el menú de mejoras"
        )

        attach(app, named: "RF-05 pestaña Personajes")

        let faces = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "upgrades.character.", ".face")
        )
        XCTAssertGreaterThanOrEqual(
            faces.count, 3,
            "el fixture tiene que dejar varias filas a la vista para poder juzgar la pantalla"
        )

        var medidas = 0
        for index in 0 ..< faces.count {
            let face = faces.element(boundBy: index)
            let frame = face.frame
            // Las filas de más abajo del ScrollView existen en el árbol pero no
            // están en pantalla; medir su alto igual es válido, pero si el
            // sistema devuelve un rect vacío no hay nada que asertar.
            guard !frame.isEmpty else { continue }
            medidas += 1
            XCTAssertEqual(
                frame.height, Self.expectedSide, accuracy: 1,
                "la carita de \(face.identifier) mide \(frame.height) pt: el pedido es el doble de los 38 pt viejos"
            )
            XCTAssertEqual(
                frame.width, frame.height, accuracy: 1,
                "la carita de \(face.identifier) dejó de ser un círculo: \(frame.width)×\(frame.height)"
            )
        }
        XCTAssertGreaterThanOrEqual(medidas, 3, "no se pudo medir ninguna carita: la fila no la expone")

        // El nombre largo ("Empleado de Fast Food") vive más abajo y es el que
        // dice si el encabezado aguanta al lado de una carita del doble de
        // tamaño. Un assert no lo juzga: esta captura es para MIRARLA.
        app.swipeUp()
        app.swipeUp()
        attach(app, named: "RF-05 nombres largos")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
