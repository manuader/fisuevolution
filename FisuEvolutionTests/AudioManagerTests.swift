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
    @Test("precargar deja los diez SFX listos antes del primer play")
    func preloadLeavesEverySFXReady() async {
        let audio = AudioManager()
        #expect(audio.preparedSFX.isEmpty, "recién construido no debería haber tocado el disco")

        await audio.preloadSFX()

        #expect(
            audio.preparedSFX == Set(AudioManager.SFX.allCases),
            "un SFX sin precargar se construye en main durante el gameplay"
        )
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
}
