import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El calendario de la pantalla de Regalos (spec §9) y el "qué te da" de cada
/// video.
///
/// ## La decisión de semántica que estos tests pinean
///
/// `meta.daily.cycleDay` **apunta al día que el ciclo va a pagar**, no al que ya
/// pagó: `DailyRewardManager.claimIfAvailable` cobra el día `cycleDay` y recién
/// entonces lo avanza (`ContentSystems.swift:396-397`). Así que el calendario se
/// lee siempre igual —los días **menores** a `cycleDay` están cobrados, el
/// `cycleDay` es el que está en juego— y NO se intenta deducir "el día que
/// cobraste hoy" mirando `lastClaimDay`.
///
/// ⚠️ Y no se intenta por una razón medida, no por comodidad: en una instalación
/// nueva el bootstrap escribe `lastClaimDay = hoy` **sin cobrar nada y sin tocar
/// `cycleDay`** (`GameState.swift:436-440`, para que el popup del daily no
/// compita con el tutorial). Con la regla "si `lastClaimDay` es hoy, el día
/// cobrado es `cycleDay − 1`", esa partida nueva mostraría los siete días con
/// tilde y el cofre del día 7 resaltado — el estado más falso posible. El test
/// `freshInstallShowsAnEmptyWeek` es ese caso.
@Suite("Calendario diario y premios por video")
@MainActor
struct DailyCalendarTests {
    // MARK: El calendario

    @Test("con cycleDay 3, los dos primeros están cobrados y el tercero es el que está en juego")
    func calendarSplitsAroundCycleDay() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.daily.cycleDay = 3

        let days = gameState.dailyCalendar

        #expect(days.map(\.id) == [1, 2, 3, 4, 5, 6, 7], "el ciclo son siete días, en orden")
        for day in days {
            #expect(day.isClaimed == (day.id < 3), "día \(day.id): cobrado tendría que ser \(day.id < 3)")
            #expect(day.isToday == (day.id == 3), "día \(day.id): en juego tendría que ser \(day.id == 3)")
        }
    }

    @Test("el séptimo día es el cofre y ningún otro lo es")
    func onlyTheSeventhDayIsTheChest() async throws {
        let gameState = await makeGameState()

        let days = gameState.dailyCalendar

        #expect(days.filter(\.isChest).map(\.id) == [7], "el cofre es el premio del día 7 (special_roll)")
        // Los títulos salen del config, no de una lista escrita en la vista.
        let last = try #require(days.last)
        let first = try #require(days.first)
        #expect(last.titleKey == "daily.day7.title")
        #expect(first.titleKey == "daily.day1.title")
    }

    @Test("una instalación nueva muestra la semana entera por delante")
    func freshInstallShowsAnEmptyWeek() async throws {
        // El bootstrap de una partida nueva marca `lastClaimDay = hoy` sin cobrar
        // (FTUE): si el calendario dedujera el día cobrado de esa marca, esta
        // partida arrancaría con los siete días tildados.
        let gameState = await makeGameState()

        let days = gameState.dailyCalendar

        #expect(gameState.player?.meta.daily.cycleDay == 1)
        #expect(days.allSatisfy { !$0.isClaimed }, "nadie cobró nada todavía")
        #expect(days.filter(\.isToday).map(\.id) == [1], "el día 1 es el que está en juego")
    }

    @Test("después del claim automático, el resaltado se corre al día siguiente")
    func claimingAdvancesTheHighlight() async throws {
        let gameState = await makeGameState()
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        gameState.player?.meta.daily.cycleDay = 3
        gameState.player?.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: yesterday)

        // El mismo camino que corre el bootstrap: el calendario es informativo y
        // no cobra nada por su cuenta.
        gameState.claimDailyIfAvailable()

        let days = gameState.dailyCalendar
        #expect(gameState.dailyClaim?.day.day == 3, "el que se cobró es el día 3")
        #expect(days.filter(\.isClaimed).map(\.id) == [1, 2, 3], "el día cobrado queda con tilde")
        #expect(days.filter(\.isToday).map(\.id) == [4], "y el resaltado pasa a ser el próximo del ciclo")
    }

    // MARK: El premio de cada video

    @Test("cada video dice qué da, sin dejar una clave cruda en pantalla")
    func rewardTextIsResolvedCopy() async throws {
        let gameState = await makeGameState()

        let rows = gameState.rewardRows

        #expect(rows.count == 4)
        for row in rows {
            #expect(!row.rewardText.isEmpty, "\(row.id) no dice qué da")
            #expect(!row.rewardText.contains("ads."), "\(row.id) dejó una clave cruda: '\(row.rewardText)'")
            #expect(!row.rewardText.contains("gifts."), "\(row.id) dejó una clave cruda: '\(row.rewardText)'")
        }
    }

    @Test("el multiplicador sale del dato: factor y duración, no un número escrito a mano")
    func rewardTextReadsTheConfig() async throws {
        let gameState = await makeGameState()

        let double = try #require(gameState.rewardRows.first { $0.id == "double_earnings" })
        #expect(double.rewardText.contains("×2"), "magnitud 2,0 se lee ×2, dijo '\(double.rewardText)'")
        #expect(double.rewardText.contains("2"), "y dura 2 minutos, dijo '\(double.rewardText)'")
        #expect(!double.rewardText.contains("120"), "120 segundos se cuentan en minutos: '\(double.rewardText)'")

        let turbo = try #require(gameState.rewardRows.first { $0.id == "temp_multiplier" })
        #expect(turbo.rewardText.contains("×3"), "magnitud 3,0 se lee ×3, dijo '\(turbo.rewardText)'")

        // Los dos que no son multiplicadores tienen su propia frase y no la del
        // multiplicador vacía.
        let merge = try #require(gameState.rewardRows.first { $0.id == "accelerate_evolution" })
        let rare = try #require(gameState.rewardRows.first { $0.id == "spawn_rare" })
        #expect(!merge.rewardText.contains("×"))
        #expect(merge.rewardText != rare.rewardText)
    }
}
