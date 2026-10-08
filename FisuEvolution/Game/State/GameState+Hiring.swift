import EconomyKit
import Foundation

/// Una fila de FisuJobs (§5.1), ya resuelta: la vista la dibuja sin volver a
/// preguntarle nada al estado ni conocer `PlayerState`.
///
/// ⚠️ **El payload de `lockedFloor` es el NOMBRE del piso ya resuelto**
/// ("Callejón"), no una clave de localización — el label dice `Key` porque así
/// quedó fijada la firma que consume la vista, pero armar un
/// `LocalizedStringKey` con esto es exactamente la trampa 5 del HANDOFF. La
/// vista lo interpola dentro de SU clave (`jobs.state.locked %@`), que es el
/// único camino que el catálogo resuelve.
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
        /// El piso está abierto pero a este personaje le falta compuerta: tu
        /// frontera de merge todavía no llegó `hire.gateTierDistance` tiers por
        /// encima del suyo. El payload es el TIER al que hay que llegar, que es
        /// lo que el jugador puede ir a mirar en sus estadísticas.
        ///
        /// ⚠️ **Cambió de significado el 2026-08-22.** Era
        /// `gated(aboveFloorNameKey:)` —"falta desbloquear el piso de arriba"—
        /// cuando la compuerta se medía en pisos. Ahora se mide en tiers, así
        /// que el piso de arriba ya no dice nada: dos tipos del MISMO piso
        /// pueden estar uno contratable y el otro no.
        case gated(requiredTier: Int)
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
    /// Cuánto sube la próxima compra (0,06 = "+6 %"), con la curva, el
    /// amortiguador y todo lo demás adentro. `nil` en una fila "???".
    let priceStep: Double?
    /// Cuánto la abarata fusionar un par, con reintegro. `nil` sin reintegro.
    let mergeRelief: Double?
    /// "+6 % por compra · fusionar lo abarata 11 %", ya resuelto.
    let priceTrendText: String?
    let affordable: Bool
    let state: State
    let tier: Int
    let floorID: String
}

/// La oferta del botón "contratar al mejor" de la pantalla principal: el **tier
/// más alto que la plata alcanza**, entre los que FisuJobs ofrece como
/// contratables. Sin nada pagable, el más barato como meta de ahorro.
///
/// ⚠️ **El botón ofrece exactamente lo mismo que FisuJobs vende**, y ésa es la
/// regla desde el 2026-08-28: el atajo no recorta nada que la pantalla de
/// laburos no recorte. Entre el 2026-08-21 y esa fecha vendió sólo el tier base
/// del piso (§4.5 del rebalance) — el porqué de la vuelta atrás, con los tres
/// datos que la sostienen, está en `computeBestHire()`.
///
/// Es una fila de FisuJobs recortada a lo que el botón dibuja, y no un `JobRow`
/// entero, porque el botón no muestra ni el income ni cuántos tenés ni el piso:
/// publicar los quince campos invitaría a la vista a decidir con ellos, que es
/// justo lo que esta proyección viene a evitar.
struct BestHire: Equatable {
    let typeId: String
    let displayName: String
    let faceKey: String
    let costText: String
    /// La plata alcanza. Igual que en `JobRow`, `false` NO deshabilita el botón:
    /// muestra la meta de ahorro y tiembla al tocarlo (patrón `SpawnButtonView`).
    let affordable: Bool
    let tier: Int
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
            // Cuánto sube o baja el precio sólo le importa a lo que se puede contratar.
            let trend = state == .hirable ? priceTrend(player: player, typeId: type.id) : (step: nil, relief: nil)
            return JobRow(
                id: type.id,
                displayName: unseen ? "???" : type.localizedName,
                faceKey: "\(type.id)_face",
                incomeText: passiveEffectText(for: type),
                hiredCount: player.run.units[type.id] ?? 0,
                // Del quote y no de `run.hireCountsByType` a mano: es el mismo
                // número, y leerlo de donde salió el precio impide que la
                // tarjeta diga "3 contratados" con la curva en otro exponente.
                purchases: Int(quote.purchases.rounded(.down)),
                costText: unseen ? "" : CoinFormatter.cost(from: quote.cost),
                priceStep: trend.step,
                mergeRelief: trend.relief,
                priceTrendText: Self.priceTrendText(step: trend.step, relief: trend.relief),
                affordable: !unseen && !quote.blockedBySpendingFreeze && coins >= quote.cost,
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

    /// Calcula la oferta del botón "contratar al mejor".
    ///
    /// La llama SOLO `refreshProjections` (8 Hz): la vista lee la proyección
    /// publicada `bestHire` y nunca esto. Vive en ESTE archivo y no junto a las
    /// otras proyecciones porque se apoya en `jobState`, que es `private` y en
    /// Swift eso alcanza al tipo y a sus extensiones **del mismo archivo**.
    ///
    /// Que la compuerta sea `jobState` y no una regla propia es el punto entero:
    /// el botón ofrece exactamente lo que la pantalla de laburos da por
    /// contratable —piso abierto, gate abierto, lugar libre y, sobre todo, tipo
    /// YA VISTO—, así que no puede espoilear la cadena (RF-03) ni vender algo
    /// que después `TowerActions.hire` rechace. Duplicar la condición acá sería
    /// el mismo error que el balance-log documenta para la fórmula de precio.
    ///
    /// **Encima de esa compuerta no va ningún recorte**: la oferta es el tier más
    /// alto que la plata alcanza entre los contratables, punto.
    ///
    /// ⚠️ **Esto revierte el recorte a tier base que pidió §4.5 del prompt del
    /// rebalance** (commit `2db8f1d`, 2026-08-21), por pedido del dueño del
    /// 2026-08-28. El argumento de entonces era que ofrecer el tier más alto
    /// "saltea la profundidad de merge del piso". Lo que cambió no es la opinión,
    /// son los datos:
    ///
    /// - **FisuJobs siempre vendió todo lo desbloqueado** —`jobRows` no filtra por
    ///   tier base—, así que el recorte nunca movió el techo de lo comprable: sólo
    ///   ponía la mejor compra a tres toques en vez de uno.
    /// - **El simulador de pacing compra todos los tiers desde el 2026-08-22**
    ///   (`PacingSimulator.hireActions`, que lo dice con todas las letras: "el bot
    ///   compraba sólo el tier base y eso dejó de ser una aproximación aceptable…
    ///   el jugador, mientras tanto, tiene esa fila en FisuJobs"). O sea que el
    ///   contrato de las 20-30 h **se midió con un jugador que compra el mejor
    ///   tier**: el recorte hacía al botón peor que el jugador que el balance
    ///   modela, no más seguro que él.
    /// - **La regla de precios tira para el mismo lado** (§5.2): bajar un tier
    ///   abarata 1,5× pero duplica las unidades que hay que fusionar, así que
    ///   comprar hondo ya está penalizado por el precio y no hace falta que además
    ///   lo impida el botón.
    func computeBestHire() -> BestHire? {
        guard let content, let player else { return nil }
        let coins = player.run.coins

        struct Candidate {
            let type: CharacterType
            let cost: Double
            let frozen: Bool
        }
        let candidates: [Candidate] = content.tiers.concreteTypes.compactMap { type in
            guard let quote = currentQuote(player: player, typeId: type.id),
                  jobState(for: type, ordinal: quote.floorOrdinal, player: player, content: content) == .hirable
            else { return nil }
            return Candidate(type: type, cost: quote.cost, frozen: quote.blockedBySpendingFreeze)
        }
        guard !candidates.isEmpty else { return nil }

        let pick: Candidate
        // ⚠️ Los dos comparadores van al revés uno del otro y es a propósito:
        // `max(by:)` recibe un "menor que", así que para que gane el MÁS BARATO
        // hay que declarar barato = mayor (`lhs.cost > rhs.cost`), y para que
        // gane el id ASCENDENTE hay que declarar id chico = mayor
        // (`lhs.type.id > rhs.type.id`). En el `min(by:)` de abajo, que devuelve
        // el mínimo, los mismos dos criterios se escriben derechos.
        //
        // ⚠️⚠️ **Los desempates del `max` vuelven a decidir de verdad** desde que
        // se sacó el filtro de tier base (2026-08-28): sin él, los tiers 11 y 12
        // aportan CUATRO candidatos cada uno —las ramas de carrera— y el empate
        // de tier es la regla, no el borde. Están cubiertos por
        // `tiesOnTierPreferTheCheapest` y `tiesFallBackToTheAscendingID`, que
        // volvieron a la suite por eso mismo. El `min` de la meta de ahorro sigue
        // pineado por `brokePlayerSeesTheCheapestAsAGoal` y
        // `withoutCoinsTheGoalIsTheCheapestOfMany`.
        if let best = candidates.filter({ !$0.frozen && coins >= $0.cost }).max(by: { lhs, rhs in
            if lhs.type.tier != rhs.type.tier { return lhs.type.tier < rhs.type.tier }
            if lhs.cost != rhs.cost { return lhs.cost > rhs.cost }
            return lhs.type.id > rhs.type.id
        }) {
            pick = best
        } else if let goal = candidates.min(by: { lhs, rhs in
            if lhs.cost != rhs.cost { return lhs.cost < rhs.cost }
            return lhs.type.id < rhs.type.id
        }) {
            // Nada pagable: la oferta es lo más barato que hay, para que el
            // botón muestre a cuánto tiene que llegar en vez de desaparecer.
            pick = goal
        } else {
            return nil
        }

        return BestHire(
            typeId: pick.type.id,
            displayName: pick.type.localizedName,
            faceKey: "\(pick.type.id)_face",
            costText: CoinFormatter.cost(from: pick.cost),
            affordable: !pick.frozen && coins >= pick.cost,
            tier: pick.type.tier
        )
    }

    /// Contrata la oferta vigente; no-op si no hay ninguna.
    ///
    /// Reusa `hireCharacter` ENTERO en vez de llamar a `TowerActions.hire` por
    /// su cuenta: FTUE, hápticos, audio, logros, aviso de piso lleno y save
    /// salen de ahí, y una segunda ruta de compra sería una segunda lista de
    /// efectos que mantener sincronizada.
    func hireBestCharacter() {
        guard let best = bestHire else { return }
        hireCharacter(typeId: best.typeId)
    }

    /// Contrata un TIPO concreto desde FisuJobs.
    ///
    /// Gemela de `buySpawn()` —mismos efectos, mismo orden— pero cotizando por
    /// tipo en vez de por el tier base del piso visible. Las dos conviven hasta
    /// que la Task 7 borre el botón viejo.
    ///
    /// **La autorización ya no depende de esta pantalla.** `TowerActions.hire`
    /// gatea piso abierto, saldo, slot y —desde el 2026-08-22— la compuerta del
    /// TIPO, con la misma función que usa `jobState` para pintar la fila. Antes
    /// sus guards eran todos del PISO y la única compuerta por tipo del juego
    /// era esta proyección: un `hireCharacter` llamado con un id de tier alto se
    /// lo vendía igual. Lo único que sigue cubriendo sólo la vista es el tipo
    /// nunca visto de un piso abierto — la fila sale "???" y sin precio, así que
    /// la pantalla no lo ofrece.
    func hireCharacter(typeId: String) {
        guard let content, var player = player, var tower,
              let quote = currentQuote(player: player, typeId: typeId)
        else { return }
        do {
            _ = try TowerActions.hire(
                quote: quote,
                state: &player,
                tower: &tower,
                floorTable: content.floorTable,
                config: content.economy,
                countsAsPurchase: quote.cost > 0
            )
            self.player = player
            self.tower = tower
            if !ftueSpawned {
                ftueSpawned = true
                UserDefaults.standard.set(true, forKey: "ftue.spawned")
            }
            haptics?.play(.purchase)
            audio?.play(.buy)
            // `TowerActions.hire` es quien mueve `totalHiresEver`, así que el
            // logro de contrataciones se mide recién acá (y sólo si la compra
            // salió: el `catch` no cuenta).
            evaluateAchievements()
            bumpBoard()
            scheduleSave()
        } catch {
            publishNotice(forRejectedSpend: error)
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

    /// El paso y el reintegro con los MISMOS argumentos que `currentQuote`: si
    /// cotizaran distinto, la tarjeta diría un número y la compra cobraría otro.
    func priceTrend(player: PlayerState, typeId: String) -> (step: Double?, relief: Double?) {
        guard let content else { return (nil, nil) }
        let costMultiplier = 1 - content.prestigeUnlocks.cumulativeSpawnDiscount(atPrestigeLevel: player.meta.prestigeLevel)
        let now = Date().timeIntervalSince1970
        let step = TowerActions.nextHireStep(
            typeId: typeId, state: player, config: content.economy, floorTable: content.floorTable,
            tiers: content.tiers, costMultiplier: costMultiplier, now: now
        )
        let relief = TowerActions.mergeRelief(
            typeId: typeId, state: player, config: content.economy, floorTable: content.floorTable,
            tiers: content.tiers, costMultiplier: costMultiplier, now: now
        )
        return (step, relief)
    }

    /// ⚠️ Los porcentajes van como `String` (trampa 5).
    static func priceTrendText(step: Double?, relief: Double?) -> String? {
        guard let step else { return nil }
        let percent: (Double) -> String = { $0.formatted(.percent.precision(.fractionLength(0))) }
        let stepText = String(localized: "jobs.step \("+" + percent(step))")
        guard let relief else { return stepText }
        return stepText + " · " + String(localized: "jobs.merge_relief \(percent(relief))")
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
            tier: type.tier,
            maxTierReached: player.run.maxTierReached,
            floorTable: content.floorTable,
            config: content.economy
        ) else {
            // El tier que destraba esta fila. Se arma con el MISMO knob que la
            // regla acaba de aplicar, así que el mensaje no puede prometer un
            // número que la compuerta no exija.
            return .gated(requiredTier: type.tier + content.economy.hire.gateTierDistance)
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
