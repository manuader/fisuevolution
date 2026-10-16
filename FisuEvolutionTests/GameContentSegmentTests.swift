import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los relojes de las ayudas según el segmento (2.1 E15 F2 T7): el colchón gratis, los visitantes y
/// las pausas del costado se aplican transformando el contenido, con la misma función que usa el
/// `PacingFixture`. Con la base, el contenido es el de la 2.0 sin un bit de diferencia.
@Suite("Los relojes de las ayudas según el segmento")
@MainActor
struct GameContentSegmentTests {
    private let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private static let high = SegmentLevers.Levers(
        videoRewardMultiplier: ["offline": 2.5],
        freeMattressIntervalScale: 0.85,
        visitorIntervalScale: 0.9,
        sideRailCooldownScale: 0.8,
        forcedSpacingScale: 1.25
    )

    // MARK: - La transformación pura

    @Test("la identidad devuelve el mismo contenido")
    func identityIsTheSameContent() {
        let applied = content.applying(.identity)
        #expect(applied.segmentClocks == content.segmentClocks)
        #expect(applied.rewardedAds == content.rewardedAds)
        #expect(applied.rewardedAds.sideRail == content.rewardedAds.sideRail)
        #expect(applied.economy == content.economy)
    }

    @Test("las palancas que no son de reloj no tocan el contenido")
    func nonClockLeversLeaveContentAlone() {
        let levers = SegmentLevers.Levers(videoRewardMultiplier: ["offline": 2.5, "visit": 2.25], forcedSpacingScale: 3)
        #expect(content.applying(levers).segmentClocks == content.segmentClocks)
    }

    @Test("el colchón: sólo su intervalo, y nada más")
    func freeMattressScalesOnlyItsInterval() {
        let applied = content.applying(SegmentLevers.Levers(freeMattressIntervalScale: 0.75))
        let base = content.treasures
        let treasures = applied.treasures
        #expect(treasures.freeBoardIntervalSeconds == base.freeBoardIntervalSeconds * 0.75)
        #expect(treasures.spawnIntervalSeconds == base.spawnIntervalSeconds)
        #expect(treasures.firstTreasureAfterSeconds == base.firstTreasureAfterSeconds)
        #expect(treasures.extraOpensPerTreasure == base.extraOpensPerTreasure)
        #expect(treasures.prizes == base.prizes)
        #expect(treasures.freeBoardPrizes == base.freeBoardPrizes)
        #expect(applied.visitors == content.visitors)
        #expect(applied.rewardedAds == content.rewardedAds)
    }

    @Test("los visitantes: el mínimo y el máximo entre dos, y nada más")
    func visitorsScaleOnlyTheirInterval() {
        let applied = content.applying(SegmentLevers.Levers(visitorIntervalScale: 0.9))
        let base = content.visitors
        let visitors = applied.visitors
        #expect(visitors.intervalMinSeconds == base.intervalMinSeconds * 0.9)
        #expect(visitors.intervalMaxSeconds == base.intervalMaxSeconds * 0.9)
        #expect(visitors.firstVisitAfterSeconds == base.firstVisitAfterSeconds)
        #expect(visitors.retryWhenNoneSeconds == base.retryWhenNoneSeconds)
        #expect(visitors.patienceSeconds == base.patienceSeconds)
        #expect(visitors.presenterTalkSeconds == base.presenterTalkSeconds)
        #expect(visitors.coinsSecondsScale == base.coinsSecondsScale)
        #expect(visitors.visitors == base.visitors)
        #expect(visitors.scripts == base.scripts)
        #expect(applied.treasures == content.treasures)
        #expect(applied.rewardedAds == content.rewardedAds)
    }

    @Test("el costado: las dos pausas, y ni el premio de la lluvia ni los videos de Regalos")
    func sideRailScalesOnlyItsCooldowns() {
        let applied = content.applying(SegmentLevers.Levers(sideRailCooldownScale: 0.8))
        let base = content.rewardedAds
        let rail = applied.rewardedAds.effectiveSideRail
        #expect(rail.mergeAllCooldownSeconds == base.effectiveSideRail.mergeAllCooldownSeconds * 0.8)
        #expect(rail.packageRainCooldownSeconds == base.effectiveSideRail.packageRainCooldownSeconds * 0.8)
        #expect(rail.packageRain == base.effectiveSideRail.packageRain)
        #expect(applied.rewardedAds.rewards == base.rewards)
        #expect(applied.rewardedAds.compensationSeconds == base.compensationSeconds)
        #expect(applied.rewardedAds.adBreak == base.adBreak)
        #expect(applied.treasures == content.treasures)
        #expect(applied.visitors == content.visitors)
    }

    @Test("un costado sin sección en el JSON escala el default")
    func sideRailWithoutSectionScalesTheDefault() {
        let clocks = GameContent.SegmentClocks(
            treasures: content.treasures, visitors: content.visitors,
            rewardedAds: { var ads = content.rewardedAds; ads.sideRail = nil; return ads }()
        )
        let rail = clocks.applying(SegmentLevers.Levers(sideRailCooldownScale: 0.75)).rewardedAds.effectiveSideRail
        #expect(rail.mergeAllCooldownSeconds == RewardedAdsConfig.SideRail.default.mergeAllCooldownSeconds * 0.75)
        #expect(rail.packageRainCooldownSeconds == RewardedAdsConfig.SideRail.default.packageRainCooldownSeconds * 0.75)
        #expect(clocks.applying(.identity).rewardedAds.sideRail == nil)
    }

    @Test("las tres escalas juntas no se pisan entre sí ni tocan el resto")
    func allClocksTogether() {
        let applied = content.applying(Self.high)
        #expect(applied.treasures.freeBoardIntervalSeconds == content.treasures.freeBoardIntervalSeconds * 0.85)
        #expect(applied.visitors.intervalMinSeconds == content.visitors.intervalMinSeconds * 0.9)
        #expect(applied.rewardedAds.effectiveSideRail.mergeAllCooldownSeconds
                == content.rewardedAds.effectiveSideRail.mergeAllCooldownSeconds * 0.8)
        #expect(applied.economy == content.economy)
        #expect(applied.floorTable == content.floorTable)
        #expect(applied.baseFloorTable == content.baseFloorTable)
        #expect(applied.packages == content.packages)
        #expect(applied.wheel == content.wheel)
        #expect(applied.tabs == content.tabs)
    }

    @Test("volver a la base desde los relojes base restaura el original exacto")
    func backToBaseRestoresTheOriginal() {
        let base = content.segmentClocks
        let high = content.applying(Self.high)
        let restored = high.replacing(base.applying(.identity))
        #expect(restored.segmentClocks == content.segmentClocks)
    }

    // MARK: - En la partida

    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "segclocks-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    @Test("sin servicio de personalización, las palancas son la base")
    func noServiceIsBase() async {
        let gameState = await makeGameState()
        #expect(gameState.segmentLevers == .identity)
        gameState.applySegmentClocks(gameState.segmentLevers)
        #expect(gameState.content?.segmentClocks == content.segmentClocks)
    }

    @Test("aplicar un segmento y volver a la base deja la partida como la 2.0")
    func gameStateAppliesAndRestores() async throws {
        let gameState = await makeGameState()
        gameState.applySegmentClocks(Self.high)
        let applied = try #require(gameState.content)
        #expect(applied.treasures.freeBoardIntervalSeconds == content.treasures.freeBoardIntervalSeconds * 0.85)
        gameState.applySegmentClocks(Self.high)
        #expect(gameState.content?.treasures.freeBoardIntervalSeconds == content.treasures.freeBoardIntervalSeconds * 0.85)
        gameState.applySegmentClocks(.identity)
        #expect(gameState.content?.segmentClocks == content.segmentClocks)
    }

    @Test("el fixture del colchón gratis manda sobre el segmento")
    func freeMattressFixtureWins() async {
        let gameState = await makeGameState()
        gameState.debugFreeMattressEvery(5)
        gameState.applySegmentClocks(Self.high)
        #expect(gameState.content?.treasures.freeBoardIntervalSeconds == 5)
        #expect(gameState.content?.visitors.intervalMinSeconds == content.visitors.intervalMinSeconds * 0.9)
    }

    @Test("con el servicio y un segmento forzado, la partida lee las palancas de la config")
    func serviceLeversAreRead() async throws {
        let gameState = await makeGameState()
        let json = PersonalizationFixtures.envelope(sections: [
            "player_value": PersonalizationFixtures.playerValue,
            "segments": #"{"version":"t7","segments":{"high":{"visitorIntervalScale":0.9}}}"#,
        ])
        let service = PersonalizationService(
            source: FakePersonalizationSource(enabled: true, json: json),
            store: PersonalizationStore(url: FileManager.default.temporaryDirectory
                .appending(path: "segclocks-\(UUID().uuidString)").appending(path: "personalization.json")),
            device: { ("USA", "iPhone16,2") },
            installId: { "8c1f0c6e-0000-4000-8000-000000000001" },
            consentAllows: { true },
            underAgeSignal: { false },
            arguments: [],
            isDebug: false
        )
        gameState.attachPersonalization(service)
        await service.settle()
        service.debugForce(.high)
        #expect(gameState.segmentLevers.visitorIntervalScale == 0.9)
        gameState.applySegmentClocks(gameState.segmentLevers)
        #expect(gameState.content?.visitors.intervalMinSeconds == content.visitors.intervalMinSeconds * 0.9)
        service.debugForce(.base)
        #expect(gameState.segmentLevers == .identity)
    }
}
