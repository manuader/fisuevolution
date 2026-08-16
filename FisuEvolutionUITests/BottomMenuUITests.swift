import XCTest

/// La barra inferior de 6 pantallas (spec §4): los seis tabs existen, cada uno
/// abre SU hoja y todas se cierran con `sheet.close`.
///
/// ⚠️ Cada tab se comprueba con un identifier que **sólo vive dentro de su
/// pantalla**, y no sólo con `sheet.close`: con el botón de cerrar alcanza para
/// saber que se abrió *algo*, que es justo lo que no se quiere saber cuando se
/// prueba una barra de seis destinos. Si dos tabs abrieran la misma hoja
/// —cablear mal el `switch` del `.sheet(item:)` cuesta un renglón— un test que
/// mire `sheet.close` pasaría igual.
///
/// ⚠️ Todo va por identifier: el runner corre la app en INGLÉS aunque el idioma
/// de desarrollo sea `es` (trampa 6 del HANDOFF).
final class BottomMenuUITests: XCTestCase {
    /// El tab y lo que tiene que aparecer adentro. El orden es el de la barra.
    private static let destinations: [(tab: String, inside: [String])] = [
        ("hud.hire", ["jobs.hire.homeless"]),
        ("hud.upgrades", ["upgrades.tab.permanent"]),
        // Pintas abre siempre con la grilla del primer personaje visto, y la
        // apariencia original es la primera tarjeta de cualquier personaje: la
        // fila `skins.row.base` existe en toda partida, también en una recién
        // empezada.
        ("hud.skins", ["skins.row.base"]),
        ("hud.bonus", ["bonus.activate.mate"]),
        // La tienda depende de StoreKit y su lista es perezosa: con los
        // productos cargados se ve la primera fila, mientras carga se ve el
        // botón de restaurar, y si la carga falla, el cartel de "no hay nada"
        // con su reintento. Los cuatro son ids exclusivos de `StoreView`, así
        // que cualquiera de ellos la discrimina de las otras cinco pantallas.
        ("hud.store", ["store.buy.com.fisuevolution.iap.starter_pack", "store.restore",
                       "store.unavailable", "store.retry"]),
        ("hud.settings", ["menu.placeholder"]),
    ]

    @MainActor
    func testCadaTabAbreSuPantallaYSeCierra() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()

        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20),
                      "la barra inferior nunca apareció")
        attach(app, named: "T7 la barra de 6 pantallas")

        for destination in Self.destinations {
            let tab = app.buttons[destination.tab]
            XCTAssertTrue(tab.exists, "falta el tab \(destination.tab) en la barra")
            // ⚠️ Se espera a que el tab sea TOCABLE y no sólo a que exista: la
            // hoja anterior sigue en el árbol de AX mientras se va deslizando, y
            // los tabs existen debajo de ella todo ese rato. Tocando por
            // existencia, el toque llega mientras la hoja saliente todavía tapa
            // la barra: XCUITest muere con "Failed to scroll to visible"
            // (trampa 4 — nunca es el botón, siempre es algo tapándolo) y, lo
            // peor, el toque que sí entra puede caer sobre el CONTENIDO de la
            // hoja en vuelo y contratar o activar algo que nadie pidió.
            XCTAssertTrue(waitUntilHittable(tab), "el tab \(destination.tab) nunca quedó tocable")
            tab.tap()

            let close = app.buttons["sheet.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10),
                          "\(destination.tab) no abrió ninguna hoja cerrable")
            attach(app, named: "T7 hoja de \(destination.tab)")

            XCTAssertTrue(
                waitForAny(destination.inside, in: app, timeout: 10),
                "\(destination.tab) abrió una hoja que no es la suya: no apareció ninguno de \(destination.inside)"
            )

            close.tap()
            XCTAssertTrue(waitUntilGone(close),
                          "la hoja de \(destination.tab) no se cerró: su botón de cerrar sigue ahí")
        }
    }

    /// Los dos extremos son los destacados (56 pt contra 48): es lo que hace que
    /// la barra se lea como la de Cow Evolution y no como seis botones iguales.
    /// Se mide sobre el frame REAL que reporta XCUITest, no sobre el arte.
    @MainActor
    func testLosExtremosSonMasGrandesQueElResto() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let jobs = app.buttons["hud.hire"]
        XCTAssertTrue(jobs.waitForExistence(timeout: 20))
        let menu = app.buttons["hud.settings"]
        let middle = ["hud.upgrades", "hud.skins", "hud.bonus", "hud.store"].map { app.buttons[$0] }

        attach(app, named: "T7 extremos destacados")

        for tab in middle {
            XCTAssertTrue(tab.exists)
            XCTAssertGreaterThan(jobs.frame.height, tab.frame.height,
                                 "FisuJobs tiene que ser más alto que \(tab.identifier)")
            XCTAssertGreaterThan(menu.frame.height, tab.frame.height,
                                 "el Menú tiene que ser más alto que \(tab.identifier)")
        }

        // Y la barra vive abajo de todo: si algún día se cuela arriba del
        // tablero, el ajuste de `BoardScene.bottomInset` deja de tener sentido.
        let screen = app.windows.element(boundBy: 0).frame
        XCTAssertGreaterThan(jobs.frame.minY, screen.height * 0.75,
                             "la barra tiene que estar pegada abajo, arrancó en \(jobs.frame.minY)")
    }

    /// Espera a que aparezca ALGUNO de los identifiers, mirando los tres tipos
    /// que usan las pantallas: botón (contratar, comprar, activar), texto de
    /// estado (los placeholders) y contenedor (el cartel de tienda vacía).
    ///
    /// ⚠️ Nada de `descendants(matching: .any)`: esa query obliga a XCUITest a
    /// snapshotear el árbol ENTERO de la app, y repetirla en un bucle cerrado
    /// diez segundos es una tormenta de peticiones de accesibilidad contra el
    /// main thread de la app. Las queries tipadas se resuelven contra su
    /// subárbol, y la pausa entre rondas deja respirar al que está probando.
    @MainActor
    private func waitForAny(_ identifiers: [String], in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for identifier in identifiers
            where app.buttons[identifier].exists
                || app.staticTexts[identifier].exists
                || app.otherElements[identifier].exists {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return false
    }

    /// Tocable de verdad: existe, está en pantalla y nada lo tapa.
    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: element
        )
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }

    /// La hoja se fue del todo (no sólo empezó a irse).
    @MainActor
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: element
        )
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
