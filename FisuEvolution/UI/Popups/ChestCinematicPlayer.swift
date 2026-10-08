import AVFoundation
import SwiftUI

/// El tramo cinemático del cofre: `chest_open.mov` (HEVC con canal alfa
/// premultiplicado), del estallido al marco vacío, reproducido por hardware.
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
        warmup = Task { [weak self, player] in
            for _ in 0..<40 where player.currentItem?.status != .readyToPlay {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled,
                  player.currentItem?.status == .readyToPlay else { return }
            _ = await player.preroll(atRate: 1.0)
            guard !Task.isCancelled else { return }

            // ⚠️ **`preroll` NO alcanza para este archivo, y está medido.**
            //
            // Con sólo `preroll(atRate:)` la grabación mostraba **133 ms de
            // pantalla congelada en el primer cuadro del video** — el
            // "se traba al abrirse" que reportó el dueño tres veces. La causa:
            // `preroll` "prepara los render pipelines", pero el HEVC-con-alfa
            // se decodifica **por software en el simulador** (no hay camino de
            // hardware para la capa auxiliar de alfa), y ese arranque en frío
            // no se paga hasta que alguien pide cuadros de verdad.
            //
            // Así que se los pedimos: reproducir MUDO unos cuadros y volver a
            // cero deja la cola del decoder llena. Es invisible y silencioso —
            // la capa está en `opacity(0)` hasta el latido cinemático y el
            // volumen va en 0—, y corre en el hueco muerto de los toques.
            player.volume = 0
            player.playImmediately(atRate: 1.0)
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            player.pause()
            // Exacto y no aproximado: un seek con tolerancia puede dejar el
            // playhead en el keyframe más cercano y el video arrancaría unos
            // cuadros adentro, comiéndose el estallido.
            await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            guard !Task.isCancelled else { return }
            self?.isWarm = true
        }
    }

    /// El decoder ya escupió cuadros y el playhead volvió a cero. Si el jugador
    /// llega al tercer toque antes de que esto sea `true`, `play` se encarga de
    /// reposicionar — ver ahí.
    private var isWarm = false

    /// El mov trae su pista de sonido adentro; el volumen es el del canal SFX
    /// del juego, leído al momento de reproducir (con el overlay abierto no
    /// hay forma de cambiarlo a mitad de video).
    func play(rate: Float, volume: Float) {
        warmup?.cancel()
        player.volume = volume

        // ⚠️ El calentado puede haber quedado A MITAD si el jugador llegó al
        // tercer toque antes de que terminara: el playhead estaría unos cuadros
        // adentro y `playImmediately` se comería el estallido, que es el cuadro
        // más importante de la animación. En ese caso se reposiciona primero.
        //
        // El camino normal —calentado completo— no paga ese await: arranca en
        // este mismo frame.
        guard isWarm || player.currentTime() == .zero else {
            player.pause()
            Task { @MainActor [player] in
                await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                player.playImmediately(atRate: rate)
            }
            return
        }
        // `playImmediately` y no `play()` + `rate`: arranca en ESTE frame con
        // lo que el calentado dejó decodificado, sin renegociar el ritmo.
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

/// El `AVPlayerLayer` en SwiftUI, transparente: el alfa del HEVC compone
/// contra lo que haya detrás. `videoGravity: .resize` porque el frame lo
/// dicta la geometría del manifest (`cinematicStage`), no el video.
///
/// ⚠️⚠️ **`isOpaque` TIENE que quedar en `false`. No lo "optimices".**
///
/// Se probó ponerlo en `true` el 2026-09-06 razonando que el video ya no
/// tenía alfa, y **el resultado fue la pantalla entera en negro** al abrirse
/// el cofre: el tablero desaparecía y quedaba sólo la carta sobre un fondo
/// liso. El error de fondo fue el diagnóstico, y vale escribirlo porque
/// cualquiera lo repite:
///
/// **`ffprobe` NO puede ver el alfa de este archivo.** Reporta
/// `pix_fmt=yuv420p` y dos streams pelados (hevc + aac), como si fuera un
/// video opaco cualquiera. Pero el pipeline lo encodea con
/// `hevc_videotoolbox -alpha_quality`, o sea el **HEVC-con-alfa de Apple**,
/// que guarda el alfa en una capa auxiliar que ffmpeg no decodifica y por lo
/// tanto no lista. La prueba está del lado del generador
/// (`chest_video_frames.py`: `alphamerge` → `premultiply` → `format=bgra`
/// → `-alpha_quality`), no del lado del inspector.
///
/// Moraleja para el próximo: para saber si este mov tiene alfa, leé el
/// ENCODER, no el probe.
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
