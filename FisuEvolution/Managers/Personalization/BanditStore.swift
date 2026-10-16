import EconomyKit
import Foundation

/// Lo que el bandido de los momentos aprendió en este teléfono (2.1 E15 F3 T7): por brazo, los aciertos y
/// los fallos que se suman a los priors `α`/`β` de la config. Vale para una sola `version` de la sección
/// `moments`: con otra, se arranca de nuevo desde los priors.
struct BanditRecord: Codable, Sendable, Equatable {
    struct Tally: Codable, Sendable, Equatable {
        var successes = 0
        var failures = 0
    }

    /// La `version` de `moments` sobre la que se aprendió.
    var version: String
    var tallies: [String: Tally] = [:]

    mutating func observe(arm id: String, success: Bool) {
        var tally = tallies[id] ?? Tally()
        if success {
            tally.successes += 1
        } else {
            tally.failures += 1
        }
        tallies[id] = tally
    }

    /// El bandido de la config con lo aprendido encima. Manda la config: un brazo que ya no trae no
    /// cuenta, y uno nuevo arranca en su prior.
    func bandit(over config: MomentsConfig) -> ThompsonBandit {
        ThompsonBandit(arms: config.bandit().arms.map { arm in
            guard let tally = tallies[arm.id] else { return arm }
            return BanditArm(id: arm.id, alpha: arm.alpha + Double(tally.successes),
                             beta: arm.beta + Double(tally.failures), isControl: arm.isControl)
        })
    }
}

/// `Application Support/bandit.json`, con escritura atómica, como `PersonalizationStore`. Un archivo que
/// no se puede leer, o de otra versión, es un registro vacío: vuelven los priors, nunca se traba.
struct BanditStore: Sendable {
    let url: URL

    init(url: URL = BanditStore.defaultURL) {
        self.url = url
    }

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "bandit.json")
    }

    /// El de la app; con el host de los tests unitarios, uno temporal por proceso: los tests no aprenden
    /// sobre el bandido del simulador ni heredan lo de una corrida anterior.
    static func standard(environment: [String: String] = ProcessInfo.processInfo.environment) -> BanditStore {
        guard environment["XCTestConfigurationFilePath"] != nil else { return BanditStore() }
        return BanditStore(url: FileManager.default.temporaryDirectory
            .appending(path: "bandit-\(ProcessInfo.processInfo.processIdentifier)").appending(path: "bandit.json"))
    }

    func load(version: String) -> BanditRecord {
        guard let data = try? Data(contentsOf: url),
              let record = try? JSONDecoder().decode(BanditRecord.self, from: data),
              record.version == version else { return BanditRecord(version: version) }
        return record
    }

    func save(_ record: BanditRecord) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(record) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
