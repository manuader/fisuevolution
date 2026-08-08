import XCTest

/// RF-05 · que el arte del personaje se APRECIE.
///
/// El pedido del dueño, del 2026-08-07: *"no quiero que la foto de la cara de los
/// personajes esté embebida en un círculo, sino que tiene que ser la card quien
/// contenga toda la imagen (en la parte izquierda)"*. O sea: el retrato es una
/// **banda** de la card, de ancho fijo y alto el de la card entera.
///
/// Se mide **en pantalla y no en el código**: una constante puede decir 104 y la
/// fila apretar la banda igual. Por eso el retrato expone un accessibility
/// identifier y lo que se asserta es su `frame`.
///
/// ⚠️ Se asserta por identifier y **nunca** por texto: el runner corre la app en
/// inglés aunque el idioma de desarrollo del proyecto sea `es` (trampa 6 del
/// HANDOFF).
final class UpgradesFaceUITests: XCTestCase {
    /// El ancho de la banda, `CharacterPortrait.width`.
    private static let expectedWidth: CGFloat = 104

    /// La captura va antes de los asserts a propósito: en rojo también quiero la
    /// foto, porque el criterio de este pedido es estético y se juzga mirando.
    @MainActor
    func testEveryCharacterRowShowsItsPortraitAsAFullHeightBand() throws {
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
                frame.width, Self.expectedWidth, accuracy: 1,
                "el retrato de \(face.identifier) mide \(frame.width) pt de ancho, no \(Self.expectedWidth)"
            )
            // Lo que separa una banda de una viñeta: el alto lo pone la card, así
            // que tiene que ser MÁS alto que ancho. Un cuadrado acá significa que
            // volvió a ser un recuadro metido adentro.
            XCTAssertGreaterThan(
                frame.height, frame.width,
                "el retrato de \(face.identifier) volvió a ser una viñeta cuadrada: \(frame.width)×\(frame.height)"
            )
        }
        XCTAssertGreaterThanOrEqual(medidas, 3, "no se pudo medir ningún retrato: la fila no lo expone")

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
