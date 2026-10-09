import Foundation
import SwiftUI

/// Las cinemáticas a pantalla completa, por el id con el que las registra `video_assets.py`.
enum CinematicID: String, CaseIterable, Sendable {
    case intro
    case reencarnacion
    case arresto
    case dios

    /// Cuántas veces por cuenta; `nil` = cada vez.
    var maxPlays: Int? {
        switch self {
        case .reencarnacion: nil
        case .arresto: 2
        case .intro, .dios: 1
        }
    }
}

/// Una pieza animada, por sección del manifest y su id.
enum ArtClip: Hashable, Sendable {
    case portrait(String)
    case object(String)
    case character(String)
    case talking(String)
    case visitorAction(String)
    case event(String)
    case shopIcon(String)
    case floor(String)
    case cinematic(CinematicID)
}

/// `loops_manifest.json`: lo escribe `video_assets.py`; acá sólo se lee. Una pieza sin entrada,
/// o con entrada y sin archivo, no se reproduce: quien la dibuja muestra su póster.
struct LoopsManifest: Decodable, Sendable, Equatable {
    struct Entry: Decodable, Sendable, Equatable {
        let file: String
        let width: Int
        let height: Int
        let fps: Double?
        let frames: Int?
        let alpha: Bool
        let audio: Bool
        let odrTag: String?
    }

    let schemaVersion: Int
    let portraits: [String: Entry]
    let objects: [String: Entry]
    let cabin: [String: Entry]
    let cinematics: [String: Entry]
    let characters: [String: Entry]
    let talking: [String: Entry]
    let visitorActions: [String: Entry]
    let events: [String: Entry]
    let shopIcons: [String: Entry]
    let floors: [String: Entry]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, portraits, objects, cabin, cinematics
        case characters, talking, visitorActions, events, shopIcons, floors
    }

    init(schemaVersion: Int = 1, portraits: [String: Entry] = [:], objects: [String: Entry] = [:],
         cabin: [String: Entry] = [:], cinematics: [String: Entry] = [:],
         characters: [String: Entry] = [:], talking: [String: Entry] = [:],
         visitorActions: [String: Entry] = [:], events: [String: Entry] = [:],
         shopIcons: [String: Entry] = [:], floors: [String: Entry] = [:]) {
        self.schemaVersion = schemaVersion
        self.portraits = portraits
        self.objects = objects
        self.cabin = cabin
        self.cinematics = cinematics
        self.characters = characters
        self.talking = talking
        self.visitorActions = visitorActions
        self.events = events
        self.shopIcons = shopIcons
        self.floors = floors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func section(_ key: CodingKeys) throws -> [String: Entry] {
            try container.decodeIfPresent([String: Entry].self, forKey: key) ?? [:]
        }
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            portraits: try section(.portraits), objects: try section(.objects),
            cabin: try section(.cabin), cinematics: try section(.cinematics),
            characters: try section(.characters), talking: try section(.talking),
            visitorActions: try section(.visitorActions), events: try section(.events),
            shopIcons: try section(.shopIcons), floors: try section(.floors))
    }

    static let empty = LoopsManifest()

    static func load(from bundle: Bundle) throws -> LoopsManifest {
        guard let url = bundle.url(forResource: "loops_manifest", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(LoopsManifest.self, from: Data(contentsOf: url))
    }

    /// El del bundle, leído una vez. Sin archivo o roto, vacío: nada depende de que haya videos.
    static let main: LoopsManifest = (try? load(from: .main)) ?? .empty

    /// El pack ODR que hay que bajar para esta pieza; `nil` si viaja en el paquete base.
    func odrTag(for clip: ArtClip) -> String? {
        entry(for: clip)?.odrTag
    }

    func entry(for clip: ArtClip) -> Entry? {
        switch clip {
        case .portrait(let id): portraits[id]
        case .object(let id): objects[id]
        case .character(let id): characters[id]
        case .talking(let id): talking[id]
        case .visitorAction(let id): visitorActions[id]
        case .event(let id): events[id]
        case .shopIcon(let id): shopIcons[id]
        case .floor(let id): floors[id]
        case .cinematic(let id): cinematics[id.rawValue]
        }
    }

    /// `nil` sin entrada, sin archivo o con el pack ODR todavía sin bajar. Xcode aplana los recursos:
    /// se busca por nombre.
    @MainActor
    func url(for clip: ArtClip, in bundle: Bundle = .main, packs: ArtPacks = .shared) -> URL? {
        guard let entry = entry(for: clip) else { return nil }
        if let tag = entry.odrTag, !packs.isReady(tag) { return nil }
        let file = entry.file as NSString
        return bundle.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension)
    }

    @MainActor
    func portraitURL(for id: String, in bundle: Bundle = .main) -> URL? {
        url(for: .portrait(id), in: bundle)
    }

    @MainActor
    func cinematicURL(for id: CinematicID, in bundle: Bundle = .main) -> URL? {
        url(for: .cinematic(id), in: bundle)
    }
}

extension EnvironmentValues {
    @Entry var loopsManifest: LoopsManifest = .main
}
