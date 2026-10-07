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
        write(payload, stampedBy: "save-", now: now)
        for stale in names(withPrefix: "save-").sorted(by: >).dropFirst(Self.keptRotating) {
            try? FileManager.default.removeItem(at: directory.appending(path: stale))
        }
    }

    func keepPremigration(_ payload: Data, version: Int) {
        let name = "save_v\(version)_premigration.json"
        guard !FileManager.default.fileExists(atPath: directory.appending(path: name).path()) else { return }
        write(payload, named: name)
    }

    /// Un save ilegible que ya tiene copia (los mismos bytes) no suma otra: devuelve la que hay.
    @discardableResult
    func keepUnreadable(_ payload: Data, now: Date = Date()) -> URL? {
        let kept = names(withPrefix: "unreadable-")
            .map { directory.appending(path: $0) }
            .first { (try? Data(contentsOf: $0)) == payload }
        return kept ?? write(payload, stampedBy: "unreadable-", now: now)
    }

    /// El nombre lleva los milisegundos con ancho fijo, así el orden alfabético es el
    /// cronológico. La copia nueva se estampa siempre después de todas las que hay (con el
    /// reloj quieto o atrasado se corre al milisegundo siguiente): nunca pisa a otra ni
    /// queda como la más vieja de la rotación.
    @discardableResult
    private func write(_ payload: Data, stampedBy prefix: String, now: Date) -> URL? {
        let latest = names(withPrefix: prefix).compactMap { Self.millis(in: $0, prefix: prefix) }.max()
        let millis = max(Int((now.timeIntervalSince1970 * 1000).rounded()), (latest ?? -1) + 1)
        return write(payload, named: "\(prefix)\(String(format: "%015ld", millis)).json")
    }

    private func names(withPrefix prefix: String) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path())) ?? []
        return names.filter { $0.hasPrefix(prefix) }
    }

    private static func millis(in name: String, prefix: String) -> Int? {
        Int(name.dropFirst(prefix.count).prefix { $0.isNumber })
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
}
