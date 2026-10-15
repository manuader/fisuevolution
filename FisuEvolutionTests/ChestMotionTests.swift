import CoreGraphics
import Foundation
import EconomyKit
import Testing
@testable import FisuEvolution

/// El cofre rehecho en r56: cuándo corren sus clips, sus partículas y el
/// momento del estallido.
@Suite("El cofre: clips, partículas y estallido")
struct ChestMotionTests {
    /// El bug del dueño (iPhone 15 Pro, Release): con el Modo de bajo consumo, la
    /// térmica o la reproducción automática apagada, el pool deja los loops en
    /// póster, y el cofre —que colgaba de esa regla— quedaba quieto y largaba la
    /// tarjeta de golpe. El cofre lo pide el dedo: esas razones no lo apagan.
    @Test(arguments: [
        VideoPlaybackPolicy.Reason.lowPower, .thermal, .videoAutoplayOff,
    ])
    func lasRazonesDelTableroNoApaganElCofre(_ reason: VideoPlaybackPolicy.Reason) {
        let policy = VideoPlaybackPolicy.allowAll.with(reason)
        #expect(!policy.allowsLoops, "la premisa: el tablero sí queda en póster")
        #expect(ChestMotion.playsClips(policy: policy, reduceMotion: false))
    }

    @Test(arguments: [
        VideoPlaybackPolicy.Reason.reduceMotion, .background, .forcedStill,
    ])
    func loQuePideElJugadorOElTestSiLoApaga(_ reason: VideoPlaybackPolicy.Reason) {
        let policy = VideoPlaybackPolicy.allowAll.with(reason)
        #expect(!ChestMotion.playsClips(policy: policy, reduceMotion: false))
    }

    @Test func reduceMotionDeLaVistaLoApaga() {
        #expect(!ChestMotion.playsClips(policy: .allowAll, reduceMotion: true))
        #expect(ChestMotion.playsClips(policy: .allowAll, reduceMotion: false))
    }

    /// Los tres clips del mazo están en el bundle base (sin pack ODR): en
    /// Release no hay nada que bajar para que el cofre se mueva.
    @MainActor @Test func losClipsViajanEnElPaqueteBase() throws {
        let manifest = try LoopsManifest.load(from: .main)
        for id in ["cofre_espera", "cofre_sacude", "cofre_abre"] {
            #expect(manifest.odrTag(for: .object(id)) == nil, "\(id) no puede depender de un pack ODR")
        }
        #expect(ChestClipDeck(animates: true, manifest: manifest) != nil)
    }

    /// El estallido es el cuadro de los rayos del clip, contado desde el
    /// cuadro en que arranca la apertura (justo antes de la tapa).
    @Test func elEstallidoCaeEnLosRayosDelClip() {
        #expect(ChestClipDeck.openStartFrame < ChestClipDeck.openBurstFrame)
        #expect(abs(ChestClipDeck.burstDelay - 16.0 / 24.0) < 0.001)
    }

    @Test func elSEDibujaMenosParticulas() {
        let se = ChestFX.budget(maxLiveVideos: VideoPlayerPool.conservativeMaxLive)
        let pro = ChestFX.budget(maxLiveVideos: VideoPlayerPool.maxLive)
        #expect(se.burst < pro.burst)
        #expect(se.tap <= pro.tap)
        #expect(pro.burst <= 50, "tope: un Canvas, pero no infinito")
    }

    /// Cada toque larga más chispas que el anterior, sin pasar el tope.
    @Test func lasChispasCrecenConCadaToque() {
        let budget = ChestFX.fullBudget
        let counts = (1...3).map { ChestFX.tapSparks(tap: $0, at: .zero, budget: budget).count }
        #expect(counts[0] < counts[1])
        #expect(counts[1] <= counts[2])
        #expect(counts.allSatisfy { $0 <= budget.tap })
    }

    /// Las estrellas del estallido llevan el color de la rareza.
    @Test(arguments: SkinsConfig.Rarity.allCases)
    func elEstallidoTieneElColorDeLaRareza(_ rarity: SkinsConfig.Rarity) {
        let burst = ChestFX.burst(rarity: rarity, at: .zero, budget: ChestFX.fullBudget)
        #expect(burst.count == ChestFX.fullBudget.burst)
        #expect(burst.contains { $0.colorAsset == ChestCardStyle.glowAsset(rarity) })
    }

    /// Una partícula sale, vuela hacia donde apunta, y se apaga a tiempo: el
    /// `Canvas` deja de dibujarla y la emisión se retira.
    @Test func unaParticulaNaceVuelaYSeApaga() throws {
        let spark = ChestParticle(shape: .star, colorAsset: "PaletteYellow", origin: .zero,
                                  velocity: CGVector(dx: 100, dy: -200), gravity: 0, spin: 90,
                                  size: 10, life: 1, delay: 0.1)
        #expect(ChestFX.state(of: spark, at: 0.05) == nil, "antes de su retardo no existe")
        let mid = try #require(ChestFX.state(of: spark, at: 0.5))
        #expect(mid.position.x > 0 && mid.position.y < 0)
        #expect(ChestFX.state(of: spark, at: 1.2) == nil, "pasada su vida no se dibuja")
        let all = ChestFX.burst(rarity: .legendaria, at: .zero, budget: ChestFX.fullBudget)
            + ChestFX.dust(at: .zero, budget: ChestFX.fullBudget)
        #expect(all.allSatisfy { $0.delay + $0.life <= ChestFX.maxLifetime })
    }

    /// Mismo cofre, mismas partículas: la semilla es fija.
    @Test func lasParticulasSonDeterministas() {
        let a = ChestFX.burst(rarity: .rara, at: .zero, budget: ChestFX.fullBudget)
        let b = ChestFX.burst(rarity: .rara, at: .zero, budget: ChestFX.fullBudget)
        #expect(a == b)
    }

    /// Los sonidos nuevos del cofre están en el bundle.
    @Test func losSonidosDelCofreEstanEnElBundle() {
        let nuevos: [AudioManager.SFX] = [
            .chestLand, .chestKnock, .chestBurst,
            .chestFanfareComun, .chestFanfareRara, .chestFanfareEpica, .chestFanfareLegendaria,
        ]
        for sfx in nuevos {
            #expect(Bundle.main.url(forResource: sfx.rawValue, withExtension: "caf") != nil, "falta \(sfx.rawValue)")
        }
    }
}
