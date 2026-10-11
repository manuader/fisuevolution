import AVFoundation
import SpriteKit

/// El par de `AnimatedArtView` para la escena: el póster siempre dibujado y, encima, un
/// `SKVideoNode` que funde al primer cuadro. El `AVQueuePlayer` nace cuando el pool lo pone vivo
/// y la escena lo pide visible (`setVisible`); se suelta al bajarlo o si el primer cuadro no llega.
/// La escena llama `setVisible(false)` al sacar el nodo de pantalla o al pausar; el `deinit` es sólo
/// la red de seguridad. El póster no puede ser vacío (se dibuja blanco y tapa lo de abajo): quien
/// lo crea pasa la textura real o una transparente.
///
/// `.once(onEnd:)` es el contrato de `AnimatedArtView`: una pasada y `onEnd` exactamente una vez,
/// en el acto si no hay video (sin entrada, política quieta, pack ODR sin bajar) y también si el
/// pool lo baja, el primer cuadro no llega o el vigía vence. `stop()` y el `deinit` no lo llaman.
@MainActor
final class LoopingVideoNode: SKNode, VideoLeaseHolder {
    private static let fadeDuration: TimeInterval = 0.15
    private static let readyPollNanos: UInt64 = 50_000_000
    private static let readyPollLimit = 40
    private static let watchdogSeconds = 1.0

    private var url: URL?
    private let clip: ArtClip
    private let manifest: LoopsManifest
    private let packs: ArtPacks
    private let role: VideoRole
    private let pool: VideoPlayerPool
    private var size: CGSize
    private let playback: ArtPlayback
    private let posterNode: SKSpriteNode
    private var lease: VideoPlayerPool.Lease?
    private var looper: AVPlayerLooper?
    private var readyTask: Task<Void, Never>?
    private var gaveUp = false
    private var wantsVisible = false
    private var requestedTag: String?
    private var waitToken: UUID?
    private var onceFinished = false
    private var watchdog: Task<Void, Never>?
    private var endTasks: [Task<Void, Never>] = []

    private var isOnce: Bool {
        if case .once = playback { return true }
        return false
    }

    private(set) var videoNode: SKVideoNode?
    private(set) var player: AVQueuePlayer?
    /// Si el primer cuadro llegó a verse alguna vez: distingue un `.once` visto de uno que nunca arrancó.
    private(set) var didShowVideo = false

    var videoAlpha: CGFloat { videoNode?.alpha ?? 0 }

    init(clip: ArtClip, poster: SKTexture, size: CGSize, role: VideoRole,
         playback: ArtPlayback = .loop, manifest: LoopsManifest = .main, pool: VideoPlayerPool = .shared, packs: ArtPacks = .shared) {
        self.url = manifest.url(for: clip, packs: packs)
        self.clip = clip
        self.manifest = manifest
        self.packs = packs
        self.role = role
        self.pool = pool
        self.size = size
        self.playback = playback
        self.posterNode = SKSpriteNode(texture: poster, size: size)
        super.init()
        posterNode.zPosition = 0
        addChild(posterNode)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LoopingVideoNode is never decoded")
    }

    deinit {
        if let lease { Task { @MainActor [pool] in pool.release(lease) } }
        if let requestedTag { Task { @MainActor [packs] in packs.release(requestedTag) } }
    }

    /// Sólo el piso visible y asentado anima. Sin video en el manifest, no hace nada; con el pack ODR
    /// sin bajar, lo pide y arranca cuando llega (un `.once` no espera: termina en el acto).
    func setVisible(_ visible: Bool) {
        wantsVisible = visible
        guard visible else {
            stop()
            return
        }
        requestPackIfNeeded()
        guard !onceFinished else { return }
        if isOnce, url == nil || !pool.policy.allowsLoops {
            finishOnce()
            return
        }
        guard url != nil, lease == nil, !gaveUp else { return }
        if isOnce { startWatchdog() }
        lease = pool.acquire(self, role: role)
    }

    /// El tamaño nuevo del póster y del video (la escena cambió de medida).
    func resize(_ size: CGSize) {
        self.size = size
        posterNode.size = size
        videoNode?.size = size
    }

    func stop() {
        if isOnce { onceFinished = true }
        wantsVisible = false
        gaveUp = false
        cancelWatchdog()
        releaseLease()
        if let requestedTag {
            self.requestedTag = nil
            if let waitToken { packs.cancelWait(requestedTag, token: waitToken) }
            waitToken = nil
            packs.release(requestedTag)
            url = manifest.url(for: clip, packs: packs)
        }
    }

    private func requestPackIfNeeded() {
        guard requestedTag == nil, let tag = manifest.odrTag(for: clip) else { return }
        requestedTag = tag
        packs.request(tag)
        waitToken = packs.whenAvailable(tag) { [weak self] in self?.packArrived() }
    }

    private func packArrived() {
        guard requestedTag != nil, url == nil else { return }
        url = manifest.url(for: clip, packs: packs)
        if wantsVisible, !onceFinished { setVisible(true) }
    }

    private func releaseLease() {
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

    struct NotVisibleError: Error {}

    func waitUntilVisible(timeout: Duration) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while videoAlpha < 1 {
            guard clock.now < deadline else { throw NotVisibleError() }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func startPlayer() {
        guard let url, player == nil, !onceFinished else { return }
        cancelWatchdog()
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
        let video = SKVideoNode(avPlayer: queue)
        video.size = size
        video.alpha = 0
        video.zPosition = 1
        addChild(video)
        videoNode = video
        video.play()
        queue.play()
        readyTask = Task { [weak self] in await self?.fadeInWhenReady() }
    }

    private func tearDownPlayer() {
        readyTask?.cancel()
        readyTask = nil
        endTasks.forEach { $0.cancel() }
        endTasks = []
        videoNode?.removeAllActions()
        videoNode?.pause()
        videoNode?.removeFromParent()
        videoNode = nil
        looper?.disableLooping()
        looper = nil
        player?.pause()
        player?.removeAllItems()
        player = nil
    }

    /// `SKVideoNode` no expone `isReadyForDisplay`: el primer cuadro decodificado se sabe por
    /// `readyToPlay` más un `currentTime` que ya avanzó. Si no llega, se suelta todo y queda el póster.
    private func fadeInWhenReady() async {
        for _ in 0..<Self.readyPollLimit {
            if Task.isCancelled { return }
            if let player, player.currentItem?.status == .readyToPlay, player.currentTime().seconds > 0 {
                didShowVideo = true
                videoNode?.run(.fadeIn(withDuration: Self.fadeDuration), withKey: "fadeIn")
                return
            }
            try? await Task.sleep(nanoseconds: Self.readyPollNanos)
        }
        if Task.isCancelled { return }
        gaveUp = true
        releaseLease()
        finishOnce()
    }

    /// Si el pool nunca lo pone vivo, un `.once` no puede quedar esperando para siempre.
    private func startWatchdog() {
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.watchdogSeconds))
            if Task.isCancelled { return }
            guard let self, self.player == nil else { return }
            self.releaseLease()
            self.finishOnce()
        }
    }

    private func cancelWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }

    /// El fin llega por la notificación del item o, de red de seguridad, por la duración más 1 s.
    private func watchEnd(of item: AVPlayerItem) {
        let center = NotificationCenter.default
        endTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: .AVPlayerItemDidPlayToEndTime, object: item).map({ _ in () }) {
                self?.finishOnce()
                return
            }
        })
        let asset = item.asset
        endTasks.append(Task { [weak self, weak item] in
            let duration = (try? await asset.load(.duration).seconds) ?? 0
            try? await Task.sleep(for: .seconds((duration.isFinite ? duration : 0) + 1))
            if Task.isCancelled { return }
            if item?.status == .failed { self?.releaseLease() }
            self?.finishOnce()
        })
    }

    private func finishOnce() {
        guard case .once(let onEnd) = playback, !onceFinished else { return }
        onceFinished = true
        cancelWatchdog()
        onEnd()
    }
}
