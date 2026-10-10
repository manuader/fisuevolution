import EconomyKit
import Foundation

/// Un giro ya resuelto: el premio se acreditó ANTES de que la rueda se mueva.
struct WheelSpinOutcome: Equatable {
    /// La tabla con la que se giró (la efectiva) y dónde cayó.
    let segments: [WheelConfig.Segment]
    let index: Int
    /// La plata acreditada (0 si el premio no era plata).
    let coins: Double

    var segment: WheelConfig.Segment { segments[index] }
}

/// Lo que la ruleta ofrece ahora.
struct WheelAvailability: Equatable {
    let bonus: Int
    let videoLeft: Int
    /// 0 donde la tienda no permite azar con ORO.
    let oroLeft: Int
    let oroCost: Int
    let canPayOro: Bool
    let canRepeat: Bool

    var hasFreeSpin: Bool { bonus > 0 || videoLeft > 0 }

    static let none = WheelAvailability(bonus: 0, videoLeft: 0, oroLeft: 0, oroCost: 0, canPayOro: false, canRepeat: false)
}

/// La Ruleta en la partida (PLAN-v2 E5).
extension GameState {
    /// La tabla que se muestra y la que gira: si un cofre hoy no tendría nada
    /// que dar, su peso pasa a la plata.
    var wheelSegments: [WheelConfig.Segment] {
        content?.wheel.effectiveSegments(chestHasSomethingToGive: wheelChestHasSomethingToGive) ?? []
    }

    var wheelOdds: [PrizeOdds] {
        content?.wheel.odds(chestHasSomethingToGive: wheelChestHasSomethingToGive) ?? []
    }

    /// La misma pregunta que `canOpenChest`, sin pedir cofres pendientes.
    var wheelChestHasSomethingToGive: Bool {
        guard let content, let player else { return false }
        return ChestRoller.hasSomethingToGive(
            owned: player.meta.allOwnedSkins, unlocked: chestUnlockedCharacterTypes, skins: content.skins
        )
    }

    func wheelAvailability(storefrontAllows: Bool, now: TimeInterval = Date().timeIntervalSince1970) -> WheelAvailability {
        guard let content, let wheelConfig = effectiveWheel, let player else { return .none }
        let state = Self.wheelState(player.meta.engagement.wheel, at: now)
        let oroLeft = storefrontAllows ? WheelRoller.spinsLeft(.oro, state: state, config: wheelConfig) : 0
        return WheelAvailability(
            bonus: WheelRoller.spinsLeft(.bonus, state: state, config: wheelConfig),
            videoLeft: WheelRoller.spinsLeft(.video, state: state, config: wheelConfig),
            oroLeft: oroLeft,
            oroCost: content.wheel.oroSpinCost,
            canPayOro: oroLeft > 0 && player.meta.oro >= content.wheel.oroSpinCost,
            canRepeat: state.repeatableSegmentId != nil
        )
    }

    /// Gira. El premio se sortea y se acredita acá, y se guarda en el acto: si
    /// matan la app en medio de la animación, el giro ya se gastó y el premio ya
    /// es del jugador. El video ya se vio antes de llamar; el ORO se cobra acá,
    /// y sólo si el giro sale.
    @discardableResult
    func spinWheel(
        _ source: WheelSpinSource,
        storefrontAllows: Bool = false,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> WheelSpinOutcome? {
        guard let content, let wheelConfig = effectiveWheel, var player else { return nil }
        var wheel = Self.wheelState(player.meta.engagement.wheel, at: now)
        if source == .oro {
            guard storefrontAllows, WheelRoller.spinsLeft(.oro, state: wheel, config: wheelConfig) > 0,
                  player.meta.spendOro(content.wheel.oroSpinCost)
            else { return nil }
        }
        let segments = wheelSegments
        guard WheelRoller.consume(source, state: &wheel, config: wheelConfig),
              let index = WheelRoller.roll(segments, using: &rng)
        else { return nil }
        wheel.repeatableSegmentId = segments[index].id
        player.meta.engagement.wheel = wheel
        self.player = player
        let coins = grant(segments[index].reward, source: "wheel.\(segments[index].id)", now: now)
        Task { await persistNow() }
        Log.economy.info("wheel spin (\(source.rawValue)): \(segments[index].id)")
        return WheelSpinOutcome(segments: segments, index: index, coins: coins)
    }

    /// Lo que llama la vista: el cerrojo corta el segundo toque ANTES de cobrar
    /// (el giro por ORO descuenta al instante) y se suelta si el giro no sale.
    /// Quien lo tomó lo suelta al terminar la animación.
    @discardableResult
    func beginWheelSpin(
        _ source: WheelSpinSource,
        latch: inout PurchaseLatch,
        storefrontAllows: Bool = false,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> WheelSpinOutcome? {
        guard latch.claim() else { return nil }
        guard let outcome = spinWheel(source, storefrontAllows: storefrontAllows, now: now) else {
            latch.release()
            return nil
        }
        return outcome
    }

    /// "Repetir premio": otro video que vuelve a dar lo mismo (no es otro
    /// giro). Una vez por giro.
    @discardableResult
    func repeatWheelPrize(now: TimeInterval = Date().timeIntervalSince1970) -> WheelSpinOutcome? {
        guard let content, var player else { return nil }
        var wheel = Self.wheelState(player.meta.engagement.wheel, at: now)
        guard let id = wheel.repeatableSegmentId else { return nil }
        let segments = wheelSegments
        // Si el cofre ya no tiene nada que dar, lo que se repite es su respaldo.
        let wasChest = content.wheel.segments.first { $0.id == id }?.reward.kind == .skinChest
        let repeated = segments.first { $0.id == id }
            ?? (wasChest ? segments.first { $0.id == content.wheel.chestFallbackSegmentId } : nil)
        guard let repeated, let index = segments.firstIndex(of: repeated) else { return nil }
        wheel.repeatableSegmentId = nil
        player.meta.engagement.wheel = wheel
        self.player = player
        let coins = grant(repeated.reward, source: "wheel.\(repeated.id)", now: now)
        Task { await persistNow() }
        Log.economy.info("wheel prize repeated: \(repeated.id)")
        return WheelSpinOutcome(segments: segments, index: index, coins: coins)
    }

    /// El día de los cupos: el del diario, pero siempre en calendario
    /// gregoriano. Con el japonés o el budista el año cambia y cambiar de
    /// calendario dejaría el día guardado "en el futuro".
    static func wheelDay(_ now: TimeInterval) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return DailyRewardManager.dayString(for: Date(timeIntervalSince1970: now), calendar: calendar)
    }

    /// El estado pasado al día de `now`. Un reloj atrasado (o un viaje al
    /// oeste) no devuelve los cupos de ayer: se respeta un día guardado que
    /// llegue hasta mañana. Uno más lejano es un reloj roto o el día de otro
    /// dispositivo, y no puede bloquear la ruleta: se vuelve a hoy. Los días
    /// "yyyy-MM-dd" se ordenan como texto.
    static func wheelState(_ state: WheelState, at now: TimeInterval) -> WheelState {
        let today = wheelDay(now)
        guard let saved = state.day, saved > today, saved <= wheelDay(now + 86_400) else {
            return state.rolledOver(to: today)
        }
        return state
    }

    /// Cuándo vuelven los giros por video, si hoy se usó alguno: la medianoche
    /// que cierra el día guardado, con el mismo calendario gregoriano fijo de
    /// `wheelDay` y la misma tolerancia (un día guardado futuro sólo cuenta hasta
    /// mañana). Los giros regalados y los de ORO no avisan: los regalados no
    /// vencen y el de ORO depende de la tienda. Sin giros por video usados, nada.
    func wheelSpinsReadyAt(now: TimeInterval) -> TimeInterval? {
        guard let wheel = player?.meta.engagement.wheel else { return nil }
        let state = Self.wheelState(wheel, at: now)
        guard state.videoSpinsUsed > 0, let saved = state.day else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: now))
        return (1...2)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: today)?.timeIntervalSince1970 }
            .first { Self.wheelDay($0) > saved }
    }

    /// El tic de una rebanada que pasa bajo el puntero: el sonido y una
    /// vibración corta. El ritmo lo marca la vista (`WheelGeometry.boundariesCrossed`);
    /// el anti-duplicado de `AudioManager` evita la ametralladora al arrancar.
    func playWheelTick() {
        audio?.play(.wheelTick)
        haptics?.play(.tick)
    }

    #if DEBUG
    func debugAddWheelSpins(_ count: Int) {
        guard var player, count > 0 else { return }
        player.meta.engagement.wheel.bonusSpins += count
        self.player = player
    }

    /// El próximo acceso arranca un día nuevo: los cupos vuelven.
    func debugWheelNewDay() {
        guard var player else { return }
        player.meta.engagement.wheel.day = nil
        self.player = player
    }
    #endif
}
