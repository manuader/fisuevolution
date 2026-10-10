import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La ruleta en la partida")
@MainActor
struct WheelRuntimeTests {
    private let day: TimeInterval = 86_400

    /// Mediodía local: lejos de la medianoche, para que ±1 día no dependa del huso.
    private var noon: TimeInterval {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))
        return date?.timeIntervalSince1970 ?? 0
    }

    @Test("seis giros por video por día, y al día siguiente vuelven")
    func sixVideoSpinsADay() async throws {
        let gameState = await makeGameState()
        let now = noon
        for _ in 0..<6 {
            #expect(gameState.spinWheel(.video, now: now) != nil)
        }
        #expect(gameState.spinWheel(.video, now: now) == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: now).videoLeft == 0)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: now + day).videoLeft == 6)
        #expect(gameState.spinWheel(.video, now: now + day) != nil)
    }

    @Test("el cupo se renueva a la medianoche exacta, no un segundo antes")
    func theQuotaRollsAtMidnight() async throws {
        let gameState = await makeGameState()
        let midnight = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 16)))
        let lastSecond = midnight.timeIntervalSince1970 - 1
        for _ in 0..<6 { _ = gameState.spinWheel(.video, now: lastSecond) }
        #expect(gameState.spinWheel(.video, now: lastSecond) == nil)
        #expect(gameState.spinWheel(.video, now: midnight.timeIntervalSince1970) != nil)
    }

    @Test("un reloj atrasado no devuelve los cupos gastados")
    func aRewoundClockDoesNotRefillTheQuota() async throws {
        let gameState = await makeGameState()
        for _ in 0..<6 { _ = gameState.spinWheel(.video, now: noon) }
        #expect(gameState.spinWheel(.video, now: noon - day) == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: noon - day).videoLeft == 0)
    }

    @Test("viaje al oeste: un día guardado que es mañana se respeta, y el reloj real no da cupos nuevos")
    func aDayAheadIsRespected() async throws {
        let gameState = await makeGameState()
        for _ in 0..<6 { _ = gameState.spinWheel(.video, now: noon + day) }
        #expect(gameState.spinWheel(.video, now: noon) == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: noon).videoLeft == 0)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: noon + 2 * day).videoLeft == 6)
    }

    @Test("un día guardado un año adelante (reloj roto, otro dispositivo) no bloquea: hoy vuelven los cupos")
    func aFarFutureDayDoesNotLockTheWheel() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.engagement.wheel = WheelState(
            day: GameState.wheelDay(noon + 365 * day), videoSpinsUsed: 6, oroSpinsUsed: 6, bonusSpins: 2
        )
        let availability = gameState.wheelAvailability(storefrontAllows: true, now: noon)
        #expect(availability.videoLeft == 6 && availability.oroLeft == 6 && availability.bonus == 2)
        #expect(gameState.spinWheel(.video, now: noon) != nil)
        #expect(gameState.player?.meta.engagement.wheel.day == GameState.wheelDay(noon))
    }

    @Test("el día es gregoriano aunque el calendario del dispositivo no lo sea")
    func theDayIsGregorian() {
        #expect(GameState.wheelDay(noon) == "2026-06-15")
        let date = Date(timeIntervalSince1970: noon)
        for identifier in [Calendar.Identifier.japanese, .buddhist, .persian] {
            let other = DailyRewardManager.dayString(for: date, calendar: Calendar(identifier: identifier))
            #expect(other != GameState.wheelDay(noon), "\(identifier) cambia el año")
        }
    }

    @Test("repetir un cofre que ya no tiene nada que dar da el segmento de respaldo")
    func repeatingAChestFallsBackToCoins() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.player?.meta.engagement.wheel = WheelState(day: GameState.wheelDay(noon), repeatableSegmentId: "chest")
        let unlocked = gameState.chestUnlockedCharacterTypes
        gameState.player?.meta.milestoneSkins = content.skins.chestPool
            .filter { unlocked.contains($0.characterType) }.map(\.id)
        #expect(!gameState.wheelChestHasSomethingToGive)
        let chests = try #require(gameState.player?.meta.chestsPending)
        let outcome = try #require(gameState.repeatWheelPrize(now: noon))
        #expect(outcome.segment.id == content.wheel.chestFallbackSegmentId)
        #expect(outcome.coins > 0)
        #expect(gameState.player?.meta.chestsPending == chests)
    }

    @Test("el premio se acredita al girar, antes de cualquier animación")
    func thePrizeIsGrantedOnSpin() async throws {
        let gameState = await makeGameState()
        for _ in 0..<6 {
            let before = try #require(gameState.player)
            let outcome = try #require(gameState.spinWheel(.video))
            let after = try #require(gameState.player)
            switch outcome.segment.reward {
            case .coinsSeconds: #expect(after.run.coins > before.run.coins && outcome.coins > 0)
            case .modifier: #expect(after.run.activeModifiers.contains { $0.sourceKey == "wheel.\(outcome.segment.id)" })
            case .oro(let amount): #expect(after.meta.oro == before.meta.oro + amount)
            case .package(let count): #expect(after.meta.engagement.packages.waiting == before.meta.engagement.packages.waiting + count)
            case .skinChest(let count): #expect(after.meta.chestsPending == before.meta.chestsPending + count)
            default: Issue.record("la ruleta dio \(outcome.segment.reward.kind)")
            }
        }
    }

    @Test("el giro queda gastado y el premio repetible en el estado, en el acto")
    func theSpinIsRecordedImmediately() async throws {
        let gameState = await makeGameState()
        let outcome = try #require(gameState.spinWheel(.video, now: noon))
        let wheel = try #require(gameState.player?.meta.engagement.wheel)
        #expect(wheel.videoSpinsUsed == 1)
        #expect(wheel.repeatableSegmentId == outcome.segment.id)
        #expect(wheel.day == GameState.wheelDay(noon))
    }

    @Test("repetir da lo mismo, una sola vez por giro")
    func repeatingOnce() async throws {
        let gameState = await makeGameState()
        let outcome = try #require(gameState.spinWheel(.video, now: noon))
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: noon).canRepeat)
        let again = try #require(gameState.repeatWheelPrize(now: noon))
        #expect(again.segment.id == outcome.segment.id)
        #expect(gameState.repeatWheelPrize(now: noon) == nil)
        #expect(!gameState.wheelAvailability(storefrontAllows: false, now: noon).canRepeat)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: noon).videoLeft == 5, "repetir no gasta un giro")
    }

    @Test("repetir el premio de plata acredita otra vez; el de ORO suma otra vez")
    func repeatingPaysAgain() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.engagement.wheel = WheelState(day: GameState.wheelDay(noon), repeatableSegmentId: "oro_3")
        let before = try #require(gameState.player?.meta.oro)
        #expect(gameState.repeatWheelPrize(now: noon) != nil)
        #expect(gameState.player?.meta.oro == before + 3)
    }

    @Test("sin giro previo, o al día siguiente, no hay nada que repetir")
    func nothingToRepeat() async throws {
        let gameState = await makeGameState()
        #expect(gameState.repeatWheelPrize(now: noon) == nil)
        _ = gameState.spinWheel(.video, now: noon)
        #expect(gameState.repeatWheelPrize(now: noon + day) == nil)
    }

    @Test("el giro con ORO cuesta 12, tiene su tope y se apaga donde la tienda no lo permite")
    func theOroSpin() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 100
        #expect(gameState.spinWheel(.oro, storefrontAllows: false, now: noon) == nil)
        #expect(gameState.player?.meta.oro == 100)
        #expect(gameState.player?.meta.engagement.wheel.oroSpinsUsed == 0)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: noon).oroLeft == 0)
        for spin in 1...6 {
            _ = try #require(gameState.spinWheel(.oro, storefrontAllows: true, now: noon))
            #expect(gameState.player?.meta.stats.oroSpentEver == 12 * spin)
        }
        let oroAfterSix = try #require(gameState.player?.meta.oro)
        #expect(gameState.spinWheel(.oro, storefrontAllows: true, now: noon) == nil)
        #expect(gameState.player?.meta.oro == oroAfterSix, "el séptimo no cobra")
    }

    @Test("el borde del saldo: con 12 ORO gira y queda en 0; con 11 no gira ni cobra")
    func theOroBalanceEdge() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 11
        #expect(!gameState.wheelAvailability(storefrontAllows: true, now: noon).canPayOro)
        #expect(gameState.spinWheel(.oro, storefrontAllows: true, now: noon) == nil)
        #expect(gameState.player?.meta.oro == 11)
        #expect(gameState.player?.meta.engagement.wheel.oroSpinsUsed == 0)
        gameState.player?.meta.oro = 12
        #expect(gameState.wheelAvailability(storefrontAllows: true, now: noon).canPayOro)
        let outcome = try #require(gameState.spinWheel(.oro, storefrontAllows: true, now: noon))
        let prizeOro: Int = if case .oro(let amount) = outcome.segment.reward { amount } else { 0 }
        #expect(gameState.player?.meta.oro == prizeOro, "se cobró 12 una sola vez; el premio puede devolver ORO")
        #expect(gameState.player?.meta.engagement.wheel.oroSpinsUsed == 1)
    }

    @Test("el giro con ORO no toca los cupos de video ni los regalados")
    func oroSpinLeavesOtherQuotas() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 50
        gameState.debugAddWheelSpins(2)
        _ = try #require(gameState.spinWheel(.oro, storefrontAllows: true, now: noon))
        let availability = gameState.wheelAvailability(storefrontAllows: true, now: noon)
        #expect(availability.videoLeft == 6 && availability.bonus == 2 && availability.oroLeft == 5)
    }

    @Test("sin ORO no gira ni cobra")
    func noOroNoSpin() async {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 5
        #expect(gameState.spinWheel(.oro, storefrontAllows: true) == nil)
        #expect(gameState.player?.meta.oro == 5)
        #expect(!gameState.wheelAvailability(storefrontAllows: true).canPayOro)
    }

    @Test("un reloj atrasado tampoco devuelve el cupo de ORO")
    func aRewoundClockDoesNotRefillTheOroQuota() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 500
        for _ in 0..<6 { _ = gameState.spinWheel(.oro, storefrontAllows: true, now: noon) }
        #expect(gameState.spinWheel(.oro, storefrontAllows: true, now: noon - day) == nil)
        #expect(gameState.spinWheel(.oro, storefrontAllows: true, now: noon + day) != nil)
    }

    @Test("un giro regalado no pide video y no vence con el día")
    func giftedSpins() async throws {
        let gameState = await makeGameState()
        gameState.grant(.wheelSpin(1), source: "visit.conductor_ruleta", now: noon)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: noon + day).bonus == 1)
        #expect(gameState.spinWheel(.bonus, now: noon + day) != nil)
        #expect(gameState.spinWheel(.bonus, now: noon + day) == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: noon + day).videoLeft == 6)
    }

    @Test("grant(.wheelSpin) suma de a n, y el ×2 con video suma el doble")
    func grantingSpins() async {
        let gameState = await makeGameState()
        gameState.grant(.wheelSpin(2), source: "test")
        #expect(gameState.player?.meta.engagement.wheel.bonusSpins == 2)
        gameState.grant(.wheelSpin(1), multiplier: 2, source: "test")
        #expect(gameState.player?.meta.engagement.wheel.bonusSpins == 4)
    }

    @Test("con el cofre sin nada que dar, la ruleta no tiene cofre y su peso es plata")
    func anEmptyChestLeavesTheWheel() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        #expect(gameState.wheelChestHasSomethingToGive)
        #expect(gameState.wheelSegments.contains { $0.reward.kind == .skinChest })
        let unlocked = gameState.chestUnlockedCharacterTypes
        gameState.player?.meta.milestoneSkins = content.skins.chestPool
            .filter { unlocked.contains($0.characterType) }.map(\.id)
        #expect(!gameState.wheelChestHasSomethingToGive)
        #expect(!gameState.wheelSegments.contains { $0.reward.kind == .skinChest })
        #expect(gameState.wheelSegments.map(\.weight).reduce(0, +) == 100)
        #expect(gameState.wheelOdds.map(\.id) == gameState.wheelSegments.map(\.id), "lo mostrado es lo que gira")
        for _ in 0..<6 {
            let outcome = try #require(gameState.spinWheel(.video, now: noon))
            #expect(outcome.segments == gameState.wheelSegments, "se gira sobre la tabla efectiva")
            #expect(outcome.segment.reward.kind != .skinChest)
        }
    }

    @Test("la ruleta y el colchón sólo dan lo que el juego sabe entregar")
    func everyPrizeIsGrantable() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let kinds = content.wheel.segments.map(\.reward.kind) + content.treasures.prizes.flatMap { $0.rewards.map(\.kind) }
        #expect(Set(kinds).isSubset(of: GameState.grantableRewardKinds))
    }

    @Test("sin partida cargada, no hay nada que girar")
    func noPlayer() {
        let gameState = GameState()
        #expect(gameState.spinWheel(.video) == nil)
        #expect(gameState.repeatWheelPrize() == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: true) == .none)
    }
}
