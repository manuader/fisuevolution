import EconomyKit
import Foundation

/// Los gestos del jugador ya resueltos: tap, contratar, drop (merge/movimiento/
/// ascenso), elección de carrera, ficha de personaje y compra de pasivo.
/// Separado de `GameState.swift` para que el frente de la carrera no comparta
/// archivo con los otros cinco dominios.
extension GameState {
    struct TapResult {
        let gain: Double
        let isCrit: Bool
        let isGolden: Bool
    }

    /// Tap con rolls de crítico (× critMultiplier) y golden touch (×10).
    /// `cellIndex` = slot del piso visible. Nil si el slot está vacío.
    @discardableResult
    func registerTap(cellIndex: Int) -> TapResult? {
        guard let economy, let content, var player = player,
              let typeId = tower?.typeId(floorOrdinal: visibleFloorOrdinal, slot: cellIndex),
              let type = content.tiers.type(id: typeId)
        else { return nil }

        var gain = economy.applyTap(
            type: type,
            state: &player,
            floorTable: content.floorTable,
            now: Date().timeIntervalSince1970
        )
        let isCrit = Double.random(in: 0..<1, using: &rng) < player.meta.derivedEffects.critChance
        let isGolden = Double.random(in: 0..<1, using: &rng) < player.meta.derivedEffects.goldenChance
        var bonusFactor = 1.0
        if isCrit { bonusFactor *= content.economy.critMultiplier }
        if isGolden { bonusFactor *= 10 }
        if bonusFactor > 1 {
            let extra = gain * (bonusFactor - 1)
            player.run.coins += extra
            player.meta.lifetimeEarnings += extra
            gain += extra
        }
        player.meta.stats.totalTapsEver += 1
        self.player = player
        if !ftueTapped {
            ftueTapped = true
            UserDefaults.standard.set(true, forKey: "ftue.tapped")
        }
        audio?.play(isCrit || isGolden ? .coin : .tap)
        // Los logros de toques (1.000 / 100.000) y los de riqueza no tienen otro
        // choke point: sin esto sólo se enterarían en la próxima fusión. La
        // pasada cuesta una comparación por logro pendiente, contra el
        // `refreshProjections` de la línea de abajo.
        evaluateAchievements()
        refreshProjections()
        scheduleSave()
        return TapResult(gain: gain, isCrit: isCrit, isGolden: isGolden)
    }

    /// Contrata el tier base del piso donde cae la oferta (F7 §3.3): el visible,
    /// o el de abajo si el gate cerró el visible.
    func buySpawn() {
        guard let content, var player = player, var tower,
              let ordinal = hireTargetOrdinal(player: player),
              let quote = currentQuote(player: player, floorOrdinal: ordinal)
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
            // Ídem `hireCharacter`: el contador lo mueve `TowerActions.hire`.
            evaluateAchievements()
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

    /// Resolves a drag-drop from the scene (slots del piso visible; F7 §3.4:
    /// si el resultado pertenece a un piso superior, asciende — piso destino
    /// lleno bloquea el merge).
    func handleDrop(fromCell: Int, toCell: Int) -> DropResolution {
        guard let content, var player = player, var tower, fromCell != toCell,
              let sourceType = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: fromCell)
        else { return .snapBack }

        guard let targetType = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: toCell) else {
            if TowerActions.move(floorOrdinal: visibleFloorOrdinal, fromSlot: fromCell, toSlot: toCell, tower: &tower) {
                self.tower = tower
                bumpBoard()
                return .moved
            }
            return .snapBack
        }

        switch MergeRules.evaluate(
            sourceTypeId: sourceType,
            targetTypeId: targetType,
            chosenCareerPath: player.run.chosenCareerPath,
            tiers: content.tiers
        ) {
        case .merged(let newTypeId):
            let tierBefore = player.run.maxTierReached
            // `applyMerge` muta `unlockedFloors`: hay que fotografiarlo antes
            // para saber qué destrabó el ascenso.
            let unlockedBefore = player.run.unlockedFloors
            do {
                let result = try TowerActions.applyMerge(
                    floorOrdinal: visibleFloorOrdinal,
                    sourceSlot: fromCell,
                    targetSlot: toCell,
                    newTypeId: newTypeId,
                    state: &player,
                    tower: &tower,
                    tiers: content.tiers,
                    floorTable: content.floorTable
                )
                let evolvedTo = player.run.maxTierReached > tierBefore ? content.tiers.type(id: newTypeId) : nil
                self.player = player
                self.tower = tower
                // ⚠️ Se pide el turno ACÁ, antes que nada.
                //
                // `updateMaxFloorStat()` (más abajo) acredita la skin de
                // milestone y `rollSpecialDrop()` puede soltar un special: los
                // dos asignan su payload y piden turno. Si el ascenso encolara
                // después, la cola ya estaría ocupada —no se expropia lo que está
                // en pantalla— y el sheet taparía el vuelo y el reveal, que es
                // exactamente el bug que esto arregla. La ESCENA es la que
                // reproduce la cadena, pero el turno lo pide quien sabe primero
                // que hay algo que celebrar.
                //
                // Y se lleva anotado si este ascenso ABRE el piso: la animación
                // se reproduce igual siempre, pero apagar la UI es exclusivo de
                // la primera vez (pedido del dueño). `unlockedFloorId` sólo viene
                // cuando el piso destino no estaba en `unlockedFloors`, así que es
                // exactamente "primera vez" y no hay que llevar cuenta aparte.
                var promoted = false
                var opensNewFloor = false
                if case .promoted(_, _, _, let unlockedFloorId) = result {
                    promoted = true
                    opensNewFloor = unlockedFloorId != nil
                }
                if evolvedTo != nil || promoted { celebrateBoard(opensNewFloor: opensNewFloor) }
                // El aviso se asigna y listo: la cola lo ordena. `.towerNotice`
                // tiene la prioridad más baja, así que sale después del ascenso
                // y del sheet de skin sin que nadie tenga que encadenarlo.
                if case .promoted = result {
                    let newlyHireable = TowerActions.newlyHireableFloors(
                        unlockedBefore: unlockedBefore,
                        unlockedAfter: player.run.unlockedFloors,
                        floorTable: content.floorTable
                    )
                    // El más bajo: es el que el jugador va a querer rellenar.
                    if let ordinal = newlyHireable.first {
                        towerNotice = TowerNotice(kind: .hireUnlocked(floorID: content.floorTable[ordinal].id))
                    }
                }
                if !ftueMerged {
                    ftueMerged = true
                    UserDefaults.standard.set(true, forKey: "ftue.merged")
                }
                audio?.play(evolvedTo != nil ? .evolution : .merge)
                reportMergeMilestones()
                rollSpecialDrop()
                updateMaxFloorStat()
                bumpBoard()
                scheduleSave()
                switch result {
                case .stayed(_, let slot, _):
                    return .merged(
                        targetCell: slot,
                        evolvedTo: evolvedTo,
                        promotedType: nil,
                        promotedToFloor: nil,
                        unlockedFloorId: nil
                    )
                case .promoted(let toFloor, _, _, let unlockedFloorId):
                    return .merged(
                        targetCell: toCell,
                        evolvedTo: evolvedTo,
                        promotedType: content.tiers.type(id: newTypeId),
                        promotedToFloor: toFloor,
                        unlockedFloorId: unlockedFloorId
                    )
                case .requiresCareerChoice:
                    return .snapBack  // unreachable: MergeRules ya resolvió
                }
            } catch TowerError.destinationFloorFull(let floorID) {
                towerNotice = TowerNotice(kind: .destinationFloorFull(floorID: floorID))
                haptics?.play(.error)
                audio?.play(.error)
                Log.economy.info("merge blocked: destination floor full")
                return .snapBack
            } catch {
                Log.economy.info("merge rejected: \(error)")
                return .snapBack
            }
        case .requiresCareerChoice(let options):
            careerPrompt = CareerPrompt(
                options: options.compactMap { content.tiers.type(id: $0) },
                sourceCell: fromCell,
                targetCell: toCell
            )
            return .careerPending
        case .invalid:
            return .snapBack
        }
    }

    /// Completes the deferred T9 merge after the player picks a career. The choice
    /// persists until the next reincarnation (bible §1).
    func chooseCareer(optionId: String) {
        guard let prompt = careerPrompt, let content, var player = player, var tower else { return }
        player.run.chosenCareerPath = MergeRules.careerPath(fromOptionId: optionId)

        guard let sourceType = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: prompt.sourceCell),
              let targetType = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: prompt.targetCell),
              case .merged(let newTypeId) = MergeRules.evaluate(
                  sourceTypeId: sourceType,
                  targetTypeId: targetType,
                  chosenCareerPath: player.run.chosenCareerPath,
                  tiers: content.tiers
              )
        else {
            self.player = player
            careerPrompt = nil
            celebrationFinished(.careerChoice)
            // Elegiste igual, así que cobrás igual (RF-15).
            grantCareerReward(optionId: optionId)
            refreshProjections()
            return
        }

        do {
            _ = try TowerActions.applyMerge(
                floorOrdinal: visibleFloorOrdinal,
                sourceSlot: prompt.sourceCell,
                targetSlot: prompt.targetCell,
                newTypeId: newTypeId,
                state: &player,
                tower: &tower,
                tiers: content.tiers,
                floorTable: content.floorTable
            )
        } catch {
            Log.economy.info("career merge rejected: \(error)")
        }
        self.player = player
        self.tower = tower
        careerPrompt = nil
        celebrationFinished(.careerChoice)
        // El premio de una vez que hace que elegir carrera defina algo (RF-15).
        // Vive en `+Bonus`: es un bonus más, y este archivo sólo lo dispara.
        grantCareerReward(optionId: optionId)
        reportMergeMilestones()
        rollSpecialDrop()
        updateMaxFloorStat()
        bumpBoard()
        scheduleSave()
    }

    func dismissTowerNotice(id: UUID) {
        guard towerNotice?.id == id else { return }
        towerNotice = nil
        celebrationFinished(.towerNotice)
    }

    private func reportMergeMilestones() {
        guard let player else { return }
        gameCenter?.report(.firstMerge)
        gameCenter?.report(.reachedTier(player.run.maxTierReached))
        gameCenter?.report(.scoreUpdate(lifetimeEarnings: player.meta.lifetimeEarnings, maxTier: player.run.maxTierReached))
    }

    private func rollSpecialDrop() {
        guard let economy, let content, var player else { return }
        if let dropped = SpecialDropManager.rollOnMerge(
            state: &player,
            config: content.specials,
            upgrades: content.upgradesConfig,
            viral: content.viral,
            economy: economy,
            rng: &rng
        ) {
            // Anclaje visual: el special queda en el piso donde cayó (⚠️5).
            if let floorId = visibleFloorDef?.id {
                player.meta.specialAnchors[dropped.id] = floorId
            }
            self.player = player
            specialDrop = dropped
            haptics?.play(.rarity)
            audio?.play(.rare)
            Log.economy.info("special dropped: \(dropped.id)")
        }
    }

    func dismissSpecialDrop() {
        specialDrop = nil
        celebrationFinished(.specialDrop)
    }

    /// Long-press on a unit → ficha por personaje (§2.3 regla 3).
    /// `cellIndex` = slot del piso visible.
    func presentCharacterSheet(cellIndex: Int) {
        guard let content, let player, let tower,
              let typeId = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: cellIndex),
              let type = content.tiers.type(id: typeId)
        else { return }
        characterSheet = CharacterSheet(
            type: type,
            cellIndex: cellIndex,
            instanceCount: player.run.units[type.id] ?? 0,
            isUnlocked: player.run.passiveUnlocked[type.id] == true,
            canAfford: player.run.coins >= type.passiveUnlockCost,
            canDismiss: player.run.totalUnits > 1
        )
    }

    /// "Dejar de contratar": saca la unidad del slot y libera el espacio.
    func dismissCharacter(atCell cell: Int) {
        guard var player, var tower else { return }
        guard TowerActions.removeUnit(floorOrdinal: visibleFloorOrdinal, slot: cell, state: &player, tower: &tower) else { return }
        self.player = player
        self.tower = tower
        characterSheet = nil
        playHaptic(.merge)
        bumpBoard()
        scheduleSave()
    }

    func unlockPassive(typeId: String) {
        guard let economy, let content, var player = player else { return }
        do {
            try economy.applyPassiveUnlock(typeId: typeId, state: &player, tiers: content.tiers)
            self.player = player
            haptics?.play(.purchase)
            characterSheet = nil
            refreshProjections()
            scheduleSave()
        } catch {
            haptics?.play(.error)
            audio?.play(.error)
            Log.economy.info("passive unlock rejected: \(error)")
        }
    }
}
