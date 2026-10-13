import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Pantallas de premio en tres momentos (E14 T17)")
@MainActor
struct PrizeScreensTests {
    @Test("el Colchón se abre con tres toques: espera, sacude, sacude, abre")
    func threeTapsOpenTheMattress() {
        var opening = MattressOpening()
        #expect(opening.clipID == "colchon_espera")
        #expect(!opening.isOpen)

        opening.tap(reduceMotion: false)
        #expect(opening.clipID == "colchon_sacude")
        opening.shakeEnded()
        #expect(opening.clipID == "colchon_espera", "entre toque y toque respira")

        opening.tap(reduceMotion: false)
        #expect(opening.clipID == "colchon_sacude")
        #expect(!opening.isOpen)

        opening.tap(reduceMotion: false)
        #expect(opening.isOpen)
        #expect(opening.clipID == "colchon_abre")
        #expect(opening.taps == MattressOpening.tapsToOpen)
    }

    @Test("con Reduce Motion un solo toque lo abre, y de ahí no pasa")
    func reduceMotionOpensAtOnce() {
        var opening = MattressOpening()
        opening.tap(reduceMotion: true)
        #expect(opening.isOpen)
        #expect(opening.clipID == "colchon_abre")
        opening.tap(reduceMotion: false)
        #expect(opening.taps == MattressOpening.tapsToOpen, "abierto no se cuenta más")
    }

    @Test("los tres clips del Colchón están en el manifest")
    func mattressClipsExist() {
        for id in ["colchon_espera", "colchon_sacude", "colchon_abre", "ruleta_espera", "ruleta_premio"] {
            #expect(LoopsManifest.main.url(for: .object(id)) != nil, "falta \(id)")
        }
    }

    @Test("cada gajo de la Ruleta tiene su imagen y cabe en su rebanada")
    func everyWheelSliceHasArt() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        for segment in content.wheel.segments {
            let spec = segment.reward
            #expect(RewardKind(spec) != nil, "\(segment.id) no tiene imagen: caería al regalo genérico")
            let kind = WheelSliceLayout.kind(of: spec)
            #expect(kind.resolvedArtKey != nil, "\(segment.id): \(kind) no tiene ni una clave integrada")
        }
        #expect(WheelSliceLayout.artFits(slices: content.wheel.segments.count))
        #expect(!WheelSliceLayout.artFits(slices: 0))
    }

    @Test("lo que puede salir del Colchón también se ilustra")
    func mattressPrizesHaveArt() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        for prize in content.treasures.prizes {
            let first = try #require(prize.rewards.first)
            #expect(RewardKind(first) != nil, "\(prize.id) sin imagen")
        }
    }

    @Test("el disco liso del clip cae adentro del cuadro y los gajos caben en el escenario")
    func wheelStageGeometry() {
        let half = WheelStage.discDiameter / 2
        #expect(WheelStage.discDiameter < WheelStage.size.width)
        #expect(abs(WheelStage.discOffset.width) + half <= WheelStage.size.width / 2)
        #expect(abs(WheelStage.discOffset.height) + half <= WheelStage.size.height / 2)
    }

    @Test("sólo un deslizón lateral tira la ruleta; el vertical es scroll")
    func swipeVersusScroll() {
        #expect(WheelStage.isSwipe(CGSize(width: 90, height: 10)))
        #expect(WheelStage.isSwipe(CGSize(width: -80, height: 20)))
        #expect(!WheelStage.isSwipe(CGSize(width: 10, height: 90)))
        #expect(!WheelStage.isSwipe(CGSize(width: 40, height: 0)), "corto: es un roce")
        #expect(!WheelStage.isSwipe(CGSize(width: 70, height: 70)), "en diagonal manda el scroll")
    }
}
