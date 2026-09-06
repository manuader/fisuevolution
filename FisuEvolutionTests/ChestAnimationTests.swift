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
        // 48 y no 24: la velocidad 2x del dueño (2026-09-06) viaja en el
        // manifest — los mismos frames del master presentados a 48 fps. Fue 36
        // en la ronda del 1,5x.
        //
        // ⚠️ Este número tiene un gemelo que el compilador NO relaciona:
        // `ChestOpeningView.playbackFPS`. Si se separan, los relojes del flip y
        // del reveal quedan corridos respecto del video y no falla nada.
        #expect(animation.fps == 48)
        #expect(animation.info(.idle).frameCount == 1)
        #expect(animation.info(.shakeA).frameCount == 16)
        #expect(animation.info(.shakeB).frameCount == 11)
    }

    @Test func losFramesResuelvenASusArchivos() {
        #expect(animation.frames(.idle).first?.lastPathComponent == "chest_f000.png")
        #expect(animation.frames(.shakeA).first?.lastPathComponent == "chest_f023.png")
        #expect(animation.frames(.shakeA).last?.lastPathComponent == "chest_f038.png")
        #expect(animation.frames(.shakeB).first?.lastPathComponent == "chest_f039.png")
        #expect(animation.frames(.shakeB).last?.lastPathComponent == "chest_f049.png")
    }

    @Test func elCinematicoYElStillEstanEnElBundle() {
        #expect(animation.cinematicURL.lastPathComponent == "chest_open.mov")
        #expect(animation.cinematicFrameCount == 190)
        #expect(animation.cardStillURL.lastPathComponent == "chest_card_still.png")
        #expect((try? Data(contentsOf: animation.cinematicURL))?.isEmpty == false)
        // El still decodifica de verdad y con el tamaño del encuadre a 0,8.
        let still = UIImage(contentsOfFile: animation.cardStillURL.path)
        #expect(still != nil)
        if let still {
            #expect(abs(still.size.width * still.scale - 576) < 1)
        }
    }

    /// Los clips de las sacudidas (recortados de la pista del video por el
    /// pipeline) viven en el bundle con los nombres que espera `AudioManager`:
    /// sin ellos los toques del candado quedan mudos EN SILENCIO.
    @Test func losSonidosDeLasSacudidasEstanEnElBundle() {
        for name in ["sfx_chest_shake_a", "sfx_chest_shake_b"] {
            let url = Bundle.main.url(forResource: name, withExtension: "caf")
            #expect(url != nil, "falta \(name).caf")
            if let url {
                #expect(((try? Data(contentsOf: url))?.count ?? 0) > 1_000)
            }
        }
    }

    /// El escenario del idle a cofre de 210 pt: el recorte de 640×372 con el
    /// cofre de 448 px escala a 300,0×174,4 pt, corrido para que el cofre —no
    /// el recorte— quede en el centro del frame.
    @Test func elEscenarioDelIdleAnclaElCofreAlCentro() {
        let stage = animation.stage(.idle, chestWidth: 210)
        #expect(abs(stage.size.width - 300.0) < 0.5)
        #expect(abs(stage.size.height - 174.4) < 0.5)
        #expect(abs(stage.offset.width - 0.0) < 0.5)
        #expect(abs(stage.offset.height - (-5.4)) < 0.5)
    }

    /// El encuadre del video es el lienzo vertical entero, anclado por el
    /// mismo cofre: el empalme PNG→video no mueve nada.
    @Test func elEncuadreCinematicoAnclaElMismoCofre() {
        let stage = animation.cinematicStage(chestWidth: 210)
        #expect(abs(stage.size.width - 337.5) < 0.5)
        #expect(abs(stage.size.height - 600.0) < 0.5)
        #expect(abs(stage.offset.width - 4.7) < 0.5)
        #expect(abs(stage.offset.height - (-35.4)) < 0.5)
    }

    /// El pergamino del marco final, donde se renderiza el contenido del
    /// premio: 349×504 px del lienzo → 163,6×236,3 pt con el cofre a 210.
    @Test func elPergaminoDelMarcoTieneSuLugar() {
        let parch = animation.parchmentStage(chestWidth: 210)
        #expect(abs(parch.size.width - 163.6) < 0.5)
        #expect(abs(parch.size.height - 236.3) < 0.5)
        #expect(abs(parch.offset.width - (-1.6)) < 0.5)
        #expect(abs(parch.offset.height - (-47.1)) < 0.5)
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

        // 0,25 s a 48 fps son 12 frames.
        feed.advance(to: t0.addingTimeInterval(0.25))
        #expect(feed.displayedIndex == 12)

        // Mucho después del final: se clava en el último y apaga el reloj.
        feed.advance(to: t0.addingTimeInterval(10))
        #expect(feed.displayedIndex == 15)
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
        // 0,125 s a 48 fps: el playhead va por el frame 6, exacto.
        feed.advance(to: t1.addingTimeInterval(0.125))
        #expect(feed.displayedIndex == 6)
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
