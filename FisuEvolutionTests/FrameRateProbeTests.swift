#if DEBUG
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La sonda de fps: las cuentas y el fixture de estrés")
@MainActor
struct FrameRateProbeTests {
    @Test("sin cuadros, todo en cero")
    func empty() {
        let stats = FrameStats()
        #expect(stats.frameCount == 0)
        #expect(stats.averageFPS == 0)
        #expect(stats.slowFrames == 0)
        #expect(stats.worstFrameMs == 0)
    }

    @Test("a 60 fps parejos: promedio 60, ningún cuadro lento")
    func steady() {
        var stats = FrameStats()
        for _ in 0..<120 { stats.add(frameDuration: 1.0 / 60) }
        #expect(abs(stats.averageFPS - 60) < 0.001)
        #expect(stats.slowFrames == 0)
        #expect(abs(stats.worstFrameMs - 1000.0 / 60) < 0.001)
    }

    @Test("cuenta los cuadros de más de 25 ms y recuerda el peor")
    func slowAndWorst() {
        var stats = FrameStats()
        for _ in 0..<8 { stats.add(frameDuration: 0.010) }
        stats.add(frameDuration: 0.026)
        stats.add(frameDuration: 0.080)
        #expect(stats.slowFrames == 2)
        #expect(abs(stats.worstFrameMs - 80) < 0.001)
        #expect(stats.frameCount == 10)
    }

    @Test("justo 25 ms no es lento")
    func threshold() {
        var stats = FrameStats()
        stats.add(frameDuration: 0.025)
        #expect(stats.slowFrames == 0)
    }

    @Test("la ventana es de 600 cuadros: el peor viejo sale cuando se va")
    func window() {
        var stats = FrameStats()
        stats.add(frameDuration: 0.500)
        for _ in 0..<FrameStats.windowSize { stats.add(frameDuration: 0.016) }
        #expect(stats.frameCount == FrameStats.windowSize)
        #expect(stats.slowFrames == 0)
        #expect(abs(stats.worstFrameMs - 16) < 0.001)
    }

    @Test("un cuadro de duración inválida no entra")
    func invalid() {
        var stats = FrameStats()
        stats.add(frameDuration: 0)
        stats.add(frameDuration: -1)
        #expect(stats.frameCount == 0)
    }

    @Test("el resumen del panel junta fps, peor cuadro y memoria")
    func summary() {
        var stats = FrameStats()
        for _ in 0..<60 { stats.add(frameDuration: 1.0 / 30) }
        let line = FrameRateProbe.summary(stats, footprintMB: 312.4)
        #expect(line == "30 fps · peor 33 ms · >25 ms: 60 · 312 MB")
    }

    @Test("la memoria residente se lee y es positiva")
    func footprint() {
        #expect(FrameRateProbe.footprintMB() > 1)
    }

    @Test("el estrés pone el piso, el especial y el ícono sobre videos reales del bundle")
    func stressManifest() throws {
        let content = try GameContentLoader.load(from: .main)
        let manifest = LoopsManifest.animStress(over: .main, content: content)
        let backgrounds = Set(content.floorTable.floors.map(\.background))
        #expect(!backgrounds.isEmpty)
        for key in backgrounds {
            #expect(manifest.floors[key]?.file == "cine_reencarnacion.mov")
            #expect(manifest.url(for: .floor(key)) != nil)
        }
        let special = try #require(content.specials.specials.first)
        #expect(manifest.url(for: .character(special.id)) != nil)
        #expect(manifest.url(for: .shopIcon(LoopsManifest.animStressIconID)) != nil)
        #expect(manifest.portraits == LoopsManifest.main.portraits)
    }
}
#endif
