import Foundation

/// Las copias crudas del save en `Application Support/SaveBackups/`: una por cada
/// carga buena (quedan las últimas diez), la foto de antes de cada migración y
/// los saves que no se pudieron leer. Ninguna se borra al empezar de nuevo.
struct SaveBackupStore: Sendable {
    static let keptRotating = 10

    let directory: URL

    static func defaultDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "SaveBackups")
    }

    func rotate(_ payload: Data, now: Date = Date()) {
        write(payload, named: "save-\(Self.stamp(now)).json")
        let copies = (try? FileManager.default.contentsOfDirectory(atPath: directory.path())) ?? []
        for stale in copies.filter({ $0.hasPrefix("save-") }).sorted(by: >).dropFirst(Self.keptRotating) {
            try? FileManager.default.removeItem(at: directory.appending(path: stale))
        }
    }

    func keepPremigration(_ payload: Data, version: Int) {
        let name = "save_v\(version)_premigration.json"
        guard !FileManager.default.fileExists(atPath: directory.appending(path: name).path()) else { return }
        write(payload, named: name)
    }

    @discardableResult
    func keepUnreadable(_ payload: Data, now: Date = Date()) -> URL? {
        write(payload, named: "unreadable-\(Self.stamp(now)).json")
    }

    @discardableResult
    private func write(_ payload: Data, named name: String) -> URL? {
        let url = directory.appending(path: name)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try payload.write(to: url, options: .atomic)
            return url
        } catch {
            Log.persistence.error("save backup failed (\(name)): \(error)")
            return nil
        }
    }

    /// Milisegundos con ancho fijo: el orden alfabético es el cronológico.
    private static func stamp(_ date: Date) -> String {
        String(format: "%015.0f", date.timeIntervalSince1970 * 1000)
    }
}
