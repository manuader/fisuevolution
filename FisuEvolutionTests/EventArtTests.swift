import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La ilustración del evento: póster y clip van de a pares")
@MainActor
struct EventArtTests {
    private func posterKey(_ id: String) -> String { "ui_event_\(id)" }

    @Test("cada evento con clip tiene su póster en el manifest y en el atlas")
    func everyClipHasItsPoster() throws {
        let loops = try LoopsManifest.load(from: .main)
        let content = try GameContentLoader.load(from: .main)
        let atlasNames = UIArt.bundledNames()
        #expect(!loops.events.isEmpty)
        for id in loops.events.keys {
            #expect(content.manifest.ui[posterKey(id)] != nil, "\(id): clip sin póster en assets_manifest")
            #expect(atlasNames.contains(posterKey(id)), "\(id): clip sin póster en el atlas")
            #expect(UIArt.image(posterKey(id)) != nil, "\(id): el atlas no lo carga")
        }
    }

    @Test("ningún póster de evento queda sin clip")
    func noPosterWithoutClip() throws {
        let loops = try LoopsManifest.load(from: .main)
        let content = try GameContentLoader.load(from: .main)
        let posters = Set(content.manifest.ui.keys.filter { $0.hasPrefix("ui_event_") })
        #expect(posters == Set(loops.events.keys.map(posterKey)))
    }

    @Test("la ilustración existe para los ocho eventos con clip y para ninguno de los otros")
    func illustrationOnlyWhereThereIsAClip() throws {
        let loops = try LoopsManifest.load(from: .main)
        let content = try GameContentLoader.load(from: .main)
        for event in content.events.events {
            let illustrated = EventPopupView.illustrationClip(for: event.id, in: loops) != nil
            #expect(illustrated == (loops.events[event.id] != nil), "\(event.id)")
        }
        #expect(EventPopupView.illustrationClip(for: "aguinaldo", in: loops) == .event("aguinaldo"))
    }
}
