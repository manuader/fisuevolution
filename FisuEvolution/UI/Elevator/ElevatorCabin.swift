import SwiftUI
import UIKit

/// El arte de la cabina, en orden de preferencia: el clip con alfa, los dos cuadros fijos, o el vectorial.
/// Cierra y abre van juntos: con un solo clip no hay video.
@MainActor
enum ElevatorCabinArt: Equatable {
    case video(close: URL, open: URL)
    case stills(closed: UIImage, open: UIImage)
    case vector

    /// Se resuelve una vez, no por cuadro. Si no hay clip, los dos cuadros quedan retenidos acá
    /// (~7 MB) mientras viva el proceso.
    static let shared = resolve()

    var isVideo: Bool { if case .video = self { true } else { false } }
    var isStills: Bool { if case .stills = self { true } else { false } }

    /// Los cuadros se leen sólo si no hay video: si el clip está, no ocupan memoria.
    static func resolve(
        url: (String) -> URL? = { Bundle.main.url(forResource: $0, withExtension: "mov") },
        image: (String) -> UIImage? = { name in
            Bundle.main.url(forResource: name, withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) }
        }
    ) -> ElevatorCabinArt {
        if let close = url("cabina_puertas_cierran"), let open = url("cabina_puertas_abren") {
            return .video(close: close, open: open)
        }
        if let closed = image("cabina_cerrada"), let open = image("cabina_abierta") {
            return .stills(closed: closed, open: open)
        }
        return .vector
    }
}

/// Dónde cae la cabina (el cuadro es de 720 × 1280) dentro de la pantalla.
enum CabinFrame {
    static let aspect: CGFloat = 720.0 / 1280.0

    /// Teléfono: el cuadro cubre la pantalla (aspect fill). iPad: al alto, centrado; los costados son pared.
    static func rect(in size: CGSize) -> CGRect {
        let scale = size.width / size.height <= 0.6
            ? max(size.width / 720, size.height / 1280)
            : size.height / 1280
        let fitted = CGSize(width: 720 * scale, height: 1280 * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }
}

/// Los dos clips de la cabina calentados, de a uno. Se preparan al abrir la placa o el mapa
/// (`prepare()`), nunca al elegir el piso: el arranque en frío del HEVC con alfa congela el primer cuadro.
///
/// Memoria: vive un solo player por vez. El de "abre" se crea cuando arranca el tramo de viaje
/// (hay ≥ 300 ms para calentarlo) y el de "cierra" se suelta al abrir las puertas. Si nadie usa el
/// que se preparó, se suelta solo.
@MainActor
final class ElevatorCabinWarmup {
    static let shared = ElevatorCabinWarmup()

    private static let patience: Duration = .seconds(45)

    private var closing: (url: URL, player: ChestCinematicPlayer)?
    private var opening: (url: URL, player: ChestCinematicPlayer)?
    private var expiry: Task<Void, Never>?
    private let pool: VideoPlayerPool
    private var reservation: VideoPlayerPool.Reservation?

    init(pool: VideoPlayerPool = .shared) {
        self.pool = pool
    }

    /// Idempotente y sin esperar: el calentado corre en el `Task` del player.
    func prepare(art: ElevatorCabinArt = .shared) {
        guard case .video(let close, _) = art, !UIAccessibility.isReduceMotionEnabled else { return }
        _ = closingPlayer(url: close)
        reserveDecoder()
        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(for: Self.patience)
            guard !Task.isCancelled else { return }
            self?.release()
        }
    }

    /// Para dibujar: no crea nada. `nil` si todavía no se creó, ya se soltó o falló.
    func currentClosing(url: URL) -> ChestCinematicPlayer? {
        closing.flatMap { $0.url == url && Self.isUsable($0.player) ? $0.player : nil }
    }

    func currentOpening(url: URL) -> ChestCinematicPlayer? {
        opening.flatMap { $0.url == url && Self.isUsable($0.player) ? $0.player : nil }
    }

    /// El viaje arrancó: el calentado ya no vence.
    func cancelExpiry() {
        expiry?.cancel()
        expiry = nil
    }

    /// Mientras la cabina tiene un player calentado, el pool le deja uno de sus tres decodificadores.
    private func reserveDecoder() {
        guard reservation == nil else { return }
        reservation = pool.reserve()
    }

    private func unreserveDecoder() {
        guard let reservation else { return }
        pool.unreserve(reservation)
        self.reservation = nil
    }

    private static func isUsable(_ player: ChestCinematicPlayer) -> Bool {
        player.player.currentItem.map { $0.status != .failed } ?? false
    }

    func closingPlayer(url: URL) -> ChestCinematicPlayer {
        if let closing, closing.url == url { return closing.player }
        Self.dispose(closing?.player)
        let player = ChestCinematicPlayer(url: url)
        closing = (url, player)
        return player
    }

    func openingPlayer(url: URL) -> ChestCinematicPlayer {
        if let opening, opening.url == url { return opening.player }
        Self.dispose(opening?.player)
        let player = ChestCinematicPlayer(url: url)
        opening = (url, player)
        return player
    }

    /// Las puertas ya abren: el player de "cierra" no se usa más.
    func releaseClosing() {
        Self.dispose(closing?.player)
        closing = nil
    }

    func release() {
        expiry?.cancel()
        expiry = nil
        unreserveDecoder()
        releaseClosing()
        Self.dispose(opening?.player)
        opening = nil
    }

    private static func dispose(_ player: ChestCinematicPlayer?) {
        player?.player.pause()
        player?.player.replaceCurrentItem(with: nil)
    }
}

// MARK: - La cabina vectorial

/// La cabina dibujada, para cuando no hay clip ni cuadros. `doors`: 0 abiertas, 1 cerradas.
/// El hueco y las ventanas quedan transparentes: detrás se ve lo que haya.
struct VectorCabin: View {
    var doors: Double

    private static let opening = CGRect(x: 0.18, y: 0.18, width: 0.64, height: 0.73)
    private static let board = CGRect(x: 0.30, y: 0.075, width: 0.40, height: 0.06)
    private static let steel = [MetalTone.light, MetalTone.base]
    private static let steelEdge = MetalTone.dark

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let hole = Self.scaled(Self.opening, in: size)
            ZStack(alignment: .topLeading) {
                VectorCabin.wall
                    .fill(Color("PaletteCream"), style: FillStyle(eoFill: true))
                    .overlay(VectorCabin.wall.stroke(Color("PaletteInk"), lineWidth: 2.5))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color("PaletteYellow"), lineWidth: 5)
                    .frame(width: hole.width, height: hole.height)
                    .offset(x: hole.minX, y: hole.minY)
                leaves(in: hole)
                boardPlate(in: size)
            }
        }
        .accessibilityHidden(true)
    }

    /// La pared: todo el cuadro menos el hueco de las puertas (relleno par-impar).
    private static let wall = HoleShape(hole: opening)

    private func leaves(in hole: CGRect) -> some View {
        let leafWidth = hole.width / 2
        let slide = (1 - doors) * leafWidth
        return ZStack(alignment: .topLeading) {
            leaf(width: leafWidth, height: hole.height).offset(x: -slide)
            leaf(width: leafWidth, height: hole.height).offset(x: leafWidth + slide)
        }
        .frame(width: hole.width, height: hole.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .offset(x: hole.minX, y: hole.minY)
    }

    private func leaf(width: CGFloat, height: CGFloat) -> some View {
        let window = CGRect(x: width * 0.2, y: height * 0.12, width: width * 0.6, height: height * 0.3)
        return ZStack(alignment: .topLeading) {
            HoleShape(hole: CGRect(x: 0.2, y: 0.12, width: 0.6, height: 0.3), cornerRadius: 0.12)
                .fill(LinearGradient(colors: Self.steel, startPoint: .top, endPoint: .bottom),
                      style: FillStyle(eoFill: true))
                .overlay(Rectangle().strokeBorder(Self.steelEdge, lineWidth: 2.5))
            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                .strokeBorder(Color("PaletteYellow"), lineWidth: 3)
                .frame(width: window.width, height: window.height)
                .offset(x: window.minX, y: window.minY)
            ForEach(0..<4, id: \.self) { corner in
                PanelScrew(fill: MetalTone.screw, line: MetalTone.dark, diameter: 9)
                    .offset(x: corner % 2 == 0 ? 7 : width - 16, y: corner < 2 ? height * 0.55 : height - 16)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func boardPlate(in size: CGSize) -> some View {
        let plate = Self.scaled(Self.board, in: size)
        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(LinearGradient(colors: Self.steel, startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
            .frame(width: plate.width, height: plate.height)
            .offset(x: plate.minX, y: plate.minY)
    }

    private static func scaled(_ unit: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: unit.minX * size.width, y: unit.minY * size.height,
               width: unit.width * size.width, height: unit.height * size.height)
    }
}

/// Un rectángulo con un hueco redondeado, en coordenadas unitarias; se rellena con `eoFill`.
private struct HoleShape: Shape {
    let hole: CGRect
    var cornerRadius: CGFloat = 0.02

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let frame = CGRect(x: rect.minX + hole.minX * rect.width, y: rect.minY + hole.minY * rect.height,
                           width: hole.width * rect.width, height: hole.height * rect.height)
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: cornerRadius * rect.width, height: cornerRadius * rect.width))
        return path
    }
}
