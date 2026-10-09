import Foundation
import Testing
@testable import FisuEvolution

/// Las duraciones del ranking y las claves de la tarjeta de Dios. Los bundles de cada idioma se abren
/// a mano porque `Bundle.main` sólo responde en el idioma del runner (inglés, trampa 6).
@Suite("Textos del ranking")
struct RankingCopyTests {
    private func languageBundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test("las duraciones de borde", arguments: [
        (0, "0 min"), (59, "0 min"), (60, "1 min"), (3_599, "59 min"), (3_600, "1 h 0 min"),
        (115_999, "32 h 13 min"), (116_040, "32 h 14 min"), (259_199, "71 h 59 min"),
        (259_200, "3 d 0 h"), (273_600, "3 d 4 h"), (-5, "0 min")
    ] as [(Int, String)])
    func durationEdges(seconds: Int, expected: String) throws {
        let es = try languageBundle("es")
        #expect(RankingCopy.duration(seconds, bundle: es, locale: Locale(identifier: "es_AR")) == expected)
    }

    @Test("las duraciones no cambian entre idiomas", arguments: ["es", "en"])
    func durationsAreTheSameInBothLanguages(language: String) throws {
        let bundle = try languageBundle(language)
        #expect(RankingCopy.duration(116_040, bundle: bundle, locale: Locale(identifier: language)) == "32 h 14 min")
    }

    static let entryKeys = [
        "ranking.duration.hm", "ranking.duration.m", "ranking.duration.dh",
        "ranking.entry.title", "ranking.entry.title.unsealed", "ranking.entry.review", "ranking.entry.prompt",
        "ranking.entry.placeholder", "ranking.entry.submit", "ranking.entry.later", "ranking.entry.rejected",
        "ranking.entry.offline", "ranking.entry.error.empty", "ranking.entry.error.too_long",
        "ranking.entry.error.forbidden", "ranking.entry.counter.ax", "ranking.entry.name.ax"
    ]

    @Test("la tarjeta de Dios existe en es y en", arguments: ["es", "en"])
    func entryKeysExist(language: String) throws {
        let bundle = try languageBundle(language)
        for key in Self.entryKeys {
            #expect(bundle.localizedString(forKey: key, value: "<falta>", table: nil) != "<falta>",
                    "\(key): sin texto en \(language)")
        }
    }

    @Test("el título lleva la duración interpolada", arguments: ["es", "en"])
    func titleInterpolatesTheDuration(language: String) throws {
        let bundle = try languageBundle(language)
        let title = String(format: RankingCopy.text("ranking.entry.title", bundle), "32 h 14 min")
        #expect(title.contains("32 h 14 min"))
        #expect(!title.contains("%"))
    }
}
