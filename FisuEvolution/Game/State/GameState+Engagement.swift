import EconomyKit
import Foundation

/// Los relojes de engagement (PLAN-v2 E4): colgados del tick, que sólo corre con
/// la escena activa (E1 T8) y trae el delta con tope. E4b suma visitantes y el
/// escenario; E5, paquetes y colchón. Todos acá, en este orden.
extension GameState {
    func advanceEngagement(delta: TimeInterval) {
        advanceEvents(delta: delta)
        advanceVisitors(delta: delta)
        advancePackages(delta: delta)
        advanceTreasures(delta: delta)
        advanceStage(delta: delta)
    }

    #if DEBUG
    /// Las puertas de test del engagement, colgadas de UNA línea del bootstrap:
    /// cada épica suma la suya acá y no vuelve a abrir `GameState.swift`.
    func applyEngagementFixtures(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let id = Self.fixtureValue("--uitest-event=", in: arguments) {
            debugStartEvent(id: id)
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
        if arguments.contains("--uitest-mattress") {
            debugSpawnMattress()
        }
    }

    /// El valor de un argumento `--uitest-algo=<valor>`.
    static func fixtureValue(_ prefix: String, in arguments: [String]) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
    #endif
}
