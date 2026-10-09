import Foundation
import Testing
import UIKit
@testable import FisuEvolution

@Suite("La cabina del ascensor")
@MainActor
struct ElevatorCabinTests {
    @Test("con los dos clips es video; con los cuadros, cuadros; sin nada, vectorial")
    func artFallsBackInOrder() {
        let url = URL(fileURLWithPath: "/tmp/x.mov")
        let image = UIImage(systemName: "square")!
        let video = ElevatorCabinArt.resolve(url: { _ in url }, image: { _ in image })
        #expect(video.isVideo)
        let stills = ElevatorCabinArt.resolve(url: { _ in nil }, image: { _ in image })
        #expect(stills.isStills)
        let vector = ElevatorCabinArt.resolve(url: { _ in nil }, image: { _ in nil })
        #expect(vector == .vector)
        let halfVideo = ElevatorCabinArt.resolve(url: { $0 == "cabina_puertas_cierran" ? url : nil }, image: { _ in nil })
        #expect(halfVideo == .vector, "un clip solo no alcanza: cierra y abre van juntos")
    }

    @Test("con el video no se leen los cuadros")
    func stillsAreNotLoadedWhenTheClipIsThere() {
        let url = URL(fileURLWithPath: "/tmp/x.mov")
        var asked: [String] = []
        _ = ElevatorCabinArt.resolve(url: { _ in url }, image: { asked.append($0); return nil })
        #expect(asked.isEmpty)
    }

    @Test("el bundle de hoy resuelve el arte que dice el manifest")
    func bundleMatchesTheManifest() throws {
        let art = ElevatorCabinArt.resolve()
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: #require(
            Bundle.main.url(forResource: "loops_manifest", withExtension: "json")))) as? [String: Any]
        let cabin = manifest?["cabin"] as? [String: Any] ?? [:]
        #expect(art.isVideo == (cabin["puertas_cierran"] != nil && cabin["puertas_abren"] != nil))
    }

    @Test("en el teléfono la cabina cubre la pantalla; en el iPad va al alto, centrada")
    func cabinFrame() {
        let phone = CabinFrame.rect(in: CGSize(width: 393, height: 852))
        #expect(phone.width >= 393 && phone.height >= 852)
        let pad = CabinFrame.rect(in: CGSize(width: 820, height: 1180))
        #expect(pad.height == 1180)
        #expect(abs(pad.midX - 410) < 0.5)
        #expect(abs(pad.width / pad.height - 720.0 / 1280.0) < 0.001)
    }

    @Test("el calentado suelta lo que no se usa")
    func warmupReleases() {
        let url = Bundle.main.url(forResource: "cabina_puertas_cierran", withExtension: "mov")
        guard let url else { return }
        let warmup = ElevatorCabinWarmup()
        let first = warmup.closingPlayer(url: url)
        #expect(warmup.closingPlayer(url: url) === first, "idempotente: el mismo player")
        warmup.release()
        #expect(first.player.currentItem == nil)
        #expect(warmup.closingPlayer(url: url) !== first)
        warmup.release()
    }

    @Test("el dibujo sólo busca: sin player creado no hay nada, y el que se soltó desaparece")
    func lookupsNeverCreate() {
        guard let url = Bundle.main.url(forResource: "cabina_puertas_cierran", withExtension: "mov") else { return }
        let warmup = ElevatorCabinWarmup()
        #expect(warmup.currentClosing(url: url) == nil)
        #expect(warmup.currentOpening(url: url) == nil)
        let made = warmup.closingPlayer(url: url)
        #expect(warmup.currentClosing(url: url) === made)
        warmup.release()
        #expect(warmup.currentClosing(url: url) == nil)
    }

    private final class Holder: VideoLeaseHolder {
        func videoLeaseDidChange(isLive: Bool) {}
    }

    private static let clip = URL(fileURLWithPath: "/dev/null/cabina.mov")

    private func fullPool() -> (pool: VideoPlayerPool, holders: [Holder]) {
        let pool = VideoPlayerPool(policy: .allowAll)
        let holders = [Holder(), Holder(), Holder()]
        _ = pool.acquire(holders[0], role: .background)
        _ = pool.acquire(holders[1], role: .popup)
        _ = pool.acquire(holders[2], role: .icon)
        return (pool, holders)
    }

    // `prepare` corta con Reduce Motion: estos tests suponen que está apagado (el simulador de CI).
    @Test("preparar con video reserva un decodificador: de 3 vivos a 2; soltar lo devuelve")
    func prepareReservesADecoder() {
        let (pool, holders) = fullPool()
        withExtendedLifetime(holders) {
            #expect(pool.liveCount == 3)
            let warmup = ElevatorCabinWarmup(pool: pool)
            warmup.prepare(art: .video(close: Self.clip, open: Self.clip))
            #expect(pool.liveCount == 2)
            warmup.release()
            #expect(pool.liveCount == 3)
        }
    }

    @Test("preparar dos veces reserva uno solo")
    func prepareTwiceReservesOnce() {
        let (pool, holders) = fullPool()
        withExtendedLifetime(holders) {
            let warmup = ElevatorCabinWarmup(pool: pool)
            let art = ElevatorCabinArt.video(close: Self.clip, open: Self.clip)
            warmup.prepare(art: art)
            warmup.prepare(art: art)
            #expect(pool.liveCount == 2)
            warmup.release()
            warmup.release()
            #expect(pool.liveCount == 3, "un solo unreserve alcanza y el segundo release no resta de más")
        }
    }

    @Test("un player creado sin prepare, o después de vencer el calentado, también reserva")
    func lazyPlayersReserve() {
        let (pool, holders) = fullPool()
        withExtendedLifetime(holders) {
            let warmup = ElevatorCabinWarmup(pool: pool)
            warmup.prepare(art: .video(close: Self.clip, open: Self.clip))
            warmup.release()
            #expect(pool.liveCount == 3)
            _ = warmup.closingPlayer(url: Self.clip)
            #expect(pool.liveCount == 2)
            _ = warmup.openingPlayer(url: Self.clip)
            #expect(pool.liveCount == 2, "los dos players comparten una sola reserva")
            warmup.release()
            #expect(pool.liveCount == 3)
        }
    }

    @Test("con cuadros o vectorial no se reserva nada")
    func stillsAndVectorDoNotReserve() throws {
        let (pool, holders) = fullPool()
        try withExtendedLifetime(holders) {
            let warmup = ElevatorCabinWarmup(pool: pool)
            let image = try #require(UIImage(systemName: "circle"))
            warmup.prepare(art: .stills(closed: image, open: image))
            warmup.prepare(art: .vector)
            #expect(pool.liveCount == 3)
            warmup.release()
        }
    }
}
