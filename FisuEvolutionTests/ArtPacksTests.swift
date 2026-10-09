import Foundation
import Testing
@testable import FisuEvolution

@MainActor
final class FakeArtPackRequest: ArtPackRequest {
    private var continuation: CheckedContinuation<Void, Error>?
    private(set) var urgent: Bool?
    private(set) var ended = false

    func load(urgent: Bool) async throws {
        self.urgent = urgent
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func end() { ended = true }

    func complete() { continuation?.resume(); continuation = nil }
    func fail() { continuation?.resume(throwing: CocoaError(.fileReadUnknown)); continuation = nil }
}

@MainActor
final class FakeArtPackSource: ArtPackSource {
    private(set) var made: [(tag: String, request: FakeArtPackRequest)] = []

    func makeRequest(tag: String) -> any ArtPackRequest {
        let request = FakeArtPackRequest()
        made.append((tag, request))
        return request
    }

    var last: FakeArtPackRequest? { made.last?.request }
}

@Suite("ArtPacks: los packs ODR, el pedido y el aviso")
@MainActor
struct ArtPacksTests {
    private func settle() async {
        for _ in 0..<5 { await Task.yield() }
    }

    @Test("un tag sin bajar no tiene URL y deja un pedido; al terminar hay URL y avisa una vez")
    func requestThenArrives() async throws {
        let source = FakeArtPackSource()
        let packs = ArtPacks(source: source)
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"], odrTag: "anim-piso-1")
        #expect(manifest.url(for: .floor("urban"), packs: packs) == nil)
        packs.request("anim-piso-1")
        #expect(packs.isRequested("anim-piso-1") && source.made.count == 1)
        var arrivals = 0
        packs.whenAvailable("anim-piso-1") { arrivals += 1 }
        await settle()
        source.last?.complete()
        await settle()
        #expect(manifest.url(for: .floor("urban"), packs: packs) != nil)
        #expect(arrivals == 1 && !packs.isRequested("anim-piso-1"))
    }

    @Test("dos pedidos del mismo tag comparten el request, y el pack se suelta con el último release")
    func sharedUntilLastRelease() async {
        let source = FakeArtPackSource()
        let packs = ArtPacks(source: source)
        packs.request("anim-tienda")
        packs.request("anim-tienda")
        #expect(source.made.count == 1)
        await settle()
        source.last?.complete()
        await settle()
        packs.release("anim-tienda")
        #expect(packs.isReady("anim-tienda") && source.last?.ended == false)
        packs.release("anim-tienda")
        #expect(!packs.isReady("anim-tienda") && source.last?.ended == true)
    }

    @Test("un error de red sigue en póster, sin reintento en lazo; el próximo pedido reintenta")
    func failureDoesNotLoop() async throws {
        let source = FakeArtPackSource()
        let packs = ArtPacks(source: source)
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"], odrTag: "anim-piso-1")
        packs.request("anim-piso-1")
        await settle()
        source.last?.fail()
        await settle()
        #expect(source.made.count == 1, "no reintenta solo")
        #expect(!packs.isRequested("anim-piso-1") && manifest.url(for: .floor("urban"), packs: packs) == nil)
        packs.request("anim-piso-1")
        #expect(source.made.count == 2 && packs.isRequested("anim-piso-1"))
    }

    @Test("sin odrTag no pasa por ArtPacks")
    func baseBundleSkipsPacks() throws {
        let source = FakeArtPackSource()
        let packs = ArtPacks(source: source)
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"])
        #expect(manifest.odrTag(for: .floor("urban")) == nil)
        #expect(manifest.url(for: .floor("urban"), packs: packs) != nil)
        #expect(source.made.isEmpty)
    }

    @Test("el prefetch pide con prioridad baja y lo que está en pantalla, urgente")
    func priorities() async {
        let source = FakeArtPackSource()
        let packs = ArtPacks(source: source)
        packs.prefetch("anim-piso-2")
        packs.request("anim-tienda")
        await settle()
        #expect(source.made[0].request.urgent == false && source.made[1].request.urgent == true)
    }

    @Test("soltar un pedido en vuelo lo termina, y su fin tardío no marca el pack como listo")
    func releaseWhilePending() async {
        let source = FakeArtPackSource()
        let packs = ArtPacks(source: source)
        packs.request("anim-piso-1")
        await settle()
        packs.release("anim-piso-1")
        #expect(source.last?.ended == true)
        source.last?.complete()
        await settle()
        #expect(!packs.isReady("anim-piso-1"))
    }
}
