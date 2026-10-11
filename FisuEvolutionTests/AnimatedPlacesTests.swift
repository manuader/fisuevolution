import Foundation
import Testing
@testable import FisuEvolution

/// El barrido de lugares: toda sección llena de `loops_manifest.json` tiene que tener quien la
/// pida. Un video en el bundle que ninguna vista reproduce pesa y no se ve.
///
/// Cuenta como call site el texto del caso de `ArtClip` (`.portrait(`, `.floor(`…) o el helper de
/// `ArtClips` que lo arma, buscado en `FisuEvolution/` salvo las definiciones y el código DEBUG.
/// El caso tiene que arrancar una expresión: `defaults.object(forKey:)` no es `.object(`.
@Suite struct AnimatedPlacesTests {
    /// Cómo se pide cada sección; una sección nueva del manifest sin entrada acá es rojo.
    private static let requests: [String: [String]] = [
        "portraits": [".portrait("],
        "objects": [".object("],
        "cabin": ["\"cabina_puertas_"],
        "cinematics": [".cinematic(", "cinematicURL(for:"],
        "characters": [".character(", "ArtClips.character("],
        "talking": ["ArtClips.stageVisitor("],
        "visitorActions": ["ArtClips.stageVisitor("],
        "events": ["ArtClips.event("],
        "shopIcons": [".shopIcon(", "ArtClips.shopIcon("],
        "floors": [".floor("],
    ]

    /// Secciones llenas que todavía nadie pide, con la tarea que las cablea. Al cablearse, la tarea
    /// la saca de acá (el test falla si queda).
    private static let pendingPlaces: [String: String] = [
        "shopIcons": "E8e T4 (OroShopView); ui_oro_extra_slots, además, E6b T7",
    ]

    private static let definitions: Set<String> = ["ArtClips.swift", "LoopsManifest.swift"]

    private static var repo: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func sources() throws -> String {
        let root = repo.appendingPathComponent("FisuEvolution")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []
        return try files
            .filter { $0.pathExtension == "swift" && !definitions.contains($0.lastPathComponent) }
            .filter { !$0.pathComponents.contains("Debug") }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    /// El token cuenta si no cuelga de un identificador: `defaults.object(` no es el caso `.object(`.
    private static func isRequested(_ token: String, in sources: String) -> Bool {
        var cursor = sources.startIndex
        while let hit = sources.range(of: token, range: cursor..<sources.endIndex) {
            guard token.hasPrefix("."), hit.lowerBound > sources.startIndex else { return true }
            let previous = sources[sources.index(before: hit.lowerBound)]
            if !(previous.isLetter || previous.isNumber || previous == "_" || previous == ")" || previous == "]") {
                return true
            }
            cursor = hit.upperBound
        }
        return false
    }

    private static func filledSections() throws -> [String] {
        let url = repo.appendingPathComponent("FisuEvolution/Resources/Data/loops_manifest.json")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
        return json.compactMap { key, value in (value as? [String: Any])?.isEmpty == false ? key : nil }.sorted()
    }

    @Test("toda sección del manifest con entradas tiene quien la pida, o un dueño pendiente")
    func everyFilledSectionIsRequested() throws {
        let sources = try Self.sources()
        let sections = try Self.filledSections()
        let unknown = sections.filter { Self.requests[$0] == nil }
        #expect(unknown.isEmpty, "secciones nuevas sin regla de búsqueda: \(unknown)")
        let orphans = sections.filter { section in
            guard let tokens = Self.requests[section], Self.pendingPlaces[section] == nil else { return false }
            return !tokens.contains { Self.isRequested($0, in: sources) }
        }
        #expect(orphans.isEmpty, "secciones llenas que nadie pide: \(orphans)")
    }

    @Test("lo pendiente sigue sin call site y sigue lleno: cableado, sale de la lista")
    func pendingPlacesAreStillPending() throws {
        let sources = try Self.sources()
        let sections = try Self.filledSections()
        for (section, owner) in Self.pendingPlaces {
            #expect(sections.contains(section), "\(section) ya no tiene entradas: sacalo de pendingPlaces (\(owner))")
            let wired = Self.requests[section, default: []].contains { Self.isRequested($0, in: sources) }
            #expect(!wired, "\(section) ya tiene quien lo pida: sacalo de pendingPlaces (\(owner))")
        }
    }
}
