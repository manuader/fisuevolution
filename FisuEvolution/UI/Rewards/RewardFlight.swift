import CoreGraphics
import EconomyKit
import Foundation

/// A dónde vuela un premio (E14b B13): el contador de plata del HUD, el botón del
/// dólar blue, el chip de boosts o la columna de sellos.
enum RewardFlightDestination: Hashable, Sendable {
    case coins
    case blue
    case boosts
    case seals
}

/// De dónde sale: el centro del pop-up que lo dio, o un sello/chip de las esquinas.
enum RewardFlightOrigin: Equatable, Sendable {
    case popup
    case seals
    case boosts
}

/// Un premio que se ve llegar. Es presentación pura: la acreditación ya ocurrió
/// (`GameState.grant`), esto sólo dice qué mostrar y por cuánto.
struct RewardFlightItem: Equatable, Sendable {
    let kind: RewardKind
    let destination: RewardFlightDestination
    /// Plata o blue; la cantidad de lo contable (paquetes, cofres, giros); 0 si no se cuenta.
    let amount: Double

    /// El rótulo grande sobre el origen. Los montos van con el formateador del HUD.
    var label: String? {
        guard amount > 0 else { return nil }
        if kind == .coins { return "+" + CoinFormatter.string(from: amount) }
        return "+" + String(Int(amount.rounded()))
    }

    /// Cuántas partículas pide: la plata chorrea, el resto vuela con su ícono.
    var requestedParticles: Int {
        switch kind {
        case .coins: RewardFlightBudget.coinParticles
        case .blue: RewardFlightBudget.blueParticles
        default: 1
        }
    }
}

/// De los premios que acaba de dar una fuente a lo que se anima.
enum RewardFlightPlan {
    /// `coins` es la plata ya acreditada (lo que devuelve `grant` más lo que se
    /// cobró aparte); los `.coinsSeconds` de `rewards` no suman otra vez.
    static func items(for rewards: [RewardSpec], multiplier: Int = 1, coins: Double = 0) -> [RewardFlightItem] {
        var items: [RewardFlightItem] = []
        if coins > 0, coins.isFinite {
            items.append(RewardFlightItem(kind: .coins, destination: .coins, amount: coins))
        }
        for reward in rewards {
            if let item = item(for: reward.scaled(by: multiplier)) { items.append(item) }
        }
        return items
    }

    private static func item(for reward: RewardSpec) -> RewardFlightItem? {
        switch reward {
        case .coinsSeconds, .extraSlots:
            return nil
        case .blue(let amount):
            return amount > 0 ? RewardFlightItem(kind: .blue, destination: .blue, amount: Double(amount)) : nil
        case .skinChest(let count):
            return RewardFlightItem(kind: .chest, destination: .seals, amount: Double(count))
        case .package(let count):
            return RewardFlightItem(kind: .package, destination: .seals, amount: Double(count))
        case .wheelSpin(let count):
            return RewardFlightItem(kind: .wheelSpin, destination: .seals, amount: Double(count))
        case .modifier(let effect, _, _):
            return RewardKind(modifier: effect).map { RewardFlightItem(kind: $0, destination: .boosts, amount: 0) }
        case .autoTap:
            return RewardFlightItem(kind: .tapBoost, destination: .boosts, amount: 0)
        case .clearBoostCooldowns, .eventImmunity:
            return RewardFlightItem(kind: .boostRefresh, destination: .boosts, amount: 0)
        case .nextOfflineMultiplier:
            return RewardFlightItem(kind: .incomeBoost, destination: .boosts, amount: 0)
        case .nextDailyMultiplier:
            return RewardFlightItem(kind: .gift, destination: .seals, amount: 0)
        }
    }
}

/// El tope de partículas: una tanda no pasa de `batchCap` y entre todas las vivas
/// no pasan de `liveCap` (la mitad en el iPhone SE, que ya sostiene menos videos).
enum RewardFlightBudget {
    static let coinParticles = 9
    static let blueParticles = 5
    static let batchCap = 10
    static let standardLiveCap = 24
    static let compactLiveCap = 12

    static func liveCap(forModel model: String) -> Int {
        VideoPlayerPool.iPhoneSEModels.contains(model) ? compactLiveCap : standardLiveCap
    }

    /// Reparte el cupo en el orden pedido (la plata va primero): `requested[i]`
    /// partículas para el premio i, recortadas a lo que queda de la tanda y del tope vivo.
    static func allocate(requested: [Int], alreadyLive: Int, liveCap: Int, batchCap: Int = RewardFlightBudget.batchCap) -> [Int] {
        var room = min(batchCap, max(0, liveCap - alreadyLive))
        return requested.map { wanted in
            let granted = min(max(0, wanted), room)
            room -= granted
            return granted
        }
    }
}

enum RewardFlightTiming {
    /// La espera entre que se acredita y arranca el vuelo: que el pop-up de origen alcance a cerrarse.
    static let defaultDelay: TimeInterval = 0.3
    static let stagger: TimeInterval = 0.06
    static let flight: TimeInterval = 0.75
    static let labelSeconds: TimeInterval = 1.5
}

/// Una moneda (o billete, o ícono) en el aire.
struct RewardFlightParticle: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: RewardKind
    let destination: RewardFlightDestination
    /// Lo que este vuelo suma al contador cuando aterriza (sólo plata).
    let share: Double
    let index: Int
    let count: Int
    let delay: TimeInterval
}

struct RewardFlightLabel: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let kind: RewardKind
}

/// Todo lo que sale de una fuente en el mismo momento.
struct RewardFlightBatch: Identifiable, Equatable, Sendable {
    let id: UUID
    let origin: RewardFlightOrigin
    let delay: TimeInterval
    /// Escalón vertical del rótulo: dos tandas seguidas no se pisan (D14).
    let slot: Int
    let labels: [RewardFlightLabel]
    var particles: [RewardFlightParticle]
}

/// La pantalla y los destinos medidos: de un origen/destino lógico a un punto local.
struct RewardFlightGeometry {
    let size: CGSize
    /// El origen global de la capa: los anchors se miden en coordenadas globales.
    let layerOrigin: CGPoint
    let anchors: [RewardFlightDestination: CGRect]

    func point(for origin: RewardFlightOrigin) -> CGPoint {
        switch origin {
        case .popup:
            return CGPoint(x: size.width / 2, y: size.height * 0.42)
        case .seals:
            return local(anchors[.seals]).map { CGPoint(x: $0.minX + 30, y: $0.minY + 30) }
                ?? CGPoint(x: 36, y: size.height * 0.2)
        case .boosts:
            return local(anchors[.boosts]).map { CGPoint(x: $0.maxX - 24, y: $0.minY + 24) }
                ?? CGPoint(x: size.width - 36, y: size.height * 0.2)
        }
    }

    func target(for destination: RewardFlightDestination) -> CGPoint {
        switch destination {
        case .coins:
            return local(anchors[.coins]).map { CGPoint(x: $0.midX, y: $0.midY) }
                ?? CGPoint(x: size.width / 2, y: 52)
        case .blue:
            return local(anchors[.blue]).map { CGPoint(x: $0.midX, y: $0.midY) }
                ?? CGPoint(x: 40, y: 52)
        case .boosts:
            return local(anchors[.boosts]).map { CGPoint(x: $0.maxX - 24, y: $0.minY + 24) }
                ?? CGPoint(x: size.width - 36, y: size.height * 0.2)
        case .seals:
            return local(anchors[.seals]).map { CGPoint(x: $0.minX + 30, y: $0.minY + 30) }
                ?? CGPoint(x: 36, y: size.height * 0.2)
        }
    }

    /// Un anchor vacío (la columna sin nada) no es un destino: cae al respaldo.
    private func local(_ rect: CGRect?) -> CGRect? {
        guard let rect, rect.width > 1, rect.height > 1 else { return nil }
        return rect.offsetBy(dx: -layerOrigin.x, dy: -layerOrigin.y)
    }
}
