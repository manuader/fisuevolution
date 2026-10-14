import CoreGraphics
import EconomyKit
import Foundation
import UIKit

/// La cola de vuelos de recompensa (E14b B13). Las fuentes de premios la llaman
/// después de acreditar (`GameState.announceReward`); la capa (`RewardFlightLayer`)
/// dibuja lo que hay en `batches`; el HUD lee `heldCoins` y `bumps`.
///
/// Es presentación: **no toca el saldo**. Mientras las monedas vuelan, `heldCoins`
/// es lo que el HUD todavía no muestra, para que el contador suba de a poco en vez
/// de saltar; cada moneda que aterriza lo baja. Si algo falla (la capa no está
/// montada, el vuelo se cortó), el cierre de la tanda lo suelta igual.
@Observable @MainActor
final class RewardFlightCenter {
    static let shared = RewardFlightCenter()

    private(set) var batches: [RewardFlightBatch] = []
    /// Plata ya acreditada que el contador del HUD todavía no muestra.
    private(set) var heldCoins: Double = 0
    /// Cuántas tandas aterrizaron por destino: el HUD rebota con cada una.
    private(set) var bumps: [RewardFlightDestination: Int] = [:]
    /// Suma una por cada partícula que aterriza: dispara el sonido y el haptic.
    private(set) var landings = 0
    /// Lo lanzado, en orden (acotado): lo que leen los tests y la telemetría.
    private(set) var launched: [RewardFlightItem] = []

    @ObservationIgnored var anchors: [RewardFlightDestination: CGRect] = [:]
    @ObservationIgnored var reduceMotion: () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    @ObservationIgnored var liveCap = RewardFlightBudget.liveCap(forModel: VideoPlayerPool.hardwareModel)

    private static let historyLimit = 64

    var hasActiveBatches: Bool { !batches.isEmpty }

    var liveParticles: Int { batches.reduce(0) { $0 + $1.particles.count } }

    func bumpCount(_ destination: RewardFlightDestination) -> Int { bumps[destination] ?? 0 }

    func launch(
        _ items: [RewardFlightItem],
        from origin: RewardFlightOrigin = .popup,
        after delay: TimeInterval = RewardFlightTiming.defaultDelay
    ) {
        guard !items.isEmpty else { return }
        launched.append(contentsOf: items)
        if launched.count > Self.historyLimit { launched.removeFirst(launched.count - Self.historyLimit) }

        let counts = reduceMotion()
            ? items.map { _ in 0 }
            : RewardFlightBudget.allocate(requested: items.map(\.requestedParticles), alreadyLive: liveParticles, liveCap: liveCap)
        var particles: [RewardFlightParticle] = []
        for (item, count) in zip(items, counts) where count > 0 {
            let holds = item.destination == .coins
            for index in 0..<count {
                particles.append(RewardFlightParticle(
                    id: UUID(), kind: item.kind, destination: item.destination,
                    share: holds ? item.amount / Double(count) : 0,
                    index: index, count: count,
                    delay: delay + Double(index) * RewardFlightTiming.stagger
                ))
            }
            if holds { heldCoins += item.amount }
        }
        let labels = items.compactMap { item in
            item.label.map { RewardFlightLabel(id: UUID(), text: $0, kind: item.kind) }
        }
        let batch = RewardFlightBatch(
            id: UUID(), origin: origin, delay: delay,
            slot: batches.filter { !$0.labels.isEmpty }.count % 3,
            labels: labels, particles: particles
        )
        batches.append(batch)

        let lastLanding = (particles.map(\.delay).max() ?? delay) + RewardFlightTiming.flight
        let lifetime = max(lastLanding, delay + RewardFlightTiming.labelSeconds) + 0.4
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(lifetime))
            self?.finish(batch.id)
        }
    }

    /// Una partícula llegó: el contador suma su parte, el HUD rebota y suena.
    func land(_ particleID: UUID) {
        guard let batchIndex = batches.firstIndex(where: { $0.particles.contains { $0.id == particleID } }),
              let particleIndex = batches[batchIndex].particles.firstIndex(where: { $0.id == particleID })
        else { return }
        let particle = batches[batchIndex].particles.remove(at: particleIndex)
        release(particle.share)
        landings &+= 1
        if batches[batchIndex].particles.allSatisfy({ $0.destination != particle.destination }) {
            bumps[particle.destination, default: 0] += 1
        }
    }

    /// Cierra la tanda: lo que no llegó a aterrizar se suelta para que el contador no quede retenido.
    func finish(_ batchID: UUID) {
        guard let index = batches.firstIndex(where: { $0.id == batchID }) else { return }
        let batch = batches.remove(at: index)
        for particle in batch.particles { release(particle.share) }
        if batches.isEmpty { heldCoins = 0 }
    }

    /// Para los tests: deja el centro como recién creado.
    func reset() {
        batches = []
        heldCoins = 0
        bumps = [:]
        landings = 0
        launched = []
    }

    private func release(_ share: Double) {
        guard share > 0 else { return }
        heldCoins = max(0, heldCoins - share)
    }
}
