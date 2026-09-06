import AVFoundation
import SwiftUI

/// El tramo cinemático del cofre: `chest_open.mov` (HEVC premultiplicado, sin
/// canal alfa), del estallido al marco vacío, reproducido por hardware.
///
/// Es el primer AVFoundation del repo, y entra por una razón medida: los
/// ~4 s lineales del estallido a la carta pesan ~1,6 MB en HEVC contra ~12 MB
/// en frames PNG, con los 48 fps del retime garantizados por el decoder. Los
/// tramos que responden al dedo (idle y sacudidas) siguen siendo frames de
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
    private var warmup: Task<Void, Never>?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        // Archivo local del bundle: sin esperas "inteligentes" de buffering.
        // Con el default en `true`, el primer `play` puede diferir el arranque
        // y el empalme f49→f50 se ve como un cofre congelado en la agachada.
        player.automaticallyWaitsToMinimizeStalling = false
        // El preroll DE VERDAD, cuando el item está listo. Directo en el init
        // lanza NSException (SIGABRT con status `.unknown`, medido en el
        // primer smoke), así que primero se espera `readyToPlay` — con un
        // poll barato en el MainActor, porque KVO mete un closure @Sendable
        // que no convive con AVPlayer bajo strict concurrency. El overlay
        // crea este player en la llegada: latidos enteros de margen para que
        // el decoder ya tenga los primeros frames listos al tercer toque.
        warmup = Task { [player] in
            for _ in 0..<40 where player.currentItem?.status != .readyToPlay {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled,
                  player.currentItem?.status == .readyToPlay else { return }
            _ = await player.preroll(atRate: 1.0)
        }
    }

    /// El mov trae su pista de sonido adentro; el volumen es el del canal SFX
    /// del juego, leído al momento de reproducir (con el overlay abierto no
    /// hay forma de cambiarlo a mitad de video).
    func play(rate: Float, volume: Float) {
        warmup?.cancel()
        player.volume = volume
        // `playImmediately` y no `play()` + `rate`: arranca en ESTE frame con
        // lo que el preroll dejó decodificado, sin renegociar el ritmo.
        player.playImmediately(atRate: rate)
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

/// El `AVPlayerLayer` en SwiftUI. `videoGravity: .resize` porque el frame lo
/// dicta la geometría del manifest (`cinematicStage`), no el video.
///
/// ⚠️ **La capa es OPACA, y eso cambió**: hasta la sesión del velo el mov era
/// HEVC **con canal alfa** y componía contra el tablero, así que la vista iba
/// `isOpaque = false` + fondo `.clear`. Desde que el video se premultiplica,
/// el asset embarcado es `yuv420p` PLANO —verificado con ffprobe: dos
/// streams, hevc + aac, sin pista de alfa— y `.resize` hace que el video
/// cubra los bounds enteros. La transparencia había quedado como herencia del
/// asset viejo, y no era gratis: obligaba al compositor a mezclar una capa de
/// ~1320×2350 px contra lo de atrás **en cada cuadro**, para un contenido que
/// no tiene un solo píxel translúcido.
///
/// El recorte del encuadre y el feather del borde son del PROPIO video (los
/// trae horneados), no de la capa: apagar la transparencia no los toca.
struct ChestCinematicView: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerContainer: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerContainer {
        let view = PlayerContainer()
        view.isOpaque = true
        view.backgroundColor = .black
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
