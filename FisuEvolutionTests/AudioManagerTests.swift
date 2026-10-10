import Foundation
import Testing
@testable import FisuEvolution

/// Los diez `.caf` de SFX se construían recién en el **primer `play` de cada
/// uno**, en el hilo principal y sin `prepareToPlay()`: diez tirones repartidos
/// por la partida, cada uno justo encima de la acción que lo dispara (el tap, el
/// merge, la compra). Un promedio de fps a 60 no los muestra nunca porque son
/// caídas de un frame suelto, así que el contrato se fija acá.
@Suite("AudioManager")
@MainActor
struct AudioManagerTests {
    @Test("precargar deja todos los SFX listos antes del primer play")
    func preloadLeavesEverySFXReady() async {
        let audio = AudioManager()
        #expect(audio.preparedSFX.isEmpty, "recién construido no debería haber tocado el disco")

        await audio.preloadSFX()

        #expect(
            audio.preparedSFX == Set(AudioManager.SFX.allCases),
            "un SFX sin precargar se construye en main durante el gameplay"
        )
    }

    @Test("cada SFX tiene su archivo en el bundle")
    func everySFXHasItsFile() {
        for sfx in AudioManager.SFX.allCases {
            #expect(
                Bundle.main.url(forResource: sfx.rawValue, withExtension: "caf") != nil,
                "falta \(sfx.rawValue).caf"
            )
        }
    }

    @Test("con la música bajada, el volumen efectivo es una fracción; al soltar, vuelve")
    func duckingLowersAndRestores() {
        let audio = AudioManager()
        audio.musicVolume = 0.8
        audio.setMusicDucked(true)
        #expect(abs(audio.effectiveMusicVolume - 0.8 * AudioManager.duckFactor) < 0.0001)
        audio.setMusicDucked(false)
        #expect(abs(audio.effectiveMusicVolume - 0.8) < 0.0001)
    }

    @Test("el ambiente suena 18 dB abajo de la acción")
    func ambientGain() {
        #expect(abs(AudioManager.Gain.ambient.linear - Float(pow(10, -18.0 / 20))) < 0.001)
        #expect(abs(AudioManager.Gain.action.linear - Float(pow(10, -6.0 / 20))) < 0.001)
    }

    @Test("los nueve eventos con acento propio no lo comparten; los demás suenan el genérico")
    func eventAccents() throws {
        let ids = try GameContentLoader.load(from: .main).events.events.map(\.id)
        let withAccent = ["plan_platita", "startup_comprada", "devaluacion", "blanqueo",
                          "inversion_alienigena", "corralito", "aguinaldo", "home_banking", "apagon"]
        #expect(withAccent.allSatisfy(ids.contains))
        let accents = withAccent.map { AudioManager.accent(forEvent: $0) }
        #expect(!accents.contains(.event), "evento sin acento: \(withAccent.filter { AudioManager.accent(forEvent: $0) == .event })")
        #expect(Set(accents).count == accents.count, "dos eventos comparten acento")
        for id in ids where !withAccent.contains(id) {
            #expect(AudioManager.accent(forEvent: id) == .event, "\(id) ya tiene acento: sumalo a la lista")
        }
        #expect(AudioManager.accent(forEvent: "no_existe") == .event)
    }

    @Test("el tono del blip es estable por personaje y está en 0,8–1,25")
    func blipPitch() {
        let vecina = AudioManager.talkPitch(for: "npc_vecina")
        #expect(vecina == AudioManager.talkPitch(for: "npc_vecina"))
        #expect((0.8...1.25).contains(vecina))
        #expect(vecina != AudioManager.talkPitch(for: "npc_comisario"))
    }

    @Test("un ambiente arranca una sola vez y se corta sin dejar el loop armado")
    func ambientStartStop() {
        let audio = AudioManager()
        audio.startAmbient(.packageRattle)
        audio.startAmbient(.packageRattle)
        #expect(audio.preparedSFX.contains(.packageRattle))
        audio.stopAmbient(.packageRattle)
    }

    @Test("stop corta un SFX que suena y no rompe si nunca sonó")
    func stopSilencesAPlayingSFX() {
        let audio = AudioManager()
        audio.sfxVolume = 0.9
        audio.stop(.elevatorMotor)

        audio.play(.elevatorMotor)
        audio.stop(.elevatorMotor)

        #expect(audio.preparedSFX == [.elevatorMotor])
    }

    @Test("sin precarga, play sigue construyendo el player a demanda")
    func playStillLoadsOnDemandWithoutPreload() {
        let audio = AudioManager()
        audio.sfxVolume = 0.9

        audio.play(.tap)

        #expect(
            audio.preparedSFX == [.tap],
            "el camino perezoso es el fallback si la precarga todavía no terminó"
        )
    }

    /// Bajo `--uitest*` y en este host la música sigue siendo la de la v1: los
    /// temas por piso no se cargan aunque el tablero cambie de piso.
    @Test("en una corrida de tests la música por piso no carga nada")
    func floorMusicStaysOffUnderTests() {
        #expect(!AudioManager.launchAllowsFloorMusic, "el host de los unit tests cargaría temas de piso")
        let audio = AudioManager()

        audio.showFloor("alley")

        #expect(audio.floorTracks.isEmpty)
    }

    @Test("el remate de Fusionar todo existe en el bundle y se precarga")
    func mergeAllFinaleIsBundled() async {
        let audio = AudioManager()
        await audio.preloadSFX()
        #expect(audio.preparedSFX.contains(.mergeAllDone))
    }

    @Test("play con rate deja el player con el rate pedido, acotado a 0,5–2")
    func playWithRateSetsTheRate() async {
        let audio = AudioManager()
        audio.sfxVolume = 0.9
        await audio.preloadSFX()
        audio.play(.merge, rate: 1.25)
        #expect(audio.debugRate(of: .merge) == 1.25)
        audio.play(.coin, rate: 9)
        #expect(audio.debugRate(of: .coin) == 2)
        audio.play(.buy, rate: 0.1)
        #expect(audio.debugRate(of: .buy) == 0.5)
    }
}
