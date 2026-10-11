import EconomyKit
import Foundation

/// Los cuatro accesos de la columna lateral (PLAN-v2 §2, "Accesos en
/// pantalla"), en el orden en que se leen en la persiana.
enum SideRailKind: String, CaseIterable, Sendable {
    case wheel
    case mattress
    case packages
    case boost
}

/// Lo que dice un botón de la columna.
enum SideRailStatus: Equatable, Sendable {
    /// Hay algo para tocar: el "!" (o el número) y el latido.
    case ready(count: Int?)
    /// Hay algo, pero no entra (paquetes con todo lleno): "LLENO".
    case blocked
    /// Falta: el reloj, en segundos enteros.
    case waiting(seconds: Int)
    /// Nada que ofrecer ni reloj que mostrar.
    case idle
}

struct SideRailItem: Identifiable, Equatable, Sendable {
    let kind: SideRailKind
    let status: SideRailStatus
    var id: SideRailKind { kind }
}

/// Un video de la columna: Fusionar todo o la lluvia de paquetes.
enum RailVideoStatus: Equatable, Sendable {
    case available
    case coolingDown(seconds: Double)
    /// Ahora no haría nada (sin pares, el buzón lleno, un piquete): no se ofrece.
    case notApplicable
}

/// Lo que la columna muestra. Publicado por `GameState.refreshSideRail`.
struct SideRailState: Equatable, Sendable {
    var items: [SideRailItem] = []
    /// Cuántas fusiones haría "Fusionar todo" ahora en el piso a la vista.
    var mergeAllPairs = 0
    /// La lluvia de paquetes, que ofrece el botón de Paquetes cuando no hay ninguno.
    var packageRain = RailVideoStatus.notApplicable

    var isVisible: Bool { !items.isEmpty }

    /// Cuántos accesos tienen algo listo: el número del "!" del botón en reposo.
    /// "LLENO" no cuenta: no hay nada que tocar.
    var readyCount: Int {
        items.filter { if case .ready = $0.status { true } else { false } }.count
    }

    static let hidden = SideRailState()

    func status(of kind: SideRailKind) -> SideRailStatus? {
        items.first { $0.kind == kind }?.status
    }
}

/// Todo lo que la columna necesita saber, ya resuelto por `GameState`.
struct SideRailInput: Equatable, Sendable {
    /// Fuera del núcleo del tutorial y con la partida cargada.
    var shown: Bool
    var access: PrizeAccess
    var packageSecondsUntilNext: Double?
    /// Un piquete corta los paquetes: su reloj no corre, así que no se muestra.
    var packagesPaused = false
    var mattressSecondsUntilNext: Double?
    /// Hasta que vuelven los giros por video; `nil` sin ruleta o sin giros que esperar.
    var wheelSecondsUntilReset: Double?
    var mergeAllPairs: Int
    var mergeAll: RailVideoStatus
    var packageRain: RailVideoStatus
}

/// La columna como función pura de su entrada. Todos los relojes salen en
/// segundos enteros: lo publicado no cambia a 8 Hz.
enum SideRailModel {
    static func state(_ input: SideRailInput) -> SideRailState {
        guard input.shown else { return .hidden }
        return SideRailState(
            items: SideRailKind.allCases.map { SideRailItem(kind: $0, status: status($0, input)) },
            mergeAllPairs: input.mergeAllPairs,
            packageRain: wholeSeconds(input.packageRain)
        )
    }

    private static func status(_ kind: SideRailKind, _ input: SideRailInput) -> SideRailStatus {
        switch kind {
        case .wheel:
            if input.access.wheelSpinsReady > 0 { return .ready(count: input.access.wheelSpinsReady) }
            return input.wheelSecondsUntilReset.map { .waiting(seconds: whole($0)) } ?? .idle
        case .mattress:
            if input.access.mattressReady { return .ready(count: nil) }
            return input.mattressSecondsUntilNext.map { .waiting(seconds: whole($0)) } ?? .idle
        case .packages:
            if input.access.packagesBlocked { return .blocked }
            if input.access.packagesWaiting > 0 { return .ready(count: input.access.packagesWaiting) }
            guard !input.packagesPaused else { return .idle }
            return input.packageSecondsUntilNext.map { .waiting(seconds: whole($0)) } ?? .idle
        case .boost:
            switch input.mergeAll {
            case .available: return .ready(count: nil)
            case .coolingDown(let seconds): return .waiting(seconds: whole(seconds))
            case .notApplicable: return .idle
            }
        }
    }

    private static func wholeSeconds(_ video: RailVideoStatus) -> RailVideoStatus {
        guard case .coolingDown(let seconds) = video else { return video }
        return .coolingDown(seconds: Double(whole(seconds)))
    }

    /// Hacia arriba: un reloj que dice 0 con algo todavía faltando miente.
    private static func whole(_ seconds: Double) -> Int {
        max(0, Int(seconds.rounded(.up)))
    }
}

/// El reloj de un botón: "42s", "4:05", y arriba de la hora "3h" (la ruleta
/// espera a la medianoche y los minutos ahí no dicen nada).
enum SideRailClock {
    static func text(_ seconds: Int) -> String {
        if seconds >= 3600 { return "\(seconds / 3600)h" }
        guard seconds >= 60 else { return "\(seconds)s" }
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}

/// El valor de accesibilidad de un botón: lo leen VoiceOver y los tests de UI.
enum SideRailAX {
    static func value(_ status: SideRailStatus) -> String {
        switch status {
        case .ready(let count): count.map { "ready:\($0)" } ?? "ready"
        case .blocked: "full"
        case .waiting(let seconds): "waiting:\(seconds)"
        case .idle: "idle"
        }
    }
}
