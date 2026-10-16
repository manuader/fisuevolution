import Foundation
import Testing
@testable import EconomyKit

/// Las palancas por segmento y sus topes (2.1 E15 F2 T1, contrato C1): cada segmento ve más ayuda
/// opcional que la base, nunca más que los topes del código, y `base` es la identidad siempre.
@Suite("Las palancas por segmento y sus topes")
struct SegmentLeversTests {
    /// El ejemplo del contrato C1.
    static let example = """
    {
      "version": "seed-2026-10-16",
      "segments": {
        "low":  { "videoRewardMultiplier": {}, "freeMattressIntervalScale": 1.0, "visitorIntervalScale": 1.0,
                  "sideRailCooldownScale": 1.0, "forcedSpacingScale": 1.0 },
        "mid":  { "videoRewardMultiplier": {"offline": 2.25}, "freeMattressIntervalScale": 0.9,
                  "visitorIntervalScale": 0.95, "sideRailCooldownScale": 0.95, "forcedSpacingScale": 1.0 },
        "high": { "videoRewardMultiplier": {"offline": 2.5, "mattress": 2.25}, "freeMattressIntervalScale": 0.85,
                  "visitorIntervalScale": 0.9, "sideRailCooldownScale": 0.9, "forcedSpacingScale": 1.25 }
      }
    }
    """

    private func decode(_ json: String) throws -> SegmentLevers {
        try JSONDecoder().decode(SegmentLevers.self, from: Data(json.utf8))
    }

    /// El ejemplo con `high` cambiado por `levers`.
    private func withHigh(_ levers: SegmentLevers.Levers) throws -> SegmentLevers {
        var file = try decode(Self.example)
        file.segments["high"] = levers
        return file
    }

    private func rejects(_ file: SegmentLevers, _ expected: SegmentLevers.ValidationError) {
        #expect(throws: expected) { try file.validate() }
    }

    @Test("el ejemplo del contrato decodifica y valida")
    func theExampleDecodes() throws {
        let file = try decode(Self.example)
        try file.validate()
        #expect(file.version == "seed-2026-10-16")
        let high = file.levers(for: .high)
        #expect(high.rewardMultiplier(for: .offline) == 2.5)
        #expect(high.rewardMultiplier(for: .mattress) == 2.25)
        #expect(high.freeMattressIntervalScale == 0.85)
        #expect(high.visitorIntervalScale == 0.9)
        #expect(high.sideRailCooldownScale == 0.9)
        #expect(high.forcedSpacingScale == 1.25)
        #expect(file.levers(for: .low) == .identity)
    }

    @Test("base es la identidad aunque el archivo diga otra cosa")
    func baseIsAlwaysTheIdentity() throws {
        var file = try decode(Self.example)
        file.segments["base"] = SegmentLevers.Levers(
            videoRewardMultiplier: ["offline": 2.5], freeMattressIntervalScale: 0.75, forcedSpacingScale: 3
        )
        #expect(file.levers(for: .base) == .identity)
        let empty = SegmentLevers(version: "v", segments: [:])
        #expect(empty.levers(for: .base) == .identity)
    }

    @Test("un segmento que falta queda en la base")
    func aMissingSegmentIsTheIdentity() throws {
        let file = try decode(#"{"version": "v", "segments": {"high": {"forcedSpacingScale": 1.5}}}"#)
        try file.validate()
        #expect(file.levers(for: .low) == .identity)
        #expect(file.levers(for: .mid) == .identity)
        #expect(file.levers(for: .high).forcedSpacingScale == 1.5)
        #expect(file.levers(for: .high).freeMattressIntervalScale == 1, "una palanca que falta queda como en la base")
    }

    @Test("una fuente que falta paga el ×2 de la 2.0")
    func aMissingSourceIsTimesTwo() throws {
        let high = try decode(Self.example).levers(for: .high)
        for source in SegmentLevers.Source.allCases where ![.offline, .mattress].contains(source) {
            #expect(high.rewardMultiplier(for: source) == 2)
        }
        for source in SegmentLevers.Source.allCases {
            #expect(SegmentLevers.Levers.identity.rewardMultiplier(for: source) == 2)
        }
    }

    @Test("un ×2,6 pasa el tope del ×2,5 e invalida el archivo")
    func aboveTheRewardCapRejects() throws {
        let file = try withHigh(SegmentLevers.Levers(videoRewardMultiplier: ["offline": 2.6]))
        rejects(file, .outOfRange(segment: "high", lever: "videoRewardMultiplier.offline"))
    }

    @Test("un ×1,9 es menos que la base e invalida el archivo")
    func belowTheBaseRewardRejects() throws {
        var file = try decode(Self.example)
        file.segments["low"] = SegmentLevers.Levers(videoRewardMultiplier: ["daily": 1.9])
        rejects(file, .outOfRange(segment: "low", lever: "videoRewardMultiplier.daily"))
    }

    @Test("visitantes con escala 0,5 pasan el tope")
    func visitorScaleBelowTheCapRejects() throws {
        let file = try withHigh(SegmentLevers.Levers(visitorIntervalScale: 0.5))
        rejects(file, .outOfRange(segment: "high", lever: "visitorIntervalScale"))
    }

    @Test("forzados con escala 0,9 serían más forzados que la base")
    func forcedSpacingBelowOneRejects() throws {
        let file = try withHigh(SegmentLevers.Levers(forcedSpacingScale: 0.9))
        rejects(file, .outOfRange(segment: "high", lever: "forcedSpacingScale"))
    }

    @Test("cada escala fuera de tope invalida el archivo, también las que alargan")
    func everyScaleHasItsCap() throws {
        let cases: [(SegmentLevers.Levers, String)] = [
            (SegmentLevers.Levers(freeMattressIntervalScale: SegmentLevers.Caps.minScale - 0.01), "freeMattressIntervalScale"),
            (SegmentLevers.Levers(freeMattressIntervalScale: 1.1), "freeMattressIntervalScale"),
            (SegmentLevers.Levers(visitorIntervalScale: 1.1), "visitorIntervalScale"),
            (SegmentLevers.Levers(sideRailCooldownScale: 0.7), "sideRailCooldownScale"),
            (SegmentLevers.Levers(sideRailCooldownScale: 1.1), "sideRailCooldownScale"),
            (SegmentLevers.Levers(forcedSpacingScale: 3.1), "forcedSpacingScale"),
            (SegmentLevers.Levers(forcedSpacingScale: .nan), "forcedSpacingScale"),
        ]
        for (levers, lever) in cases {
            rejects(try withHigh(levers), .outOfRange(segment: "high", lever: lever))
        }
    }

    @Test("mid más generoso que high rompe la monotonía")
    func brokenMonotonyRejects() throws {
        var file = try decode(Self.example)
        file.segments["mid"] = SegmentLevers.Levers(videoRewardMultiplier: ["offline": 2.5, "career": 2.25])
        rejects(file, .notMonotonic(lever: "videoRewardMultiplier.career"))

        var scales = try decode(Self.example)
        scales.segments["mid"]?.freeMattressIntervalScale = 0.8
        rejects(scales, .notMonotonic(lever: "freeMattressIntervalScale"))
    }

    @Test("una fuente desconocida invalida el archivo")
    func unknownSourceRejects() throws {
        let file = try withHigh(SegmentLevers.Levers(videoRewardMultiplier: ["lottery": 2.25]))
        rejects(file, .unknownSource(segment: "high", source: "lottery"))
    }

    @Test("un segmento desconocido invalida el archivo")
    func unknownSegmentRejects() throws {
        var file = try decode(Self.example)
        file.segments["ultra"] = .identity
        rejects(file, .unknownSegment("ultra"))
    }

    @Test("ida y vuelta por JSON")
    func roundTrips() throws {
        let file = try decode(Self.example)
        let again = try JSONDecoder().decode(SegmentLevers.self, from: try JSONEncoder().encode(file))
        #expect(again == file)
    }

    @Test("el peor caso de los topes valida y no pasa del ×2,5")
    func theWorstCaseIsWithinTheCaps() throws {
        let worst = SegmentLevers.Caps.worstCase
        try SegmentLevers(version: "caps", segments: [.high: worst]).validate()
        for source in SegmentLevers.Source.allCases {
            #expect(worst.rewardMultiplier(for: source) <= 2.5, "V3")
            #expect(worst.rewardMultiplier(for: source) >= 2)
        }
        #expect(worst.forcedSpacingScale >= 1)
    }

    @Test("la fuente sale del site de RewardDouble, sin prefijo ni sufijo")
    func theSourceComesFromTheSite() {
        #expect(SegmentLevers.Source(site: "double.offline") == .offline)
        #expect(SegmentLevers.Source(site: "double.visit.ministro_subsidio") == .visit)
        #expect(SegmentLevers.Source(site: "double.event.aguinaldo") == .event)
        #expect(SegmentLevers.Source(site: "double.lottery") == nil)
        #expect(SegmentLevers.Source(site: "offline") == nil)
    }

    @Test("el segments.json del bundle valida y da la identidad en los tres segmentos")
    func theBundledFileIsTheIdentity() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // EconomyKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // EconomyKit
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // raíz del repo
            .appending(path: "FisuEvolution/Resources/Config/segments.json")
        let file = try JSONDecoder().decode(SegmentLevers.self, from: Data(contentsOf: url))
        try file.validate()
        for segment in PlayerSegment.allCases {
            #expect(file.levers(for: segment) == .identity, "\(segment): el juego no cambia hasta la calibración")
        }
    }
}
