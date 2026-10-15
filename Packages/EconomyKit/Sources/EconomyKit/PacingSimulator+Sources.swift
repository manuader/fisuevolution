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
        /// Las cajas que esperan, la más vieja primero (E14b B18): lo que traen se decide al
        /// caer (`nil` = cayó sin nadie a quien traer, se sortea al abrir). Con los sorteos
        /// esperados una caja puede traer cero, uno o más.
        var packageBoxes: [[String]?] = []
        var lastBoostAt: [String: Double] = [:]
        var lastDailyDay = -1
        var cycleDay = 0
        var draws: ExpectedDraws

        // Los relojes de las fuentes de video. Los del colchón, la pausa y el
        // "Fusionar todo" corren en segundos ACTIVOS; el de la lluvia, en PARED.
        var nextMattressAt = Double.infinity
        var nextAdBreakAt = Double.infinity
        var mergeAllReadyAt = Double.infinity
        var nextRainWall = Double.infinity
        var adBreakIndex = 0
        /// El "próximo offline / diario ×k" que dejó un premio, a cobrar una vez.
        var pendingOfflineMultiplier = 1.0
        var pendingDailyMultiplier = 1.0
        /// Giros de ruleta que dejó un premio, a girar sin video.
        var pendingSpins = 0
        var wheelDay = -1
        /// Videos mirados al volver de una ausencia: su tiempo sale de la sesión
        /// que arranca.
        var pendingVideoSeconds = 0.0
        /// Entró blue de una fuente y el bot todavía no lo gastó en líneas.
        var hasUnspentBlue = false

        init(nextPackageAt: Double, seedFraction: Double, ads: AdsSources? = nil) {
            self.nextPackageAt = nextPackageAt
            self.draws = ExpectedDraws(seed: seedFraction)
            guard let ads else { return }
            nextMattressAt = ads.treasures.map { $0.firstTreasureAfterSeconds > 0 ? $0.firstTreasureAfterSeconds : .infinity } ?? .infinity
            nextAdBreakAt = ads.adBreakIntervalSeconds > 0 && !ads.adBreakPrizes.isEmpty ? ads.adBreakIntervalSeconds : .infinity
            mergeAllReadyAt = ads.mergeAllCooldownSeconds > 0 ? ads.mergeAllCooldownSeconds : .infinity
            nextRainWall = ads.packageRain == nil || ads.packageRainCooldownSeconds <= 0 ? .infinity : 0
        }
    }

    /// Las fuentes de video, sólo si el perfil las mira.
    var activeAds: AdsSources? { profile.watchesVideos ? sources.ads : nil }

    /// Los permanentes de la tienda, sólo si el perfil los tiene.
    var activeShop: ShopPermanents? { profile.ownsShopPermanents ? sources.shop : nil }

    // MARK: - Regalos de inicio de sesión

    /// El diario y los boosts gratis cuyo cooldown venció: lo que el jugador
    /// cobra al abrir la app. Con videos, además el diario ×2 y la ruleta del día.
    /// Devuelve los segundos de sesión que se fueron en videos.
    func startSession(
        state: inout PlayerState, clocks: inout SourceClocks, report: inout Report, wall: Double, active: Double
    ) -> Double {
        state.run.activeModifiers.removeAll { !$0.isActive(at: wall) }
        guard profile.usesFreeGifts else { return 0 }

        let ads = activeAds
        var videoSeconds = clocks.pendingVideoSeconds
        clocks.pendingVideoSeconds = 0
        let day = Int(wall / human.daySeconds)
        if day != clocks.lastDailyDay, !sources.dailyMinutes.isEmpty {
            let minutes = sources.dailyMinutes[clocks.cycleDay % sources.dailyMinutes.count]
            var amount = payout(minutes: minutes, state: state)
            amount *= clocks.pendingDailyMultiplier
            clocks.pendingDailyMultiplier = 1
            if let ads, ads.dailyMultiplier > 1 {
                amount *= ads.dailyMultiplier
                videoSeconds += watchVideo(ads, report: &report)
            }
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

        if let ads, let wheel = ads.wheel, day != clocks.wheelDay {
            clocks.wheelDay = day
            for _ in 0..<max(0, wheel.videoSpinsPerDay + (activeShop?.bonusDailyWheelSpins ?? 0)) {
                videoSeconds += watchVideo(ads, report: &report)
                spin(wheel, state: &state, clocks: &clocks, report: &report)
                if ads.wheelRepeats {
                    videoSeconds += watchVideo(ads, report: &report)
                    spin(wheel, state: &state, clocks: &clocks, report: &report)
                }
            }
        }
        if let ads {
            videoSeconds += drainSpins(ads, state: &state, clocks: &clocks, report: &report)
            settleBlue(state: &state, clocks: &clocks, report: &report, wall: wall, active: active)
        }
        return videoSeconds
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
    /// Con videos es el ×2 de la carrera. Devuelve los segundos de video.
    func grantFreeHire(state: inout PlayerState, wall: Double, report: inout Report) -> Double {
        guard profile.usesFreeGifts, sources.freeHireSeconds > 0 else { return 0 }
        var seconds = sources.freeHireSeconds
        var videoSeconds = 0.0
        if let ads = activeAds, ads.careerMultiplier > 1 {
            seconds *= ads.careerMultiplier
            videoSeconds = watchVideo(ads, report: &report)
        }
        state.run.activeModifiers.append(ActiveModifier(
            effect: .freeHire, magnitude: 1, expiresAt: wall + seconds,
            sourceKey: "career.junior_programmer"
        ))
        return videoSeconds
    }

    // MARK: - El Paquete de la Aduana

    /// Cae el paquete que toque en el reloj activo y abre los que esperan.
    /// Devuelve cuántos abrió (cada uno cuesta un toque de la sesión). Lo que
    /// trae se sortea al caer, con el estado de ese momento (E14b B18); una
    /// caja cuyo piso está lleno espera, como en el juego.
    func tickPackages(
        state: inout PlayerState, clocks: inout SourceClocks, report: inout Report, active: Double
    ) -> Int {
        guard profile.usesFreeGifts, let packages = sources.packages else { return 0 }
        while active >= clocks.nextPackageAt {
            if clocks.packageBoxes.count >= packages.maxWaiting {
                clocks.nextPackageAt = active + packages.spawnIntervalSeconds
                break
            }
            clocks.packageBoxes.append(rollPackage(state: state, clocks: &clocks, packages: packages))
            clocks.nextPackageAt += packages.spawnIntervalSeconds
        }

        var opened = 0
        var index = 0
        while index < clocks.packageBoxes.count {
            if clocks.packageBoxes[index] == nil {
                clocks.packageBoxes[index] = rollPackage(state: state, clocks: &clocks, packages: packages)
            }
            guard let content = clocks.packageBoxes[index], deliver(content, state: &state) else {
                index += 1
                continue
            }
            clocks.packageBoxes.remove(at: index)
            report.sourceTotals["packages.opened", default: 0] += 1
            opened += 1
        }
        return opened
    }

    /// Sortea lo que trae una caja que aparece. `nil` si no hay a quién traer.
    private func rollPackage(state: PlayerState, clocks: inout SourceClocks, packages: PackagesConfig) -> [String]? {
        let occupancy = (0..<floorTable.count).map { floorCount($0, state: state) }
        let eligible = PackageRoller.eligibleTypes(
            state: state, tiers: tiers, floorTable: floorTable, config: config, occupancy: occupancy
        )
        let table = PackageRoller.odds(
            eligible: eligible, windowTiers: packages.windowTiers,
            ratio: packages.tierRatio(bestSupplierLevel: activeShop?.bestSupplierLevel ?? 0)
        )
        guard !table.isEmpty else { return nil }
        var content: [String] = []
        for odds in table {
            let arrivals = clocks.draws.add(odds.probability, to: "pkg.T\(odds.tier)")
            guard arrivals > 0, let type = packageType(among: odds.typeIds) else { continue }
            content.append(contentsOf: Array(repeating: type.id, count: arrivals))
        }
        return content
    }

    /// Abre una caja ya sorteada: entran los que tienen lugar en su piso. `false` (y la caja
    /// espera) si traía a alguien y ninguno entra.
    private func deliver(_ content: [String], state: inout PlayerState) -> Bool {
        var delivered = content.isEmpty
        for typeId in content {
            guard let type = tiers.type(id: typeId) else { continue }
            let ordinal = floorTable.ordinal(forTier: type.tier)
            guard floorCount(ordinal, state: state) < floorTable[ordinal].capacity else { continue }
            state.run.units[typeId, default: 0] += 1
            delivered = true
        }
        return delivered
    }

    private func packageType(among typeIds: [String]) -> CharacterType? {
        let id = typeIds.first(where: { $0.hasSuffix(careerPath) }) ?? typeIds.first
        return id.flatMap { tiers.type(id: $0) }
    }
}

// MARK: - Lo que se cobra mirando videos

extension PacingSimulator {
    /// Un video mirado: cuenta en el reporte y devuelve lo que le saca a la sesión.
    func watchVideo(_ ads: AdsSources, report: inout Report) -> Double {
        report.sourceTotals["videos", default: 0] += 1
        return ads.videoSeconds
    }

    /// Los segundos hasta el próximo evento de las fuentes de video (infinito sin ellas).
    func untilNextAdsEvent(clocks: SourceClocks, active: Double, wall: Double) -> Double {
        guard activeAds != nil else { return .infinity }
        return min(clocks.nextMattressAt - active, clocks.nextAdBreakAt - active, clocks.nextRainWall - wall)
    }

    /// Lo que vence en el reloj activo o de pared: el colchón, la pausa y la
    /// lluvia. Devuelve los segundos de sesión que se fueron en videos.
    func tickAds(
        state: inout PlayerState, clocks: inout SourceClocks, report: inout Report, active: Double, wall: Double
    ) -> Double {
        guard let ads = activeAds else { return 0 }
        var seconds = 0.0

        if let treasures = ads.treasures, active >= clocks.nextMattressAt {
            // Cada apertura es un video: la primera (salvo la parte que llega de regalo, E14b B6)
            // y los "otro colchón".
            for open in 0...max(0, treasures.extraOpensPerTreasure) {
                let paidShare = open == 0 ? 1 - treasures.giftShare : 1
                seconds += ads.videoSeconds * paidShare
                report.sourceTotals["videos", default: 0] += paidShare
                for (prize, odds) in zip(treasures.prizes, treasures.odds) {
                    for reward in prize.rewards {
                        apply(reward, probability: odds.probability, source: "mattress",
                              state: &state, clocks: &clocks, report: &report)
                    }
                }
            }
            clocks.nextMattressAt = active + treasures.spawnIntervalSeconds
        }

        if active >= clocks.nextAdBreakAt, !ads.adBreakPrizes.isEmpty {
            seconds += watchVideo(ads, report: &report)
            apply(ads.adBreakPrizes[clocks.adBreakIndex % ads.adBreakPrizes.count], probability: 1,
                  source: "adBreak", state: &state, clocks: &clocks, report: &report)
            clocks.adBreakIndex += 1
            clocks.nextAdBreakAt = active + ads.adBreakIntervalSeconds
        }

        if let rain = ads.packageRain, wall >= clocks.nextRainWall {
            seconds += watchVideo(ads, report: &report)
            apply(rain, probability: 1, source: "rain", state: &state, clocks: &clocks, report: &report)
            clocks.nextRainWall = wall + ads.packageRainCooldownSeconds
        }

        seconds += drainSpins(ads, state: &state, clocks: &clocks, report: &report)
        settleBlue(state: &state, clocks: &clocks, report: &report, wall: wall, active: active)
        return seconds
    }

    /// Un giro de la ruleta por valor esperado: cada segmento paga con su
    /// probabilidad. El bot no tiene pintas que el cofre pueda dar.
    func spin(_ wheel: WheelConfig, state: inout PlayerState, clocks: inout SourceClocks, report: inout Report) {
        let segments = wheel.effectiveSegments(chestHasSomethingToGive: false)
        for (segment, odds) in zip(segments, wheel.odds(chestHasSomethingToGive: false)) {
            apply(segment.reward, probability: odds.probability, source: "wheel",
                  state: &state, clocks: &clocks, report: &report)
        }
    }

    /// Gira los giros que dejaron los premios (sin video; el "repetir premio"
    /// sí cuesta uno). Los premios de esos giros pueden dejar más: se corta en 100.
    private func drainSpins(
        _ ads: AdsSources, state: inout PlayerState, clocks: inout SourceClocks, report: inout Report
    ) -> Double {
        guard let wheel = ads.wheel else {
            clocks.pendingSpins = 0
            return 0
        }
        var seconds = 0.0
        var guardrail = 100
        while clocks.pendingSpins > 0, guardrail > 0 {
            clocks.pendingSpins -= 1
            guardrail -= 1
            spin(wheel, state: &state, clocks: &clocks, report: &report)
            if ads.wheelRepeats {
                seconds += watchVideo(ads, report: &report)
                spin(wheel, state: &state, clocks: &clocks, report: &report)
            }
        }
        clocks.pendingSpins = 0
        return seconds
    }

    /// El blue que entró de una fuente se gasta en líneas en el acto.
    private func settleBlue(
        state: inout PlayerState, clocks: inout SourceClocks, report: inout Report, wall: Double, active: Double
    ) {
        guard clocks.hasUnspentBlue else { return }
        clocks.hasUnspentBlue = false
        buyPermanentUpgrades(state: &state, report: &report, wall: wall, active: active)
    }

    /// El único lugar donde un `RewardSpec` toca la economía del bot. Todo entra
    /// por valor esperado (`probability`); lo que no mueve la economía del bot
    /// (cofres de pintas, autotoque, lugares extra, inmunidad, descuentos y demás
    /// modificadores) se ignora a propósito.
    func apply(
        _ reward: RewardSpec, probability: Double, source: String,
        state: inout PlayerState, clocks: inout SourceClocks, report: inout Report
    ) {
        switch reward {
        case .coinsSeconds(let seconds):
            credit(coins(seconds: seconds * probability, state: state), source: source, state: &state, report: &report)
        case let .modifier(effect, magnitude, seconds):
            switch effect {
            case .incomeMultiplier, .passiveMultiplier:
                credit(coins(seconds: (magnitude - 1) * seconds * probability, state: state),
                       source: source, state: &state, report: &report)
            case .tapMultiplier:
                let tapRate = activeIncomeRate(state: state) - passiveRate(state: state)
                credit(max(0, (magnitude - 1) * seconds * tapRate * probability),
                       source: source, state: &state, report: &report)
            default:
                break
            }
        case .blue(let amount):
            let whole = clocks.draws.add(Double(amount) * probability, to: "blue")
            guard whole > 0 else { return }
            // Sólo el balance, como `grant(.blue)` en la app: `blueEarnedLifetime` lo gana el prestigio.
            state.meta.blue += whole
            report.sourceTotals["blue.fromSources", default: 0] += Double(whole)
            clocks.hasUnspentBlue = true
        case .package(let count):
            let won = clocks.draws.add(Double(count) * probability, to: "pkg.extra")
            clocks.packageBoxes.append(contentsOf: [[String]?](repeating: nil, count: won))
        case .nextOfflineMultiplier(let multiplier):
            clocks.pendingOfflineMultiplier *= 1 + (multiplier - 1) * probability
        case .nextDailyMultiplier(let multiplier):
            clocks.pendingDailyMultiplier *= 1 + (multiplier - 1) * probability
        case .wheelSpin(let count):
            clocks.pendingSpins += clocks.draws.add(Double(count) * probability, to: "wheel.spin")
        case .skinChest, .clearBoostCooldowns, .autoTap, .extraSlots, .eventImmunity:
            break
        }
    }

    private func coins(seconds: Double, state: PlayerState) -> Double {
        RewardScale.coinPayout(seconds: seconds, state: state, tiers: tiers, floorTable: floorTable, config: config)
    }

    private func credit(_ amount: Double, source: String, state: inout PlayerState, report: inout Report) {
        earn(state: &state, amount: amount)
        report.sourceTotals["coins.\(source)", default: 0] += amount
    }
}
