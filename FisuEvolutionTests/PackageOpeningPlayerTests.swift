import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("La apertura del Paquete de la Aduana")
@MainActor
struct PackageOpeningPlayerTests {
    private func run(_ player: PackageOpeningPlayer, seconds: TimeInterval, reduceMotion: Bool) {
        let step = 1.0 / 60
        var elapsed = 0.0
        while elapsed < seconds {
            player.update(delta: step, reduceMotion: reduceMotion)
            elapsed += step
        }
    }

    @Test("se sacude, saltan las monedas una vez y recién al final confirma la llegada, una sola vez")
    func opensOnce() {
        let player = PackageOpeningPlayer()
        let parent = SKNode()
        var bursts = 0
        var opened = 0
        player.play(at: CGPoint(x: 100, y: 200), in: parent, z: 50, side: 44,
                    burst: { _ in bursts += 1 }, opened: { opened += 1 })
        #expect(parent.children.count == 1)
        run(player, seconds: PackageOpeningPlayer.totalSeconds - 0.1, reduceMotion: false)
        #expect(opened == 0)
        #expect(bursts == 1)
        run(player, seconds: 0.5, reduceMotion: false)
        #expect(opened == 1)
        #expect(bursts == 1)
        #expect(parent.children.isEmpty)
        #expect(!player.isPlaying)
    }

    @Test("con Reduce Motion: un fundido corto, sin sacudida ni monedas")
    func reduceMotionIsAFade() {
        let player = PackageOpeningPlayer()
        let parent = SKNode()
        var bursts = 0
        var opened = 0
        player.play(at: .zero, in: parent, z: 0, side: 44, burst: { _ in bursts += 1 }, opened: { opened += 1 })
        run(player, seconds: PackageOpeningPlayer.fadeSeconds + 0.05, reduceMotion: true)
        #expect(opened == 1)
        #expect(bursts == 0)
    }

    @Test("cortarla no confirma nada y no deja nodos")
    func cancelling() {
        let player = PackageOpeningPlayer()
        let parent = SKNode()
        var opened = 0
        player.play(at: .zero, in: parent, z: 0, side: 44, burst: { _ in }, opened: { opened += 1 })
        run(player, seconds: 0.3, reduceMotion: false)
        player.cancel()
        run(player, seconds: 2, reduceMotion: false)
        #expect(opened == 0)
        #expect(parent.children.isEmpty)
    }

    // MARK: con video (E8e T6)

    private final class Counts {
        var bursts = 0
        var opened = 0
    }

    private func playVideo(_ player: PackageOpeningPlayer, in parent: SKNode, counts: Counts) {
        player.play(at: CGPoint(x: 100, y: 200), in: parent, z: 50, side: 44,
                    burst: { _ in counts.bursts += 1 }, opened: { counts.opened += 1 })
    }

    private func waitFor(_ seconds: Double = 8, _ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(seconds)
        while !condition(), clock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
    }

    @Test("con video y el pool vivo: monta paquete_abre y la llegada se confirma cuando el video termina")
    func realVideoDrivesOpened() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let player = PackageOpeningPlayer(pool: pool)
        let parent = SKNode()
        let counts = Counts()
        playVideo(player, in: parent, counts: counts)
        #expect(player.video != nil && pool.liveCount == 1 && counts.opened == 0)
        try await waitFor { counts.opened > 0 }
        #expect(counts.opened == 1)
        #expect(parent.children.isEmpty && pool.liveCount == 0 && !player.isPlaying)
    }

    @Test("con video, las monedas saltan una vez a mitad de la apertura")
    func videoBurstsOnce() {
        let pool = VideoPlayerPool(policy: .allowAll)
        let player = PackageOpeningPlayer(pool: pool)
        let counts = Counts()
        playVideo(player, in: SKNode(), counts: counts)
        run(player, seconds: PackageOpeningPlayer.videoBurstSeconds - 0.1, reduceMotion: false)
        #expect(counts.bursts == 0)
        run(player, seconds: 0.3, reduceMotion: false)
        #expect(counts.bursts == 1)
        run(player, seconds: 1, reduceMotion: false)
        #expect(counts.bursts == 1)
        player.cancel()
    }

    @Test("el tope por cuadros confirma aunque el video no avise, una sola vez; el aviso tardío no repite")
    func frameCapOpensAnyway() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let player = PackageOpeningPlayer(pool: pool)
        let parent = SKNode()
        let counts = Counts()
        playVideo(player, in: parent, counts: counts)
        run(player, seconds: PackageOpeningPlayer.videoCapSeconds + 0.2, reduceMotion: false)
        #expect(counts.opened == 1 && parent.children.isEmpty && pool.liveCount == 0)
        try await Task.sleep(for: .milliseconds(3500))
        #expect(counts.opened == 1, "el fin real del video no puede confirmar otra vez")
    }

    @Test("cortarla con el video vivo: sin aviso, sin nodos y el cupo vuelve")
    func cancelReleasesTheVideo() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let player = PackageOpeningPlayer(pool: pool)
        let parent = SKNode()
        let counts = Counts()
        playVideo(player, in: parent, counts: counts)
        #expect(pool.liveCount == 1)
        player.cancel()
        #expect(pool.liveCount == 0 && parent.children.isEmpty && player.video == nil)
        try await Task.sleep(for: .milliseconds(3500))
        #expect(counts.opened == 0)
    }

    @Test("volver a llamar play() corta la anterior y no deja un segundo video")
    func playTwice() {
        let pool = VideoPlayerPool(policy: .allowAll)
        let player = PackageOpeningPlayer(pool: pool)
        let parent = SKNode()
        playVideo(player, in: parent, counts: Counts())
        playVideo(player, in: parent, counts: Counts())
        #expect(parent.children.count == 1 && pool.liveCount == 1)
        player.cancel()
        #expect(pool.liveCount == 0)
    }

    @Test("sin el video (política quieta): abre igual por la animación de código")
    func stillPolicyOpensByCode() {
        let pool = VideoPlayerPool(policy: .allowAll.with(.forcedStill))
        let player = PackageOpeningPlayer(pool: pool)
        let counts = Counts()
        playVideo(player, in: SKNode(), counts: counts)
        #expect(player.video == nil)
        run(player, seconds: PackageOpeningPlayer.totalSeconds - 0.1, reduceMotion: false)
        #expect(counts.opened == 0)
        run(player, seconds: 0.3, reduceMotion: false)
        #expect(counts.opened == 1 && counts.bursts == 1)
    }

    @Test("sin el clip en el manifest: abre igual por la animación de código")
    func missingClipOpensByCode() {
        let player = PackageOpeningPlayer(manifest: .empty, pool: VideoPlayerPool(policy: .allowAll))
        let counts = Counts()
        playVideo(player, in: SKNode(), counts: counts)
        #expect(player.video == nil)
        run(player, seconds: PackageOpeningPlayer.totalSeconds + 0.1, reduceMotion: false)
        #expect(counts.opened == 1)
    }

    @Test("con Reduce Motion en pleno video: baja el video y abre con el fundido")
    func reduceMotionDuringVideo() {
        let pool = VideoPlayerPool(policy: .allowAll)
        let player = PackageOpeningPlayer(pool: pool)
        let parent = SKNode()
        let counts = Counts()
        playVideo(player, in: parent, counts: counts)
        run(player, seconds: PackageOpeningPlayer.fadeSeconds + 0.1, reduceMotion: true)
        #expect(counts.opened == 1 && counts.bursts == 0 && pool.liveCount == 0 && parent.children.isEmpty)
    }

    @Test("si el pool no lo pone vivo (suspendido), tras el vigía abre por la animación de código")
    func videoThatNeverStartsFallsBack() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let suspension = pool.suspend(.overlay)
        let player = PackageOpeningPlayer(pool: pool)
        let counts = Counts()
        playVideo(player, in: SKNode(), counts: counts)
        #expect(player.video != nil)
        try await waitFor(3) { player.video == nil }
        #expect(player.video == nil && counts.opened == 0)
        run(player, seconds: PackageOpeningPlayer.totalSeconds + 0.1, reduceMotion: false)
        #expect(counts.opened == 1)
        pool.resume(suspension)
    }
}
