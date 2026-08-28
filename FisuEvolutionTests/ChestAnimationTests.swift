import Foundation
import Testing
import UIKit
@testable import FisuEvolution

/// El bundle real vino sin `chest_anim.json` completo: el popup estaría
/// cayendo al cofre estático.
private struct ChestAnimMissing: Error {}

private func loadedChestAnimation() throws -> ChestAnimation {
    guard let animation = ChestAnimation.load() else { throw ChestAnimMissing() }
    return animation
}

/// El contrato de `ChestAnim/` (schemaVersion 2) visto desde el runtime.
///
/// `test_chest_video_frames` (pipeline) pina lo mismo del otro lado: si un
/// lado cambia el manifest, los frames, el video o la geometría sin el otro,
/// uno de los dos se pone rojo. Los números concretos (conteos, tamaños,
/// offsets) están a propósito: son el manifest INTEGRADO, no una
/// re-derivación de la fórmula.
@Suite("La animación del cofre: manifest y geometría")
struct ChestAnimationManifestTests {
    let animation: ChestAnimation

    init() throws {
        animation = try loadedChestAnimation()
    }

    @Test func losSegmentosInteractivosVienenConSusConteos() {
        #expect(animation.fps == 24)
        #expect(animation.info(.idle).frameCount == 1)
        #expect(animation.info(.shakeA).frameCount == 27)
        #expect(animation.info(.shakeB).frameCount == 17)
    }

    @Test func losFramesResuelvenASusArchivos() {
        #expect(animation.frames(.idle).first?.lastPathComponent == "chest_f000.png")
        #expect(animation.frames(.shakeA).first?.lastPathComponent == "chest_f004.png")
        #expect(animation.frames(.shakeA).last?.lastPathComponent == "chest_f030.png")
        #expect(animation.frames(.shakeB).first?.lastPathComponent == "chest_f031.png")
        #expect(animation.frames(.shakeB).last?.lastPathComponent == "chest_f047.png")
    }

    @Test func elCinematicoYElStillEstanEnElBundle() {
        #expect(animation.cinematicURL.lastPathComponent == "chest_open.mov")
        #expect(animation.cinematicFrameCount == 192)
        #expect(animation.cardStillURL.lastPathComponent == "chest_card_still.png")
        #expect((try? Data(contentsOf: animation.cinematicURL))?.isEmpty == false)
        // El still decodifica de verdad y con el tamaño del encuadre a 0,8.
        let still = UIImage(contentsOfFile: animation.cardStillURL.path)
        #expect(still != nil)
        if let still {
            #expect(abs(still.size.width * still.scale - 1024) < 1)
        }
    }

    /// El escenario del idle a cofre de 210 pt: el recorte de 912×504 con el
    /// cofre de 409 px escala a 468,3×258,8 pt, corrido para que el cofre —no
    /// el recorte— quede en el centro del frame.
    @Test func elEscenarioDelIdleAnclaElCofreAlCentro() {
        let stage = animation.stage(.idle, chestWidth: 210)
        #expect(abs(stage.size.width - 468.3) < 0.5)
        #expect(abs(stage.size.height - 258.8) < 0.5)
        #expect(abs(stage.offset.width - 9.0) < 0.5)
        #expect(abs(stage.offset.height - (-30.6)) < 0.5)
    }

    /// El encuadre del video es el lienzo entero, anclado por el mismo cofre:
    /// el empalme PNG→video no mueve nada.
    @Test func elEncuadreCinematicoAnclaElMismoCofre() {
        let stage = animation.cinematicStage(chestWidth: 210)
        #expect(abs(stage.size.width - 657.2) < 0.5)
        #expect(abs(stage.size.height - 369.7) < 0.5)
        #expect(abs(stage.offset.width - 2.8) < 0.5)
        #expect(abs(stage.offset.height - (-40.8)) < 0.5)
    }

    /// El pergamino del marco final, donde se renderiza el contenido del
    /// premio: 302×418 px del lienzo → 155,1×214,6 pt con el cofre a 210.
    @Test func elPergaminoDelMarcoTieneSuLugar() {
        let parch = animation.parchmentStage(chestWidth: 210)
        #expect(abs(parch.size.width - 155.1) < 0.5)
        #expect(abs(parch.size.height - 214.6) < 0.5)
        #expect(abs(parch.offset.width - 3.3) < 0.5)
        #expect(abs(parch.offset.height - (-44.9)) < 0.5)
    }
}

@Suite("La animación del cofre: el playhead")
@MainActor
struct ChestAnimationFeedTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    private func makeFeed() throws -> ChestAnimationFeed {
        ChestAnimationFeed(animation: try loadedChestAnimation())
    }

    @Test func clavadoEnUnFrameNoCorreNingunReloj() throws {
        let feed = try makeFeed()
        feed.show(.idle)
        #expect(feed.isPaused)
        #expect(feed.displayedIndex == 0)
        #expect(feed.displayed != nil)
    }

    @Test func elPlayheadSigueElRelojYSePausaAlFinal() throws {
        let feed = try makeFeed()
        feed.play(.shakeA, at: t0)
        #expect(!feed.isPaused)
        #expect(feed.displayedIndex == 0)

        // 0,25 s a 24 fps son 6 frames.
        feed.advance(to: t0.addingTimeInterval(0.25))
        #expect(feed.displayedIndex == 6)

        // Mucho después del final: se clava en el último y apaga el reloj.
        feed.advance(to: t0.addingTimeInterval(10))
        #expect(feed.displayedIndex == 26)
        #expect(feed.isPaused)
    }

    @Test func elRelojNuncaRetrocedeDelPrimerFrame() throws {
        let feed = try makeFeed()
        feed.play(.shakeA, at: t0)
        #expect(feed.index(at: t0.addingTimeInterval(-5)) == 0)
    }

    /// El tercer toque vuelve a reproducir la sacudida A: arranca de cero.
    @Test func rePlayDelMismoSegmentoReinicia() throws {
        let feed = try makeFeed()
        feed.play(.shakeA, at: t0)
        feed.advance(to: t0.addingTimeInterval(10))
        #expect(feed.isPaused)

        let t1 = t0.addingTimeInterval(20)
        feed.play(.shakeA, at: t1)
        #expect(!feed.isPaused)
        #expect(feed.displayedIndex == 0)
        feed.advance(to: t1.addingTimeInterval(0.125))
        #expect(feed.displayedIndex == 3)
    }

    /// Sin manifest (roto o ausente) el feed es un mueble: no rompe, no corre.
    @Test func sinManifestNoHayNadaQueCorra() {
        let feed = ChestAnimationFeed(animation: nil)
        feed.show(.idle)
        feed.play(.shakeB)
        feed.advance(to: .now)
        feed.warm(.shakeA)
        #expect(feed.displayed == nil)
        #expect(feed.displayedIndex == 0)
    }
}
