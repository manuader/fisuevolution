import Foundation

extension PacingSimulator {
    /// Lo que en el juego es azar entra por valor esperado: cada sorteo suma su
    /// probabilidad a un acumulador por resultado, y cuando uno pasa de 1 sale
    /// ese resultado. Arranca en `seedFraction`: determinístico y sin sesgo.
    struct ExpectedDraws {
        private var buckets: [String: Double] = [:]
        let seed: Double

        init(seed: Double) { self.seed = seed }

        /// Suma `probability` al resultado `id` y devuelve cuántas veces salió.
        mutating func add(_ probability: Double, to id: String) -> Int {
            let total = buckets[id, default: seed] + probability
            let whole = Int(total.rounded(.down))
            buckets[id] = total - Double(whole)
            return whole
        }
    }

    /// Los relojes de las fuentes: los paquetes corren en segundos ACTIVOS (de
    /// juego, como en el juego) y los regalos con cooldown en segundos de PARED.
    struct SourceClocks {
        var nextPackageAt: Double
        var waitingPackages = 0
        var lastBoostAt: [String: Double] = [:]
        var lastDailyDay = -1
        var cycleDay = 0
        var draws: ExpectedDraws

        init(nextPackageAt: Double, seedFraction: Double) {
            self.nextPackageAt = nextPackageAt
            self.draws = ExpectedDraws(seed: seedFraction)
        }
    }

    // MARK: - Regalos de inicio de sesión

    /// El diario y los boosts gratis cuyo cooldown venció: lo que el jugador
    /// cobra al abrir la app, sin mirar un video.
    func startSession(
        state: inout PlayerState, clocks: inout SourceClocks, report: inout Report, wall: Double
    ) {
        state.run.activeModifiers.removeAll { !$0.isActive(at: wall) }
        guard profile.usesFreeGifts else { return }

        let day = Int(wall / human.daySeconds)
        if day != clocks.lastDailyDay, !sources.dailyMinutes.isEmpty {
            let minutes = sources.dailyMinutes[clocks.cycleDay % sources.dailyMinutes.count]
            let amount = payout(minutes: minutes, state: state)
            earn(state: &state, amount: amount)
            report.sourceTotals["coins.daily", default: 0] += amount
            clocks.cycleDay += 1
        }
        clocks.lastDailyDay = day

        for boost in sources.freeBoosts {
            if let last = clocks.lastBoostAt[boost.id], wall - last < boost.cooldownSeconds { continue }
            clocks.lastBoostAt[boost.id] = wall
            let amount = redeem(boost.effect, state: &state)
            earn(state: &state, amount: amount)
            report.sourceTotals["coins.boosts", default: 0] += amount
        }
    }

    private func payout(minutes: Double, state: PlayerState) -> Double {
        RewardScale.coinPayout(minutes: minutes, state: state, tiers: tiers, floorTable: floorTable, config: config)
    }

    /// Las monedas que deja un boost al canjearlo (cero si su efecto no es en
    /// monedas: la Milanesa sube la eficiencia offline).
    private func redeem(_ effect: PacingSources.FreeBoost.Effect, state: inout PlayerState) -> Double {
        switch effect {
        case .incomeBurst(let multiplier, let seconds):
            return RewardScale.coinPayout(
                seconds: (multiplier - 1) * seconds,
                state: state, tiers: tiers, floorTable: floorTable, config: config
            )
        case .tapBurst(let multiplier, let seconds):
            let tapRate = activeIncomeRate(state: state) - passiveRate(state: state)
            return max(0, (multiplier - 1) * seconds * tapRate)
        case .payoutMinutes(let minutes):
            return payout(minutes: minutes, state: state)
        case .offlineStep(let step, let cap):
            let current = state.meta.derivedEffects.offlineEfficiency
            state.meta.derivedEffects.offlineEfficiency = max(current, min(cap, current + step))
            return 0
        }
    }

    /// El premio del Programador al elegir carrera: contratar gratis un rato.
    func grantFreeHire(state: inout PlayerState, wall: Double) {
        guard profile.usesFreeGifts, sources.freeHireSeconds > 0 else { return }
        state.run.activeModifiers.append(ActiveModifier(
            effect: .freeHire, magnitude: 1, expiresAt: wall + sources.freeHireSeconds,
            sourceKey: "career.junior_programmer"
        ))
    }

    // MARK: - El Paquete de la Aduana

    /// Cae el paquete que toque en el reloj activo y abre los que esperan.
    /// Devuelve cuántos abrió (cada uno cuesta un toque de la sesión). Un
    /// paquete sin lugar donde caer espera, como en el juego.
    func tickPackages(
        state: inout PlayerState, clocks: inout SourceClocks, report: inout Report, active: Double
    ) -> Int {
        guard profile.usesFreeGifts, let packages = sources.packages else { return 0 }
        while active >= clocks.nextPackageAt {
            if clocks.waitingPackages >= packages.maxWaiting {
                clocks.nextPackageAt = active + packages.spawnIntervalSeconds
                break
            }
            clocks.waitingPackages += 1
            clocks.nextPackageAt += packages.spawnIntervalSeconds
        }

        var opened = 0
        while clocks.waitingPackages > 0, openPackage(state: &state, clocks: &clocks, packages: packages) {
            clocks.waitingPackages -= 1
            report.sourceTotals["packages.opened", default: 0] += 1
            opened += 1
        }
        return opened
    }

    /// Sortea y entrega un paquete. `false` si no hay a quién traer.
    private func openPackage(state: inout PlayerState, clocks: inout SourceClocks, packages: PackagesConfig) -> Bool {
        let occupancy = (0..<floorTable.count).map { floorCount($0, state: state) }
        let eligible = PackageRoller.eligibleTypes(
            state: state, tiers: tiers, floorTable: floorTable, config: config, occupancy: occupancy
        )
        let table = PackageRoller.odds(
            eligible: eligible, windowTiers: packages.windowTiers,
            ratio: packages.tierRatio(bestSupplierLevel: 0)
        )
        guard !table.isEmpty else { return false }
        for odds in table {
            let arrivals = clocks.draws.add(odds.probability, to: "pkg.T\(odds.tier)")
            guard arrivals > 0, let type = packageType(among: odds.typeIds) else { continue }
            let ordinal = floorTable.ordinal(forTier: type.tier)
            for _ in 0..<arrivals where floorCount(ordinal, state: state) < floorTable[ordinal].capacity {
                state.run.units[type.id, default: 0] += 1
            }
        }
        return true
    }

    private func packageType(among typeIds: [String]) -> CharacterType? {
        let id = typeIds.first(where: { $0.hasSuffix(careerPath) }) ?? typeIds.first
        return id.flatMap { tiers.type(id: $0) }
    }
}
