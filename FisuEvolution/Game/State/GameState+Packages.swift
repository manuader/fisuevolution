import EconomyKit
import Foundation

/// Lo que pasa al tocar un paquete.
enum PackageOpenResult: Equatable {
    /// Sorteó a quién trae y lo dejó en el embudo de E1: llega en su turno, a la vista.
    case opened(typeId: String)
    /// No hay a quién traer con lugar: "LLENO", y el paquete se queda.
    case full
    /// No había ninguno esperando.
    case noneWaiting
}

/// El Paquete de la Aduana en la partida (PLAN-v2 E5).
extension GameState {
    var packagesWaiting: Int { player?.meta.engagement.packages.waiting ?? 0 }

    /// A quién podría traer un paquete ahora: lo que FisuJobs vende con lugar.
    var packageCandidates: [CharacterType] {
        guard let content, let player, let tower else { return [] }
        return PackageRoller.eligibleTypes(
            state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy
        )
    }

    /// Hay paquetes esperando y ninguno entra: el cartel "LLENO".
    var packagesBlocked: Bool { packagesWaiting > 0 && packageCandidates.isEmpty }

    /// El reloj de juego activo. Lo llama `advanceEngagement` con el delta del tick.
    func advancePackages(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        let rate = ModifierMath.factor(player.run.activeModifiers, effect: .packageRateMultiplier, now: now)
        let dropped = PackageScheduler.advance(
            &player.meta.engagement.packages, delta: delta, rateMultiplier: rate, config: content.packages
        )
        self.player = player
        guard dropped > 0 else { return }
        Log.economy.info("package dropped: \(player.meta.engagement.packages.waiting) waiting")
        scheduleSave()
    }

    /// Abre uno: sortea a quién trae y deja su llegada en el embudo. El
    /// paquete se gasta sólo si alguien entra.
    @discardableResult
    func openPackage() -> PackageOpenResult {
        guard let content, var player, let tower, player.meta.engagement.packages.waiting > 0 else {
            return .noneWaiting
        }
        // E6: el nivel del permanente "mejor proveedor".
        let ratio = content.packages.tierRatio(bestSupplierLevel: 0)
        guard let type = PackageRoller.roll(
                  eligible: packageCandidates, windowTiers: content.packages.windowTiers, ratio: ratio, using: &rng
              ),
              let change = BoardChangePlanner.planArrival(
                  typeId: type.id, state: player, tower: tower, tiers: content.tiers,
                  floorTable: content.floorTable, origin: .package
              )
        else {
            haptics?.play(.error)
            audio?.play(.error)
            return .full
        }
        player.meta.engagement.packages.waiting -= 1
        self.player = player
        enqueueBoardChange(change)
        haptics?.play(.purchase)
        scheduleSave()
        Log.economy.info("package opened: \(type.id)")
        return .opened(typeId: type.id)
    }

    /// Un paquete cuyo empleado ya no entra cuando le toca el turno vuelve al
    /// buzón, aunque pase el tope: ya estaba ganado.
    func refundPackage() {
        guard var player else { return }
        player.meta.engagement.packages.waiting += 1
        self.player = player
        scheduleSave()
    }

    #if DEBUG
    func debugAddPackages(_ count: Int) {
        guard var player, count > 0 else { return }
        player.meta.engagement.packages.waiting += count
        self.player = player
    }
    #endif
}
