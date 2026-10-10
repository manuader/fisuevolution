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
}
