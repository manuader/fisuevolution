import Foundation

extension UserDefaults {
    private static let isolatedPrefix = "test.flags."

    /// Barre una vez por proceso los dominios que dejó la corrida anterior: cada test usa uno
    /// propio y ninguno sabe cuándo termina el `GameState` que lo usa, así que la limpieza va
    /// al empezar y los plists del host no se acumulan más allá de una corrida.
    private static let sweptPreviousRuns: Void = {
        let fileManager = FileManager.default
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let preferences = library.appending(path: "Preferences")
        let files = (try? fileManager.contentsOfDirectory(atPath: preferences.path())) ?? []
        for file in files where file.hasPrefix(isolatedPrefix) && file.hasSuffix(".plist") {
            let name = String(file.dropLast(".plist".count))
            UserDefaults.standard.removePersistentDomain(forName: name)
            try? fileManager.removeItem(at: preferences.appending(path: file))
        }
    }()

    /// Un dominio propio y vacío por test. Las banderas de la partida (`TutorialFlags`,
    /// `tabs.new`) van a `GameState.flagDefaults`: con éste, cerrar el núcleo en un test no le
    /// deja `tutorial.v2.completed` al host, y ningún test depende del orden en que corre.
    static func isolatedForTest() -> UserDefaults {
        _ = sweptPreviousRuns
        let name = isolatedPrefix + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("no se pudo crear el dominio \(name)")
        }
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
