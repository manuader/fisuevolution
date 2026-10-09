import Foundation
import Observation

/// Un pedido de un pack On-Demand Resources. `load` termina cuando el pack está en disco.
@MainActor
protocol ArtPackRequest: AnyObject {
    func load(urgent: Bool) async throws
    func raisePriority()
    func end()
}

@MainActor
protocol ArtPackSource {
    func makeRequest(tag: String) -> any ArtPackRequest
}

@MainActor
struct BundleArtPackSource: ArtPackSource {
    func makeRequest(tag: String) -> any ArtPackRequest {
        BundleArtPackRequest(tag: tag)
    }
}

@MainActor
private final class BundleArtPackRequest: ArtPackRequest {
    private let request: NSBundleResourceRequest

    init(tag: String) {
        request = NSBundleResourceRequest(tags: [tag])
    }

    func load(urgent: Bool) async throws {
        if await request.conditionallyBeginAccessingResources() { return }
        request.loadingPriority = urgent ? NSBundleResourceRequestLoadingPriorityUrgent : 0.5
        try await request.beginAccessingResources()
    }

    func raisePriority() {
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
    }

    func end() {
        request.endAccessingResources()
    }
}

/// Los videos pesados viajan en packs ODR (`odrTag` del manifest). Un pack que no está en disco
/// no tiene URL: quien dibuja muestra su póster y, cuando el pack llega, se entera y funde.
/// Un error de red deja el pedido caído sin reintento en lazo: el próximo `request` lo reintenta.
@MainActor
@Observable
final class ArtPacks {
    static let shared = ArtPacks()

    private struct Pending {
        let request: any ArtPackRequest
        let generation: Int
        var urgent: Bool
    }

    @ObservationIgnored private let source: any ArtPackSource
    @ObservationIgnored private var pending: [String: Pending] = [:]
    @ObservationIgnored private var users: [String: Int] = [:]
    @ObservationIgnored private var requests: [String: any ArtPackRequest] = [:]
    @ObservationIgnored private var observers: [String: [UUID: @MainActor () -> Void]] = [:]
    @ObservationIgnored private var generation = 0
    private var readyTags: Set<String> = []

    init(source: any ArtPackSource = BundleArtPackSource()) {
        self.source = source
    }

    func isReady(_ tag: String) -> Bool {
        readyTags.contains(tag)
    }

    func isRequested(_ tag: String) -> Bool {
        pending[tag] != nil
    }

    /// Pide el pack en segundo plano. `urgent` es para lo que está en pantalla; el resto, `prefetch`.
    /// Cada `request` se compensa con un `release`.
    func request(_ tag: String, urgent: Bool = true) {
        users[tag, default: 0] += 1
        guard !isReady(tag) else { return }
        if var inFlight = pending[tag] {
            if urgent, !inFlight.urgent {
                inFlight.urgent = true
                pending[tag] = inFlight
                inFlight.request.raisePriority()
            }
            return
        }
        generation += 1
        let current = generation
        let packRequest = source.makeRequest(tag: tag)
        pending[tag] = Pending(request: packRequest, generation: current, urgent: urgent)
        Task { [weak self] in
            do {
                try await packRequest.load(urgent: urgent)
                self?.finished(tag, generation: current)
            } catch {
                self?.failed(tag, generation: current)
            }
        }
    }

    func prefetch(_ tag: String) {
        request(tag, urgent: false)
    }

    /// Suelta el pack al salir de la pantalla que lo usaba; el sistema purga cuando necesite lugar.
    func release(_ tag: String) {
        guard let count = users[tag] else { return }
        if count > 1 {
            users[tag] = count - 1
            return
        }
        users[tag] = nil
        if let pack = pending.removeValue(forKey: tag) {
            pack.request.end()
        } else if let kept = requests.removeValue(forKey: tag) {
            kept.end()
        }
        readyTags.remove(tag)
    }

    /// Avisa una sola vez cuando el pack llega; si ya está, en el acto. El token sirve para
    /// `cancelWait` si quien esperaba se va antes.
    @discardableResult
    func whenAvailable(_ tag: String, _ handler: @escaping @MainActor () -> Void) -> UUID {
        let token = UUID()
        if isReady(tag) {
            handler()
        } else {
            observers[tag, default: [:]][token] = handler
        }
        return token
    }

    func cancelWait(_ tag: String, token: UUID) {
        observers[tag]?[token] = nil
    }

    private func finished(_ tag: String, generation: Int) {
        guard let pack = pending[tag], pack.generation == generation else { return }
        pending[tag] = nil
        requests[tag] = pack.request
        readyTags.insert(tag)
        let handlers = observers.removeValue(forKey: tag) ?? [:]
        handlers.values.forEach { $0() }
    }

    private func failed(_ tag: String, generation: Int) {
        guard let pack = pending[tag], pack.generation == generation else { return }
        pending[tag] = nil
        pack.request.end()
    }
}
