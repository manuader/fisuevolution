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
        // El piso a la vista al arrancar (E14b B19: el globo largo en un piso alto). Va antes del
        // evento: el presentador entra en el piso que se mira. Con el piso cerrado no hace nada.
        if let floorId = Self.fixtureValue("--uitest-floor=", in: arguments),
           let ordinal = content?.floorTable.floors.firstIndex(where: { $0.id == floorId }) {
            jumpToFloor(ordinal: ordinal)
        }
        if let id = Self.fixtureValue("--uitest-event=", in: arguments) {
            debugPresentEvent(id: id)
        }
        // Fisuras sueltos para fusionar a mano (B21: un merge en medio de la entrada del visitante).
        if let count = Self.fixtureValue("--uitest-homeless=", in: arguments).flatMap(Int.init) {
            debugSeedHomeless(count)
        }
        if let scriptId = Self.fixtureValue("--uitest-visitor=", in: arguments) {
            stageRuntime.debugScript = scriptId
        }
        // La Marcha del Puntero (E14b B25): una ventana corta, o ya ganada para la foto del festejo.
        if arguments.contains("--uitest-marcha-corta") {
            stageRuntime.debugShortMarch = true
        }
        if arguments.contains("--uitest-marcha-ganada") {
            debugSeedWonMarch()
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
        // `reconcileTower` lleva la cámara al piso abierto más alto: se vuelve al que se miraba, así el
        // colchón y el visitante que vienen después caen en el piso de la foto y no arriba.
        if arguments.contains("--uitest-extra-slots"), var player, let content {
            let visible = visibleFloorOrdinal
            player.meta.engagement.shop.levels["extra_slots"] = 2
            self.player = player
            reconcileTower()
            if var filled = self.player {
                filled.run.units = [content.tiers.baseType.id: self.content?.floorTable[0].capacity ?? 0]
                self.player = filled
                reconcileTower()
            }
            visibleFloorOrdinal = visible
        }
        // Después de los lugares extra: la caja cae en un lugar libre del piso y `--uitest-extra-slots`
        // lo llena hasta el tope, así que antes de él la caja se quedaría sin sitio (las capturas de
        // la ficha combinan los dos).
        if let count = Self.fixtureValue("--uitest-packages=", in: arguments).flatMap(Int.init) {
            debugAddPackages(count)
        }
        if let fixture = Self.fixtureValue("--uitest-package-floor=", in: arguments) {
            debugDropPackages(fixture: fixture)
        }
        if arguments.contains("--uitest-mattress") {
            debugSpawnMattress()
        }
        if arguments.contains("--uitest-mattress-extra") {
            debugSpawnMattress(extraSaved: true)
        }
        // El gratis del tablero ya caído (E14b B31), o su reloj cada tantos segundos para verlo caer.
        if arguments.contains("--uitest-mattress-board") {
            debugDropFreeMattress()
        }
        if let seconds = Self.fixtureValue("--uitest-free-mattress-every=", in: arguments).flatMap(TimeInterval.init) {
            debugFreeMattressEvery(seconds)
        }
    }

    /// El valor de un argumento `--uitest-algo=<valor>`.
    static func fixtureValue(_ prefix: String, in arguments: [String]) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
    #endif
}
