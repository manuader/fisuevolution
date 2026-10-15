import Foundation
import Testing
@testable import FisuEvolution

/// El mapa de ubicaciones de PLAN-v2 E7: qué lugar del juego ofrece videos de
/// qué unidad de AdMob. AdMob reporta por unidad, así que este mapa es lo que
/// el dueño lee en el panel. Un lugar nuevo sin fila acá, o con otra unidad,
/// pone esto en rojo.
@Suite("El mapa de ubicaciones de video")
struct AdPlacementMapTests {
    /// Rutas desde `FisuEvolution/`.
    static let map: [String: Set<RewardedPlacement>] = [
        "UI/Gifts/GiftsView.swift": [.gifts, .boost],
        "UI/Popups/ChestOpeningView.swift": [.chestExtra],
        // El paso 2 de las recompensas gratis (E14b B29): cada fuente cuenta en su unidad.
        "Game/State/GameState+RewardDouble.swift": [.visitor, .offlineX2, .daily, .wheel, .treasure, .gifts],
        "UI/SideRail/SideRailOfferCard.swift": [.boost, .treasure],
        "UI/Wheel/WheelView.swift": [.wheel],
        "UI/Prizes/MattressPopupView.swift": [.treasure],
        "UI/Visitors/VisitorPopupView.swift": [.visitor],
        "UI/Visitors/VendorCardsView.swift": [.visitor],
        "UI/Events/EventPopupView.swift": [.visitor],
    ]

    private static let usage = try! NSRegularExpression(
        pattern: #"(?:placement:\s*|showRewarded\(for:\s*|preloadRewarded\(for:\s*|isRewardedReady\(for:\s*)\.([A-Za-z0-9]+)"#
    )

    private static var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "FisuEvolution")
    }

    static func placements(in source: String) -> Set<RewardedPlacement> {
        let range = NSRange(source.startIndex..., in: source)
        return Set(usage.matches(in: source, range: range).compactMap { match in
            Range(match.range(at: 1), in: source).flatMap { RewardedPlacement(rawValue: String(source[$0])) }
        })
    }

    @Test("cada lugar ofrece videos de su unidad, y no hay lugares fuera del mapa")
    func everyOfferUsesItsUnit() throws {
        let root = Self.appRoot
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        var found: [String: Set<RewardedPlacement>] = [:]
        for file in files {
            let path = String(file.path.dropFirst(root.path.count + 1))
            // La costura misma (proveedor, coordinador, flags) habla de unidades
            // en general; no es un lugar del juego.
            guard !path.hasPrefix("Managers/Ads/"), path != "Managers/FeatureFlags.swift" else { continue }
            let used = Self.placements(in: try String(contentsOf: file, encoding: .utf8))
            if !used.isEmpty { found[path] = used }
        }
        #expect(found == Self.map)
    }

    @Test("toda unidad de video tiene al menos un lugar")
    func everyUnitHasAPlace() {
        #expect(Set(Self.map.values.flatMap { $0 }) == Set(RewardedPlacement.allCases))
    }

    @Test("el botón sondea rápido al principio y después espaciado")
    func pollInterval() {
        #expect(RewardedOfferButton.pollInterval(attempt: 0) == .milliseconds(250))
        #expect(RewardedOfferButton.pollInterval(attempt: 19) == .milliseconds(250))
        #expect(RewardedOfferButton.pollInterval(attempt: 20) == .seconds(2))
    }
}
