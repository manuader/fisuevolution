import EconomyKit
import Foundation

/// Los relojes de engagement (PLAN-v2 E4): colgados del tick, que sólo corre con
/// la escena activa (E1 T8) y trae el delta con tope. E4b suma visitantes y el
/// escenario; E5, paquetes y colchón. Todos acá, en este orden.
extension GameState {
    func advanceEngagement(delta: TimeInterval) {
        advanceAutoTap(delta: delta)
        advanceEvents(delta: delta)
        presentPendingEventIfPossible()
        advanceVisitors(delta: delta)
        advancePackages(delta: delta)
        advanceTreasures(delta: delta)
        advanceStage(delta: delta)
        advanceOffers()
    }

    #if DEBUG
    /// Las puertas de test del engagement, colgadas de UNA línea del bootstrap:
    /// cada épica suma la suya acá y no vuelve a abrir `GameState.swift`.
    func applyEngagementFixtures(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let id = Self.fixtureValue("--uitest-event=", in: arguments) {
            debugPresentEvent(id: id)
        }
        if let scriptId = Self.fixtureValue("--uitest-visitor=", in: arguments) {
            stageRuntime.debugScript = scriptId
        }
        if let count = Self.fixtureValue("--uitest-packages=", in: arguments).flatMap(Int.init) {
            debugAddPackages(count)
        }
        if let count = Self.fixtureValue("--uitest-wheel-spins=", in: arguments).flatMap(Int.init) {
            debugAddWheelSpins(count)
        }
        // El blue para ejercitar la tienda sin reencarnar.
        if let blue = Self.fixtureValue("--uitest-blue=", in: arguments).flatMap(Int.init), var player {
            player.meta.blue = blue
            self.player = player
            refreshProjections()
        }
        if let offer = Self.fixtureValue("--uitest-offer=", in: arguments) {
            debugOpenOffer(id: offer)
        }
        // Los dos niveles de lugares extra y el piso de abajo lleno: la foto de las
        // 4 filas sin jugar horas.
        if arguments.contains("--uitest-extra-slots"), var player, let content {
            player.meta.engagement.shop.levels["extra_slots"] = 2
            self.player = player
            reconcileTower()
            if var filled = self.player {
                filled.run.units = [content.tiers.baseType.id: self.content?.floorTable[0].capacity ?? 0]
                self.player = filled
                reconcileTower()
            }
        }
        if arguments.contains("--uitest-mattress") {
            debugSpawnMattress()
        }
        if arguments.contains("--uitest-mattress-extra") {
            debugSpawnMattress(extraSaved: true)
        }
        if arguments.contains("--uitest-mattress-board") {
            debugSpawnMattress(onBoard: true)
        }
    }

    /// El valor de un argumento `--uitest-algo=<valor>`.
    static func fixtureValue(_ prefix: String, in arguments: [String]) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
    #endif
}
