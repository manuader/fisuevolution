import AVFoundation
import Foundation
import Observation

/// Audio por canales (música / SFX) con volúmenes independientes persistidos y
/// throttle anti-duplicado (skill: nunca sonidos duplicados). Los archivos llegan
/// en el [GATE HUMANO] de audio (CC0, ver plan F5.10); hasta entonces cada key
/// faltante se loguea una sola vez y el juego suena en silencio sin romperse.
///
/// La música de la 2.0 es un tema por piso con crossfade (ver `showFloor`); el
/// tema único de la v1 queda para las corridas de tests.
@Observable @MainActor
final class AudioManager {
    enum SFX: String, CaseIterable {
        case tap = "sfx_tap"
        case merge = "sfx_merge"
        case evolution = "sfx_evolution"
        case coin = "sfx_coin"
        case buy = "sfx_buy"
        case error = "sfx_error"
        case rare = "sfx_rare"
        case prestige = "sfx_prestige"
        case event = "sfx_event"
        case daily = "sfx_daily"
        // Las sacudidas del cofre, recortadas de la pista del video del
        // animador (las genera `chest_video_frames.py`): el timing lo pone el
        // dedo, así que van como clips y no dentro del mov del cinemático.
        case chestShakeA = "sfx_chest_shake_a"
        case chestShakeB = "sfx_chest_shake_b"
        /// La campana de la botonera del ascensor (E8 audio, cableada en E3).
        case elevatorDing = "sfx_elevator_ding"
    }

    static let musicVolumeKey = "settings.musicVolume"
    static let sfxVolumeKey = "settings.sfxVolume"

    var musicVolume: Double {
        didSet {
            UserDefaults.standard.set(musicVolume, forKey: Self.musicVolumeKey)
            musicPlayer?.volume = Float(musicVolume)
            // Sólo el tema que manda: el que se está yendo baja a cero solo.
            if let lead = floorMusic.lead {
                floorPlayers[lead]?.volume = Float(musicVolume)
            }
        }
    }

    var sfxVolume: Double {
        didSet {
            UserDefaults.standard.set(sfxVolume, forKey: Self.sfxVolumeKey)
        }
    }

    @ObservationIgnored private var musicPlayer: AVAudioPlayer?
    @ObservationIgnored private var sfxPlayers: [SFX: AVAudioPlayer] = [:]
    @ObservationIgnored private var lastPlayed: [SFX: TimeInterval] = [:]
    @ObservationIgnored private var missingLogged: Set<String> = []
    /// Mismo SFX no re-dispara dentro de esta ventana (anti-duplicado).
    private static let throttleWindow: TimeInterval = 0.08

    /// La música por piso (PLAN-v2 §5): un tema por piso con crossfade. Qué
    /// suena lo decide `FloorMusicDirector`; acá sólo viven los players, uno
    /// por tema vivo. El que se corta sale del diccionario en el acto, así que
    /// nunca hay más de dos.
    private let floorMusicEnabled: Bool
    @ObservationIgnored private var floorMusic = FloorMusicDirector()
    @ObservationIgnored private var floorPlayers: [String: AVAudioPlayer] = [:]
    /// El corte del tercero en un cambio rápido: un fundido cortito y no un
    /// `stop()` seco, que parar una onda a media amplitud hace clic.
    private static let cutFade: TimeInterval = 0.15

    init(floorMusicEnabled: Bool = AudioManager.launchAllowsFloorMusic) {
        let defaults = UserDefaults.standard
        musicVolume = defaults.object(forKey: Self.musicVolumeKey) as? Double ?? 0.6
        sfxVolume = defaults.object(forKey: Self.sfxVolumeKey) as? Double ?? 0.9
        self.floorMusicEnabled = floorMusicEnabled
    }

    /// Bajo `--uitest*` y en el host de los unit tests la música sigue siendo
    /// la de la v1 (`music_earth_loop` desde el arranque) y ningún tema de
    /// piso se carga: en una corrida de tests no entra nada nuevo que el test
    /// no haya pedido.
    nonisolated static var launchAllowsFloorMusic: Bool {
        let process = ProcessInfo.processInfo
        let uiTest = process.arguments.contains { $0.hasPrefix("--uitest") }
        let unitTestHost = process.environment["XCTestConfigurationFilePath"] != nil
        return !uiTest && !unitTestHost
    }

    /// Los SFX que ya tienen su player construido y sus buffers reservados.
    var preparedSFX: Set<SFX> { Set(sfxPlayers.keys) }

    func prepare() {
        // .ambient: respeta la música que el jugador ya tiene sonando.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Construir un `AVAudioPlayer` lee el archivo entero (no hay streaming en
    /// esta API) y `prepareToPlay()` reserva sus buffers. Hacerlo recién en el
    /// primer `play` de cada SFX dejaba diez tirones sueltos repartidos por la
    /// partida, cada uno justo encima de la acción que lo dispara —el tap, el
    /// merge, la compra—. Un promedio de fps no los muestra: son caídas de un
    /// frame, no throughput.
    ///
    /// La lectura del disco va afuera y sólo la construcción vuelve acá, de a un
    /// SFX por vez: cada `await` cede el hilo principal, así que la precarga
    /// convive con el bootstrap en lugar de bloquearlo.
    func preloadSFX() async {
        for sfx in SFX.allCases where sfxPlayers[sfx] == nil {
            guard let url = url(forResource: sfx.rawValue),
                  let data = await Self.read(url),
                  let player = try? AVAudioPlayer(data: data)
            else { continue }
            player.volume = Float(sfxVolume)
            player.prepareToPlay()
            sfxPlayers[sfx] = player
        }
    }

    /// La música es el archivo más pesado del bundle (1,7 MB) y se cargaba en
    /// main durante el arranque.
    ///
    /// Con la música por piso el arranque no pone nada: el primer tema lo
    /// pide el tablero apenas sabe en qué piso está (`showFloor`), y entra
    /// con el mismo fundido que un cambio de piso.
    func startMusic(named name: String = "music_earth_loop") async {
        guard !floorMusicEnabled, musicPlayer == nil else { return }
        guard let url = url(forResource: name),
              let data = await Self.read(url),
              let player = try? AVAudioPlayer(data: data)
        else { return }
        player.numberOfLoops = -1
        player.volume = Float(musicVolume)
        musicPlayer = player
        player.play()
    }

    /// `AVAudioPlayer` no es `Sendable`, así que no puede cruzar desde una tarea
    /// suelta hasta este actor. Lo que cruza es el `Data`, que sí lo es.
    private static func read(_ url: URL) async -> Data? {
        await Task.detached(priority: .utility) { try? Data(contentsOf: url) }.value
    }

    // MARK: Música por piso

    /// Los temas de piso vivos, el que manda primero.
    var floorTracks: [String] { floorMusic.voices }

    /// El piso visible cambió: por scroll, por ascensor o al cargar la
    /// partida. Lo llama `GameBoardView` observando el piso visible.
    func showFloor(_ floorID: String?) {
        guard floorMusicEnabled, let floorID else { return }
        for step in floorMusic.show(floor: floorID) {
            perform(step)
        }
    }

    private func perform(_ step: FloorMusicDirector.Step) {
        switch step {
        case .fadeIn(let track):
            Task { await fadeIn(track) }
        case .restore(let track):
            if let player = floorPlayers[track] {
                player.setVolume(Float(musicVolume), fadeDuration: FloorMusicDirector.crossfade)
            } else {
                // Se fue antes de terminar de cargar: entra como nuevo.
                Task { await fadeIn(track) }
            }
        case .fadeOut(let exit):
            floorPlayers[exit.track]?.setVolume(0, fadeDuration: FloorMusicDirector.crossfade)
            Task {
                try? await Task.sleep(for: .seconds(FloorMusicDirector.crossfade))
                if floorMusic.exitFinished(exit) {
                    floorPlayers.removeValue(forKey: exit.track)?.stop()
                }
            }
        case .cut(let track):
            guard let player = floorPlayers.removeValue(forKey: track) else { return }
            player.setVolume(0, fadeDuration: Self.cutFade)
            Task {
                try? await Task.sleep(for: .seconds(Self.cutFade))
                player.stop()
            }
        }
    }

    private func fadeIn(_ track: String) async {
        guard let url = url(forResource: track),
              let data = await Self.loopData(url)
        else { return }
        // Mientras se decodificaba el jugador pudo seguir de largo: el tema
        // sólo entra si todavía manda y nadie lo cargó en el medio.
        guard floorMusic.lead == track, floorPlayers[track] == nil,
              let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
        else { return }
        player.numberOfLoops = -1
        player.volume = 0
        floorPlayers[track] = player
        player.play()
        player.setVolume(Float(musicVolume), fadeDuration: FloorMusicDirector.crossfade)
    }

    /// El tema entero decodificado a PCM de 16 bits y envuelto en un WAV en
    /// memoria. Los temas por piso vienen en AAC —diez loops en PCM pesarían
    /// ~22 MB— y el AAC trae el priming del encoder: loopeado desde el
    /// archivo, la costura puede tropezar. Decodificado, `AVAudioFile` ya
    /// recorta el priming con la tabla de paquetes del CAF y el loop queda
    /// exacto muestra a muestra. Corre fuera de main, igual que `read`.
    nonisolated static func loopData(_ url: URL) async -> Data? {
        await Task.detached(priority: .utility) { decodedWAV(url) }.value
    }

    nonisolated static func decodedWAV(_ url: URL) -> Data? {
        guard let file = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatInt16, interleaved: true),
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: file.processingFormat,
                  frameCapacity: AVAudioFrameCount(file.length)
              ),
              (try? file.read(into: buffer)) != nil,
              let samples = buffer.int16ChannelData
        else { return nil }
        let channels = Int(file.processingFormat.channelCount)
        let pcm = Data(bytes: samples[0], count: Int(buffer.frameLength) * channels * 2)
        return wav(pcm: pcm, sampleRate: Int(file.processingFormat.sampleRate), channels: channels)
    }

    /// Cabecera RIFF de 44 bytes para PCM entero de 16 bits.
    private nonisolated static func wav(pcm: Data, sampleRate: Int, channels: Int) -> Data {
        var data = Data()
        func append(_ text: String) { data.append(contentsOf: Array(text.utf8)) }
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        append("RIFF")
        append(UInt32(36 + pcm.count))
        append("WAVE")
        append("fmt ")
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(channels))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * channels * 2))
        append(UInt16(channels * 2))
        append(UInt16(16))
        append("data")
        append(UInt32(pcm.count))
        data.append(pcm)
        return data
    }

    func play(_ sfx: SFX) {
        guard sfxVolume > 0 else { return }
        let now = Date().timeIntervalSince1970
        guard now - (lastPlayed[sfx] ?? 0) > Self.throttleWindow else { return }
        lastPlayed[sfx] = now

        if let player = sfxPlayers[sfx] {
            player.currentTime = 0
            player.volume = Float(sfxVolume)
            player.play()
            return
        }
        guard let url = url(forResource: sfx.rawValue),
              let player = try? AVAudioPlayer(contentsOf: url)
        else { return }
        player.volume = Float(sfxVolume)
        sfxPlayers[sfx] = player
        player.play()
    }

    private func url(forResource name: String) -> URL? {
        for fileExtension in ["caf", "m4a", "wav"] {
            if let url = Bundle.main.url(forResource: name, withExtension: fileExtension) {
                return url
            }
        }
        if missingLogged.insert(name).inserted {
            Log.lifecycle.info("audio asset missing (esperando gate de audio): \(name)")
        }
        return nil
    }
}
