import AVFoundation
import SpriteKit

/// El par de `AnimatedArtView` para la escena: el póster siempre dibujado y, encima, un
/// `SKVideoNode` que funde al primer cuadro. El `AVQueuePlayer` nace cuando el pool lo pone vivo
/// y la escena lo pide visible (`setVisible`); se suelta al bajarlo o si el primer cuadro no llega.
/// La escena llama `setVisible(false)` al sacar el nodo de pantalla o al pausar; el `deinit` es sólo
/// la red de seguridad. El póster no puede ser vacío (se dibuja blanco y tapa lo de abajo): quien
/// lo crea pasa la textura real o una transparente.
@MainActor
final class LoopingVideoNode: SKNode, VideoLeaseHolder {
    private static let fadeDuration: TimeInterval = 0.15
    private static let readyPollNanos: UInt64 = 50_000_000
    private static let readyPollLimit = 40

    private var url: URL?
    private let clip: ArtClip
    private let manifest: LoopsManifest
    private let packs: ArtPacks
    private let role: VideoRole
    private let pool: VideoPlayerPool
    private let size: CGSize
    private let posterNode: SKSpriteNode
    private var lease: VideoPlayerPool.Lease?
    private var looper: AVPlayerLooper?
    private var player: AVQueuePlayer?
    private var readyTask: Task<Void, Never>?
    private var gaveUp = false
    private var wantsVisible = false
    private var requestedTag: String?
    private var waitToken: UUID?

    private(set) var videoNode: SKVideoNode?

    var videoAlpha: CGFloat { videoNode?.alpha ?? 0 }

    init(clip: ArtClip, poster: SKTexture, size: CGSize, role: VideoRole,
         manifest: LoopsManifest = .main, pool: VideoPlayerPool = .shared, packs: ArtPacks = .shared) {
        self.url = manifest.url(for: clip, packs: packs)
        self.clip = clip
        self.manifest = manifest
        self.packs = packs
        self.role = role
        self.pool = pool
        self.size = size
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
    /// sin bajar, lo pide y arranca cuando llega.
    func setVisible(_ visible: Bool) {
        wantsVisible = visible
        if visible {
            requestPackIfNeeded()
            guard url != nil, lease == nil, !gaveUp else { return }
            lease = pool.acquire(self, role: role)
        } else {
            stop()
        }
    }

    func stop() {
        wantsVisible = false
        gaveUp = false
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
        if wantsVisible { setVisible(true) }
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
        guard let url, player == nil else { return }
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.automaticallyWaitsToMinimizeStalling = false
        queue.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
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
                videoNode?.run(.fadeIn(withDuration: Self.fadeDuration), withKey: "fadeIn")
                return
            }
            try? await Task.sleep(nanoseconds: Self.readyPollNanos)
        }
        if Task.isCancelled { return }
        gaveUp = true
        releaseLease()
    }
}
