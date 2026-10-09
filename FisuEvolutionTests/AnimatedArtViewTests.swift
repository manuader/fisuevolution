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

    @Test("con el pack sin bajar, póster; cuando llega, la vista resuelve la URL")
    func resolvesWhenThePackArrives() async throws {
        let source = FakeArtPackSource()
        let packs = ArtPacks(source: source)
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"], odrTag: "anim-piso-1")
        #expect(AnimatedArt.resolve(.floor("urban"), manifest: manifest, packs: packs) == nil)
        packs.request("anim-piso-1")
        for _ in 0..<5 { await Task.yield() }
        source.last?.complete()
        for _ in 0..<5 { await Task.yield() }
        #expect(AnimatedArt.resolve(.floor("urban"), manifest: manifest, packs: packs) != nil)
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

    @Test("un `.once` vivo: suspender lo termina una vez y reanudar no lo revive")
    func onceDoesNotReplay() throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let url = try #require(LoopsManifest.main.url(for: .object("paquete_abre")))
        var ends = 0
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .once { ends += 1 }, pool: pool)
        let window = window(with: layer)
        #expect(layer.player != nil)
        let suspension = pool.suspend(.overlay)
        #expect(layer.player == nil && ends == 1)
        pool.resume(suspension)
        #expect(layer.player == nil && ends == 1)
        _ = window
    }

    @Test("desmontar un `.once` vivo no es terminarlo")
    func dismantleIsNotEnd() throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let url = try #require(LoopsManifest.main.url(for: .object("paquete_abre")))
        var ends = 0
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .once { ends += 1 }, pool: pool)
        let window = window(with: layer)
        layer.removeFromSuperview()
        #expect(ends == 0)
        _ = window
    }

    @Test("un segundo popup desplaza al primero")
    func newerPopupWins() throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let url = try #require(LoopsManifest.main.url(for: .portrait("npc_vecina")))
        let first = ArtVideoUIView(url: url, role: .popup, playback: .loop, pool: pool)
        let second = ArtVideoUIView(url: url, role: .popup, playback: .loop, pool: pool)
        let w1 = window(with: first)
        let w2 = window(with: second)
        #expect(first.player == nil && second.player != nil)
        _ = (w1, w2)
    }

    @Test("un `.loop` con la política apagada espera, y arranca cuando se enciende")
    func loopWaitsForPolicy() throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.lowPower))
        let url = try #require(LoopsManifest.main.url(for: .portrait("npc_vecina")))
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .loop, pool: pool)
        let window = window(with: layer)
        #expect(layer.player == nil)
        pool.update(policy: .allowAll)
        #expect(layer.player != nil)
        _ = window
    }

    @Test("el player arranca reproduciendo")
    func playerPlays() throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let url = try #require(LoopsManifest.main.url(for: .portrait("npc_vecina")))
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .loop, pool: pool)
        let window = window(with: layer)
        #expect(layer.player?.rate != 0 || layer.player?.timeControlStatus != .paused)
        _ = window
    }
}
