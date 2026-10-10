import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La ruleta en el aviso de la ausencia")
@MainActor
struct WheelReadyNotificationTests {
    private var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func midnight(after days: Int, from now: TimeInterval) throws -> TimeInterval {
        let today = gregorian.startOfDay(for: Date(timeIntervalSince1970: now))
        return try #require(gregorian.date(byAdding: .day, value: days, to: today)).timeIntervalSince1970
    }

    @Test("sin giros por video hoy no hay nada que avisar")
    func anUntouchedWheelIsQuiet() async {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        #expect(gameState.wheelSpinsReadyAt(now: now) == nil)
        #expect(gameState.notificationSnapshot(now: now)?.wheelSpinsReadyAt == nil)
    }

    @Test("con un giro por video hoy, los giros vuelven a la medianoche")
    func aSpinTodayMeansMidnight() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        _ = try #require(gameState.spinWheel(.video, now: now))
        let expected = try midnight(after: 1, from: now)
        #expect(gameState.wheelSpinsReadyAt(now: now) == expected)
        #expect(gameState.notificationSnapshot(now: now)?.wheelSpinsReadyAt == expected)
    }

    @Test("un día guardado de mañana (reloj atrasado) corre el aviso un día más")
    func aSavedTomorrowPushesTheNoticeOneDay() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        let tomorrow = try midnight(after: 1, from: now)
        _ = try #require(gameState.spinWheel(.video, now: tomorrow))
        #expect(gameState.wheelSpinsReadyAt(now: now) == (try midnight(after: 2, from: now)))
    }

    @Test("un día guardado más lejano que mañana es un reloj roto: se cuenta desde hoy")
    func aFarFutureDayIsIgnored() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        let farAway = try midnight(after: 30, from: now)
        _ = try #require(gameState.spinWheel(.video, now: farAway))
        #expect(gameState.wheelSpinsReadyAt(now: now) == nil)
    }

    @Test("un giro regalado no cuenta: no se perdió nada")
    func aBonusSpinIsNotAReason() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        gameState.debugAddWheelSpins(1)
        _ = try #require(gameState.spinWheel(.bonus, now: now))
        #expect(gameState.wheelSpinsReadyAt(now: now) == nil)
    }
}
