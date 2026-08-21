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
    /// Una lección contextual del tutorial: el coach-mark que enseña una
    /// pantalla la primera vez que hay algo que HACER en ella. Viaja por la
    /// cola como cualquier celebración: así el "de a una" y el no-pisarse no
    /// son un caso especial del tutorial, son la regla de siempre.
    case tutorialTip

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
        // Una lección puede esperar a todo el mundo: enseña una pantalla que
        // no se va a ir a ningún lado.
        case .tutorialTip: 7
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
        // Lo que tarda en leerse el globo con margen: una lección ignorada se
        // va sola, nunca deja la pantalla ocupada.
        case .tutorialTip: 12
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
    /// Mientras está puesto, sólo estos kinds pueden tomar el turno; el resto
    /// queda en `pending` — no se presenta ni se pierde. `nil` = sin
    /// restricción.
    ///
    /// Es lo que hace que la fase obligatoria del tutorial no comparta pantalla
    /// con nada: el daily del día 2, la skin, los toasts — todos esperan a que
    /// la fase termine y recién ahí desfilan, en su orden de siempre. Sin esto
    /// un kind de sheet con `timeout == nil` podía tomar `current` con el
    /// tutorial arriba, su hoja no se presentaba y la cola entera quedaba
    /// congelada.
    public private(set) var allowedKinds: Set<CelebrationKind>?

    private var pending: [CelebrationKind] = []

    public init() {}

    /// Restringe qué kinds pueden tomar el turno (`nil` levanta la
    /// restricción). Levantarla promueve en el acto lo que estaba esperando,
    /// respetando prioridad y orden de llegada.
    ///
    /// No toca `current`: si algo ya estaba en pantalla al restringir, se lo
    /// deja terminar — matarlo perdería una celebración que el jugador está
    /// viendo. El que restringe tiene que hacerlo antes de encolar (el
    /// tutorial lo hace en el bootstrap, antes del primer sync).
    public mutating func restrict(to allowed: Set<CelebrationKind>?) {
        allowedKinds = allowed
        promoteIfIdle()
    }

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
        guard current == nil else { return }
        // El barrido conserva el orden de llegada dentro de la misma prioridad
        // (ordenar el array entero no lo garantiza), y saltea lo que la
        // restricción no deja pasar: eso queda en `pending`, no se pierde.
        var bestIndex: Int?
        for index in pending.indices {
            guard allowedKinds?.contains(pending[index]) ?? true else { continue }
            if let best = bestIndex {
                if pending[index].priority < pending[best].priority { bestIndex = index }
            } else {
                bestIndex = index
            }
        }
        guard let bestIndex else { return }
        current = pending.remove(at: bestIndex)
        elapsed = 0
    }
}
