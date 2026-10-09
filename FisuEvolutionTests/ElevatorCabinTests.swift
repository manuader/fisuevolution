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
}
