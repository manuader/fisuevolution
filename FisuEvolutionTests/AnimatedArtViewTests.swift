import Testing
import UIKit
@testable import FisuEvolution

@Suite("AnimatedArtView: póster siempre, video si se puede")
@MainActor
struct AnimatedArtViewTests {
    private func window(with layer: UIView) -> UIWindow {
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 200, height: 200))
        window.addSubview(layer)
        return window
    }

    @Test("sin entrada, póster; con entrada, video")
    func resolve() {
        #expect(AnimatedArt.resolve(.portrait("npc_x"), manifest: .main) == nil)
        #expect(AnimatedArt.resolve(.portrait("npc_vecina"), manifest: .main) != nil)
    }

    @Test("la capa no crea player hasta que el pool la pone viva, y lo suelta al bajarla")
    func playerFollowsTheLease() throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let url = try #require(LoopsManifest.main.url(for: .portrait("npc_vecina")))
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .loop, pool: pool)
        #expect(layer.player == nil, "el init no decodifica")
        let window = window(with: layer)
        #expect(layer.player != nil)
        #expect(!layer.isOpaque, "con true el alfa sale negro")
        #expect(layer.videoAlpha == 0, "transparente hasta el primer cuadro")
        layer.removeFromSuperview()
        #expect(layer.player == nil && pool.liveCount == 0)
        _ = window
    }

    @Test("con la política apagada no hay player y `.once` termina en el acto")
    func stillPolicy() throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let url = try #require(LoopsManifest.main.url(for: .object("paquete_abre")))
        var ended = false
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .once { ended = true }, pool: pool)
        let window = window(with: layer)
        #expect(layer.player == nil)
        #expect(ended, "Reduce Motion muestra el cuadro final: quien lo usa dibuja el estado de después")
        _ = window
    }

    @Test("el primer cuadro llega y la capa funde (simulador: con tope generoso)")
    func fadesInWhenReady() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let url = try #require(LoopsManifest.main.url(for: .portrait("npc_vecina")))
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .loop, pool: pool)
        let window = window(with: layer)
        try await layer.waitUntilVisible(timeout: .seconds(5))
        #expect(layer.videoAlpha == 1)
        _ = window
    }
}
