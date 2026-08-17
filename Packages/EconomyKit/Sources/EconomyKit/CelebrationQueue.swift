import Foundation

/// Cada cosa que la app muestra SOLA y que narra algo: premios, celebraciones,
/// avisos.
///
/// Quedan afuera las pantallas que abre el jugador (tienda, mejoras, ficha) y la
/// reencarnación, que sale de un botón: ésas no compiten por atención, las pidió
/// él.
public enum CelebrationKind: String, CaseIterable, Hashable, Sendable {
    /// Lo que ganaste mientras no estabas.
    case offlineEarnings
    /// El premio del día.
    case dailyReward
    /// La elección de carrera de T9.
    case careerChoice
    /// Vuelo del ascenso + reveal del personaje + celebración de piso nuevo.
    /// Son UN ítem: se encadenan entre sí dentro de la escena.
    case boardCelebration
    /// La skin que te ganaste por milestone.
    case skinAward
    /// El special que te cayó.
    case specialDrop
    /// La franja del evento activo.
    case eventBanner
    /// Los logros recién conseguidos. Es UN casillero para toda la tanda: la
    /// sub-cola de toasts los desfila adentro con su título cada uno.
    case achievements
    /// El aviso de la torre (piso lleno, ya podés contratar acá…).
    case towerNotice

    /// Menor es antes. Los de arranque de sesión primero —cobrás y seguís—, la
    /// carrera antes que las celebraciones porque BLOQUEA la progresión (hasta
    /// que elegís, los merges de ese tier no se resuelven), y los avisos chicos
    /// al final.
    public var priority: Int {
        switch self {
        case .offlineEarnings, .dailyReward: 1
        case .careerChoice: 2
        case .boardCelebration: 3
        case .skinAward, .specialDrop: 4
        case .eventBanner: 5
        case .achievements, .towerNotice: 6
        }
    }

    /// Cuánto se le tolera a un ítem que se cierra solo antes de destrabarlo.
    /// `nil` = lo cierra el jugador y espera lo que haga falta.
    ///
    /// **No compite con la animación**: va con margen sobre lo que dura de
    /// verdad. Es una red para el caso en que la señal de "terminé" no llegue
    /// nunca, que con una cola global congelaría TODAS las celebraciones hasta
    /// reiniciar la app.
    public var timeout: TimeInterval? {
        switch self {
        case .offlineEarnings, .dailyReward, .careerChoice, .skinAward, .specialDrop: nil
        case .boardCelebration: 8
        case .eventBanner: 6
        // Cubre unos diez toasts seguidos; pasado eso corta y lo loguea.
        case .achievements: 30
        case .towerNotice: 4
        }
    }

    /// Se puede saltear con un tap exactamente lo que se cierra solo. Un sheet
    /// tiene su botón: un tap al vacío no lo cierra.
    public var isSkippable: Bool { timeout != nil }
}

/// Hace que las celebraciones se reproduzcan **de a una**.
///
/// Guarda turnos, no contenidos: los payloads (`skinAward`, `dailyClaim`…) siguen
/// viviendo en `GameState` y se muestran sólo cuando esta cola dice que es su
/// turno. Por eso es pura y `Sendable`, y por eso EconomyKit puede tenerla sin
/// conocer un solo tipo de UI.
public struct CelebrationQueue: Sendable, Equatable {
    /// Cuánto tiene que llevar un ítem en pantalla antes de que un tap lo pueda
    /// saltear.
    ///
    /// Sin este piso las celebraciones no se llegarían a ver: el tap es el verbo
    /// principal del juego y el jugador tapea varias veces por segundo, así que
    /// el siguiente tap mataría el reveal a los 0,3 s, la cola avanzaría, y el
    /// próximo mataría al que sigue. La cola se vaciaría en un segundo.
    public static let skipFloor: TimeInterval = 0.6

    /// Lo que se está mostrando ahora.
    public private(set) var current: CelebrationKind?
    /// Segundos que lleva `current` en pantalla.
    public private(set) var elapsed: TimeInterval = 0

    private var pending: [CelebrationKind] = []

    public init() {}

    /// Pone un ítem en la fila. **Deduplica**: encolar `.achievements` tres veces
    /// deja un solo casillero, que es lo que agrupa la tanda de logros sin
    /// lógica aparte.
    public mutating func enqueue(_ kind: CelebrationKind) {
        guard current != kind, !pending.contains(kind) else { return }
        pending.append(kind)
        promoteIfIdle()
    }

    /// Libera el turno.
    ///
    /// Es **idempotente y tolerante al ítem equivocado** a propósito: el
    /// completion de la animación, el tap del jugador y el watchdog pueden llegar
    /// los tres por el mismo ítem, y si cualquiera de esas repeticiones avanzara
    /// la cola se comería la celebración siguiente.
    public mutating func finish(_ kind: CelebrationKind) {
        guard current == kind else {
            pending.removeAll { $0 == kind }
            return
        }
        current = nil
        elapsed = 0
        promoteIfIdle()
    }

    /// El jugador tocó la pantalla. Devuelve `true` si eso salteó algo, así el
    /// llamador no tiene que consultar el estado antes de pedirlo.
    @discardableResult
    public mutating func skip() -> Bool {
        guard let current, current.isSkippable, elapsed >= Self.skipFloor else { return false }
        finish(current)
        return true
    }

    /// Avanza el reloj del ítem actual. Devuelve el ítem que el watchdog
    /// destrabó —para poder loguearlo— o `nil`.
    ///
    /// Se llama desde el tick que ya corre por frame: sin `Timer` (regla 2 de
    /// concurrencia) y con tests que inyectan deltas en vez de esperar segundos
    /// reales.
    public mutating func tick(_ delta: TimeInterval) -> CelebrationKind? {
        guard let showing = current else { return nil }
        elapsed += delta
        guard let timeout = showing.timeout, elapsed >= timeout else { return nil }
        finish(showing)
        return showing
    }

    private mutating func promoteIfIdle() {
        guard current == nil, !pending.isEmpty else { return }
        // `min(by:)` sobre el índice conserva el orden de llegada dentro de la
        // misma prioridad; ordenar el array entero no lo garantiza.
        var bestIndex = 0
        for index in pending.indices where pending[index].priority < pending[bestIndex].priority {
            bestIndex = index
        }
        current = pending.remove(at: bestIndex)
        elapsed = 0
    }
}
