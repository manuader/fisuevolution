import EconomyKit
import Foundation

/// El embudo de los cambios del tablero que no hizo el jugador: se planean en
/// el acto y se confirman en su turno, a la vista (PLAN-v2 E1).
extension GameState {
    var boardIsVisibleForChanges: Bool {
        phase == .ready && isSceneActive && !uiCoversBoard && !tutorialPhaseActive
            && careerPrompt == nil && characterSheet == nil && specialInfo == nil
    }

    func enqueueBoardChange(_ change: BoardChange) {
        pendingBoardChanges.append(change)
        Log.economy.info("board change planned: \(change.origin.rawValue)")
    }

    func floorOrdinal(of change: BoardChange) -> Int? {
        guard let content else { return nil }
        return change.floorOrdinal(floorTable: content.floorTable, tiers: content.tiers)
    }

    /// El próximo cambio, revalidado contra el tablero de ahora. Lo pide la escena
    /// al empezar su turno.
    func beginNextBoardChange() -> BoardChange? {
        guard inFlightBoardChange == nil, boardIsVisibleForChanges else { return nil }
        guard let content, let player, let tower else { return nil }
        while !pendingBoardChanges.isEmpty {
            let planned = pendingBoardChanges.removeFirst()
            guard let valid = BoardChangePlanner.revalidate(
                planned, state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable
            ) else {
                discardBoardChange(planned)
                continue
            }
            inFlightBoardChange = valid
            setBoardCelebrationShowsSomethingNew(BoardChangePlanner.revealsSomethingNew(
                valid, state: player, tiers: content.tiers, floorTable: content.floorTable
            ))
            return valid
        }
        return nil
    }

    /// Aplica el cambio en vuelo si el tablero de ahora todavía lo admite tal
    /// cual: entre el inicio y la confirmación pudo entrar un evento o una
    /// contratación. La segunda llamada por el mismo id —completion tardío,
    /// skip, watchdog— no encuentra nada y devuelve `nil`.
    @discardableResult
    func confirmBoardChange(id: UUID) -> DropResolution? {
        guard let change = inFlightBoardChange, change.id == id else { return nil }
        inFlightBoardChange = nil
        guard let content, let player, let tower,
              BoardChangePlanner.revalidate(
                  change, state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable
              ) == change
        else {
            discardBoardChange(change)
            return nil
        }
        return applyBoardChange(change)
    }

    func settleInFlightBoardChange() {
        guard let change = inFlightBoardChange else { return }
        confirmBoardChange(id: change.id)
    }

    /// Al irse: lo pendiente se aplica en silencio y queda en el save; la red de
    /// seguridad revela lo nuevo al volver.
    func settleAllPendingBoardChanges() {
        settleInFlightBoardChange()
        while !pendingBoardChanges.isEmpty {
            let planned = pendingBoardChanges.removeFirst()
            guard let content, let player, let tower,
                  let valid = BoardChangePlanner.revalidate(
                      planned, state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable
                  )
            else {
                discardBoardChange(planned)
                continue
            }
            applyBoardChange(valid)
        }
    }

    /// Al pasar a inactivo (App Switcher: un kill puede venir sin `.background`)
    /// se asienta lo que el jugador ya pagó —un video visto, una carrera
    /// elegida—; lo demás espera a `.background`.
    func settlePrepaidBoardChanges() {
        guard let content else { return }
        if inFlightBoardChange?.isPrepaid == true { settleInFlightBoardChange() }
        let prepaid = pendingBoardChanges.filter(\.isPrepaid)
        pendingBoardChanges.removeAll(where: \.isPrepaid)
        for planned in prepaid {
            guard let player, let tower,
                  let valid = BoardChangePlanner.revalidate(
                      planned, state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable
                  )
            else {
                discardBoardChange(planned)
                continue
            }
            applyBoardChange(valid)
        }
    }

    /// La escena lo llama al ARRANCAR un reveal: un reveal salteado ya se vio.
    func markRevealed(tier: Int) {
        guard var player, tier > player.run.revealedTier else { return }
        player.run.revealedTier = tier
        self.player = player
        scheduleSave()
    }

    /// El personaje más alto de la run que todavía no se reveló.
    var typePendingReveal: CharacterType? {
        guard let content, let player, player.run.maxTierReached > player.run.revealedTier else { return nil }
        let candidates = content.tiers.concreteTypes.filter { $0.tier == player.run.maxTierReached }
        return candidates.first { player.run.seenTypes.contains($0.id) } ?? candidates.first
    }

    /// Dónde cae el resultado cuando el cambio sube de piso y el slot de salida
    /// no existe: el destino que el plan miró.
    private func plannedSlot(of change: BoardChange) -> Int {
        switch change.kind {
        case .merge(_, _, _, let targetSlot, _): targetSlot
        case .evolve(_, let slot, _, _), .departure(_, let slot, _): slot
        case .arrival: -1
        }
    }

    func discardBoardChange(_ change: BoardChange) {
        Log.economy.info("board change dropped: \(change.origin.rawValue)")
    }

    @discardableResult
    private func applyBoardChange(_ change: BoardChange) -> DropResolution? {
        guard let content, var player, var tower else { return nil }
        do {
            let outcome = try BoardChangeApplier.apply(
                change, state: &player, tower: &tower, tiers: content.tiers, floorTable: content.floorTable
            )
            self.player = player
            self.tower = tower
            let result = outcome.resultTypeId.flatMap { content.tiers.type(id: $0) }
            let evolvedTo = player.run.maxTierReached > outcome.tierBefore ? result : nil
            announceNewlyHireableFloor(maxTierBefore: outcome.tierBefore, player: player, content: content)
            if case .merge = change.kind { reportMergeMilestones() }
            updateMaxFloorStat()
            bumpBoard()
            scheduleSave()
            return .merged(
                targetCell: outcome.slot ?? plannedSlot(of: change),
                evolvedTo: evolvedTo,
                promotedType: outcome.promotedToFloor == nil ? nil : result,
                promotedToFloor: outcome.promotedToFloor,
                unlockedFloorId: outcome.unlockedFloorId
            )
        } catch {
            Log.economy.info("board change rejected on confirm: \(error)")
            discardBoardChange(change)
            return nil
        }
    }
}

private extension BoardChange {
    var isPrepaid: Bool {
        switch origin {
        case .rewardedInstantMerge, .rewardedRareUnit, .career: true
        case .eventStartup, .eventBlanqueo, .debug: false
        }
    }
}
