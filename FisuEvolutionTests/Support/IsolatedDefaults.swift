import Foundation

extension UserDefaults {
    /// Un dominio propio y vacío por test. Las banderas de la partida (`TutorialFlags`,
    /// `tabs.new`) van a `GameState.flagDefaults`: con éste, cerrar el núcleo en un test no le
    /// deja `tutorial.v2.completed` al host, y ningún test depende del orden en que corre.
    static func isolatedForTest() -> UserDefaults {
        let name = "test.flags.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("no se pudo crear el dominio \(name)")
        }
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
