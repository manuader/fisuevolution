import Foundation
import Testing
@testable import EconomyKit

/// La config de los momentos y sus topes (2.1 E15 F3 T3, contrato C3): lo remoto puede ser más prudente,
/// nunca más insistente ni más generoso; el control es obligatorio y `base` no ve ofertas.
@Suite("La config de los momentos y sus topes")
struct MomentsConfigTests {
    /// El ejemplo del contrato C3.
    static let example = """
    {
      "version": "seed-2026-10-16",
      "thresholds": { "priceWallMinutes": 8, "backOfflineMinutes": 120 },
      "caps": { "maxPerHour": 3, "minSecondsBetween": 600, "cooldownAfterDeclineSeconds": 1200, "maxPerSession": 6 },
      "arms": [
        { "id": "pw_small", "moment": "price_wall", "reward": {"kind": "coinsSeconds", "seconds": 300}, "alpha": 1, "beta": 1, "segments": ["low","mid","high"] },
        { "id": "pw_big",   "moment": "price_wall", "reward": {"kind": "coinsSeconds", "seconds": 600}, "alpha": 1, "beta": 1, "segments": ["mid","high"] },
        { "id": "ff_merge", "moment": "floor_full", "reward": {"kind": "mergeAll"},                     "alpha": 1, "beta": 1, "segments": ["low","mid","high"] },
        { "id": "control",  "moment": "*", "control": true, "alpha": 1, "beta": 1 }
      ]
    }
    """

    static func decode(_ json: String = example) throws -> MomentsConfig {
        try JSONDecoder().decode(MomentsConfig.self, from: Data(json.utf8))
    }

    private func rejects(_ config: MomentsConfig, _ expected: MomentsConfig.ValidationError) {
        #expect(throws: expected) { try config.validate() }
    }

    /// El ejemplo con el brazo `id` cambiado por `change`.
    private func withArm(_ id: String, _ change: (inout MomentsConfig.Arm) -> Void) throws -> MomentsConfig {
        var config = try Self.decode()
        let index = try #require(config.arms.firstIndex { $0.id == id })
        change(&config.arms[index])
        return config
    }

    private func withCaps(_ change: (inout MomentsConfig.Caps) -> Void) throws -> MomentsConfig {
        var config = try Self.decode()
        change(&config.caps)
        return config
    }

    // MARK: - El ejemplo y la semilla

    @Test("el ejemplo del contrato decodifica y valida")
    func theExampleDecodes() throws {
        let config = try Self.decode()
        try config.validate()
        #expect(config.version == "seed-2026-10-16")
        #expect(config.thresholds == .seed)
        #expect(config.caps == .seed)
        #expect(config.arms.map(\.id) == ["pw_small", "pw_big", "ff_merge", "control"])
        #expect(config.arm("pw_small")?.reward == .grant(.coinsSeconds(300)))
        #expect(config.arm("ff_merge")?.reward == .mergeAll)
        #expect(config.arm("control")?.control == true)
        #expect(config.arm("control")?.reward == nil)
        #expect(config.arm("pw_big")?.segments == ["mid", "high"])
    }

    @Test("el moments.json del bundle es la semilla del contrato y valida")
    func theBundledFileIsTheSeed() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // EconomyKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // EconomyKit
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // raíz del repo
            .appending(path: "FisuEvolution/Resources/Config/moments.json")
        let bundled = try JSONDecoder().decode(MomentsConfig.self, from: Data(contentsOf: url))
        try bundled.validate()
        let contract = try Self.decode()
        #expect(bundled == contract)
    }

    @Test("«Fusionar todo» y la plata van y vuelven por JSON con el mismo kind")
    func rewardsRoundTrip() throws {
        let config = try Self.decode()
        let again = try JSONDecoder().decode(MomentsConfig.self, from: JSONEncoder().encode(config))
        #expect(again == config)
        let mergeAll = try JSONEncoder().encode(MomentReward.mergeAll)
        let object = try #require(try JSONSerialization.jsonObject(with: mergeAll) as? [String: String])
        #expect(object == ["kind": "mergeAll"])
    }

    @Test("el bandido sale con los brazos y priors del archivo, el control marcado")
    func theBanditTakesThePriors() throws {
        let config = try withArm("pw_big") { $0.alpha = 3; $0.beta = 7 }
        let bandit = config.bandit()
        #expect(bandit.arms.map(\.id) == ["pw_small", "pw_big", "ff_merge", "control"])
        #expect(bandit.arm("pw_big")?.alpha == 3)
        #expect(bandit.arm("pw_big")?.beta == 7)
        #expect(bandit.arm("control")?.isControl == true)
        #expect(bandit.arm("pw_small")?.isControl == false)
    }

    // MARK: - Cada tope rechaza

    @Test("en el tope del código valida; un paso más allá, cada tope invalida el archivo")
    func everyCapRejects() throws {
        try withCaps { $0 = .hard }.validate()
        rejects(try withCaps { $0.maxPerHour = MomentsConfig.Caps.hard.maxPerHour + 1 }, .capOutOfRange("maxPerHour"))
        rejects(try withCaps { $0.maxPerSession = MomentsConfig.Caps.hard.maxPerSession + 1 }, .capOutOfRange("maxPerSession"))
        rejects(try withCaps { $0.minSecondsBetween = MomentsConfig.Caps.hard.minSecondsBetween - 1 },
                .capOutOfRange("minSecondsBetween"))
        rejects(try withCaps { $0.cooldownAfterDeclineSeconds = MomentsConfig.Caps.hard.cooldownAfterDeclineSeconds - 1 },
                .capOutOfRange("cooldownAfterDeclineSeconds"))
    }

    @Test("los topes del código son los del contrato C3")
    func theHardCapsAreTheContract() {
        let hard = MomentsConfig.Caps.hard
        #expect(hard.maxPerHour == 4)
        #expect(hard.minSecondsBetween == 300)
        #expect(hard.cooldownAfterDeclineSeconds == 600)
        #expect(hard.maxPerSession == 8)
        #expect(MomentsConfig.maxRewardSeconds == 600)
    }

    @Test("topes negativos, infinitos o NaN invalidan")
    func nonsenseCapsReject() throws {
        rejects(try withCaps { $0.maxPerHour = -1 }, .capOutOfRange("maxPerHour"))
        rejects(try withCaps { $0.maxPerSession = -1 }, .capOutOfRange("maxPerSession"))
        rejects(try withCaps { $0.minSecondsBetween = .infinity }, .capOutOfRange("minSecondsBetween"))
        rejects(try withCaps { $0.cooldownAfterDeclineSeconds = .nan }, .capOutOfRange("cooldownAfterDeclineSeconds"))
    }

    @Test("más prudente que la semilla vale: cero ofertas por hora apaga los momentos sin invalidar")
    func stricterIsFine() throws {
        try withCaps { $0.maxPerHour = 0; $0.maxPerSession = 0; $0.minSecondsBetween = 7200 }.validate()
    }

    @Test("plata por encima de maxRewardSeconds invalida; justo en el tope, no")
    func rewardAboveTheCapRejects() throws {
        try withArm("pw_big") { $0.reward = .grant(.coinsSeconds(MomentsConfig.maxRewardSeconds)) }.validate()
        rejects(try withArm("pw_big") { $0.reward = .grant(.coinsSeconds(MomentsConfig.maxRewardSeconds + 1)) },
                .rewardOutOfRange(arm: "pw_big"))
    }

    @Test("plata en cero o negativa es un premio inválido")
    func nonPositiveRewardRejects() throws {
        rejects(try withArm("pw_small") { $0.reward = .grant(.coinsSeconds(0)) }, .invalidReward(arm: "pw_small"))
        rejects(try withArm("pw_small") { $0.reward = .grant(.coinsSeconds(-60)) }, .invalidReward(arm: "pw_small"))
    }

    @Test("sólo plata y «Fusionar todo»: otro premio existente invalida")
    func otherRewardsReject() throws {
        rejects(try withArm("pw_small") { $0.reward = .grant(.blue(5)) }, .unsupportedReward(arm: "pw_small"))
        rejects(try withArm("pw_small") { $0.reward = .grant(.nextOfflineMultiplier(3)) }, .unsupportedReward(arm: "pw_small"))
    }

    @Test("un kind de premio que nadie conoce no decodifica")
    func unknownRewardKindFails() {
        let json = Self.example.replacingOccurrences(of: "\"mergeAll\"", with: "\"freeGod\"")
        #expect(throws: (any Error).self) { try Self.decode(json) }
    }

    // MARK: - El control

    @Test("sin brazo de control el archivo es inválido: el control es obligatorio")
    func missingControlRejects() throws {
        var config = try Self.decode()
        config.arms.removeAll(where: \.control)
        rejects(config, .missingControl)
    }

    @Test("dos controles invalidan")
    func twoControlsReject() throws {
        var config = try Self.decode()
        config.arms.append(.init(id: "control_2", moment: "*", control: true))
        rejects(config, .multipleControls)
    }

    @Test("el control no paga nada y vale para cualquier momento")
    func theControlIsEmpty() throws {
        rejects(try withArm("control") { $0.reward = .grant(.coinsSeconds(60)) }, .controlWithReward(arm: "control"))
        rejects(try withArm("control") { $0.moment = "price_wall" }, .unknownMoment(arm: "control", moment: "price_wall"))
    }

    // MARK: - Brazos y segmentos

    @Test("un segmento desconocido invalida (no se lee como base)")
    func unknownSegmentRejects() throws {
        let json = Self.example.replacingOccurrences(of: "[\"mid\",\"high\"]", with: "[\"mid\",\"whale\"]")
        rejects(try Self.decode(json), .unknownSegment(arm: "pw_big", segment: "whale"))
    }

    @Test("base no puede figurar en un brazo")
    func baseInAnArmRejects() throws {
        rejects(try withArm("pw_small") { $0.segments = ["base", "low"] }, .baseSegment(arm: "pw_small"))
    }

    @Test("un brazo de oferta sin segmentos ni premio invalida")
    func armsNeedSegmentsAndReward() throws {
        rejects(try withArm("pw_small") { $0.segments = [] }, .noSegments(arm: "pw_small"))
        rejects(try withArm("pw_small") { $0.reward = nil }, .missingReward(arm: "pw_small"))
    }

    @Test("un momento desconocido o el comodín en un brazo de oferta invalida")
    func unknownMomentRejects() throws {
        rejects(try withArm("pw_small") { $0.moment = "sad_face" }, .unknownMoment(arm: "pw_small", moment: "sad_face"))
        rejects(try withArm("pw_small") { $0.moment = "*" }, .unknownMoment(arm: "pw_small", moment: "*"))
    }

    @Test("ids repetidos o vacíos invalidan")
    func armIdsMustBeUnique() throws {
        rejects(try withArm("pw_big") { $0.id = "pw_small" }, .duplicateArm("pw_small"))
        rejects(try withArm("pw_big") { $0.id = " " }, .emptyArmId)
    }

    @Test("priors en cero, negativos o infinitos invalidan")
    func badPriorsReject() throws {
        rejects(try withArm("pw_small") { $0.alpha = 0 }, .badPrior(arm: "pw_small"))
        rejects(try withArm("pw_small") { $0.beta = -1 }, .badPrior(arm: "pw_small"))
        rejects(try withArm("control") { $0.alpha = .infinity }, .badPrior(arm: "control"))
    }

    @Test("un brazo nuevo para el colchón o la vuelta entra por config")
    func newMomentsCanGetArms() throws {
        var config = try Self.decode()
        config.arms.insert(.init(id: "mr_coins", moment: "mattress_ready", reward: .grant(.coinsSeconds(120)),
                                 segments: ["high"]), at: 0)
        try config.validate()
    }

    // MARK: - Versión y umbrales

    @Test("versión vacía o umbrales que no sirven invalidan")
    func versionAndThresholds() throws {
        var config = try Self.decode()
        config.version = "  "
        rejects(config, .emptyVersion)
        config = try Self.decode()
        config.thresholds.priceWallMinutes = 0
        rejects(config, .badThreshold("priceWallMinutes"))
        config = try Self.decode()
        config.thresholds.backOfflineMinutes = .nan
        rejects(config, .badThreshold("backOfflineMinutes"))
    }

    @Test("withinHard lleva una config sin validar adentro de los topes del código")
    func withinHardClamps() {
        let wild = MomentsConfig.Caps(maxPerHour: 99, minSecondsBetween: 1, cooldownAfterDeclineSeconds: .nan, maxPerSession: -3)
        #expect(wild.withinHard == MomentsConfig.Caps(maxPerHour: 4, minSecondsBetween: 300,
                                                       cooldownAfterDeclineSeconds: 600, maxPerSession: 0))
        #expect(MomentsConfig.Caps.seed.withinHard == .seed)
    }
}
