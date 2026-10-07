import Foundation
import Testing
@testable import FisuEvolution

/// El contrato del Info.plist COMPILADO (PLAN-v2 E3, iPad): universal, vertical,
/// de pantalla completa, iOS 18 y la pantalla de lanzamiento crema.
///
/// Lee el `Info.plist` del bundle —el host de los unit tests es la app— y no
/// `project.yml`: la trampa de siempre de este repo es una clave puesta como
/// build setting que no llega al Info.plist (ver `UIStatusBarHidden` en
/// `project.yml`).
///
/// Lo lee del ARCHIVO y no de `Bundle.infoDictionary`: éste colapsa las claves
/// `~ipad` / `~iphone` según el idioma del dispositivo, así que en el simulador
/// iPhone `UISupportedInterfaceOrientations~ipad` no existe y el test dependería
/// del host.
@Suite("El contrato del Info.plist")
struct InfoPlistContractTests {
    private var info: [String: Any] {
        let url = Bundle.main.bundleURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }

    @Test("la app es universal: iPhone y iPad")
    func universal() {
        #expect(info["UIDeviceFamily"] as? [Int] == [1, 2])
    }

    @Test("sólo vertical, en iPhone y en iPad")
    func portraitOnly() {
        #expect(info["UISupportedInterfaceOrientations"] as? [String] == ["UIInterfaceOrientationPortrait"])
        #expect(info["UISupportedInterfaceOrientations~ipad"] as? [String] == ["UIInterfaceOrientationPortrait"])
    }

    /// Sin esta clave, Apple pide las cuatro orientaciones a toda app con iPad
    /// (error 90474 en Validate) y el tablero sólo funciona vertical.
    @Test("de pantalla completa: no participa del multitasking del iPad")
    func requiresFullScreen() {
        #expect(info["UIRequiresFullScreen"] as? Bool == true)
    }

    @Test("iOS 18 como mínimo")
    func minimumOS() {
        #expect(info["MinimumOSVersion"] as? String == "18.0")
    }

    @Test("la pantalla de lanzamiento es crema, no blanca")
    func creamLaunchScreen() {
        let launch = info["UILaunchScreen"] as? [String: Any]
        #expect(launch?["UIColorName"] as? String == "PaletteCream")
    }

    /// ⚠️ **Rojo a propósito el día que se compile con el SDK de iOS 27.** Ese SDK
    /// ignora `UIRequiresFullScreen`: vuelve el error 90474 y la app pasa a poder
    /// vivir en ventanas de cualquier tamaño. Antes de subir de SDK hay que
    /// decidir (landscape, "sólo iPhone" o ventanas) y recién ahí tocar este test.
    @Test("el SDK con el que se compila todavía respeta UIRequiresFullScreen")
    func theSDKStillHonorsFullScreen() throws {
        let sdk = try #require(info["DTSDKName"] as? String, "el Info.plist compilado no trae DTSDKName")
        let digits = sdk.drop { !$0.isNumber }.prefix { $0.isNumber }
        let major = try #require(Int(digits), "no entiendo el SDK \(sdk)")
        #expect(major < 27, "SDK \(sdk): UIRequiresFullScreen ya no rige — ver PLAN-v2 §2, iPad")
    }
}
