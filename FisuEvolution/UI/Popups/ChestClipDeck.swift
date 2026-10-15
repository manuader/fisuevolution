import AVFoundation
import SwiftUI
import UIKit

/// Cuándo el cofre reproduce sus clips. Pura: la consulta la vista y la pinean
/// los tests.
///
/// ⚠️ **No es la regla de los loops del tablero** (`allowsLoops`), y por eso
/// existe. C26 puso los clips del cofre en `AnimatedArtView`, que los apaga con
/// CUALQUIER razón del pool —Modo de bajo consumo, térmica `.serious`, la
/// reproducción automática de previsualizaciones apagada—: en el iPhone del
/// dueño el cofre quedaba en su póster quieto, los toques no movían nada y la
/// tarjeta aparecía de golpe. El cofre es un momento que el jugador pide con el
/// dedo, como la cinemática: lo apagan sólo Reduce Motion, el segundo plano y
/// el póster forzado de los tests.
enum ChestMotion {
    static func playsClips(policy: VideoPlaybackPolicy, reduceMotion: Bool) -> Bool {
        guard !reduceMotion else { return false }
        return policy.reasons.isDisjoint(with: [.reduceMotion, .background, .forcedStill])
    }
}

/// Los tres clips del cofre (`cofre_espera`, `cofre_sacude`, `cofre_abre`),
/// calentados juntos al llegar y montados a la vez: cambiar de clip es cambiar
/// cuál se ve, nunca crear un decodificador en el medio de un toque (el arranque
/// en frío del HEVC con alfa dejaba el cofre transparente un instante en cada
/// sacudida).
///
/// No pasa por `VideoPlayerPool`: mientras el cofre está en pantalla el pool
/// queda suspendido (`suspendsVideoPool`), así que los decodificadores del
/// tablero se sueltan y el cofre tiene los suyos — también en el SE.
///
/// Los cuadros quietos (el primero de la espera y el último de la apertura) se
/// sacan de los mismos clips: con Reduce Motion o en los tests, el cofre cerrado
/// y el abierto son exactamente los del video.
@MainActor
@Observable
final class ChestClipDeck {
    enum Clip: String { case idle, shake, open }

    /// La apertura arranca en el cuadro 22, justo antes de que la tapa se
    /// despegue: el segundo quieto del principio del clip ya lo hicieron los
    /// tres toques.
    nonisolated static let openStartFrame: Int64 = 22
    /// El cuadro en que estallan los rayos del clip (38): ahí sale el premio.
    nonisolated static let openBurstFrame: Int64 = 38
    nonisolated static let fps: Int32 = 24
    /// Segundos entre el tercer toque y el estallido.
    nonisolated static var burstDelay: Double { Double(openBurstFrame - openStartFrame) / Double(fps) }

    let animates: Bool
    private(set) var showing: Clip = .idle
    private(set) var ready: Set<Clip> = []
    private(set) var closedStill: UIImage?
    private(set) var openedStill: UIImage?

    @ObservationIgnored private let urls: [Clip: URL]
    private(set) var players: [Clip: AVPlayer] = [:]
    @ObservationIgnored private var looper: AVPlayerLooper?
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var shakeToken = 0
    @ObservationIgnored private var openWarm = false

    /// `nil` si falta alguno de los tres clips (el cofre se arma con el póster
    /// del atlas).
    init?(animates: Bool, manifest: LoopsManifest = .main) {
        var urls: [Clip: URL] = [:]
        for (clip, id) in [(Clip.idle, "cofre_espera"), (.shake, "cofre_sacude"), (.open, "cofre_abre")] {
            guard let url = manifest.url(for: .object(id)) else { return nil }
            urls[clip] = url
        }
        self.urls = urls
        self.animates = animates
    }

    /// Los clips que llegaron a verse vivos, en orden (sin repetir). Lo lee el
    /// UI test (`chest.clip`): un cofre que se queda en su póster no suma nada.
    private(set) var played: [Clip] = []

    var status: String {
        guard animates else { return "still" }
        return played.isEmpty ? "loading" : played.map(\.rawValue).joined(separator: "+")
    }

    private func show(_ clip: Clip) {
        showing = clip
        notePlayed()
    }

    private func notePlayed() {
        if ready.contains(showing), !played.contains(showing) { played.append(showing) }
    }

    /// Arma todo. Idempotente.
    func start() {
        guard tasks.isEmpty else { return }
        tasks.append(Task { [weak self] in await self?.loadStills() })
        guard animates, let idleURL = urls[.idle], let shakeURL = urls[.shake], let openURL = urls[.open] else { return }

        let idle = AVQueuePlayer()
        Self.configure(idle)
        looper = AVPlayerLooper(player: idle, templateItem: AVPlayerItem(url: idleURL))
        players[.idle] = idle
        idle.play()

        let shake = AVPlayer(playerItem: AVPlayerItem(url: shakeURL))
        Self.configure(shake)
        players[.shake] = shake

        let open = AVPlayer(playerItem: AVPlayerItem(url: openURL))
        Self.configure(open)
        players[.open] = open

        tasks.append(Task { [weak self] in await self?.warm(shake, at: .zero) })
        tasks.append(Task { [weak self] in
            await self?.warm(open, at: CMTime(value: Self.openStartFrame, timescale: Self.fps))
            self?.openWarm = true
        })
        tasks.append(Task { [weak self] in await self?.watchShakeEnds(of: shake) })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        looper?.disableLooping()
        looper = nil
        for player in players.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        players = [:]
    }

    func markReady(_ clip: Clip) {
        ready.insert(clip)
        notePlayed()
    }

    /// Una sacudida: el clip vuelve a cero y corre una vez; al terminar, la
    /// espera (que nunca dejó de correr por debajo) vuelve a verse.
    func playShake() {
        guard animates, let shake = players[.shake], showing != .open else { return }
        shakeToken += 1
        show(.shake)
        shake.pause()
        Task { [shake] in
            await shake.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            shake.playImmediately(atRate: 1)
        }
        let token = shakeToken
        Task { [weak self] in
            // Tope por si el fin del item no llega: la espera tiene que volver.
            try? await Task.sleep(for: .seconds(1.6))
            guard let self, self.shakeToken == token, self.showing == .shake else { return }
            self.show(.idle)
        }
    }

    /// La apertura, desde el cuadro de antes de la tapa. Queda pausada en el
    /// último cuadro: el cofre abierto se queda en pantalla.
    func playOpen() {
        guard animates, let open = players[.open] else { return }
        show(.open)
        players[.idle]?.pause()
        players[.shake]?.pause()
        guard openWarm else {
            open.pause()
            Task { [open] in
                await open.seek(to: CMTime(value: Self.openStartFrame, timescale: Self.fps),
                                toleranceBefore: .zero, toleranceAfter: .zero)
                open.playImmediately(atRate: 1)
            }
            return
        }
        open.playImmediately(atRate: 1)
    }

    /// Espera el cuadro quieto del cofre cerrado (o el tope): el cofre cae ya
    /// con el arte del clip y no con el del atlas, que es más chico.
    func waitForClosedStill(timeout: Double) async {
        let deadline = ContinuousClock.now + .seconds(timeout)
        while closedStill == nil, ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Espera a que la apertura llegue al cuadro `frame` (o el tope): el
    /// estallido del código cae sobre el de los rayos del clip aunque el
    /// decodificador haya tardado en arrancar.
    func waitForOpenFrame(_ frame: Int64, timeout: Double) async {
        let target = CMTime(value: frame, timescale: Self.fps)
        let deadline = ContinuousClock.now + .seconds(timeout)
        while ContinuousClock.now < deadline, !Task.isCancelled {
            if let open = players[.open], open.currentTime() >= target { return }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private static func configure(_ player: AVPlayer) {
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.actionAtItemEnd = .pause
    }

    /// El calentado de `ChestCinematicPlayer`: esperar `readyToPlay`, pedir
    /// cuadros de verdad unos milisegundos (el `preroll` solo no llena la cola
    /// del decodificador del HEVC con alfa) y volver al cuadro de arranque.
    private func warm(_ player: AVPlayer, at start: CMTime) async {
        for _ in 0..<60 where player.currentItem?.status != .readyToPlay {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard !Task.isCancelled, player.currentItem?.status == .readyToPlay else { return }
        await player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
        guard !Task.isCancelled else { return }
        player.playImmediately(atRate: 1)
        try? await Task.sleep(for: .milliseconds(140))
        guard !Task.isCancelled else { return }
        // Si el jugador ya tocó, el clip es suyo: no se rebobina debajo del dedo.
        guard showing != .shake || player !== players[.shake],
              showing != .open || player !== players[.open] else { return }
        player.pause()
        await player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func watchShakeEnds(of player: AVPlayer) async {
        guard let item = player.currentItem else { return }
        let ends = NotificationCenter.default
            .notifications(named: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .map { _ in () }
        for await _ in ends where showing == .shake {
            show(.idle)
        }
    }

    /// El primer cuadro de la espera y el último de la apertura, con su alfa
    /// (`AVAssetImageGenerator` lee la capa auxiliar del HEVC; ffmpeg no).
    private func loadStills() async {
        if let url = urls[.idle] { closedStill = await Self.frame(of: url, at: .zero) }
        if let url = urls[.open] { openedStill = await Self.frame(of: url, at: CMTime(value: 72, timescale: Self.fps)) }
    }

    private static func frame(of url: URL, at time: CMTime) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let image = try? await generator.image(at: time).image else { return nil }
        return UIImage(cgImage: image)
    }
}

/// La capa de un clip del mazo: un `AVPlayerLayer` transparente que avisa
/// cuando pintó su primer cuadro.
struct ChestClipSurface: UIViewRepresentable {
    let player: AVPlayer
    let onReady: @MainActor () -> Void

    final class Surface: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        // layerClass fija el tipo: el cast no puede fallar.
        // swiftlint:disable:next force_cast
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var poll: Task<Void, Never>?
    }

    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        // Transparente SIEMPRE: el alfa del HEVC compone contra el telón (ver
        // `ChestCinematicView`).
        view.isOpaque = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        let onReady = onReady
        view.poll = Task { @MainActor [weak view] in
            for _ in 0..<120 {
                guard let view, !Task.isCancelled else { return }
                if view.playerLayer.isReadyForDisplay {
                    onReady()
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        return view
    }

    func updateUIView(_ view: Surface, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
    }

    static func dismantleUIView(_ view: Surface, coordinator: ()) {
        view.poll?.cancel()
        view.playerLayer.player = nil
    }
}
