import AVFoundation
import SwiftUI
import UIKit

@MainActor
enum AnimatedArt {
    static func resolve(_ clip: ArtClip, manifest: LoopsManifest, packs: ArtPacks = .shared) -> URL? {
        manifest.url(for: clip, packs: packs)
    }
}

/// Pide el pack ODR del clip mientras la vista está en pantalla y lo suelta al salir. Cuando el pack
/// llega, `ArtPacks` (observable) vuelve a evaluar el `body` y el `.id(url)` monta la capa de video.
private struct ArtPackLease: ViewModifier {
    let tag: String?

    func body(content: Content) -> some View {
        content
            .onAppear { tag.map { ArtPacks.shared.request($0) } }
            .onDisappear { tag.map { ArtPacks.shared.release($0) } }
            .onChange(of: tag) { old, new in
                old.map { ArtPacks.shared.release($0) }
                new.map { ArtPacks.shared.request($0) }
            }
    }
}

enum ArtPlayback {
    case loop
    case once(onEnd: @MainActor () -> Void)
}

/// Un arte del juego que se mueve (spec E8): el póster de siempre y, encima, su video si el
/// manifest lo tiene y el pool lo deja. El póster nunca se saca: si el video no carga o el pool
/// lo baja, se ve el póster, sin hueco ni parpadeo.
struct AnimatedArtView<Poster: View>: View {
    typealias Playback = ArtPlayback

    /// El `onEnd` de `.once` es el del montaje: si cambia el clip o el rol, la capa se rehace.
    let clip: ArtClip
    var role: VideoRole = .popup
    var playback: Playback = .loop
    @ViewBuilder let poster: () -> Poster
    @Environment(\.loopsManifest) private var manifest

    var body: some View {
        poster().modifier(ArtPackLease(tag: manifest.odrTag(for: clip))).overlay {
            if let url = AnimatedArt.resolve(clip, manifest: manifest) {
                ArtVideoLayer(url: url, role: role, playback: playback)
                    .id("\(url.absoluteString)|\(role.rawValue)")
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct ArtVideoLayer: UIViewRepresentable {
    let url: URL
    let role: VideoRole
    let playback: ArtPlayback

    func makeUIView(context: Context) -> ArtVideoUIView {
        ArtVideoUIView(url: url, role: role, playback: playback, pool: .shared)
    }

    func updateUIView(_ uiView: ArtVideoUIView, context: Context) {}

    static func dismantleUIView(_ uiView: ArtVideoUIView, coordinator: ()) {
        uiView.stop()
    }
}

/// La capa de video: transparente hasta el primer cuadro. El `AVQueuePlayer` nace cuando el pool
/// la pone viva y se suelta cuando la baja, nunca antes.
@MainActor
final class ArtVideoUIView: UIView, VideoLeaseHolder {
    private static let fadeDuration: TimeInterval = 0.15
    private static let watchdogSeconds = 1.0
    private static let readyPollNanos: UInt64 = 50_000_000
    private static let readyPollLimit = 40

    private let url: URL
    private let role: VideoRole
    private let playback: ArtPlayback
    private let pool: VideoPlayerPool
    private var lease: VideoPlayerPool.Lease?
    private var looper: AVPlayerLooper?
    private var tasks: [Task<Void, Never>] = []
    private var onceFinished = false
    private var watchdog: Task<Void, Never>?

    private var isOnce: Bool {
        if case .once = playback { return true }
        return false
    }

    private(set) var player: AVPlayer?

    var videoAlpha: CGFloat { alpha }

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer {
        // layerClass fija el tipo: el cast no puede fallar.
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }

    init(url: URL, role: VideoRole, playback: ArtPlayback, pool: VideoPlayerPool) {
        self.url = url
        self.role = role
        self.playback = playback
        self.pool = pool
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        accessibilityIdentifier = "art.video"
        playerLayer.videoGravity = .resizeAspect
        alpha = 0
        accessibilityValue = "still"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stop()
        } else if lease == nil, !onceFinished {
            if isOnce {
                guard pool.policy.allowsLoops else {
                    finishOnce()
                    return
                }
                startWatchdog()
            }
            lease = pool.acquire(self, role: role)
        }
    }

    func stop() {
        if isOnce { onceFinished = true }
        watchdog?.cancel()
        watchdog = nil
        if let lease {
            self.lease = nil
            pool.release(lease)
        }
        tearDownPlayer()
    }

    func videoLeaseDidChange(isLive: Bool) {
        if isLive {
            startPlayer()
        } else {
            tearDownPlayer()
            finishOnce()
        }
    }

    func waitUntilVisible(timeout: Duration) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while videoAlpha < 1 {
            guard clock.now < deadline else { throw CancellationError() }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func startPlayer() {
        guard player == nil, !onceFinished else { return }
        watchdog?.cancel()
        watchdog = nil
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.automaticallyWaitsToMinimizeStalling = false
        queue.preventsDisplaySleepDuringVideoPlayback = false
        switch playback {
        case .loop:
            looper = AVPlayerLooper(player: queue, templateItem: item)
        case .once:
            queue.actionAtItemEnd = .pause
            queue.insert(item, after: nil)
            watchEnd(of: item)
        }
        player = queue
        playerLayer.player = queue
        alpha = 0
        queue.play()
        tasks.append(Task { [weak self] in await self?.fadeInWhenReady() })
    }

    private func tearDownPlayer() {
        tasks.forEach { $0.cancel() }
        tasks = []
        looper?.disableLooping()
        looper = nil
        player?.pause()
        (player as? AVQueuePlayer)?.removeAllItems()
        player = nil
        playerLayer.player = nil
        alpha = 0
        accessibilityValue = "still"
    }

    /// Sondeo barato (50 ms, con tope): si el primer cuadro no llega, no queda un decodificador
    /// invisible vivo; se suelta el player y el lease, y se ve el póster.
    private func fadeInWhenReady() async {
        for _ in 0..<Self.readyPollLimit {
            if Task.isCancelled { return }
            if playerLayer.isReadyForDisplay {
                UIView.animate(withDuration: Self.fadeDuration) { self.alpha = 1 }
                accessibilityValue = "live"
                return
            }
            try? await Task.sleep(nanoseconds: Self.readyPollNanos)
        }
        if Task.isCancelled { return }
        giveUp()
    }

    private func giveUp() {
        if let lease {
            self.lease = nil
            pool.release(lease)
        }
        tearDownPlayer()
        finishOnce()
    }

    private func startWatchdog() {
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.watchdogSeconds))
            if Task.isCancelled { return }
            guard let self, self.player == nil else { return }
            self.finishOnce()
        }
    }

    private func watchEnd(of item: AVPlayerItem) {
        let center = NotificationCenter.default
        tasks.append(Task { [weak self] in
            for await _ in center.notifications(named: .AVPlayerItemDidPlayToEndTime, object: item).map({ _ in () }) {
                self?.finishOnce()
                return
            }
        })
        let asset = item.asset
        tasks.append(Task { [weak self] in
            let duration = (try? await asset.load(.duration).seconds) ?? 0
            let seconds = duration.isFinite ? duration : 0
            try? await Task.sleep(for: .seconds(seconds + 1))
            if Task.isCancelled { return }
            self?.finishOnce()
        })
    }

    private func finishOnce() {
        guard case .once(let onEnd) = playback, !onceFinished else { return }
        onceFinished = true
        onEnd()
    }
}
