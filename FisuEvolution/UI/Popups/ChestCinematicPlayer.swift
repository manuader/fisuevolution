import AVFoundation
import SwiftUI

/// El tramo cinemático del cofre: `chest_open.mov` (HEVC con canal alfa),
/// del estallido al marco vacío, reproducido por hardware.
///
/// Es el primer AVFoundation del repo, y entra por una razón medida: las 8 s
/// lineales del estallido a la carta pesan ~3 MB en HEVC contra ~12 MB en
/// frames PNG, con 24 fps garantizados por el decoder. Los tramos que
/// responden al dedo (idle y sacudidas) siguen siendo frames de
/// `ChestAnimationFeed`: un tap pide el swap en el mismo cuadro y un seek de
/// AVPlayer mete latencia variable.
///
/// El item termina PAUSADO en su último frame (`actionAtItemEnd = .pause`):
/// el marco vacío queda en pantalla y el contenido del premio se renderiza
/// encima. `awaitEnd` espera la notificación real de fin — con un tope por si
/// el decoder se traba, porque un latido colgado dejaría la cola de
/// celebraciones muda para siempre.
@MainActor
final class ChestCinematicPlayer {
    let player: AVPlayer

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        // Sin esto el primer `play()` paga el arranque del decoder; el
        // overlay crea el player latidos antes de reproducirlo.
        player.preroll(atRate: 1)
    }

    func play(rate: Float) {
        player.play()
        player.rate = rate
    }

    /// Espera el fin real del video (o el tope). El tope no es adorno: si el
    /// item nunca llega al final, el latido que espera colgaría la animación
    /// y con ella la cola entera.
    func awaitEnd(timeout: Double) async {
        guard let item = player.currentItem else { return }
        let notifications = NotificationCenter.default.notifications(
            named: AVPlayerItem.didPlayToEndTimeNotification, object: item
        )
        let deadline = ContinuousClock.now + .seconds(timeout)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in notifications { break }
            }
            group.addTask {
                try? await Task.sleep(until: deadline)
            }
            await group.next()
            group.cancelAll()
        }
    }
}

/// El `AVPlayerLayer` en SwiftUI, transparente: el alfa del HEVC compone
/// contra lo que haya detrás. `videoGravity: .resize` porque el frame lo
/// dicta la geometría del manifest (`cinematicStage`), no el video.
struct ChestCinematicView: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerContainer: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerContainer {
        let view = PlayerContainer()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resize
        return view
    }

    func updateUIView(_ view: PlayerContainer, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }
}
