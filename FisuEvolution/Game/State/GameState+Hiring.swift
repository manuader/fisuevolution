import EconomyKit
import Foundation

/// Una fila de FisuJobs (§5.1), ya resuelta: la vista la dibuja sin volver a
/// preguntarle nada al estado ni conocer `PlayerState`.
///
/// ⚠️ **Los payloads de `gated` y `lockedFloor` son el NOMBRE del piso ya
/// resuelto** ("Callejón"), no una clave de localización — el label dice `Key`
/// porque así quedó fijada la firma que consume la vista, pero armar un
/// `LocalizedStringKey` con esto es exactamente la trampa 5 del HANDOFF. La
/// vista los interpola dentro de SU clave (`jobs.gated %@`, `jobs.locked %@`),
/// que es el único camino que el catálogo resuelve.
struct JobRow: Identifiable, Equatable {
    /// Por qué esta fila se puede comprar o no. La plata NO entra acá: un tipo
    /// contratable que no podés pagar sigue siendo `hirable` con
    /// `affordable == false`, porque el botón se desatura pero se toca igual
    /// (nunca `.disabled` — patrón `SpawnButtonView`).
    enum State: Equatable {
        /// Piso abierto, gate abierto y hay lugar.
        case hirable
        /// Todo en orden salvo el espacio: el piso destino está lleno.
        case floorFull
        /// El piso está abierto pero su gate pide el de arriba. El payload es el
        /// NOMBRE de ese piso de arriba, ya resuelto.
        case gated(aboveFloorNameKey: String)
        /// El piso del tipo todavía no se abrió. El payload es el NOMBRE de ese
        /// piso —el propio, no el de arriba—, ya resuelto.
        case lockedFloor(floorNameKey: String)
        /// Nunca visto en esta run: silueta y "???" (criterio RF-03, no
        /// espoilear la cadena de evolución).
        case unseen
    }

    let id: String
    /// "???" cuando el tipo nunca se vio.
    let displayName: String
    /// Clave del manifest para el retrato. Las 43 caras de los 43 tipos
    /// concretos existen (auditoría RF-05), así que no lleva fallback a nil como
    /// `CharacterUpgradeRow`: si alguna faltara, `UIArt` ya cae al placeholder.
    let faceKey: String
    /// "+2,5/s cada uno": lo que rinde por segundo UNA instancia con el pasivo
    /// puesto. Mismo texto y misma fórmula que la pestaña Personajes.
    let incomeText: String
    /// Cuántos tenés vivos ahora mismo (`run.units`).
    let hiredCount: Int
    /// Cuántos compraste en esta run (`run.hireCountsByType`): es el exponente
    /// que mueve el precio, y por eso la tarjeta lo muestra.
    let purchases: Int
    /// "" cuando el tipo nunca se vio: una fila "???" no es una oferta.
    let costText: String
    let affordable: Bool
    let state: State
    let tier: Int
    let floorID: String
}

/// La pantalla FisuJobs: qué se ofrece y qué pasa al comprarlo (§5).
///
/// Separado de `GameState.swift` para que el frente de la tienda de
/// contratación no comparta archivo con los otros seis dominios.
extension GameState {
    /// Las filas de FisuJobs, listas para dibujar.
    ///
    /// Es computada y no una proyección publicada por el mismo motivo que
    /// `characterUpgradeRows`: la pantalla es un modal y se re-evalúa contra
    /// `coinsText` + `boardVersion` + `effectsVersion`, que son las tres cosas
    /// que mueven una fila (el precio, el lugar en el piso y las mejoras).
    /// Publicar 43 filas ocho veces por segundo para una hoja que casi nunca
    /// está abierta sería difundir el array entero por nada.
    ///
    /// El orden sale de lo que podés HACER con la fila y no del catálogo:
    /// primero lo comprable con el mejor arriba (tier descendente, como el
    /// Animal Shop del spec), después lo bloqueado con lo más cercano arriba
    /// (tier ascendente: es la lista de lo que viene), y al final los que nunca
    /// viste. Empate de tier —las cuatro ramas de carrera comparten tier— se
    /// desempata por id para que el orden sea estable entre dos lecturas.
    var jobRows: [JobRow] {
        guard let content, let player else { return [] }
        let coins = player.run.coins

        let rows: [JobRow] = content.tiers.concreteTypes.compactMap { type in
            // `nil` sólo para el nodo de elección de carrera, que no es un
            // personaje contratable sino la bifurcación.
            guard let quote = currentQuote(player: player, typeId: type.id) else { return nil }
            let floor = content.floorTable[quote.floorOrdinal]
            let state = jobState(for: type, ordinal: quote.floorOrdinal, player: player, content: content)
            let unseen = state == .unseen
            return JobRow(
                id: type.id,
                displayName: unseen ? "???" : type.displayName,
                faceKey: "\(type.id)_face",
                incomeText: passiveEffectText(for: type),
                hiredCount: player.run.units[type.id] ?? 0,
                // Del quote y no de `run.hireCountsByType` a mano: es el mismo
                // número, y leerlo de donde salió el precio impide que la
                // tarjeta diga "3 contratados" con la curva en otro exponente.
                purchases: quote.purchases,
                costText: unseen ? "" : CoinFormatter.string(from: quote.cost),
                affordable: !unseen && coins >= quote.cost,
                state: state,
                tier: type.tier,
                floorID: floor.id
            )
        }
        return rows.sorted { lhs, rhs in
            let lhsGroup = Self.jobGroup(lhs.state)
            let rhsGroup = Self.jobGroup(rhs.state)
            guard lhsGroup == rhsGroup else { return lhsGroup < rhsGroup }
            guard lhs.tier != rhs.tier else { return lhs.id < rhs.id }
            return lhsGroup == 0 ? lhs.tier > rhs.tier : lhs.tier < rhs.tier
        }
    }

    /// Contrata un TIPO concreto desde FisuJobs.
    ///
    /// Gemela de `buySpawn()` —mismos efectos, mismo orden— pero cotizando por
    /// tipo en vez de por el tier base del piso visible. Las dos conviven hasta
    /// que la Task 7 borre el botón viejo.
    ///
    /// ⚠️ **La autorización no está acá abajo.** `TowerActions.hire` gatea piso
    /// abierto, gate del piso, saldo y slot, pero **no mira el tipo** (su
    /// docstring lo dice: cotizar un tipo no es autorizarlo). Alcanza porque la
    /// regla de FisuJobs es POR PISO: cualquier tier de un piso abierto con el
    /// gate abierto se puede comprar, y el `tierPremium` lo hace carísimo. Lo
    /// único que no cubre ese guard es el tipo nunca visto de un piso abierto —
    /// la fila sale "???" y sin precio, así que la pantalla no lo ofrece.
    func hireCharacter(typeId: String) {
        guard let content, var player = player, var tower,
              let quote = currentQuote(player: player, typeId: typeId)
        else { return }
        do {
            _ = try TowerActions.hire(
                quote: quote,
                state: &player,
                tower: &tower,
                floorTable: content.floorTable
            )
            self.player = player
            self.tower = tower
            if !ftueSpawned {
                ftueSpawned = true
                UserDefaults.standard.set(true, forKey: "ftue.spawned")
            }
            haptics?.play(.purchase)
            audio?.play(.buy)
            bumpBoard()
            scheduleSave()
        } catch {
            if case TowerError.floorFull = error {
                towerNotice = TowerNotice(kind: .floorFull)
            }
            haptics?.play(.error)
            audio?.play(.error)
            Log.economy.info("hire rejected: \(error)")
        }
    }

    /// Cotización por TIPO con el descuento de prestigio puesto: el gemelo de
    /// `currentQuote(player:floorOrdinal:)` para el camino de FisuJobs.
    ///
    /// El `costMultiplier` sale de la misma fuente que el del botón viejo. Si se
    /// calculara distinto, el mismo personaje costaría distinto según de dónde
    /// lo comprás, que es justo el bug que el balance-log documenta para la
    /// fórmula de precio.
    func currentQuote(player: PlayerState, typeId: String) -> HireQuote? {
        guard let content else { return nil }
        let prestigeDiscount = content.prestigeUnlocks.cumulativeSpawnDiscount(
            atPrestigeLevel: player.meta.prestigeLevel
        )
        return TowerActions.hireQuote(
            typeId: typeId,
            state: player,
            config: content.economy,
            floorTable: content.floorTable,
            tiers: content.tiers,
            costMultiplier: 1 - prestigeDiscount,
            now: Date().timeIntervalSince1970
        )
    }

    /// Qué se puede hacer con este tipo, en orden de prioridad.
    ///
    /// `unseen` gana sobre todo lo demás a propósito: un tipo del callejón que
    /// nunca viste no se muestra con nombre por más que su piso esté abierto
    /// (RF-03, no espoilear la cadena).
    private func jobState(
        for type: CharacterType,
        ordinal: Int,
        player: PlayerState,
        content: GameContent
    ) -> JobRow.State {
        guard player.run.seenTypes.contains(type.id) else { return .unseen }
        let floor = content.floorTable[ordinal]
        guard player.run.unlockedFloors.contains(floor.id) else {
            return .lockedFloor(floorNameKey: TowerNaming.floorName(for: floor.id))
        }
        guard TowerActions.canHire(
            floorOrdinal: ordinal,
            unlockedFloors: player.run.unlockedFloors,
            floorTable: content.floorTable
        ) else {
            // El gate es de UN piso, así que el que falta es siempre el de
            // arriba. El `min` es defensivo: el último piso desbloqueado se
            // habilita a sí mismo, así que no puede caer acá.
            let above = min(ordinal + 1, content.floorTable.count - 1)
            return .gated(aboveFloorNameKey: TowerNaming.floorName(for: content.floorTable[above].id))
        }
        // El `max` es por el `(0, 0)` que `floorOccupancy` devuelve cuando la
        // torre todavía no cargó: sin él, un piso sin capacidad conocida saldría
        // "lleno" y la pantalla mentiría durante el arranque. Ningún piso real
        // tiene capacidad 0 (la valida `FloorTable`), así que no tapa un lleno.
        let occupancy = floorOccupancy(ordinal: ordinal)
        guard occupancy.occupied < max(occupancy.capacity, 1) else { return .floorFull }
        return .hirable
    }

    /// Los tres grupos del orden. Piso lleno viaja con los contratables: el piso
    /// está abierto y el gate también, y lo que falta se arregla mergeando en el
    /// mismo piso donde ya estás mirando.
    private static func jobGroup(_ state: JobRow.State) -> Int {
        switch state {
        case .hirable, .floorFull: 0
        case .gated, .lockedFloor: 1
        case .unseen: 2
        }
    }
}
