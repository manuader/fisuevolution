import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Activabas el Fernet, se cerraba el panel y no quedaba ni un rastro en
/// pantalla de que tenías un ×3 corriendo. El único lugar donde el efecto
/// existía era `player.run.activeModifiers`, que no leía ninguna vista.
///
/// La traducción de modificadores a chips vive en un tipo puro para poder fijar
/// acá las cuatro decisiones que tiene: a quién deja afuera, en qué orden, con
/// qué número y qué hace cuando no reconoce el origen.
@Suite("ActiveBonus")
@MainActor
struct ActiveBonusTests {
    private let now: TimeInterval = 1_000

    private func modifier(
        _ effect: ActiveModifier.Effect = .incomeMultiplier,
        magnitude: Double = 3,
        expiresIn: TimeInterval = 60,
        source: String = "boost.fernet"
    ) -> ActiveModifier {
        ActiveModifier(effect: effect, magnitude: magnitude, expiresAt: now + expiresIn, sourceKey: source)
    }

    private let catalog: [String: BonusSource] = [
        "boost.fernet": BonusSource(icon: .art("ui_boost_fernet"), duration: 90),
        "boost.mate": BonusSource(icon: .art("ui_boost_mate"), duration: 60),
        "rewarded.temp_multiplier": BonusSource(icon: .symbol("play.rectangle.fill"), duration: 60),
        "career.junior_lawyer": BonusSource(icon: .symbol("briefcase.fill"), duration: 600),
    ]

    private func build(_ modifiers: [ActiveModifier]) -> [ActiveBonus] {
        ActiveBonusBuilder.bonuses(from: modifiers, catalog: catalog, now: now)
    }

    // MARK: - Quién entra

    @Test("un boost corriendo da su chip, con su arte y su duración")
    func aRunningBoostBecomesAChip() throws {
        let bonus = try #require(build([modifier()]).first)

        #expect(bonus.icon == .art("ui_boost_fernet"))
        #expect(bonus.totalDuration == 90)
        #expect(bonus.expiresAt == now + 60)
    }

    @Test("los tres orígenes temporales entran: boost, video y carrera")
    func boostsVideosAndCareerRewardsAllShow() {
        let bonuses = build([
            modifier(source: "boost.mate"),
            modifier(source: "rewarded.temp_multiplier"),
            modifier(source: "career.junior_lawyer"),
        ])

        #expect(bonuses.count == 3)
    }

    @Test("el evento no entra: ya tiene su propio banner")
    func eventsStayOutBecauseTheyHaveTheirOwnBanner() {
        let bonuses = build([modifier(source: "event.plan_platita"), modifier(source: "boost.mate")])

        #expect(bonuses.count == 1)
        #expect(bonuses.first?.icon == .art("ui_boost_mate"))
    }

    @Test("un modificador vencido no entra")
    func expiredModifiersStayOut() {
        #expect(build([modifier(expiresIn: -1)]).isEmpty)
    }

    @Test("un modificador permanente no entra: no hay nada que contar")
    func permanentModifiersStayOut() {
        let forever = ActiveModifier(
            effect: .incomeMultiplier, magnitude: 2, expiresAt: .infinity, sourceKey: "boost.milanesa"
        )

        #expect(build([forever]).isEmpty)
    }

    // MARK: - En qué orden

    @Test("primero el que vence, que es el que urge")
    func theSoonestToExpireComesFirst() {
        let bonuses = build([
            modifier(expiresIn: 80, source: "career.junior_lawyer"),
            modifier(expiresIn: 10, source: "boost.mate"),
            modifier(expiresIn: 40, source: "rewarded.temp_multiplier"),
        ])

        #expect(bonuses.map(\.expiresAt) == [now + 10, now + 40, now + 80])
    }

    // MARK: - Con qué número

    @Test("el número es el mismo que muestra el menú de Bonus")
    func theNumberMatchesTheBonusMenu() throws {
        // El mate es el caso que delata una traducción hecha a mano: su magnitud
        // es 0,7 porque multiplica el COSTO, y se lee −30%, nunca ×0,7.
        let mate = try #require(build([
            modifier(.spawnCostMultiplier, magnitude: 0.7, source: "boost.mate")
        ]).first)
        #expect(mate.effectText == "−30%")

        let fernet = try #require(build([modifier(magnitude: 3)]).first)
        #expect(fernet.effectText == "×3")

        let cafe = try #require(build([
            modifier(.tapMultiplier, magnitude: 2, source: "rewarded.temp_multiplier")
        ]).first)
        #expect(cafe.effectText == "×2")
    }

    // MARK: - Cuando no reconoce el origen

    @Test("un origen desconocido igual muestra su chip")
    func anUnknownSourceStillGetsAChip() throws {
        // Un config editado o una fuente nueva no puede hacer desaparecer un
        // bonus que de verdad está corriendo: se muestra con el aro lleno.
        let bonus = try #require(build([modifier(source: "boost.inventado")]).first)

        #expect(bonus.totalDuration == nil)
        #expect(bonus.effectText == "×3")
        if case .art = bonus.icon { Issue.record("sin catálogo no hay arte que valga") }
    }

    // MARK: - Lo que dibuja el chip

    @Test("el aro va lleno cuando no se sabe cuánto duraba")
    func theRingIsFullWithoutAKnownDuration() {
        #expect(ActiveBonusBar.progress(remaining: 12, total: nil) == 1)
        #expect(ActiveBonusBar.progress(remaining: 45, total: 90) == 0.5)
        #expect(ActiveBonusBar.progress(remaining: 0, total: 90) == 0)
    }

    @Test("el tiempo se lee en segundos abajo del minuto y en mm:ss arriba")
    func theCountdownReadsWell() {
        #expect(ActiveBonusBar.timeText(42) == "42s")
        // Redondea hacia ARRIBA: con truncado, un boost de 60 s recién activado
        // aparecería marcando 59 s apenas lo activás.
        #expect(ActiveBonusBar.timeText(41.2) == "42s")
        #expect(ActiveBonusBar.timeText(59.4) == "1:00")
        #expect(ActiveBonusBar.timeText(102) == "1:42")
        #expect(ActiveBonusBar.timeText(600) == "10:00")
        #expect(ActiveBonusBar.timeText(0) == "0s")
    }
}
