import Foundation
import SwiftUI

@MainActor
protocol VideoLeaseHolder: AnyObject {
    func videoLeaseDidChange(isLive: Bool)
}

enum VideoRole: Int, Comparable, Sendable {
    // Orden = qué cae primero cuando no alcanza el tope.
    case icon = 0, background = 1, popup = 2, fullscreen = 3

    static func < (lhs: VideoRole, rhs: VideoRole) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Decide quién decodifica: tope de 3 vivos (2 en el iPhone SE), el más nuevo de cada rol, la
/// cinemática sola. No toca AVFoundation: cada holder crea o suelta su player cuando el pool lo
/// pone vivo o lo baja.
@MainActor
final class VideoPlayerPool {
    nonisolated static let maxLive = 3
    nonisolated static let conservativeMaxLive = 2

    /// El escalón conservador (G1 de E8d): el iPhone SE de 2.ª y 3.ª generación, con pantalla de
    /// 4,7" y 3-4 GB de RAM, sostiene menos decodificaciones a la vez. El simulador informa el
    /// modelo simulado en `SIMULATOR_MODEL_IDENTIFIER`.
    nonisolated static let iPhoneSEModels: Set<String> = ["iPhone12,8", "iPhone14,6"]

    nonisolated static func maxLive(forModel model: String) -> Int {
        iPhoneSEModels.contains(model) ? conservativeMaxLive : maxLive
    }

    nonisolated static var hardwareModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
    static let shared: VideoPlayerPool = {
        let pool = VideoPlayerPool(policy: .launch)
        observer.start(pool: pool)
        return pool
    }()
    private static let observer = VideoPlaybackObserver()

    struct Lease: Hashable {
        fileprivate let pool: ObjectIdentifier
        fileprivate let id: Int
    }
    struct Suspension: Hashable { fileprivate let id: Int }
    struct Reservation: Hashable { fileprivate let id: Int }
    enum SuspendReason: Sendable { case overlay, elevatorRide, scrolling }

    private struct Entry {
        let id: Int
        let role: VideoRole
        weak var holder: VideoLeaseHolder?
        var notified = false
    }

    private var entries: [Entry] = []
    private var suspensions: Set<Int> = []
    private var reservations: Set<Int> = []
    private(set) var policy: VideoPlaybackPolicy
    private var isRecomputing = false
    private var needsRecompute = false
    private var nextID = 0

    private(set) var liveCount = 0
    let maxLive: Int

    init(policy: VideoPlaybackPolicy, maxLive: Int = VideoPlayerPool.maxLive(forModel: VideoPlayerPool.hardwareModel)) {
        self.policy = policy
        self.maxLive = maxLive
    }

    func acquire(_ holder: VideoLeaseHolder, role: VideoRole) -> Lease {
        let id = makeID()
        entries.append(Entry(id: id, role: role, holder: holder))
        recompute()
        return Lease(pool: ObjectIdentifier(self), id: id)
    }

    func release(_ lease: Lease) {
        guard lease.pool == ObjectIdentifier(self),
              let index = entries.firstIndex(where: { $0.id == lease.id }) else { return }
        let entry = entries.remove(at: index)
        if entry.notified { entry.holder?.videoLeaseDidChange(isLive: false) }
        recompute()
    }

    func suspend(_ reason: SuspendReason) -> Suspension {
        let id = makeID()
        suspensions.insert(id)
        recompute()
        return Suspension(id: id)
    }

    func resume(_ suspension: Suspension) {
        guard suspensions.remove(suspension.id) != nil else { return }
        recompute()
    }

    func reserve() -> Reservation {
        let id = makeID()
        reservations.insert(id)
        recompute()
        return Reservation(id: id)
    }

    func unreserve(_ reservation: Reservation) {
        guard reservations.remove(reservation.id) != nil else { return }
        recompute()
    }

    func update(policy: VideoPlaybackPolicy) {
        guard policy != self.policy else { return }
        self.policy = policy
        recompute()
    }

    private func makeID() -> Int {
        nextID += 1
        return nextID
    }

    /// Quién vive: con `fullscreen` (y `allowsCinematics`), sólo él. Si no, con suspensiones o
    /// sin `allowsLoops`, nadie. Si no, el más nuevo de cada rol, de mayor a menor rol, hasta
    /// `maxLive - reservas`. Al holder que cambia se le avisa una sola vez; si un aviso dispara
    /// otro acquire o release, se vuelve a calcular con el estado vigente.
    private func recompute() {
        if isRecomputing {
            needsRecompute = true
            return
        }
        isRecomputing = true
        defer { isRecomputing = false }
        repeat {
            needsRecompute = false
            entries.removeAll { $0.holder == nil }
            let next = liveIDs()
            liveCount = next.count
            for id in entries.map(\.id) {
                guard let index = entries.firstIndex(where: { $0.id == id }) else { continue }
                let now = next.contains(id)
                guard entries[index].notified != now else { continue }
                entries[index].notified = now
                entries[index].holder?.videoLeaseDidChange(isLive: now)
            }
        } while needsRecompute
    }

    private func liveIDs() -> Set<Int> {
        if let cinematic = entries.last(where: { $0.role == .fullscreen }), policy.allowsCinematics {
            return [cinematic.id]
        }
        guard suspensions.isEmpty, policy.allowsLoops else { return [] }
        let capacity = max(0, maxLive - reservations.count)
        var chosen: [Int] = []
        for role in [VideoRole.popup, .background, .icon] {
            if let newest = entries.last(where: { $0.role == role }) { chosen.append(newest.id) }
        }
        return Set(chosen.prefix(capacity))
    }
}

private struct SuspendsVideoPool: ViewModifier {
    let active: Bool
    let reason: VideoPlayerPool.SuspendReason
    @State private var suspension: VideoPlayerPool.Suspension?

    func body(content: Content) -> some View {
        content
            .onAppear { begin() }
            .onDisappear { end() }
            .onChange(of: active) { _, isActive in
                if isActive { begin() } else { end() }
            }
    }

    private func begin() {
        guard active, suspension == nil else { return }
        suspension = VideoPlayerPool.shared.suspend(reason)
    }

    private func end() {
        if let suspension { VideoPlayerPool.shared.resume(suspension) }
        suspension = nil
    }
}

extension View {
    /// Mientras la vista está en pantalla (y `active`), el pool no decodifica nada: el cofre, el viaje.
    func suspendsVideoPool(_ active: Bool = true,
                           reason: VideoPlayerPool.SuspendReason = .overlay) -> some View {
        modifier(SuspendsVideoPool(active: active, reason: reason))
    }
}
