import SwiftUI

/// El playhead de la animación del cofre: qué segmento corre, qué frame toca
/// según el reloj, y los bitmaps decodificados por delante del dedo.
///
/// La vista lo consulta desde un `TimelineView(.animation(paused:))`: el
/// índice sale de la FECHA del timeline (no de contar ticks), así que un
/// cuadro que el hilo se comió se saltea solo y la animación nunca deriva.
/// `isPaused` se prende al llegar al último frame y con él muere el display
/// link — la regla del design system: ningún reloj corriendo incondicional.
///
/// La memoria es la razón de que esto exista: los 34 frames del estallido
/// decodificados a la vez son ~75 MB. La ventana deslizante decodifica ~8 por
/// delante del playhead en background (`preparingForDisplay`) y va soltando lo
/// que quedó atrás, con un pico de <20 MB que se libera entero al cerrar el
/// overlay.
@MainActor
@Observable
final class ChestAnimationFeed {
    /// En qué frame clavarse cuando el segmento no se reproduce.
    enum FramePin { case first, last }

    private static let prefetchWindow = 8

    let animation: ChestAnimation?

    private(set) var segment: ChestAnimation.Segment = .idle
    private(set) var displayed: UIImage?
    private(set) var displayedIndex = 0
    private(set) var isPaused = true

    private var startDate: Date?
    private var cache: [Int: UIImage] = [:]
    private var inFlight: Set<Int> = []
    private var generation = 0

    init(animation: ChestAnimation?) {
        self.animation = animation
    }

    /// Clava un segmento sin reproducirlo (el idle de la espera, o el estado
    /// final con Reduce Motion). Decodifica ese único frame en el acto.
    func show(_ segment: ChestAnimation.Segment, frame pin: FramePin = .first) {
        guard let animation else { return }
        beginSegment(segment)
        isPaused = true
        startDate = nil
        let index = pin == .first ? 0 : animation.info(segment).frameCount - 1
        displayedIndex = index
        displayed = decodeNow(index)
    }

    /// Arranca un segmento desde su primer frame. El reloj es la fecha que se
    /// le pasa (la misma familia de fechas que el `TimelineView` consulta).
    func play(_ segment: ChestAnimation.Segment, at date: Date = .now) {
        guard animation != nil else { return }
        beginSegment(segment)
        isPaused = false
        startDate = date
        displayedIndex = 0
        displayed = decodeNow(0)
        prefetch(after: 0)
    }

    /// El frame que corresponde a esta fecha, recortado al rango del segmento.
    func index(at date: Date) -> Int {
        guard let animation, let startDate else { return displayedIndex }
        let elapsed = date.timeIntervalSince(startDate)
        let raw = Int(elapsed * animation.fps)
        return min(max(raw, 0), animation.info(segment).frameCount - 1)
    }

    /// El tick de la vista: mueve el playhead, publica el bitmap si ya está
    /// decodificado (si no, sostiene el anterior — un cuadro tarde no se ve;
    /// un hueco en blanco sí) y apaga el reloj al llegar al final.
    func advance(to date: Date) {
        guard animation != nil, !isPaused else { return }
        let target = index(at: date)
        if target != displayedIndex,
           // El rescate sync (~3 ms) cuando la ventana no llegó: preferible a
           // sostener un frame viejo. Si el background lo trae después, pisa el
           // caché con la versión preparada y no pasa nada.
           let image = cache[target] ?? decodeNow(target) {
            displayed = image
            displayedIndex = target
            trim(before: target)
        }
        prefetch(after: displayedIndex)
        // Se pausa cuando el último frame efectivamente SE MOSTRÓ (no cuando el
        // reloj lo alcanzó): pausar congela el timeline de la vista, y un final
        // que todavía no decodificó quedaría sin dibujar para siempre.
        if displayedIndex == lastIndex { isPaused = true }
    }

    /// Precalienta un segmento entero hacia adelante sin mostrarlo, para pagar
    /// el decode ANTES del latido que lo reproduce (la sacudida tras el
    /// aterrizaje, el estallido cuando el segundo toque anuncia la rareza).
    func warm(_ segment: ChestAnimation.Segment) {
        guard segment != self.segment else { return }
        guard let animation else { return }
        let urls = animation.frames(segment)
        let capturedGeneration = generation
        for (index, url) in urls.prefix(Self.prefetchWindow).enumerated() {
            decodeInBackground(index: index, url: url, into: segment, generation: capturedGeneration)
        }
    }

    private var lastIndex: Int {
        guard let animation else { return 0 }
        return animation.info(segment).frameCount - 1
    }

    private func beginSegment(_ new: ChestAnimation.Segment) {
        guard new != segment || displayed == nil else {
            // Reproducir de nuevo el mismo segmento (el tercer toque repite la
            // sacudida A): el caché que quede sigue valiendo, no se tira.
            return
        }
        segment = new
        generation += 1
        inFlight = []
        // Lo que `warm` precalentó para ESTE segmento entra como caché inicial.
        cache = warmedPerSegment.removeValue(forKey: new) ?? [:]
    }

    /// Frames precalentados por `warm` para segmentos que todavía no corren.
    private var warmedPerSegment: [ChestAnimation.Segment: [Int: UIImage]] = [:]

    private func decodeNow(_ index: Int) -> UIImage? {
        if let cached = cache[index] { return cached }
        guard let animation else { return nil }
        let urls = animation.frames(segment)
        guard urls.indices.contains(index),
              let image = UIImage(contentsOfFile: urls[index].path)
        else { return nil }
        cache[index] = image
        return image
    }

    private func prefetch(after index: Int) {
        guard let animation else { return }
        let urls = animation.frames(segment)
        let capturedGeneration = generation
        for next in (index + 1)...(index + Self.prefetchWindow) where urls.indices.contains(next) {
            guard cache[next] == nil, !inFlight.contains(next) else { continue }
            inFlight.insert(next)
            decodeInBackground(index: next, url: urls[next], into: segment, generation: capturedGeneration)
        }
    }

    private func decodeInBackground(
        index: Int,
        url: URL,
        into segment: ChestAnimation.Segment,
        generation: Int
    ) {
        Task.detached(priority: .userInitiated) {
            let image = UIImage(contentsOfFile: url.path)?.preparingForDisplay()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.inFlight.remove(index)
                guard let image else { return }
                if generation == self.generation, segment == self.segment {
                    self.cache[index] = image
                } else if segment != self.segment {
                    self.warmedPerSegment[segment, default: [:]][index] = image
                }
            }
        }
    }

    /// Suelta lo que el playhead ya dejó atrás, menos el frame vigente.
    private func trim(before index: Int) {
        for key in cache.keys where key < index - 1 {
            cache.removeValue(forKey: key)
        }
    }
}
