import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El catálogo de notificaciones que viaja en el bundle (PLAN-v2 E11).
@Suite("Notificaciones: el catálogo del bundle")
struct NotificationsContentTests {
    let config: NotificationsConfig

    init() throws {
        config = try GameContentLoader.load(from: .main).notifications
    }

    @Test("los tres motivos de la 2.0, en su orden de prioridad")
    func catalogOrder() {
        #expect(config.kinds == [.vaultFull, .dailyReady, .comeback])
    }

    @Test("las reglas de PLAN-v2 E11, pineadas")
    func rules() {
        #expect(config.quietHours == NotificationsConfig.QuietHours(startHour: 22, endHour: 9))
        #expect(config.minSpacingHours == 4)
        #expect(config.maxPerAbsence == 3)
        #expect(config.dailyReadyHour == 19)
        #expect(config.comebackAfterHours == 72)
        #expect(config.permissionCard == NotificationsConfig.PermissionCard(maxOffers: 2, retryAfterHours: 72))
    }

    /// El rechazo de ids desconocidos vive en `validate()`: si el arranque no lo
    /// llamara, `kinds` descartaría el motivo en silencio y su aviso no sonaría nunca.
    @Test("el arranque rechaza un catálogo con un motivo que el código no conoce")
    func loaderRejectsAnUnknownKind() throws {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory.appending(path: "e11-\(UUID().uuidString).bundle")
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: bundleURL) }
        for url in Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [] {
            try fileManager.copyItem(at: url, to: bundleURL.appending(path: url.lastPathComponent))
        }
        let catalogURL = bundleURL.appending(path: "notifications.json")
        var catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        catalog["notifications"] = (catalog["notifications"] as? [[String: String]] ?? []) + [["id": "mystery"]]
        try JSONSerialization.data(withJSONObject: catalog).write(to: catalogURL)
        let bundle = try #require(Bundle(url: bundleURL))

        #expect {
            _ = try GameContentLoader.load(from: bundle)
        } throws: { error in
            guard case .contentInvalid(let file, let reason)? = error as? GameError else { return false }
            return file == "notifications.json" && reason.contains("mystery")
        }
    }

    /// Guía 4.5.4 de App Store: una notificación no puede promocionar. Sólo
    /// cuenta el estado del juego.
    @Test("ningún aviso habla de anuncios, ofertas ni precios")
    func copyNeverSells() throws {
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        for kind in config.kinds {
            for key in [kind.titleKey, kind.bodyKey] {
                let values = LocalizationCompletenessTests.languages.flatMap { language in
                    catalog.strings[key]?.localizations?[language]?.units.map(\.value) ?? []
                }
                #expect(!values.isEmpty, "\(key) no tiene texto")
                for value in values {
                    let lowered = value.lowercased()
                    let hits = Self.promotional.filter { lowered.contains($0) }
                    #expect(hits.isEmpty, "\(key): «\(value)» habla de \(hits)")
                }
            }
        }
    }

    private static let promotional = [
        "oferta", "offer", "precio", "price", "gratis", "free", "descuento", "discount",
        "anuncio", "video", "compr", "buy", "purchase", "$", "usd",
    ]
}
