import AVFoundation
import SwiftUI
import UIKit

/// La cinemática a pantalla completa (PLAN-v2 E8): opaca, con su sonido al volumen de efectos y la
/// música abajo. Es el ítem `.cinematic` de la cola: cerrarla (fin, "Saltar") es
/// `celebrationFinished(.cinematic)`, que la anota vista.
///
/// No es un `sheet`, por lo mismo que el cofre: el arrastre de una hoja la cortaría a la mitad. Y se
/// come los toques: el tablero de abajo no los recibe, así que un tap no la saltea por la cola.
struct CinematicOverlay: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.horizontalSizeClass) private var sizeClass
    let id: CinematicID

    @State private var canSkip = false
    @State private var finished = false

    /// La hoja que la abrió (reencarnar, el popup del visitante) termina de bajar.
    static let sheetSettle: Duration = .milliseconds(350)
    static let skipDelay: Duration = .seconds(1)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)
            if let url = LoopsManifest.main.cinematicURL(for: id) {
                CinematicVideoLayer(
                    url: url, fills: sizeClass != .regular,
                    volume: Float(gameState.audio?.sfxVolume ?? 1),
                    onPlay: showSkipSoon, onEnd: finish
                )
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(LocalizedStringKey("cinematic.\(id.rawValue).a11y")))
                .accessibilityIdentifier("cinematic.player")
            }
            if canSkip {
                Button(action: finish) {
                    Text("cinematic.skip")
                        .font(Tokens.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Tokens.s16)
                        .padding(.vertical, Tokens.s8)
                        .background(Capsule().fill(Color("PaletteInk").opacity(0.55)))
                }
                .accessibilityIdentifier("cinematic.skip")
                .padding(Tokens.s16)
                .transition(.opacity)
            }
        }
        .onAppear {
            gameState.audio?.setMusicDucked(true)
            if LoopsManifest.main.cinematicURL(for: id) == nil { finish() }
        }
        .onDisappear { gameState.audio?.setMusicDucked(false) }
    }

    private func showSkipSoon() {
        Task {
            try? await Task.sleep(for: Self.skipDelay)
            withAnimation(.easeInOut(duration: 0.2)) { canSkip = true }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        gameState.audio?.setMusicDucked(false)
        gameState.celebrationFinished(.cinematic)
    }
}

/// El video de la cinemática. Toma el lease `fullscreen` del pool (que suspende a todos los demás
/// mientras vive) y lo suelta siempre. Si la política no deja cinemáticas (Reduce Motion, sin
/// reproducción automática, segundo plano) o el pool la baja, se cierra en el acto.
///
/// ⚠️ `isOpaque = false` aunque el video sea opaco: la regla de `ChestCinematicView` (con `true`, la
/// pantalla entera en negro el 2026-09-06).
private struct CinematicVideoLayer: UIViewRepresentable {
    let url: URL
    let fills: Bool
    let volume: Float
    let onPlay: @MainActor () -> Void
    let onEnd: @MainActor () -> Void

    func makeUIView(context: Context) -> CinematicVideoUIView {
        CinematicVideoUIView(url: url, volume: volume, onPlay: onPlay, onEnd: onEnd, pool: .shared)
    }

    func updateUIView(_ view: CinematicVideoUIView, context: Context) {
        view.fills = fills
    }

    static func dismantleUIView(_ view: CinematicVideoUIView, coordinator: ()) {
        view.stop()
    }
}

@MainActor
final class CinematicVideoUIView: UIView, VideoLeaseHolder {
    private static let readyPollLimit = 40
    private static let endMargin: Double = 1

    private let url: URL
    private let volume: Float
    private let onPlay: @MainActor () -> Void
    private let onEnd: @MainActor () -> Void
    private let pool: VideoPlayerPool
    private var lease: VideoPlayerPool.Lease?
    private var player: AVPlayer?
    private var task: Task<Void, Never>?
    private var ended = false

    var fills = true {
        didSet { playerLayer.videoGravity = fills ? .resizeAspectFill : .resizeAspect }
    }

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer {
        // layerClass fija el tipo: el cast no puede fallar.
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }

    init(url: URL, volume: Float, onPlay: @escaping @MainActor () -> Void,
         onEnd: @escaping @MainActor () -> Void, pool: VideoPlayerPool) {
        self.url = url
        self.volume = volume
        self.onPlay = onPlay
        self.onEnd = onEnd
        self.pool = pool
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stop()
        } else if lease == nil, !ended {
            guard pool.policy.allowsCinematics else {
                Task { finish() }
                return
            }
            lease = pool.acquire(self, role: .fullscreen)
        }
    }

    func stop() {
        ended = true
        task?.cancel()
        task = nil
        if let lease {
            self.lease = nil
            pool.release(lease)
        }
        tearDownPlayer()
    }

    func videoLeaseDidChange(isLive: Bool) {
        if isLive {
            guard player == nil, !ended else { return }
            task = Task { [weak self] in await self?.run() }
        } else {
            finish()
        }
    }

    /// Prerrollea mientras la hoja que la abrió termina de bajar y arranca. Con tope: un item que
    /// nunca está listo no cuelga nada (el watchdog de la cola lo destraba igual).
    private func run() async {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false
        player.volume = volume
        self.player = player
        playerLayer.player = player
        try? await Task.sleep(for: CinematicOverlay.sheetSettle)
        for _ in 0..<Self.readyPollLimit where item.status != .readyToPlay {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard !Task.isCancelled, item.status == .readyToPlay else { return finish() }
        _ = await player.preroll(atRate: 1)
        guard !Task.isCancelled else { return }
        player.playImmediately(atRate: 1)
        onPlay()
        let duration = (try? await item.asset.load(.duration).seconds) ?? 0
        await awaitEnd(of: item, timeout: (duration.isFinite ? duration : 0) + Self.endMargin)
        finish()
    }

    private func awaitEnd(of item: AVPlayerItem, timeout: Double) async {
        let notifications = NotificationCenter.default.notifications(
            named: AVPlayerItem.didPlayToEndTimeNotification, object: item
        )
        let deadline = ContinuousClock.now + .seconds(timeout)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for await _ in notifications { break } }
            group.addTask { try? await Task.sleep(until: deadline) }
            await group.next()
            group.cancelAll()
        }
    }

    private func tearDownPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerLayer.player = nil
    }

    private func finish() {
        guard !ended else { return }
        stop()
        onEnd()
    }
}
