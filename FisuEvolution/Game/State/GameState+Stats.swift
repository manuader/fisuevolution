import EconomyKit
import Foundation

/// La foto de estadísticas de la cuenta (spec §10.2), ya resuelta a texto.
///
/// ⚠️ **Todos los campos son `String` y no números**, y no es un detalle de
/// comodidad: la pantalla de Stats es una lista de pares "etiqueta / valor", y si
/// el formateo viviera en la vista, el mismo dato saldría distinto según qué
/// pantalla lo dibuje. El caso concreto que lo obliga es `incomePerSecond`, que
/// tiene una regla propia —abajo de 1 se muestra con un decimal en vez de
/// redondear a 0— y ya la aplica el HUD: acá se reusa **su** texto en vez de
/// volver a formatear, así la barra de arriba y la pantalla no pueden discrepar.
///
/// La otra mitad del contrato es `maxFloorName`, que llega **resuelto**
/// (`TowerNaming.floorName`). Armar `LocalizedStringKey("tower.floor.\(id)")` en
/// la vista es la trampa 5 del HANDOFF: construye la clave `tower.floor.%@`, que
/// no existe, y en pantalla se lee el id crudo.
struct StatsSnapshot: Equatable {
    // Producción
    let lifetimeEarnings: String
    let oro: String
    let oroLifetime: String
    let incomePerSecond: String
    // Carrera
    let prestigeLevel: String
    let maxFloorName: String
    let maxTier: String
    let floorsUnlocked: String
    // Colección — los cuatro van como "tenés/hay" ("12/43")
    let unitCount: String
    let seenTypes: String
    let skins: String
    let specials: String
    // Actividad (histórica: sobrevive a reencarnar)
    let totalMerges: String
    let totalHires: String
    let totalTaps: String
    let videosWatched: String
    let boostsActivated: String
    let shares: String

    /// Antes del bootstrap no hay contenido ni jugador. Ceros y no guiones: la
    /// pantalla no se abre en ese estado (vive detrás de `phase == .ready`), y un
    /// "—" obligaría a cada fila a distinguir "no cargó" de "vale cero".
    static let empty = StatsSnapshot(
        lifetimeEarnings: "0", oro: "0", oroLifetime: "0", incomePerSecond: "0",
        prestigeLevel: "0", maxFloorName: "", maxTier: "0", floorsUnlocked: "0/0",
        unitCount: "0", seenTypes: "0/0", skins: "0/0", specials: "0/0",
        totalMerges: "0", totalHires: "0", totalTaps: "0",
        videosWatched: "0", boostsActivated: "0", shares: "0"
    )
}

/// Un nodo del organigrama (spec §10.1), ya resuelto: la vista lo dibuja sin
/// preguntarle nada más al estado.
///
/// ⚠️ `displayName` es `"???"` para lo nunca visto, igual que en `JobRow`: la
/// cadena de evolución no se espoilea (RF-03). El `faceKey` viaja **igual** —la
/// vista dibuja el mismo PNG en silueta de tinta plena—, así que un nodo
/// desconocido tiene silueta y no un hueco.
struct OrgChartRow: Identifiable, Equatable {
    let id: String
    let displayName: String
    let faceKey: String
    /// Cuántos tenés vivos AHORA (`run.units`). Cero es un estado válido y
    /// visible: "lo conocés pero no tenés ninguno".
    let count: Int
    let tier: Int
    let floorID: String
    let seen: Bool
}

/// Las dos proyecciones del Menú: la foto de estadísticas y el organigrama
/// (spec §10.1 y §10.2). Separado de `GameState.swift` para que el frente del
/// menú no comparta archivo con los otros dominios.
///
/// Las dos son **computadas y no publicadas**, por el mismo motivo que `jobRows`
/// y `achievementRows`: viven en pantallas modales que casi nunca están
/// abiertas, y difundir 43 nodos ocho veces por segundo para nadie sería pagar
/// el costo de una hoja cerrada. Las vistas se invalidan contra las proyecciones
/// que ya existen (`coinsText`, `boardVersion`, `effectsVersion`).
extension GameState {
    /// La foto de la cuenta, lista para dibujar.
    var statsSnapshot: StatsSnapshot {
        guard let content, let player else { return .empty }

        let floors = content.floorTable
        // El máximo histórico se acota al catálogo vigente: un save de una
        // versión con más pisos no puede indexar fuera de la tabla de hoy.
        let maxOrdinal = min(max(player.meta.stats.maxFloorOrdinalEver, 0), max(floors.count - 1, 0))

        // Los vistos se cuentan contra el CATÁLOGO y no con `seenTypes.count`:
        // un save con un tipo retirado entre versiones (pasó con `kiosco`)
        // llegaría al total sin haberlos visto a todos. Mismo criterio que
        // `skinsAll` en el motor de logros.
        let concrete = Set(content.tiers.concreteTypes.map(\.id))
        let seenCount = player.run.seenTypes.filter { concrete.contains($0) }.count

        let ownedSkins = player.meta.allOwnedSkins
        let skinCount = content.skins.skins.filter { ownedSkins.contains($0.id) }.count

        let ownedSpecials = Set(player.meta.ownedSpecials)
        let specialCount = content.specials.specials.filter { ownedSpecials.contains($0.id) }.count

        let openFloors = Set(player.run.unlockedFloors)
        let openCount = floors.floors.filter { openFloors.contains($0.id) }.count

        let stats = player.meta.stats
        return StatsSnapshot(
            lifetimeEarnings: CoinFormatter.string(from: player.meta.lifetimeEarnings),
            oro: String(player.meta.oro),
            oroLifetime: String(player.meta.oroEarnedLifetime),
            // El texto del HUD, no un formateo paralelo (ver el docstring del tipo).
            incomePerSecond: towerIncomePerSecondText,
            prestigeLevel: String(player.meta.prestigeLevel),
            maxFloorName: floors.count > maxOrdinal ? TowerNaming.floorName(for: floors[maxOrdinal].id) : "",
            maxTier: String(player.run.maxTierReached),
            floorsUnlocked: "\(openCount)/\(floors.count)",
            unitCount: String(player.run.totalUnits),
            seenTypes: "\(seenCount)/\(concrete.count)",
            skins: "\(skinCount)/\(content.skins.skins.count)",
            specials: "\(specialCount)/\(content.specials.specials.count)",
            // ⚠️ Los cinco de abajo son los HISTÓRICOS de `meta.stats`, que
            // sobreviven a la reencarnación. No confundir con el "N contratados"
            // de FisuJobs, que es el contador de la RUN (`run.hireCountsByType`,
            // el que mueve el precio) y vuelve a cero al reencarnar.
            totalMerges: String(stats.totalMergesEver),
            totalHires: String(stats.totalHiresEver),
            totalTaps: String(stats.totalTapsEver),
            videosWatched: String(stats.videosWatchedEver),
            boostsActivated: String(stats.boostsActivatedEver),
            shares: String(player.meta.sharesCompleted)
        )
    }

    /// Cuántas veces reencarnaste, ya en texto.
    ///
    /// Existe aparte de `statsSnapshot` porque el organigrama lo necesita **solo**
    /// —para la tarjeta del Jefe— y pedir la foto entera por una línea sale caro
    /// dos veces: recorre cuatro catálogos, y —lo que de verdad importa— ata la
    /// pantalla a `towerIncomePerSecondText`, que cambia sola mientras la torre
    /// produce. Con eso, los 43 nodos se rearmarían cada vez que el income
    /// abreviado pasa de "12,3K" a "12,4K".
    var prestigeLevelText: String { String(player?.meta.prestigeLevel ?? 0) }

    /// La cadena de evolución entera, **con el jefe arriba**: tier descendente.
    ///
    /// El orden es la mitad del diseño de la pantalla: un organigrama se lee de
    /// arriba para abajo, y arriba va el que manda. El empate se desempata por
    /// id porque las cuatro ramas de carrera comparten tier: sin criterio fijo,
    /// dos lecturas seguidas podrían devolver los cuatro hermanos en distinto
    /// orden y la fila se reacomodaría sola mientras el jugador la mira.
    ///
    /// `concreteTypes` ya excluye el nodo de elección de carrera (`junior`), que
    /// es una bifurcación y no un empleado.
    var orgChartRows: [OrgChartRow] {
        guard let content, let player else { return [] }
        return content.tiers.concreteTypes.map { type in
            let seen = player.run.seenTypes.contains(type.id)
            let ordinal = content.floorTable.ordinal(forTier: type.tier)
            return OrgChartRow(
                id: type.id,
                displayName: seen ? type.displayName : "???",
                faceKey: "\(type.id)_face",
                count: player.run.units[type.id] ?? 0,
                tier: type.tier,
                floorID: content.floorTable[ordinal].id,
                seen: seen
            )
        }
        .sorted { lhs, rhs in
            lhs.tier == rhs.tier ? lhs.id < rhs.id : lhs.tier > rhs.tier
        }
    }
}
