import AVFoundation
import Foundation
import Observation

/// Audio por canales (música / SFX) con volúmenes independientes persistidos y
/// throttle anti-duplicado (skill: nunca sonidos duplicados). Los archivos llegan
/// en el [GATE HUMANO] de audio (CC0, ver plan F5.10); hasta entonces cada key
/// faltante se loguea una sola vez y el juego suena en silencio sin romperse.
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
    }

    static let musicVolumeKey = "settings.musicVolume"
    static let sfxVolumeKey = "settings.sfxVolume"

    var musicVolume: Double {
        didSet {
            UserDefaults.standard.set(musicVolume, forKey: Self.musicVolumeKey)
            musicPlayer?.volume = Float(musicVolume)
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

    init() {
        let defaults = UserDefaults.standard
        musicVolume = defaults.object(forKey: Self.musicVolumeKey) as? Double ?? 0.6
        sfxVolume = defaults.object(forKey: Self.sfxVolumeKey) as? Double ?? 0.9
    }

    func prepare() {
        // .ambient: respeta la música que el jugador ya tiene sonando.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func startMusic(named name: String = "music_earth_loop") {
        guard musicPlayer == nil else { return }
        guard let url = url(forResource: name) else { return }
        musicPlayer = try? AVAudioPlayer(contentsOf: url)
        musicPlayer?.numberOfLoops = -1
        musicPlayer?.volume = Float(musicVolume)
        musicPlayer?.play()
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
